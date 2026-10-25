import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/labels.dart';
import '../core/notifications/notification_service.dart';
import '../features/schedule/data/schedule_repository.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

class MedicationsScreen extends ConsumerStatefulWidget {
  const MedicationsScreen({super.key});

  @override
  ConsumerState<MedicationsScreen> createState() => _MedicationsState();
}

class _MedicationsState extends ConsumerState<MedicationsScreen> {
  /// Kaydırılıp silinen satırlar, DB akışı yenilenene kadar gizli tutulur;
  /// Dismissible kapandıktan sonra ağaçta kalırsa Flutter hata verir.
  final _removed = <int>{};

  Future<void> _delete(int id) async {
    setState(() => _removed.add(id));
    final db = ref.read(dbProvider);
    await db.deleteMedication(id);
    await trySyncNotifications(db);
  }

  Future<bool?> _confirmDelete(String name) {
    final c = context.c;
    final error = Theme.of(context).colorScheme.error;
    return showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: Text('$name silinsin mi?'),
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
            style: TextButton.styleFrom(foregroundColor: error),
            onPressed: () => Navigator.pop(dc, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(medicationPlansProvider);
    final visible = data.value?.$1
        .where((p) => !_removed.contains(p.medication.id))
        .toList();
    final scheme = Theme.of(context).colorScheme;
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
              eyebrow: switch (visible) {
                final l? when l.isNotEmpty => '${l.length} aktif ilaç',
                _ => null,
              },
              title: 'İlaçlarım',
            ),
            Expanded(
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => LoadError(error: e),
                data: (d) => visible!.isEmpty
                    ? const EmptyState(
                        icon: Icons.medication_outlined,
                        title: 'Henüz ilaç eklenmedi.',
                        message:
                            'Sağ alttaki butonla ilk ilacını ekle; saatini ve '
                            'yemekle ilişkisini birlikte ayarlayalım.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final p = visible[i];
                          final m = p.medication;
                          return Dismissible(
                            key: ValueKey(m.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: scheme.error,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: scheme.onError,
                              ),
                            ),
                            confirmDismiss: (_) => _confirmDelete(m.name),
                            onDismissed: (_) => _delete(m.id),
                            child: _MedTile(plan: p, meals: d.$2),
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

class _MedTile extends StatelessWidget {
  const _MedTile({required this.plan, required this.meals});

  final MedicationPlan plan;
  final MealTimes meals;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final m = plan.medication;
    final rule = plan.rule;
    final (summary, times, food) = switch (rule) {
      DailyRule() => (
        'Günde ${rule.slots.length} kez',
        [for (final s in rule.slots) fmtMinutes(s.minutesOn(meals))],
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
                  [if (m.purpose.isNotEmpty) m.purpose, summary].join(' · '),
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
  }
}
