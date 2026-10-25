import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Ekran görüntülerini Flutter yüzeyinden değil, simülatörün tamamından
/// (durum çubuğu ve sistem bildirimleri dahil) alır.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final dir = Platform.environment['SHOT_DIR'] ?? '.';
    final r = await Process.run('xcrun', [
      'simctl',
      'io',
      'booted',
      'screenshot',
      '$dir/$name.png',
    ]);
    return r.exitCode == 0;
  },
);
