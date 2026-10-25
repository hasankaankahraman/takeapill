import 'package:clock/clock.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/review.dart';
import 'package:takeapill/features/schedule/data/schedule_repository.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';

class _FakeReview implements InAppReview {
  int requests = 0;
  bool available = true;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> requestReview() async => requests++;

  @override
  Future<void> openStoreListing({
    String? appStoreId,
    String? microsoftStoreId,
  }) async {}
}

void main() {
  late AppDatabase db;
  late int id;

  final start = DateTime(2026, 11, 1);
  final now = DateTime(2026, 11, 3, 21);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    id = await db.addMedication(
      MedicationsCompanion.insert(name: 'Metformin'),
      encodeRule(
        DailyRule(
          startDate: start,
          slots: const [DoseSlot.fixed(8 * 60), DoseSlot.fixed(20 * 60)],
        ),
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> mark(int day, int hour, DoseStatus s) =>
      db.recordDose(id, DateTime(2026, 11, day, hour), s);

  Future<void> markAll({DoseStatus s = DoseStatus.taken}) async {
    for (final d in [1, 2, 3]) {
      await mark(d, 8, s);
      await mark(d, 20, s);
    }
  }

  Future<bool> due({DateTime? lastAskedAt, int askCount = 0}) async =>
      shouldRequestReview(
        views: await loadDoseViews(db, start, DateTime(2026, 11, 4)),
        now: now,
        lastAskedAt: lastAskedAt,
        askCount: askCount,
      );

  test('üç gün üst üste tüm dozlar işaretlenince sorulur', () async {
    await markAll();
    expect(await due(), isTrue);
  });

  test('bugünün dozu eksikse sorulmaz', () async {
    await markAll();
    await db.clearDose(id, DateTime(2026, 11, 3, 20));
    expect(await due(), isFalse);
  });

  test('aradaki bir gün eksikse sorulmaz', () async {
    await markAll();
    await db.clearDose(id, DateTime(2026, 11, 2, 8));
    expect(await due(), isFalse);
  });

  test('hepsi atlanan gün tam sayılmaz', () async {
    await markAll();
    await mark(2, 8, DoseStatus.skipped);
    expect(await due(), isTrue);
    await mark(2, 20, DoseStatus.skipped);
    expect(await due(), isFalse);
  });

  test('bekleme süresi ve üst sınır', () async {
    await markAll();
    expect(
      await due(lastAskedAt: now.subtract(const Duration(days: 30))),
      isFalse,
    );
    expect(await due(lastAskedAt: now.subtract(reviewCooldown)), isTrue);
    expect(await due(askCount: reviewMaxAsks), isFalse);
  });

  test('istek bir kez gösterilir, hemen tekrarlanmaz', () async {
    await markAll();
    final review = _FakeReview();
    await withClock(Clock.fixed(now), () async {
      await maybeRequestReview(db, review: review);
      await maybeRequestReview(db, review: review);
    });
    expect(review.requests, 1);
  });

  test('pencere desteklenmiyorsa hak harcanmaz', () async {
    await markAll();
    final review = _FakeReview()..available = false;
    await withClock(Clock.fixed(now), () async {
      await maybeRequestReview(db, review: review);
      review.available = true;
      await maybeRequestReview(db, review: review);
    });
    expect(review.requests, 1);
  });
}
