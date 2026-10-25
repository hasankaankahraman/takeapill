import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Karşılama sahnesi: kutudan hap çıkar, bardak dolar (bir turda su, bir
/// turda şurup), içilir, karakter mutlu olur. Sonsuz döngü.
class PillStoryAnimation extends StatefulWidget {
  const PillStoryAnimation({super.key});

  @override
  State<PillStoryAnimation> createState() => _PillStoryState();
}

class _PillStoryState extends State<PillStoryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );
  int _loop = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _loop++);
        _c.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Hareketi azalt" açıksa son kareyi sabit göster.
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 0.9;
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final syrup = _loop.isOdd;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        final caption = switch (t) {
          < 0.22 => 'Zamanı gelince kutudan hapını çıkar',
          < 0.45 => syrup ? 'Şurubunu hazırla' : 'Bir bardak su doldur',
          < 0.66 => 'Afiyetle iç',
          _ => 'Geçmiş olsun, sağlıcakla kal!',
        };
        return Column(
          children: [
            AspectRatio(
              aspectRatio: 300 / 210,
              child: Semantics(
                label: 'Hap kutusundan çıkıp suyla içilen hap animasyonu',
                child: CustomPaint(
                  painter: _StoryPainter(
                    t: t,
                    syrup: syrup,
                    c: c,
                    dark: Theme.of(context).brightness == Brightness.dark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  caption,
                  key: ValueKey(caption),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: t >= 0.66 ? c.accent : c.ink,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _seg(double t, double a, double b) =>
    Curves.easeInOut.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _StoryPainter extends CustomPainter {
  _StoryPainter({
    required this.t,
    required this.syrup,
    required this.c,
    required this.dark,
  });

  final double t;
  final bool syrup;
  final AppColors c;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 300, size.height / 210);

    // Zemin gölgesi
    canvas.drawRRect(
      RRect.fromLTRBR(10, 182, 290, 190, const Radius.circular(4)),
      Paint()..color = c.ink.withValues(alpha: dark ? 0.12 : 0.05),
    );

    final lid = _seg(t, 0.02, 0.10) - _seg(t, 0.88, 0.97);
    final rise = Curves.easeOutBack.transform(
      ((t - 0.10) / 0.10).clamp(0.0, 1.0),
    );
    final fill = _seg(t, 0.24, 0.42);
    final toMouth = _seg(t, 0.46, 0.54);
    final drink = _seg(t, 0.54, 0.66);
    final back = _seg(t, 0.68, 0.76);
    final happy = _seg(t, 0.64, 0.72);

    _box(canvas, lid);
    _glass(canvas, fill, drink, back);
    _face(canvas, happy, drink);

    // Hap: kutudan yükselir, sonra ağza gider ve kaybolur.
    if (toMouth < 1) {
      final start = Offset(58, 150 - 62 * rise);
      final bob = t > 0.2 && t < 0.46 ? math.sin(t * 60) * 2.5 : 0.0;
      final mouth = const Offset(238, 120);
      final p = Offset.lerp(start + Offset(0, bob), mouth, toMouth)!;
      _pill(canvas, p, 1 - toMouth * 0.8, -0.5 + toMouth * 0.5);
    }

    if (happy > 0) _sparkles(canvas, happy);
  }

  void _box(Canvas canvas, double lid) {
    final body = RRect.fromLTRBR(26, 132, 92, 182, const Radius.circular(10));
    canvas.drawRRect(body, Paint()..color = c.accent);
    // Ön etiket
    canvas.drawRRect(
      RRect.fromLTRBR(38, 148, 80, 168, const Radius.circular(5)),
      Paint()..color = c.onAccent.withValues(alpha: 0.85),
    );
    final plus = Paint()
      ..color = c.accent
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(59, 152), const Offset(59, 164), plus);
    canvas.drawLine(const Offset(53, 158), const Offset(65, 158), plus);

    // Kapak sol üst köşeden menteşeli açılır.
    canvas.save();
    canvas.translate(24, 132);
    canvas.rotate(-1.9 * lid);
    canvas.drawRRect(
      RRect.fromLTRBR(0, -12, 70, 2, const Radius.circular(6)),
      Paint()..color = Color.lerp(c.accent, Colors.black, 0.15)!,
    );
    canvas.restore();
  }

  void _pill(Canvas canvas, Offset center, double scale, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.scale(scale);
    const w = 36.0, h = 15.0;
    final full = RRect.fromLTRBR(
      -w / 2,
      -h / 2,
      w / 2,
      h / 2,
      const Radius.circular(h / 2),
    );
    canvas.clipRRect(full);
    canvas.drawRect(
      const Rect.fromLTRB(-w / 2, -h / 2, 0, h / 2),
      Paint()..color = const Color(0xFFFFC94D),
    );
    canvas.drawRect(
      const Rect.fromLTRB(0, -h / 2, w / 2, h / 2),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      full,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0x33000000),
    );
    canvas.restore();
  }

  void _glass(Canvas canvas, double fill, double drink, double back) {
    // Bardak ortadan yüze doğru gider, eğilir, sonra geri döner.
    final move = drink > 0 ? math.min(1.0, drink * 3) * (1 - back) : 0.0;
    final cx = 150 + 52 * move;
    final tilt = -0.65 * move;
    final level = fill * (1 - drink * 0.9);

    const top = 96.0, bottom = 182.0, wTop = 25.0, wBottom = 19.0;
    final path = Path()
      ..moveTo(-wTop, top - bottom)
      ..lineTo(wTop, top - bottom)
      ..lineTo(wBottom, 0)
      ..lineTo(-wBottom, 0)
      ..close();

    // Dökülen akış (doldurma sırasında)
    if (fill > 0 && fill < 1) {
      final surface = bottom - (bottom - top - 8) * fill;
      final stream = Paint()
        ..color = _liquid.withValues(alpha: 0.9)
        ..strokeWidth = syrup ? 6 : 5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(cx, 30), Offset(cx, surface), stream);
      _source(canvas, Offset(cx, 24));
    }

    canvas.save();
    canvas.translate(cx, bottom);
    canvas.rotate(tilt);
    canvas.drawPath(
      path,
      Paint()
        ..color = (dark ? Colors.white : const Color(0xFFDCE6F5)).withValues(
          alpha: dark ? 0.10 : 0.55,
        ),
    );
    canvas.save();
    canvas.clipPath(path);
    final h = (bottom - top - 8) * level;
    canvas.drawRect(Rect.fromLTRB(-40, -h, 40, 2), Paint()..color = _liquid);
    // Yüzeydeki parlaklık
    if (h > 3) {
      canvas.drawRect(
        Rect.fromLTRB(-40, -h, 40, -h + 3),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = c.muted.withValues(alpha: 0.7),
    );
    canvas.restore();
  }

  Color get _liquid =>
      syrup ? const Color(0xFFE0823A) : const Color(0xFF5AB4F0);

  /// Akışın geldiği yer: su için sürahi ağzı, şurup için şişe.
  void _source(Canvas canvas, Offset tip) {
    final p = Paint()..color = syrup ? const Color(0xFFB4561A) : c.muted;
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(syrup ? 2.3 : 2.1);
    if (syrup) {
      canvas.drawRRect(
        RRect.fromLTRBR(-6, -2, 6, 12, const Radius.circular(2)),
        p,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(-13, 10, 13, 46, const Radius.circular(8)),
        p,
      );
      canvas.drawRRect(
        RRect.fromLTRBR(-9, 20, 9, 34, const Radius.circular(3)),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
    } else {
      canvas.drawRRect(
        RRect.fromLTRBR(-16, 0, 16, 40, const Radius.circular(10)),
        Paint()..color = c.muted.withValues(alpha: 0.35),
      );
      canvas.drawRRect(
        RRect.fromLTRBR(-12, 14, 12, 38, const Radius.circular(7)),
        Paint()..color = _liquid.withValues(alpha: 0.8),
      );
    }
    canvas.restore();
  }

  void _face(Canvas canvas, double happy, double drink) {
    const center = Offset(250, 118);
    const r = 40.0;
    canvas.drawCircle(center, r, Paint()..color = const Color(0xFFFFD66B));

    final ink = Paint()
      ..color = const Color(0xFF3A2A12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    // Gözler: nokta -> mutlu kavis
    for (final dx in const [-14.0, 14.0]) {
      final e = center + Offset(dx, -8);
      if (happy < 0.5) {
        canvas.drawCircle(e, 3.6, Paint()..color = const Color(0xFF3A2A12));
      } else {
        canvas.drawArc(
          Rect.fromCenter(
            center: e + const Offset(0, 2),
            width: 12,
            height: 10,
          ),
          math.pi,
          math.pi,
          false,
          ink,
        );
      }
    }

    // Yanaklar
    if (happy > 0) {
      final blush = Paint()
        ..color = const Color(0xFFFF8FA3).withValues(alpha: 0.6 * happy);
      canvas.drawCircle(center + const Offset(-24, 8), 6, blush);
      canvas.drawCircle(center + const Offset(24, 8), 6, blush);
    }

    // Ağız: içerken "o", sonra gülümseme
    final mouth = center + const Offset(0, 12);
    if (drink > 0 && drink < 1 && happy < 0.3) {
      canvas.drawOval(
        Rect.fromCenter(center: mouth, width: 10, height: 12),
        Paint()..color = const Color(0xFF3A2A12),
      );
    } else {
      final curve = 2 + 10 * happy;
      final path = Path()
        ..moveTo(mouth.dx - 11, mouth.dy)
        ..quadraticBezierTo(
          mouth.dx,
          mouth.dy + curve,
          mouth.dx + 11,
          mouth.dy,
        );
      canvas.drawPath(path, ink);
    }
  }

  void _sparkles(Canvas canvas, double happy) {
    final rnd = [
      (const Offset(206, 72), 0.0),
      (const Offset(292, 80), 0.3),
      (const Offset(282, 160), 0.6),
      (const Offset(214, 158), 0.15),
    ];
    for (final (o, phase) in rnd) {
      final k = ((t * 9 + phase) % 1.0);
      final pos = o + Offset(0, -10 * k);
      final a = happy * (1 - k);
      _heart(canvas, pos, 7 + 3 * happy, c.accent.withValues(alpha: a));
    }
  }

  void _heart(Canvas canvas, Offset o, double s, Color color) {
    final p = Path()
      ..moveTo(o.dx, o.dy + s * 0.9)
      ..cubicTo(
        o.dx - s * 1.4,
        o.dy - s * 0.1,
        o.dx - s * 0.6,
        o.dy - s * 1.1,
        o.dx,
        o.dy - s * 0.3,
      )
      ..cubicTo(
        o.dx + s * 0.6,
        o.dy - s * 1.1,
        o.dx + s * 1.4,
        o.dy - s * 0.1,
        o.dx,
        o.dy + s * 0.9,
      );
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StoryPainter old) =>
      old.t != t || old.syrup != syrup || old.dark != dark || old.c != c;
}
