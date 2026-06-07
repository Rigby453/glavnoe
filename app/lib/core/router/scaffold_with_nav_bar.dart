// Оболочка с BottomNavigationBar и AppBar с кнопкой профиля
// Profile открывается из leading кнопки AppBar, а НЕ из нижней навигации

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Profile — leading кнопка, НЕ таб
        leading: const ProfileAvatarButton(),
        // Заголовок меняется в зависимости от активного таба
        title: Text(_tabTitle(navigationShell.currentIndex)),
        centerTitle: true,
      ),
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTabTap(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny_outlined),
            activeIcon: Icon(Icons.wb_sunny),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Plan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Health',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Diary',
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
  String _tabTitle(int index) => switch (index) {
        0 => 'Today',
        1 => 'Plan',
        2 => 'Health',
        3 => 'Diary',
        _ => 'Kaizen',
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
