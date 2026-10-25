import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/labels.dart';
import '../features/schedule/data/schedule_repository.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

const _days = 14;

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final from = DateTime(now.year, now.month, now.day - (_days - 1));
    // Anahtar gün içinde sabit kalmalı; yoksa her çizimde yeni sorgu açılır.
    final to = DateTime(now.year, now.month, now.day + 1);
    final doses = ref.watch(doseViewsProvider((from, to)));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const PageHeader(eyebrow: 'Son $_days gün', title: 'Geçmiş'),
            Expanded(
              child: doses.when(
                loading: () => const Loading(),
                error: (e, _) => LoadError(error: e),
                data: (all) {
                  final list = [
                    for (final v in all)
                      if (v.dose.scheduledAt.isBefore(now)) v,
                  ];
                  if (list.isEmpty) {
                    return const EmptyState(
                      icon: Icons.bar_chart_rounded,
                      title: 'Son $_days günde kayıt yok.',
                      message:
                          'Dozlarını işaretledikçe uyum oranın burada görünür.',
                    );
                  }
                  final byDay = <DateTime, List<DoseView>>{};
                  for (final v in list) {
                    final s = v.dose.scheduledAt;
                    byDay
                        .putIfAbsent(DateTime(s.year, s.month, s.day), () => [])
                        .add(v);
                  }
                  final days = byDay.keys.toList()
                    ..sort((a, b) => b.compareTo(a));
                  return ListView(
                    padding: listPadding(context),
                    children: [
                      _AdherenceCard(list: list, byDay: byDay, now: now),
                      for (final day in days) ...[
                        SectionLabel(
                          DateFormat('d MMMM, EEEE', 'tr').format(day),
                        ),
                        GroupPanel(
                          children: [
                            for (final v in byDay[day]!) _row(context, v),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, DoseView v) {
    final c = context.c;
    final (icon, bg, fg, label) = switch (v.status) {
      DoseStatus.taken => (
        Icons.check_rounded,
        c.accentSoft,
        c.onAccentSoft,
        'Alındı',
      ),
      DoseStatus.skipped => (Icons.remove_rounded, c.chip, c.muted, 'Atlandı'),
      null => (Icons.priority_high_rounded, c.warnSoft, c.warn, 'Kaçırıldı'),
    };
    final missed = v.status == null;
    return PanelRow(
      leading: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: fg),
      ),
      title: v.medication.name,
      trailing: Text(
        '${fmtTime(v.dose.scheduledAt)} · $label',
        style: TextStyle(
          fontSize: 13,
          fontWeight: missed ? FontWeight.w600 : FontWeight.w500,
          color: missed ? c.warn : c.muted,
        ),
      ),
    );
  }
}

class _AdherenceCard extends StatelessWidget {
  const _AdherenceCard({
    required this.list,
    required this.byDay,
    required this.now,
  });

  final List<DoseView> list;
  final Map<DateTime, List<DoseView>> byDay;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final taken = list.where((d) => d.status == DoseStatus.taken).length;
    final pct = (taken * 100 / list.length).round();
    final week = [
      for (var i = 6; i >= 0; i--) DateTime(now.year, now.month, now.day - i),
    ];
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uyum oranı',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.muted,
                      ),
                    ),
                    Text(
                      '%$pct',
                      style: const TextStyle(
                        fontSize: 40,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$taken / ${list.length} doz\nalındı',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 72,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in week) ...[
                  if (d != week.first) const SizedBox(width: 8),
                  Expanded(child: _bar(d, c)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in week) ...[
                if (d != week.first) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d == week.last ? 'Bugün' : weekdayShort[d.weekday - 1],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: d == week.last
                          ? FontWeight.w600
                          : FontWeight.w500,
                      color: d == week.last ? c.ink : c.muted,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Günün oranı: gri ray üstünde alttan dolan vurgu çubuğu.
  Widget _bar(DateTime d, AppColors c) {
    final items = byDay[d] ?? const <DoseView>[];
    final ratio = items.isEmpty
        ? 0.0
        : items.where((v) => v.status == DoseStatus.taken).length /
              items.length;
    return LayoutBuilder(
      builder: (_, box) => Container(
        height: box.maxHeight,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: c.chip,
          borderRadius: BorderRadius.circular(6),
        ),
        child: ratio == 0
            ? null
            : Container(
                height: (box.maxHeight * ratio).clamp(6, box.maxHeight),
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
      ),
    );
  }
}
