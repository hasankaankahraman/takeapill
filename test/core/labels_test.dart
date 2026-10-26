import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/core/labels.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

void main() {
  group('fmtMinutes', () {
    test('SS:dd biçimler', () {
      expect(fmtMinutes(0), '00:00');
      expect(fmtMinutes(8 * 60 + 5), '08:05');
      expect(fmtMinutes(23 * 60 + 59), '23:59');
    });

    test('gün taşmasını ve negatifi sarar', () {
      expect(fmtMinutes(24 * 60 + 30), '00:30');
      expect(fmtMinutes(-30), '23:30');
    });
  });

  test('fmtTime ve fmtDate', () {
    final d = DateTime(2026, 3, 4, 9, 7);
    expect(fmtTime(d), '09:07');
    expect(fmtDate(d), '04.03.2026');
  });

  test('etiket tabloları tüm değerleri kapsar', () {
    expect(anchorLabels.keys, containsAll(TimingAnchor.values));
    expect(foodLabels.keys, containsAll(FoodRelation.values));
    expect(weekdayShort, hasLength(7));
    expect(formShortLabels.keys, formLabels.keys);
  });

  test('foodNote: fark etmez boş, diğerleri etiket', () {
    expect(foodNote(FoodRelation.none), '');
    expect(foodNote(FoodRelation.after), 'Yemekten sonra');
  });
}
