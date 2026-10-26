import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'med_icons.dart';
import 'theme.dart';

/// Android takvim diyaloğu.
Future<DateTime?> pickDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

/// Türkçe büyük harf: "i" → "İ", "ı" → "I" (Dart'ın toUpperCase'i bilmez).
String upperTr(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Onay penceresi; iOS'ta Cupertino uyarısı olarak açılır.
Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirm,
  bool destructive = false,
}) {
  final apple = isApple(context);
  final c = context.c;
  final error = Theme.of(context).colorScheme.error;
  Widget action(
    BuildContext dc,
    String label,
    bool value, {
    bool main = false,
  }) => apple
      ? CupertinoDialogAction(
          isDestructiveAction: main && destructive,
          isDefaultAction: !main,
          onPressed: () => Navigator.pop(dc, value),
          child: Text(label),
        )
      : TextButton(
          style: main && destructive
              ? TextButton.styleFrom(foregroundColor: error)
              : null,
          onPressed: () => Navigator.pop(dc, value),
          child: Text(label),
        );
  return showAdaptiveDialog<bool>(
    context: context,
    builder: (dc) => AlertDialog.adaptive(
      title: Text(title),
      content: Text(message, style: apple ? null : TextStyle(color: c.muted)),
      actions: [
        action(dc, 'Vazgeç', false),
        action(dc, confirm, true, main: true),
      ],
    ),
  );
}

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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bilgi satırı boşken de yeri korunur; sekmeler arasında
                // başlık ve buton aynı pikselde kalsın.
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    upperTr(eyebrow ?? ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                      color: c.muted,
                    ),
                  ),
                ),
                // Uzun başlık ("İyi akşamlar, Zeynep") tek satıra sığsın diye
                // küçülür; buton ve liste yerinden oynamaz.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.headlineLarge
                        ?.copyWith(fontSize: 32, height: 1.15),
                  ),
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

/// Başlık satırındaki yuvarlak "ilaç ekle" butonu.
class AddButton extends StatelessWidget {
  const AddButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return IconButton.filled(
      tooltip: 'İlaç ekle',
      style: IconButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        fixedSize: const Size(44, 44),
        shape: const CircleBorder(),
      ),
      icon: Icon(isApple(context) ? CupertinoIcons.add : Icons.add_rounded),
      onPressed: onPressed,
    );
  }
}

/// Sekme ekranlarındaki listelerin altı; yüzen menünün altında kalmasın.
EdgeInsets listPadding(BuildContext context, {double top = 0}) =>
    EdgeInsets.fromLTRB(20, top, 20, 24 + MediaQuery.paddingOf(context).bottom);

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.padding});

  final String text;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding ?? const EdgeInsets.fromLTRB(4, 24, 4, 10),
    child: Text(
      upperTr(text),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: context.c.muted,
      ),
    ),
  );
}

/// İnce çerçeveli yüzey.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.onTap,
    this.highlight = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: color ?? c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: highlight
            ? BorderSide(color: c.accent, width: 1.5)
            : BorderSide(color: borderColor ?? c.line),
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
          if (i > 0) const Divider(indent: 16),
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
                  fontWeight: FontWeight.w500,
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
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: textColor ?? context.c.ink,
      ),
    ),
  );
}

/// İlacın renkli ikon kutusu; ikon ilacın formundan gelir.
class MedBadge extends StatelessWidget {
  const MedBadge({
    super.key,
    required this.color,
    this.form = 'pill',
    this.size = 44,
  });

  final int color;
  final String form;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = medTint(context, color);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: MedFormIcon(form: form, color: fg, size: size * 0.55),
    );
  }
}

/// Seçili öğesi beyaz "kaydırıcı" olan bölümlü seçici.
class Segmented<T extends Object> extends StatelessWidget {
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
    if (isApple(context)) {
      return CupertinoSlidingSegmentedControl<T>(
        groupValue: selected,
        backgroundColor: Color.alphaBlend(c.ink.withValues(alpha: 0.06), c.bg),
        thumbColor: dark ? c.chip : c.surface,
        padding: const EdgeInsets.all(3),
        onValueChanged: (v) {
          if (v != null) onChanged(v);
        },
        children: {
          for (final e in options.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: e.key == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: c.ink,
                ),
              ),
            ),
        },
      );
    }
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(c.ink.withValues(alpha: 0.06), c.bg),
        borderRadius: BorderRadius.circular(12),
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
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e.key == selected
                          ? (dark ? c.chip : c.surface)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: e.key == selected && !dark
                          ? const [
                              BoxShadow(
                                color: Color(0x14000000),
                                blurRadius: 4,
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
                            ? FontWeight.w600
                            : FontWeight.w500,
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
    final shape = circle
        ? CircleBorder(side: BorderSide(color: selected ? c.primary : c.line))
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: selected ? c.primary : c.line),
          );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.primary : c.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Container(
            height: circle ? 40 : 36,
            width: circle ? 40 : null,
            padding: circle ? null : const EdgeInsets.symmetric(horizontal: 14),
            // widthFactor: Wrap içinde satırın tamamına yayılmasın.
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: circle ? 12 : 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? c.onPrimary : c.ink,
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
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.line),
              ),
              child: Icon(icon, size: 28, color: c.ink),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.muted, height: 1.45),
            ),
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Platforma uygun yükleniyor göstergesi.
class Loading extends StatelessWidget {
  const Loading({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

/// Veri yüklenemediğinde; ham hata metni kullanıcıya gösterilmez.
class LoadError extends StatelessWidget {
  const LoadError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    debugPrint('Yükleme hatası: $error');
    return const EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Bir şeyler ters gitti.',
      message: 'Veriler yüklenemedi. Uygulamayı kapatıp yeniden açmayı dene.',
    );
  }
}
