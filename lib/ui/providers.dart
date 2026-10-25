import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../core/settings_store.dart';
import '../features/schedule/data/schedule_repository.dart';
import '../features/schedule/domain/schedule_models.dart';

final dbProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('dbProvider main()de override edilmeli'),
);

/// Şu an; dakika başlarında yenilenir. "Gecikti" etiketleri ve gece yarısı
/// gün geçişi uygulama açık dururken de kendiliğinden güncellenir.
final nowProvider = NotifierProvider.autoDispose<NowNotifier, DateTime>(
  NowNotifier.new,
);

class NowNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    ref.onDispose(() => _timer?.cancel());
    final now = clock.now();
    _timer = Timer(Duration(seconds: 60 - now.second), ref.invalidateSelf);
    return now;
  }
}

typedef DayRange = (DateTime, DateTime);

/// [from, to) aralığındaki dozlar; veri değiştikçe kendiliğinden güncellenir.
final doseViewsProvider = StreamProvider.autoDispose
    .family<List<DoseView>, DayRange>((ref, r) {
      final db = ref.watch(dbProvider);
      return db.watchAnyChange().asyncMap((_) => loadDoseViews(db, r.$1, r.$2));
    });

/// Aktif ilaçlar, kuralları ve yemek saatleri (saatleri göstermek için).
final medicationPlansProvider =
    StreamProvider.autoDispose<(List<MedicationPlan>, MealTimes)>((ref) {
      final db = ref.watch(dbProvider);
      return db.watchAnyChange().asyncMap(
        (_) async => (await loadMedicationPlans(db), await db.loadMealTimes()),
      );
    });

/// Dozu alındı/atlandı olarak işaretler; null verilirse işareti geri alır.
Future<void> markDose(AppDatabase db, DoseView v, DoseStatus? status) async {
  if (status == null) {
    await db.clearDose(v.dose.medicationId, v.dose.scheduledAt);
  } else {
    await db.recordDose(v.dose.medicationId, v.dose.scheduledAt, status);
  }
  await syncNotifications(db);
}

ThemeMode parseThemeMode(String? name) =>
    ThemeMode.values.where((m) => m.name == name).firstOrNull ??
    ThemeMode.system;

/// Açılışta DB'den okunan tema; ilk karede yanlış tema yanıp sönmesin diye
/// bootstrap'ta verilir.
final initialThemeModeProvider = Provider<ThemeMode>((_) => ThemeMode.system);

/// Tema tercihi (sistem / açık / koyu); Settings tablosunda saklanır.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.read(initialThemeModeProvider);

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(dbProvider).setSetting(SettingKeys.themeMode, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
