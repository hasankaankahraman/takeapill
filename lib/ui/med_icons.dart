import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// İlaç formuna göre çizilen ikon ([formLabels] anahtarları). Hepsi aynı
/// 24'lük ızgarada, aynı çizgi kalınlığıyla çizilir; tanınmayan form için
/// ilaç kutusu.
class MedFormIcon extends StatelessWidget {
  const MedFormIcon({
    super.key,
    required this.form,
    required this.color,
    this.size = 24,
  });

  final String form;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _MedFormPainter(form, color)),
  );
}

class _MedFormPainter extends CustomPainter {
  _MedFormPainter(this.form, this.color);

  final String form;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // İkinci ton: kapak, etiket, içerik gibi dolu kısımlar.
    final fill = Paint()..color = color.withValues(alpha: 0.28);
    switch (form) {
      case 'pill':
        _tablet(canvas, line, fill);
      case 'capsule':
        _capsule(canvas, line, fill);
      case 'syrup':
        _syrup(canvas, line, fill);
      case 'drops':
        _drops(canvas, line, fill);
      case 'injection':
        _syringe(canvas, line, fill);
      case 'cream':
        _tube(canvas, line, fill);
      case 'inhaler':
        _inhaler(canvas, line, fill);
      default:
        _bottle(canvas, line, fill);
    }
  }

  /// Yandan görünen, üstü çentikli yassı tablet.
  void _tablet(Canvas c, Paint line, Paint fill) {
    final top = Rect.fromCenter(
      center: const Offset(12, 10.2),
      width: 17,
      height: 8.6,
    );
    final side = Path()
      ..moveTo(3.5, 10.2)
      ..lineTo(3.5, 13.8)
      ..arcToPoint(
        const Offset(20.5, 13.8),
        radius: const Radius.elliptical(8.5, 4.3),
        clockwise: false,
      )
      ..lineTo(20.5, 10.2);
    c.drawPath(side, line);
    c.drawOval(top, fill);
    c.drawOval(top, line);
    c.drawLine(const Offset(8.2, 10.2), const Offset(15.8, 10.2), line);
  }

  /// Çapraz duran iki renkli kapsül.
  void _capsule(Canvas c, Paint line, Paint fill) {
    c.save();
    c.translate(12, 12);
    c.rotate(-math.pi / 4);
    final body = RRect.fromLTRBR(
      -9.6,
      -4.3,
      9.6,
      4.3,
      const Radius.circular(4.3),
    );
    c.save();
    c.clipRect(const Rect.fromLTRB(0, -5, 10, 5));
    c.drawRRect(body, fill);
    c.restore();
    c.drawRRect(body, line);
    c.drawLine(const Offset(0, -4.3), const Offset(0, 4.3), line);
    c.restore();
  }

  /// Kapaklı, etiketli şurup şişesi.
  void _syrup(Canvas c, Paint line, Paint fill) {
    final body = Path()
      ..moveTo(10, 6.5)
      ..lineTo(10, 8.2)
      ..lineTo(7.6, 10)
      ..quadraticBezierTo(6.5, 10.8, 6.5, 12)
      ..lineTo(6.5, 19.5)
      ..quadraticBezierTo(6.5, 21.5, 8.5, 21.5)
      ..lineTo(15.5, 21.5)
      ..quadraticBezierTo(17.5, 21.5, 17.5, 19.5)
      ..lineTo(17.5, 12)
      ..quadraticBezierTo(17.5, 10.8, 16.4, 10)
      ..lineTo(14, 8.2)
      ..lineTo(14, 6.5);
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTRB(6, 13.5, 18, 18.5), fill);
    c.restore();
    c.drawPath(body, line);
    final cap = RRect.fromLTRBR(
      8.8,
      2.5,
      15.2,
      6.5,
      const Radius.circular(1.2),
    );
    c.drawRRect(cap, fill);
    c.drawRRect(cap, line);
  }

  /// Büyük ve küçük damla.
  void _drops(Canvas c, Paint line, Paint fill) {
    final drop = Path()
      ..moveTo(10.5, 3)
      ..cubicTo(10.5, 3, 4.5, 9.8, 4.5, 14.5)
      ..arcToPoint(
        const Offset(16.5, 14.5),
        radius: const Radius.circular(6),
        clockwise: false,
      )
      ..cubicTo(16.5, 9.8, 10.5, 3, 10.5, 3)
      ..close();
    c.drawPath(drop, fill);
    c.drawPath(drop, line);
    // Parlama
    c.drawPath(
      Path()
        ..moveTo(7.8, 14.6)
        ..quadraticBezierTo(7.9, 17, 10.2, 17.6),
      line,
    );
    final small = Path()
      ..moveTo(18.5, 3.5)
      ..cubicTo(18.5, 3.5, 16.3, 6, 16.3, 7.6)
      ..arcToPoint(
        const Offset(20.7, 7.6),
        radius: const Radius.circular(2.2),
        clockwise: false,
      )
      ..cubicTo(20.7, 6, 18.5, 3.5, 18.5, 3.5)
      ..close();
    c.drawPath(small, line);
  }

  /// İğnesi sağ üste bakan şırınga.
  void _syringe(Canvas c, Paint line, Paint fill) {
    c.save();
    c.translate(12, 12.6);
    c.rotate(math.pi / 4);
    final barrel = RRect.fromLTRBR(
      -3,
      -6.5,
      3,
      4.5,
      const Radius.circular(1.2),
    );
    c.save();
    c.clipRRect(barrel);
    c.drawRect(const Rect.fromLTRB(-3, -6.5, 3, -0.5), fill);
    c.restore();
    c.drawRRect(barrel, line);
    c.drawLine(const Offset(-3, -3.5), const Offset(-0.8, -3.5), line);
    c.drawLine(const Offset(-3, -0.5), const Offset(-0.8, -0.5), line);
    c.drawLine(const Offset(0, -6.5), const Offset(0, -10.8), line);
    c.drawLine(const Offset(-5.2, 4.5), const Offset(5.2, 4.5), line);
    c.drawLine(const Offset(0, 4.5), const Offset(0, 8.6), line);
    c.drawLine(const Offset(-2.8, 8.6), const Offset(2.8, 8.6), line);
    c.restore();
  }

  /// Krem / merhem tüpü, kapağı altta.
  void _tube(Canvas c, Paint line, Paint fill) {
    final body = Path()
      ..moveTo(6.3, 4.5)
      ..lineTo(17.7, 4.5)
      ..lineTo(15.4, 15.6)
      ..quadraticBezierTo(15.2, 16.5, 14.2, 16.5)
      ..lineTo(9.8, 16.5)
      ..quadraticBezierTo(8.8, 16.5, 8.6, 15.6)
      ..close();
    c.save();
    c.clipPath(body);
    c.drawRect(const Rect.fromLTRB(5, 8, 19, 12), fill);
    c.restore();
    c.drawPath(body, line);
    c.drawLine(const Offset(5.5, 2.6), const Offset(18.5, 2.6), line);
    final cap = RRect.fromLTRBR(
      9.6,
      16.5,
      14.4,
      21.5,
      const Radius.circular(1.2),
    );
    c.drawRRect(cap, fill);
    c.drawRRect(cap, line);
  }

  /// Ağızlığı solda, kartuşu üstte solunum ilacı.
  void _inhaler(Canvas c, Paint line, Paint fill) {
    final can = RRect.fromLTRBR(11.5, 2.5, 17, 9.2, const Radius.circular(1.6));
    c.drawRRect(can, fill);
    c.drawRRect(can, line);
    final body = Path()
      ..moveTo(9.5, 9.2)
      ..lineTo(19, 9.2)
      ..lineTo(19, 19.5)
      ..quadraticBezierTo(19, 21.5, 17, 21.5)
      ..lineTo(6, 21.5)
      ..quadraticBezierTo(4, 21.5, 4, 19.5)
      ..lineTo(4, 17)
      ..quadraticBezierTo(4, 15, 6, 15)
      ..lineTo(9.5, 15)
      ..close();
    c.drawPath(body, line);
  }

  /// Artı işaretli ilaç kutusu ("Diğer").
  void _bottle(Canvas c, Paint line, Paint fill) {
    final cap = RRect.fromLTRBR(
      5.5,
      2.5,
      18.5,
      6.5,
      const Radius.circular(1.5),
    );
    c.drawRRect(cap, fill);
    c.drawRRect(cap, line);
    c.drawRRect(
      RRect.fromLTRBR(6.5, 6.5, 17.5, 21.5, const Radius.circular(2.5)),
      line,
    );
    c.drawLine(const Offset(12, 11), const Offset(12, 17), line);
    c.drawLine(const Offset(9, 14), const Offset(15, 14), line);
  }

  @override
  bool shouldRepaint(_MedFormPainter old) =>
      old.form != form || old.color != color;
}
