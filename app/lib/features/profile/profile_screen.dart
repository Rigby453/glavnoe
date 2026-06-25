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
import '../mascot/kai_mascot.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/reminder_default_provider.dart';
import '../../core/settings/rest_default_provider.dart';
import '../../core/settings/sound_provider.dart';
import '../../core/settings/swipe_action_provider.dart';
import '../../core/settings/task_presets_provider.dart';
import '../../core/settings/text_scale_provider.dart';
import '../../core/settings/timezone_provider.dart';
import '../../core/widgets/number_input_dialog.dart';
import '../../core/utils/id.dart';
import 'shared_plan.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/mood/mood_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../services/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/custom_theme_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../core/settings/fab_position_provider.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/streak/freeze_accrual_service.dart';
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

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // Начислить созревшие заморозки при открытии профиля.
    // Делаем это постфреймово, чтобы ref был готов.
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAccrual());
  }

  Future<void> _runAccrual() async {
    if (!mounted) return;
    final isPremium = ref.read(isPremiumProvider).valueOrNull ?? false;
    final svc = ref.read(freezeAccrualServiceProvider);
    final result = await svc.accrueIfNeeded(isPremium: isPremium);

    if (!mounted) return;

    // Показать снэкбар при начислении.
    if (result.addedFreezes > 0) {
      final msg = result.addedFreezes == 1
          ? context.s('streak.freeze_accrued').replaceAll('{n}', '1')
          : context.s('streak.freezes_accrued')
              .replaceAll('{n}', '${result.addedFreezes}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }

    // Показать снэкбар за каждый новый порог наград.
    for (final threshold in result.newlyClaimedThresholds) {
      if (!mounted) break;
      final rewardLabel = _rewardLabel(context, threshold);
      final msg = context
          .s('streak.freeze_reward_granted')
          .replaceAll('{reward}', rewardLabel);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Локализованное название награды по порогу.
  String _rewardLabel(BuildContext ctx, int threshold) {
    switch (threshold) {
      case 10:
        return ctx.s('streak.freeze_reward_10');
      case 25:
        return ctx.s('streak.freeze_reward_25');
      case 50:
        return ctx.s('streak.freeze_reward_50');
      default:
        return '$threshold';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final userAsync = ref.watch(currentUserProvider);
    final streak = ref.watch(_streakProvider).valueOrNull;
    final isAuthenticated =
        ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('profile.title'))),
      body: Padding(
        // Отступы экрана: 24dp по бокам (02-type-space.md §4.1 lg = 24dp)
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                children: [
                  _buildHeader(context, ref, userAsync, textTheme, streak, ext),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Выход / вход — деструктивный/акцентный: ember для Sign Out, filled для Sign In
            isAuthenticated
                ? OutlinedButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ext.ember,
                      side: BorderSide(color: ext.ember),
                    ),
                    child: Text(context.s('btn.sign_out')),
                  )
                : FilledButton(
                    onPressed: () async {
                      await ref.read(authControllerProvider.notifier).logout();
                    },
                    child: Text(context.s('btn.sign_in')),
                  ),
            const SizedBox(height: 12),
            const _AppVersionLabel(),
            const SizedBox(height: 8),
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
    FocusThemeExtension ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок аккаунта
        userAsync.when(
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: KaiLoader(label: context.s('loading.generic')),
            ),
          ),
          error: (_, _) => const SizedBox.shrink(),
          data: (user) {
            if (user == null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.s('profile.offline_mode'), style: textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text(
                    context.s('profile.offline_subtitle'),
                    style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user['name'] as String?) ?? context.s('profile.you'),
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  (user['email'] as String?) ?? '',
                  style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 24),

        // Карточка streak + заморозки с прогрессом к награде
        _FreezeCard(streak: streak),

        const SizedBox(height: 12),
        const _PremiumCard(),
        const SizedBox(height: 8),
        const _ShareWeekCard(),
        const SizedBox(height: 8),
        const _SharedWithMeCard(),

        // Кнопка «Мои данные» — единая точка для тела/макросов/питания/здоровья
        const SizedBox(height: 16),
        const _MyDataTile(),

        // Секция «Задачи по умолчанию»
        const SizedBox(height: 28),
        const _TaskDefaultsSection(),

        // Секция «Тренировки» (#23): глобальное время отдыха по умолчанию
        const SizedBox(height: 28),
        const _WorkoutDefaultsSection(),

        // Секция «Внешний вид»
        const SizedBox(height: 28),
        Text(context.s('profile.section_appearance'), style: textTheme.titleMedium),
        const SizedBox(height: 12),
        const _ThemePicker(),

        // Секция «Настройки»
        const SizedBox(height: 28),
        Text(context.s('profile.section_preferences'), style: textTheme.titleMedium),
        const SizedBox(height: 8),

        // Язык
        Consumer(
          builder: (context, ref, _) {
            final locale = ref.watch(localeNotifierProvider);
            // Канонический тег текущей локали: 'en', 'ru', 'pt-BR', 'es-ES' и т.д.
            final currentTag = localeTag(locale);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              // Иконки настроек нейтральные (textMuted) — не accent (03-components §19)
              leading: Icon(Icons.language, color: ext.textMuted),
              title: Text(context.s('profile.language')),
              // Ограничиваем ширину дропдауна, иначе самый длинный пункт
              // («Português (Brasil)») распирает ListTile и вызывает overflow
              // на узких экранах (320px) и при крупном масштабе текста.
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: DropdownButton<String>(
                value: currentTag,
                // В рамках ограниченной ширины выбранное имя обрезается «…»,
                // а не распирает строку. Меню при открытии не ограничено —
                // полные имена видны.
                isExpanded: true,
                underline: const SizedBox.shrink(),
                // Непрозрачный фон меню (иначе контент страницы просвечивает).
                // DropdownButton не читает popupMenuTheme — задаём явно.
                dropdownColor: ext.surfaceElevated,
                items: localeEntries
                    .map((e) => DropdownMenuItem(
                          value: localeTag(e.locale),
                          child: Text(e.displayName),
                        ))
                    .toList(),
                onChanged: (tag) {
                  if (tag != null) {
                    // Найти Locale в localeEntries по тегу
                    final entry = localeEntries.firstWhere(
                      (e) => localeTag(e.locale) == tag,
                      orElse: () => const LocaleEntry(Locale('en'), 'English'),
                    );
                    ref
                        .read(localeNotifierProvider.notifier)
                        .setLocale(entry.locale);
                  }
                },
                ),
              ),
            );
          },
        ),

        const _MoodKaiSection(),
        const SizedBox(height: 16),
        const _TextSizeSetting(),
        const SizedBox(height: 8),
        const _FabPositionSetting(),
        const SizedBox(height: 8),
        const _NotificationsSetting(),
        const _CompletionSoundSetting(),
        const _ShowKaiSetting(),
        const _SwipeActionsSetting(),
        const _TimezoneSetting(),

        // Секция «Поддержка»
        const SizedBox(height: 28),
        Text(context.s('profile.section_support'), style: textTheme.titleMedium),
        const SizedBox(height: 8),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.star_border, color: ext.textMuted),
          title: Text(context.s('profile.rate_app')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.s('profile.rate_coming_soon'))),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.feedback_outlined, color: ext.textMuted),
          title: Text(context.s('profile.send_feedback')),
          subtitle: Text(context.s('profile.feedback_subtitle')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.s('profile.feedback_email'))),
            );
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.description_outlined, color: ext.textMuted),
          title: Text(context.s('profile.terms_privacy')),
          trailing: Icon(Icons.chevron_right, color: ext.textMuted),
          onTap: () => context.push('/terms'),
        ),

        // Реферальная карточка
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.s('profile.invite_title'),
                            style: textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.s('profile.invite_subtitle'),
                            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Вторичная кнопка поделиться (не единственная CTA) — Outlined
                OutlinedButton.icon(
                  icon: const Icon(Icons.share, size: 16),
                  label: Text(context.s('profile.share_kaizen')),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.s('profile.referral_coming_soon')),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка стрика + заморозок с прогрессом наград
// ---------------------------------------------------------------------------

/// Карточка со статистикой стрика, числом заморозок и прогресс-баром к
/// ближайшей награде за накопление заморозок.
class _FreezeCard extends ConsumerWidget {
  const _FreezeCard({this.streak});

  final StreakTableData? streak;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final freezes = streak?.freezeCount ?? 0;

    final svc = ref.read(freezeAccrualServiceProvider);
    final nextThreshold = svc.nextRewardThreshold(freezes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Строка с тремя статами
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _StreakStat(
                    label: context.s('profile.streak'),
                    value: '${streak?.current ?? 0}',
                  ),
                ),
                Expanded(
                  child: _StreakStat(
                    label: context.s('profile.streak_best'),
                    value: '${streak?.longest ?? 0}',
                  ),
                ),
                Expanded(
                  child: Tooltip(
                    message: context.s('streak.freeze'),
                    child: _StreakStat(
                      label: context.s('profile.streak_freezes'),
                      value: '$freezes',
                    ),
                  ),
                ),
              ],
            ),

            // Подсказка про заморозку (если есть хотя бы одна)
            if (freezes > 0) ...[
              const SizedBox(height: 12),
              Divider(color: ext.border, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('😌', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.s('profile.freeze_hint'),
                      style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    ),
                  ),
                ],
              ),
            ],

            // Прогресс к ближайшей награде
            if (nextThreshold != null) ...[
              const SizedBox(height: 12),
              Divider(color: ext.border, height: 1),
              const SizedBox(height: 12),
              _FreezeRewardProgress(
                currentFreezes: freezes,
                threshold: nextThreshold,
              ),
            ] else ...[
              // Все награды получены
              const SizedBox(height: 12),
              Divider(color: ext.border, height: 1),
              const SizedBox(height: 8),
              Text(
                context.s('streak.freeze_reward_all_claimed'),
                style: textTheme.bodySmall?.copyWith(color: ext.success),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Прогресс-бар + подпись к ближайшей награде за заморозки.
class _FreezeRewardProgress extends StatelessWidget {
  const _FreezeRewardProgress({
    required this.currentFreezes,
    required this.threshold,
  });

  final int currentFreezes;
  final FreezeRewardThreshold threshold;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final progress =
        (currentFreezes / threshold.freezeCount).clamp(0.0, 1.0);

    final rewardKey = switch (threshold.freezeCount) {
      10 => 'streak.freeze_reward_10',
      25 => 'streak.freeze_reward_25',
      50 => 'streak.freeze_reward_50',
      _ => 'streak.freeze_reward_10',
    };
    final rewardLabel = context.s(rewardKey);

    final progressLabel = context
        .s('streak.freeze_progress_to_reward')
        .replaceAll('{current}', '$currentFreezes')
        .replaceAll('{target}', '${threshold.freezeCount}')
        .replaceAll('{reward}', rewardLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text('🧊', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                progressLabel,
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: ext.border,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.primary,
            ),
          ),
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
      title: Text(context.s('profile.notifications')),
      subtitle: Text(context.s('profile.notifications_subtitle')),
      value: enabled,
      onChanged: (want) async {
        final result = await ref
            .read(notificationsEnabledProvider.notifier)
            .setEnabled(want);
        if (want && !result && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.s('profile.notifications_snackbar')),
            ),
          );
        }
      },
    );
  }
}

/// Тумблер отображения маскота Kai на экране Today (MASCOT.md §6, ADR-032).
/// Взрослая аудитория может отключить присутствие — функционал не страдает.
class _ShowKaiSetting extends ConsumerWidget {
  const _ShowKaiSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showKai = ref.watch(showKaiProvider);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.s('profile.show_kai')),
      subtitle: Text(context.s('profile.show_kai_subtitle')),
      value: showKai,
      onChanged: (_) => ref.read(showKaiProvider.notifier).toggle(),
    );
  }
}

/// Тумблер звука при выполнении задачи. Стиль — как _NotificationsSetting.
class _CompletionSoundSetting extends ConsumerWidget {
  const _CompletionSoundSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(completionSoundEnabledProvider);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(context.s('profile.completion_sound')),
      subtitle: Text(context.s('profile.completion_sound_subtitle')),
      value: enabled,
      onChanged: (want) =>
          ref.read(completionSoundEnabledProvider.notifier).set(want),
    );
  }
}

/// Настройка действий свайпа по задачам: две строки (вправо/влево),
/// каждая — Dropdown из 4 действий (done/skip/delete/snooze) с иконкой+подписью.
/// Стиль строки — как «Язык» (ListTile + DropdownButton).
class _SwipeActionsSetting extends ConsumerWidget {
  const _SwipeActionsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final config = ref.watch(swipeActionsProvider);

    Widget row({
      required IconData leadingIcon,
      required String title,
      required SwipeAction current,
      required ValueChanged<SwipeAction> onChanged,
    }) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(leadingIcon, color: ext.textMuted),
        title: Text(title),
        trailing: DropdownButton<SwipeAction>(
          value: current,
          underline: const SizedBox.shrink(),
          dropdownColor: ext.surfaceElevated,
          items: SwipeAction.values
              .map((a) => DropdownMenuItem(
                    value: a,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(a.icon, size: 18, color: a.color(context)),
                        const SizedBox(width: 8),
                        Text(a.label(context)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (a) {
            if (a != null) onChanged(a);
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          leadingIcon: Icons.swipe_right_alt,
          title: context.s('profile.swipe_right'),
          current: config.right,
          onChanged: (a) =>
              ref.read(swipeActionsProvider.notifier).setRight(a),
        ),
        row(
          leadingIcon: Icons.swipe_left_alt,
          title: context.s('profile.swipe_left'),
          current: config.left,
          onChanged: (a) =>
              ref.read(swipeActionsProvider.notifier).setLeft(a),
        ),
      ],
    );
  }
}

/// Настройка часового пояса. Строка-ListTile (как «Язык»), но из-за большого
/// числа зон выбор открывается прокручиваемым боттомшитом, а не Dropdown.
class _TimezoneSetting extends ConsumerWidget {
  const _TimezoneSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final pref = ref.watch(timezoneOverrideProvider);

    final currentLabel =
        pref.isAuto ? context.s('profile.timezone_auto') : pref.iana!;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.schedule, color: ext.textMuted),
      title: Text(context.s('profile.timezone')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              currentLabel,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: ext.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right, color: ext.textMuted),
        ],
      ),
      onTap: () => _pickTimezone(context, ref, pref),
    );
  }

  Future<void> _pickTimezone(
    BuildContext context,
    WidgetRef ref,
    TimezonePref current,
  ) async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final notifier = ref.read(timezoneOverrideProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ext.surfaceElevated,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ctx.s('profile.timezone_select'),
                          style: Theme.of(ctx).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: ctx.s('btn.close'),
                        onPressed: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                ),
                // Авто (устройство)
                ListTile(
                  title: Text(ctx.s('profile.timezone_auto')),
                  trailing: current.isAuto
                      ? Icon(Icons.check,
                          color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () {
                    notifier.setAuto();
                    Navigator.of(ctx).pop();
                  },
                ),
                const Divider(height: 1),
                // Список зон
                ...kSelectableTimezones.map(
                  (zone) => ListTile(
                    title: Text(zone),
                    trailing: (!current.isAuto && current.iana == zone)
                        ? Icon(Icons.check,
                            color: Theme.of(ctx).colorScheme.primary)
                        : null,
                    onTap: () {
                      notifier.setOverride(zone);
                      Navigator.of(ctx).pop();
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Task defaults section — (Health section moved to MyDataScreen)
// ---------------------------------------------------------------------------

// REMOVED: _HealthProfileSection, _HealthProfileView, _HealthProfileEditor,
//          _MealsPerDayPicker, _MealsCustomDialog, _FoodPreferencesSection,
//          _FoodPreferencesView — all moved to MyDataScreen via extracted widgets.

// ---------------------------------------------------------------------------
// Placeholder sentinel — Task defaults section follows
// ---------------------------------------------------------------------------

// (Inline health/food sections removed — see MyDataScreen)

// ---------------------------------------------------------------------------
// Task defaults section
// ---------------------------------------------------------------------------

/// Секция «Задачи по умолчанию»: глобальное напоминание по умолчанию + редактор
/// пресетов длительности и пресетов напоминаний. Пишет в reminderDefaultProvider,
/// durationPresetsProvider, reminderPresetsProvider.
class _TaskDefaultsSection extends ConsumerWidget {
  const _TaskDefaultsSection();

  /// Локализованная подпись минут: «N мин» либо «в момент» для 0 в режиме
  /// напоминаний.
  static String _minutesLabel(BuildContext context, int minutes,
      {bool reminder = false}) {
    if (reminder && minutes == 0) {
      return context.s('profile.reminder_at_start');
    }
    return '$minutes ${context.s('profile.minutes_short')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final reminderDefault = ref.watch(reminderDefaultProvider);
    final reminderPresets = ref.watch(reminderPresetsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.s('profile.section_task_defaults'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.s('profile.task_defaults_note'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 16),

        // ---- Напоминание по умолчанию: режим ----
        Text(
          context.s('profile.reminder_default_label'),
          style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(
              value: 'none',
              label: Text(context.s('profile.reminder_mode_none')),
            ),
            ButtonSegment(
              value: 'main',
              label: Text(context.s('profile.reminder_mode_main')),
            ),
            ButtonSegment(
              value: 'all',
              label: Text(context.s('profile.reminder_mode_all')),
            ),
          ],
          selected: {reminderDefault.mode},
          showSelectedIcon: false,
          onSelectionChanged: (s) =>
              ref.read(reminderDefaultProvider.notifier).setMode(s.first),
        ),

        // ---- Напоминание по умолчанию: за сколько (если не «Нет») ----
        if (reminderDefault.mode != 'none') ...[
          const SizedBox(height: 16),
          Text(
            context.s('profile.reminder_when_label'),
            style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reminderPresets.map((minutes) {
              return ChoiceChip(
                label: Text(_minutesLabel(context, minutes, reminder: true)),
                selected: reminderDefault.minutes == minutes,
                onSelected: (_) => ref
                    .read(reminderDefaultProvider.notifier)
                    .setMinutes(minutes),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 20),

        // ---- Пресеты длительности ----
        _PresetEditor(
          label: context.s('profile.duration_presets_label'),
          presets: ref.watch(durationPresetsProvider),
          reminder: false,
          onChanged: (list) =>
              ref.read(durationPresetsProvider.notifier).setPresets(list),
        ),

        const SizedBox(height: 20),

        // ---- Пресеты напоминаний ----
        _PresetEditor(
          label: context.s('profile.reminder_presets_label'),
          presets: reminderPresets,
          reminder: true,
          onChanged: (list) =>
              ref.read(reminderPresetsProvider.notifier).setPresets(list),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Workout defaults section (#23)
// ---------------------------------------------------------------------------

/// Секция «Тренировки»: глобальное время отдыха между подходами по умолчанию.
/// Пишет в restDefaultProvider (SharedPreferences). Тренажёр использует это
/// значение, когда у упражнения нет своего restSeconds (effectiveRestSeconds).
class _WorkoutDefaultsSection extends ConsumerWidget {
  const _WorkoutDefaultsSection();

  /// «M:SS» либо «N с» для коротких — компактная подпись текущего значения.
  static String _formatSeconds(BuildContext context, int seconds) {
    if (seconds < 60) {
      return '$seconds ${context.s('workout.seconds_short')}';
    }
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return s == 0 ? '$m:00' : '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _editRest(BuildContext context, WidgetRef ref) async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final current = ref.read(restDefaultProvider);
    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => NumberInputDialog(
        backgroundColor: ext.surfaceElevated,
        title: ctx.s('workout.rest_default_dialog_title'),
        labelText: ctx.s('workout.rest_default_label'),
        suffixText: ctx.s('workout.seconds_short'),
        initialValue: current,
        confirmLabel: ctx.s('btn.done'),
        // Кламп в разумные границы делает сам провайдер (set).
        minValue: kRestDefaultMinSeconds,
      ),
    );
    if (entered == null) return;
    await ref.read(restDefaultProvider.notifier).set(entered);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final restDefault = ref.watch(restDefaultProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.s('workout.section_defaults'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.s('workout.rest_default_note'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            context.s('workout.rest_default_label'),
            style: textTheme.bodyLarge,
          ),
          trailing: Text(
            _formatSeconds(context, restDefault),
            style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
          ),
          onTap: () => _editRest(context, ref),
        ),
      ],
    );
  }
}

/// Редактор списка пресетов (минут): чипы с возможностью удаления (тап по чипу
/// убирает его) + кнопка «Добавить» (диалог ввода минут). Используется для
/// длительностей и для напоминаний (флаг [reminder] меняет подпись 0 минут).
class _PresetEditor extends StatelessWidget {
  const _PresetEditor({
    required this.label,
    required this.presets,
    required this.reminder,
    required this.onChanged,
  });

  final String label;
  final List<int> presets;
  final bool reminder;
  final ValueChanged<List<int>> onChanged;

  String _chipLabel(BuildContext context, int minutes) {
    if (reminder && minutes == 0) {
      return context.s('profile.reminder_at_start');
    }
    return '$minutes ${context.s('profile.minutes_short')}';
  }

  Future<void> _addPreset(BuildContext context) async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    // Контроллером владеет State диалога (NumberInputDialog), он уничтожается
    // после анимации закрытия — исключает краш «used after disposed».
    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => NumberInputDialog(
        backgroundColor: ext.surfaceElevated,
        title: ctx.s('profile.presets_add_minutes_title'),
        labelText: ctx.s('profile.presets_minutes_hint'),
        confirmLabel: ctx.s('profile.presets_add'),
        // Без рамки — как в исходном поле (подчёркивание по умолчанию).
        bordered: false,
        // Нормализацию/валидацию выполнит провайдер; 0 допускаем.
        minValue: 0,
      ),
    );
    if (entered == null) return;
    // Нормализацию/валидацию выполнит провайдер; здесь просто добавляем.
    onChanged([...presets, entered]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((minutes) {
              return InputChip(
                label: Text(_chipLabel(context, minutes)),
                onDeleted: presets.length > 1
                    ? () => onChanged(
                        presets.where((m) => m != minutes).toList())
                    : null,
              );
            }),
            ActionChip(
              avatar: Icon(Icons.add, size: 16, color: ext.textMuted),
              label: Text(context.s('profile.presets_add')),
              onPressed: () => _addPreset(context),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// My Data tile
// ---------------------------------------------------------------------------

/// Строка «Мои данные» — ведёт на MyDataScreen.
/// Объединяет параметры тела, макросы, пищевые предпочтения и профиль здоровья.
class _MyDataTile extends StatelessWidget {
  const _MyDataTile();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.tune_rounded, color: ext.textMuted),
      title: Text(
        context.s('profile.my_data'),
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        context.s('profile.my_data_subtitle'),
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: ext.textMuted),
      ),
      trailing: Icon(Icons.chevron_right, color: ext.textMuted),
      onTap: () => context.push('/profile/my-data'),
    );
  }
}

/// Выбор темы оформления. Доступны все 5 предустановленных тем + пользовательская.
class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  static const _available = [
    (AppThemeKey.focus, 'profile.theme_focus'),
    (AppThemeKey.calm, 'profile.theme_calm'),
    (AppThemeKey.black, 'profile.theme_black'),
    (AppThemeKey.white, 'profile.theme_white'),
    (AppThemeKey.contrast, 'profile.theme_contrast'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeNotifierProvider);
    final hasCustom = ref.watch(customThemeNotifierProvider) != null;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Предустановленные темы — selected = accent, unselected = neutral (03-components §11)
        ..._available.map((entry) {
          final (key, labelKey) = entry;
          return ChoiceChip(
            label: Text(context.s(labelKey)),
            selected: current == key,
            onSelected: (_) =>
                ref.read(themeNotifierProvider.notifier).setTheme(key),
          );
        }),

        // 6-й чип — «Мой стиль» (custom) + кнопка редактирования
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ChoiceChip(
              label: Text(context.s('profile.theme_custom')),
              selected: current == AppThemeKey.custom,
              onSelected: (_) {
                if (hasCustom) {
                  ref
                      .read(themeNotifierProvider.notifier)
                      .setTheme(AppThemeKey.custom);
                } else {
                  context.push('/profile/custom-theme');
                }
              },
            ),
            if (hasCustom) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: context.s('profile.theme_custom_edit'),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => context.push('/profile/custom-theme'),
              ),
            ],
          ],
        ),
      ],
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
        SnackBar(content: Text(context.s('profile.share_sign_in'))),
      );
      return;
    }

    setState(() => _working = true);
    try {
      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final url = await api.createShareLink(
        from: from,
        to: from.add(const Duration(days: 7)),
      );
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.s('profile.share_link_copied')),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Card(
      child: ListTile(
        // Иконка нейтральная (textMuted); primary — только одна CTA на экране
        leading: _working
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : Icon(Icons.ios_share, color: ext.textMuted),
        title: Text(context.s('profile.share_week')),
        subtitle: Text(context.s('profile.share_week_subtitle')),
        trailing: Icon(Icons.chevron_right, color: ext.textMuted),
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;

    return Card(
      // Акцентный фон только для премиум (как отличительный маркер активного статуса)
      // Для free — стандартный surface
      color: isPremium
          ? ext.accentMuted
          : null,
      child: ListTile(
        leading: Icon(
          isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
          // Иконка акцентная только для Premium (сигнал успеха), для free — нейтральная
          color: isPremium
              ? Theme.of(context).colorScheme.primary
              : ext.textMuted,
        ),
        title: Text(
          isPremium ? context.s('profile.premium_badge') : context.s('profile.free_plan'),
          style: textTheme.titleSmall,
        ),
        subtitle: Text(
          isPremium ? context.s('profile.premium_unlocked') : context.s('profile.premium_unlock_cta'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        trailing: isPremium
            ? null
            : Icon(Icons.chevron_right, color: ext.textMuted),
        onTap: isPremium ? null : () => context.push('/paywall'),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Пульт управления настроем «Настрой и Kai»
// ---------------------------------------------------------------------------

/// Секция «Настрой и Kai» в Профиле.
/// 3 кнопки-пресета + раскрываемая тонкая настройка (тон + интенсивность + превью).
class _MoodKaiSection extends ConsumerStatefulWidget {
  const _MoodKaiSection();

  @override
  ConsumerState<_MoodKaiSection> createState() => _MoodKaiSectionState();
}

class _MoodKaiSectionState extends ConsumerState<_MoodKaiSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final mood = ref.watch(effectiveMoodProvider);
    final intensity = ref.watch(reactiveIntensityProvider);
    final tone = ref.watch(toneProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции
        Text(context.s('profile.section_mood_kai'), style: textTheme.titleMedium),
        const SizedBox(height: 12),

        // 3 кнопки-пресета
        Row(
          children: [
            _PresetChip(
              emoji: '🌿',
              label: context.s('mood.preset_calm'),
              subtitle: context.s('mood.preset_calm_subtitle'),
              isActive: tone == AppTone.gentle && intensity == ReactiveIntensity.off,
              onTap: () => applyMoodPreset(ref, MoodPreset.calm),
            ),
            const SizedBox(width: 8),
            _PresetChip(
              emoji: '⚖️',
              label: context.s('mood.preset_normal'),
              subtitle: context.s('mood.preset_normal_subtitle'),
              isActive: tone == AppTone.gentle && intensity == ReactiveIntensity.slight,
              onTap: () => applyMoodPreset(ref, MoodPreset.normal),
            ),
            const SizedBox(width: 8),
            _PresetChip(
              emoji: '🔥',
              label: context.s('mood.preset_coach'),
              subtitle: context.s('mood.preset_coach_subtitle'),
              isActive: tone == AppTone.harsh && intensity == ReactiveIntensity.full,
              onTap: () => applyMoodPreset(ref, MoodPreset.coach),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Раскрывающаяся тонкая настройка
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(
                  context.s('mood.fine_tuning'),
                  style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: ext.textMuted,
                ),
              ],
            ),
          ),
        ),

        if (_expanded) ...[
          const SizedBox(height: 12),

          // Тумблер тона (переиспользуем логику _ToneSetting)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.s('profile.default_tone'),
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<AppTone>(
                segments: [
                  ButtonSegment(
                    value: AppTone.gentle,
                    label: Text(context.s('settings.gentle')),
                  ),
                  ButtonSegment(
                    value: AppTone.harsh,
                    label: Text(context.s('settings.harsh')),
                  ),
                ],
                selected: {tone},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(toneProvider.notifier).set(s.first),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Интенсивность реакции
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.s('mood.reaction_to_laziness'),
                  style: textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 12),
              SegmentedButton<ReactiveIntensity>(
                segments: [
                  ButtonSegment(
                    value: ReactiveIntensity.off,
                    label: Text(context.s('mood.intensity_off')),
                  ),
                  ButtonSegment(
                    value: ReactiveIntensity.slight,
                    label: Text(context.s('mood.intensity_slight')),
                  ),
                  ButtonSegment(
                    value: ReactiveIntensity.full,
                    label: Text(context.s('mood.intensity_full')),
                  ),
                ],
                selected: {intensity},
                showSelectedIcon: false,
                onSelectionChanged: (s) =>
                    ref.read(reactiveIntensityProvider.notifier).set(s.first),
              ),
            ],
          ),

          const SizedBox(height: 16),
        ],

        // Живое превью тона: всегда видно (и в свёрнутом виде), чтобы связь
        // «тон → оформление» читалась сразу при переключении сегмента.
        const SizedBox(height: 12),
        _TonePreview(tone: tone, mood: mood),
      ],
    );
  }
}

/// Одна кнопка-пресет настроя.
class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.isActive,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final String subtitle;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.12)
                : colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? colorScheme.primary : ext.border,
              width: isActive ? 1.5 : 0.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: textTheme.labelSmall?.copyWith(
                  color: isActive ? colorScheme.primary : null,
                  fontWeight: isActive ? FontWeight.w700 : null,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Живое превью тона: образец фразы Kai в выбранном тоне.
///
/// Цель — мгновенно показать связь «тон → оформление». gentle и harsh
/// отличаются НЕ только текстом:
///   • акцент (gentle = accent/primary, harsh = ember) — рамка, иконка, бейдж;
///   • скругление карточки (gentle мягче, harsh резче);
///   • иконка/эмодзи (🌿 росток / 🔥 молния);
///   • плотность заголовка («вайб»-бейдж) и сам копирайт (мягкий/резкий);
///   • Kai-маскот в соответствующем выражении (isHarsh).
/// Свап между тонами анимирован (AnimatedContainer + switcher), чтобы
/// переключение читалось как «живая» смена режима.
class _TonePreview extends StatelessWidget {
  const _TonePreview({required this.tone, required this.mood});

  final AppTone tone;
  final EffectiveMood mood;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final v = ToneVisuals.of(context, tone);

    // Выражение Kai: harsh-тон делает его строгим, иначе ведём от настроения дня.
    final previewEmotion = v.isHarsh
        ? KaiEmotion.harsh
        : switch (mood.level) {
            MoodLevel.angry => KaiEmotion.harsh,
            MoodLevel.stern => KaiEmotion.anxious,
            MoodLevel.neutral => KaiEmotion.neutral,
            MoodLevel.calm => KaiEmotion.success,
          };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        // Лёгкая заливка акцентом тона — harsh ember, gentle accent.
        color: v.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(v.cornerRadius),
        border: Border.all(
          color: v.accent.withValues(alpha: v.isHarsh ? 0.85 : 0.45),
          width: v.isHarsh ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          KaiMascot(
            size: 48,
            emotion: previewEmotion,
            isHarsh: v.isHarsh,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // «Вайб»-бейдж: иконка тона + одно слово, в акцентном цвете.
                Row(
                  children: [
                    Icon(v.icon, size: 15, color: v.accent),
                    const SizedBox(width: 5),
                    Text(
                      '${v.emoji} ${KaiCopy.previewVibe(context, tone)}',
                      style: textTheme.labelSmall?.copyWith(
                        color: v.accent,
                        fontWeight: v.headingWeight,
                        letterSpacing: v.isHarsh ? 0.4 : 0.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Сам образец фразы — меняется со сменой тона (с кроссфейдом).
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    KaiCopy.preview(context, tone),
                    key: ValueKey(tone),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      // harsh — плотнее/строже, gentle — обычный.
                      fontWeight:
                          v.isHarsh ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
        Text(context.s('profile.text_size'), style: textTheme.bodyLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: TextSizePref.values.map((p) {
            // Маппинг enum → ключ локализации (резолвится здесь, в виджете)
            final labelKey = switch (p) {
              TextSizePref.small => 'profile.text_size_small',
              TextSizePref.normal => 'profile.text_size_default',
              TextSizePref.large => 'profile.text_size_large',
              TextSizePref.larger => 'profile.text_size_xlarge',
            };
            return ChoiceChip(
              label: Text(context.s(labelKey)),
              selected: current == p,
              onSelected: (_) => ref.read(textScaleProvider.notifier).set(p),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// FAB position setting
// ---------------------------------------------------------------------------

/// Выбор горизонтального положения кнопки «+» (FAB).
/// SegmentedButton из трёх позиций: Left / Center / Right.
/// Сохраняет выбор в fabPositionProvider (SharedPreferences).
class _FabPositionSetting extends ConsumerWidget {
  const _FabPositionSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(fabPositionProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.add_circle_outline, color: ext.textMuted),
          title: Text(context.s('profile.fab_position')),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<FabPosition>(
              segments: [
                ButtonSegment(
                  value: FabPosition.left,
                  label: Text(
                    context.s('profile.fab_position_left'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: const Icon(Icons.align_horizontal_left, size: 16),
                ),
                ButtonSegment(
                  value: FabPosition.center,
                  label: Text(
                    context.s('profile.fab_position_center'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: const Icon(Icons.align_horizontal_center, size: 16),
                ),
                ButtonSegment(
                  value: FabPosition.right,
                  label: Text(
                    context.s('profile.fab_position_right'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  icon: const Icon(Icons.align_horizontal_right, size: 16),
                ),
              ],
              selected: {current},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  ref.read(fabPositionProvider.notifier).set(s.first),
            ),
          ),
          // isThreeLine даёт лишний вертикальный отступ — не нужен, subtitle не текст
          isThreeLine: false,
        ),
      ],
    );
  }
}

/// Версия приложения внизу профиля.
class _AppVersionLabel extends StatelessWidget {
  const _AppVersionLabel();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox(height: 16);
        final debugSuffix = kDebugMode ? ' · debug' : '';
        return Text(
          'Version ${info.version} (${info.buildNumber})$debugSuffix',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
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
  static final _dayFmt = DateFormat('EEE, d MMM');
  static final _timeFmt = DateFormat('HH:mm');

  late final TextEditingController _linkController;

  @override
  void initState() {
    super.initState();
    _linkController = TextEditingController();
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _openDialog() async {
    _linkController.clear();

    final submitted = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.s('profile.shared_with_me')),
        content: TextField(
          controller: _linkController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: context.s('profile.paste_link_hint'),
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_linkController.text),
            child: Text(context.s('profile.open')),
          ),
        ],
      ),
    );

    if (submitted == null || submitted.trim().isEmpty) return;
    if (!mounted) return;

    final token = extractShareToken(submitted);
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('profile.invalid_link'))),
      );
      return;
    }

    await _loadAndShow(token);
  }

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
          SnackBar(content: Text(context.s('profile.network_error'))),
        );
      }
      return;
    }

    if (!mounted) return;
    await _showPlanSheet(plan);
  }

  Future<void> _showPlanSheet(Map<String, dynamic> plan) async {
    final ownerName = (plan['owner_name'] as String?) ?? 'Friend';
    final fromRaw = plan['from'] as String?;
    final toRaw = plan['to'] as String?;

    String rangeLabel = '';
    if (fromRaw != null && toRaw != null) {
      try {
        final from = DateTime.parse(fromRaw).toLocal();
        final to = DateTime.parse(toRaw).toLocal();
        rangeLabel = '${_dayFmt.format(from)} – ${_dayFmt.format(to)}';
      } catch (_) {}
    }

    final rawItems = (plan['items'] as List<dynamic>?) ?? <dynamic>[];

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

    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('profile.events_copied').replaceAll('{n}', '$copied'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Card(
      child: ListTile(
        leading: Icon(Icons.group_outlined, color: ext.textMuted),
        title: Text(context.s('profile.shared_with_me')),
        subtitle: Text(context.s('profile.shared_with_me_subtitle')),
        trailing: Icon(Icons.chevron_right, color: ext.textMuted),
        onTap: _openDialog,
      ),
    );
  }
}

/// Содержимое шита просмотра чужого плана.
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollController) => Column(
        children: [
          // Ручка шита (drag handle через BottomSheetTheme)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ext.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Заголовок
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.s('profile.plan_of').replaceAll('{name}', ownerName),
                        style: textTheme.headlineSmall,
                      ),
                      if (rangeLabel.isNotEmpty)
                        Text(
                          rangeLabel,
                          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                        ),
                    ],
                  ),
                ),
                // Крестик закрытия — видимый аффорданс шита
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: ext.border, height: 1),
          // Список событий
          Expanded(
            child: rawItems.isEmpty
                ? Center(
                    child: Text(
                      context.s('profile.no_events'),
                      style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _itemCount(),
                    itemBuilder: (_, index) => _buildRow(context, index, ext),
                  ),
          ),
          // Единственная CTA на шите — FilledButton (03-components §2)
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: FilledButton(
              onPressed: rawItems.isEmpty ? null : () => onCopy(rawItems),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                context.s('profile.copy_to_my_plan')
                    .replaceAll('{n}', '${rawItems.length}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _itemCount() {
    int count = 0;
    for (final day in sortedDays) {
      count += 1 + (byDay[day]?.length ?? 0);
    }
    return count;
  }

  Widget _buildRow(BuildContext context, int flatIndex, FocusThemeExtension ext) {
    final textTheme = Theme.of(context).textTheme;

    int cursor = 0;
    for (final day in sortedDays) {
      if (flatIndex == cursor) {
        DateTime? dt;
        try {
          dt = DateTime.parse(day);
        } catch (_) {}
        final label = dt != null ? dayFmt.format(dt) : day;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: Text(
            label,
            style: textTheme.labelLarge?.copyWith(color: ext.textMuted),
          ),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: Icon(
            _typeIcon(type),
            size: 18,
            color: ext.textMuted,
          ),
          title: Text(title, style: textTheme.bodyMedium),
          trailing: Text(
            '$timeLabel · $type',
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
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
        return Icons.alarm_outlined;
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Column(
      children: [
        // Крупное число — headlineSmall (display font)
        Text(value, style: textTheme.headlineSmall),
        const SizedBox(height: 2),
        // Подпись ужимается под узкую/крупную типографику, не ломая Row
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
