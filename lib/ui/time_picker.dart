import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/labels.dart';
import 'theme.dart';

/// Günün dilimi; Bugün ekranındaki gruplamayla aynı sınırlar.
String dayPartOf(int minutes) => switch ((minutes ~/ 60) % 24) {
  < 12 => 'Sabah',
  < 17 => 'Öğle',
  < 21 => 'Akşam',
  _ => 'Gece',
};

/// Hızlı seçim çipleri.
const _presets = [
  ('Sabah', 8 * 60),
  ('Öğle', 13 * 60),
  ('Akşam', 19 * 60),
  ('Gece', 22 * 60),
];

/// İki platformda da aynı görünen, alttan açılan saat seçici. Değer gece
/// yarısından itibaren dakika; vazgeçilirse null.
Future<int?> showTimeSheet(
  BuildContext context,
  int minutes, {
  String? title,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  backgroundColor: context.c.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _TimeSheet(initial: minutes, title: title),
);

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({required this.initial, this.title});

  final int initial;
  final String? title;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _minutes = ((widget.initial % 1440) + 1440) % 1440;
  late final _hours = FixedExtentScrollController(initialItem: _minutes ~/ 60);
  late final _mins = FixedExtentScrollController(initialItem: _minutes % 60);

  /// Çip tekerleri döndürürken her adımda titreşim olmasın.
  bool _jumping = false;

  @override
  void dispose() {
    _hours.dispose();
    _mins.dispose();
    super.dispose();
  }

  void _set({int? hour, int? minute}) {
    if (!_jumping) HapticFeedback.selectionClick();
    setState(
      () =>
          _minutes = (hour ?? _minutes ~/ 60) * 60 + (minute ?? _minutes % 60),
    );
  }

  /// Tekerleri en kısa yönden hedefe döndürür (döngülü liste).
  Future<void> _jump(int target) async {
    HapticFeedback.selectionClick();
    final reduce = MediaQuery.disableAnimationsOf(context);
    Future<void> spin(FixedExtentScrollController c, int value, int n) {
      final current = c.selectedItem;
      var delta = (value - current % n) % n;
      if (delta > n ~/ 2) delta -= n;
      if (reduce) {
        c.jumpToItem(current + delta);
        return Future.value();
      }
      return c.animateToItem(
        current + delta,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }

    _jumping = true;
    setState(() => _minutes = target);
    await Future.wait([
      spin(_hours, target ~/ 60, 24),
      spin(_mins, target % 60, 60),
    ]);
    _jumping = false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.title case final title?)
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: c.muted,
              ),
            ),
          const SizedBox(height: 2),
          Semantics(
            liveRegion: true,
            child: Text(
              fmtMinutes(_minutes),
              style: const TextStyle(
                fontSize: 52,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            dayPartOf(_minutes),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.accent,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Seçili satırın zemini; iki teker ortak bir şerit üzerinde.
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.chip,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _Wheel(
                        label: 'Saat',
                        controller: _hours,
                        count: 24,
                        value: _minutes ~/ 60,
                        onChanged: (h) => _set(hour: h),
                      ),
                    ),
                    Text(
                      ':',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    Expanded(
                      child: _Wheel(
                        label: 'Dakika',
                        controller: _mins,
                        count: 60,
                        value: _minutes % 60,
                        onChanged: (m) => _set(minute: m),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (i, (label, value)) in _presets.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _Preset(
                    label: label,
                    minutes: value,
                    selected: _minutes == value,
                    onTap: () => _jump(value),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    backgroundColor: c.chip,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Vazgeç'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, _minutes),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Döngülü sayı tekeri; ekran okuyucuda artır/azalt ile değişir.
class _Wheel extends StatelessWidget {
  const _Wheel({
    required this.label,
    required this.controller,
    required this.count,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int count;
  final int value;
  final ValueChanged<int> onChanged;

  void _step(int by) => controller.animateToItem(
    controller.selectedItem + by,
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: label,
      value: _two(value),
      increasedValue: _two((value + 1) % count),
      decreasedValue: _two((value - 1) % count),
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      child: ExcludeSemantics(
        child: ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 56,
          diameterRatio: 1.4,
          perspective: 0.004,
          overAndUnderCenterOpacity: 0.45,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) => onChanged(i % count),
          childDelegate: ListWheelChildLoopingListDelegate(
            children: [
              for (var i = 0; i < count; i++)
                Center(
                  child: Text(
                    _two(i),
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: i == value
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: i == value ? c.ink : c.muted,
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

class _Preset extends StatelessWidget {
  const _Preset({
    required this.label,
    required this.minutes,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int minutes;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: selected ? c.accent : c.line),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? c.accentSoft : c.surface,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? c.onAccentSoft : c.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fmtMinutes(minutes),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: selected ? c.onAccentSoft : c.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
