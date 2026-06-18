// Карточка одного варианта раскладки (free или AI) с кнопкой Apply.
// Общая для утреннего и вечернего разборов.

import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import 'review_engine.dart';

class ReviewVariantCard extends StatelessWidget {
  const ReviewVariantCard({
    required this.variant,
    required this.onApply,
    super.key,
  });

  final PlanVariant variant;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(variant.label),
        subtitle: variant.reason.isEmpty ? null : Text(variant.reason),
        trailing: TextButton(
          onPressed: onApply,
          child: Text(context.s('today.apply_btn')),
        ),
      ),
    );
  }
}
