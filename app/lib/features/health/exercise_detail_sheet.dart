// Детальная карточка упражнения из каталога (exercise_library.dart).
// Показывает: название, чипы (группа мышц / инвентарь / сложность),
// шаги техники (пронумерованный список), типичные ошибки (буллеты),
// дефолтные параметры (подходы × повторения, отдых).
// Кнопка «Смотреть видео» показывается только когда videoUrl != null && !isEmpty.
// Поскольку url_launcher НЕ добавлен в pubspec, кнопка копирует URL в буфер
// и показывает SnackBar (flutter/services — Clipboard уже в SDK).
//
// Использование:
//   showExerciseDetail(context, exercise);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'exercise_library.dart';

// ---------------------------------------------------------------------------
// Точка входа
// ---------------------------------------------------------------------------

/// Открывает модальный bottom-sheet с деталями упражнения [exercise].
void showExerciseDetail(BuildContext context, Exercise exercise) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ExerciseDetailSheet(exercise: exercise),
  );
}

// ---------------------------------------------------------------------------
// Виджет листа
// ---------------------------------------------------------------------------

class _ExerciseDetailSheet extends StatelessWidget {
  const _ExerciseDetailSheet({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    // Разрешаем l10n-ключи
    final name = context.s(exercise.nameKey);

    // Параметры по умолчанию
    final defaultParams =
        '${exercise.defaultSets} × ${exercise.defaultReps}  ·  '
        '${exercise.defaultRestSeconds} ${context.s('workout.seconds_short')} ${context.s('exercise.detail.rest')}';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Padding(
          // Горизонтальные отступы 20px — комфортно на 320px
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // ── Заголовок + кнопка закрытия ──────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    // Drag handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: ext.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Строка: название + крестик
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: context.s('btn.close'),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Чипы: группа мышц / инвентарь / сложность
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(
                          label: _muscleLabel(context, exercise.muscleGroup),
                          icon: Icons.fitness_center,
                          color: colorScheme.primary,
                        ),
                        _InfoChip(
                          label: _equipmentLabel(context, exercise.equipment),
                          icon: Icons.handyman_outlined,
                          color: ext.textMuted,
                        ),
                        _InfoChip(
                          label: _difficultyLabel(context, exercise.difficulty),
                          icon: Icons.bar_chart,
                          color: _difficultyColor(ext, exercise.difficulty),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Параметры (подходы × повторения, отдых)
                    Text(
                      defaultParams,
                      style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),

              // ── Техника выполнения ────────────────────────────────────────
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: context.s('exercise.detail.technique'),
                  textTheme: textTheme,
                  ext: ext,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final key = exercise.stepKeys[i];
                    return _StepTile(
                      number: i + 1,
                      text: context.s(key),
                      textTheme: textTheme,
                      ext: ext,
                    );
                  },
                  childCount: exercise.stepKeys.length,
                ),
              ),

              // ── Типичные ошибки (только если есть) ───────────────────────
              if (exercise.mistakeKeys.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      _SectionHeader(
                        title: context.s('exercise.detail.mistakes'),
                        textTheme: textTheme,
                        ext: ext,
                      ),
                    ],
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final key = exercise.mistakeKeys[i];
                      return _MistakeTile(
                        text: context.s(key),
                        textTheme: textTheme,
                        ext: ext,
                      );
                    },
                    childCount: exercise.mistakeKeys.length,
                  ),
                ),
              ],

              // ── Кнопка «Смотреть видео» (только когда videoUrl заполнен) ─
              if (exercise.videoUrl != null &&
                  exercise.videoUrl!.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 8),
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(context.s('exercise.detail.watch_video')),
                      onPressed: () =>
                          _handleVideoTap(context, exercise.videoUrl!),
                    ),
                  ),
                ),
              ],

              // ── Нижний отступ (safe area) ─────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Обработка тапа по видео-кнопке.
  // url_launcher НЕ в pubspec → копируем URL в буфер обмена через flutter/services.
  // ---------------------------------------------------------------------------

  static Future<void> _handleVideoTap(
    BuildContext context,
    String url,
  ) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('exercise.detail.link_copied'))),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Разрешение l10n-меток для чипов
  // ---------------------------------------------------------------------------

  static String _muscleLabel(BuildContext context, String group) {
    final key = 'muscle_group.$group';
    final resolved = context.s(key);
    // Откат на сам слаг если ключ не найден (не должно происходить)
    return resolved == key ? group : resolved;
  }

  static String _equipmentLabel(BuildContext context, String equipment) {
    final key = 'equipment.$equipment';
    final resolved = context.s(key);
    return resolved == key ? equipment : resolved;
  }

  static String _difficultyLabel(BuildContext context, String difficulty) {
    final key = 'difficulty.$difficulty';
    final resolved = context.s(key);
    return resolved == key ? difficulty : resolved;
  }

  static Color _difficultyColor(FocusThemeExtension ext, String difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.beginner:
        return ext.success;
      case ExerciseDifficulty.advanced:
        return ext.ember;
      default:
        return ext.textMuted;
    }
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные виджеты
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.textTheme,
    required this.ext,
  });

  final String title;
  final TextTheme textTheme;
  final FocusThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: textTheme.titleMedium?.copyWith(color: ext.textMuted),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.text,
    required this.textTheme,
    required this.ext,
  });

  final int number;
  final String text;
  final TextTheme textTheme;
  final FocusThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Номер шага
          SizedBox(
            width: 24,
            child: Text(
              '$number.',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeTile extends StatelessWidget {
  const _MistakeTile({
    required this.text,
    required this.textTheme,
    required this.ext,
  });

  final String text;
  final TextTheme textTheme;
  final FocusThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_outlined, size: 16, color: ext.ember),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ext.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          // Wrap in Flexible so chips don't overflow at 320px
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
