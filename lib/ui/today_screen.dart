import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../core/labels.dart';
import '../core/notifications/notification_service.dart';
import '../core/review.dart';
import '../features/schedule/data/schedule_repository.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider);
    final start = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day + 1);
    final doses = ref.watch(doseViewsProvider((start, end)));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              eyebrow: DateFormat('d MMMM, EEEE', 'tr').format(now),
              title: switch (ref.watch(userNameProvider)) {
                final name? => '${_greeting(now)}, $name',
                null => 'Bugün',
              },
              trailing: AddButton(onPressed: () => context.push('/med')),
            ),
            if (ref.watch(notificationsEnabledProvider).value == false)
              const _NotificationsOff(),
            Expanded(
              child: doses.when(
                loading: () => const Loading(),
                error: (e, _) => LoadError(error: e),
                data: (list) => list.isEmpty
                    ? EmptyState(
                        icon: Icons.wb_sunny_outlined,
                        title: 'Bugün için planlı ilaç yok.',
                        message: 'İlaçlar sekmesinden ekleyebilirsin.',
                        action: FilledButton.icon(
                          onPressed: () => context.push('/med'),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('İlk ilacını ekle'),
                        ),
                      )
                    : _DoseList(list: list, now: now),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// İzin kapalıyken hiçbir hatırlatma gelmez; sistem ayarlarına kısayol.
class _NotificationsOff extends StatelessWidget {
  const _NotificationsOff();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: c.note,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: c.line),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: NotificationService.openSettings,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.notifications_off_outlined, color: c.warn),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bildirimler kapalı; ilaç hatırlatmaları gelmez. '
                    'Açmak için dokun.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: c.onNote,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _greeting(DateTime d) => switch (d.hour) {
  >= 5 && < 11 => 'Günaydın',
  >= 11 && < 18 => 'Merhaba',
  _ => 'İyi akşamlar',
};

String _dayPart(DateTime d) => switch (d.hour) {
  < 12 => 'Sabah',
  < 17 => 'Öğle',
  < 21 => 'Akşam',
  _ => 'Gece',
};

class _DoseList extends StatelessWidget {
  const _DoseList({required this.list, required this.now});

  final List<DoseView> list;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = list
        .where((v) => v.status == null && !v.dose.scheduledAt.isBefore(now))
        .firstOrNull;
    final groups = <String, List<DoseView>>{};
    for (final v in list) {
      groups.putIfAbsent(_dayPart(v.dose.scheduledAt), () => []).add(v);
    }
    return ListView(
      padding: listPadding(context),
      children: [
        _Summary(list: list, next: next, now: now),
        for (final e in groups.entries) ...[
          SectionLabel(e.key),
          for (final v in e.value)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DoseCard(view: v, now: now, isNext: identical(v, next)),
            ),
        ],
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.list, required this.next, required this.now});

  final List<DoseView> list;
  final DoseView? next;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final done = list.where((d) => d.status != null).length;
    final late = list
        .where((v) => v.status == null && v.dose.scheduledAt.isBefore(now))
        .length;
    final (title, body) = switch ((done == list.length, late, next)) {
      (true, _, _) => ('Bugünlük tamam', 'Tüm dozlar işaretlendi.'),
      (_, > 0, _) => ('$late doz gecikti', 'Aldıysan işaretlemeyi unutma.'),
      (_, _, final n?) => (
        done == 0 ? 'Güne başlayalım' : 'Güzel gidiyorsun',
        'Sıradaki: ${n.medication.name} · ${fmtTime(n.dose.scheduledAt)}',
      ),
      _ => ('Güzel gidiyorsun', ''),
    };
    return Panel(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: done / list.length,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  color: c.accent,
                  backgroundColor: c.chip,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$done/${list.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      Text(
                        'doz',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: c.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(fontSize: 14, color: c.muted, height: 1.4),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '$done / ${list.length} doz tamamlandı',
                  style: TextStyle(fontSize: 12, color: c.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoseCard extends ConsumerWidget {
  const _DoseCard({
    required this.view,
    required this.now,
    required this.isNext,
  });

  final DoseView view;
  final DateTime now;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(dbProvider);
    final c = context.c;
    final at = view.dose.scheduledAt;
    final overdue = view.status == null && at.isBefore(now);
    final taken = view.status == DoseStatus.taken;
    final skipped = view.status == DoseStatus.skipped;
    final done = taken || skipped;
    final food = foodNote(view.dose.food);
    final med = view.medication;
    final expanded = overdue || isNext;

    Future<void> take() async {
      await markDose(db, view, DoseStatus.taken);
      await maybeRequestReview(db);
    }

    final info = Row(
      children: [
        MedBadge(color: med.color, form: med.form),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                med.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: done ? c.muted : c.ink,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: c.muted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  fmtTime(at),
                  if (med.strength.isNotEmpty) med.strength,
                  if (food.isNotEmpty) food,
                  if (skipped) 'Atlandı',
                ].join(' · '),
                style: TextStyle(fontSize: 13, color: c.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (overdue)
          Tag('Gecikti', color: c.warnSoft, textColor: c.warn)
        else if (isNext)
          Tag(
            _until(at.difference(now)),
            color: c.accentSoft,
            textColor: c.onAccentSoft,
          )
        else if (taken)
          _UndoChip(onTap: () => markDose(db, view, null))
        else if (skipped)
          IconButton(
            tooltip: 'Geri al',
            style: IconButton.styleFrom(
              backgroundColor: c.chip,
              foregroundColor: c.muted,
              fixedSize: const Size(44, 44),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.undo_rounded, size: 20),
            onPressed: () => markDose(db, view, null),
          )
        else
          IconButton.outlined(
            tooltip: 'Aldım',
            style: IconButton.styleFrom(
              foregroundColor: c.ink,
              side: BorderSide(color: c.line, width: 1.5),
              fixedSize: const Size(44, 44),
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.check_rounded, size: 22),
            onPressed: take,
          ),
      ],
    );

    return Panel(
      padding: const EdgeInsets.all(14),
      highlight: isNext,
      color: overdue
          ? Color.alphaBlend(c.warnSoft.withValues(alpha: 0.5), c.surface)
          : null,
      borderColor: overdue ? c.warn.withValues(alpha: 0.35) : null,
      child: !expanded
          ? info
          : Column(
              children: [
                info,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Tooltip(
                        message: 'Atla',
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: c.ink,
                            side: BorderSide(color: c.line),
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: () =>
                              markDose(db, view, DoseStatus.skipped),
                          child: const Text('Atla'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Tooltip(
                        message: 'Aldım',
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                          ),
                          onPressed: take,
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: const Text('Aldım'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  static String _until(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return 'Şimdi';
    if (m < 60) return '$m dk';
    return '${m ~/ 60} sa';
  }
}

class _UndoChip extends StatelessWidget {
  const _UndoChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: 'Geri al',
      child: TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: c.accentSoft,
          foregroundColor: c.onAccentSoft,
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: onTap,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Alındı'),
      ),
    );
  }
}
