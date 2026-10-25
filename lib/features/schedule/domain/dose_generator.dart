import 'schedule_models.dart';

/// Kuralı, [from] (dahil) ile [to] (hariç) arasındaki planlı dozlara çevirir.
/// Saf fonksiyon: DB ve bildirim katmanından bağımsız, kolay test edilir.
List<PlannedDose> generateDoses({
  required int medicationId,
  required ScheduleRule rule,
  required MealTimes mealTimes,
  required DateTime from,
  required DateTime to,
}) {
  final doses = switch (rule) {
    DailyRule() => _daily(medicationId, rule, mealTimes, from, to),
    IntervalRule() => _interval(medicationId, rule, from, to),
    AsNeededRule() => <PlannedDose>[],
  };
  doses.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return doses;
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Yerel duvar saatiyle gün + dakika. DateTime(...) dakika taşmasını gün
/// sınırlarında doğru normalize eder; yaz saati boşluğunda ileri kayar.
DateTime _at(DateTime day, int minutes) =>
    DateTime(day.year, day.month, day.day, 0, minutes);

List<PlannedDose> _daily(
  int id,
  DailyRule rule,
  MealTimes meals,
  DateTime from,
  DateTime to,
) {
  final start = _day(rule.startDate);
  final end = rule.endDate == null ? null : _day(rule.endDate!);
  final out = <PlannedDose>[];

  // Bir gün geriden başla: önceki günün gece yarısını aşan dozları yakalar.
  var day = _day(from);
  day = DateTime(day.year, day.month, day.day - 1);
  // Başlangıçtan önceki günleri atla.
  if (day.isBefore(start)) day = start;

  for (; day.isBefore(to); day = DateTime(day.year, day.month, day.day + 1)) {
    if (end != null && day.isAfter(end)) break;
    // Takvim günü farkı (DST'de 24 saat varsayımı yapmamak için UTC'ye çevir).
    final diff = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(start.year, start.month, start.day)).inDays;
    if (diff % rule.everyNDays != 0) continue;
    if (!rule.weekdays.contains(day.weekday)) continue;

    for (final slot in rule.slots) {
      final at = _at(day, slot.minutesOn(meals));
      if (at.isBefore(from) || !at.isBefore(to)) continue;
      out.add(PlannedDose(medicationId: id, scheduledAt: at, food: slot.food));
    }
  }
  return out;
}

List<PlannedDose> _interval(
  int id,
  IntervalRule rule,
  DateTime from,
  DateTime to,
) {
  final start = _day(rule.startDate);
  final endExclusive = rule.endDate == null
      ? null
      : _at(_day(rule.endDate!), 24 * 60);
  final step = Duration(hours: rule.everyHours);
  final out = <PlannedDose>[];

  var at = _at(start, rule.firstMinutes);
  // Pencereye hızlıca yaklaş.
  if (at.isBefore(from)) {
    final skip = from.difference(at).inMinutes ~/ step.inMinutes;
    at = at.add(step * skip);
  }
  for (; at.isBefore(to); at = at.add(step)) {
    if (endExclusive != null && !at.isBefore(endExclusive)) break;
    if (at.isBefore(from)) continue;
    out.add(PlannedDose(medicationId: id, scheduledAt: at, food: rule.food));
  }
  return out;
}
