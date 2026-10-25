import 'package:flutter/material.dart';

import 'theme.dart';

/// Sekme ekranlarının büyük başlığı: üstte küçük harfli bilgi, altında başlık.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null)
                  Text(
                    eyebrow!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: c.muted,
                    ),
                  ),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(fontSize: 30),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(4, 20, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: context.c.muted,
      ),
    ),
  );
}

/// Yuvarlatılmış beyaz yüzey.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.onTap,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(20);
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: highlight
            ? BorderSide(color: c.accent, width: 2)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Satırların arasına ince çizgi koyan gruplu liste kartı.
class GroupPanel extends StatelessWidget {
  const GroupPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Panel(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const Divider(indent: 16, endIndent: 16),
          children[i],
        ],
      ],
    ),
  );
}

/// Gruplu kart içindeki satır.
class PanelRow extends StatelessWidget {
  const PanelRow({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    ),
  );
}

/// Küçük gri etiket ("08:00" gibi).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color, this.textColor});

  final String text;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color ?? context.c.chip,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: textColor ?? context.c.ink,
      ),
    ),
  );
}

/// İlacın renkli ikon kutusu.
class MedBadge extends StatelessWidget {
  const MedBadge({super.key, required this.color, this.size = 44});

  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = medTint(context, color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(Icons.medication_rounded, color: fg, size: size * 0.52),
    );
  }
}

/// Seçili öğesi beyaz "kaydırıcı" olan bölümlü seçici.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dark ? c.chip : const Color(0xFFE9EBF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: Semantics(
                button: true,
                selected: e.key == selected,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == selected
                          ? (dark ? c.surface : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: e.key == selected && !dark
                          ? const [
                              BoxShadow(
                                color: Color(0x1A12131A),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      e.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: e.key == selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: e.key == selected ? c.ink : c.muted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Seçilebilir yuvarlak köşeli küçük buton (ilaç formu vb.).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.circle = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.accent : c.chip,
        shape: circle
            ? const CircleBorder()
            : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          customBorder: circle ? const CircleBorder() : null,
          borderRadius: circle ? null : BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            height: circle ? 42 : 38,
            width: circle ? 42 : null,
            padding: circle ? null : const EdgeInsets.symmetric(horizontal: 14),
            // widthFactor: Wrap içinde satırın tamamına yayılmasın.
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: circle ? 12 : 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? c.onAccent : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 34, color: c.onAccentSoft),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.muted, height: 1.4),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}
