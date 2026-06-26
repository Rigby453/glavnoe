// Экран «Осанка» (SPEC C5 Ф2).
// Тумблер ежедневных напоминаний «выпрямись» + список текстовых упражнений.
// Нет БД, нет видео, нет новых пакетов.
//
// ПРИМЕЧАНИЕ: экран убран из навигации (задача 7 эпика), файл сохранён
// компилируемым. Провайдер напоминаний перенесён в
// core/settings/posture_reminder_provider.dart, где доступен из Профиля.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/settings/posture_reminder_provider.dart';
import '../../core/theme/app_theme.dart';
import 'posture_exercises.dart';

// ---------------------------------------------------------------------------
// PostureScreen
// ---------------------------------------------------------------------------

class PostureScreen extends ConsumerWidget {
  const PostureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final remindersOn = ref.watch(postureRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.s('posture.title'))),
      body: ListView(
        // 24dp screen margin — spec §4.1
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // headlineSmall — display font, заголовок раздела
          Text(context.s('posture.title'), style: textTheme.headlineSmall),
          const SizedBox(height: 24),

          // --- Карточка тумблера напоминаний ---
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SwitchListTile(
                secondary: Icon(
                  Icons.notifications_outlined,
                  // Иконка нейтральная — не accent (не первичное действие)
                  color: ext.textMuted,
                ),
                title: Text(
                  context.s('posture.reminders_title'),
                  style: textTheme.bodyLarge,
                ),
                subtitle: Text(
                  // Используем subtitle строку (расписание) как подпись
                  context.s('posture.reminders_subtitle'),
                  style: textTheme.bodySmall,
                ),
                value: remindersOn,
                onChanged: (value) async {
                  final notifier =
                      ref.read(postureRemindersProvider.notifier);
                  final result = await notifier.setEnabled(value);
                  // Если разрешение не выдано — показываем снэкбар
                  if (value && !result && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.s('posture.permission_required')),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                },
              ),
            ),
          ),

          const SizedBox(height: 32),

          // --- Раздел упражнений ---
          Text(context.s('posture.exercises'), style: textTheme.titleMedium),
          const SizedBox(height: 12),
          ...postureExercises.map(
            (exercise) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ExerciseTile(exercise: exercise),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Плитка упражнения с раскрытием шагов
// ---------------------------------------------------------------------------

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});

  final PostureExercise exercise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      child: ExpansionTile(
        leading: Icon(
          Icons.self_improvement,
          // Иконка нейтральная (textMuted) — accent только для первичного элемента
          color: ext.textMuted,
        ),
        // Название упражнения — titleSmall (название задачи/сессии)
        title: Text(context.s(exercise.nameKey), style: textTheme.titleSmall),
        // Длительность — bodySmall + textFaint (мета-данные)
        trailing: Text(
          plPostureDuration(context, exercise.seconds),
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шаги — bodyMedium
          Text(context.s(exercise.stepsKey), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
