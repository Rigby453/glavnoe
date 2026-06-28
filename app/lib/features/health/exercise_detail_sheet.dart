// Детальная карточка упражнения — Kaname redesign §D.
// Sheet pattern: handle · title row + close X · content · OutlinedButton видео.
// Chips: surface + hairline border, accent color for the muscle chip icon.
// Phosphor icons: barbell, wrench, chartBar, playCircle, warning, x.
// Использование:
//   showExerciseDetail(context, exercise);

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import 'exercise_library.dart';

// ---------------------------------------------------------------------------
// Точка входа
// ---------------------------------------------------------------------------

void showExerciseDetail(BuildContext context, Exercise exercise) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
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

    final name = context.s(exercise.nameKey);

    // Параметры по умолчанию
    final defaultParams =
        '${exercise.defaultSets} × ${exercise.defaultReps}  ·  '
        '${exercise.defaultRestSeconds}${context.s('workout.seconds_short')} ${context.s('exercise.detail.rest')}';

    return Container(
      // Мягкая тень (только шиты — §4.3)
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomScrollView(
              controller: scrollController,
              slivers: [
                // ── Handle + заголовок + крестик ─────────────────────────────
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Drag handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: ext.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Название + крестик
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
                          const SizedBox(width: 8),
                          // Phosphor X — закрыть
                          IconButton(
                            icon: Icon(PhosphorIcons.x(), size: 20),
                            color: ext.textMuted,
                            tooltip: context.s('btn.close'),
                            onPressed: () => Navigator.of(context).maybePop(),
                            visualDensity: VisualDensity.compact,
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
                            icon: PhosphorIcons.barbell(PhosphorIconsStyle.fill),
                            color: colorScheme.primary,
                          ),
                          _InfoChip(
                            label: _equipmentLabel(context, exercise.equipment),
                            icon: PhosphorIcons.wrench(),
                            color: ext.textMuted,
                          ),
                          _InfoChip(
                            label: _difficultyLabel(context, exercise.difficulty),
                            icon: PhosphorIcons.chartBar(),
                            color: _difficultyColor(ext, exercise.difficulty),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Параметры по умолчанию
                      Text(
                        defaultParams,
                        style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                        accent: colorScheme.primary,
                      );
                    },
                    childCount: exercise.stepKeys.length,
                  ),
                ),

                // ── Типичные ошибки ───────────────────────────────────────────
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

                // ── Кнопка видео ──────────────────────────────────────────────
                if (exercise.videoUrl != null &&
                    exercise.videoUrl!.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20, bottom: 8),
                      child: OutlinedButton.icon(
                        icon: Icon(PhosphorIcons.playCircle(), size: 18),
                        label: Text(context.s('exercise.detail.watch_video')),
                        onPressed: () =>
                            _handleVideoTap(context, exercise.videoUrl!),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                // Нижний отступ
                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          );
        },
      ),
    );
  }

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

  static String _muscleLabel(BuildContext context, String group) {
    final key = 'muscle_group.$group';
    final resolved = context.s(key);
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
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
    required this.accent,
  });

  final int number;
  final String text;
  final TextTheme textTheme;
  final FocusThemeExtension ext;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Номер шага — accent color, w500
          SizedBox(
            width: 24,
            child: Text(
              '$number.',
              style: textTheme.bodyMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w500,
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
          // Phosphor warning — ember (вместо Icons.warning_amber_outlined)
          Icon(PhosphorIcons.warning(), size: 16, color: ext.ember),
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

/// Чип информации — surface + hairline border (§4.2).
/// NO shadow, NO filled color — только border; leading icon с семантическим цветом.
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: ext.textMuted,
                    fontWeight: FontWeight.w400,
                  ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
