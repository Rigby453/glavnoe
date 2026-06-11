// Экран «Осанка» (SPEC C5 Ф2).
// Тумблер ежедневных напоминаний «выпрямись» + список текстовых упражнений.
// Нет БД, нет видео, нет новых пакетов.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart';
import '../../services/notifications/notification_service.dart';
import 'posture_exercises.dart';

// ---------------------------------------------------------------------------
// Провайдер тумблера напоминаний об осанке
// ---------------------------------------------------------------------------

const _kPostureRemindersKey = 'posture_reminders_on';

/// Состояние тумблера «Sit-up-straight reminders» — хранится в SharedPreferences.
class PostureRemindersNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(sharedPreferencesProvider).getBool(_kPostureRemindersKey) ??
      false;

  /// Включает или выключает напоминания об осанке.
  /// При включении — запрашивает разрешение, планирует уведомления.
  /// Возвращает фактическое состояние после операции.
  Future<bool> setEnabled(bool enabled) async {
    final service = ref.read(notificationServiceProvider);
    try {
      if (enabled) {
        final granted = await service.requestPermission();
        if (!granted) return false;
        await service.schedulePostureReminders();
      } else {
        await service.cancelPostureReminders();
      }
      await ref
          .read(sharedPreferencesProvider)
          .setBool(_kPostureRemindersKey, enabled);
      state = enabled;
      return enabled;
    } catch (e) {
      debugPrint('[PostureReminders] setEnabled($enabled) failed: $e');
      return state;
    }
  }
}

final postureRemindersProvider =
    NotifierProvider<PostureRemindersNotifier, bool>(
        PostureRemindersNotifier.new);

// ---------------------------------------------------------------------------
// PostureScreen
// ---------------------------------------------------------------------------

class PostureScreen extends ConsumerWidget {
  const PostureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final remindersOn = ref.watch(postureRemindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Posture')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          // --- Тумблер напоминаний ---
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined),
              title: const Text('Sit-up-straight reminders'),
              subtitle: const Text('Every 2 hours, 10:00–18:00'),
              value: remindersOn,
              onChanged: (value) async {
                final notifier =
                    ref.read(postureRemindersProvider.notifier);
                final result = await notifier.setEnabled(value);
                // Если разрешение не выдано — показываем снэкбар
                if (value && !result && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Notification permission required. '
                        'Enable it in system settings.',
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
            ),
          ),

          // --- Список упражнений ---
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('Exercises', style: textTheme.titleMedium),
          ),
          ...postureExercises.map(
            (exercise) => _ExerciseTile(exercise: exercise),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(Icons.self_improvement, color: colorScheme.primary),
        title: Text(exercise.name),
        trailing: Text(
          exercise.durationLabel,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        childrenPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(exercise.steps, style: textTheme.bodyMedium),
        ],
      ),
    );
  }
}
