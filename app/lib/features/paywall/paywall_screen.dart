// Экран подписки / пейволл — соответствие Apple 3.1.2/5.6 + EU Digital Fairness Act 2026.
//
// Обязательные элементы compliance:
//   ✓ Видимая кнопка ✕ (закрыть) → бесплатная версия (/today)
//   ✓ Два плана (Monthly $10 / Yearly $79), оба видны, цены чёткие
//   ✓ Список premium-функций с галочками
//   ✓ CTA «Start free» (один primary)
//   ✓ Disclosure: «N дней бесплатно, затем {цена}. Спишем {дата}. Отмена в настройках.»
//   ✓ Ссылки Terms · Privacy · Restore
//   ✓ Нет второго «guilt»-пейвола — закрытие ✕ ведёт сразу на /today
//   ✓ Kai с нейтральным/success-выражением (не навязчивый)
//
// Реальные платежи (RevenueCat) — Phase 1; сейчас buyPremium() через StubPurchaseService:
//   debug → вызывает dev-апгрейд на бэкенде; release → unavailable.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../features/mascot/kai_mascot.dart';
import '../../features/mascot/kai_speech_bubble.dart';
import '../../services/api/api_client.dart';
import '../../services/purchases/purchase_service.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart' show currentUserProvider;

// ---------------------------------------------------------------------------
// Константы ценообразования — меняются в одном месте.
// ---------------------------------------------------------------------------

/// Пробный период в днях (7 — соответствует стандарту App Store).
const int _kTrialDays = 7;

/// Цена месячного плана (строка, store-валюта позже через RevenueCat).
const String _kPriceMonthly = r'$10';

/// Цена годового плана.
const String _kPriceYearly = r'$79';

/// Эквивалентная месячная цена годового плана (для подзаголовка карточки).
const String _kPriceYearlyPerMonth = r'$6.58';

/// Скидка годового плана в % (честный расчёт: (120−79)/120 = 34%).
const int _kYearlySavePercent = 34;

// ---------------------------------------------------------------------------
// Enum вариантов плана
// ---------------------------------------------------------------------------

enum _Plan { monthly, yearly }

// ---------------------------------------------------------------------------
// Список premium-функций с акцентными галочками
// ---------------------------------------------------------------------------

const List<({IconData icon, String titleKey, String subtitleKey})> _benefits = [
  (
    icon: Icons.auto_awesome,
    titleKey: 'paywall.benefit_reschedule_title',
    subtitleKey: 'paywall.benefit_reschedule_subtitle',
  ),
  (
    icon: Icons.restaurant_menu,
    titleKey: 'paywall.benefit_menu_title',
    subtitleKey: 'paywall.benefit_menu_subtitle',
  ),
  (
    icon: Icons.photo_camera_outlined,
    titleKey: 'paywall.benefit_photo_title',
    subtitleKey: 'paywall.benefit_photo_subtitle',
  ),
  (
    icon: Icons.mic_none_outlined,
    titleKey: 'paywall.benefit_voice_title',
    subtitleKey: 'paywall.benefit_voice_subtitle',
  ),
  (
    icon: Icons.insights,
    titleKey: 'paywall.benefit_wrapped_title',
    subtitleKey: 'paywall.benefit_wrapped_subtitle',
  ),
];

// ---------------------------------------------------------------------------
// Утилита для уведомления об апгрейде из любого экрана
// ---------------------------------------------------------------------------

/// Показывает апселл-снэкбар с действием «Upgrade» → пейволл.
/// Вызывается там, где упёрлись в premium-гейт (AI-фичи).
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

  // Годовой план — по умолчанию выбран (лучший value)
  _Plan _selectedPlan = _Plan.yearly;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Вычисляет дату конца пробного периода (сегодня + _kTrialDays).
  String _trialEndDate(BuildContext context) {
    final end = DateTime.now().add(const Duration(days: _kTrialDays));
    // Локализованный короткий формат: "Jun 26", "26 июня" и т. д.
    try {
      final lang = Localizations.localeOf(context).languageCode;
      final fmt = DateFormat.yMMMd(lang);
      return fmt.format(end);
    } catch (_) {
      return '${end.day}.${end.month}.${end.year}';
    }
  }

  String get _selectedPriceLabel => _selectedPlan == _Plan.monthly
      ? '$_kPriceMonthly / mo'
      : '$_kPriceYearly / yr';

  // ---------------------------------------------------------------------------
  // Действия
  // ---------------------------------------------------------------------------

  Future<void> _subscribe() async {
    setState(() => _working = true);
    try {
      final outcome = await ref.read(purchaseServiceProvider).buyPremium();
      if (!mounted) return;

      switch (outcome) {
        case PurchaseOutcome.success:
          ref.invalidate(isPremiumProvider);
          ref.invalidate(currentUserProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.welcome_premium'))),
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
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final isAuthed = ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      // Без AppBar — закрытие через кнопку ✕ (compliance: должна быть заметной).
      body: SafeArea(
        child: Stack(
          children: [
            // ---- Основной контент ----
            _working
                ? Center(child: KaiLoader(label: context.s('loading.processing')))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 32),
                    children: [
                      // ---- Kai + речевой пузырь ----
                      _KaiSection(s: context.s),

                      const SizedBox(height: 20),

                      // ---- Заголовок ----
                      Text(
                        context.s('paywall.headline'),
                        style: textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        context.s('paywall.subheadline'),
                        style: textTheme.bodyMedium
                            ?.copyWith(color: ext.textMuted),
                      ),

                      const SizedBox(height: 24),

                      // ---- Список функций с акцентными галочками ----
                      ..._benefits.map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Акцентная галочка (accent — только для checkmarks в premium списке)
                              Icon(
                                Icons.check_circle_rounded,
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
                                      style: textTheme.bodySmall?.copyWith(
                                        color: ext.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ---- Небольшая пометка о бесплатном тире ----
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          context.s('paywall.free_includes'),
                          style: textTheme.bodySmall
                              ?.copyWith(color: ext.textFaint),
                        ),
                      ),

                      // ---- Карточки планов ----
                      _PlanCard(
                        label: context.s('paywall.plan_monthly'),
                        price: _kPriceMonthly,
                        priceSuffix: context.s('paywall.per_month'),
                        badge: null,
                        isSelected: _selectedPlan == _Plan.monthly,
                        onTap: _working
                            ? null
                            : () => setState(
                                () => _selectedPlan = _Plan.monthly),
                      ),

                      const SizedBox(height: 10),

                      _PlanCard(
                        label: context.s('paywall.plan_yearly'),
                        price: _kPriceYearly,
                        priceSuffix: context.s('paywall.per_year'),
                        badge: context.s('paywall.save_badge').replaceFirst(
                              '{pct}',
                              '$_kYearlySavePercent',
                            ),
                        subNote: context.s('paywall.yearly_per_month')
                            .replaceFirst('{price}', _kPriceYearlyPerMonth),
                        isSelected: _selectedPlan == _Plan.yearly,
                        onTap: _working
                            ? null
                            : () => setState(
                                () => _selectedPlan = _Plan.yearly),
                      ),

                      const SizedBox(height: 20),

                      // ---- Hint для незалогиненных ----
                      if (!isAuthed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            context.s('paywall.sign_in_hint'),
                            style: textTheme.bodySmall?.copyWith(
                              color: ext.textMuted,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // ---- Основная CTA ----
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _working ? null : _subscribe,
                          child: Text(context.s('paywall.cta_start_free')),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ---- Disclosure (читаемый, не faint) ----
                      Text(
                        context
                            .s('paywall.disclosure')
                            .replaceFirst('{n}', '$_kTrialDays')
                            .replaceFirst('{price}', _selectedPriceLabel)
                            .replaceFirst('{date}', _trialEndDate(context)),
                        style: textTheme.bodySmall?.copyWith(
                          color: ext.textMuted, // textMuted — НЕ faint: должно читаться
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // ---- Нижний ряд ссылок ----
                      _LinksRow(
                        onRestore: _working ? null : _restorePurchases,
                      ),

                      // ---- Dev tools (только debug) ----
                      if (kDebugMode) ...[
                        const SizedBox(height: 24),
                        Divider(color: ext.border),
                        const SizedBox(height: 8),
                        Text(
                          'Dev tools',
                          style: textTheme.labelSmall
                              ?.copyWith(color: ext.textFaint),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _working ? null : _devActivate,
                          child:
                              const Text('Activate Premium (dev only)'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _working ? null : _devDeactivate,
                          child:
                              const Text('Downgrade to Free (dev only)'),
                        ),
                      ],
                    ],
                  ),

            // ---- Кнопка ✕ (закрыть) — compliance: заметная, доступная ----
            // Позиция: top-right, за пределами ListView, всегда видна.
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

/// Кнопка закрытия: большая, хороший контраст. Ведёт на /today (free app).
/// Compliance: Apple 3.1.2 — free tier must be reachable without payment.
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
                // Без «guilt» — сразу в free-приложение.
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
            Icons.close,
            size: 24, // не мелкий — минимум 24 для touch target 48dp
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

/// Секция Kai сверху: маскот + речевой пузырь тёплого одноразового приветствия.
class _KaiSection extends StatelessWidget {
  const _KaiSection({required this.s});
  final String Function(String) s;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Пузырь слева от Kai
        Flexible(
          child: KaiSpeechBubble(
            message: s('paywall.kai_bubble'),
            tail: KaiBubbleTail.rightCenter,
            maxWidth: 200,
          ),
        ),
        const SizedBox(width: 8),
        // Kai — neutral/success (не harsh, не anxious — не давить на пользователя)
        const KaiMascot(
          size: 64,
          emotion: KaiEmotion.success,
          isHarsh: false,
        ),
      ],
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
  /// Текст бейджа, например «save 34%». null → без бейджа.
  final String? badge;
  /// Подстрочная заметка, например «$6.58 / mo». null → без заметки.
  final String? subNote;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Акцент — только у выбранного плана (accent discipline).
    final borderColor =
        isSelected ? colorScheme.primary : ext.border;
    final bgColor =
        isSelected ? ext.accentMuted : colorScheme.surface;
    // onAccent — цвет текста поверх accent; в ThemeExtension не вынесен,
    // но соответствует colorScheme.onPrimary (выставляется в _buildTheme).
    final onAccentColor = colorScheme.onPrimary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Радио-индикатор (filled/outline)
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : ext.border,
                  width: 2,
                ),
                color: isSelected ? colorScheme.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 14,
                      color: onAccentColor,
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

            // Цена справа
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: price,
                        style: textTheme.titleMedium?.copyWith(
                          color: isSelected
                              ? colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
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
                // Бейдж «save N%» — только на выбранном/yearly
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Нижний ряд ссылок: Terms · Privacy · Restore.
class _LinksRow extends StatelessWidget {
  const _LinksRow({required this.onRestore});
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ext.textMuted,
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed: () => context.push('/terms'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(context.s('paywall.link_terms'), style: style),
        ),
        Text(' · ', style: style),
        TextButton(
          // Privacy — в том же /terms экране (TermsScreen содержит оба раздела)
          onPressed: () => context.push('/terms'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(context.s('paywall.link_privacy'), style: style),
        ),
        Text(' · ', style: style),
        TextButton(
          onPressed: onRestore,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(context.s('paywall.restore'), style: style),
        ),
      ],
    );
  }
}
