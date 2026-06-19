// Оболочка с NavigationBar (M3) и AppBar с кнопкой профиля.
// Profile открывается из leading кнопки AppBar, а НЕ из нижней навигации.
// На широких экранах (≥600px) — NavigationRail вместо NavigationBar.
//
// M3 NavigationBar выбран вместо M2 BottomNavigationBar, потому что он
// нативно рендерит accent-«пилюлю» (indicator) под активным табом через
// NavigationBarThemeData — что требует UX-LAYOUT.md §3 и 03-components.md §9.
// Никакого дополнительного кода для pill-индикатора не нужно.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
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

  /// Wide layout (≥600px): NavigationRail + no bottom bar.
  Widget _buildWideLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (i) => _onTabTap(context, i),
            labelType: NavigationRailLabelType.all,
            // Цвета по spec: активный = accent, неактивный = textMuted
            selectedIconTheme: IconThemeData(
              color: colorScheme.primary,
              size: 24,
            ),
            unselectedIconTheme: IconThemeData(
              color: ext.textMuted,
              size: 24,
            ),
            selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
              color: ext.textMuted,
            ),
            indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
            backgroundColor: colorScheme.surface,
            // NB: NavigationRail требует elevation == null || > 0 (assert в
            // navigation_rail.dart). НЕ ставить 0 — крашит широкий layout.
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const ProfileAvatarButton(),
            ),
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.wb_sunny_outlined, color: ext.textMuted),
                selectedIcon:
                    Icon(Icons.wb_sunny, color: colorScheme.primary),
                label: Text(context.s('nav.today')),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined,
                    color: ext.textMuted),
                selectedIcon: Icon(Icons.calendar_today,
                    color: colorScheme.primary),
                label: Text(context.s('nav.plan')),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.favorite_border, color: ext.textMuted),
                selectedIcon:
                    Icon(Icons.favorite, color: colorScheme.primary),
                label: Text(context.s('nav.health')),
              ),
              NavigationRailDestination(
                icon:
                    Icon(Icons.menu_book_outlined, color: ext.textMuted),
                selectedIcon:
                    Icon(Icons.menu_book, color: colorScheme.primary),
                label: Text(context.s('nav.diary')),
              ),
            ],
          ),
          // Разделитель — 1dp hairline border (03-components.md §18)
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: ext.border,
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }

  /// Mobile layout (<600px): AppBar + M3 NavigationBar с pill-индикатором.
  Widget _buildMobileLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        // Profile — leading кнопка, НЕ таб (UX-LAYOUT.md §2)
        leading: const ProfileAvatarButton(),
        // Заголовок меняется в зависимости от активного таба
        title: Text(_tabTitle(context, navigationShell.currentIndex)),
        centerTitle: true,
      ),
      body: navigationShell,
      // M3 NavigationBar: нативный pill-индикатор (03-components.md §9)
      // Оборачиваем в DecoratedBox — добавляем hairline border сверху
      // (top border не поддерживается NavigationBarThemeData нативно).
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          // Тонкая линия-разделитель сверху — 1dp, border color (03-components §9)
          border: Border(
            top: BorderSide(color: ext.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => _onTabTap(context, i),
          // Высота 64dp (03-components.md §9 NavigationBarThemeData)
          height: 64,
          // Фон: surface, без elevation (03-components.md §9)
          backgroundColor: colorScheme.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          // Pill-индикатор: accent.withOpacity(0.15) — нативно в M3
          indicatorColor: colorScheme.primary.withValues(alpha: 0.15),
          // labelBehavior: alwaysShow — иконка + подпись у каждого таба
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.wb_sunny_outlined, size: 24, color: ext.textMuted),
              selectedIcon: Icon(Icons.wb_sunny,
                  size: 24, color: colorScheme.primary),
              label: context.s('nav.today'),
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined,
                  size: 24, color: ext.textMuted),
              selectedIcon: Icon(Icons.calendar_today,
                  size: 24, color: colorScheme.primary),
              label: context.s('nav.plan'),
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border, size: 24, color: ext.textMuted),
              selectedIcon:
                  Icon(Icons.favorite, size: 24, color: colorScheme.primary),
              label: context.s('nav.health'),
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined,
                  size: 24, color: ext.textMuted),
              selectedIcon: Icon(Icons.menu_book,
                  size: 24, color: colorScheme.primary),
              label: context.s('nav.diary'),
            ),
          ],
          // Стили подписей и индикатора через явные параметры текста
          // (NavigationBarThemeData применяется на уровне ThemeData,
          // но здесь мы переопределяем labelTextStyle для правильных весов).
        ),
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

/// Кнопка-аватар профиля в leading AppBar.
/// Нажатие → переход на /profile (UX-LAYOUT.md §2).
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      // Минимальный тап-таргет 48dp (03-components.md §0)
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => context.push('/profile'),
        borderRadius: BorderRadius.circular(999),
        child: CircleAvatar(
          radius: 16,
          // accent fill, onAccent icon — per 03-components.md §8 (AppBar spec)
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
