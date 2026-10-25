import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/db/app_database.dart';
import 'core/notifications/notification_service.dart';
import 'core/settings_store.dart';
import 'ui/providers.dart';

/// Uygulamanın kök widget'ını hazırlar. Test, [db] vererek bellek içi DB kullanır.
Future<Widget> bootstrap({AppDatabase? db}) async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');

  final database = db ?? AppDatabase();
  await NotificationService.init(database);
  final onboarded = await database.getSetting(SettingKeys.onboarded) != null;
  if (onboarded) await syncNotifications(database);

  return ProviderScope(
    overrides: [dbProvider.overrideWithValue(database)],
    child: TakeAPillApp(router: buildRouter(onboarded: onboarded)),
  );
}
