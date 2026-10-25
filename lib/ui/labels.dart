import 'package:flutter/material.dart';

import '../features/schedule/domain/schedule_models.dart';

String fmtMinutes(int m) {
  final t = ((m % 1440) + 1440) % 1440;
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

String fmtTime(DateTime d) => fmtMinutes(d.hour * 60 + d.minute);

TimeOfDay toTimeOfDay(int m) => TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);

const weekdayShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

const formLabels = {
  'pill': 'Hap / tablet',
  'capsule': 'Kapsül',
  'syrup': 'Şurup',
  'drops': 'Damla',
  'injection': 'İğne',
  'cream': 'Krem / merhem',
  'inhaler': 'Solunum',
  'other': 'Diğer',
};

const anchorLabels = {
  TimingAnchor.fixed: 'Belirli saat',
  TimingAnchor.wake: 'Uyanınca',
  TimingAnchor.breakfast: 'Kahvaltı',
  TimingAnchor.lunch: 'Öğle yemeği',
  TimingAnchor.dinner: 'Akşam yemeği',
  TimingAnchor.bedtime: 'Yatmadan',
};

const foodLabels = {
  FoodRelation.none: 'Fark etmez',
  FoodRelation.before: 'Yemekten önce',
  FoodRelation.after: 'Yemekten sonra',
  FoodRelation.withMeal: 'Yemekle birlikte',
  FoodRelation.emptyStomach: 'Aç karnına',
  FoodRelation.fullStomach: 'Tok karnına',
};

String slotSummary(DoseSlot s, MealTimes meals) {
  final when = s.anchor == TimingAnchor.fixed
      ? fmtMinutes(s.fixedMinutes)
      : fmtMinutes(meals.minutesFor(s.anchor) + s.offsetMinutes);
  final food = s.food == FoodRelation.none ? '' : ' · ${foodLabels[s.food]}';
  return '$when$food';
}
