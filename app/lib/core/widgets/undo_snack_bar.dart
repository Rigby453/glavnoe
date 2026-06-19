// Хелпер показа Undo-snackbar для паттерна безопасного удаления.
//
// КОНТРАКТ ДЛЯ СЛЕДУЮЩИХ АГЕНТОВ:
// ---------------------------------------------------------------------------
// showUndoSnackBar(
//   context,
//   message: '"Протеиновый коктейль" removed',
//   onUndo: () async { await dao.reinsertItem(snapshot); },
// );
//
// Публичный API:
//   void showUndoSnackBar(
//     BuildContext context, {
//     required String message,
//     required VoidCallback onUndo,
//   })
//
// SnackBar: floating, скруглённый, surface-цвет из темы, border из темы.
// Кнопка «Undo» использует ключ 'common.undo' из системы переводов.
// Перед показом нового — скрывает предыдущий (hideCurrentSnackBar).
// Длительность: 4 секунды (совпадает с §3.3 ANIMATIONS.md).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Показывает [SnackBar] с кнопкой «Undo» (§3.3 ANIMATIONS.md).
///
/// - Floating-поведение: появляется над bottom nav.
/// - Стиль из темы: surface фон, border рамка, onSurface текст.
/// - Длительность 4 секунды.
/// - Скрывает предыдущий snackbar перед показом нового.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  // Убираем предыдущий немедленно — нет накопления
  messenger.hideCurrentSnackBar();

  final theme = Theme.of(context);
  final ext = theme.extension<FocusThemeExtension>();
  final borderColor = ext?.border ?? theme.colorScheme.outline;
  final surfaceColor = theme.colorScheme.surface;
  final onSurface = theme.colorScheme.onSurface;

  messenger.showSnackBar(
    SnackBar(
      // floating — над нижней навигацией, не перекрывает контент экрана
      behavior: SnackBarBehavior.floating,
      // Убираем стандартные отступы floating-snackbar, задаём через margin
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      backgroundColor: surfaceColor,
      // 4 секунды (§3.3)
      duration: const Duration(seconds: 4),
      // Иконка корзины слева + текст + кнопка Undo
      content: Row(
        children: [
          Icon(Icons.delete_outline, size: 20, color: onSurface.withAlpha(180)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      action: SnackBarAction(
        // Переиспользуем common.undo; если ключа нет — откат на 'Undo'
        label: context.s('common.undo'),
        // accent-цвет для кнопки действия — согласно теме
        textColor: theme.colorScheme.primary,
        onPressed: onUndo,
      ),
    ),
  );
}
