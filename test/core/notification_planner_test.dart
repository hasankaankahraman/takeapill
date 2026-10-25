import 'package:flutter_test/flutter_test.dart';
import 'package:takeapill/core/notifications/notification_planner.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

PlannedDose dose(int med, DateTime at) =>
    PlannedDose(medicationId: med, scheduledAt: at, food: FoodRelation.none);

void main() {
  final now = DateTime(2026, 11, 2, 7, 0);

  test('her doz için önce, tam zamanında ve tekrar bildirimi üretir', () {
    final d = dose(1, DateTime(2026, 11, 2, 8));
    final r = planNotifications(doses: [(d, 'A')], now: now);
    expect(r.map((e) => e.kind), [
      NotifKind.lead,
      NotifKind.due,
      NotifKind.nag,
    ]);
    expect(r[0].at, DateTime(2026, 11, 2, 7, 55));
    expect(r[2].at, DateTime(2026, 11, 2, 8, 10));
  });

  test('geçmişteki bildirimler atlanır', () {
    final d = dose(1, DateTime(2026, 11, 2, 7, 3));
    final r = planNotifications(doses: [(d, 'A')], now: now);
    // lead (06:58) geçmişte; due ve nag kalır.
    expect(r.map((e) => e.kind), [NotifKind.due, NotifKind.nag]);
  });

  test('lead ve nag kapatılabilir', () {
    final d = dose(1, DateTime(2026, 11, 2, 8));
    final r = planNotifications(
      doses: [(d, 'A')],
      now: now,
      prefs: const NotificationPrefs(leadMinutes: 0, nagMinutes: 0),
    );
    expect(r.map((e) => e.kind), [NotifKind.due]);
  });

  test('limit: en yakın bildirimler seçilir, sıralı gelir', () {
    final doses = [
      for (var i = 0; i < 40; i++)
        (dose(1, DateTime(2026, 11, 2, 8).add(Duration(hours: i))), 'A'),
    ];
    final r = planNotifications(doses: doses, now: now, limit: 64);
    expect(r.length, 64);
    for (var i = 1; i < r.length; i++) {
      expect(r[i].at.isBefore(r[i - 1].at), isFalse);
    }
    expect(r.first.at, DateTime(2026, 11, 2, 7, 55));
  });

  test('kimlik kararlı, farklı doz/tür için farklı', () {
    final at = DateTime(2026, 11, 2, 8);
    expect(
      notificationId(1, at, NotifKind.due),
      notificationId(1, at, NotifKind.due),
    );
    expect(
      notificationId(1, at, NotifKind.due),
      isNot(notificationId(1, at, NotifKind.nag)),
    );
    expect(
      notificationId(1, at, NotifKind.due),
      isNot(notificationId(2, at, NotifKind.due)),
    );
    expect(notificationId(1, at, NotifKind.due), lessThan(0x80000000));
  });

  test('payload gidiş-dönüş', () {
    final at = DateTime(2026, 11, 2, 8);
    expect(decodePayload(encodePayload(7, at)), (7, at));
    expect(decodePayload('bozuk'), isNull);
    expect(decodePayload(null), isNull);
  });
}
