// FL-PLAN: Экран Plan — переключатель День/Неделя/Месяц.
// - День: недельная полоса + таймлайн выбранного дня (исходное поведение).
// - Неделя: повестка из 7 дней.
// - Месяц: календарная сетка с точками на днях с задачами.
// AppBar даёт общая оболочка ScaffoldWithNavBar; здесь вложенный Scaffold
// нужен только ради FAB. Добавление задачи переиспользует showAddTaskSheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../import/import_sheet.dart';
import '../today/widgets/add_task_sheet.dart';
import 'widgets/day_timeline.dart';
import 'widgets/month_view.dart';
import 'widgets/plan_providers.dart';
import 'widgets/week_agenda.dart';
import 'widgets/week_strip.dart';

class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final view = ref.watch(planViewProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddTaskSheet(context, day: selectedDay),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Переключатель вида + импорт
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SegmentedButton<PlanView>(
                  segments: const [
                    ButtonSegment(value: PlanView.day, label: Text('Day')),
                    ButtonSegment(value: PlanView.week, label: Text('Week')),
                    ButtonSegment(value: PlanView.month, label: Text('Month')),
                  ],
                  selected: {view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) =>
                      ref.read(planViewProvider.notifier).state = s.first,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Import'),
                  onPressed: () => showImportSheet(context, day: selectedDay),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body(view)),
        ],
      ),
    );
  }

  Widget _body(PlanView view) {
    switch (view) {
      case PlanView.month:
        return const MonthView();
      case PlanView.week:
        return const Column(
          children: [
            WeekStrip(),
            Divider(height: 1),
            Expanded(child: WeekAgenda()),
          ],
        );
      case PlanView.day:
        return const Column(
          children: [
            WeekStrip(),
            Divider(height: 1),
            Expanded(child: DayTimeline()),
          ],
        );
    }
  }
}
