import '../../../core/db/app_database.dart';
import '../../../core/settings_store.dart';
import '../domain/dose_generator.dart';
import '../domain/rule_codec.dart';
import '../domain/schedule_models.dart';

/// Arşivlenmemiş bir ilaç ve çözülmüş kuralı.
class MedicationPlan {
  const MedicationPlan({required this.medication, required this.rule});

  final Medication medication;
  final ScheduleRule rule;
}

/// Bir doz + ilaç bilgisi + (varsa) kullanıcı işlemi.
class DoseView {
  const DoseView({required this.dose, required this.medication, this.status});

  final PlannedDose dose;
  final Medication medication;

  /// null = henüz işlem yok.
  final DoseStatus? status;
}

/// Ada göre sıralı aktif ilaçlar.
Future<List<MedicationPlan>> loadMedicationPlans(AppDatabase db) async => [
  for (final (med, json) in await db.activeSchedules())
    MedicationPlan(medication: med, rule: decodeRule(json)),
];

/// [from, to) aralığındaki tüm planlı dozlar, kullanıcı işlemiyle birleşik.
Future<List<DoseView>> loadDoseViews(
  AppDatabase db,
  DateTime from,
  DateTime to,
) async {
  final meals = await db.loadMealTimes();
  final plans = await loadMedicationPlans(db);
  final events = await db.doseEventsBetween(from, to);
  final acted = {
    for (final e in events)
      (e.medicationId, e.scheduledAt): DoseStatus.values
          .where((s) => s.name == e.status)
          .firstOrNull,
  };

  final views = <DoseView>[];
  for (final p in plans) {
    final doses = generateDoses(
      medicationId: p.medication.id,
      rule: p.rule,
      mealTimes: meals,
      from: from,
      to: to,
    );
    for (final d in doses) {
      views.add(
        DoseView(
          dose: d,
          medication: p.medication,
          status: acted[(d.medicationId, d.scheduledAt)],
        ),
      );
    }
  }
  views.sort((a, b) => a.dose.scheduledAt.compareTo(b.dose.scheduledAt));
  return views;
}
