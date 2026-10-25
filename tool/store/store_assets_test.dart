// Mağaza görsellerini uygulamanın gerçek ekranlarından üretir:
//
//   flutter test tool/store/store_assets_test.dart
//   tool/store/finalize.sh
//
// Çıktılar store/ altına PNG olarak yazılır; finalize.sh bunları mağazaların
// istediği alfa kanalsız JPEG'lere çevirir.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:takeapill/app.dart';
import 'package:takeapill/core/db/app_database.dart';
import 'package:takeapill/core/settings_store.dart';
import 'package:takeapill/features/schedule/data/schedule_repository.dart';
import 'package:takeapill/features/schedule/domain/rule_codec.dart';
import 'package:takeapill/features/schedule/domain/schedule_models.dart';
import 'package:takeapill/ui/onboarding_art.dart';
import 'package:takeapill/ui/providers.dart';
import 'package:takeapill/ui/theme.dart';

const _out = 'store';
final _shotKey = GlobalKey();

/// Ekranlarda görünen "şimdi": öğleden sonra, sabah dozları alınmış.
final _now = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day, 14, 20);
}();

// --- Cihazlar -----------------------------------------------------------------

class _Device {
  const _Device({
    required this.dir,
    required this.canvas,
    required this.ratio,
    required this.screen,
    required this.insets,
    required this.bezel,
    required this.radius,
    required this.screenRadius,
    required this.camera,
    required this.width,
    required this.top,
    required this.titleSize,
  });

  final String dir;

  /// Mantıksal tuval; piksel boyutu canvas × ratio.
  final Size canvas;
  final double ratio;

  /// Cihaz ekranının mantıksal boyutu ve sistem çubukları.
  final Size screen;
  final EdgeInsets insets;
  final double bezel;
  final double radius;
  final double screenRadius;
  final _Camera camera;

  /// Cihazın tuval genişliğine oranı ve üst kenarının tuval yüksekliğine oranı.
  final double width;
  final double top;

  /// Başlık punto oranı (tuval genişliğine göre).
  final double titleSize;

  bool get tablet => screen.shortestSide > 600;

  /// App Store görsellerinde iOS arayüzü (liquid glass alt menü) çizilir.
  bool get apple => dir.startsWith('app-store');
}

enum _Camera { island, hole, dot }

const _iphone = _Device(
  dir: 'app-store/iphone-6.9',
  canvas: Size(440, 956),
  ratio: 3,
  screen: Size(393, 852),
  insets: EdgeInsets.only(top: 59, bottom: 34),
  bezel: 12,
  radius: 64,
  screenRadius: 52,
  camera: _Camera.island,
  width: 0.8,
  top: 0.26,
  titleSize: 0.088,
);

const _ipad = _Device(
  dir: 'app-store/ipad-13',
  canvas: Size(1032, 1376),
  ratio: 2,
  screen: Size(1024, 1366),
  insets: EdgeInsets.only(top: 24, bottom: 20),
  bezel: 20,
  radius: 44,
  screenRadius: 24,
  camera: _Camera.dot,
  width: 0.78,
  top: 0.215,
  titleSize: 0.056,
);

const _android = _Device(
  dir: 'google-play/phone',
  canvas: Size(360, 640),
  ratio: 3,
  screen: Size(412, 915),
  insets: EdgeInsets.only(top: 40, bottom: 24),
  bezel: 11,
  radius: 46,
  screenRadius: 36,
  camera: _Camera.hole,
  width: 0.78,
  top: 0.275,
  titleSize: 0.085,
);

// --- Sahneler -----------------------------------------------------------------

class _Shot {
  const _Shot(
    this.file,
    this.title,
    this.subtitle,
    this.bg, {
    this.route,
    this.push,
    this.brightness = Brightness.light,
    this.scroll = 0,
  });

  final String file;
  final String title;
  final String subtitle;
  final List<Color> bg;

  /// null ise kilit ekranı bildirimi gösterilir.
  final String? route;

  /// [route] açıldıktan sonra üstüne itilen sayfa (iOS'ta alttan açılan form).
  final String? push;
  final Brightness brightness;

  /// Ekranın kaydırılacağı mesafe (telefonda; tablette ekran zaten uzun).
  final double scroll;
}

// Uygulamanın paleti: grafit zemin, petrol yeşili vurgu.
const _graphite = [Color(0xFF2B2B30), Color(0xFF0B0B0D)];
const _teal = [Color(0xFF115E59), Color(0xFF0B0B0D)];
const _night = [Color(0xFF0F3D3A), Color(0xFF050506)];
const _glow = Color(0xFF3CCFB9);

const _shots = [
  _Shot(
    '01-bugun',
    'İlaç saatini\nkaçırma.',
    'Günün dozları tek ekranda,\nsıradaki hep önde.',
    _graphite,
    route: '/',
  ),
  _Shot(
    '02-bildirim',
    'Tam zamanında\nhatırlatır.',
    'Birkaç dakika önce, zamanında\nve gerekirse bir kez daha.',
    _teal,
  ),
  _Shot(
    '03-ilac-ekle',
    'Bir kez gir,\ngerisini unut.',
    'Saat, doz ve aç/tok durumu;\nyemek saatine göre plan.',
    _graphite,
    route: '/meds',
    push: '/med?id=3',
  ),
  _Shot(
    '04-ilaclar',
    'Tüm ilaçların\ntek yerde.',
    'Hap, kapsül, damla, şurup;\nher biri kendi planıyla.',
    _teal,
    route: '/meds',
  ),
  _Shot(
    '05-gecmis',
    'Uyumunu\ntakip et.',
    'Aldığın, atladığın ve\nkaçırdığın her doz kayıtlı.',
    _graphite,
    route: '/history',
  ),
  _Shot(
    '06-gizlilik',
    'Verilerin\nsende kalır.',
    'Hesap yok, reklam yok.\nHer şey bu cihazda.',
    _night,
    route: '/',
    brightness: Brightness.dark,
    scroll: 470,
  ),
];

// --- Örnek veri ---------------------------------------------------------------

Future<AppDatabase> _seed() async {
  final db = AppDatabase(NativeDatabase.memory());
  final today = DateTime(_now.year, _now.month, _now.day);
  DateTime day(int offset) =>
      DateTime(today.year, today.month, today.day + offset);

  Future<void> add(
    String name,
    String strength,
    String purpose,
    String form,
    int color,
    ScheduleRule rule,
  ) => db.addMedication(
    MedicationsCompanion.insert(
      name: name,
      strength: Value(strength),
      purpose: Value(purpose),
      form: Value(form),
      color: Value(color),
    ),
    encodeRule(rule),
  );

  await add(
    'Levotiroksin',
    '50 mcg',
    'Tiroid',
    'pill',
    0xFF14B8A6,
    DailyRule(
      startDate: day(-60),
      slots: const [
        DoseSlot.anchored(TimingAnchor.wake, food: FoodRelation.emptyStomach),
      ],
    ),
  );
  await add(
    'Amoksisilin',
    '1000 mg',
    'Antibiyotik',
    'pill',
    0xFFEF4444,
    IntervalRule(
      startDate: day(-4),
      endDate: day(3),
      everyHours: 12,
      firstMinutes: 9 * 60,
      food: FoodRelation.after,
    ),
  );
  await add(
    'Metformin',
    '500 mg',
    'Şeker',
    'pill',
    0xFF3B82F6,
    DailyRule(
      startDate: day(-60),
      slots: const [
        DoseSlot.anchored(
          TimingAnchor.breakfast,
          food: FoodRelation.fullStomach,
        ),
        DoseSlot.anchored(TimingAnchor.dinner, food: FoodRelation.fullStomach),
      ],
    ),
  );
  await add(
    'D vitamini',
    '1000 IU',
    'Takviye',
    'drops',
    0xFFF59E0B,
    DailyRule(
      startDate: day(-60),
      slots: const [
        DoseSlot.anchored(TimingAnchor.lunch, food: FoodRelation.withMeal),
      ],
    ),
  );
  await add(
    'Omega 3',
    '1000 mg',
    'Takviye',
    'capsule',
    0xFF64748B,
    DailyRule(
      startDate: day(-60),
      slots: const [
        DoseSlot.anchored(TimingAnchor.dinner, food: FoodRelation.withMeal),
      ],
    ),
  );
  await add(
    'Parasetamol',
    '500 mg',
    'Ağrı, ateş',
    'pill',
    0xFFEC4899,
    AsNeededRule(startDate: day(-60), maxPerDay: 4),
  );

  // Son 14 gün: birkaç istisna dışında her doz alınmış.
  const skipped = {('D vitamini', -3, 13), ('Metformin', -9, 19)};
  const missed = {('Omega 3', -6, 19)};
  final views = await loadDoseViews(db, day(-13), _now);
  for (final v in views) {
    final s = v.dose.scheduledAt;
    final offset =
        (DateTime(s.year, s.month, s.day).difference(today).inHours / 24)
            .round();
    final key = (v.medication.name, offset, s.hour);
    if (missed.contains(key)) continue;
    await db.recordDose(
      v.medication.id,
      s,
      skipped.contains(key) ? DoseStatus.skipped : DoseStatus.taken,
    );
  }
  await db.setSetting(SettingKeys.onboarded, '1');
  return db;
}

// --- Test ---------------------------------------------------------------------

Future<void> _font(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(
      Future.value(ByteData.sublistView(File(p).readAsBytesSync())),
    );
  }
  await loader.load();
}

String get _flutterRoot {
  final flutter = Process.runSync('which', [
    'flutter',
  ]).stdout.toString().trim();
  return File(flutter)
      .resolveSymbolicLinksSync()
      .replaceFirst(RegExp(r'/bin/flutter$'), '');
}

/// cupertino_icons paketinin yerel kopyası (package_config.json'dan).
String get _cupertinoIcons {
  final config = File('.dart_tool/package_config.json').readAsStringSync();
  final uri = RegExp(r'"name":\s*"cupertino_icons",\s*"rootUri":\s*"([^"]+)"')
      .firstMatch(config)!
      .group(1)!;
  return Uri.parse(uri).toFilePath();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('tr');
    Intl.defaultLocale = 'tr';
    await _font('PlusJakartaSans', [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold'])
        'assets/fonts/PlusJakartaSans-$w.ttf',
    ]);
    await _font('MaterialIcons', [
      '$_flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
    await _font('packages/cupertino_icons/CupertinoIcons', [
      '$_cupertinoIcons/assets/CupertinoIcons.ttf',
    ]);
    await LiquidGlassWidgets.initialize(enablePerformanceMonitor: false);
  });

  testWidgets('mağaza görselleri', (t) async {
    debugDisableShadows = false;
    final db = (await t.runAsync(_seed))!;

    await withClock(Clock.fixed(_now), () async {
      for (final device in [_iphone, _ipad, _android]) {
        t.view.physicalSize = device.canvas * device.ratio;
        t.view.devicePixelRatio = device.ratio;
        for (final shot in _shots) {
          final router = buildRouter(onboarded: true);
          final route = shot.route;
          if (route != null) router.go(route);
          final screen = route == null
              ? _LockScreen(device: device)
              : ProviderScope(
                  overrides: [dbProvider.overrideWithValue(db)],
                  child: MaterialApp.router(
                    routerConfig: router,
                    debugShowCheckedModeBanner: false,
                    theme: buildTheme(shot.brightness).copyWith(
                      platform: device.apple
                          ? TargetPlatform.iOS
                          : TargetPlatform.android,
                    ),
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        size: device.screen,
                        padding: device.insets,
                        viewPadding: device.insets,
                        textScaler: TextScaler.noScaling,
                      ),
                      child: child!,
                    ),
                  ),
                );
          await _render(
            t,
            _StorePage(
              device: device,
              shot: shot,
              screen: screen,
              // iOS sayfasının arkası siyah; durum çubuğu açık renk olur.
              darkStatus:
                  route == null ||
                  shot.brightness == Brightness.dark ||
                  (device.apple && shot.push != null),
            ),
            '$_out/${device.dir}/${shot.file}.png',
            scroll: device.tablet ? 0 : shot.scroll,
            then: switch (shot.push) {
              final push? => () => router.push(push),
              null => null,
            },
          );
        }
      }

      // Google Play öne çıkan görseli (1024 × 500)
      t.view.physicalSize = const Size(1024, 500);
      t.view.devicePixelRatio = 2;
      await _render(
        t,
        const _FeatureGraphic(),
        '$_out/google-play/feature-graphic.png',
      );
    });

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    await t.runAsync(db.close);
    debugDisableShadows = true;
    t.view.reset();
  });
}

Future<void> _render(
  WidgetTester t,
  Widget page,
  String path, {
  double scroll = 0,
  VoidCallback? then,
}) async {
  await t.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      home: Material(
        type: MaterialType.transparency,
        child: RepaintBoundary(key: _shotKey, child: page),
      ),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (then != null) {
    then();
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  // Animasyonların bitmesi ve FutureBuilder'ların dolması için.
  for (var i = 0; i < 30; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
  if (scroll > 0) {
    // Formda formun listesi; arkadaki ekranın ya da metin alanlarının değil.
    final form = find.ancestor(
      of: find.byKey(const ValueKey('name')),
      matching: find.byType(Scrollable),
    );
    t
        .state<ScrollableState>(
          form.evaluate().isEmpty ? find.byType(Scrollable).first : form.first,
        )
        .position
        .jumpTo(scroll);
    await t.pump(const Duration(milliseconds: 100));
  }
  final boundary = t.renderObject<RenderRepaintBoundary>(find.byKey(_shotKey));
  await t.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: t.view.devicePixelRatio);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('yazıldı: $path');
}

// --- Sayfa düzeni -------------------------------------------------------------

class _StorePage extends StatelessWidget {
  const _StorePage({
    required this.device,
    required this.shot,
    required this.screen,
    required this.darkStatus,
  });

  final _Device device;
  final _Shot shot;
  final Widget screen;
  final bool darkStatus;

  @override
  Widget build(BuildContext context) {
    final size = device.canvas;
    final w = size.width;
    final phoneW = w * device.width;
    return SizedBox.fromSize(
      size: size,
      child: ClipRect(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: shot.bg,
            ),
          ),
          child: Stack(
            children: [
              _Blob(
                center: Offset(w * 0.1, size.height * 0.08),
                radius: w * 0.7,
                color: Colors.white.withValues(alpha: 0.07),
              ),
              _Blob(
                center: Offset(w * 1.0, size.height * 0.62),
                radius: w * 0.9,
                color: _glow.withValues(alpha: 0.16),
              ),
              Positioned(
                left: w * 0.08,
                right: w * 0.08,
                top: size.height * (device.tablet ? 0.05 : 0.065),
                child: Column(
                  children: [
                    Text(
                      shot.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: w * device.titleSize,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                        letterSpacing: -0.012 * w * device.titleSize,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: w * device.titleSize * 0.36),
                    Text(
                      shot.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: w * device.titleSize * 0.46,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: size.height * device.top,
                left: (w - phoneW) / 2,
                width: phoneW,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  child: _Frame(
                    device: device,
                    darkStatus: darkStatus,
                    child: screen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.center,
    required this.radius,
    required this.color,
  });

  final Offset center;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) => Positioned(
    left: center.dx - radius,
    top: center.dy - radius,
    child: Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Markasız, sade bir cihaz çerçevesi.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.device,
    required this.darkStatus,
    required this.child,
  });

  final _Device device;
  final bool darkStatus;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = device.screen;
    final b = device.bezel;
    return Container(
      width: s.width + b * 2,
      height: s.height + b * 2,
      padding: EdgeInsets.all(b),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B10),
        borderRadius: BorderRadius.circular(device.radius),
        border: Border.all(color: const Color(0xFF4A4A55), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 60,
            offset: const Offset(0, 30),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(device.screenRadius),
        child: Stack(
          children: [
            Positioned.fill(child: child),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: device.insets.top,
              child: _StatusBar(device: device, dark: darkStatus),
            ),
            if (device.camera == _Camera.island)
              Positioned(
                top: 11,
                left: (s.width - 124) / 2,
                child: Container(
                  width: 124,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            if (device.camera == _Camera.hole)
              Positioned(
                top: 12,
                left: (s.width - 16) / 2,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.device, required this.dark});

  final _Device device;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : const Color(0xFF111113);
    final island = device.camera == _Camera.island;
    final time = Text(
      '9:41',
      style: TextStyle(
        fontSize: island ? 17 : 14,
        fontWeight: FontWeight.w700,
        color: fg,
      ),
    );
    final icons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.signal_cellular_alt_rounded,
          size: island ? 19 : 16,
          color: fg,
        ),
        const SizedBox(width: 5),
        Icon(Icons.wifi_rounded, size: island ? 19 : 16, color: fg),
        const SizedBox(width: 6),
        Container(
          width: island ? 26 : 22,
          height: island ? 13 : 11,
          padding: const EdgeInsets.all(1.6),
          decoration: BoxDecoration(
            border: Border.all(color: fg.withValues(alpha: 0.45), width: 1.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: fg,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ],
    );
    if (island) {
      return Row(
        children: [
          Expanded(child: Center(child: time)),
          const SizedBox(width: 124),
          Expanded(child: Center(child: icons)),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(children: [time, const Spacer(), icons]),
    );
  }
}

// --- Kilit ekranı ---------------------------------------------------------------

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.device});

  final _Device device;

  @override
  Widget build(BuildContext context) {
    final s = device.screen;
    final cardW = (s.width - 28).clamp(0.0, 440.0);
    final date = DateFormat('d MMMM EEEE', 'tr').format(_now);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C1C1F), Color(0xFF0F3D3A), Color(0xFF0A0A0C)],
        ),
      ),
      child: Stack(
        children: [
          const _Blob(
            center: Offset(60, 620),
            radius: 320,
            color: Color(0x443CCFB9),
          ),
          const _Blob(
            center: Offset(380, 260),
            radius: 280,
            color: Color(0x22FFFFFF),
          ),
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: device.insets.top + s.height * 0.035),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
                const Text(
                  '08:00',
                  style: TextStyle(
                    fontSize: 96,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -3,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: s.height * (device.tablet ? 0.18 : 0.12)),
                SizedBox(
                  width: cardW,
                  child: const Column(
                    children: [
                      _Notification(
                        title: 'İlaç zamanı: Metformin',
                        body: '08:00 · Tok karnına',
                        time: 'şimdi',
                        actions: true,
                      ),
                      SizedBox(height: 10),
                      _Notification(
                        title: 'Birazdan: Metformin',
                        body: '08:00 · Tok karnına',
                        time: '5 dk önce',
                      ),
                      SizedBox(height: 10),
                      _Notification(
                        title: 'İlaç zamanı: Levotiroksin',
                        body: '07:00 · Aç karnına',
                        time: '1 sa önce',
                        done: true,
                      ),
                    ],
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

class _Notification extends StatelessWidget {
  const _Notification({
    required this.title,
    required this.body,
    required this.time,
    this.actions = false,
    this.done = false,
  });

  final String title;
  final String body;
  final String time;
  final bool actions;
  final bool done;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF111113);
    const muted = Color(0xFF6B6B73);
    return Opacity(
      opacity: done ? 0.75 : 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 38,
                    height: 38,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: ink,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (actions) ...[
              const SizedBox(height: 12),
              const Row(
                children: [
                  Expanded(
                    child: _NotifAction(
                      icon: Icons.check_rounded,
                      text: 'Aldım',
                      primary: true,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _NotifAction(
                      icon: Icons.snooze_rounded,
                      text: 'Ertele',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _NotifAction(
                      icon: Icons.close_rounded,
                      text: 'Atla',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifAction extends StatelessWidget {
  const _NotifAction({
    required this.icon,
    required this.text,
    this.primary = false,
  });

  final IconData icon;
  final String text;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : const Color(0xFF111113);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: primary ? const Color(0xFF18181B) : const Color(0xFFF0F0F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Öne çıkan görsel -----------------------------------------------------------

class _FeatureGraphic extends StatelessWidget {
  const _FeatureGraphic();

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 512,
    height: 250,
    child: ClipRect(
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _graphite,
          ),
        ),
        child: Stack(
          children: [
            _Blob(
              center: const Offset(400, 120),
              radius: 220,
              color: _glow.withValues(alpha: 0.18),
            ),
            Positioned(
              left: 36,
              top: 0,
              bottom: 0,
              width: 250,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/icon/icon.png',
                        width: 64,
                        height: 64,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Take a Pill',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                      height: 1.05,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'İlaçlarını unutma.',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 250,
              child: Theme(
                data: buildTheme(Brightness.light),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: OnboardingArt(page: 0, active: true),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
