import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/labels.dart';
import 'theme.dart';
import 'time_picker.dart';
import 'widgets.dart';

/// iOS ayarlarındaki gibi gruplu bölüm: üstte başlık, altta açıklama.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    this.header,
    this.action,
    this.footer,
    required this.children,
  });

  final String? header;

  /// Başlığın sağındaki küçük eylem ("Sil" gibi).
  final Widget? action;
  final Widget? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (header != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: SectionLabel(header!)),
            ?action,
          ],
        )
      else
        const SizedBox(height: 20),
      GroupPanel(children: children),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: footer,
        ),
    ],
  );
}

/// Bölümün altındaki gri açıklama ya da kırmızı hata metni.
class FormNote extends StatelessWidget {
  const FormNote(this.text, {super.key, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 13,
      height: 1.35,
      color: error ? Theme.of(context).colorScheme.error : context.c.muted,
    ),
  );
}

/// Çerçevesiz metin alanı satırı. [label] verilirse solda başlık, sağda
/// sağa yaslı alan olur (iOS Kişiler'deki gibi).
class FieldRow extends StatelessWidget {
  const FieldRow({
    super.key,
    required this.controller,
    required this.placeholder,
    this.label,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.maxLength,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
    this.trailing,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String placeholder;
  final String? label;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final int? maxLength;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final align = label == null ? TextAlign.start : TextAlign.end;
    const style = TextStyle(
      fontFamily: fontFamily,
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );
    final hint = style.copyWith(color: c.muted.withValues(alpha: 0.7));
    final formatters = [
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
    ];
    final field = isApple(context)
        ? CupertinoTextField.borderless(
            controller: controller,
            placeholder: placeholder,
            placeholderStyle: hint,
            style: style.copyWith(color: c.ink),
            padding: EdgeInsets.zero,
            textAlign: align,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            minLines: 1,
            inputFormatters: formatters,
            cursorColor: c.accent,
            onChanged: onChanged,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autofocus: autofocus,
          )
        : TextField(
            controller: controller,
            // Temanın odak çerçevesi kenarlıksız satıra sızmasın.
            decoration: InputDecoration.collapsed(
              hintText: placeholder,
              hintStyle: hint,
            ).copyWith(focusedBorder: InputBorder.none),
            style: style.copyWith(color: c.ink),
            textAlign: align,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            maxLines: maxLines,
            minLines: 1,
            inputFormatters: formatters,
            onChanged: onChanged,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autofocus: autofocus,
          );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (label != null) ...[
              Text(label!, style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 16),
            ],
            Expanded(child: field),
            if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Sağda seçili değeri gösteren, dokununca menü açan satır.
class MenuRow<T> extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String title;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  State<MenuRow<T>> createState() => _MenuRowState<T>();
}

class _MenuRowState<T> extends State<MenuRow<T>> {
  final _menu = MenuController();

  @override
  Widget build(BuildContext context) => PanelRow(
    title: widget.title,
    // Satırın herhangi bir yerine dokunmak da menüyü açar.
    onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
    trailing: MenuButton<T>(
      controller: _menu,
      value: widget.value,
      options: widget.options,
      onChanged: widget.onChanged,
    ),
  );
}

/// "değer ⌃⌄" etiketi ve menüsü. iOS'ta yerel açılır menü, Android'de
/// Material menü.
class MenuButton<T> extends StatefulWidget {
  const MenuButton({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.controller,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  final MenuController? controller;

  @override
  State<MenuButton<T>> createState() => _MenuButtonState<T>();
}

class _MenuButtonState<T> extends State<MenuButton<T>> {
  final _own = MenuController();

  MenuController get _menu => widget.controller ?? _own;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final apple = isApple(context);
    final label = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _menu.isOpen ? _menu.close() : _menu.open(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.options[widget.value] ?? '',
            style: TextStyle(fontSize: 15, color: c.muted),
          ),
          const SizedBox(width: 6),
          Icon(
            apple
                ? CupertinoIcons.chevron_up_chevron_down
                : Icons.unfold_more_rounded,
            size: 15,
            color: c.muted,
          ),
        ],
      ),
    );
    final entries = widget.options.entries;
    if (apple) {
      return CupertinoMenuAnchor(
        controller: _menu,
        // iOS'ta dışarıya dokunmak yalnızca menüyü kapatır.
        consumeOutsideTaps: true,
        menuChildren: [
          for (final e in entries)
            CupertinoMenuItem(
              leading: e.key == widget.value
                  ? const Icon(CupertinoIcons.checkmark, size: 17)
                  : null,
              onPressed: () => widget.onChanged(e.key),
              child: Text(e.value),
            ),
        ],
        child: label,
      );
    }
    return MenuAnchor(
      controller: _menu,
      alignmentOffset: const Offset(0, 4),
      menuChildren: [
        for (final e in entries)
          MenuItemButton(
            leadingIcon: Icon(
              Icons.check_rounded,
              size: 18,
              color: e.key == widget.value ? c.ink : Colors.transparent,
            ),
            onPressed: () => widget.onChanged(e.key),
            child: Text(e.value),
          ),
      ],
      child: label,
    );
  }
}

/// Saat satırı; değer gece yarısından itibaren dakika. İki platformda da
/// aynı saat seçici açılır (bkz. [showTimeSheet]).
class TimeRow extends StatelessWidget {
  const TimeRow({
    super.key,
    required this.title,
    required this.minutes,
    required this.onChanged,
  });

  final String title;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => PanelRow(
    title: title,
    onTap: () async {
      final m = await showTimeSheet(context, minutes, title: title);
      if (m != null) onChanged(m);
    },
    trailing: _ValueBox(
      label: fmtMinutes(minutes),
      semantics: 'Saat ${fmtMinutes(minutes)}',
    ),
  );
}

/// Tarih satırı. iOS'un sıkışık tarih seçicisi gibi: dokununca çark satırın
/// altında açılır. Android'de sistem diyaloğu açılır.
class DateRow extends StatefulWidget {
  const DateRow({
    super.key,
    required this.title,
    required this.date,
    required this.onChanged,
  });

  final String title;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  State<DateRow> createState() => _DateRowState();
}

class _DateRowState extends State<DateRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final apple = isApple(context);
    void tap() => apple
        ? setState(() => _open = !_open)
        : pickDate(context, widget.date).then((d) {
            if (d != null) widget.onChanged(d);
          });
    return Column(
      children: [
        PanelRow(
          title: widget.title,
          onTap: tap,
          trailing: _ValueBox(
            label: DateFormat('d MMM y', 'tr').format(widget.date),
            active: _open,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: _open
              ? SizedBox(
                  height: 216,
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: widget.date,
                    minimumDate: DateTime(2020),
                    maximumDate: DateTime(2100),
                    onDateTimeChanged: (d) =>
                        widget.onChanged(DateTime(d.year, d.month, d.day)),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Satırın sağındaki gri kutuda değer.
class _ValueBox extends StatelessWidget {
  const _ValueBox({required this.label, this.semantics, this.active = false});

  final String label;
  final String? semantics;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: c.chip,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        semanticsLabel: semantics,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: active ? c.accent : c.ink,
        ),
      ),
    );
  }
}

/// Sağında anahtar olan satır.
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => PanelRow(
    title: title,
    onTap: () => onChanged(!value),
    trailing: Switch.adaptive(
      value: value,
      activeTrackColor: context.c.accent,
      onChanged: onChanged,
    ),
  );
}
