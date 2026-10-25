import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/notification_service.dart';
import '../core/settings_store.dart';
import 'providers.dart';
import 'theme.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/icon/icon.png',
                            width: 56,
                            height: 56,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Take a Pill',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'İlaçlarını\nunutma.',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(fontSize: 38, height: 1.1),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Saatini, dozunu ve yemekle ilişkisini bir kez gir. '
                      'Zamanı geldiğinde, istersen birkaç dakika önce, haber verelim.',
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: c.muted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Feature(
                      icon: Icons.notifications_none_rounded,
                      bg: c.accentSoft,
                      fg: c.onAccentSoft,
                      text:
                          'Hatırlatmalar için bildirim iznine ihtiyacımız var',
                    ),
                    _Feature(
                      icon: Icons.lock_outline_rounded,
                      bg: c.ok.withValues(alpha: 0.14),
                      fg: c.ok,
                      text: 'Tüm verilerin yalnızca bu cihazda kalır',
                    ),
                    _Feature(
                      icon: Icons.info_outline_rounded,
                      bg: c.warnSoft,
                      fg: c.warn,
                      text: 'Bir hatırlatıcıdır, tıbbi tavsiye vermez',
                    ),
                    const Spacer(),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: () async {
                          final db = ref.read(dbProvider);
                          await NotificationService.requestPermissions();
                          await db.setSetting(SettingKeys.onboarded, '1');
                          if (context.mounted) context.go('/');
                        },
                        child: const Text('Başla ve bildirimlere izin ver'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.text,
  });

  final IconData icon;
  final Color bg;
  final Color fg;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: context.c.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: fg, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
