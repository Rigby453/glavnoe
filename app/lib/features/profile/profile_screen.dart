// Экран профиля (Kaname redesign §4.2 — dense hairline rows + Phosphor).
// ProfileScreen — главное меню-хаб.
// ProfileAccountScreen, ProfileBehaviorScreen, ProfileAppearanceScreen —
//   подстраницы, живут здесь и экспортируются стабами.

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import '../../core/branding.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../mascot/kai_mascot.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/posture_reminder_provider.dart';
import '../../core/settings/reminder_default_provider.dart';
import '../../core/settings/rest_default_provider.dart';
import '../../core/settings/sound_provider.dart';
import '../../core/settings/swipe_action_provider.dart';
import '../../core/settings/task_presets_provider.dart';
import '../../core/settings/text_scale_provider.dart';
import '../../core/settings/timezone_provider.dart';
import '../../core/widgets/number_input_dialog.dart';
import '../../core/utils/app_version.dart';
import '../../core/utils/id.dart';
import 'shared_plan.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/mood/mood_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../services/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../core/settings/feature_modes_provider.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/streak/freeze_accrual_service.dart';
import '../auth/auth_controller.dart';

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Стрик пользователя (локально; наполняется через синхронизацию).
final _streakProvider = StreamProvider.autoDispose<StreakTableData?>((ref) {
  return ref.watch(streakDaoProvider).watchStreak();
});

/// Данные текущего пользователя (или null, если офлайн-режим / не вошёл).
final currentUserProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth) return null;
  final api = ref.read(apiClientProvider);
  if (api.token == null) return null;
  try {
    return await api.me();
  } on ApiException {
    return null;
  }
});

// ---------------------------------------------------------------------------
// §4.2 Вспомогательные виджеты: hairline-строки и секции
// ---------------------------------------------------------------------------

/// Тонкий разделитель между строками (0.5dp, border-цвет темы).
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Divider(height: 1, thickness: 0.5, color: ext.border);
  }
}

/// Метка секции (sentence case, muted, labelSmall).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.topPad = 28});

  final String label;
  final double topPad;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(0, topPad, 0, 6),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(color: ext.textMuted),
      ),
    );
  }
}

/// Плотная навигационная строка §4.2: иконка 20dp + заголовок + trailing.
/// Используется для всех nav-строк профиля.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget icon;   // Phosphor icon, размер задаётся снаружи
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: Center(child: icon)),
            const SizedBox(width: 12),
            Expanded(
              child: subtitle == null
                  ? Text(title, style: textTheme.bodyLarge)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: textTheme.bodyLarge),
                        Text(
                          subtitle!,
                          style: textTheme.bodySmall
                              ?.copyWith(color: ext.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  PhosphorIcons.caretRight(),
                  size: 16,
                  color: ext.textFaint,
                ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Главный экран профиля (хаб-меню)
// ---------------------------------------------------------------------------

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runAccrual());
  }

  Future<void> _runAccrual() async {
    if (!mounted) return;
    final isPremium = ref.read(isPremiumProvider).valueOrNull ?? false;
    final svc = ref.read(freezeAccrualServiceProvider);
    final result = await svc.accrueIfNeeded(isPremium: isPremium);

    if (!mounted) return;

    if (result.addedFreezes > 0) {
      final msg = result.addedFreezes == 1
          ? context.s('streak.freeze_accrued').replaceAll('{n}', '1')
          : context.s('streak.freezes_accrued')
              .replaceAll('{n}', '${result.addedFreezes}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    }

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
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final userAsync = ref.watch(currentUserProvider);
    final isAuthenticated =
        ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text(kAppWordmark),
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        children: [
          // ── Шапка: аватар + имя + email ──────────────────────────────────
          const SizedBox(height: 12),
          _UserHeader(userAsync: userAsync),
          const SizedBox(height: 20),
          const _Hairline(),

          // ── Аккаунт ──────────────────────────────────────────────────────
          _NavRow(
            icon: Icon(PhosphorIcons.user(), size: 20, color: ext.textMuted),
            title: context.s('profile.section_account'),
            onTap: () => context.push('/profile/account'),
          ),
          const _Hairline(),
          const SizedBox(height: 8),

          // ── Прогресс (геймификация, перенесена из Today) ─────────────────
          _SectionLabel(context.s('profile.section_progress'), topPad: 0),
          const _ProfileProgressSection(),

          // ── Подписка, шеринг ─────────────────────────────────────────────
          const SizedBox(height: 20),
          const _Hairline(),
          const _SubscriptionRow(),
          const _Hairline(),
          const _ShareWeekRow(),
          const _Hairline(),
          const _SharedWithMeRow(),
          const _Hairline(),

          // ── Данные / настройки ───────────────────────────────────────────
          _SectionLabel(context.s('profile.section_preferences')),
          _NavRow(
            icon: Icon(PhosphorIcons.target(), size: 20, color: ext.textMuted),
            title: context.s('profile.my_data'),
            subtitle: context.s('profile.my_data_subtitle'),
            onTap: () => context.push('/profile/my-data'),
          ),
          const _Hairline(),
          _NavRow(
            icon: Icon(PhosphorIcons.slidersHorizontal(), size: 20, color: ext.textMuted),
            title: context.s('profile.section_defaults'),
            onTap: () => context.push('/profile/behavior'),
          ),
          const _Hairline(),
          _NavRow(
            icon: Icon(PhosphorIcons.palette(), size: 20, color: ext.textMuted),
            title: context.s('profile.section_appearance'),
            onTap: () => context.push('/profile/appearance'),
          ),
          const _Hairline(),
          _NavRow(
            icon: Icon(PhosphorIcons.gearSix(), size: 20, color: ext.textMuted),
            title: context.s('profile.section_behavior'),
            onTap: () => context.push('/profile/behavior'),
          ),
          const _Hairline(),

          // ── Поддержка ────────────────────────────────────────────────────
          _SectionLabel(context.s('profile.section_support')),
          _NavRow(
            icon: Icon(PhosphorIcons.star(), size: 20, color: ext.textMuted),
            title: context.s('profile.rate_app'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.s('profile.rate_coming_soon')),
                ),
              );
            },
          ),
          const _Hairline(),
          _NavRow(
            icon: Icon(PhosphorIcons.chatText(), size: 20, color: ext.textMuted),
            title: context.s('profile.send_feedback'),
            subtitle: context.s('profile.feedback_subtitle'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.s('profile.feedback_email')),
                ),
              );
            },
          ),
          const _Hairline(),
          _NavRow(
            icon: Icon(PhosphorIcons.shieldCheck(), size: 20, color: ext.textMuted),
            title: context.s('profile.terms_privacy'),
            onTap: () => context.push('/terms'),
          ),
          const _Hairline(),

          // ── Реферал ──────────────────────────────────────────────────────
          _SectionLabel(context.s('profile.invite_title')),
          _NavRow(
            icon: Icon(PhosphorIcons.userPlus(), size: 20, color: ext.textMuted),
            title: context.s('profile.invite_title'),
            subtitle: context.s('profile.invite_subtitle'),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.s('profile.referral_coming_soon')),
                ),
              );
            },
          ),
          const _Hairline(),

          // ── Выход / вход ─────────────────────────────────────────────────
          const SizedBox(height: 28),
          isAuthenticated
              ? OutlinedButton.icon(
                  icon: Icon(PhosphorIcons.signOut(), size: 18),
                  label: Text(context.s('btn.sign_out')),
                  onPressed: () async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .logout();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ext.danger,
                    side: BorderSide(color: ext.danger),
                    minimumSize: const Size.fromHeight(48),
                  ),
                )
              : FilledButton.icon(
                  icon: Icon(PhosphorIcons.signIn(), size: 18),
                  label: Text(context.s('btn.sign_in')),
                  onPressed: () async {
                    await ref
                        .read(authControllerProvider.notifier)
                        .logout();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
          const SizedBox(height: 20),
          const Center(child: _AppVersionLabel()),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Шапка профиля (аватар + имя + email)
// ---------------------------------------------------------------------------

class _UserHeader extends StatelessWidget {
  const _UserHeader({required this.userAsync});

  final AsyncValue<Map<String, dynamic>?> userAsync;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return userAsync.when(
      loading: () => Center(
        child: KaiLoader(label: context.s('loading.generic')),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (user) {
        final name = user == null
            ? context.s('profile.offline_mode')
            : ((user['name'] as String?) ?? context.s('profile.you'));
        final email =
            user != null ? ((user['email'] as String?) ?? '') : '';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Аватар в акцентном кружке
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primary.withAlpha(18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.primary.withAlpha(40),
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.user(PhosphorIconsStyle.fill),
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: textTheme.bodySmall
                          ?.copyWith(color: ext.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Секция «Прогресс» (геймификация, перенесена из Today)
// ---------------------------------------------------------------------------

/// Компактная карточка стрика/заморозок/наград — теперь в профиле.
class _ProfileProgressSection extends ConsumerWidget {
  const _ProfileProgressSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final streak = ref.watch(_streakProvider).valueOrNull;
    final freezes = streak?.freezeCount ?? 0;
    final svc = ref.read(freezeAccrualServiceProvider);
    final nextThreshold = svc.nextRewardThreshold(freezes);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: Column(
        children: [
          // Три статы: стрик / рекорд / заморозки
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _ProgressStat(
                    icon: Icon(
                      PhosphorIcons.fire(PhosphorIconsStyle.fill),
                      size: 16,
                      color: ext.ember,
                    ),
                    value: '${streak?.current ?? 0}',
                    label: context.s('profile.streak'),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: ext.border,
                ),
                Expanded(
                  child: _ProgressStat(
                    icon: Icon(
                      PhosphorIcons.trophy(),
                      size: 16,
                      color: ext.textMuted,
                    ),
                    value: '${streak?.longest ?? 0}',
                    label: context.s('profile.streak_best'),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  thickness: 0.5,
                  color: ext.border,
                ),
                Expanded(
                  child: _ProgressStat(
                    icon: Icon(
                      PhosphorIcons.snowflake(),
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    value: '$freezes',
                    label: context.s('profile.streak_freezes'),
                  ),
                ),
              ],
            ),
          ),

          // Подсказка про заморозку (если есть хотя бы одна)
          if (freezes > 0) ...[
            const SizedBox(height: 10),
            Divider(color: ext.border, height: 1, thickness: 0.5),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(PhosphorIcons.info(), size: 14, color: ext.textFaint),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    context.s('profile.freeze_hint'),
                    style: textTheme.bodySmall
                        ?.copyWith(color: ext.textMuted),
                  ),
                ),
              ],
            ),
          ],

          // Прогресс к ближайшей награде
          if (nextThreshold != null) ...[
            const SizedBox(height: 10),
            Divider(color: ext.border, height: 1, thickness: 0.5),
            const SizedBox(height: 10),
            _FreezeRewardProgress(
              currentFreezes: freezes,
              threshold: nextThreshold,
            ),
          ] else if (freezes > 0) ...[
            const SizedBox(height: 10),
            Divider(color: ext.border, height: 1, thickness: 0.5),
            const SizedBox(height: 8),
            Text(
              context.s('streak.freeze_reward_all_claimed'),
              style: textTheme.bodySmall?.copyWith(color: ext.success),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Одна стата прогресса (иконка + значение + подпись).
class _ProgressStat extends StatelessWidget {
  const _ProgressStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final Widget icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
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

// ---------------------------------------------------------------------------
// Прогресс к ближайшей награде за заморозки
// ---------------------------------------------------------------------------

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
    final colorScheme = Theme.of(context).colorScheme;
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
            Icon(PhosphorIcons.snowflake(), size: 14, color: colorScheme.primary),
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
            minHeight: 5,
            backgroundColor: ext.border,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Строки шеринга (hairline версии _ShareWeekCard / _SharedWithMeCard)
// ---------------------------------------------------------------------------

class _SubscriptionRow extends ConsumerWidget {
  const _SubscriptionRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isPremium = ref.watch(isPremiumProvider).valueOrNull ?? false;

    final iconColor = isPremium ? colorScheme.primary : ext.textMuted;
    final title = isPremium
        ? context.s('profile.premium_badge')
        : context.s('profile.free_plan');
    final subtitle = isPremium
        ? context.s('profile.premium_unlocked')
        : context.s('profile.premium_unlock_cta');

    return _NavRow(
      icon: Icon(
        PhosphorIcons.crownSimple(
          isPremium ? PhosphorIconsStyle.fill : PhosphorIconsStyle.regular,
        ),
        size: 20,
        color: iconColor,
      ),
      title: title,
      subtitle: subtitle,
      onTap: isPremium ? null : () => context.push('/paywall'),
      trailing: isPremium
          ? const SizedBox.shrink()
          : Icon(
              PhosphorIcons.caretRight(),
              size: 16,
              color: ext.textFaint,
            ),
    );
  }
}

class _ShareWeekRow extends ConsumerStatefulWidget {
  const _ShareWeekRow();

  @override
  ConsumerState<_ShareWeekRow> createState() => _ShareWeekRowState();
}

class _ShareWeekRowState extends ConsumerState<_ShareWeekRow> {
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
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return _NavRow(
      icon: _working
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: colorScheme.primary,
              ),
            )
          : Icon(PhosphorIcons.shareNetwork(), size: 20, color: ext.textMuted),
      title: context.s('profile.share_week'),
      subtitle: context.s('profile.share_week_subtitle'),
      onTap: _working ? null : _share,
    );
  }
}

class _SharedWithMeRow extends ConsumerStatefulWidget {
  const _SharedWithMeRow();

  @override
  ConsumerState<_SharedWithMeRow> createState() => _SharedWithMeRowState();
}

class _SharedWithMeRowState extends ConsumerState<_SharedWithMeRow> {
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
    return _NavRow(
      icon: Icon(PhosphorIcons.users(), size: 20, color: ext.textMuted),
      title: context.s('profile.shared_with_me'),
      subtitle: context.s('profile.shared_with_me_subtitle'),
      onTap: _openDialog,
    );
  }
}

// ---------------------------------------------------------------------------
// Шит просмотра чужого плана
// ---------------------------------------------------------------------------

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
                        context
                            .s('profile.plan_of')
                            .replaceAll('{name}', ownerName),
                        style: textTheme.headlineSmall,
                      ),
                      if (rangeLabel.isNotEmpty)
                        Text(
                          rangeLabel,
                          style: textTheme.bodySmall
                              ?.copyWith(color: ext.textMuted),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(PhosphorIcons.x()),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          Expanded(
            child: rawItems.isEmpty
                ? Center(
                    child: Text(
                      context.s('profile.no_events'),
                      style: textTheme.bodyMedium
                          ?.copyWith(color: ext.textMuted),
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _itemCount(),
                    itemBuilder: (_, index) => _buildRow(context, index, ext),
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: FilledButton(
              onPressed:
                  rawItems.isEmpty ? null : () => onCopy(rawItems),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(
                context
                    .s('profile.copy_to_my_plan')
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

  PhosphorIconData _typeIcon(String type) {
    switch (type) {
      case 'event':
        return PhosphorIcons.calendar();
      case 'exam':
        return PhosphorIcons.graduationCap();
      case 'deadline':
        return PhosphorIcons.alarm();
      default:
        return PhosphorIcons.checkCircle();
    }
  }
}

// ---------------------------------------------------------------------------
// Виджеты настроек (Behavior screen)
// ---------------------------------------------------------------------------

/// Переключатель ежедневных напоминаний.
class _NotificationsSetting extends ConsumerWidget {
  const _NotificationsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationsEnabledProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(PhosphorIcons.bell(), size: 20, color: ext.textMuted),
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

/// Тумблер отображения маскота Kai.
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

/// Тумблер звука завершения задачи.
class _CompletionSoundSetting extends ConsumerWidget {
  const _CompletionSoundSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(completionSoundEnabledProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(PhosphorIcons.speakerHigh(), size: 20, color: ext.textMuted),
      title: Text(context.s('profile.completion_sound')),
      subtitle: Text(context.s('profile.completion_sound_subtitle')),
      value: enabled,
      onChanged: (want) =>
          ref.read(completionSoundEnabledProvider.notifier).set(want),
    );
  }
}

/// Настройка действий свайпа.
class _SwipeActionsSetting extends ConsumerWidget {
  const _SwipeActionsSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final config = ref.watch(swipeActionsProvider);

    Widget row({
      required PhosphorIconData leadingIconData,
      required String title,
      required SwipeAction current,
      required ValueChanged<SwipeAction> onChanged,
    }) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(leadingIconData, size: 20, color: ext.textMuted),
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
          leadingIconData: PhosphorIcons.arrowRight(),
          title: context.s('profile.swipe_right'),
          current: config.right,
          onChanged: (a) =>
              ref.read(swipeActionsProvider.notifier).setRight(a),
        ),
        row(
          leadingIconData: PhosphorIcons.arrowLeft(),
          title: context.s('profile.swipe_left'),
          current: config.left,
          onChanged: (a) =>
              ref.read(swipeActionsProvider.notifier).setLeft(a),
        ),
      ],
    );
  }
}

/// Настройка часового пояса.
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
      leading: Icon(PhosphorIcons.clock(), size: 20, color: ext.textMuted),
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
          Icon(PhosphorIcons.caretRight(), size: 16, color: ext.textFaint),
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
    final colorScheme = Theme.of(context).colorScheme;

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
                        icon: Icon(PhosphorIcons.x()),
                        tooltip: ctx.s('btn.close'),
                        onPressed: () => Navigator.of(ctx).maybePop(),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  title: Text(ctx.s('profile.timezone_auto')),
                  trailing: current.isAuto
                      ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill),
                          color: colorScheme.primary)
                      : null,
                  onTap: () {
                    notifier.setAuto();
                    Navigator.of(ctx).pop();
                  },
                ),
                const Divider(height: 1),
                ...kSelectableTimezones.map(
                  (zone) => ListTile(
                    title: Text(zone),
                    trailing: (!current.isAuto && current.iana == zone)
                        ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill),
                            color: colorScheme.primary)
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

/// Настройка высокого контраста (доступность).
class _HighContrastSetting extends ConsumerWidget {
  const _HighContrastSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(highContrastProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(PhosphorIcons.eye(), size: 20, color: ext.textMuted),
      title: Text(context.s('profile.high_contrast')),
      subtitle: Text(context.s('profile.high_contrast_subtitle')),
      value: enabled,
      onChanged: (v) =>
          ref.read(highContrastProvider.notifier).setHighContrast(v),
    );
  }
}

/// Выбор языка (Consumer — обращается к localeNotifierProvider).
class _LanguageSetting extends ConsumerWidget {
  const _LanguageSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final locale = ref.watch(localeNotifierProvider);
    final currentTag = localeTag(locale);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(PhosphorIcons.translate(), size: 20, color: ext.textMuted),
      title: Text(context.s('profile.language')),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 140),
        child: DropdownButton<String>(
          value: currentTag,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: ext.surfaceElevated,
          items: localeEntries
              .map((e) => DropdownMenuItem(
                    value: localeTag(e.locale),
                    child: Text(e.displayName),
                  ))
              .toList(),
          onChanged: (tag) {
            if (tag != null) {
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
  }
}

// ---------------------------------------------------------------------------
// Task defaults section
// ---------------------------------------------------------------------------

class _TaskDefaultsSection extends ConsumerWidget {
  const _TaskDefaultsSection();

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

        _PresetEditor(
          label: context.s('profile.duration_presets_label'),
          presets: ref.watch(durationPresetsProvider),
          reminder: false,
          onChanged: (list) =>
              ref.read(durationPresetsProvider.notifier).setPresets(list),
        ),

        const SizedBox(height: 20),

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
// Workout defaults section
// ---------------------------------------------------------------------------

class _WorkoutDefaultsSection extends ConsumerWidget {
  const _WorkoutDefaultsSection();

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
        minValue: kRestDefaultMinSeconds,
        maxValue: kRestDefaultMaxSeconds,
        maxValueHint: ctx
            .s('common.max_value_hint')
            .replaceAll('{n}', (kRestDefaultMaxSeconds ~/ 60).toString()),
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
            style: textTheme.titleMedium
                ?.copyWith(color: colorScheme.primary),
          ),
          onTap: () => _editRest(context, ref),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Advanced features section
// ---------------------------------------------------------------------------

class _AdvancedFeaturesSection extends ConsumerWidget {
  const _AdvancedFeaturesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final nutritionOn = ref.watch(nutritionModeProvider);
    final workoutOn = ref.watch(workoutModeProvider);
    final meditationOn = ref.watch(meditationLibraryModeProvider);
    final breathingOn = ref.watch(breathingEditorModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.s('profile.section_advanced'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          context.s('profile.advanced_section_note'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 8),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.s('profile.advanced_nutrition')),
          subtitle: Text(context.s('profile.advanced_nutrition_subtitle')),
          value: nutritionOn,
          onChanged: (v) =>
              ref.read(nutritionModeProvider.notifier).set(v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.s('profile.advanced_workouts')),
          subtitle: Text(context.s('profile.advanced_workouts_subtitle')),
          value: workoutOn,
          onChanged: (v) =>
              ref.read(workoutModeProvider.notifier).set(v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.s('profile.advanced_meditation')),
          subtitle: Text(context.s('profile.advanced_meditation_subtitle')),
          value: meditationOn,
          onChanged: (v) =>
              ref.read(meditationLibraryModeProvider.notifier).set(v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.s('profile.advanced_breathing')),
          subtitle: Text(context.s('profile.advanced_breathing_subtitle')),
          value: breathingOn,
          onChanged: (v) =>
              ref.read(breathingEditorModeProvider.notifier).set(v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Preset editor
// ---------------------------------------------------------------------------

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
    final entered = await showDialog<int>(
      context: context,
      builder: (ctx) => NumberInputDialog(
        backgroundColor: ext.surfaceElevated,
        title: ctx.s('profile.presets_add_minutes_title'),
        labelText: ctx.s('profile.presets_minutes_hint'),
        confirmLabel: ctx.s('profile.presets_add'),
        bordered: false,
        minValue: 0,
      ),
    );
    if (entered == null) return;
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
              avatar: Icon(PhosphorIcons.plus(), size: 16, color: ext.textMuted),
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
// Kai settings section
// ---------------------------------------------------------------------------

class _KaiSettingsSection extends ConsumerWidget {
  const _KaiSettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final tone = ref.watch(toneProvider);
    final mood = ref.watch(effectiveMoodProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.s('profile.section_kai'), style: textTheme.titleMedium),
        const SizedBox(height: 8),
        const _ShowKaiSetting(),
        const SizedBox(height: 4),
        _ToneRow(tone: tone),
        const SizedBox(height: 12),
        _TonePreview(tone: tone, mood: mood),
      ],
    );
  }
}

class _ToneRow extends ConsumerWidget {
  const _ToneRow({required this.tone});

  final AppTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.s('profile.kai_tone'), style: textTheme.bodyLarge),
              const SizedBox(height: 2),
              Text(
                context.s('profile.kai_tone_subtitle'),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        SegmentedButton<AppTone>(
          segments: [
            ButtonSegment(
              value: AppTone.gentle,
              label: Text(
                context.s('settings.gentle'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ButtonSegment(
              value: AppTone.harsh,
              label: Text(
                context.s('settings.harsh'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
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

class _TonePreview extends StatelessWidget {
  const _TonePreview({required this.tone, required this.mood});

  final AppTone tone;
  final EffectiveMood mood;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final v = ToneVisuals.of(context, tone);

    final previewEmotion = switch (mood.level) {
      MoodLevel.angry => KaiEmotion.anxious,
      MoodLevel.stern => KaiEmotion.anxious,
      MoodLevel.neutral => KaiEmotion.neutral,
      MoodLevel.calm => KaiEmotion.success,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
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
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    KaiCopy.preview(context, tone),
                    key: ValueKey(tone),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
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

// ---------------------------------------------------------------------------
// Размер шрифта (доступность)
// ---------------------------------------------------------------------------

class _TextSizeSetting extends ConsumerWidget {
  const _TextSizeSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(textScaleProvider);
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(PhosphorIcons.textAa(), size: 20, color: ext.textMuted),
            const SizedBox(width: 12),
            Text(context.s('profile.text_size'), style: textTheme.bodyLarge),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: TextSizePref.values.map((p) {
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
// Тумблер напоминаний об осанке
// ---------------------------------------------------------------------------

class _PostureReminderSetting extends ConsumerWidget {
  const _PostureReminderSetting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(postureRemindersProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(
        PhosphorIcons.personSimpleWalk(),
        size: 20,
        color: ext.textMuted,
      ),
      title: Text(context.s('posture.reminders_title')),
      subtitle: Text(context.s('posture.reminders_subtitle')),
      value: enabled,
      onChanged: (want) async {
        final result =
            await ref.read(postureRemindersProvider.notifier).setEnabled(want);
        if (want && !result && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.s('posture.permission_required')),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Выбор темы
// ---------------------------------------------------------------------------

class _ThemePicker extends ConsumerWidget {
  const _ThemePicker();

  static const _available = [
    (AppThemeKey.day, 'profile.theme_day'),
    (AppThemeKey.night, 'profile.theme_night'),
    (AppThemeKey.black, 'profile.theme_black'),
    (AppThemeKey.calm, 'profile.theme_calm'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeNotifierProvider);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _available.map((entry) {
        final (key, labelKey) = entry;
        return ChoiceChip(
          label: Text(context.s(labelKey)),
          selected: current == key,
          onSelected: (_) =>
              ref.read(themeNotifierProvider.notifier).setTheme(key),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Выбор акцента (Phase 4 — 6 AccentKey свотчей)
// ---------------------------------------------------------------------------

/// Пикер акцентного цвета: 6 цветных кружков, по тапу устанавливает акцент.
class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  // Канонические цвета акцентов (light/day из design-tokens.json §accents).
  static const Map<AccentKey, Color> _colors = {
    AccentKey.indigo:  Color(0xFF4B57C9),
    AccentKey.emerald: Color(0xFF1D9E75),
    AccentKey.violet:  Color(0xFF7A4FC9),
    AccentKey.ochre:   Color(0xFFB5772A),
    AccentKey.rose:    Color(0xFFC24E78),
    AccentKey.slate:   Color(0xFF3F6E9E),
  };

  static String _labelKey(AccentKey key) => switch (key) {
        AccentKey.indigo  => 'accent.indigo',
        AccentKey.emerald => 'accent.emerald',
        AccentKey.violet  => 'accent.violet',
        AccentKey.ochre   => 'accent.ochre',
        AccentKey.rose    => 'accent.rose',
        AccentKey.slate   => 'accent.slate',
      };

  // Выбирает чёрный или белый контрастный цвет для галочки
  Color _contrastColor(Color bg) {
    double lin(double v) =>
        v <= 0.04045
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final l = 0.2126 * lin(bg.r) + 0.7152 * lin(bg.g) + 0.0722 * lin(bg.b);
    return l > 0.35 ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(accentNotifierProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Длительность анимации: fast=180ms, учитываем MediaQuery.disableAnimations.
    final dur = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AccentKey.values.map((key) {
        final color = _colors[key]!;
        final selected = current == key;
        final label = context.s(_labelKey(key));

        return Tooltip(
          message: label,
          child: GestureDetector(
            onTap: () =>
                ref.read(accentNotifierProvider.notifier).setAccent(key),
            child: AnimatedContainer(
              duration: dur,
              curve: Curves.easeOut,
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: selected
                    ? Border.all(color: onSurface, width: 2.5)
                    : Border.all(color: Colors.transparent, width: 2.5),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? Center(
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: _contrastColor(color),
                      ),
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Версия приложения
// ---------------------------------------------------------------------------

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
        final tagPart =
            kAppBuildTag.isNotEmpty ? ' · $kAppBuildTag' : '';
        final debugPart = kDebugMode ? ' · debug' : '';
        final versionData =
            'v${info.version} (build ${info.buildNumber}$tagPart)$debugPart';
        return Text(
          '${context.s('profile.version_label')} $versionData',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
        );
      },
    );
  }
}

// ===========================================================================
// Подстраницы профиля
// ===========================================================================

// ---------------------------------------------------------------------------
// Подстраница «Внешний вид»
// Секции: тема (4 варианта). Язык и размер текста перенесены в «Поведение».
// ---------------------------------------------------------------------------

class ProfileAppearanceScreen extends ConsumerWidget {
  const ProfileAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('profile.section_appearance')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          Text(
            context.s('profile.section_appearance'),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.s('profile.advanced_section_note'),
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 16),
          // Выбор темы (4 варианта: Day / Night / Black / Calm)
          const _ThemePicker(),
          const SizedBox(height: 28),
          // Выбор акцентного цвета (6 AccentKey) — Phase 4
          Text(
            context.s('profile.accent'),
            style: textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          const _AccentPicker(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Подстраница «Поведение» / «Настройки»
// Секции: Kai, Язык, Уведомления, Звук, Свайпы, Часовой пояс,
//         Доступность (высокий контраст + размер текста),
//         Умолчания задач, Умолчания тренировок, Расширенные функции.
// FAB-позиция УБРАНА (позиция зафиксирована).
// ---------------------------------------------------------------------------

class ProfileBehaviorScreen extends StatelessWidget {
  const ProfileBehaviorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('profile.section_behavior'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          // ── Kai ──────────────────────────────────────────────────────────
          const _KaiSettingsSection(),

          // ── Язык ─────────────────────────────────────────────────────────
          const SizedBox(height: 24),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const _LanguageSetting(),

          // ── Уведомления / Звук / Осанка ───────────────────────────────────
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const _NotificationsSetting(),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const _CompletionSoundSetting(),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const _PostureReminderSetting(),

          // ── Свайп-действия ────────────────────────────────────────────────
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const _SwipeActionsSetting(),

          // ── Часовой пояс ──────────────────────────────────────────────────
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const _TimezoneSetting(),

          // ── Доступность ───────────────────────────────────────────────────
          const SizedBox(height: 28),
          Text(
            context.s('profile.section_accessibility'),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const _HighContrastSetting(),
          const SizedBox(height: 12),
          const _TextSizeSetting(),

          // ── Умолчания задач ───────────────────────────────────────────────
          const SizedBox(height: 28),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const SizedBox(height: 20),
          const _TaskDefaultsSection(),

          // ── Умолчания тренировок ──────────────────────────────────────────
          const SizedBox(height: 28),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const SizedBox(height: 20),
          const _WorkoutDefaultsSection(),

          // ── Расширенные функции ───────────────────────────────────────────
          const SizedBox(height: 28),
          Divider(color: ext.border, height: 1, thickness: 0.5),
          const SizedBox(height: 20),
          const _AdvancedFeaturesSection(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Подстраница «Аккаунт»
// Показывает имя/email и кнопку выхода (бизнес-логика входа/выхода здесь).
// Геймификация, подписка и шеринг перенесены в главный ProfileScreen.
// ---------------------------------------------------------------------------

class ProfileAccountScreen extends ConsumerWidget {
  const ProfileAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final userAsync = ref.watch(currentUserProvider);
    final isAuthenticated =
        ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('profile.section_account'))),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                children: [
                  // Имя / email
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
                            Text(
                              context.s('profile.offline_mode'),
                              style: textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              context.s('profile.offline_subtitle'),
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: ext.textMuted),
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (user['name'] as String?) ??
                                context.s('profile.you'),
                            style: textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (user['email'] as String?) ?? '',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: ext.textMuted),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                  Divider(color: ext.border, height: 1, thickness: 0.5),

                  // Навигация по аккаунту (placeholder — функционал не реализован)
                  _NavRow(
                    icon: Icon(PhosphorIcons.envelope(), size: 20, color: ext.textMuted),
                    title: context.s('profile.send_feedback'),
                    subtitle: context.s('profile.feedback_subtitle'),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.s('profile.feedback_email')),
                        ),
                      );
                    },
                  ),
                  Divider(color: ext.border, height: 1, thickness: 0.5),
                  _NavRow(
                    icon: Icon(PhosphorIcons.shieldCheck(), size: 20, color: ext.textMuted),
                    title: context.s('profile.terms_privacy'),
                    onTap: () => context.push('/terms'),
                  ),
                  Divider(color: ext.border, height: 1, thickness: 0.5),
                ],
              ),
            ),

            const SizedBox(height: 12),
            // Выход / вход
            isAuthenticated
                ? OutlinedButton.icon(
                    icon: Icon(PhosphorIcons.signOut(), size: 18),
                    label: Text(context.s('btn.sign_out')),
                    onPressed: () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .logout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ext.danger,
                      side: BorderSide(color: ext.danger),
                      minimumSize: const Size.fromHeight(48),
                    ),
                  )
                : FilledButton.icon(
                    icon: Icon(PhosphorIcons.signIn(), size: 18),
                    label: Text(context.s('btn.sign_in')),
                    onPressed: () async {
                      await ref
                          .read(authControllerProvider.notifier)
                          .logout();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
            const SizedBox(height: 12),
            const Center(child: _AppVersionLabel()),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
