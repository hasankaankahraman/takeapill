import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dexterous.com/flutter/local_notifications');
const _callChannel = MethodChannel('takeapill/call');

/// Bildirim eklentisinin Android tarafını taklit eder: çağrıları kaydeder,
/// planlanmış bildirimleri tutar.
class FakeNotifications {
  final calls = <MethodCall>[];
  final scheduled = <int, Map<Object?, Object?>>{};

  /// Android 14'te yeni kurulumun varsayılanı false'tur.
  bool exactAlarmsAllowed = true;

  /// Bildirim izni (Android 13+ POST_NOTIFICATIONS).
  bool notificationsEnabled = true;

  /// Android'de tam ekran alarmı engelleyen izin: null, 'miui' ya da 'system'.
  String? fullScreenState;

  /// Gerçek kanal gibi her yanıtın bir olay döngüsü sürmesini sağlar; sırasız
  /// çalışan iki senkron böylece iç içe geçebilir.
  Duration latency = Duration.zero;

  Iterable<String?> get titles =>
      scheduled.values.map((a) => a['title'] as String?);

  /// flutter test'te platform zaten Android'dir.
  void install() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    _installCallChannel();
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
            case 'areNotificationsEnabled':
              return notificationsEnabled;
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

  /// Alarm köprüsünün (MainActivity) taklidi. Yanıt verilmezse çağrı sahte
  /// zamanda hiç dönmez.
  void _installCallChannel() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_callChannel, (call) async {
          calls.add(call);
          return call.method == 'fullScreenState' ? fullScreenState : null;
        });
  }

  /// Kullanıcının bildirime ya da butonuna dokunmasını taklit eder.
  Future<void> respond({String? actionId, required String payload}) =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            _channel.name,
            _channel.codec.encodeMethodCall(
              MethodCall('didReceiveNotificationResponse', {
                'notificationId': 0,
                'actionId': actionId,
                'payload': payload,
                'notificationResponseType': actionId == null ? 0 : 1,
              }),
            ),
            (_) {},
          );

  void uninstall() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      ..setMockMethodCallHandler(_channel, null)
      ..setMockMethodCallHandler(_callChannel, null);
  }
}
