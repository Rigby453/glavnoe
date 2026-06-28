// Экран «Осанка» (SPEC C5 Ф2).
// Kaname redesign (Phase 5): §4.2 cards, Phosphor icons.
// Тумблер ежедневных напоминаний + список текстовых упражнений с раскрытием шагов.
// Нет БД, нет видео, нет новых пакетов.
//
// ПРИМЕЧАНИЕ: экран убран из навигации (задача 7 эпика), файл сохранён
// компилируемым. Провайдер напоминаний — core/settings/posture_reminder_provider.dart.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

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
    final surface = Theme.of(context).colorScheme.surface;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('posture.title'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          // titleLarge — спокойный заголовок раздела
          Text(context.s('posture.title'), style: textTheme.titleLarge),
          const SizedBox(height: 24),

          // ── Карточка тумблера напоминаний (§4.2) ───────────────────────
          Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: ext.border, width: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: Icon(
                PhosphorIcons.bell(),
                // Иконка нейтральная — не accent
                color: ext.textMuted,
              ),
              title: Text(
                context.s('posture.reminders_title'),
                style: textTheme.bodyLarge,
              ),
              subtitle: Text(
                context.s('posture.reminders_subtitle'),
                style: textTheme.bodySmall,
              ),
              value: remindersOn,
              onChanged: (value) async {
                final notifier = ref.read(postureRemindersProvider.notifier);
                final result = await notifier.setEnabled(value);
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

          const SizedBox(height: 32),

          // ── Раздел упражнений ──────────────────────────────────────────
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
// Плитка упражнения с раскрытием шагов (§4.2 card + ExpansionTile).
// ---------------------------------------------------------------------------

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.exercise});
  final PostureExercise exercise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: ext.border, width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          // personSimpleWalk — Phosphor эквивалент accessibility_new (posture)
          PhosphorIcons.personSimpleWalk(),
          color: ext.textMuted,
        ),
        title: Text(
          context.s(exercise.nameKey),
          style: textTheme.titleSmall,
          overflow: TextOverflow.ellipsis,
        ),
        // trailing — длительность упражнения (заменяет дефолтную стрелку ExpansionTile)
        trailing: Text(
          plPostureDuration(context, exercise.seconds),
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Инструкция: bodyMedium
          Text(context.s(exercise.stepsKey), style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
