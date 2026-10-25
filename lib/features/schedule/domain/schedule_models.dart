/// Günün hangi referans noktasına göre doz saati hesaplanacağı.
enum TimingAnchor { fixed, wake, breakfast, lunch, dinner, bedtime }

/// Yemekle ilişki (aç/tok dahil).
enum FoodRelation { none, before, after, withMeal, emptyStomach, fullStomach }

/// Kullanıcının bir doz için yaptığı işlem. DB'de [name] olarak saklanır.
enum DoseStatus { taken, skipped }

/// Kullanıcının günlük yemek/uyku saatleri (gece yarısından itibaren dakika).
class MealTimes {
  const MealTimes({
    this.wake = 7 * 60,
    this.breakfast = 8 * 60,
    this.lunch = 13 * 60,
    this.dinner = 19 * 60,
    this.bedtime = 23 * 60,
  });

  final int wake;
  final int breakfast;
  final int lunch;
  final int dinner;
  final int bedtime;

  int minutesFor(TimingAnchor anchor) => switch (anchor) {
    TimingAnchor.wake => wake,
    TimingAnchor.breakfast => breakfast,
    TimingAnchor.lunch => lunch,
    TimingAnchor.dinner => dinner,
    TimingAnchor.bedtime => bedtime,
    TimingAnchor.fixed => throw ArgumentError('fixed has no meal time'),
  };

  MealTimes copyWith({
    int? wake,
    int? breakfast,
    int? lunch,
    int? dinner,
    int? bedtime,
  }) => MealTimes(
    wake: wake ?? this.wake,
    breakfast: breakfast ?? this.breakfast,
    lunch: lunch ?? this.lunch,
    dinner: dinner ?? this.dinner,
    bedtime: bedtime ?? this.bedtime,
  );
}

/// Günlük bir doz noktası. [anchor] fixed ise [fixedMinutes] kullanılır,
/// değilse yemek saati + [offsetMinutes] (negatif = önce).
class DoseSlot {
  const DoseSlot.fixed(int minutes, {this.food = FoodRelation.none})
    : anchor = TimingAnchor.fixed,
      fixedMinutes = minutes,
      offsetMinutes = 0;

  const DoseSlot.anchored(
    this.anchor, {
    this.offsetMinutes = 0,
    this.food = FoodRelation.none,
  }) : fixedMinutes = 0;

  final TimingAnchor anchor;
  final int fixedMinutes;
  final int offsetMinutes;
  final FoodRelation food;

  /// Gece yarısından itibaren dakika; gün sınırını aşabilir (ör. 24:30).
  int minutesOn(MealTimes meals) => anchor == TimingAnchor.fixed
      ? fixedMinutes
      : meals.minutesFor(anchor) + offsetMinutes;
}

sealed class ScheduleRule {
  const ScheduleRule({required this.startDate, this.endDate});

  /// Takvim günü olarak (saat kısmı yok sayılır).
  final DateTime startDate;

  /// Dahil son gün; null ise süresiz.
  final DateTime? endDate;
}

/// Günde N kez belirli noktalarda; haftanın günleri ve gün aralığı destekli.
class DailyRule extends ScheduleRule {
  const DailyRule({
    required super.startDate,
    super.endDate,
    required this.slots,
    this.weekdays = const {1, 2, 3, 4, 5, 6, 7},
    this.everyNDays = 1,
  });

  final List<DoseSlot> slots;

  /// DateTime.weekday değerleri (1 = Pazartesi).
  final Set<int> weekdays;
  final int everyNDays;
}

/// Her X saatte bir; ilk doz başlangıç gününde [firstMinutes]'te.
class IntervalRule extends ScheduleRule {
  const IntervalRule({
    required super.startDate,
    super.endDate,
    required this.everyHours,
    required this.firstMinutes,
    this.food = FoodRelation.none,
  });

  final int everyHours;
  final int firstMinutes;
  final FoodRelation food;
}

/// Gerektiğinde: planlı doz üretmez, yalnızca günlük üst sınır tutar.
class AsNeededRule extends ScheduleRule {
  const AsNeededRule({required super.startDate, super.endDate, this.maxPerDay});

  final int? maxPerDay;
}

class PlannedDose {
  const PlannedDose({
    required this.medicationId,
    required this.scheduledAt,
    required this.food,
  });

  final int medicationId;

  /// Yerel duvar saati.
  final DateTime scheduledAt;
  final FoodRelation food;

  @override
  bool operator ==(Object other) =>
      other is PlannedDose &&
      other.medicationId == medicationId &&
      other.scheduledAt == scheduledAt &&
      other.food == food;

  @override
  int get hashCode => Object.hash(medicationId, scheduledAt, food);

  @override
  String toString() => 'PlannedDose($medicationId, $scheduledAt, $food)';
}
