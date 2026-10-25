import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'theme.dart';

typedef _Tab = ({
  String label,
  IconData icon,
  IconData selectedIcon,
  IconData appleIcon,
  IconData appleSelectedIcon,
});

const List<_Tab> _tabs = [
  (
    label: 'Bugün',
    icon: Icons.today_outlined,
    selectedIcon: Icons.today,
    appleIcon: CupertinoIcons.clock,
    appleSelectedIcon: CupertinoIcons.clock_fill,
  ),
  (
    label: 'İlaçlar',
    icon: Icons.medication_outlined,
    selectedIcon: Icons.medication,
    appleIcon: CupertinoIcons.capsule,
    appleSelectedIcon: CupertinoIcons.capsule_fill,
  ),
  (
    label: 'Geçmiş',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights,
    appleIcon: CupertinoIcons.chart_bar,
    appleSelectedIcon: CupertinoIcons.chart_bar_fill,
  ),
  (
    label: 'Ayarlar',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    appleIcon: CupertinoIcons.gear_alt,
    appleSelectedIcon: CupertinoIcons.gear_alt_fill,
  ),
];

/// Alt menü: iOS'ta yüzen liquid glass kapsül, Android'de içeriğin üstünde
/// bulanık, yarı saydam bir şerit. İçerik ikisinin de altından akar.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) =>
      // Büyük yazı boyutunda etiketler çubuğu taşırmasın.
      MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.2,
        child: isApple(context)
            ? _GlassBar(selectedIndex: selectedIndex, onSelected: onSelected)
            : _FrostedBar(selectedIndex: selectedIndex, onSelected: onSelected),
      );
}

class _GlassBar extends StatelessWidget {
  const _GlassBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const label = TextStyle(fontFamily: fontFamily, letterSpacing: 0);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassTabBar.bottom(
      // Yerel iOS malzemesi: buzlu gövde, koyu içerik üstünde de okunur.
      settings: dark
          ? LiquidGlassSettings.ios27Dark
          : LiquidGlassSettings.ios27Light,
      selectedIndex: selectedIndex,
      onTabSelected: onSelected,
      selectedIconColor: c.ink,
      unselectedIconColor: c.muted,
      selectedLabelColor: c.ink,
      unselectedLabelColor: c.muted,
      selectedLabelStyle: label.copyWith(fontWeight: FontWeight.w600),
      unselectedLabelStyle: label.copyWith(fontWeight: FontWeight.w500),
      iconSize: 22,
      tabs: [
        for (final t in _tabs)
          GlassTab(
            icon: Icon(t.appleIcon),
            activeIcon: Icon(t.appleSelectedIcon),
            label: t.label,
          ),
      ],
    );
  }
}

class _FrostedBar extends StatelessWidget {
  const _FrostedBar({required this.selectedIndex, required this.onSelected});

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.glass,
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (final (i, t) in _tabs.indexed)
                    Expanded(
                      child: _FrostedItem(
                        tab: t,
                        selected: i == selectedIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostedItem extends StatelessWidget {
  const _FrostedItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = selected ? c.ink : c.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              selected ? tab.selectedIcon : tab.icon,
              size: 22,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              tab.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
