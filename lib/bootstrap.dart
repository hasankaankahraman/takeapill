import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings_store.dart';
import 'ui/providers.dart';

/// Uygulamanın kök widget'ını hazırlar. Test, [db] vererek bellek içi DB kullanır.
Future<Widget> bootstrap({AppDatabase? db}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  // Yalnızca dikey; iOS'ta Info.plist de aynı kısıtı taşır.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Liquid glass yalnızca iOS'ta; Android'de alt menü düz bulanık şerit.
  final glass = defaultTargetPlatform == TargetPlatform.iOS;
  if (glass) {
    await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  } else {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  final database = db ?? AppDatabase();
  await NotificationService.init(database);
  final onboarded = await database.getSetting(SettingKeys.onboarded) != null;
  final theme = parseThemeMode(
    await database.getSetting(SettingKeys.themeMode),
  );
  final userName = await database.loadUserName();
  if (onboarded) {
    // Kapalıyken iOS alarmında basılan "Ertele"ler planlanmadan önce uygulansın;
    // "Aç" için ek iş yok, uygulama zaten Bugün'de açılır.
    await NotificationService.applyAlarmActions(database);
    // Plan yenilenemese de uygulama açılmalı; bir sonraki açılışta tekrar denenir.
    await trySyncNotifications(database);
  }

  final app = TakeAPillApp(router: buildRouter(onboarded: onboarded));
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(database),
      initialThemeModeProvider.overrideWithValue(theme),
      initialUserNameProvider.overrideWithValue(userName),
    ],
    child: glass
        ? LiquidGlassWidgets.wrap(
            // Uygulamadaki tema seçimi (Açık/Koyu) cama da yansısın.
            brightnessResolver: Theme.maybeBrightnessOf,
            child: app,
          )
        : app,
  );
}
