// FL-TODAY-03: Строка streak — иконка огня, число, 7 точек за последние 7 дней
// Читает StreakTable через streakDaoProvider
// Устойчив к отсутствию строки в БД (показывает 0 и пустые точки)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';

class StreakRow extends ConsumerWidget {
  const StreakRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(
      // StreamProvider на основе watchStreak()
      _streakStreamProvider,
    );

    return streakAsync.when(
      data: (streak) {
        final current = streak?.current ?? 0;
        return _StreakRowContent(current: current);
      },
      loading: () => _StreakRowContent(current: 0),
      error: (_, _) => _StreakRowContent(current: 0),
    );
  }
}

/// StreamProvider для streak-данных
final _streakStreamProvider = StreamProvider((ref) {
  return ref.watch(streakDaoProvider).watchStreak();
});

class _StreakRowContent extends StatelessWidget {
  const _StreakRowContent({required this.current});

  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Иконка огня
        Icon(
          Icons.local_fire_department,
          color: colorScheme.secondary, // ember из темы
          size: 22,
        ),
        const SizedBox(width: 6),

        // Число дней подряд
        Text(
          '$current',
          style: textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          current == 1 ? context.s('today.streak_day') : context.s('today.streak_days'),
          style: textTheme.bodySmall,
        ),

        const SizedBox(width: 16),

        // 7 точек: для MVP показываем заполненными last N дней по счётчику
        // Полная история по датам будет в step 8 (sync + DayLogs)
        ..._buildDots(context, current),
      ],
    );
  }

  /// 7 точек: заполненные для дней со streak, пустые для остальных
  /// MVP: считаем от текущей позиции назад (max 7 заполненных)
  List<Widget> _buildDots(BuildContext context, int streakCount) {
    final colorScheme = Theme.of(context).colorScheme;
    final filled = streakCount.clamp(0, 7);

    return List.generate(7, (i) {
      // Точки идут от старых к новым слева направо
      // Последние `filled` точек — заполнены
      final isFilled = i >= (7 - filled);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? colorScheme.primary : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(60),
              width: 1.5,
            ),
          ),
        ),
      );
    });
  }
}
