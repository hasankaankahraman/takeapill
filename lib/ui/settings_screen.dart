import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/labels.dart';
import '../core/notifications/notification_planner.dart';
import '../core/notifications/notification_service.dart';
import '../core/settings_store.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'providers.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  MealTimes? _meals;
  NotificationPrefs? _prefs;
  bool _exactAlarms = true;

  /// İzin sistem ayarlarından açılıp dönülürse uyarı kalksın.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshExactAlarms);
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refreshExactAlarms() async {
    final exact = await NotificationService.exactAlarmsAllowed();
    if (mounted && exact != _exactAlarms) setState(() => _exactAlarms = exact);
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final m = await db.loadMealTimes();
    final p = await db.loadNotificationPrefs();
    final exact = await NotificationService.exactAlarmsAllowed();
    if (!mounted) return;
    setState(() {
      _meals = m;
      _prefs = p;
      _exactAlarms = exact;
    });
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _saveMeals(MealTimes m) async {
    setState(() => _meals = m);
    final db = ref.read(dbProvider);
    await db.saveMealTimes(m);
    await trySyncNotifications(db);
  }

  Future<void> _savePrefs(NotificationPrefs p) async {
    setState(() => _prefs = p);
    final db = ref.read(dbProvider);
    await db.saveNotificationPrefs(p);
    await trySyncNotifications(db);
  }

  Future<void> _pick(int current, void Function(int) set) async {
    final m = await pickMinutes(context, current);
    if (m != null) set(m);
  }

  @override
  Widget build(BuildContext context) {
    final m = _meals;
    final p = _prefs;
    if (m == null || p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final c = context.c;
    Widget meal(String title, int value, MealTimes Function(int) copy) =>
        PanelRow(
          title: title,
          trailing: Tag(fmtMinutes(value)),
          onTap: () => _pick(value, (v) => _saveMeals(copy(v))),
        );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const PageHeader(title: 'Ayarlar'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionLabel(
                    'Görünüm',
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                  ),
                  Segmented<ThemeMode>(
                    options: const {
                      ThemeMode.system: 'Sistem',
                      ThemeMode.light: 'Açık',
                      ThemeMode.dark: 'Koyu',
                    },
                    selected: ref.watch(themeModeProvider),
                    onChanged: (v) =>
                        ref.read(themeModeProvider.notifier).set(v),
                  ),
                  const SectionLabel('Günlük rutin'),
                  GroupPanel(
                    children: [
                      meal('Uyanma', m.wake, (v) => m.copyWith(wake: v)),
                      meal(
                        'Kahvaltı',
                        m.breakfast,
                        (v) => m.copyWith(breakfast: v),
                      ),
                      meal('Öğle yemeği', m.lunch, (v) => m.copyWith(lunch: v)),
                      meal(
                        'Akşam yemeği',
                        m.dinner,
                        (v) => m.copyWith(dinner: v),
                      ),
                      meal('Yatma', m.bedtime, (v) => m.copyWith(bedtime: v)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      '"Kahvaltıda" gibi zamanlanan ilaçlar bu saatlere göre hatırlatılır.',
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  ),
                  const SectionLabel('Bildirimler'),
                  GroupPanel(
                    children: [
                      _minutesTile(
                        'Önceden haber ver',
                        p.leadMinutes,
                        const [0, 2, 5, 10, 15],
                        (v) => _savePrefs(p.copyWith(lead: v)),
                        zeroLabel: 'Kapalı',
                      ),
                      _minutesTile(
                        'Alınmadıysa tekrar hatırlat',
                        p.nagMinutes,
                        const [0, 5, 10, 15, 30],
                        (v) => _savePrefs(p.copyWith(nag: v)),
                        zeroLabel: 'Kapalı',
                      ),
                      _minutesTile('Erteleme süresi', p.snoozeMinutes, const [
                        5,
                        10,
                        15,
                        30,
                      ], (v) => _savePrefs(p.copyWith(snooze: v))),
                      PanelRow(
                        leading: Icon(
                          Icons.notifications_active_outlined,
                          color: c.muted,
                        ),
                        title: 'Bildirim iznini kontrol et',
                        trailing: Icon(
                          Icons.chevron_right_rounded,
                          color: c.muted,
                        ),
                        onTap: () async {
                          final ok =
                              await NotificationService.requestPermissions();
                          await _refreshExactAlarms();
                          if (!mounted) return;
                          // Alarm izni yeni açıldıysa plan tam zamanlıya geçsin.
                          await trySyncNotifications(ref.read(dbProvider));
                          if (!mounted) return;
                          _snack(
                            ok ? 'Bildirimlere izin verildi.' : 'İzin verilmedi. Sistem ayarlarından açabilirsin.',
                          );
                        },
                      ),
                      PanelRow(
                        leading: Icon(Icons.sync_rounded, color: c.muted),
                        title: 'Bildirimleri yeniden planla',
                        onTap: () async {
                          var ok = true;
                          try {
                            await syncNotifications(ref.read(dbProvider));
                          } catch (e) {
                            debugPrint('Yeniden planlama hatası: $e');
                            ok = false;
                          }
                          if (!mounted) return;
                          _snack(
                            ok
                                ? 'Bildirimler yeniden planlandı.'
                                : 'Bildirimler planlanamadı. Tekrar dene.',
                          );
                        },
                      ),
                    ],
                  ),
                  if (!_exactAlarms)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                      child: Text(
                        '"Alarmlar ve hatırlatıcılar" izni kapalı; hatırlatmalar '
                        'birkaç dakika gecikebilir. Açmak için "Bildirim iznini '
                        'kontrol et"e dokun.',
                        style: TextStyle(fontSize: 12, color: c.warn),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.note,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Bu uygulama bir hatırlatma aracıdır; tıbbi tavsiye vermez. '
                      'İlaç kullanımınla ilgili kararları doktorun veya eczacınla ver. '
                      'Verilerin yalnızca bu cihazda saklanır.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: c.onNote,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _minutesTile(
    String title,
    int value,
    List<int> options,
    void Function(int) onChanged, {
    String? zeroLabel,
  }) {
    final c = context.c;
    // Kayıtlı değer seçenekler dışındaysa yanlış göstermemek için listeye eklenir.
    final values = [...options, if (!options.contains(value)) value]..sort();
    return PanelRow(
      title: title,
      trailing: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(14),
        icon: Icon(Icons.expand_more_rounded, color: c.accent),
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: c.accent,
        ),
        items: [
          for (final o in values)
            DropdownMenuItem(
              value: o,
              child: Text(o == 0 ? (zeroLabel ?? '0') : '$o dk'),
            ),
        ],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }
}
