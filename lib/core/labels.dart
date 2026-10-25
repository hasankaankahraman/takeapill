import '../features/schedule/domain/schedule_models.dart';

/// Gece yarısından itibaren dakikayı "SS:dd" yazar; gün taşmasını sarar.
String fmtMinutes(int m) {
  final t = ((m % 1440) + 1440) % 1440;
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

String fmtTime(DateTime d) => fmtMinutes(d.hour * 60 + d.minute);

String fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

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

/// Doz satırlarında gösterilen yemek notu; "fark etmez" ise boş.
String foodNote(FoodRelation f) => f == FoodRelation.none ? '' : foodLabels[f]!;
