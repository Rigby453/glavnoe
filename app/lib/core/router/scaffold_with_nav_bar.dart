// Оболочка с NavigationBar (M3) и AppBar с кнопкой профиля.
// Profile открывается из leading кнопки AppBar, а НЕ из нижней навигации.
//
// Wide layout (NavigationRail) активируется ТОЛЬКО при ширине ≥600dp И высоте ≥520dp.
// Телефон в альбомной ориентации (низкая высота) сохраняет мобильный layout с
// NavigationBar снизу — это защищает от узкого контента при landscape.
//
// Content max-width: на больших экранах (>905dp ширина) тело оборачивается
// в Center + ConstrainedBox(maxWidth: 1160) — токен content_max_width из design-tokens.json v4.
//
// M3 NavigationBar выбран вместо M2 BottomNavigationBar, потому что он
// нативно рендерит accent-«пилюлю» (indicator) под активным табом через
// NavigationBarThemeData — что требует UX-LAYOUT.md §3.
// Никакого дополнительного кода для pill-индикатора не нужно.
//
// Контекстные действия таба Plan (Цели, Импорт) встроены в ЕДИНСТВЕННЫЙ AppBar
// (этот файл), видны только когда currentIndex == 1 (Plan). Второй AppBar
// в plan_screen.dart удалён — экономим целую строку высоты (UX).
//
// Иконки: Phosphor (phosphor_flutter ≥2.1). regular=outline (неактивный),
// fill+accent=активный/выбранный. Размер 20 в navbar/inline (spec §1.8).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../features/import/import_sheet.dart';
import '../../features/plan/widgets/week_strip.dart' show selectedDayProvider;
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import '../utils/breakpoints.dart';

// Индекс таба Plan в StatefulShellRoute (Today=0, Plan=1, Health=2, Diary=3).
const _kPlanTabIndex = 1;

// Максимальная ширина читаемой колонки на expanded/large-экранах (design-tokens v4 content_max_width).
const double _kContentMaxWidth = 1160;

// Минимальная высота для активации wide-layout (NavigationRail).
// Альбомный телефон обычно 320–420dp высота → остаётся мобильный layout.
const double _kWideMinHeight = 520;

/// Пункты меню «⋮» (PopupMenuButton) в AppBar вкладки Plan.
enum _PlanMenuAction { goals, importSchedule }

class ScaffoldWithNavBar extends ConsumerWidget {
  const ScaffoldWithNavBar({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Landscape guard: wide layout только при достаточных ширине И высоте.
        final isWide = constraints.maxWidth >= Breakpoints.tablet &&
            constraints.maxHeight >= _kWideMinHeight;
        if (isWide) {
          return _buildWideLayout(context, ref, constraints);
        }
        return _buildMobileLayout(context, ref, constraints);
      },
    );
  }

  /// Оборачивает тело в ConstrainedBox(maxWidth:1160) на экранах шире 905dp.
  /// На телефоне и планшете — полная ширина.
  Widget _constrainedBody(Widget child, BoxConstraints constraints) {
    if (constraints.maxWidth > Breakpoints.desktop) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
          child: child,
        ),
      );
    }
    return child;
  }

  /// Контекстные действия таба Plan — отображаются только на табе Plan.
  /// Единое меню «⋮» вместо двух голых иконок — пункты подписаны (UX-polish).
  List<Widget> _planActions(BuildContext context, WidgetRef ref) {
    if (navigationShell.currentIndex != _kPlanTabIndex) return const [];
    final selectedDay = ref.watch(selectedDayProvider);
    return [
      PopupMenuButton<_PlanMenuAction>(
        tooltip: context.s('plan.more_tooltip'),
        icon: Icon(PhosphorIcons.dotsThreeVertical(PhosphorIconsStyle.regular)),
        onSelected: (action) {
          switch (action) {
            case _PlanMenuAction.goals:
              context.push('/goals');
            case _PlanMenuAction.importSchedule:
              showImportSheet(context, day: selectedDay);
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem<_PlanMenuAction>(
            value: _PlanMenuAction.goals,
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.flag(PhosphorIconsStyle.regular),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(ctx.s('plan.goals_label')),
              ],
            ),
          ),
          PopupMenuItem<_PlanMenuAction>(
            value: _PlanMenuAction.importSchedule,
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.uploadSimple(PhosphorIconsStyle.regular),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(ctx.s('plan.import_tooltip')),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  /// Wide layout (≥600dp ширина И ≥520dp высота):
  /// AppBar + NavigationRail слева + контент справа (нет нижнего бара).
  Widget _buildWideLayout(
    BuildContext context,
    WidgetRef ref,
    BoxConstraints constraints,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      // AppBar на wide-layout: profile вынесен в leading NavigationRail,
      // поэтому здесь — только заголовок + контекстные действия (Plan).
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_tabTitle(context, navigationShell.currentIndex)),
        centerTitle: false,
        actions: _planActions(context, ref),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (i) => _onTabTap(context, i),
            labelType: NavigationRailLabelType.all,
            // Размер иконки 20 (spec §1.8 navbar/inline)
            selectedIconTheme: IconThemeData(
              color: colorScheme.primary,
              size: 20,
            ),
            unselectedIconTheme: IconThemeData(
              color: ext.textMuted,
              size: 20,
            ),
            selectedLabelTextStyle: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
            unselectedLabelTextStyle: textTheme.labelSmall?.copyWith(
              color: ext.textMuted,
            ),
            // Pill-индикатор: accentTint (мягкий подслой акцента)
            indicatorColor: ext.accentTint,
            backgroundColor: colorScheme.surface,
            // NB: NavigationRail требует elevation == null || > 0 (assert в
            // navigation_rail.dart). НЕ ставить 0 — крашит широкий layout.
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const ProfileAvatarButton(),
            ),
            destinations: [
              NavigationRailDestination(
                icon: Icon(
                  PhosphorIcons.sun(PhosphorIconsStyle.regular),
                  color: ext.textMuted,
                ),
                selectedIcon: Icon(
                  PhosphorIcons.sun(PhosphorIconsStyle.fill),
                  color: colorScheme.primary,
                ),
                label: Text(context.s('nav.today')),
              ),
              NavigationRailDestination(
                icon: Icon(
                  PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular),
                  color: ext.textMuted,
                ),
                selectedIcon: Icon(
                  PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                  color: colorScheme.primary,
                ),
                label: Text(context.s('nav.plan')),
              ),
              NavigationRailDestination(
                icon: Icon(
                  PhosphorIcons.heartbeat(PhosphorIconsStyle.regular),
                  color: ext.textMuted,
                ),
                selectedIcon: Icon(
                  PhosphorIcons.heartbeat(PhosphorIconsStyle.fill),
                  color: colorScheme.primary,
                ),
                label: Text(context.s('nav.health')),
              ),
              NavigationRailDestination(
                icon: Icon(
                  PhosphorIcons.notebook(PhosphorIconsStyle.regular),
                  color: ext.textMuted,
                ),
                selectedIcon: Icon(
                  PhosphorIcons.notebook(PhosphorIconsStyle.fill),
                  color: colorScheme.primary,
                ),
                label: Text(context.s('nav.diary')),
              ),
            ],
          ),
          // Разделитель — 1dp hairline border
          VerticalDivider(
            thickness: 1,
            width: 1,
            color: ext.border,
          ),
          Expanded(
            child: _constrainedBody(navigationShell, constraints),
          ),
        ],
      ),
    );
  }

  /// Mobile layout (<600dp ширины ИЛИ <520dp высоты):
  /// AppBar + M3 NavigationBar снизу с pill-индикатором.
  Widget _buildMobileLayout(
    BuildContext context,
    WidgetRef ref,
    BoxConstraints constraints,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        // Profile — leading кнопка, НЕ таб (UX-LAYOUT.md §2)
        leading: const ProfileAvatarButton(),
        title: Text(_tabTitle(context, navigationShell.currentIndex)),
        centerTitle: true,
        actions: _planActions(context, ref),
      ),
      body: _constrainedBody(navigationShell, constraints),
      // M3 NavigationBar: нативный pill-индикатор
      // Оборачиваем в DecoratedBox — добавляем hairline border сверху
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: ext.border, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => _onTabTap(context, i),
          height: 64,
          backgroundColor: colorScheme.surface,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          // Pill-индикатор: accentTint (мягкий подслой акцента)
          indicatorColor: ext.accentTint,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                PhosphorIcons.sun(PhosphorIconsStyle.regular),
                size: 20,
                color: ext.textMuted,
              ),
              selectedIcon: Icon(
                PhosphorIcons.sun(PhosphorIconsStyle.fill),
                size: 20,
                color: colorScheme.primary,
              ),
              label: context.s('nav.today'),
            ),
            NavigationDestination(
              icon: Icon(
                PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular),
                size: 20,
                color: ext.textMuted,
              ),
              selectedIcon: Icon(
                PhosphorIcons.calendarBlank(PhosphorIconsStyle.fill),
                size: 20,
                color: colorScheme.primary,
              ),
              label: context.s('nav.plan'),
            ),
            NavigationDestination(
              icon: Icon(
                PhosphorIcons.heartbeat(PhosphorIconsStyle.regular),
                size: 20,
                color: ext.textMuted,
              ),
              selectedIcon: Icon(
                PhosphorIcons.heartbeat(PhosphorIconsStyle.fill),
                size: 20,
                color: colorScheme.primary,
              ),
              label: context.s('nav.health'),
            ),
            NavigationDestination(
              icon: Icon(
                PhosphorIcons.notebook(PhosphorIconsStyle.regular),
                size: 20,
                color: ext.textMuted,
              ),
              selectedIcon: Icon(
                PhosphorIcons.notebook(PhosphorIconsStyle.fill),
                size: 20,
                color: colorScheme.primary,
              ),
              label: context.s('nav.diary'),
            ),
          ],
        ),
      ),
    );
  }

  /// Переключение таба — goBranch сохраняет состояние каждой ветки.
  /// Повторный тап по активному табу — возврат к корневому маршруту ветки.
  void _onTabTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  /// Заголовок AppBar в зависимости от активного таба.
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
/// Иконка: PhosphorIcons.user (regular) в круге accentTint — Kaname spec §navigation.
class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Padding(
      // Минимальный тап-таргет 48dp
      padding: const EdgeInsets.all(8.0),
      child: InkWell(
        onTap: () => context.push('/profile'),
        borderRadius: BorderRadius.circular(999),
        child: CircleAvatar(
          radius: 16,
          // accentTint fill + accentInk icon — Kaname spec §navigation
          backgroundColor: ext.accentTint,
          child: Icon(
            PhosphorIcons.user(PhosphorIconsStyle.regular),
            size: 18,
            color: ext.accentInk,
          ),
        ),
      ),
    );
  }
}
