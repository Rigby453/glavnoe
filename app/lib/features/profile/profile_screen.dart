// Экран профиля (не таб). Показывает статус аккаунта и кнопку выхода/входа.
// При выходе routerProvider уводит на /auth.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/text_scale_provider.dart';
import '../../core/utils/id.dart';
import 'shared_plan.dart';
import '../../core/l10n/locale_provider.dart';
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _StreakStat(label: 'Streak', value: '${streak?.current ?? 0}'),
                        _StreakStat(label: 'Best', value: '${streak?.longest ?? 0}'),
                        Tooltip(
                          message: 'Freeze protects your streak\nif you miss a day.',
                          child: _StreakStat(
                            label: 'Freezes ❄️',
                            value: '${streak?.freezeCount ?? 0}',
                          ),
                        ),
                      ],
                    ),
                    if ((streak?.freezeCount ?? 0) > 0) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('😌', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Give yourself a day off — a freeze will protect your streak automatically if you miss today.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _PremiumCard(),
            const SizedBox(height: 16),
            const _ShareWeekCard(),
            const SizedBox(height: 8),
            const _SharedWithMeCard(),
            const SizedBox(height: 24),
            Text('Appearance', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            const _ThemePicker(),
            const SizedBox(height: 24),
            Text('Preferences', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            // --- Язык ---
            Consumer(
              builder: (context, ref, _) {
                final locale = ref.watch(localeNotifierProvider);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  trailing: DropdownButton<String>(
                    value: locale.languageCode,
                    underline: const SizedBox.shrink(),
                    items: localeNames.entries
                        .map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value),
                            ))
                        .toList(),
                    onChanged: (code) {
                      if (code != null) {
                        ref
                            .read(localeNotifierProvider.notifier)
                            .setLocale(Locale(code));
                      }
                    },
                  ),
                );
              },
            ),
            const _ToneSetting(),
            const SizedBox(height: 16),
            const _TextSizeSetting(),
            const SizedBox(height: 8),
            const _NotificationsSetting(),
            const SizedBox(height: 16),
            Text('Support', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.star_border),
              title: const Text('Rate the app'),
              onTap: () {
                // TODO: открыть Store страницу — подставить реальный URL при публикации
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon — we\'re not in the store yet 😊')),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Send feedback'),
              subtitle: const Text('Report a bug or suggest a feature'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email us: support@kaizen.app')),
                );
              },
            ),
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

/// «Поделиться неделей»: view-only веб-ссылка (Ф3, ADR-030).
/// Ссылка живёт 7 дней; друг открывает её в браузере без приложения.
class _ShareWeekCard extends ConsumerStatefulWidget {
  const _ShareWeekCard();

  @override
  ConsumerState<_ShareWeekCard> createState() => _ShareWeekCardState();
}

class _ShareWeekCardState extends ConsumerState<_ShareWeekCard> {
  bool _working = false;

  Future<void> _share() async {
    final api = ref.read(apiClientProvider);
    if (api.token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to share your plan')),
      );
      return;
    }

    setState(() => _working = true);
    try {
      // Текущая неделя: с сегодняшнего дня на 7 дней вперёд.
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final url = await api.createShareLink(
        from: from,
        to: from.add(const Duration(days: 7)),
      );
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied — valid for 7 days, view-only'),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: _working
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(Icons.ios_share, color: colorScheme.primary),
        title: const Text('Share my week'),
        subtitle: const Text('View-only web link · friends need no app'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _working ? null : _share,
      ),
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

// ---------------------------------------------------------------------------
// «Поделились со мной» (SPEC C7, Ф3, v1)
// ---------------------------------------------------------------------------

/// Карточка «Shared with me»: вставить ссылку/токен → посмотреть
/// read-only план друга → скопировать события к себе.
class _SharedWithMeCard extends ConsumerStatefulWidget {
  const _SharedWithMeCard();

  @override
  ConsumerState<_SharedWithMeCard> createState() => _SharedWithMeCardState();
}

class _SharedWithMeCardState extends ConsumerState<_SharedWithMeCard> {
  // Форматтер для заголовков дней
  static final _dayFmt = DateFormat('EEE, d MMM');
  // Форматтер для времени событий
  static final _timeFmt = DateFormat('HH:mm');

  /// Диалог ввода ссылки/токена, затем загрузка и показ шита.
  Future<void> _openDialog() async {
    final controller = TextEditingController();

    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Shared with me"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste link or token',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Open'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (submitted == null || submitted.trim().isEmpty) return;
    if (!mounted) return;

    final token = extractShareToken(submitted);
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid link or token')),
      );
      return;
    }

    await _loadAndShow(token);
  }

  /// Загружает план по токену и открывает шит просмотра.
  Future<void> _loadAndShow(String token) async {
    final api = ref.read(apiClientProvider);
    Map<String, dynamic> plan;
    try {
      plan = await api.fetchSharedPlan(token);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error — check your connection')),
        );
      }
      return;
    }

    if (!mounted) return;
    await _showPlanSheet(plan);
  }

  /// Шит с read-only списком событий и кнопкой «Copy to my plan».
  Future<void> _showPlanSheet(Map<String, dynamic> plan) async {
    final ownerName = (plan['owner_name'] as String?) ?? 'Friend';
    final fromRaw = plan['from'] as String?;
    final toRaw = plan['to'] as String?;

    // Диапазон для заголовка шита
    String rangeLabel = '';
    if (fromRaw != null && toRaw != null) {
      try {
        final from = DateTime.parse(fromRaw).toLocal();
        final to = DateTime.parse(toRaw).toLocal();
        rangeLabel = '${_dayFmt.format(from)} – ${_dayFmt.format(to)}';
      } catch (_) {}
    }

    final rawItems = (plan['items'] as List<dynamic>?) ?? <dynamic>[];

    // Группируем события по дням
    final Map<String, List<Map<String, dynamic>>> byDay = {};
    for (final raw in rawItems) {
      final item = raw as Map<String, dynamic>;
      final scheduledRaw = item['scheduled_at'] as String?;
      if (scheduledRaw == null) continue;
      DateTime dt;
      try {
        dt = DateTime.parse(scheduledRaw).toLocal();
      } catch (_) {
        continue;
      }
      final dayKey = DateFormat('yyyy-MM-dd').format(dt);
      byDay.putIfAbsent(dayKey, () => []).add({...item, '_dt': dt});
    }

    // Упорядоченные ключи дней
    final sortedDays = byDay.keys.toList()..sort();

    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PlanSheetContent(
        ownerName: ownerName,
        rangeLabel: rangeLabel,
        sortedDays: sortedDays,
        byDay: byDay,
        dayFmt: _dayFmt,
        timeFmt: _timeFmt,
        rawItems: rawItems,
        onCopy: (items) => _copyToMyPlan(ctx, items),
      ),
    );
  }

  /// Вставляет каждый элемент как локальную задачу через ItemsDao.
  Future<void> _copyToMyPlan(
    BuildContext sheetCtx,
    List<dynamic> rawItems,
  ) async {
    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    int copied = 0;

    for (final raw in rawItems) {
      final item = raw as Map<String, dynamic>;
      final scheduledRaw = item['scheduled_at'] as String?;
      if (scheduledRaw == null) continue;
      DateTime scheduledAt;
      try {
        scheduledAt = DateTime.parse(scheduledRaw).toLocal();
      } catch (_) {
        continue;
      }

      final title = (item['title'] as String?) ?? '';
      if (title.isEmpty) continue;

      final type = (item['type'] as String?) ?? 'task';
      final durationMinutes = (item['duration_minutes'] as int?) ?? 30;

      await dao.insertItem(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: const Value('local'),
          title: Value(title),
          type: Value(type),
          priority: const Value('medium'),
          status: const Value('pending'),
          scheduledAt: Value(scheduledAt),
          durationMinutes: Value(durationMinutes),
          isProtected: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      copied++;
    }

    // Закрываем шит и показываем снэкбар
    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$copied event${copied == 1 ? '' : 's'} copied to your plan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(Icons.group_outlined, color: colorScheme.primary),
        title: const Text('Shared with me'),
        subtitle: const Text("Open a friend's plan link"),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openDialog,
      ),
    );
  }
}

/// Содержимое шита просмотра чужого плана.
/// Вынесен в отдельный StatelessWidget, чтобы не тянуть BuildContext шита
/// в _SharedWithMeCardState и избежать mounted-проблем.
class _PlanSheetContent extends StatelessWidget {
  const _PlanSheetContent({
    required this.ownerName,
    required this.rangeLabel,
    required this.sortedDays,
    required this.byDay,
    required this.dayFmt,
    required this.timeFmt,
    required this.rawItems,
    required this.onCopy,
  });

  final String ownerName;
  final String rangeLabel;
  final List<String> sortedDays;
  final Map<String, List<Map<String, dynamic>>> byDay;
  final DateFormat dayFmt;
  final DateFormat timeFmt;
  final List<dynamic> rawItems;
  final void Function(List<dynamic>) onCopy;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollController) => Column(
        children: [
          // Ручка шита
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Заголовок
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$ownerName's plan",
                        style: textTheme.titleLarge,
                      ),
                      if (rangeLabel.isNotEmpty)
                        Text(rangeLabel, style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          // Список событий
          Expanded(
            child: rawItems.isEmpty
                ? Center(
                    child: Text(
                      'No events in this plan',
                      style: textTheme.bodyMedium,
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _itemCount(),
                    itemBuilder: (_, index) => _buildRow(context, index),
                  ),
          ),
          // Кнопка копирования
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: FilledButton(
              onPressed: rawItems.isEmpty ? null : () => onCopy(rawItems),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text('Copy to my plan (${rawItems.length} event${rawItems.length == 1 ? '' : 's'})'),
            ),
          ),
        ],
      ),
    );
  }

  /// Общее количество строк: заголовок дня + строки событий.
  int _itemCount() {
    int count = 0;
    for (final day in sortedDays) {
      count += 1 + (byDay[day]?.length ?? 0);
    }
    return count;
  }

  /// Строит строку списка: либо заголовок дня, либо строку события.
  Widget _buildRow(BuildContext context, int flatIndex) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    int cursor = 0;
    for (final day in sortedDays) {
      if (flatIndex == cursor) {
        // Заголовок дня
        DateTime? dt;
        try {
          dt = DateTime.parse(day);
        } catch (_) {}
        final label = dt != null ? dayFmt.format(dt) : day;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(label, style: textTheme.labelLarge),
        );
      }
      cursor++;
      final events = byDay[day] ?? [];
      if (flatIndex < cursor + events.length) {
        final item = events[flatIndex - cursor];
        final dt = item['_dt'] as DateTime?;
        final timeLabel = dt != null ? timeFmt.format(dt) : '--:--';
        final title = (item['title'] as String?) ?? '';
        final type = (item['type'] as String?) ?? 'task';

        return ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          leading: Icon(
            _typeIcon(type),
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          title: Text(title, style: textTheme.bodyMedium),
          trailing: Text(
            '$timeLabel · $type',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        );
      }
      cursor += events.length;
    }
    return const SizedBox.shrink();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'event':
        return Icons.event_outlined;
      case 'exam':
        return Icons.school_outlined;
      case 'deadline':
        return Icons.flag_outlined;
      default:
        return Icons.check_circle_outline;
    }
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
