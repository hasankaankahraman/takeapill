import 'dart:ui' show Color;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
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

/// Planlama penceresi; iOS 64 sınırı nedeniyle plan her açılışta yenilenir.
const _horizonDays = 14;

/// Ertelenmiş dozları yakalamak için pencere bu kadar geriden başlar.
const _lookback = Duration(days: 1);

final _plugin = FlutterLocalNotificationsPlugin();

/// Uygulama kapalıyken bildirim butonuna basılınca (arka plan isolate'i).
@pragma('vm:entry-point')
Future<void> notificationBackgroundHandler(NotificationResponse r) async {
  await initTimezone();
  final db = AppDatabase();
  try {
    await handleNotificationAction(db, r.actionId, r.payload);
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
Future<void> handleNotificationAction(
  AppDatabase db,
  String? actionId,
  String? payload,
) async {
  final decoded = decodePayload(payload);
  if (decoded == null) return;
  final (medId, doseAt) = decoded;

  switch (actionId) {
    case actionTaken:
      await db.recordDose(medId, doseAt, DoseStatus.taken);
    case actionSkip:
      await db.recordDose(medId, doseAt, DoseStatus.skipped);
    case actionSnooze:
      final prefs = await db.loadNotificationPrefs();
      final snoozes = await db.loadSnoozes();
      snoozes[(medId, doseAt)] = clock.now().add(
        Duration(minutes: prefs.snoozeMinutes),
      );
      await db.saveSnoozes(snoozes);
    default:
      return; // Gövdeye dokunma: uygulama açılır, işlem yok.
  }
  await syncNotifications(db);
}

NotificationDetails _details() => const NotificationDetails(
  android: AndroidNotificationDetails(
    _channelId,
    'İlaç hatırlatıcıları',
    channelDescription: 'İlaç saatlerinde hatırlatma',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    color: Color(0xFF4F46E5),
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
      onDidReceiveNotificationResponse: (r) =>
          handleNotificationAction(db, r.actionId, r.payload),
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
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

  /// İzinleri ister; bildirim izninin verilip verilmediğini döner.
  static Future<bool> requestPermissions() async {
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
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
    final android = _android;
    final ok = await android?.requestNotificationsPermission() ?? false;
    // Bildirim izni yoksa alarm ayarları ekranına göndermenin anlamı yok.
    if (ok && !await exactAlarmsAllowed()) {
      await android?.requestExactAlarmsPermission();
    }
    return ok;
  }
}

AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
    .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
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
  final views = await loadDoseViews(
    db,
    now.subtract(_lookback),
    now.add(const Duration(days: _horizonDays)),
  );
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

  final plan = planNotifications(
    doses: pending,
    now: now,
    prefs: await db.loadNotificationPrefs(),
    snoozes: live,
  );
  // İzin yokken tam zamanlı kurulum hata verir; sistem birkaç dakika esnetsin.
  final mode = await NotificationService.exactAlarmsAllowed()
      ? AndroidScheduleMode.exactAllowWhileIdle
      : AndroidScheduleMode.inexactAllowWhileIdle;

  await _plugin.cancelAll();
  for (final n in plan) {
    // Planlamadan bu yana zamanı geçmiş olabilir; eklenti geçmiş tarihi reddeder.
    if (!n.at.isAfter(clock.now())) continue;
    await _plugin.zonedSchedule(
      id: n.id,
      scheduledDate: tz.TZDateTime.from(n.at, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: mode,
      title: _title(n.kind, n.medicationName),
      body: _body(n.kind, n.doseAt, n.food),
      payload: n.payload,
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
