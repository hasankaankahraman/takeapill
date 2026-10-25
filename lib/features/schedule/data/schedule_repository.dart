import '../../../core/db/app_database.dart';
import '../../../core/settings_store.dart';
import '../domain/dose_generator.dart';
import '../domain/rule_codec.dart';
import '../domain/schedule_models.dart';

/// Bir doz + ilaç bilgisi + (varsa) kullanıcı işlemi.
class DoseView {
  const DoseView({required this.dose, required this.medication, this.status});

  final PlannedDose dose;
  final Medication medication;

  /// null = henüz işlem yok, 'taken' | 'skipped'.
  final String? status;
}

/// [from, to) aralığındaki tüm planlı dozlar, kullanıcı işlemiyle birleşik.
Future<List<DoseView>> loadDoseViews(
  AppDatabase db,
  DateTime from,
  DateTime to,
) async {
  final meals = await db.loadMealTimes();
  final schedules = await db.activeSchedules();
  final events = await db.doseEventsBetween(from, to);
  final acted = {
    for (final e in events) (e.medicationId, e.scheduledAt): e.status,
  };

  final views = <DoseView>[];
  for (final (med, ruleJson) in schedules) {
    final doses = generateDoses(
      medicationId: med.id,
      rule: decodeRule(ruleJson),
      mealTimes: meals,
      from: from,
      to: to,
    );
    for (final d in doses) {
      views.add(
        DoseView(
          dose: d,
          medication: med,
          status: acted[(d.medicationId, d.scheduledAt)],
        ),
      );
    }
  }
  views.sort((a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt));
  return views;
}
