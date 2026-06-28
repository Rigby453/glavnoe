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
// SnackBar: floating, скруглённый R12, surface1 фон, hairline border из ext.
// Иконка: Phosphor trash (ember-цвет).
// Кнопка «Undo» использует ключ 'common.undo' из системы переводов.
// Длительность: 4 секунды (совпадает с §3.3 ANIMATIONS.md).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

/// Показывает [SnackBar] с кнопкой «Undo» (§3.3 ANIMATIONS.md).
///
/// - Floating: появляется над bottom nav (margin 24dp / 16dp).
/// - Стиль: surface1 фон, hairline border ext.border, onSurface текст.
/// - Иконка: Phosphor trash, ember-цвет (деструктивное действие).
/// - Длительность 4 секунды.
/// - Скрывает предыдущий snackbar перед показом нового.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  final theme = Theme.of(context);
  final ext = theme.extension<FocusThemeExtension>();
  final borderColor = ext?.border ?? theme.colorScheme.outline;
  final emberColor = ext?.ember ?? theme.colorScheme.error;
  final surfaceColor = theme.colorScheme.surface;
  final onSurface = theme.colorScheme.onSurface;

  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      // 24dp по горизонтали (spec: screen padding 24), 16dp снизу
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 0.5),
      ),
      backgroundColor: surfaceColor,
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          // Trash icon — Phosphor regular, ember-цвет (деструктивное действие)
          PhosphorIcon(
            PhosphorIcons.trash(PhosphorIconsStyle.regular),
            size: 20,
            color: emberColor,
          ),
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
        label: context.s('common.undo'),
        textColor: theme.colorScheme.primary,
        onPressed: onUndo,
      ),
    ),
  );
}
