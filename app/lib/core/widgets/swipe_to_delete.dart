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
// Если нужно И удалить И показать Undo в одном месте — передавай всю логику
// в onDelete. SwipeToDelete не знает про Undo сам по себе — это сделано
// намеренно, чтобы вызывающий код управлял сообщением и восстановлением.
//
// Фон свайпа: ember цвет из FocusThemeExtension + иконка delete_outline (белая).
// direction: endToStart (свайп влево = удалить).
// Reduce-motion: Dismissible сам корректно работает с disableAnimations.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Обёртка над [Dismissible] — свайп влево немедленно вызывает [onDelete].
///
/// Диалога подтверждения нет (пользователь выбрал паттерн «без подтверждения»).
/// Вместо этого вызывающий код показывает Undo-snackbar через [showUndoSnackBar].
///
/// Параметры:
/// - [key] — обязательный уникальный ключ (обычно ValueKey(item.id))
/// - [onDelete] — колбэк, вызываемый после завершения свайпа; должен удалить
///   элемент из БД И (при желании) показать Undo-snackbar
/// - [child] — содержимое строки
class SwipeToDelete extends StatelessWidget {
  const SwipeToDelete({
    required super.key,
    required this.onDelete,
    required this.child,
  });

  /// Собственно удаление + (опционально) показ Undo-snackbar.
  /// Вызывается после завершения свайпа.
  final VoidCallback onDelete;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // ember — деструктивное действие (01-color.md: ember = urgent/destructive)
    final emberColor = ext?.ember ?? Theme.of(context).colorScheme.error;

    return Dismissible(
      key: key!,
      direction: DismissDirection.endToStart,
      // Фон: ember с иконкой delete_outline (белая иконка даёт нужный контраст)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          // Лёгкий ember-фон: 0.15 alpha, как уже принято в workout_editor
          color: emberColor.withValues(alpha: 0.15),
          // Скругление — подхватывается из BoxDecoration; в ListView без Card
          // можно не указывать, в ItemCard — Card уже скруглён
        ),
        child: Icon(
          Icons.delete_outline,
          color: emberColor,
        ),
      ),
      // onDismissed: вызывается после завершения анимации ухода элемента.
      // confirmDismiss не нужен — удаление немедленное, восстановление через Undo.
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }
}
