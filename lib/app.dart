import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/notifications/notification_service.dart';
import 'ui/history_screen.dart';
import 'ui/medication_form.dart';
import 'ui/medications_screen.dart';
import 'ui/providers.dart';
import 'ui/settings_screen.dart';
import 'ui/theme.dart';
import 'ui/today_screen.dart';
import 'ui/welcome_screen.dart';

GoRouter buildRouter({required bool onboarded}) => GoRouter(
  initialLocation: onboarded ? '/' : '/welcome',
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: '/med',
      builder: (_, state) => MedicationFormScreen(
        medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        body: shell,
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.c.line)),
          ),
          child: NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.schedule_rounded),
                selectedIcon: Icon(Icons.schedule_rounded),
                label: 'Bugün',
              ),
              NavigationDestination(
                icon: Icon(Icons.medication_outlined),
                selectedIcon: Icon(Icons.medication_rounded),
                label: 'İlaçlar',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_rounded),
                selectedIcon: Icon(Icons.bar_chart_rounded),
                label: 'Geçmiş',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune_rounded),
                selectedIcon: Icon(Icons.tune_rounded),
                label: 'Ayarlar',
              ),
            ],
          ),
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const TodayScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/meds',
              builder: (_, _) => const MedicationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (_, _) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class TakeAPillApp extends ConsumerStatefulWidget {
  const TakeAPillApp({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<TakeAPillApp> createState() => _AppState();
}

class _AppState extends ConsumerState<TakeAPillApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Arka plandaki bildirim butonları başka isolate'te DB'yi değiştirmiş
  /// olabilir; öne gelince listeleri tazele ve planı yenile (64 sınırı).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(nowProvider);
      ref.invalidate(doseViewsProvider);
      ref.invalidate(medicationPlansProvider);
      trySyncNotifications(ref.read(dbProvider));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Take a Pill',
      routerConfig: widget.router,
      themeMode: ref.watch(themeModeProvider),
      debugShowCheckedModeBanner: false,
      // Tarih/saat seçicileri ve sistem metinleri Türkçe, saat 24 saatlik.
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
    );
  }
}
