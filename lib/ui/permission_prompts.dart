import 'package:flutter/material.dart';

import '../core/notifications/notification_service.dart';
import 'widgets.dart';

/// Android 12+: "Alarmlar ve hatırlatıcılar" izni kapalıysa kullanıcıyı sistem
/// ayarlarına göndermeden önce nedenini anlatır. iOS'ta izin gerekmez.
Future<void> askExactAlarms(BuildContext context) async {
  if (await NotificationService.exactAlarmsAllowed() || !context.mounted) {
    return;
  }
  final go = await confirmDialog(
    context,
    title: 'Tam saatinde hatırlatma',
    message:
        'Hatırlatmaların gecikmeden gelmesi için "Alarmlar ve hatırlatıcılar" '
        'izni gerekiyor. Açılan ekranda Take a Pill için izni aç ve geri dön.',
    confirm: 'Ayarları aç',
  );
  if (go == true) await NotificationService.requestExactAlarms();
}
