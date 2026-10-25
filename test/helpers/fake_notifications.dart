import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');

/// Bildirim eklentisinin Android tarafını taklit eder: çağrıları kaydeder,
/// planlanmış bildirimleri tutar.
class FakeNotifications {
  final calls = <MethodCall>[];
  final scheduled = <int, Map<Object?, Object?>>{};

  /// Android 14'te yeni kurulumun varsayılanı false'tur.
  bool exactAlarmsAllowed = true;

  /// Gerçek kanal gibi her yanıtın bir olay döngüsü sürmesini sağlar; sırasız
  /// çalışan iki senkron böylece iç içe geçebilir.
  Duration latency = Duration.zero;

  Iterable<String?> get titles =>
      scheduled.values.map((a) => a['title'] as String?);

  /// flutter test'te platform zaten Android'dir.
  void install() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          calls.add(call);
          if (latency > Duration.zero) await Future<void>.delayed(latency);
          switch (call.method) {
            case 'cancelAll':
              scheduled.clear();
            case 'zonedSchedule':
              final args = call.arguments as Map<Object?, Object?>;
              scheduled[args['id'] as int] = args;
            case 'canScheduleExactNotifications':
              return exactAlarmsAllowed;
            case 'initialize' ||
                'requestNotificationsPermission' ||
                'requestExactAlarmsPermission':
              return true;
            case 'pendingNotificationRequests' || 'getActiveNotifications':
              return <Object?>[];
          }
          return null;
        });
  }

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}
