import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/notifications/notification_service.dart';
import 'ui/history_screen.dart';
import 'ui/medication_form.dart';
import 'ui/medications_screen.dart';
import 'ui/nav_bar.dart';
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
      pageBuilder: (context, state) {
        final form = MedicationFormScreen(
          medicationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
        );
        // iOS'ta form, arkadaki ekranı küçülten bir sayfa olarak alttan açılır.
        return isApple(context)
            ? _SheetPage(key: state.pageKey, child: form)
            : MaterialPage(key: state.pageKey, child: form);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(
        // Liste, yarı saydam alt menünün altından akar.
        extendBody: true,
        body: shell,
        bottomNavigationBar: AppNavBar(
          selectedIndex: shell.currentIndex,
          onSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
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

class _SheetPage<T> extends Page<T> {
  const _SheetPage({super.key, required this.child});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => CupertinoSheetRoute<T>(
    settings: this,
    // Liste en üstteyken aşağı çekmek sayfayı kapatır.
    scrollableBuilder: (_, controller) =>
        PrimaryScrollController(controller: controller, child: child),
  );
}

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
      // AppBar'sız sekmelerde de durum çubuğu simgeleri temaya uysun;
      // Android'in alt gezinme şeridi saydam kalsın.
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
          child: child!,
        );
      },
    );
  }
}
