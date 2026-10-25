import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Karşılama sayfalarının vurgu renkleri; zemin ve görseller bunu paylaşır.
List<Color> onboardingTints(BuildContext context) {
  final c = context.c;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return [
    c.accent,
    dark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
    c.ok,
    c.accent,
  ];
}

/// Karşılama sayfasının üst görseli. Sayfa ilk açıldığında parçalar sırayla
/// yerine oturur, sonra sahne hafifçe nefes alır. "Hareketi azalt" açıksa
/// son hâli sabit gösterilir.
class OnboardingArt extends StatefulWidget {
  const OnboardingArt({super.key, required this.page, required this.active});

  final int page;
  final bool active;

  @override
  State<OnboardingArt> createState() => _OnboardingArtState();
}

class _OnboardingArtState extends State<OnboardingArt>
    with TickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(OnboardingArt old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    if (_still) {
      _enter.value = 1;
      _idle.value = 0;
      return;
    }
    if (!_idle.isAnimating) _idle.repeat();
    if (widget.active && _enter.isDismissed) _enter.forward();
  }

  @override
  void dispose() {
    _enter.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = onboardingTints(context)[widget.page];
    return ExcludeSemantics(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 400),
          child: FittedBox(
            child: AnimatedBuilder(
              animation: Listenable.merge([_enter, _idle]),
              builder: (context, _) {
                final k = _Clock(_enter.value, _idle.value);
                return SizedBox(
                  width: 320,
                  height: 300,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _Glow(color: tint, size: 280 * k.at(0, 0.6)),
                      switch (widget.page) {
                        0 => _PillScene(k: k, tint: tint),
                        1 => _ReminderScene(k: k, tint: tint),
                        2 => _ProgressScene(k: k, tint: tint),
                        _ => _PrivacyScene(k: k, tint: tint),
                      },
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Clock {
  const _Clock(this.enter, this.idle);

  final double enter;
  final double idle;

  /// Giriş animasyonunun [a, b] aralığındaki ilerlemesi.
  double at(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((enter - a) / (b - a)).clamp(0.0, 1.0));

  /// -1..1 arası yavaş dalga; [phase] tur cinsinden kaydırır.
  double wave([double phase = 0, int speed = 1]) =>
      math.sin((idle * speed + phase) * 2 * math.pi);
}

Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t)!;
Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t)!;

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

List<BoxShadow> _softShadow(BuildContext context) => [
  BoxShadow(
    color: Colors.black.withValues(alpha: _isDark(context) ? 0.4 : 0.08),
    blurRadius: 30,
    offset: const Offset(0, 14),
  ),
];

/// Parçanın aşağıdan süzülerek belirmesi; [t] easeOutBack ile 1'i aşabilir.
class _Pop extends StatelessWidget {
  const _Pop({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: t.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(0, 14 * (1 - t)),
      child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
    ),
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
      ),
    ),
  );
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.icon,
    required this.text,
    required this.tint,
  });

  final IconData icon;
  final String text;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 14, 8),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
        boxShadow: _softShadow(context),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 15, color: tint),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// --- 1. Hap -----------------------------------------------------------------

class _PillScene extends StatelessWidget {
  const _PillScene({required this.k, required this.tint});

  final _Clock k;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final float = (k.wave() + 1) / 2;
    final chips = [
      (Icons.schedule_rounded, '08:00', 66.0, true),
      (Icons.medication_rounded, '500 mg', 26.0, false),
      (Icons.restaurant_rounded, 'Tok karnına', 200.0, false),
    ];
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        for (var i = 0; i < 3; i++)
          Transform.scale(
            scale: k.at(0.05 * i, 0.6 + 0.05 * i) * (1 + 0.02 * k.wave(i / 3)),
            child: Container(
              width: 150.0 + 64 * i,
              height: 150.0 + 64 * i,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: tint.withValues(alpha: 0.18 - 0.05 * i),
                  width: 1.2,
                ),
              ),
            ),
          ),
        // Zemin gölgesi: hap yükseldikçe daralır ve soluklaşır.
        Positioned(
          top: 172,
          child: Opacity(
            opacity: k.at(0.25, 0.7) * (1 - 0.4 * float),
            child: Transform.scale(
              scaleX: 1 - 0.18 * float,
              scaleY: 0.14,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _darken(tint, 0.5).withValues(alpha: 0.32),
                      _darken(tint, 0.5).withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -4 - 12 * float),
          child: Transform.rotate(
            angle: -0.58 + 0.05 * k.wave(0.25) - 0.9 * (1 - k.at(0.1, 0.85)),
            child: Transform.scale(
              scale: k.at(0.1, 0.7, Curves.easeOutBack),
              child: _Capsule(color: tint),
            ),
          ),
        ),
        for (final (i, (icon, text, top, left)) in chips.indexed)
          Positioned(
            top: top,
            left: left ? 0 : null,
            right: left ? null : 0,
            child: Transform.translate(
              offset: Offset(0, 4 * k.wave(0.3 * i + 0.1)),
              child: _Pop(
                t: k.at(0.45 + 0.1 * i, 0.8 + 0.1 * i, Curves.easeOutBack),
                child: _GlassChip(icon: icon, text: text, tint: tint),
              ),
            ),
          ),
      ],
    );
  }
}

/// İki renkli, parlak kapsül.
class _Capsule extends StatelessWidget {
  const _Capsule({required this.color});

  final Color color;

  static const _w = 176.0, _h = 72.0;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(_h / 2);
    return Container(
      width: _w,
      height: _h,
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 34,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          _lighten(color, 0.35),
                          color,
                          _darken(color, 0.3),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                const Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFFFFF),
                          Color(0xFFEDEFF5),
                          Color(0xFFC3C8D6),
                        ],
                        stops: [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Ek yeri
            Center(
              child: Container(
                width: 2,
                color: Colors.black.withValues(alpha: 0.08),
              ),
            ),
            // Parlama
            Positioned(
              left: _h * 0.38,
              right: _h * 0.38,
              top: _h * 0.13,
              height: _h * 0.2,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_h),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0),
                      Colors.white.withValues(alpha: 0.75),
                      Colors.white.withValues(alpha: 0.75),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.25, 0.7, 1],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. Bildirim ------------------------------------------------------------

class _ReminderScene extends StatelessWidget {
  const _ReminderScene({required this.k, required this.tint});

  final _Clock k;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final back = k.at(0.0, 0.45);
    final front = k.at(0.15, 0.62);
    final bob = 3 * k.wave(0.5);
    // Zil her turun başında kısa bir süre sallanır.
    final ring = (k.idle / 0.22).clamp(0.0, 1.0);
    final swing = ring < 1
        ? math.sin(ring * 6 * math.pi) * 0.32 * (1 - ring)
        : 0.0;
    return Stack(
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      children: [
        // Arkada bekleyen bildirimler: yalnızca alt kenarları görünür.
        for (final (i, scale) in const [(2, 0.84), (1, 0.92)])
          Positioned(
            top: 96 + 12.0 * i * back + bob,
            child: Opacity(
              opacity: (0.75 - 0.25 * i) * back,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.bottomCenter,
                child: _NotifCard(
                  title: '',
                  body: '',
                  time: '',
                  tint: tint,
                  actions: 0,
                ),
              ),
            ),
          ),
        Positioned(
          top: 96 - 60 * (1 - front) + bob,
          child: Opacity(
            opacity: front,
            child: _NotifCard(
              title: 'İlaç zamanı: Metformin',
              body: '500 mg · Tok karnına',
              time: 'şimdi',
              tint: tint,
              actions: k.at(0.5, 0.85),
            ),
          ),
        ),
        Positioned(
          top: 12,
          child: Transform.scale(
            scale: k.at(0.4, 0.75, Curves.easeOutBack),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (ring < 1)
                  Container(
                    width: 58 + 40 * ring,
                    height: 58 + 40 * ring,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: tint.withValues(alpha: 0.45 * (1 - ring)),
                        width: 2,
                      ),
                    ),
                  ),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_lighten(tint, 0.25), _darken(tint, 0.15)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: tint.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: swing,
                    alignment: const Alignment(0, -0.6),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({
    required this.title,
    required this.body,
    required this.time,
    this.tint,
    this.actions,
  });

  final String title;
  final String body;
  final String time;
  final Color? tint;

  /// Eylem düğmelerinin görünürlüğü; null ise hiç yer ayrılmaz.
  final double? actions;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final a = actions;
    return Container(
      width: 284,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.line),
        boxShadow: _softShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/icon/icon.png',
                  width: 20,
                  height: 20,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TAKE A PILL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: c.muted,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: c.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.muted,
            ),
          ),
          if (a != null) ...[
            const SizedBox(height: 12),
            Opacity(
              opacity: a,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - a)),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionPill(
                        icon: Icons.check_rounded,
                        text: 'Aldım',
                        bg: tint ?? c.accent,
                        fg: _isDark(context) ? c.bg : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ActionPill(
                        icon: Icons.snooze_rounded,
                        text: 'Ertele',
                        bg: c.chip,
                        fg: c.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ],
    ),
  );
}

// --- 3. İlerleme ------------------------------------------------------------

class _ProgressScene extends StatelessWidget {
  const _ProgressScene({required this.k, required this.tint});

  final _Clock k;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ticks = [
      k.at(0.45, 0.62, Curves.easeOutBack),
      k.at(0.62, 0.79, Curves.easeOutBack),
      0.0,
    ];
    final done = ticks.where((t) => t >= 0.5).length;
    final progress = (k.at(0.45, 0.7) + k.at(0.62, 0.87)) / 3;
    final rows = [
      ('08:00', 'Metformin', '500 mg · Tok karnına'),
      ('13:00', 'Omega 3', '1 kapsül'),
      ('21:00', 'D vitamini', '1000 IU'),
    ];
    final card = k.at(0, 0.4);
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Transform.translate(
          offset: Offset(0, 24 * (1 - card) + 3 * k.wave()),
          child: Opacity(
            opacity: card,
            child: Container(
              width: 284,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.line),
                boxShadow: _softShadow(context),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 64,
                        height: 64,
                        child: CustomPaint(
                          painter: _RingPainter(
                            value: progress,
                            color: tint,
                            track: c.chip,
                          ),
                          child: Center(
                            child: Text(
                              '$done/3',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Güzel gidiyorsun',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$done / 3 doz tamamlandı',
                              style: TextStyle(fontSize: 12, color: c.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (final (i, (time, name, detail)) in rows.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                      child: _Pop(
                        t: k.at(0.1 + 0.07 * i, 0.45 + 0.07 * i),
                        child: _DoseLine(
                          time: time,
                          name: name,
                          detail: detail,
                          done: ticks[i],
                          tint: tint,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: -14,
          right: -10,
          child: Transform.translate(
            offset: Offset(0, 4 * k.wave(0.4)),
            child: _Pop(
              t: k.at(0.8, 1, Curves.easeOutBack),
              child: _GlassChip(
                icon: Icons.trending_up_rounded,
                text: '%92 uyum',
                tint: tint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine({
    required this.time,
    required this.name,
    required this.detail,
    required this.done,
    required this.tint,
  });

  final String time;
  final String name;
  final String detail;
  final double done;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: c.muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(detail, style: TextStyle(fontSize: 11, color: c.muted)),
              ],
            ),
          ),
          SizedBox(
            width: 26,
            height: 26,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.line, width: 2),
                  ),
                ),
                Transform.scale(
                  scale: done,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tint,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: _isDark(context) ? c.bg : Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});

  final double value;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, base..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

// --- 4. Gizlilik ------------------------------------------------------------

class _PrivacyScene extends StatelessWidget {
  const _PrivacyScene({required this.k, required this.tint});

  final _Clock k;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shield = k.at(0, 0.55, Curves.easeOutBack);
    final chips = [
      (Icons.phone_iphone_rounded, 'Bu cihazda kalır', 22.0, true),
      (Icons.notifications_none_rounded, 'Zamanında haber', 226.0, false),
    ];
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Kalkandan dışa yayılan halkalar
        for (var i = 0; i < 3; i++)
          Builder(
            builder: (context) {
              final r = (k.idle * 2 + i / 3) % 1.0;
              return Container(
                width: 120 + 160 * r,
                height: 120 + 160 * r,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tint.withValues(
                      alpha: 0.3 * (1 - r) * k.at(0.3, 0.8),
                    ),
                    width: 1.5,
                  ),
                ),
              );
            },
          ),
        Transform.translate(
          offset: Offset(0, 5 * k.wave()),
          child: Transform.scale(
            scale: shield,
            child: SizedBox(
              width: 124,
              height: 144,
              child: CustomPaint(
                painter: _ShieldPainter(tint),
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Icon(
                    Icons.lock_rounded,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 194,
          top: 74,
          child: Transform.translate(
            offset: Offset(0, 5 * k.wave()),
            child: Transform.scale(
              scale: k.at(0.45, 0.75, Curves.easeOutBack),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.ok,
                  border: Border.all(color: c.surface, width: 3),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 22,
                  color: _isDark(context) ? c.bg : Colors.white,
                ),
              ),
            ),
          ),
        ),
        for (final (i, (icon, text, top, left)) in chips.indexed)
          Positioned(
            top: top,
            left: left ? -4 : null,
            right: left ? null : -4,
            child: Transform.translate(
              offset: Offset(0, 4 * k.wave(0.35 * i + 0.2)),
              child: _Pop(
                t: k.at(0.55 + 0.12 * i, 0.88 + 0.12 * i, Curves.easeOutBack),
                child: _GlassChip(icon: icon, text: text, tint: tint),
              ),
            ),
          ),
      ],
    );
  }
}

class _ShieldPainter extends CustomPainter {
  _ShieldPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.7, h * 0.1, w * 0.86, h * 0.12, w, h * 0.14)
      ..lineTo(w, h * 0.46)
      ..cubicTo(w, h * 0.74, w * 0.74, h * 0.9, w / 2, h)
      ..cubicTo(w * 0.26, h * 0.9, 0, h * 0.74, 0, h * 0.46)
      ..lineTo(0, h * 0.14)
      ..cubicTo(w * 0.14, h * 0.12, w * 0.3, h * 0.1, w / 2, 0)
      ..close();

    canvas.drawPath(
      path.shift(const Offset(0, 14)),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_lighten(color, 0.3), _darken(color, 0.2)],
        ).createShader(Offset.zero & size),
    );
    // Sol üstte yumuşak parlama
    canvas.save();
    canvas.clipPath(path);
    canvas.drawOval(
      Rect.fromLTWH(-w * 0.3, -h * 0.35, w * 0.95, h * 0.75),
      Paint()..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShieldPainter old) => old.color != color;
}
