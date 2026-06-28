// SwipeToDelete — переиспользуемая обёртка над Dismissible для безопасного удаления.
//
// КОНТРАКТ ДЛЯ СЛЕДУЮЩИХ АГЕНТОВ:
// ---------------------------------------------------------------------------
// SwipeToDelete(
//   key: ValueKey(item.id),          // обязательно уникальный
//   onDelete: () async {
//     await dao.removeItem(item.id);  // собственно удаление из БД
//     if (context.mounted) {
//       showUndoSnackBar(context,
//         message: '"${item.name}" removed',
//         onUndo: () => dao.reinsertItem(snapshot), // восстановление
//       );
//     }
//   },
//   child: MyItemTile(item: item),
// )
//
// Фон свайпа: ember (0.15 alpha) + Phosphor trash (ember-цвет).
// direction: endToStart (свайп влево = удалить).
// Reduce-motion: Dismissible сам корректно работает с disableAnimations.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';

/// Обёртка над [Dismissible] — свайп влево немедленно вызывает [onDelete].
///
/// Диалога подтверждения нет.
/// Вызывающий код показывает Undo-snackbar через [showUndoSnackBar].
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    required super.key,
    required this.onDelete,
    required this.child,
  });

  /// Удаление + (опционально) показ Undo-snackbar.
  /// Вызывается после завершения свайпа.
  final VoidCallback onDelete;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // ember — деструктивное действие (design-tokens.json §status)
    final emberColor = ext?.ember ?? Theme.of(context).colorScheme.error;

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      // Фон: ember-тинт + Phosphor trash (ember-цвет)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: emberColor.withValues(alpha: 0.15),
        ),
        child: PhosphorIcon(
          PhosphorIcons.trash(PhosphorIconsStyle.regular),
          size: 20,
          color: emberColor,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
