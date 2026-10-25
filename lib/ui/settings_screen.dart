import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notifications/notification_planner.dart';
import '../core/notifications/notification_service.dart';
import '../core/review.dart';
import '../core/settings_store.dart';
import '../features/schedule/domain/schedule_models.dart';
import 'form_rows.dart';
import 'permission_prompts.dart';
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
  bool _notificationsOn = true;

  /// iOS AlarmKit izni (bkz. [NotificationService.callAlarmState]).
  String? _alarmState;

  /// İzin sistem ayarlarından açılıp dönülürse uyarı kalksın.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshPermissions);
    _load();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refreshPermissions() async {
    final exact = await NotificationService.exactAlarmsAllowed();
    final alarm = await NotificationService.callAlarmState();
    final on = await NotificationService.notificationsEnabled();
    if (!mounted ||
        (exact == _exactAlarms &&
            alarm == _alarmState &&
            on == _notificationsOn)) {
      return;
    }
    setState(() {
      _exactAlarms = exact;
      _alarmState = alarm;
      _notificationsOn = on;
    });
    // Alarm izni sistem ayarlarından açıldıysa aramalar alarma geçsin.
    await trySyncNotifications(ref.read(dbProvider));
  }

  Future<void> _load() async {
    final db = ref.read(dbProvider);
    final m = await db.loadMealTimes();
    final p = await db.loadNotificationPrefs();
    final exact = await NotificationService.exactAlarmsAllowed();
    final alarm = await NotificationService.callAlarmState();
    final on = await NotificationService.notificationsEnabled();
    if (!mounted) return;
    setState(() {
      _meals = m;
      _prefs = p;
      _exactAlarms = exact;
      _alarmState = alarm;
      _notificationsOn = on;
    });
  }

  void _snack(String text, {SnackBarAction? action}) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text), action: action));

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

  @override
  Widget build(BuildContext context) {
    final m = _meals;
    final p = _prefs;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Başlık diğer sekmelerdeki gibi sabit; yalnızca içerik kayar.
            const PageHeader(title: 'Ayarlar'),
            Expanded(
              child: m == null || p == null ? const Loading() : _content(m, p),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content(MealTimes m, NotificationPrefs p) {
    final c = context.c;
    Widget meal(String title, int value, MealTimes Function(int) copy) =>
        TimeRow(
          title: title,
          minutes: value,
          onChanged: (v) => _saveMeals(copy(v)),
        );

    return ListView(
      padding: EdgeInsets.only(
        bottom: 32 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
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
                onChanged: (v) => ref.read(themeModeProvider.notifier).set(v),
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
                  meal('Akşam yemeği', m.dinner, (v) => m.copyWith(dinner: v)),
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
                  MenuRow<bool>(
                    title: 'Hatırlatma şekli',
                    value: p.callMode,
                    options: const {false: 'Bildirim', true: 'Arama'},
                    onChanged: (v) async {
                      // Önce izin: plan, izne göre alarm ya da bildirimle kurulur.
                      if (v) await NotificationService.requestCallPermission();
                      await _savePrefs(p.copyWith(call: v));
                      await _refreshPermissions();
                    },
                  ),
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
                    trailing: Icon(Icons.chevron_right_rounded, color: c.muted),
                    onTap: () async {
                      final ok = await NotificationService.requestPermissions();
                      if (ok && mounted) await askExactAlarms(context);
                      await _refreshPermissions();
                      if (!mounted) return;
                      // Alarm izni yeni açıldıysa plan tam zamanlıya geçsin.
                      await trySyncNotifications(ref.read(dbProvider));
                      if (!mounted) return;
                      // Reddedilen izin için pencere bir daha çıkmayabilir.
                      _snack(
                        ok
                            ? 'Bildirimlere izin verildi.'
                            : 'Bildirim izni kapalı.',
                        action: ok
                            ? null
                            : const SnackBarAction(
                                label: 'Ayarları aç',
                                onPressed: NotificationService.openSettings,
                              ),
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
              if (!_notificationsOn)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Bildirimler kapalı; ilaç hatırlatmaları gelmez. Açmak '
                    'için "Bildirim iznini kontrol et"e dokun.',
                    style: TextStyle(fontSize: 12, color: c.warn),
                  ),
                ),
              if (p.callMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    [
                      'İlaç saatinde telefonun arama gibi çalar. Kabul edersen '
                          'uygulama açılır, reddedersen ertelenir.',
                      // iOS'taki sınırlar aşağıda, alarm iznine göre yazılır.
                      if (!isApple(context))
                        'Telefon sessizdeyken de alarm sesiyle çalar; bir '
                            'dakika içinde yanıtlanmazsa susar.',
                    ].join(' '),
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
                ),
              if (p.callMode && _alarmState == 'denied')
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Alarm izni kapalı; arama Dynamic Island yerine bildirim '
                    'olarak gelir ve sessiz modda çalmaz. Açmak için: iPhone '
                    'Ayarları › Take a Pill › Alarmlar.',
                    style: TextStyle(fontSize: 12, color: c.warn),
                  ),
                ),
              if (p.callMode && _alarmState == 'unsupported')
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    'Dynamic Island\'da arama için iOS 26 gerekir; bu cihazda '
                    'arama, zil sesli bildirim olarak gelir ve sessiz modda '
                    'çalmaz.',
                    style: TextStyle(fontSize: 12, color: c.muted),
                  ),
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
              if (canOpenStoreListing) ...[
                const SectionLabel('Destek'),
                GroupPanel(
                  children: [
                    PanelRow(
                      leading: Icon(Icons.star_outline_rounded, color: c.muted),
                      title: 'Uygulamayı değerlendir',
                      trailing: Icon(
                        Icons.chevron_right_rounded,
                        color: c.muted,
                      ),
                      onTap: () async {
                        try {
                          await openStoreListing();
                        } catch (e) {
                          debugPrint('Mağaza sayfası açılamadı: $e');
                          if (mounted) _snack('Mağaza sayfası açılamadı.');
                        }
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.note,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  'Bu uygulama bir hatırlatma aracıdır; tıbbi tavsiye vermez. '
                  'İlaç kullanımınla ilgili kararları doktorun veya eczacınla ver. '
                  'Verilerin yalnızca bu cihazda saklanır.',
                  style: TextStyle(fontSize: 13, height: 1.45, color: c.onNote),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _minutesTile(
    String title,
    int value,
    List<int> options,
    void Function(int) onChanged, {
    String? zeroLabel,
  }) => MenuRow<int>(
    title: title,
    value: value,
    // Kayıtlı değer seçenekler dışındaysa yanlış göstermemek için eklenir.
    options: {
      for (final o in [...options, if (!options.contains(value)) value]..sort())
        o: o == 0 ? (zeroLabel ?? '0') : '$o dk',
    },
    onChanged: onChanged,
  );
}
