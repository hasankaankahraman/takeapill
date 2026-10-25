import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

import '../features/schedule/data/schedule_repository.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'db/app_database.dart';
import 'settings_store.dart';

/// App Store Connect'teki sayısal uygulama kimliği (Apple ID). Boşken iOS'ta
/// Ayarlar'daki "Uygulamayı değerlendir" satırı gizlenir.
const appStoreId = '';

/// Ardışık kaç "tam gün" sonra puan istenir (bugün dahil).
const reviewStreakDays = 3;

/// İki istek arası en az süre ve toplam üst sınır. Sistem de kendi sınırını
/// uygular (iOS: yılda 3); bunlar onu boşa harcamamak için.
const reviewCooldown = Duration(days: 120);
const reviewMaxAsks = 3;

/// Saf karar. [views]: son [reviewStreakDays] günün dozları. Her gün en az
/// bir planlı doz olmalı, hepsi işaretlenmiş ve en az biri alınmış olmalı;
/// böylece istek ancak bugünün son dozu işaretlendiğinde gelir.
bool shouldRequestReview({
  required List<DoseView> views,
  required DateTime now,
  DateTime? lastAskedAt,
  int askCount = 0,
}) {
  if (askCount >= reviewMaxAsks) return false;
  if (lastAskedAt != null && now.difference(lastAskedAt) < reviewCooldown) {
    return false;
  }
  for (var i = 0; i < reviewStreakDays; i++) {
    final day = DateTime(now.year, now.month, now.day - i);
    final doses = views.where((v) {
      final at = v.dose.scheduledAt;
      return at.year == day.year && at.month == day.month && at.day == day.day;
    });
    if (doses.isEmpty ||
        doses.any((v) => v.status == null) ||
        !doses.any((v) => v.status == DoseStatus.taken)) {
      return false;
    }
  }
  return true;
}

/// Bir doz "alındı" işaretlendikten sonra çağrılır; koşullar uygunsa sistemin
/// puanlama penceresini açar. Hatalar yutulur: puan isteği asla akışı bozmaz.
Future<void> maybeRequestReview(AppDatabase db, {InAppReview? review}) async {
  try {
    final now = clock.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = DateTime(
      today.year,
      today.month,
      today.day - reviewStreakDays + 1,
    );
    final askedMs = int.tryParse(
      await db.getSetting(SettingKeys.reviewAskedAt) ?? '',
    );
    final count =
        int.tryParse(await db.getSetting(SettingKeys.reviewAskCount) ?? '') ??
        0;
    final due = shouldRequestReview(
      views: await loadDoseViews(
        db,
        from,
        DateTime(today.year, today.month, today.day + 1),
      ),
      now: now,
      lastAskedAt: askedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(askedMs),
      askCount: count,
    );
    if (!due) return;

    final r = review ?? InAppReview.instance;
    if (!await r.isAvailable()) return;
    // Pencere gösterilmese bile sayılır; tekrar tekrar denenmesin.
    await db.setSetting(
      SettingKeys.reviewAskedAt,
      '${now.millisecondsSinceEpoch}',
    );
    await db.setSetting(SettingKeys.reviewAskCount, '${count + 1}');
    // "Bugünlük tamam" özeti görünsün, pencere ardından gelsin.
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await r.requestReview();
  } catch (e) {
    debugPrint('Puan isteği gösterilemedi: $e');
  }
}

/// Ayarlar'daki satır için: kullanıcı kendisi istediğinde mağaza sayfası.
bool get canOpenStoreListing =>
    defaultTargetPlatform != TargetPlatform.iOS || appStoreId.isNotEmpty;

Future<void> openStoreListing() =>
    InAppReview.instance.openStoreListing(appStoreId: appStoreId);
