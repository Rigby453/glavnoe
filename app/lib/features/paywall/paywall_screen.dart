// Экран подписки / пейволл — соответствие Apple 3.1.2/5.6 + EU Digital Fairness Act 2026.
//
// Kaname redesign (2026-06-28):
//   - Phosphor иконки вместо Material
//   - kAppWordmark вместо хардкода "Kaizen"
//   - Адаптивный layout: широкий (web) / узкий (mobile), порог 700 dp
//   - Нет упоминания рекламы (ADR-052: freemium, no ads anywhere)
//
// Compliance (не изменено):
//   ✓ Видимая кнопка ✕ → бесплатная версия (/today)
//   ✓ Два плана (Monthly $10 / Yearly $79), цены чёткие
//   ✓ Список premium-функций с галочками
//   ✓ Один primary CTA «Start free»
//   ✓ Disclosure с датой окончания пробного периода
//   ✓ Ссылки Terms · Privacy · Restore
//   ✓ Без «guilt»-пейвола: закрытие ✕ → /today
//   ✓ Kai в выражении success (не навязчивый)

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/branding.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../features/mascot/kai_speech_bubble.dart';
import '../../services/api/api_client.dart';
import '../../services/purchases/purchase_service.dart';
import '../../services/streak/freeze_accrual_service.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart' show currentUserProvider;

// ---------------------------------------------------------------------------
// Константы ценообразования — меняются в одном месте.
// ---------------------------------------------------------------------------

const int _kTrialDays = 7;
const String _kPriceMonthly = r'$10';
const String _kPriceYearly = r'$79';
const String _kPriceYearlyPerMonth = r'$6.58';
const int _kYearlySavePercent = 34;

// ---------------------------------------------------------------------------
// Enum вариантов плана
// ---------------------------------------------------------------------------

enum _Plan { monthly, yearly }

// ---------------------------------------------------------------------------
// Список premium-функций (Phosphor иконки; нет рекламы — ADR-052).
// Не const — PhosphorIcons.*() не являются const-конструкторами.
// ---------------------------------------------------------------------------

final List<({IconData icon, String titleKey, String subtitleKey})> _benefits = [
  (
    icon: PhosphorIcons.sparkle(),
    titleKey: 'paywall.benefit_reschedule_title',
    subtitleKey: 'paywall.benefit_reschedule_subtitle',
  ),
  (
    icon: PhosphorIcons.cookingPot(),
    titleKey: 'paywall.benefit_menu_title',
    subtitleKey: 'paywall.benefit_menu_subtitle',
  ),
  (
    icon: PhosphorIcons.camera(),
    titleKey: 'paywall.benefit_photo_title',
    subtitleKey: 'paywall.benefit_photo_subtitle',
  ),
  (
    icon: PhosphorIcons.microphone(),
    titleKey: 'paywall.benefit_voice_title',
    subtitleKey: 'paywall.benefit_voice_subtitle',
  ),
  (
    icon: PhosphorIcons.chartLineUp(),
    titleKey: 'paywall.benefit_wrapped_title',
    subtitleKey: 'paywall.benefit_wrapped_subtitle',
  ),
];

// ---------------------------------------------------------------------------
// Утилита для уведомления об апгрейде из любого экрана
// ---------------------------------------------------------------------------

void showPremiumUpsell(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.s('paywall.premium_feature_upsell').replaceFirst('{feature}', feature),
      ),
      action: SnackBarAction(
        label: context.s('paywall.upgrade'),
        onPressed: () => context.push('/paywall'),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Основной экран
// ---------------------------------------------------------------------------

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _working = false;

  // Годовой план — по умолчанию (лучший value для пользователя)
  _Plan _selectedPlan = _Plan.yearly;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _trialEndDate(BuildContext context) {
    final end = DateTime.now().add(const Duration(days: _kTrialDays));
    try {
      final lang = Localizations.localeOf(context).languageCode;
      return DateFormat.yMMMd(lang).format(end);
    } catch (_) {
      return '${end.day}.${end.month}.${end.year}';
    }
  }

  String get _selectedPriceLabel => _selectedPlan == _Plan.monthly
      ? '$_kPriceMonthly / mo'
      : '$_kPriceYearly / yr';

  // ---------------------------------------------------------------------------
  // Действия (бизнес-логика не изменена)
  // ---------------------------------------------------------------------------

  Future<void> _subscribe() async {
    setState(() => _working = true);
    try {
      final outcome = await ref.read(purchaseServiceProvider).buyPremium();
      if (!mounted) return;

      switch (outcome) {
        case PurchaseOutcome.success:
          await ref.read(freezeAccrualServiceProvider).grantPurchaseBonus();
          ref.invalidate(isPremiumProvider);
          ref.invalidate(currentUserProvider);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.welcome_premium'))),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('streak.freeze_purchase_bonus'))),
          );
          context.pop();

        case PurchaseOutcome.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.coming_soon'))),
          );

        case PurchaseOutcome.error:
          final isAuthed =
              ref.read(authControllerProvider.notifier).isAuthenticated;
          final message = isAuthed
              ? context.s('paywall.error_generic')
              : context.s('paywall.sign_in_to_subscribe');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

        case PurchaseOutcome.cancelled:
          break;
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _devActivate() async {
    setState(() => _working = true);
    try {
      await ref.read(apiClientProvider).devUpgrade(tier: 'premium');
      ref.invalidate(isPremiumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Premium activated!')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _devDeactivate() async {
    setState(() => _working = true);
    try {
      await ref.read(apiClientProvider).devUpgrade(tier: 'free');
      ref.invalidate(isPremiumProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downgraded to Free')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restorePurchases() async {
    setState(() => _working = true);
    try {
      final outcome =
          await ref.read(purchaseServiceProvider).restorePurchases();
      if (!mounted) return;

      switch (outcome) {
        case PurchaseOutcome.success:
          ref.invalidate(isPremiumProvider);
          ref.invalidate(currentUserProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.restored'))),
          );
          context.pop();

        case PurchaseOutcome.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.nothing_to_restore'))),
          );

        case PurchaseOutcome.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.restore_error'))),
          );

        case PurchaseOutcome.cancelled:
          break;
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Вспомогательные методы построения UI
  // ---------------------------------------------------------------------------

  /// Строки-чекмарки для каждого premium-бенефита.
  List<Widget> _buildBenefitRows(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return _benefits.map((b) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Акцентная галочка — Phosphor fill
          Icon(
            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            color: colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.s(b.titleKey),
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  context.s(b.subtitleKey),
                  style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    )).toList();
  }

  /// Секция планов + CTA + disclosure + ссылки + dev tools.
  List<Widget> _buildPlanSection(BuildContext context, bool isAuthed) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return [
      _PlanCard(
        label: context.s('paywall.plan_monthly'),
        price: _kPriceMonthly,
        priceSuffix: context.s('paywall.per_month'),
        badge: null,
        isSelected: _selectedPlan == _Plan.monthly,
        onTap: _working ? null : () => setState(() => _selectedPlan = _Plan.monthly),
      ),

      const SizedBox(height: 10),

      _PlanCard(
        label: context.s('paywall.plan_yearly'),
        price: _kPriceYearly,
        priceSuffix: context.s('paywall.per_year'),
        badge: context.s('paywall.save_badge')
            .replaceFirst('{pct}', '$_kYearlySavePercent'),
        subNote: context.s('paywall.yearly_per_month')
            .replaceFirst('{price}', _kPriceYearlyPerMonth),
        isSelected: _selectedPlan == _Plan.yearly,
        onTap: _working ? null : () => setState(() => _selectedPlan = _Plan.yearly),
      ),

      const SizedBox(height: 20),

      // Hint для незалогиненных
      if (!isAuthed) ...[
        Text(
          context.s('paywall.sign_in_hint'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
      ],

      // Единственная primary CTA
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _working ? null : _subscribe,
          child: Text(context.s('paywall.cta_start_free')),
        ),
      ),

      const SizedBox(height: 12),

      // Disclosure (читаемый, textMuted — не faint)
      Text(
        context
            .s('paywall.disclosure')
            .replaceFirst('{n}', '$_kTrialDays')
            .replaceFirst('{price}', _selectedPriceLabel)
            .replaceFirst('{date}', _trialEndDate(context)),
        style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        textAlign: TextAlign.center,
      ),

      const SizedBox(height: 20),

      _LinksRow(onRestore: _working ? null : _restorePurchases),

      // Dev tools (только debug сборка)
      if (kDebugMode) ...[
        const SizedBox(height: 24),
        Divider(color: ext.border),
        const SizedBox(height: 8),
        Text(
          'Dev tools',
          style: textTheme.labelSmall?.copyWith(color: ext.textFaint),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _working ? null : _devActivate,
          child: const Text('Activate Premium (dev only)'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _working ? null : _devDeactivate,
          child: const Text('Downgrade to Free (dev only)'),
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Адаптивные layout-методы
  // ---------------------------------------------------------------------------

  /// Широкий layout (web / landscape ≥ 700 dp):
  /// левая колонка — брендинг + Kai + список функций;
  /// правая колонка — планы + CTA + ссылки.
  Widget _buildWide(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isAuthed = ref.read(authControllerProvider.notifier).isAuthenticated;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 72, 24, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Левая колонка: брендинг + Kai + бенефиты ----
              Expanded(
                flex: 55,
                child: Padding(
                  padding: const EdgeInsets.only(right: 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Wordmark — небольшой «логотип» вверху колонки
                      Text(
                        kAppWordmark,
                        style: textTheme.titleMedium?.copyWith(
                          color: ext.textFaint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Kai + пузырь
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Flexible(
                            child: KaiSpeechBubble(
                              message: context.s('paywall.kai_bubble'),
                              tail: KaiBubbleTail.rightCenter,
                              maxWidth: 220,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const KaiMascot(
                            size: 64,
                            emotion: KaiEmotion.success,
                            isHarsh: false,
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Заголовок + подзаголовок
                      Text(
                        context.s('paywall.headline'),
                        style: textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.s('paywall.subheadline'),
                        style: textTheme.bodyLarge
                            ?.copyWith(color: ext.textMuted),
                      ),

                      const SizedBox(height: 28),

                      // 5 premium-функций
                      ..._buildBenefitRows(context),

                      const SizedBox(height: 12),

                      // Пометка о бесплатном тире
                      Text(
                        context.s('paywall.free_includes'),
                        style: textTheme.bodySmall
                            ?.copyWith(color: ext.textFaint),
                      ),
                    ],
                  ),
                ),
              ),

              // ---- Правая колонка: планы + CTA + ссылки ----
              SizedBox(
                width: 340,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildPlanSection(context, isAuthed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Узкий layout (телефон / portrait):
  /// все элементы в одну колонку.
  Widget _buildNarrow(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isAuthed = ref.read(authControllerProvider.notifier).isAuthenticated;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
      children: [
        // Wordmark — мелкий, служит «логотипом» наверху
        Text(
          kAppWordmark,
          style: textTheme.labelLarge?.copyWith(color: ext.textFaint),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Kai + пузырь
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: KaiSpeechBubble(
                message: context.s('paywall.kai_bubble'),
                tail: KaiBubbleTail.rightCenter,
                maxWidth: 200,
              ),
            ),
            const SizedBox(width: 8),
            const KaiMascot(
              size: 64,
              emotion: KaiEmotion.success,
              isHarsh: false,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Заголовок + подзаголовок
        Text(
          context.s('paywall.headline'),
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          context.s('paywall.subheadline'),
          style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
        ),

        const SizedBox(height: 24),

        // 5 premium-функций
        ..._buildBenefitRows(context),

        // Пометка о бесплатном тире
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            context.s('paywall.free_includes'),
            style: textTheme.bodySmall?.copyWith(color: ext.textFaint),
          ),
        ),

        // Секция планов + CTA
        ..._buildPlanSection(context, isAuthed),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Без AppBar — закрытие через кнопку ✕ (compliance Apple 3.1.2).
      body: SafeArea(
        child: Stack(
          children: [
            // ---- Основной контент ----
            if (_working)
              Center(
                child: KaiLoader(label: context.s('loading.processing')),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  // Адаптивный порог: ≥ 700 dp → широкий (web / landscape)
                  return constraints.maxWidth >= 700
                      ? _buildWide(context)
                      : _buildNarrow(context);
                },
              ),

            // ---- Кнопка ✕ — compliance: заметная, всегда поверх контента ----
            Positioned(
              top: 8,
              right: 8,
              child: _CloseButton(working: _working),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные виджеты
// ---------------------------------------------------------------------------

/// Кнопка закрытия (Phosphor x). Ведёт на /today без «guilt»-пейвола.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.working});
  final bool working;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final iconColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: working
            ? null
            : () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/today');
                }
              },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            PhosphorIcons.x(),
            size: 22,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

/// Карточка одного плана (Monthly / Yearly).
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.price,
    required this.priceSuffix,
    required this.isSelected,
    required this.onTap,
    this.badge,
    this.subNote,
  });

  final String label;
  final String price;
  final String priceSuffix;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Текст бейджа «save 34%». null → без бейджа.
  final String? badge;

  /// Подстрочная заметка «$6.58 / mo». null → без заметки.
  final String? subNote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final borderColor = isSelected ? colorScheme.primary : ext.border;
    final bgColor = isSelected ? ext.accentMuted : colorScheme.surface;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 0.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Радио-индикатор: filled accent when selected
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : ext.border,
                  width: isSelected ? 2 : 1.5,
                ),
                color:
                    isSelected ? colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Icon(
                        PhosphorIcons.check(),
                        size: 13,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),

            // Название плана + подзаголовок
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.titleSmall),
                  if (subNote != null)
                    Text(
                      subNote!,
                      style: textTheme.bodySmall
                          ?.copyWith(color: ext.textMuted),
                    ),
                ],
              ),
            ),

            // Цена справа — Flexible для узких экранов
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    textAlign: TextAlign.end,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: price,
                          style: textTheme.titleMedium?.copyWith(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: priceSuffix,
                          style: textTheme.bodySmall?.copyWith(
                            color: ext.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Бейдж «save N%» рядом с ценой
                  if (badge != null)
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primary
                            : ext.border,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge!,
                        style: textTheme.labelSmall?.copyWith(
                          color: isSelected
                              ? colorScheme.onPrimary
                              : ext.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        softWrap: false,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Нижний ряд ссылок: Terms · Privacy · Restore.
/// Wrap вместо Row — не переполняется на узких экранах / крупном textScaler.
class _LinksRow extends StatelessWidget {
  const _LinksRow({required this.onRestore});
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ext.textMuted,
        );

    final btnStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.push('/terms'),
          style: btnStyle,
          child: Text(context.s('paywall.link_terms'), style: style),
        ),
        Text(' · ', style: style),
        TextButton(
          onPressed: () => context.push('/terms'),
          style: btnStyle,
          child: Text(context.s('paywall.link_privacy'), style: style),
        ),
        Text(' · ', style: style),
        TextButton(
          onPressed: onRestore,
          style: btnStyle,
          child: Text(context.s('paywall.restore'), style: style),
        ),
      ],
    );
  }
}
