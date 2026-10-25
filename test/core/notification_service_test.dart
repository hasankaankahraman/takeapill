import 'package:drift/native.dart';
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
