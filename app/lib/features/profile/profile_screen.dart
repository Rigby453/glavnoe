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
import '../../core/settings/health_profile_provider.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/text_scale_provider.dart';
import '../../core/widgets/voice_text_field.dart';
import '../../core/utils/id.dart';
import 'shared_plan.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../services/notifications/notification_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/custom_theme_provider.dart';
import '../../core/theme/theme_provider.dart';
import '../../services/api/api_client.dart';
import '../../core/widgets/kai_loader.dart';
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

        // Карточка streak
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StreakStat(label: context.s('profile.streak'), value: '${streak?.current ?? 0}'),
                    _StreakStat(label: context.s('profile.streak_best'), value: '${streak?.longest ?? 0}'),
                    Tooltip(
                      message: context.s('streak.freeze'),
                      child: _StreakStat(
                        label: context.s('profile.streak_freezes'),
                        value: '${streak?.freezeCount ?? 0}',
                      ),
                    ),
                  ],
                ),
                if ((streak?.freezeCount ?? 0) > 0) ...[
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
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),
        const _PremiumCard(),
        const SizedBox(height: 8),
        const _ShareWeekCard(),
        const SizedBox(height: 8),
        const _SharedWithMeCard(),

        // Секция «Профиль здоровья»
        const SizedBox(height: 28),
        const _HealthProfileSection(),

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
            return ListTile(
              contentPadding: EdgeInsets.zero,
              // Иконки настроек нейтральные (textMuted) — не accent (03-components §19)
              leading: Icon(Icons.language, color: ext.textMuted),
              title: Text(context.s('profile.language')),
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
        const _ShowKaiSetting(),

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

// ---------------------------------------------------------------------------
// Health profile section
// ---------------------------------------------------------------------------

/// Секция «Профиль здоровья» в профиле.
/// Показывает три поля (или заглушку «не заполнено»), по нажатию «Редактировать»
/// раскрывает inline-редактор с VoiceTextField и кнопкой Save.
class _HealthProfileSection extends ConsumerStatefulWidget {
  const _HealthProfileSection();

  @override
  ConsumerState<_HealthProfileSection> createState() =>
      _HealthProfileSectionState();
}

class _HealthProfileSectionState extends ConsumerState<_HealthProfileSection> {
  bool _editing = false;

  late final TextEditingController _allergiesCtrl;
  late final TextEditingController _healingCtrl;
  late final TextEditingController _deficienciesCtrl;

  @override
  void initState() {
    super.initState();
    final hp = ref.read(healthProfileProvider);
    _allergiesCtrl = TextEditingController(text: hp.allergies);
    _healingCtrl = TextEditingController(text: hp.healing);
    _deficienciesCtrl = TextEditingController(text: hp.deficiencies);
  }

  @override
  void dispose() {
    _allergiesCtrl.dispose();
    _healingCtrl.dispose();
    _deficienciesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(healthProfileProvider.notifier).save(HealthProfile(
          allergies: _allergiesCtrl.text,
          healing: _healingCtrl.text,
          deficiencies: _deficienciesCtrl.text,
        ));
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('health_profile.saved_snack'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final hp = ref.watch(healthProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции + кнопка редактирования
        Row(
          children: [
            Expanded(
              child: Text(
                context.s('health_profile.section_title'),
                style: textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                if (_editing) {
                  // Отмена — сброс к сохранённым значениям
                  final current = ref.read(healthProfileProvider);
                  _allergiesCtrl.text = current.allergies;
                  _healingCtrl.text = current.healing;
                  _deficienciesCtrl.text = current.deficiencies;
                }
                setState(() => _editing = !_editing);
              },
              child: Text(_editing
                  ? context.s('btn.cancel')
                  : context.s('health_profile.edit_btn')),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_editing) ...[
          // Режим редактирования — три VoiceTextField
          _HealthProfileVoiceFields(
            allergiesCtrl: _allergiesCtrl,
            healingCtrl: _healingCtrl,
            deficienciesCtrl: _deficienciesCtrl,
          ),
          const SizedBox(height: 8),
          // Дисклеймер
          Text(
            context.s('health_profile.disclaimer'),
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text(context.s('health_profile.btn_save')),
          ),
        ] else ...[
          // Режим просмотра — краткий дисплей заполненных полей
          if (hp.isEmpty)
            Text(
              context.s('health_profile.empty_hint'),
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            )
          else
            _HealthProfileView(profile: hp),
        ],
      ],
    );
  }
}

/// Виджет просмотра (read-only): показывает непустые поля профиля здоровья.
class _HealthProfileView extends StatelessWidget {
  const _HealthProfileView({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    Widget field(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: textTheme.labelMedium?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: textTheme.bodyMedium),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field(context.s('health_profile.q_allergies'), profile.allergies),
        field(context.s('health_profile.q_healing'), profile.healing),
        field(context.s('health_profile.q_deficiencies'), profile.deficiencies),
      ],
    );
  }
}

/// Три VoiceTextField для редактора профиля здоровья.
/// Вынесен в отдельный StatelessWidget, чтобы не пересоздавать при setState(_editing).
class _HealthProfileVoiceFields extends StatelessWidget {
  const _HealthProfileVoiceFields({
    required this.allergiesCtrl,
    required this.healingCtrl,
    required this.deficienciesCtrl,
  });

  final TextEditingController allergiesCtrl;
  final TextEditingController healingCtrl;
  final TextEditingController deficienciesCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        VoiceTextField(
          controller: allergiesCtrl,
          labelText: context.s('health_profile.q_allergies'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        VoiceTextField(
          controller: healingCtrl,
          labelText: context.s('health_profile.q_healing'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        VoiceTextField(
          controller: deficienciesCtrl,
          labelText: context.s('health_profile.q_deficiencies'),
          maxLines: 3,
        ),
      ],
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
        Expanded(
          child: Text(context.s('profile.default_tone'), style: textTheme.bodyLarge),
        ),
        const SizedBox(width: 12),
        SegmentedButton<AppTone>(
          segments: [
            ButtonSegment(value: AppTone.gentle, label: Text(context.s('settings.gentle'))),
            ButtonSegment(value: AppTone.harsh, label: Text(context.s('settings.harsh'))),
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Column(
      children: [
        // Крупное число — headlineSmall (display font)
        Text(value, style: textTheme.headlineSmall),
        const SizedBox(height: 2),
        Text(label, style: textTheme.bodySmall?.copyWith(color: ext.textMuted)),
      ],
    );
  }
}
