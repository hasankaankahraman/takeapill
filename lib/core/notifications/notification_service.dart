import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../features/schedule/data/schedule_repository.dart';
import '../db/app_database.dart';
import '../settings_store.dart';
import 'notification_planner.dart';

const _channelId = 'doses';
const _category = 'dose';
const actionTaken = 'taken';
const actionSnooze = 'snooze';
const actionSkip = 'skip';

/// Planlama penceresi; iOS 64 sınırı nedeniyle plan her açılışta yenilenir.
const _horizonDays = 14;

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
      await db.recordDose(medId, doseAt, 'taken');
    case actionSkip:
      await db.recordDose(medId, doseAt, 'skipped');
    case actionSnooze:
      final prefs = await db.loadNotificationPrefs();
      final meds = await db.activeSchedules();
      final name = meds
          .map((e) => e.$1)
          .where((m) => m.id == medId)
          .map((m) => m.name)
          .firstOrNull;
      if (name != null) {
        await _scheduleOne(
          id: notificationId(medId, doseAt, NotifKind.nag) ^ 0x1,
          at: DateTime.now().add(Duration(minutes: prefs.snoozeMinutes)),
          name: name,
          kind: NotifKind.due,
          payload: payload!,
        );
      }
      return; // Erteleme planı bozmaz; yeniden senkron gerekmez.
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
  NotifKind.due => 'İlaç zamanı: $name',
  NotifKind.nag => 'Aldın mı? $name',
};

String _body(NotifKind k, DateTime doseAt, String food) {
  final hh = doseAt.hour.toString().padLeft(2, '0');
  final mm = doseAt.minute.toString().padLeft(2, '0');
  final time = k == NotifKind.nag
      ? '$hh:$mm dozu henüz işaretlenmedi'
      : '$hh:$mm';
  return food.isEmpty ? time : '$time · $food';
}

String foodLabel(String name) => switch (name) {
  'before' => 'Yemekten önce',
  'after' => 'Yemekten sonra',
  'withMeal' => 'Yemekle birlikte',
  'emptyStomach' => 'Aç karnına',
  'fullStomach' => 'Tok karnına',
  _ => '',
};

Future<void> _scheduleOne({
  required int id,
  required DateTime at,
  required String name,
  required NotifKind kind,
  required String payload,
  String food = '',
}) async {
  final decoded = decodePayload(payload);
  await _plugin.zonedSchedule(
    id: id,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: _details(),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    title: _title(kind, name),
    body: _body(kind, decoded?.$2 ?? at, food),
    payload: payload,
  );
}

class NotificationService {
  static Future<void> init(AppDatabase db, {void Function()? onChanged}) async {
    await initTimezone();
    await _plugin.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
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
      onDidReceiveNotificationResponse: (r) async {
        await handleNotificationAction(db, r.actionId, r.payload);
        onChanged?.call();
      },
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
  }

  /// Tanılama/test: sistemde bekleyen ve teslim edilmiş bildirimler.
  static Future<List<PendingNotificationRequest>> pending() =>
      _plugin.pendingNotificationRequests();

  static Future<List<ActiveNotification>> active() =>
      _plugin.getActiveNotifications();

  /// İzinleri ister; verilip verilmediğini döner.
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
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ok = await android?.requestNotificationsPermission() ?? false;
    await android?.requestExactAlarmsPermission();
    return ok;
  }
}

/// Bekleyen tüm bildirimleri silip önümüzdeki günler için yeniden planlar.
/// İşaretlenmiş (alındı/atlandı) dozlar için bildirim üretilmez.
Future<void> syncNotifications(AppDatabase db) async {
  await initTimezone();
  final now = DateTime.now();
  final views = await loadDoseViews(
    db,
    now.subtract(const Duration(hours: 1)),
    now.add(const Duration(days: _horizonDays)),
  );
  final pending = [
    for (final v in views)
      if (v.status == null) (v.dose, v.medication.name),
  ];
  final prefs = await db.loadNotificationPrefs();
  final plan = planNotifications(doses: pending, now: now, prefs: prefs);

  await _plugin.cancelAll();
  for (final n in plan) {
    await _scheduleOne(
      id: n.id,
      at: n.at,
      name: n.medicationName,
      kind: n.kind,
      payload: n.payload,
      food: foodLabel(n.food.name),
    );
  }
}
