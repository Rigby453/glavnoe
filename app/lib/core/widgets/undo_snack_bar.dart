// Хелпер показа Undo-тоста для паттерна безопасного удаления.
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
// ЕДИНЫЙ UNDO-МЕХАНИЗМ (сведение дублей, ночная сессия 2026-07-01):
// Раньше это был отдельный ScaffoldMessenger.SnackBar (свой вид/анимация).
// Теперь — тонкий форвардер к showAppToast(variant: removed) (core/animations/
// app_toast.dart) — тому же overlay-тосту, что используют done/deadline/removed
// по всему приложению (§3.3 ANIMATIONS.md). Сигнатура НЕ изменилась — все
// существующие вызовы (food/recipes/recipe_editor/workouts/meditation/habits/
// breathing/goal steps) продолжают работать без правок.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../animations/app_toast.dart';

/// Показывает Undo-тост (§3.3 ANIMATIONS.md) — форвардер к [showAppToast]
/// с вариантом [AppToastVariant.removed] (поверхность темы + hairline border +
/// Phosphor trash + кнопка «Undo», локализованная ключом `common.undo`).
///
/// Один и тот же внешний вид/анимация/таймер (4 сек) для ЛЮБОГО удаления
/// в приложении — независимо от того, вызван ли [showUndoSnackBar] или
/// [showAppToast] напрямую.
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  showAppToast(
    context,
    variant: AppToastVariant.removed,
    message: message,
    onUndo: onUndo,
  );
}
