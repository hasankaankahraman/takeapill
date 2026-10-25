import 'package:flutter/material.dart';

/// Tasarım token'ları (Design tuvalindeki renkler). Material ColorScheme'in
/// karşılamadığı yumuşak tonlar burada tutulur.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.chip,
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
  final Color ink;
  final Color muted;
  final Color line;
  final Color chip;
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
    bg: Color(0xFFF5F6FA),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF12131A),
    muted: Color(0xFF5C6070),
    line: Color(0xFFEEF0F4),
    chip: Color(0xFFF0F1F5),
    accent: Color(0xFF4F46E5),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFEEF0FF),
    onAccentSoft: Color(0xFF4F46E5),
    warn: Color(0xFFB4470A),
    warnSoft: Color(0xFFFFEBDD),
    note: Color(0xFFFFF7E6),
    onNote: Color(0xFF5A4410),
    ok: Color(0xFF0F7A57),
  );

  static const dark = AppColors(
    bg: Color(0xFF0E0F14),
    surface: Color(0xFF181A22),
    ink: Color(0xFFF2F3F7),
    muted: Color(0xFFA0A4B3),
    line: Color(0xFF262938),
    chip: Color(0xFF242733),
    accent: Color(0xFF8B87FF),
    onAccent: Color(0xFF0E0F14),
    accentSoft: Color(0xFF25244A),
    onAccentSoft: Color(0xFFC7C4FF),
    warn: Color(0xFFFFA36B),
    warnSoft: Color(0xFF3A2416),
    note: Color(0xFF2E2614),
    onNote: Color(0xFFF1DDAE),
    ok: Color(0xFF5FD3A6),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : other ?? this;
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

/// İlacın kendi renginden ikon zemini ve ikon rengi üretir.
(Color bg, Color fg) medTint(BuildContext context, int argb) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final hsl = HSLColor.fromColor(Color(argb));
  final fg = dark
      ? hsl.withLightness((hsl.lightness + 0.2).clamp(0, 0.78)).toColor()
      : hsl.withLightness((hsl.lightness - 0.15).clamp(0.22, 1)).toColor();
  final bg = Color(argb).withValues(alpha: dark ? 0.22 : 0.14);
  return (bg, fg);
}

const fontFamily = 'PlusJakartaSans';

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF4F46E5),
        brightness: brightness,
      ).copyWith(
        primary: c.accent,
        onPrimary: c.onAccent,
        primaryContainer: c.accentSoft,
        onPrimaryContainer: c.onAccentSoft,
        surface: c.bg,
        onSurface: c.ink,
        onSurfaceVariant: c.muted,
        surfaceContainerHigh: c.surface,
        outlineVariant: c.line,
      );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: fontFamily,
  );
  final text = base.textTheme.apply(bodyColor: c.ink, displayColor: c.ink);
  final shape14 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  );

  return base.copyWith(
    extensions: [c],
    scaffoldBackgroundColor: c.bg,
    textTheme: text.copyWith(
      headlineLarge: text.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
      ),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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
        fontWeight: FontWeight.w700,
        color: c.ink,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: c.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: c.line, space: 1, thickness: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.chip,
      labelStyle: TextStyle(color: c.muted, fontWeight: FontWeight.w600),
      floatingLabelStyle: TextStyle(
        color: c.accent,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        minimumSize: const Size(44, 48),
        shape: shape14,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: c.accent,
        shape: shape14,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: c.accent,
      foregroundColor: c.onAccent,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      extendedTextStyle: const TextStyle(
        fontFamily: fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.surface,
      indicatorColor: c.accentSoft,
      elevation: 0,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? c.onAccentSoft : c.muted,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: fontFamily,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w600,
          color: s.contains(WidgetState.selected) ? c.onAccentSoft : c.muted,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: shape14,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}
