// Объединённый экран «Практики» (#19, решение владельца): Медитация и
// Дыхание живут в ОДНОМ экране с двумя вкладками вместо двух отдельных
// экранов/входов из Health.
//
// Мод-флаги (feature_modes_provider.dart) решают состав экрана:
//   - оба включены  → TabBar «Медитация | Дыхание» + TabBarView;
//   - включён один  → без TabBar, сразу содержимое включённого модуля
//     (не показываем пустую вкладку под выключенный модуль);
//   - оба выключены → защитный fallback (в норме недостижимо: Health
//     прячет плитку «Практики», когда оба флага off).
//
// Бизнес-логика/данные обоих модулей НЕ дублируются: экран переиспользует
// [MeditationLibraryBody]/[MeditationScreen] и [BreathingSessionBody]/
// [BreathingScreen] as-is. Прямые маршруты /meditation и /breathing
// остаются рабочими отдельно — они нужны для deep-link из задач с
// moduleLink='meditation'/'breathing' (block_tool_router.dart), где хотим
// открыть конкретную практику без лишнего тапа по вкладке.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/feature_modes_provider.dart';
import 'breathing_screen.dart';
import 'meditation_screen.dart';

/// Стартовая вкладка объединённого экрана, когда включены ОБА модуля.
/// Игнорируется, если включён только один модуль (тогда вкладок нет).
enum MindTab { meditation, breathing }

class MindScreen extends ConsumerStatefulWidget {
  const MindScreen({super.key, this.initialTab});

  final MindTab? initialTab;

  @override
  ConsumerState<MindScreen> createState() => _MindScreenState();
}

class _MindScreenState extends ConsumerState<MindScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meditationOn = ref.watch(meditationLibraryModeProvider);
    final breathingOn = ref.watch(breathingEditorModeProvider);

    // Оба выключены — защитный fallback. В норме недостижимо: плитка
    // «Практики» в Health рендерится только когда хотя бы один флаг on.
    if (!meditationOn && !breathingOn) {
      return Scaffold(
        appBar: AppBar(title: Text(context.s('health.mind_practices'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.s('health.mind_practices_disabled'),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    // Включён только один модуль — без TabBar, сразу его контент.
    if (meditationOn && !breathingOn) {
      return const MeditationScreen();
    }
    if (breathingOn && !meditationOn) {
      return const BreathingScreen();
    }

    // Оба включены — вкладки «Медитация | Дыхание».
    _tabController ??= TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == MindTab.breathing ? 1 : 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('health.mind_practices')),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Text(
                context.s('health.meditation'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              child: Text(
                context.s('health.breathing'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MeditationLibraryBody(),
          BreathingSessionBody(),
        ],
      ),
    );
  }
}
