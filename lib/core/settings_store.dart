import 'db/app_database.dart';
import 'notifications/notification_planner.dart';
import '../features/schedule/domain/schedule_models.dart';

/// Ayar anahtarları (Settings tablosu).
abstract final class SettingKeys {
  static const wake = 'meal.wake';
  static const breakfast = 'meal.breakfast';
  static const lunch = 'meal.lunch';
  static const dinner = 'meal.dinner';
  static const bedtime = 'meal.bedtime';
  static const leadMinutes = 'notif.lead';
  static const nagMinutes = 'notif.nag';
  static const snoozeMinutes = 'notif.snooze';
  static const onboarded = 'onboarded';
  static const themeMode = 'theme.mode';
}

extension SettingsAccess on AppDatabase {
  Future<int> _int(String key, int fallback) async =>
      int.tryParse(await getSetting(key) ?? '') ?? fallback;

  Future<MealTimes> loadMealTimes() async {
    const d = MealTimes();
    return MealTimes(
      wake: await _int(SettingKeys.wake, d.wake),
      breakfast: await _int(SettingKeys.breakfast, d.breakfast),
      lunch: await _int(SettingKeys.lunch, d.lunch),
      dinner: await _int(SettingKeys.dinner, d.dinner),
      bedtime: await _int(SettingKeys.bedtime, d.bedtime),
    );
  }

  Future<void> saveMealTimes(MealTimes m) async {
    await setSetting(SettingKeys.wake, '${m.wake}');
    await setSetting(SettingKeys.breakfast, '${m.breakfast}');
    await setSetting(SettingKeys.lunch, '${m.lunch}');
    await setSetting(SettingKeys.dinner, '${m.dinner}');
    await setSetting(SettingKeys.bedtime, '${m.bedtime}');
  }

  Future<NotificationPrefs> loadNotificationPrefs() async {
    const d = NotificationPrefs();
    return NotificationPrefs(
      leadMinutes: await _int(SettingKeys.leadMinutes, d.leadMinutes),
      nagMinutes: await _int(SettingKeys.nagMinutes, d.nagMinutes),
      snoozeMinutes: await _int(SettingKeys.snoozeMinutes, d.snoozeMinutes),
    );
  }

  Future<void> saveNotificationPrefs(NotificationPrefs p) async {
    await setSetting(SettingKeys.leadMinutes, '${p.leadMinutes}');
    await setSetting(SettingKeys.nagMinutes, '${p.nagMinutes}');
    await setSetting(SettingKeys.snoozeMinutes, '${p.snoozeMinutes}');
  }
}
