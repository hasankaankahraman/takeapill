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

/// Android'de alarmın kilit ekranında tam ekran açılması için gereken izinler.
/// Xiaomi/Redmi (MIUI) bunları varsayılan olarak kapalı tutar ve sistem
/// penceresi çıkarmaz; kullanıcı uygulama izinlerinden elle açmalıdır.
Future<void> askFullScreenAlarms(BuildContext context) async {
  final state = await NotificationService.fullScreenState();
  if (state == null || !context.mounted) return;
  final go = await confirmDialog(
    context,
    title: 'Tam ekran alarm',
    message: state == 'miui'
        ? 'Alarmın kilit ekranında tam ekran açılması için Take a Pill '
              'izinlerinde "Kilit ekranında göster" ve "Arka planda çalışırken '
              'açılır pencereleri göster" izinlerini aç. Aksi halde alarm yalnızca '
              'bildirim olarak gelir.'
        : 'Alarmın kilit ekranında tam ekran açılması için "Tam ekran '
              'bildirimleri" iznini aç.',
    confirm: 'Ayarları aç',
  );
  if (go == true) await NotificationService.openFullScreenSettings();
}
