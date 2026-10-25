// Uygulama ikonunu çizer:
//
//   flutter test tool/icon/icon_test.dart
//   dart run flutter_launcher_icons
//
// assets/icon/icon.png (iOS, 1024 px, zeminli) ve icon_foreground.png
// (Android uyarlanabilir ikonun ön katmanı, saydam) yazılır; zemin rengi
// pubspec.yaml'daki adaptive_icon_background ile aynı olmalı.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
final _key = GlobalKey();

const _bgTop = Color(0xFF2B2B30);
const _bgBottom = Color(0xFF0B0B0D);
const _teal = Color(0xFF3CCFB9);
const _tealDeep = Color(0xFF0F8F80);

void main() {
  testWidgets('uygulama ikonu', (t) async {
    t.view.physicalSize = const Size(_size, _size);
    t.view.devicePixelRatio = 1;
    debugDisableShadows = false;

    await _render(t, const _Icon(background: true), 'assets/icon/icon.png');
    // Android ön katmanı; flutter_launcher_icons %16 iç boşlukla yerleştirir,
    // hap böylece maskenin güvenli dairesinde kalır.
    await _render(
      t,
      const _Icon(background: false),
      'assets/icon/icon_foreground.png',
    );

    debugDisableShadows = true;
    t.view.reset();
  });
}

Future<void> _render(WidgetTester t, Widget icon, String path) async {
  await t.pumpWidget(
    Center(
      child: RepaintBoundary(
        key: _key,
        child: SizedBox.square(dimension: _size, child: icon),
      ),
    ),
  );
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_key));
  await t.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('yazıldı: $path');
}

class _Icon extends StatelessWidget {
  const _Icon({required this.background});

  final bool background;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _IconPainter(background: background));
}

class _IconPainter extends CustomPainter {
  _IconPainter({required this.background});

  final bool background;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;

    if (background) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_bgTop, _bgBottom],
          ).createShader(rect),
      );
      // Hapın arkasında hafif petrol yeşili ışık.
      canvas.drawCircle(
        center,
        size.width * 0.5,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  _teal.withValues(alpha: 0.2),
                  _teal.withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(center: center, radius: size.width / 2),
              ),
      );
    }

    final length = size.width * 0.6;
    final width = size.width * 0.245;
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: length, height: width),
      Radius.circular(width / 2),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Gölge döndürülmeden çizilir ki hep aşağı düşsün.
    canvas.save();
    canvas.translate(0, width * 0.12);
    canvas.rotate(-math.pi / 4);
    canvas.drawRRect(
      pill,
      Paint()
        ..color = Colors.black.withValues(alpha: background ? 0.5 : 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.16),
    );
    canvas.restore();

    canvas.rotate(-math.pi / 4);
    final half = pill.outerRect;
    // Sol alt yarı petrol yeşili, sağ üst yarı beyaz.
    canvas.save();
    canvas.clipRRect(pill);
    canvas.drawRect(
      Rect.fromLTRB(half.left, half.top, 0, half.bottom),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_teal, _tealDeep],
        ).createShader(half),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, half.top, half.right, half.bottom),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFDADADF)],
        ).createShader(half),
    );
    // İki yarının birleşim çizgisi.
    canvas.drawLine(
      Offset(0, half.top),
      Offset(0, half.bottom),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..strokeWidth = width * 0.025,
    );
    canvas.restore();

    // Yeşil yarıdaki parlama.
    canvas.drawLine(
      Offset(half.left + width * 0.42, -width * 0.24),
      Offset(-width * 0.2, -width * 0.24),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..strokeWidth = width * 0.11
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.background != background;
}
