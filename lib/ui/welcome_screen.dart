import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/notification_service.dart';
import '../core/settings_store.dart';
import 'onboarding_art.dart';
import 'providers.dart';
import 'theme.dart';

/// Kaydırmalı karşılama: üç tanıtım sayfası, hatırlatma şekli seçimi ve izin
/// istenen son sayfa.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _count = 5;

  final _pages = PageController();
  int _index = 0;

  /// Hatırlatma şekli; isteğe bağlı, Ayarlar'dan değiştirilebilir.
  bool _call = false;

  bool get _last => _index == _count - 1;

  double get _page => _pages.hasClients && _pages.position.haveDimensions
      ? _pages.page!
      : _index.toDouble();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(i);
    } else {
      _pages.animateToPage(
        i,
        duration: const Duration(milliseconds: 560),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _start() async {
    final db = ref.read(dbProvider);
    final prefs = await db.loadNotificationPrefs();
    await db.saveNotificationPrefs(prefs.copyWith(call: _call));
    final ok = await NotificationService.requestPermissions();
    if (ok && _call) await NotificationService.requestCallPermission();
    await db.setSetting(SettingKeys.onboarded, '1');
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tints = onboardingTints(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final slides = [
      const _SlideText(
        title: 'İlaçlarını unutma.',
        body:
            'Saatini, dozunu ve yemekle ilişkisini bir kez gir; '
            'gerisini biz hatırlayalım.',
      ),
      const _SlideText(
        title: 'Tam zamanında haber verelim.',
        body:
            'İstersen birkaç dakika önce, zamanı gelince ve aldın mı diye '
            'bir kez daha. Bildirimden “Aldım” ya da “Ertele” de.',
      ),
      const _SlideText(
        title: 'Gününü bir bakışta gör.',
        body:
            'Aldığın ve atladığın dozlar kaydolur; uyum oranını Geçmiş '
            'sekmesinden takip edersin.',
      ),
      _SlideText(
        title: 'Nasıl hatırlatalım?',
        body: 'İstediğin zaman Ayarlar’dan değiştirebilirsin.',
        footer: Column(
          children: [
            _ModeOption(
              icon: Icons.notifications_none_rounded,
              title: 'Bildirim',
              text: 'Bildirimden “Aldım” ya da “Ertele” de.',
              selected: !_call,
              onTap: () => setState(() => _call = false),
            ),
            _ModeOption(
              icon: Icons.call_rounded,
              title: 'Arama',
              text: 'Telefonun arama gibi çalar; kabul et ya da reddet.',
              selected: _call,
              onTap: () => setState(() => _call = true),
            ),
          ],
        ),
      ),
      _SlideText(
        title: 'Hazırsan başlayalım.',
        footer: Column(
          children: [
            _Feature(
              icon: Icons.notifications_none_rounded,
              bg: c.accentSoft,
              fg: c.onAccentSoft,
              text: 'Hatırlatmalar için bildirim iznine ihtiyacımız var',
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
          ],
        ),
      ),
    ];

    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _go(_index - 1);
      },
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _pages,
          builder: (context, child) => CustomPaint(
            painter: _Backdrop(page: _page, tints: tints, dark: dark),
            child: child,
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 12, 0),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.asset(
                          'assets/icon/icon.png',
                          width: 36,
                          height: 36,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Take a Pill',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      AnimatedOpacity(
                        opacity: _last ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: IgnorePointer(
                          ignoring: _last,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: c.muted,
                            ),
                            onPressed: () => _go(_count - 1),
                            child: const Text('Atla'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _count,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) => AnimatedBuilder(
                      animation: _pages,
                      builder: (context, _) => _Slide(
                        delta: _page - i,
                        art: OnboardingArt(page: i, active: i == _index),
                        text: slides[i],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Column(
                    children: [
                      Semantics(
                        label: 'Sayfa ${_index + 1} / $_count',
                        child: ExcludeSemantics(
                          child: AnimatedBuilder(
                            animation: _pages,
                            builder: (context, _) =>
                                _Dots(page: _page, count: _count),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _last ? _start : () => _go(_index + 1),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _last
                                ? const Text(
                                    'Başla ve bildirimlere izin ver',
                                    key: ValueKey('start'),
                                  )
                                : const Row(
                                    key: ValueKey('next'),
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('Devam'),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek sayfa. [delta], sayfanın ekrandaki konumundan ne kadar uzakta olduğu;
/// görsel metinden yavaş kayarak derinlik hissi verir.
class _Slide extends StatelessWidget {
  const _Slide({required this.delta, required this.art, required this.text});

  final double delta;
  final Widget art;
  final Widget text;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final a = delta.abs().clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Expanded(
            child: Transform.translate(
              offset: Offset(delta * w * 0.45, 0),
              child: Opacity(
                opacity: (1 - a * 1.4).clamp(0.0, 1.0),
                child: Transform.scale(scale: 1 - 0.12 * a, child: art),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Transform.translate(
            offset: Offset(delta * w * 0.15, 0),
            child: Opacity(opacity: 1 - a, child: text),
          ),
        ],
      ),
    );
  }
}

class _SlideText extends StatelessWidget {
  const _SlideText({required this.title, this.body, this.footer});

  final String title;
  final String? body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontSize: 30, height: 1.12),
        ),
        if (body case final body?) ...[
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(fontSize: 16, height: 1.5, color: context.c.muted),
          ),
        ],
        if (footer case final footer?) ...[const SizedBox(height: 16), footer],
      ],
    ),
  );
}

class _Dots extends StatelessWidget {
  const _Dots({required this.page, required this.count});

  final double page;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Builder(
            builder: (context) {
              final k = (1 - (page - i).abs()).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 8 + 18 * k,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Color.lerp(
                    c.muted.withValues(alpha: 0.25),
                    c.accent,
                    k,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Sayfa kaydıkça rengi ve yeri değişen iki yumuşak ışık lekesi.
class _Backdrop extends CustomPainter {
  _Backdrop({required this.page, required this.tints, required this.dark});

  final double page;
  final List<Color> tints;
  final bool dark;

  Color _tint(double p) {
    final q = p.clamp(0.0, tints.length - 1.0);
    final i = q.floor();
    final j = (i + 1).clamp(0, tints.length - 1);
    return Color.lerp(tints[i], tints[j], q - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final a = dark ? 0.2 : 0.14;

    void blob(Offset o, double r, Color color) {
      canvas.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(colors: [color, color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: o, radius: r)),
      );
    }

    blob(
      Offset(w * (0.9 - 0.1 * page), h * 0.16),
      w * 0.85,
      _tint(page).withValues(alpha: a),
    );
    blob(
      Offset(w * (0.05 + 0.08 * page), h * 0.5),
      w * 0.7,
      _tint(page + 0.5).withValues(alpha: a * 0.7),
    );
  }

  @override
  bool shouldRepaint(_Backdrop old) =>
      old.page != page || old.dark != dark || !listEquals(old.tints, tints);
}

/// Hatırlatma şekli seçeneği; seçili olan vurgu rengiyle çerçevelenir.
class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.icon,
    required this.title,
    required this.text,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final r = BorderRadius.circular(18);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        selected: selected,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: r,
            side: BorderSide(color: selected ? c.accent : c.surface, width: 2),
          ),
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected ? c.accentSoft : c.chip,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: selected ? c.onAccentSoft : c.muted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.35,
                            color: c.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: selected ? c.accent : c.line,
                  ),
                ],
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
