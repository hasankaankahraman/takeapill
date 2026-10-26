import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/notifications/notification_planner.dart';
import 'package:takeapill/core/settings_store.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  group('cleanUserName', () {
    test('kenar ve tekrar eden boşlukları temizler', () {
      expect(cleanUserName('  Ayşe   Nur '), 'Ayşe Nur');
    });

    test('boş ve null değerler null olur', () {
      expect(cleanUserName(null), isNull);
      expect(cleanUserName(''), isNull);
      expect(cleanUserName(' \t\n '), isNull);
    });
  });

  group('yemek saatleri', () {
    test('kayıt yoksa varsayılanlar döner', () async {
      final m = await db.loadMealTimes();
      const d = MealTimes();
      expect(m.wake, d.wake);
      expect(m.bedtime, d.bedtime);
    });

    test('kaydedilen saatler geri okunur', () async {
      await db.saveMealTimes(
        const MealTimes(
          wake: 6 * 60,
          breakfast: 7 * 60,
          lunch: 12 * 60,
          dinner: 18 * 60,
          bedtime: 22 * 60,
        ),
      );
      final m = await db.loadMealTimes();
      expect([m.wake, m.breakfast, m.lunch, m.dinner, m.bedtime], [
        360,
        420,
        720,
        1080,
        1320,
      ]);
    });

    test('bozuk değer varsayılana düşer', () async {
      await db.setSetting(SettingKeys.lunch, 'abc');
      expect((await db.loadMealTimes()).lunch, const MealTimes().lunch);
    });
  });

  group('bildirim tercihleri', () {
    test('varsayılanlar', () async {
      final p = await db.loadNotificationPrefs();
      const d = NotificationPrefs();
      expect(p.leadMinutes, d.leadMinutes);
      expect(p.nagMinutes, d.nagMinutes);
      expect(p.snoozeMinutes, d.snoozeMinutes);
      expect(p.callMode, d.callMode);
    });

    test('kaydet/oku turu', () async {
      await db.saveNotificationPrefs(
        const NotificationPrefs(
          leadMinutes: 0,
          nagMinutes: 15,
          snoozeMinutes: 30,
          callMode: true,
        ),
      );
      final p = await db.loadNotificationPrefs();
      expect(
        [p.leadMinutes, p.nagMinutes, p.snoozeMinutes, p.callMode],
        [0, 15, 30, true],
      );
    });
  });

  group('kullanıcı adı', () {
    test('temizlenmiş ad kaydedilir', () async {
      expect(await db.saveUserName('  Mehmet  Ali '), 'Mehmet Ali');
      expect(await db.loadUserName(), 'Mehmet Ali');
    });

    test('boş ad kaydı siler', () async {
      await db.saveUserName('Mehmet');
      expect(await db.saveUserName('  '), isNull);
      expect(await db.loadUserName(), isNull);
    });
  });

  group('ertelemeler', () {
    test('kayıt yoksa boş', () async {
      expect(await db.loadSnoozes(), isEmpty);
    });

    test('kaydet/oku turu', () async {
      final s = {
        (1, DateTime(2026, 11, 2, 8)): DateTime(2026, 11, 2, 8, 10),
        (2, DateTime(2026, 11, 2, 20)): DateTime(2026, 11, 2, 20, 30),
      };
      await db.saveSnoozes(s);
      expect(await db.loadSnoozes(), s);
    });

    test('bozuk JSON boş sonuç verir', () async {
      await db.setSetting(SettingKeys.snoozes, '{not json');
      expect(await db.loadSnoozes(), isEmpty);
    });
  });
}
