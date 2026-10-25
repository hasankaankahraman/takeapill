import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Tasarım token'ları. Zemin nötr grafit; ana eylemler mürekkep rengi,
/// vurgu (ilerleme, sıradaki doz, alındı) petrol yeşili.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.glass,
    required this.ink,
    required this.muted,
    required this.line,
    required this.chip,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.onAccentSoft,
    required this.warn,
    required this.warnSoft,
    required this.note,
    required this.onNote,
    required this.ok,
  });

  final Color bg;
  final Color surface;

  /// Yarı saydam çubukların (Android alt menü) dolgusu.
  final Color glass;
  final Color ink;
  final Color muted;
  final Color line;
  final Color chip;

  /// Dolu butonlar ve seçili öğeler.
  final Color primary;
  final Color onPrimary;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color onAccentSoft;
  final Color warn;
  final Color warnSoft;
  final Color note;
  final Color onNote;
  final Color ok;

  static const light = AppColors(
    bg: Color(0xFFF4F4F5),
    surface: Color(0xFFFFFFFF),
    glass: Color(0xB8FFFFFF),
    ink: Color(0xFF111113),
    muted: Color(0xFF6B6B73),
    line: Color(0xFFE4E4E7),
    chip: Color(0xFFF0F0F2),
    primary: Color(0xFF18181B),
    onPrimary: Color(0xFFFFFFFF),
    accent: Color(0xFF0F766E),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE3F1EE),
    onAccentSoft: Color(0xFF0B5C55),
    warn: Color(0xFFB4470A),
    warnSoft: Color(0xFFFBEDE3),
    note: Color(0xFFF7F6F2),
    onNote: Color(0xFF57534E),
    ok: Color(0xFF15803D),
  );

  static const dark = AppColors(
    bg: Color(0xFF09090B),
    surface: Color(0xFF161618),
    glass: Color(0xB8161618),
    ink: Color(0xFFF4F4F5),
    muted: Color(0xFF9C9CA5),
    line: Color(0xFF27272A),
    chip: Color(0xFF212124),
    primary: Color(0xFFF4F4F5),
    onPrimary: Color(0xFF111113),
    accent: Color(0xFF3CCFB9),
    onAccent: Color(0xFF062A26),
    accentSoft: Color(0xFF10302C),
    onAccentSoft: Color(0xFF8EE6D7),
    warn: Color(0xFFFB923C),
    warnSoft: Color(0xFF33200F),
    note: Color(0xFF1C1B19),
    onNote: Color(0xFFD6D3CC),
    ok: Color(0xFF4ADE80),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : other ?? this;
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

/// iOS'ta Cupertino kontrolleri ve liquid glass, Android'de Material kullanılır.
bool isApple(BuildContext context) =>
    Theme.of(context).platform == TargetPlatform.iOS;

/// İlacın kendi renginden ikon zemini ve ikon rengi üretir.
(Color bg, Color fg) medTint(BuildContext context, int argb) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final hsl = HSLColor.fromColor(Color(argb));
  final fg = dark
      ? hsl.withLightness((hsl.lightness + 0.2).clamp(0, 0.78)).toColor()
      : hsl.withLightness((hsl.lightness - 0.15).clamp(0.22, 1)).toColor();
  final bg = Color(argb).withValues(alpha: dark ? 0.2 : 0.12);
  return (bg, fg);
}

const fontFamily = 'PlusJakartaSans';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final apple = defaultTargetPlatform == TargetPlatform.iOS;
  // Monokrom tohum: seçiciler ve menüler gibi Material yüzeylerine mor
  // tonlar sızmasın.
  final scheme =
      ColorScheme.fromSeed(
        seedColor: c.accent,
        brightness: brightness,
        dynamicSchemeVariant: DynamicSchemeVariant.monochrome,
      ).copyWith(
        primary: c.primary,
        onPrimary: c.onPrimary,
        primaryContainer: c.accentSoft,
        onPrimaryContainer: c.onAccentSoft,
        secondary: c.accent,
        onSecondary: c.onAccent,
        tertiary: c.accent,
        surface: c.bg,
        onSurface: c.ink,
        onSurfaceVariant: c.muted,
        surfaceContainerLowest: c.surface,
        surfaceContainerLow: c.surface,
        surfaceContainer: c.surface,
        surfaceContainerHigh: c.surface,
        surfaceContainerHighest: c.chip,
        outline: c.muted,
        outlineVariant: c.line,
        surfaceTint: Colors.transparent,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
    // iOS'ta dalga efekti yok; basılı hâl hafif bir gölgeyle belli olur.
    splashFactory: apple ? NoSplash.splashFactory : null,
    highlightColor: apple ? c.ink.withValues(alpha: 0.05) : null,
  );
  final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
  final shape12 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return base.copyWith(
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: c.accent,
      scaffoldBackgroundColor: c.bg,
    ),
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.9,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: text.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      foregroundColor: c.ink,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: c.ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: c.line),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: c.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.chip,
      labelStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(color: c.ink, fontWeight: FontWeight.w600),
      hintStyle: TextStyle(color: c.muted.withValues(alpha: 0.7)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(c.ink, 1.2),
      errorBorder: border(scheme.error, 1.2),
      focusedErrorBorder: border(scheme.error, 1.5),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size(44, 48),
        shape: shape12,
        elevation: 0,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.ink,
        shape: shape12,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.primary,
      contentTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: c.onPrimary,
      ),
      elevation: 0,
      shape: shape12,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.surface,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.line),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      headerBackgroundColor: c.surface,
      headerForegroundColor: c.ink,
      dividerColor: c.line,
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: c.surface,
      elevation: 0,
      dialBackgroundColor: c.chip,
      hourMinuteColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.primary : c.chip,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (s) => s.contains(WidgetState.selected) ? c.onPrimary : c.ink,
      ),
    ),
  );
}
