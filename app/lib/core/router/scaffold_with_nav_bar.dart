// Оболочка с BottomNavigationBar и AppBar с кнопкой профиля
// Profile открывается из leading кнопки AppBar, а НЕ из нижней навигации
// На широких экранах (≥600px) — NavigationRail вместо BottomNavigationBar.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../utils/breakpoints.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Breakpoints.tablet) {
          return _buildWideLayout(context);
        }
        return _buildMobileLayout(context);
      },
    );
  }

  /// Wide layout (≥600px): NavigationRail + no AppBar bottom bar.
  Widget _buildWideLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (i) => _onTabTap(context, i),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const ProfileAvatarButton(),
            ),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.wb_sunny_outlined),
                selectedIcon: const Icon(Icons.wb_sunny),
                label: Text(context.s('nav.today')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.calendar_today_outlined),
                selectedIcon: const Icon(Icons.calendar_today),
                label: Text(context.s('nav.plan')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.favorite_border),
                selectedIcon: const Icon(Icons.favorite),
                label: Text(context.s('nav.health')),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: Text(context.s('nav.diary')),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  /// Mobile layout (<600px): AppBar + BottomNavigationBar.
  Widget _buildMobileLayout(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Profile — leading кнопка, НЕ таб
        leading: const ProfileAvatarButton(),
        // Заголовок меняется в зависимости от активного таба
        title: Text(_tabTitle(context, navigationShell.currentIndex)),
        centerTitle: true,
      ),
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTabTap(context, index),
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.wb_sunny_outlined),
            activeIcon: const Icon(Icons.wb_sunny),
            label: context.s('nav.today'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.calendar_today_outlined),
            activeIcon: const Icon(Icons.calendar_today),
            label: context.s('nav.plan'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_border),
            activeIcon: const Icon(Icons.favorite),
            label: context.s('nav.health'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.menu_book_outlined),
            activeIcon: const Icon(Icons.menu_book),
            label: context.s('nav.diary'),
          ),
        ],
      ),
    );
  }

  /// Переключение таба — goBranch сохраняет состояние каждой ветки
  void _onTabTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      // Повторный тап по активному табу — возврат к корневому маршруту ветки
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Заголовок AppBar в зависимости от активного таба
  String _tabTitle(BuildContext context, int index) => switch (index) {
        0 => context.s('nav.today'),
        1 => context.s('nav.plan'),
        2 => context.s('nav.health'),
        3 => context.s('nav.diary'),
        _ => context.s('nav.fallback'),
      };
}

/// Кнопка-аватар профиля в leading AppBar
/// Нажатие → переход на /profile
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => context.push('/profile'),
        borderRadius: BorderRadius.circular(999), // radius.pill
        child: CircleAvatar(
          radius: 16,
          backgroundColor: colorScheme.primary,
          child: Icon(
            Icons.person_outline,
            size: 18,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
