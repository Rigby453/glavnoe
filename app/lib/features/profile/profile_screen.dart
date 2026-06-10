// Экран профиля (не таб). Показывает статус аккаунта и кнопку выхода/входа.
// При выходе routerProvider уводит на /auth.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/text_scale_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../services/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';

/// Streak пользователя (локально; наполняется через синхронизацию).
final _streakProvider = StreamProvider.autoDispose<StreakTableData?>((ref) {
  return ref.watch(streakDaoProvider).watchStreak();
});

/// Данные текущего пользователя (или null, если офлайн-режим / не вошёл).
final currentUserProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth) return null;
  final api = ref.read(apiClientProvider);
  if (api.token == null) return null; // офлайн-режим
  try {
    return await api.me();
  } on ApiException {
    return null;
  }
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final userAsync = ref.watch(currentUserProvider);
    final streak = ref.watch(_streakProvider).valueOrNull;
    final isAuthenticated =
        ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  _buildHeader(context, ref, userAsync, textTheme, streak),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                await ref.read(authControllerProvider.notifier).logout();
              },
              child: Text(isAuthenticated ? 'Sign out' : 'Sign in / Sign up'),
            ),
            const SizedBox(height: 8),
            const _AppVersionLabel(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Map<String, dynamic>?> userAsync,
    TextTheme textTheme,
    StreakTableData? streak,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        userAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const SizedBox.shrink(),
              data: (user) {
                if (user == null) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Offline mode', style: textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Your tasks are stored on this device only. '
                        'Sign in to sync across devices.',
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (user['name'] as String?) ?? 'You',
                      style: textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (user['email'] as String?) ?? '',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StreakStat(label: 'Streak', value: '${streak?.current ?? 0}'),
                    _StreakStat(label: 'Best', value: '${streak?.longest ?? 0}'),
                    _StreakStat(label: 'Freezes', value: '${streak?.freezeCount ?? 0}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _PremiumCard(),
            const SizedBox(height: 24),
            Text('Appearance', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const _ThemePicker(),
            const SizedBox(height: 24),
            Text('Preferences', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const _ToneSetting(),
            const SizedBox(height: 16),
            const _TextSizeSetting(),
            const SizedBox(height: 8),
            const _NotificationsSetting(),
          ],
        );
  }
}

/// Переключатель ежедневных напоминаний (утренний/вечерний разбор).
class _NotificationsSetting extends ConsumerWidget {
  const _NotificationsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationsEnabledProvider);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Daily reminders'),
      subtitle: const Text('Morning & evening review nudges'),
      value: enabled,
      onChanged: (want) async {
        final result = await ref
            .read(notificationsEnabledProvider.notifier)
            .setEnabled(want);
        // Если включали, но разрешение не выдали — подсказываем.
        if (want && !result && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable notifications in system settings to use reminders'),
            ),
          );
        }
      },
    );
  }
}

/// Выбор темы оформления. Доступны все 5 тем: focus / calm / black / white / contrast.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  static const _available = [
    (AppThemeKey.focus, 'Focus'),
    (AppThemeKey.calm, 'Calm'),
    (AppThemeKey.black, 'Black'),
    (AppThemeKey.white, 'White'),
    (AppThemeKey.contrast, 'Contrast'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeNotifierProvider);
    return Wrap(
      spacing: 8,
      children: _available.map((entry) {
        final (key, label) = entry;
        return ChoiceChip(
          label: Text(label),
          selected: current == key,
          onSelected: (_) =>
              ref.read(themeNotifierProvider.notifier).setTheme(key),
        );
      }).toList(),
    );
  }
}

/// Карточка статуса подписки: показывает Free/Premium и ведёт на пейволл.
class _PremiumCard extends ConsumerWidget {
  const _PremiumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;

    return Card(
      color: colorScheme.primary.withValues(alpha: 0.10),
      child: ListTile(
        leading: Icon(
          isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
          color: colorScheme.primary,
        ),
        title: Text(isPremium ? 'Kaizen Premium' : 'Free plan',
            style: textTheme.titleSmall),
        subtitle: Text(
          isPremium ? 'AI features unlocked' : 'Unlock AI — \$10/mo',
          style: textTheme.bodySmall,
        ),
        trailing: isPremium
            ? null
            : const Icon(Icons.chevron_right),
        onTap: isPremium ? null : () => context.push('/paywall'),
      ),
    );
  }
}

/// Тон по умолчанию (gentle/harsh) — тот же toneProvider, что и тумблер на Today.
class _ToneSetting extends ConsumerWidget {
  const _ToneSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Default tone', style: textTheme.bodyLarge),
        SegmentedButton<AppTone>(
          segments: const [
            ButtonSegment(value: AppTone.gentle, label: Text('Gentle')),
            ButtonSegment(value: AppTone.harsh, label: Text('Harsh')),
          ],
          selected: {tone},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(toneProvider.notifier).set(s.first),
        ),
      ],
    );
  }
}

/// Размер шрифта (доступность) — влияет на весь интерфейс.
class _TextSizeSetting extends ConsumerWidget {
  const _TextSizeSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(textScaleProvider);
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Text size', style: textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TextSizePref.values.map((p) {
            return ChoiceChip(
              label: Text(p.label),
              selected: current == p,
              onSelected: (_) => ref.read(textScaleProvider.notifier).set(p),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Версия приложения внизу профиля (просьба с ревью MVP: видеть, какая
/// сборка стоит на устройстве). В debug-сборке помечается «debug».
class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox(height: 16);
        final debugSuffix = kDebugMode ? ' · debug' : '';
        return Text(
          'Version ${info.version} (${info.buildNumber})$debugSuffix',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        );
      },
    );
  }
}

/// Одна цифра в карточке streak (значение + подпись).
class _StreakStat extends StatelessWidget {
  const _StreakStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}
