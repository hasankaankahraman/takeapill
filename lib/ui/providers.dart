import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/db/app_database.dart';
import '../core/notifications/notification_service.dart';
import '../core/settings_store.dart';
import '../features/schedule/data/schedule_repository.dart';

final dbProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('dbProvider main()de override edilmeli'),
);

typedef DayRange = (DateTime, DateTime);

/// [from, to) aralığındaki dozlar; veri değiştikçe kendiliğinden güncellenir.
final doseViewsProvider = StreamProvider.autoDispose
    .family<List<DoseView>, DayRange>((ref, r) {
      final db = ref.watch(dbProvider);
      return db.watchAnyChange().asyncMap((_) => loadDoseViews(db, r.$1, r.$2));
    });

final medicationsProvider = StreamProvider.autoDispose<List<Medication>>(
  (ref) => ref.watch(dbProvider).watchMedications(),
);

/// Dozu alındı/atlandı olarak işaretler; null verilirse işareti geri alır.
Future<void> markDose(AppDatabase db, DoseView v, String? status) async {
  if (status == null) {
    await db.clearDose(v.dose.medicationId, v.dose.scheduledAt);
  } else {
    await db.recordDose(v.dose.medicationId, v.dose.scheduledAt, status);
  }
  await syncNotifications(db);
}

/// Tema tercihi (sistem / açık / koyu); Settings tablosunda saklanır.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final v = await ref.read(dbProvider).getSetting(SettingKeys.themeMode);
    final mode = ThemeMode.values.where((m) => m.name == v).firstOrNull;
    if (mode != null) state = mode;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(dbProvider).setSetting(SettingKeys.themeMode, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
