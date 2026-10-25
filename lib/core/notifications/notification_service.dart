import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/schedule/data/schedule_repository.dart';
import '../../features/schedule/domain/schedule_models.dart';
import '../db/app_database.dart';
import '../labels.dart';
import '../settings_store.dart';
import 'notification_planner.dart';

const _channelId = 'doses';
const _category = 'dose';
const actionTaken = 'taken';
const actionSnooze = 'snooze';
const actionSkip = 'skip';

/// Alarm sesiyle çalar: telefon sessizde ya da titreşimdeyken de duyulur
/// (iOS'taki AlarmKit alarmı gibi). Kanal ayarları sonradan değiştirilemediği
/// için zil sesi kullanan eski kanal açılışta silinir.
const _callChannelId = 'call_alarms';
const _oldCallChannelId = 'calls';
const _callCategory = 'call';
const actionAnswer = 'answer';
const actionDecline = 'decline';

/// Android'de arama bu süre çalar, sonra cevapsız sayılır.
const _callTimeout = Duration(seconds: 60);

/// iOS 26+'da arama modunun AlarmKit alarmları (CallAlarms.swift).
const _callChannel = MethodChannel('takeapill/call');

/// Planlama penceresi; iOS 64 sınırı nedeniyle plan her açılışta yenilenir.
const _horizonDays = 14;

/// iOS en fazla 64 bekleyen bildirime izin verir (uygulamayı açma
/// hatırlatmasına yer kalır). Android'in sınırı çok daha geniş, ama eklenti her
/// kurulumda tüm listeyi yeniden kaydettiği için sayı makul tutulur.
int get _planLimit => defaultTargetPlatform == TargetPlatform.iOS ? 60 : 120;

/// Plan bitince uygulamayı açmayı hatırlatan bildirim (bkz. [keepAliveAt]).
const _keepAliveId = 0;

/// Ertelenmiş dozları yakalamak için pencere bu kadar geriden başlar.
const _lookback = Duration(days: 1);

final _plugin = FlutterLocalNotificationsPlugin();

/// Uygulama kapalıyken bildirim butonuna basılınca (arka plan isolate'i).
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse r) async {
  await initTimezone();
  final db = AppDatabase();
  try {
    await _respond(db, r);
  } finally {
    await db.close();
  }
}

bool _tzReady = false;

Future<void> initTimezone() async {
  if (_tzReady) return;
  tzdata.initializeTimeZones();
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(info.identifier));
  } catch (e) {
    debugPrint('Saat dilimi alınamadı, UTC kullanılacak: $e');
  }
  _tzReady = true;
}

/// Bildirim butonu / dokunuş işleyicisi. Ön ve arka planda aynı mantık.
/// [at]: işlemin yapıldığı an (iOS alarm butonları sonradan işlenir).
Future<void> handleNotificationAction(
  AppDatabase db,
  String? actionId,
  String? payload, {
  DateTime? at,
}) async {
  final decoded = decodePayload(payload);
  if (decoded == null) return;
  final (medId, doseAt) = decoded;

  switch (actionId) {
    case actionTaken:
      await db.recordDose(medId, doseAt, DoseStatus.taken);
    case actionSkip:
      await db.recordDose(medId, doseAt, DoseStatus.skipped);
    case actionSnooze || actionDecline:
      final prefs = await db.loadNotificationPrefs();
      final snoozes = await db.loadSnoozes();
      snoozes[(medId, doseAt)] = (at ?? clock.now()).add(
        Duration(minutes: prefs.snoozeMinutes),
      );
      await db.saveSnoozes(snoozes);
    default:
      // Gövdeye dokunma ve "Kabul et": uygulama açılır, işlem yok.
      return;
  }
  await syncNotifications(db);
}

/// Bildirim butonu: önce iOS alarmında bekleyen işlemler uygulanır. Ardından
/// gelen senkron tüm alarmları yeniden kurar; henüz işlenmemiş bir "Reddet"in
/// kurduğu erteleme alarmı yoksa silinip kaybolurdu. Bekleyen bir "Kabul et"
/// varsa true döner.
Future<bool> _respond(AppDatabase db, NotificationResponse r) async {
  final answered = await NotificationService.applyAlarmActions(db);
  await handleNotificationAction(db, r.actionId, r.payload);
  return answered;
}

/// "Kabul et" ya da arama bildirimine dokunma: uygulama Bugün'de açılır.
bool _answers(NotificationResponse r) =>
    isCallPayload(r.payload) &&
    (r.actionId == null || r.actionId == actionAnswer);

final _answered = StreamController<void>.broadcast();

NotificationDetails _details({bool call = false}) =>
    call ? _callDetails() : _doseDetails;

const _doseDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    'İlaç hatırlatıcıları',
    channelDescription: 'İlaç saatlerinde hatırlatma',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    color: Color(0xFF0F766E),
    actions: [
      AndroidNotificationAction(actionTaken, 'Aldım'),
      AndroidNotificationAction(actionSnooze, 'Ertele'),
      AndroidNotificationAction(actionSkip, 'Atla'),
    ],
  ),
  iOS: DarwinNotificationDetails(
    categoryIdentifier: _category,
    presentAlert: true,
    presentSound: true,
    presentBadge: false,
  ),
);

NotificationDetails _callDetails() => NotificationDetails(
  android: AndroidNotificationDetails(
    _callChannelId,
    'İlaç aramaları',
    channelDescription: 'Doz saatinde gelen arama gibi çalan hatırlatma',
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.alarm,
    // Telefonun kendi zil sesi; FLAG_INSISTENT ile kapatılana dek tekrar eder.
    sound: const UriAndroidNotificationSound(
      'content://settings/system/ringtone',
    ),
    // Alarm akışı sessiz/titreşim modundan etkilenmez; Rahatsız Etmeyin de
    // varsayılan olarak alarmlara izin verir.
    audioAttributesUsage: AudioAttributesUsage.alarm,
    additionalFlags: Int32List.fromList([4]),
    vibrationPattern: Int64List.fromList([0, 1000, 1000]),
    timeoutAfter: _callTimeout.inMilliseconds,
    color: const Color(0xFF0F766E),
    actions: const [
      AndroidNotificationAction(actionDecline, 'Reddet'),
      AndroidNotificationAction(
        actionAnswer,
        'Kabul et',
        showsUserInterface: true,
      ),
    ],
  ),
  // iOS 26 öncesi ya da alarm izni yokken; varsa AlarmKit alarmı kurulur.
  iOS: const DarwinNotificationDetails(
    categoryIdentifier: _callCategory,
    sound: 'ring.caf',
    presentAlert: true,
    presentSound: true,
    presentBadge: false,
  ),
);

String _title(NotifKind k, String name) => switch (k) {
  NotifKind.lead => 'Birazdan: $name',
  NotifKind.due || NotifKind.snooze => 'İlaç zamanı: $name',
  NotifKind.nag => 'Aldın mı? $name',
};

String _body(NotifKind k, DateTime doseAt, FoodRelation food) {
  final time = fmtTime(doseAt);
  final main = k == NotifKind.nag ? '$time dozu henüz işaretlenmedi' : time;
  final note = foodNote(food);
  return note.isEmpty ? main : '$main · $note';
}

/// AlarmKit alarmının gövdesi yok; yemek notu başlığa eklenir.
String _alarmTitle(PlannedNotification n) {
  final title = _title(n.kind, n.medicationName);
  final note = foodNote(n.food);
  return note.isEmpty ? title : '$title · $note';
}

const _keepAliveDetails = NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    'İlaç hatırlatıcıları',
    channelDescription: 'İlaç saatlerinde hatırlatma',
    importance: Importance.max,
    priority: Priority.high,
    color: Color(0xFF0F766E),
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    presentBadge: false,
  ),
);

class NotificationService {
  static Future<void> init(AppDatabase db) async {
    await initTimezone();
    await _plugin.initialize(
      settings: InitializationSettings(
        // Tek renkli ikon; res/raw/keep.xml R8'in silmesini engeller.
        android: const AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          // İzin, onboarding sırasında açıklamayla istenir.
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              _callCategory,
              actions: [
                DarwinNotificationAction.plain(
                  actionDecline,
                  'Reddet',
                  options: {DarwinNotificationActionOption.destructive},
                ),
                DarwinNotificationAction.plain(
                  actionAnswer,
                  'Kabul et',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
            DarwinNotificationCategory(
              _category,
              actions: [
                DarwinNotificationAction.plain(actionTaken, 'Aldım'),
                DarwinNotificationAction.plain(actionSnooze, 'Ertele'),
                DarwinNotificationAction.plain(
                  actionSkip,
                  'Atla',
                  options: {DarwinNotificationActionOption.destructive},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (_answers(r)) _answered.add(null);
        unawaited(
          _respond(db, r).then((answered) {
            if (answered) _answered.add(null);
          }),
        );
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    try {
      await _android?.deleteNotificationChannel(channelId: _oldCallChannelId);
    } on PlatformException catch (e) {
      debugPrint('Eski arama kanalı silinemedi: $e');
    }
    // iOS alarmında butona uygulama açıkken basıldı.
    _callChannel.setMethodCallHandler((c) async {
      if (c.method != 'alarmActions') return;
      if (await applyAlarmActions(db)) _answered.add(null);
    });
  }

  /// Açık uygulamada aramaya "Kabul et" denildi (bildirim ya da iOS alarmı);
  /// uygulama Bugün ekranına geçer.
  static Stream<void> get answeredCalls => _answered.stream;

  /// iOS alarmındaki butonlar uygulama kapalıyken basılmış olabilir:
  /// "Reddet"leri ertelemeye çevirir; "Kabul et" varsa true döner.
  static Future<bool> applyAlarmActions(AppDatabase db) async {
    List<String> actions;
    try {
      actions =
          await _callChannel.invokeListMethod<String>('takeAlarmActions') ??
          const [];
    } on MissingPluginException {
      return false; // Android, testler
    }
    var answered = false;
    for (final a in actions) {
      // "eylem|payload|ms"; payload'ın kendisi de "|" içerir.
      final parts = a.split('|');
      if (parts.length < 3) continue;
      final payload = parts.sublist(1, parts.length - 1).join('|');
      final ms = int.tryParse(parts.last);
      if (ms == null || decodePayload(payload) == null) continue;
      switch (parts.first) {
        case actionDecline:
          await handleNotificationAction(
            db,
            actionDecline,
            payload,
            at: DateTime.fromMillisecondsSinceEpoch(ms),
          );
        case actionAnswer:
          answered = true;
      }
    }
    return answered;
  }

  /// iOS 26+: Dynamic Island'da ve kilit ekranında çalan alarm için AlarmKit
  /// izni (sistem penceresi yalnızca ilk kez çıkar). Yoksa arama bildirim
  /// olarak gelir; Android'de alarm sesiyle, iOS'ta zil sesiyle.
  static Future<void> requestCallPermission() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _callChannel.invokeMethod<bool>('requestAlarms');
    } on PlatformException catch (e) {
      debugPrint('Alarm izni istenemedi: $e');
    }
  }

  /// iOS'ta AlarmKit izni: "authorized", "notDetermined", "denied" ya da
  /// iOS 26 öncesinde "unsupported". Diğer platformlarda null.
  static Future<String?> callAlarmState() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    try {
      return await _callChannel.invokeMethod<String>('alarmState');
    } on PlatformException catch (e) {
      debugPrint('Alarm durumu alınamadı: $e');
    } on MissingPluginException {
      // Testler
    }
    return null;
  }

  /// Arama modu açık ama alarm izni hiç sorulmamışsa (ör. mod önceki bir
  /// sürümde seçildi) şimdi sorar ve planı alarmlarla yeniden kurar.
  static Future<void> ensureCallAlarms(AppDatabase db) async {
    if (await callAlarmState() != 'notDetermined') return;
    if (!(await db.loadNotificationPrefs()).callMode) return;
    await requestCallPermission();
    await trySyncNotifications(db);
  }

  /// Tanılama/test: sistemde bekleyen ve teslim edilmiş bildirimler.
  static Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  static Future<List<ActiveNotification>> active() =>
      _plugin.getActiveNotifications();

  /// Android 12+ "Alarmlar ve hatırlatıcılar" izni. Android 14'ten itibaren
  /// yeni kurulumlarda varsayılan olarak kapalıdır; iOS'ta her zaman true.
  static Future<bool> exactAlarmsAllowed() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  /// Android 12+ "Alarmlar ve hatırlatıcılar" ayar ekranını açar ve kullanıcı
  /// dönünce izin durumunu verir. Nedeni önce kullanıcıya anlatılmalı.
  static Future<bool> requestExactAlarms() async {
    await _android?.requestExactAlarmsPermission();
    return exactAlarmsAllowed();
  }

  /// Bildirim izni (iOS'ta geçici izin de sayılır); bilinemezse true.
  static Future<bool> notificationsEnabled() async {
    try {
      final ios = _ios;
      if (ios != null) {
        final o = await ios.checkPermissions();
        return o == null || o.isEnabled || o.isProvisionalEnabled;
      }
      return await _android?.areNotificationsEnabled() ?? true;
    } on PlatformException catch (e) {
      debugPrint('Bildirim izni okunamadı: $e');
      return true;
    }
  }

  /// İki retten sonra izin penceresi artık çıkmaz; izin yalnızca sistem
  /// ayarlarından açılabilir.
  static Future<void> openSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } on PlatformException catch (e) {
      debugPrint('Bildirim ayarları açılamadı: $e');
    }
  }

  /// Bildirim iznini ister ve verilip verilmediğini döner. Android'deki alarm
  /// izni ayrıca, açıklamayla istenir ([requestExactAlarms]).
  static Future<bool> requestPermissions() async {
    final ios = _ios;
    if (ios != null) {
      // Yalnızca test/geliştirme: --dart-define=PROVISIONAL_NOTIFICATIONS=true
      // izin penceresi çıkarmadan sessiz teslimata izin verir.
      const provisional = bool.fromEnvironment('PROVISIONAL_NOTIFICATIONS');
      return await ios.requestPermissions(
            alert: true,
            sound: !provisional,
            provisional: provisional,
          ) ??
          false;
    }
    return await _android?.requestNotificationsPermission() ?? false;
  }
}

AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
    .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();

IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
    .resolvePlatformSpecificImplementation<
      IOSFlutterLocalNotificationsPlugin
    >();

Future<void>? _running;

/// Bekleyen tüm bildirimleri silip önümüzdeki günler için yeniden planlar.
/// İşaretlenmiş (alındı/atlandı) dozlar için bildirim üretilmez.
///
/// Çağrılar sırayla çalışır; yoksa üst üste iki senkronda eskisinin planı,
/// yenisinin iptalinden sonra kurulup işaretlenmiş bir dozu hatırlatabilir.
Future<void> syncNotifications(AppDatabase db) async {
  for (var other = _running; other != null; other = _running) {
    try {
      await other;
    } catch (_) {
      // Öncekinin hatası çağıranına iletildi; bu senkron yine çalışır.
    }
  }
  final run = _running = _sync(db);
  try {
    await run;
  } finally {
    if (identical(_running, run)) _running = null;
  }
}

Future<void> _sync(AppDatabase db) async {
  await initTimezone();
  // Eklenti de geçmiş tarih kontrolünü `clock` ile yapar; aynı saat kullanılmalı.
  final now = clock.now();
  final horizonEnd = now.add(const Duration(days: _horizonDays));
  final views = await loadDoseViews(db, now.subtract(_lookback), horizonEnd);
  final pending = [
    for (final v in views)
      if (v.status == null) (v.dose, v.medication.name),
  ];

  // Zamanı geçmiş ya da doz işaretlenmişse erteleme artık gereksiz.
  final snoozes = await db.loadSnoozes();
  final open = {for (final (d, _) in pending) (d.medicationId, d.scheduledAt)};
  final live = {
    for (final e in snoozes.entries)
      if (e.value.isAfter(now) && open.contains(e.key)) e.key: e.value,
  };
  if (live.length != snoozes.length) await db.saveSnoozes(live);

  final prefs = await db.loadNotificationPrefs();
  final plan = planNotifications(
    doses: pending,
    now: now,
    prefs: prefs,
    snoozes: live,
    limit: _planLimit,
  );
  final keepAlive = keepAliveAt(
    doses: pending,
    plan: plan,
    horizonEnd: horizonEnd,
  );
  // iOS 26+ ve izin varsa aramalar bildirim yerine AlarmKit alarmı olur.
  var alarms = await NotificationService.callAlarmState() == 'authorized';
  if (alarms) {
    try {
      await _callChannel.invokeMethod<void>('scheduleAlarms', [
        for (final n in plan)
          if (n.call && n.at.isAfter(clock.now()))
            {
              'at': n.at.millisecondsSinceEpoch,
              'title': _alarmTitle(n),
              'payload': n.payload,
              'snoozeMinutes': prefs.snoozeMinutes,
              'cancelIds': [
                notificationId(n.medicationId, n.doseAt, NotifKind.nag),
              ],
            },
      ]);
    } on PlatformException catch (e) {
      // Alarm kurulamazsa arama hiç çalmasın diye bildirime düşülür.
      debugPrint('Arama alarmları kurulamadı, bildirim kullanılacak: $e');
      alarms = false;
    }
  }
  // İzin yokken tam zamanlı kurulum hata verir; sistem birkaç dakika esnetsin.
  final mode = await NotificationService.exactAlarmsAllowed()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  await _plugin.cancelAll();
  for (final n in plan) {
    // Planlamadan bu yana zamanı geçmiş olabilir; eklenti geçmiş tarihi reddeder.
    if (!n.at.isAfter(clock.now()) || (alarms && n.call)) continue;
    await _plugin.zonedSchedule(
      id: n.id,
      scheduledDate: tz.TZDateTime.from(n.at, tz.local),
      notificationDetails: _details(call: n.call),
      androidScheduleMode: mode,
      title: _title(n.kind, n.medicationName),
      body: _body(n.kind, n.doseAt, n.food),
      payload: n.payload,
    );
  }
  if (keepAlive != null) {
    await _plugin.zonedSchedule(
      id: _keepAliveId,
      scheduledDate: tz.TZDateTime.from(keepAlive, tz.local),
      notificationDetails: _keepAliveDetails,
      androidScheduleMode: mode,
      title: 'Hatırlatmaların sürsün',
      body: 'Sonraki ilaç hatırlatmalarını kurmak için uygulamayı bir kez aç.',
    );
  }
}

/// Sonucu beklenmeyen yerler için: hata uygulamayı düşürmez, kaydedilir.
Future<void> trySyncNotifications(AppDatabase db) async {
  try {
    await syncNotifications(db);
  } catch (e, s) {
    debugPrint('Bildirimler planlanamadı: $e\n$s');
  }
}
