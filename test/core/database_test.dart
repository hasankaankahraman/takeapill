import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/notifications/notification_planner.dart';
import 'package:takeapill/core/settings_store.dart';
import 'package:takeapill/features/schedule/data/schedule_repository.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final day = DateTime(2026, 11, 2);

  Future<int> addDaily() => db.addMedication(
    MedicationsCompanion.insert(name: 'Metformin'),
    encodeRule(
      DailyRule(
        startDate: day,
        slots: const [DoseSlot.fixed(8 * 60), DoseSlot.fixed(20 * 60)],
      ),
    ),
  );

  test('ilaç + kural kaydedilir ve doz görünümleri üretilir', () async {
    final id = await addDaily();
    final views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    expect(views.length, 2);
    expect(views.first.medication.id, id);
    expect(views.first.status, isNull);
  });

  test('doz işaretlenir ve geri alınır', () async {
    final id = await addDaily();
    final at = DateTime(2026, 11, 2, 8);
    await db.recordDose(id, at, DoseStatus.taken);
    var views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    expect(views.first.status, DoseStatus.taken);
    expect(views.last.status, isNull);

    // Aynı doz tekrar işaretlenince çoğalmaz, güncellenir.
    await db.recordDose(id, at, DoseStatus.skipped);
    views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    expect(views.first.status, DoseStatus.skipped);

    await db.clearDose(id, at);
    views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    expect(views.first.status, isNull);
  });

  test('işaretlenen doz için bildirim planlanmaz', () async {
    final id = await addDaily();
    await db.recordDose(id, DateTime(2026, 11, 2, 8), DoseStatus.taken);
    final views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    final pending = [
      for (final v in views)
        if (v.status == null) (v.dose, v.medication.name),
    ];
    final plan = planNotifications(
      doses: pending,
      now: DateTime(2026, 11, 2, 7),
      prefs: const NotificationPrefs(leadMinutes: 0, nagMinutes: 0),
    );
    expect(plan.single.doseAt, DateTime(2026, 11, 2, 20));
  });

  test('ilaç silinince kural ve doz kayıtları da silinir', () async {
    final id = await addDaily();
    await db.recordDose(id, DateTime(2026, 11, 2, 8), DoseStatus.taken);
    await db.deleteMedication(id);
    expect(await db.activeSchedules(), isEmpty);
    expect(await db.doseEventsBetween(day, DateTime(2026, 11, 3)), isEmpty);
  });

  test('düzenleme kuralı değiştirir', () async {
    final id = await addDaily();
    await db.updateMedication(
      id,
      const MedicationsCompanion(name: Value('Metformin XR')),
      encodeRule(
        DailyRule(startDate: day, slots: const [DoseSlot.fixed(9 * 60)]),
      ),
    );
    final views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    expect(views.single.medication.name, 'Metformin XR');
    expect(views.single.dose.scheduledAt, DateTime(2026, 11, 2, 9));
  });

  test('yemek saati ayarı kuralı etkiler', () async {
    await db.addMedication(
      MedicationsCompanion.insert(name: 'A'),
      encodeRule(
        DailyRule(
          startDate: day,
          slots: const [
            DoseSlot.anchored(TimingAnchor.breakfast, offsetMinutes: -30),
          ],
        ),
      ),
    );
    await db.saveMealTimes(const MealTimes(breakfast: 10 * 60));
    final views = await loadDoseViews(db, day, DateTime(2026, 11, 3));
    expect(views.single.dose.scheduledAt, DateTime(2026, 11, 2, 9, 30));
  });

  test('bildirim tercihleri varsayılan ve kayıtlı değer', () async {
    expect((await db.loadNotificationPrefs()).leadMinutes, 5);
    await db.saveNotificationPrefs(const NotificationPrefs(leadMinutes: 2));
    expect((await db.loadNotificationPrefs()).leadMinutes, 2);
  });
}
