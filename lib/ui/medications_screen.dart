import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/notification_service.dart';
import '../core/settings_store.dart';
import '../features/schedule/domain/rule_codec.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'labels.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

class MedicationsScreen extends ConsumerWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meds = ref.watch(medicationsProvider);
    final c = context.c;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/med'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('İlaç ekle'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            PageHeader(
              eyebrow: meds.whenOrNull(
                data: (l) => l.isEmpty ? null : '${l.length} aktif ilaç',
              ),
              title: 'İlaçlarım',
            ),
            Expanded(
              child: meds.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (list) => list.isEmpty
                    ? const EmptyState(
                        icon: Icons.medication_outlined,
                        title: 'Henüz ilaç eklenmedi.',
                        message:
                            'Sağ alttaki butonla ilk ilacını ekle; saatini ve '
                            'yemekle ilişkisini birlikte ayarlayalım.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final m = list[i];
                          return Dismissible(
                            key: ValueKey(m.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            confirmDismiss: (_) => showDialog<bool>(
                              context: context,
                              builder: (dc) => AlertDialog(
                                title: Text('${m.name} silinsin mi?'),
                                content: Text(
                                  'İlaç, planı ve geçmiş kayıtları kalıcı olarak silinir.',
                                  style: TextStyle(color: c.muted),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dc, false),
                                    child: const Text('Vazgeç'),
                                  ),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                    onPressed: () => Navigator.pop(dc, true),
                                    child: const Text('Sil'),
                                  ),
                                ],
                              ),
                            ),
                            onDismissed: (_) async {
                              final db = ref.read(dbProvider);
                              await db.deleteMedication(m.id);
                              await syncNotifications(db);
                            },
                            child: _MedTile(medId: m.id),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedTile extends ConsumerWidget {
  const _MedTile({required this.medId});

  final int medId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final c = context.c;
    return FutureBuilder(
      future: () async {
        final r = await db.medicationWithRule(medId);
        if (r == null) return null;
        return (r.$1, decodeRule(r.$2), await db.loadMealTimes());
      }(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null) return const SizedBox(height: 80);
        final (m, rule, meals) = data;
        final (summary, times, food) = switch (rule) {
          DailyRule() => (
            rule.slots.length == 1
                ? 'Günde 1 kez'
                : 'Günde ${rule.slots.length} kez',
            [for (final s in rule.slots) _slotTime(s, meals)],
            rule.slots
                .map((s) => s.food)
                .firstWhere(
                  (f) => f != FoodRelation.none,
                  orElse: () => FoodRelation.none,
                ),
          ),
          IntervalRule() => (
            'Her ${rule.everyHours} saatte bir',
            [fmtMinutes(rule.firstMinutes)],
            rule.food,
          ),
          AsNeededRule() => (
            rule.maxPerDay == null
                ? 'Gerektiğinde'
                : 'Gerektiğinde, günde en fazla ${rule.maxPerDay}',
            <String>[],
            FoodRelation.none,
          ),
        };
        return Panel(
          onTap: () => context.push('/med?id=${m.id}'),
          child: Row(
            children: [
              MedBadge(color: m.color, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: m.name,
                        children: [
                          if (m.strength.isNotEmpty)
                            TextSpan(
                              text: ' ${m.strength}',
                              style: TextStyle(
                                color: c.muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (m.purpose.isNotEmpty) m.purpose,
                        summary,
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, color: c.muted),
                    ),
                    if (times.isNotEmpty || food != FoodRelation.none) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final t in times) Tag(t),
                          if (food != FoodRelation.none)
                            Text(
                              foodLabels[food]!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: c.muted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.muted),
            ],
          ),
        );
      },
    );
  }

  static String _slotTime(DoseSlot s, MealTimes meals) =>
      s.anchor == TimingAnchor.fixed
      ? fmtMinutes(s.fixedMinutes)
      : fmtMinutes(meals.minutesFor(s.anchor) + s.offsetMinutes);
}
