// Экран подписки / пейволл (SPEC: $10/мес, premium открывает AI).
// Реальные платежи (RevenueCat) — Phase 1; сейчас Subscribe работает через
// PurchaseService (заглушка): в debug вызывает dev-апгрейд, в release — сообщает
// «скоро». Одна кнопка Subscribe заменяет прежние Subscribe + Dev: unlock premium.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../services/api/api_client.dart';
import '../../services/purchases/purchase_service.dart';
import '../auth/auth_controller.dart';
import '../profile/profile_screen.dart' show currentUserProvider;

// Иконки остаются статичными; тексты локализуются через context.s().
const List<({IconData icon, String titleKey, String subtitleKey})> _benefits = [
  (
    icon: Icons.auto_awesome,
    titleKey: 'paywall.benefit_smarter_title',
    subtitleKey: 'paywall.benefit_smarter_subtitle',
  ),
  (
    icon: Icons.bolt,
    titleKey: 'paywall.benefit_tone_title',
    subtitleKey: 'paywall.benefit_tone_subtitle',
  ),
  (
    icon: Icons.insights,
    titleKey: 'paywall.benefit_diary_title',
    subtitleKey: 'paywall.benefit_diary_subtitle',
  ),
  (
    icon: Icons.photo_camera_outlined,
    titleKey: 'paywall.benefit_photo_title',
    subtitleKey: 'paywall.benefit_photo_subtitle',
  ),
  (
    icon: Icons.block,
    titleKey: 'paywall.benefit_noads_title',
    subtitleKey: 'paywall.benefit_noads_subtitle',
  ),
];

/// Показывает апселл-снэкбар с действием «Upgrade» → пейволл.
/// Вызывается там, где упёрлись в premium-гейт (AI-фичи).
void showPremiumUpsell(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      // Интерполяция с $feature — строка остаётся на EN; переведены только константы.
      content: Text('Premium feature — upgrade for $feature'),
      action: SnackBarAction(
        label: context.s('paywall.upgrade'),
        onPressed: () => context.push('/paywall'),
      ),
    ),
  );
}

class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  bool _working = false;

  Future<void> _subscribe() async {
    setState(() => _working = true);
    try {
      final outcome = await ref.read(purchaseServiceProvider).buyPremium();
      if (!mounted) return;

      switch (outcome) {
        case PurchaseOutcome.success:
          // Обновляем premium-статус и данные пользователя в UI.
          ref.invalidate(isPremiumProvider);
          ref.invalidate(currentUserProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('paywall.welcome_premium'))),
          );
          context.pop();

        case PurchaseOutcome.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.s('paywall.coming_soon')),
            ),
          );

        case PurchaseOutcome.error:
          // Если не авторизован — подсказываем войти.
          final isAuthed =
              ref.read(authControllerProvider.notifier).isAuthenticated;
          final message = isAuthed
              ? context.s('paywall.error_generic')
              : context.s('paywall.sign_in_to_subscribe');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );

        case PurchaseOutcome.cancelled:
          // Пользователь закрыл диалог — ничего не делаем.
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
        const SnackBar(content: Text('✅ Premium activated!')),
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
            SnackBar(
              content: Text(context.s('paywall.nothing_to_restore')),
            ),
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isAuthed = ref.read(authControllerProvider.notifier).isAuthenticated;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('paywall.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            Text(context.s('paywall.headline'), style: textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              context.s('paywall.subheadline'),
              style: textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ..._benefits.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(b.icon, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.s(b.titleKey), style: textTheme.titleSmall),
                          const SizedBox(height: 2),
                          Text(context.s(b.subtitleKey), style: textTheme.bodySmall),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              color: colorScheme.primary.withValues(alpha: 0.12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('\$10', style: textTheme.headlineMedium),
                    Text(context.s('paywall.per_month'), style: textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!isAuthed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  context.s('paywall.sign_in_hint'),
                  style: textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _working ? null : _subscribe,
                child: Text(context.s('paywall.subscribe')),
              ),
            ),
            const SizedBox(height: 8),
            // Восстановление покупок — понадобится после интеграции RevenueCat.
            TextButton(
              onPressed: _working ? null : _restorePurchases,
              child: Text(context.s('paywall.restore')),
            ),
            const SizedBox(height: 12),
            Text(
              context.s('paywall.cancel_hint'),
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            // Кнопка только в debug-сборке — активирует premium без оплаты
            if (kDebugMode) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text('Dev tools', style: textTheme.labelSmall),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: _working ? null : _devActivate,
                child: const Text('🛠 Activate Premium (dev only)'),
              ),
              const SizedBox(height: 4),
              OutlinedButton(
                onPressed: _working ? null : _devDeactivate,
                child: const Text('🛠 Downgrade to Free (dev only)'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
