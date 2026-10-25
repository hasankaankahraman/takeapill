import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/features/schedule/domain/dose_generator.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  const meals = MealTimes();
  final day = DateTime(2026, 11, 2); // Pazartesi

  List<DateTime> times(List<PlannedDose> d) =>
      d.map((e) => e.scheduledAt).toList();

  test('günde iki kez sabit saat', () {
    final rule = DailyRule(
      startDate: day,
      slots: const [DoseSlot.fixed(8 * 60), DoseSlot.fixed(20 * 60)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: day,
      to: day.add(const Duration(days: 1)),
    );
    expect(times(r), [DateTime(2026, 11, 2, 8), DateTime(2026, 11, 2, 20)]);
  });

  test('yemekten 30 dk önce kahvaltıya göre hesaplanır', () {
    final rule = DailyRule(
      startDate: day,
      slots: const [
        DoseSlot.anchored(
          TimingAnchor.breakfast,
          offsetMinutes: -30,
          food: FoodRelation.before,
        ),
      ],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: const MealTimes(breakfast: 9 * 60),
      from: day,
      to: DateTime(2026, 11, 3),
    );
    expect(r.single.scheduledAt, DateTime(2026, 11, 2, 8, 30));
    expect(r.single.food, FoodRelation.before);
  });

  test('haftanın günleri filtresi', () {
    final rule = DailyRule(
      startDate: day,
      weekdays: const {DateTime.monday, DateTime.thursday},
      slots: const [DoseSlot.fixed(9 * 60)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: day,
      to: DateTime(2026, 11, 9),
    );
    expect(times(r), [DateTime(2026, 11, 2, 9), DateTime(2026, 11, 5, 9)]);
  });

  test('gün aşırı (everyNDays=2) ve bitiş tarihi', () {
    final rule = DailyRule(
      startDate: day,
      endDate: DateTime(2026, 11, 6),
      everyNDays: 2,
      slots: const [DoseSlot.fixed(9 * 60)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: day,
      to: DateTime(2026, 11, 30),
    );
    expect(times(r), [
      DateTime(2026, 11, 2, 9),
      DateTime(2026, 11, 4, 9),
      DateTime(2026, 11, 6, 9),
    ]);
  });

  test('başlangıçtan önceki pencere boş', () {
    final rule = DailyRule(
      startDate: day,
      slots: const [DoseSlot.fixed(9 * 60)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: DateTime(2026, 10, 1),
      to: day,
    );
    expect(r, isEmpty);
  });

  test('pencere sınırı: from dahil, to hariç', () {
    final rule = DailyRule(
      startDate: day,
      slots: const [DoseSlot.fixed(8 * 60), DoseSlot.fixed(20 * 60)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: DateTime(2026, 11, 2, 8),
      to: DateTime(2026, 11, 2, 20),
    );
    expect(times(r), [DateTime(2026, 11, 2, 8)]);
  });

  test('her 8 saatte bir', () {
    final rule = IntervalRule(
      startDate: day,
      everyHours: 8,
      firstMinutes: 6 * 60,
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: day,
      to: DateTime(2026, 11, 3, 6),
    );
    expect(times(r), [
      DateTime(2026, 11, 2, 6),
      DateTime(2026, 11, 2, 14),
      DateTime(2026, 11, 2, 22),
    ]);
  });

  test('interval: pencere başlangıçtan çok sonra olsa da hizalı kalır', () {
    final rule = IntervalRule(
      startDate: day,
      everyHours: 8,
      firstMinutes: 6 * 60,
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: meals,
      from: DateTime(2026, 11, 10, 7),
      to: DateTime(2026, 11, 11),
    );
    expect(times(r), [DateTime(2026, 11, 10, 14), DateTime(2026, 11, 10, 22)]);
  });

  test('gerektiğinde (PRN) planlı doz üretmez', () {
    final r = generateDoses(
      medicationId: 1,
      rule: AsNeededRule(startDate: day, maxPerDay: 3),
      mealTimes: meals,
      from: day,
      to: DateTime(2026, 11, 9),
    );
    expect(r, isEmpty);
  });

  test('gece yarısını aşan ofset ertesi güne düşer', () {
    final rule = DailyRule(
      startDate: day,
      slots: const [DoseSlot.anchored(TimingAnchor.bedtime, offsetMinutes: 90)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: const MealTimes(bedtime: 23 * 60),
      from: day,
      to: DateTime(2026, 11, 3, 12),
    );
    expect(times(r), [DateTime(2026, 11, 3, 0, 30)]);
  });

  test('gece yarısını aşan doz, pencere ertesi gün başlasa da gelir', () {
    final rule = DailyRule(
      startDate: day,
      slots: const [DoseSlot.anchored(TimingAnchor.bedtime, offsetMinutes: 90)],
    );
    final r = generateDoses(
      medicationId: 1,
      rule: rule,
      mealTimes: const MealTimes(bedtime: 23 * 60),
      from: DateTime(2026, 11, 3),
      to: DateTime(2026, 11, 3, 12),
    );
    expect(times(r), [DateTime(2026, 11, 3, 0, 30)]);
  });
}
