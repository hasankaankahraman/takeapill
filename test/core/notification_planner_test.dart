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

  group('uygulamayı açma hatırlatması', () {
    final horizonEnd = now.add(const Duration(days: 14));

    test('sınır dozları kesince planın sonundan sonra kurulur', () {
      final doses = [
        for (var i = 0; i < 40; i++)
          (dose(1, DateTime(2026, 11, 2, 8).add(Duration(hours: i))), 'A'),
      ];
      final plan = planNotifications(doses: doses, now: now, limit: 10);
      expect(
        keepAliveAt(doses: doses, plan: plan, horizonEnd: horizonEnd),
        plan.last.at.add(const Duration(minutes: 1)),
      );
    });

    test('ilaç pencere sonuna kadar sürüyorsa kurulur', () {
      final doses = [
        (dose(1, DateTime(2026, 11, 2, 8)), 'A'),
        (dose(1, horizonEnd.subtract(const Duration(hours: 2))), 'A'),
      ];
      final plan = planNotifications(doses: doses, now: now);
      expect(
        keepAliveAt(doses: doses, plan: plan, horizonEnd: horizonEnd),
        plan.last.at.add(const Duration(minutes: 1)),
      );
    });

    test('tüm dozlar kapsanmışsa ve ilaç bitiyorsa kurulmaz', () {
      final doses = [(dose(1, DateTime(2026, 11, 3, 8)), 'A')];
      final plan = planNotifications(doses: doses, now: now);
      expect(
        keepAliveAt(doses: doses, plan: plan, horizonEnd: horizonEnd),
        isNull,
      );
      expect(
        keepAliveAt(doses: const [], plan: const [], horizonEnd: horizonEnd),
        isNull,
      );
    });
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

    final call = encodePayload(7, at, call: true);
    expect(decodePayload(call), (7, at));
    expect(isCallPayload(call), isTrue);
    expect(isCallPayload(encodePayload(7, at)), isFalse);
    expect(decodePayload('7|1|bozuk'), isNull);
  });

  test('arama modunda yalnızca doz saati ve erteleme arama olur', () {
    final d = dose(1, DateTime(2026, 11, 2, 8));
    const prefs = NotificationPrefs(callMode: true);
    final r = planNotifications(doses: [(d, 'A')], now: now, prefs: prefs);
    expect(
      {for (final n in r) n.kind: n.call},
      {NotifKind.lead: false, NotifKind.due: true, NotifKind.nag: false},
    );
    expect(isCallPayload(r[1].payload), isTrue);

    final snoozed = planNotifications(
      doses: [(d, 'A')],
      now: DateTime(2026, 11, 2, 8, 5),
      prefs: prefs,
      snoozes: {(1, d.scheduledAt): DateTime(2026, 11, 2, 8, 15)},
    );
    expect(snoozed.single.call, isTrue);
  });

  test('ertelenen doz yalnızca erteleme bildirimi alır', () {
    final d = dose(1, DateTime(2026, 11, 2, 8));
    final until = DateTime(2026, 11, 2, 8, 20);
    final r = planNotifications(
      doses: [(d, 'A')],
      now: DateTime(2026, 11, 2, 8, 5),
      snoozes: {(1, d.scheduledAt): until},
    );
    expect(r.single.kind, NotifKind.snooze);
    expect(r.single.at, until);
    expect(r.single.doseAt, d.scheduledAt);
  });

  test('süresi geçmiş erteleme normal plana döner', () {
    final d = dose(1, DateTime(2026, 11, 2, 8));
    final r = planNotifications(
      doses: [(d, 'A')],
      now: now,
      snoozes: {(1, d.scheduledAt): DateTime(2026, 11, 2, 6)},
    );
    expect(r.map((e) => e.kind), [
      NotifKind.lead,
      NotifKind.due,
      NotifKind.nag,
    ]);
  });
}
