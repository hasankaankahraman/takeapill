import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/notifications/notification_planner.dart';
import 'package:takeapill/core/notifications/notification_service.dart';
import 'package:takeapill/core/settings_store.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

import '../helpers/fake_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeNotifications fake;
  late int medId;
  late DateTime doseAt;

  setUp(() async {
    fake = FakeNotifications()..install();
    db = AppDatabase(NativeDatabase.memory());
    await NotificationService.init(db);

    // Gerçek saate göre ~2 saat sonra tek bir günlük doz.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    doseAt = DateTime(now.year, now.month, now.day, now.hour + 2, now.minute);
    medId = await db.addMedication(
      MedicationsCompanion.insert(name: 'Metformin'),
      encodeRule(
        DailyRule(
          startDate: today,
          slots: [DoseSlot.fixed(doseAt.difference(today).inMinutes)],
        ),
      ),
    );
  });

  tearDown(() async {
    fake.uninstall();
    await db.close();
  });

  int idOf(NotifKind k) => notificationId(medId, doseAt, k);
  String payload() => encodePayload(medId, doseAt);

  test('doz için önce, zamanında ve tekrar bildirimi kurulur', () async {
    await syncNotifications(db);
    expect(
      fake.scheduled.keys,
      containsAll([
        idOf(NotifKind.lead),
        idOf(NotifKind.due),
        idOf(NotifKind.nag),
      ]),
    );
    expect(
      fake.scheduled[idOf(NotifKind.due)]!['title'],
      'İlaç zamanı: Metformin',
    );
  });

  test('arama modunda doz saati alarm sesli arama kanalında çalar', () async {
    await db.saveNotificationPrefs(const NotificationPrefs(callMode: true));
    await syncNotifications(db);
    Map<Object?, Object?> specifics(NotifKind k) =>
        fake.scheduled[idOf(k)]!['platformSpecifics'] as Map<Object?, Object?>;

    expect(specifics(NotifKind.due)['channelId'], 'call_alarms');
    // Alarm akışı: telefon sessizdeyken de çalar (iOS AlarmKit gibi).
    expect(
      specifics(NotifKind.due)['audioAttributesUsage'],
      AudioAttributesUsage.alarm.value,
    );
    expect(specifics(NotifKind.due)['fullScreenIntent'], isFalse);
    // Zil sesi kullanan eski kanal silinir.
    expect(
      fake.calls
          .where((c) => c.method == 'deleteNotificationChannel')
          .map((c) => c.arguments),
      contains('calls'),
    );
    expect(
      fake.scheduled[idOf(NotifKind.due)]!['payload'],
      '${payload()}|call',
    );
    expect(specifics(NotifKind.lead)['channelId'], 'doses');
    expect(specifics(NotifKind.nag)['channelId'], 'doses');

    // "Reddet" ertelemeyle aynıdır; erteleme bildirimi de arama olur.
    await handleNotificationAction(db, actionDecline, '${payload()}|call');
    expect(specifics(NotifKind.snooze)['channelId'], 'call_alarms');
    expect((await db.loadSnoozes()).keys, [(medId, doseAt)]);
  });

  test('iOS alarmında "Reddet" erteler, "Kabul et" bildirilir', () async {
    const channel = MethodChannel('takeapill/call');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    // Yerel taraf yoksa (Android, testler) işlem yok sayılır.
    expect(await NotificationService.applyAlarmActions(db), isFalse);

    final at = DateTime.fromMillisecondsSinceEpoch(
      DateTime.now().millisecondsSinceEpoch,
    );
    final p = encodePayload(medId, doseAt, call: true);
    final ms = at.millisecondsSinceEpoch;
    messenger.setMockMethodCallHandler(
      channel,
      (c) async => c.method == 'takeAlarmActions'
          ? ['decline|$p|$ms', 'answer|$p|$ms', 'bozuk']
          : null,
    );
    expect(await NotificationService.applyAlarmActions(db), isTrue);
    // Erteleme, butona basıldığı andan sayılır (uygulama sonra açılsa da).
    expect(
      (await db.loadSnoozes())[(medId, doseAt)],
      at.add(const Duration(minutes: 10)),
    );
    expect(fake.scheduled.keys, contains(idOf(NotifKind.snooze)));
  });

  test('bildirim butonu, bekleyen iOS "Reddet"ini önce uygular', () async {
    const channel = MethodChannel('takeapill/call');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    // Uygulama kapalıyken alarmda "Reddet"e basıldı, işlem henüz işlenmedi.
    final p = encodePayload(medId, doseAt, call: true);
    final ms = DateTime.now().millisecondsSinceEpoch;
    var pending = ['decline|$p|$ms'];
    messenger.setMockMethodCallHandler(channel, (c) async {
      if (c.method != 'takeAlarmActions') return null;
      final out = pending;
      pending = [];
      return out;
    });

    // Başka bir bildirime dokunma; senkron ertelemeyi kaybetmemeli.
    await fake.respond(payload: payload());
    await pumpEventQueue();
    expect((await db.loadSnoozes()).keys, [(medId, doseAt)]);
    expect(fake.scheduled.keys, contains(idOf(NotifKind.snooze)));
  });

  test(
    'plan dozları kapsamıyorsa uygulamayı açma hatırlatması kurulur',
    () async {
      // Günlük doz pencere sonrasında da sürer.
      await syncNotifications(db);
      final keepAlive = fake.scheduled[0];
      expect(keepAlive?['title'], 'Hatırlatmaların sürsün');
      // Planın son hatırlatmasından sonra çalar (aynı dilimde ISO metinler).
      String at(Map<Object?, Object?> a) => a['scheduledDateTime'] as String;
      final last = fake.scheduled.entries
          .where((e) => e.key != 0)
          .map((e) => at(e.value))
          .reduce((a, b) => a.compareTo(b) > 0 ? a : b);
      expect(at(keepAlive!).compareTo(last), greaterThan(0));
    },
  );

  test('alarm izni yoksa esnek moda düşer, hata vermez', () async {
    fake.exactAlarmsAllowed = false;
    await syncNotifications(db);
    expect(fake.scheduled, isNotEmpty);
    for (final args in fake.scheduled.values) {
      final specifics = args['platformSpecifics'] as Map<Object?, Object?>;
      expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
    }

    fake.exactAlarmsAllowed = true;
    await syncNotifications(db);
    final specifics =
        fake.scheduled.values.first['platformSpecifics']
            as Map<Object?, Object?>;
    expect(specifics['scheduleMode'], 'exactAllowWhileIdle');
  });

  test(
    'erteleme planın yenilenmesinden sağ çıkar, doz işaretlenince silinir',
    () async {
      await syncNotifications(db);
      await handleNotificationAction(db, actionSnooze, payload());

      // Erteleme, dozun diğer bildirimlerinin yerini alır.
      expect(fake.scheduled.keys, contains(idOf(NotifKind.snooze)));
      expect(fake.scheduled.keys, isNot(contains(idOf(NotifKind.due))));

      // Uygulama öne gelince plan yeniden kurulur; erteleme kaybolmamalı.
      await syncNotifications(db);
      expect(fake.scheduled.keys, contains(idOf(NotifKind.snooze)));
      expect((await db.loadSnoozes()).keys, [(medId, doseAt)]);

      await handleNotificationAction(db, actionTaken, payload());
      expect(fake.scheduled.keys, isNot(contains(idOf(NotifKind.snooze))));
      expect(await db.loadSnoozes(), isEmpty);
    },
  );

  test('üst üste senkronlar iç içe geçmez', () async {
    fake.latency = const Duration(milliseconds: 1);
    await Future.wait([syncNotifications(db), syncNotifications(db)]);
    final methods = [
      for (final c in fake.calls)
        if (c.method == 'cancelAll' || c.method == 'zonedSchedule') c.method,
    ];
    final perSync = methods.length ~/ 2;
    expect(methods[0], 'cancelAll');
    expect(methods[perSync], 'cancelAll');
    expect(methods.where((m) => m == 'cancelAll').length, 2);
  });

  test('bozuk erteleme kaydı yok sayılır', () async {
    await db.setSetting(SettingKeys.snoozes, 'bozuk');
    expect(await db.loadSnoozes(), isEmpty);
    await syncNotifications(db);
    expect(fake.scheduled, isNotEmpty);
  });
}
