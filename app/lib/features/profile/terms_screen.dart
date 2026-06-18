// Пользовательское соглашение и политика конфиденциальности.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(context.s('profile.terms_privacy')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(context.s('profile.terms_title'), style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            context.s('profile.terms_body'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Divider(color: colorScheme.outline.withValues(alpha: 0.3)),
          const SizedBox(height: 32),
          Text(context.s('profile.privacy_title'), style: textTheme.headlineSmall),
          const SizedBox(height: 16),
          Text(
            context.s('profile.privacy_body'),
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 48),
          Text(
            context.s('profile.tagline'),
            style: textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
