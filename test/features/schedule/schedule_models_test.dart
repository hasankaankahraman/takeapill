import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  const meals = MealTimes();

  group('MealTimes', () {
    test('minutesFor her çapa için doğru dakikayı verir', () {
      expect(meals.minutesFor(TimingAnchor.wake), meals.wake);
      expect(meals.minutesFor(TimingAnchor.breakfast), meals.breakfast);
      expect(meals.minutesFor(TimingAnchor.lunch), meals.lunch);
      expect(meals.minutesFor(TimingAnchor.dinner), meals.dinner);
      expect(meals.minutesFor(TimingAnchor.bedtime), meals.bedtime);
    });

    test('fixed çapa hata verir', () {
      expect(() => meals.minutesFor(TimingAnchor.fixed), throwsArgumentError);
    });

    test('copyWith yalnızca verilen alanı değiştirir', () {
      final m = meals.copyWith(lunch: 12 * 60);
      expect(m.lunch, 720);
      expect(m.wake, meals.wake);
      expect(m.dinner, meals.dinner);
    });
  });

  group('DoseSlot.minutesOn', () {
    test('sabit saat yemek saatlerinden etkilenmez', () {
      expect(const DoseSlot.fixed(9 * 60).minutesOn(meals), 540);
    });

    test('çapalı doz ofset uygular', () {
      const before = DoseSlot.anchored(
        TimingAnchor.breakfast,
        offsetMinutes: -30,
      );
      expect(before.minutesOn(meals), meals.breakfast - 30);
    });

    test('gün sınırını aşabilir', () {
      const late = DoseSlot.anchored(TimingAnchor.bedtime, offsetMinutes: 90);
      expect(late.minutesOn(meals), meals.bedtime + 90);
      expect(late.minutesOn(meals), greaterThan(24 * 60));
    });
  });

  test('PlannedDose eşitliği değer tabanlıdır', () {
    final a = PlannedDose(
      medicationId: 1,
      scheduledAt: DateTime(2026, 1, 1, 8),
      food: FoodRelation.after,
    );
    final b = PlannedDose(
      medicationId: 1,
      scheduledAt: DateTime(2026, 1, 1, 8),
      food: FoodRelation.after,
    );
    final c = PlannedDose(
      medicationId: 2,
      scheduledAt: DateTime(2026, 1, 1, 8),
      food: FoodRelation.after,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
