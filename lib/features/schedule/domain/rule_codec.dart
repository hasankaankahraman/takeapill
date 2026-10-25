import 'dart:convert';

import 'schedule_models.dart';

/// Kuralları tek bir JSON kolonunda saklamak için dönüştürücü.
/// Yeni kural tipi eklemek DB göçü gerektirmez.
String encodeRule(ScheduleRule rule) => jsonEncode(_toMap(rule));

ScheduleRule decodeRule(String source) =>
    _fromMap(jsonDecode(source) as Map<String, dynamic>);

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime _parseDate(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

Map<String, dynamic> _toMap(ScheduleRule rule) {
  final base = <String, dynamic>{
    'start': _date(rule.startDate),
    if (rule.endDate != null) 'end': _date(rule.endDate!),
  };
  return switch (rule) {
    DailyRule() => {
      ...base,
      'type': 'daily',
      'weekdays': (rule.weekdays.toList()..sort()),
      'everyNDays': rule.everyNDays,
      'slots': [
        for (final s in rule.slots)
          {
            'anchor': s.anchor.name,
            'fixed': s.fixedMinutes,
            'offset': s.offsetMinutes,
            'food': s.food.name,
          },
      ],
    },
    IntervalRule() => {
      ...base,
      'type': 'interval',
      'everyHours': rule.everyHours,
      'first': rule.firstMinutes,
      'food': rule.food.name,
    },
    AsNeededRule() => {
      ...base,
      'type': 'asNeeded',
      if (rule.maxPerDay != null) 'maxPerDay': rule.maxPerDay,
    },
  };
}

ScheduleRule _fromMap(Map<String, dynamic> m) {
  final start = _parseDate(m['start'] as String);
  final end = m['end'] == null ? null : _parseDate(m['end'] as String);
  switch (m['type']) {
    case 'daily':
      return DailyRule(
        startDate: start,
        endDate: end,
        weekdays: (m['weekdays'] as List).cast<int>().toSet(),
        everyNDays: m['everyNDays'] as int,
        slots: [
          for (final s in (m['slots'] as List).cast<Map<String, dynamic>>())
            _slot(s),
        ],
      );
    case 'interval':
      return IntervalRule(
        startDate: start,
        endDate: end,
        everyHours: m['everyHours'] as int,
        firstMinutes: m['first'] as int,
        food: FoodRelation.values.byName(m['food'] as String),
      );
    case 'asNeeded':
      return AsNeededRule(
        startDate: start,
        endDate: end,
        maxPerDay: m['maxPerDay'] as int?,
      );
  }
  throw FormatException('Bilinmeyen kural tipi: ${m['type']}');
}

DoseSlot _slot(Map<String, dynamic> s) {
  final anchor = TimingAnchor.values.byName(s['anchor'] as String);
  final food = FoodRelation.values.byName(s['food'] as String);
  return anchor == TimingAnchor.fixed
      ? DoseSlot.fixed(s['fixed'] as int, food: food)
      : DoseSlot.anchored(
          anchor,
          offsetMinutes: s['offset'] as int,
          food: food,
        );
}
