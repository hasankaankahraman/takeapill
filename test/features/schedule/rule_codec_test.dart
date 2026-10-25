import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  test('DailyRule gidiş-dönüş', () {
    final rule = DailyRule(
      startDate: DateTime(2026, 11, 2),
      endDate: DateTime(2026, 12, 1),
      weekdays: const {1, 3, 5},
      everyNDays: 1,
      slots: const [
        DoseSlot.fixed(480, food: FoodRelation.fullStomach),
        DoseSlot.anchored(
          TimingAnchor.dinner,
          offsetMinutes: -30,
          food: FoodRelation.before,
        ),
      ],
    );
    final back = decodeRule(encodeRule(rule)) as DailyRule;
    expect(back.startDate, rule.startDate);
    expect(back.endDate, rule.endDate);
    expect(back.weekdays, rule.weekdays);
    expect(back.slots.length, 2);
    expect(back.slots[0].anchor, TimingAnchor.fixed);
    expect(back.slots[0].fixedMinutes, 480);
    expect(back.slots[0].food, FoodRelation.fullStomach);
    expect(back.slots[1].anchor, TimingAnchor.dinner);
    expect(back.slots[1].offsetMinutes, -30);
  });

  test('IntervalRule ve AsNeededRule gidiş-dönüş', () {
    final i = decodeRule(
      encodeRule(
        IntervalRule(
          startDate: DateTime(2026, 11, 2),
          everyHours: 6,
          firstMinutes: 420,
          food: FoodRelation.withMeal,
        ),
      ),
    ) as IntervalRule;
    expect(i.everyHours, 6);
    expect(i.firstMinutes, 420);
    expect(i.endDate, isNull);
    expect(i.food, FoodRelation.withMeal);

    final a = decodeRule(
      encodeRule(AsNeededRule(startDate: DateTime(2026, 11, 2), maxPerDay: 3)),
    ) as AsNeededRule;
    expect(a.maxPerDay, 3);
  });

  test('bilinmeyen tip hata verir', () {
    expect(
      () => decodeRule('{"type":"x","start":"2026-01-01"}'),
      throwsFormatException,
    );
  });
}
