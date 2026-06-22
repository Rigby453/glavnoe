// Настраиваемые действия свайпа по задачам в списке Today.
// Пользователь выбирает, что делает свайп вправо и свайп влево, из набора:
// выполнить (done) / пропустить (skip) / удалить (delete) / отложить (snooze).
//
// Хранение в SharedPreferences по образцу tone_provider / text_scale_provider:
// Notifier + NotifierProvider, дефолты сохраняют текущее поведение
// (вправо = done, влево = skip).
//
// UI настроек добавляет отдельный агент (profile_screen.dart) — здесь только
// провайдер с понятным API + хелперы оформления (иконка/цвет/подпись).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_strings.dart';
import '../theme/app_theme.dart'; // FocusThemeExtension (success/ember/textFaint)
import '../theme/theme_provider.dart'; // sharedPreferencesProvider

/// Действие, выполняемое по свайпу задачи.
enum SwipeAction { done, skip, delete, snooze }

extension SwipeActionX on SwipeAction {
  /// Иконка действия для фона свайпа.
  IconData get icon => switch (this) {
        SwipeAction.done => Icons.check,
        SwipeAction.skip => Icons.remove_circle_outline,
        SwipeAction.delete => Icons.delete_outline,
        SwipeAction.snooze => Icons.snooze,
      };

  /// Цвет действия — резолвится из дизайн-токенов темы (без hardcoded цветов):
  ///   done   → success (зелёный),
  ///   skip   → textFaint (серый),
  ///   delete → ember (красный/срочный),
  ///   snooze → нейтральный accent (primary).
  Color color(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    return switch (this) {
      SwipeAction.done => ext?.success ?? scheme.primary,
      SwipeAction.skip => ext?.textFaint ?? scheme.onSurface.withAlpha(140),
      SwipeAction.delete => ext?.ember ?? scheme.error,
      SwipeAction.snooze => scheme.primary,
    };
  }

  /// Локализованная подпись действия (для UI настроек и подсказок).
  String label(BuildContext context) => switch (this) {
        SwipeAction.done => context.s('today.swipe_done'),
        SwipeAction.skip => context.s('today.swipe_skip'),
        SwipeAction.delete => context.s('today.swipe_delete'),
        SwipeAction.snooze => context.s('today.swipe_snooze'),
      };

  /// Ключ для хранения в SharedPreferences.
  String get storageKey => name;

  static SwipeAction fromKey(String? key, SwipeAction fallback) =>
      SwipeAction.values.firstWhere(
        (a) => a.name == key,
        orElse: () => fallback,
      );
}

/// Текущие настройки свайпов: действие вправо и влево (immutable).
@immutable
class SwipeActionsConfig {
  const SwipeActionsConfig({required this.right, required this.left});

  /// Действие свайпа вправо (startToEnd). Дефолт: done.
  final SwipeAction right;

  /// Действие свайпа влево (endToStart). Дефолт: skip.
  final SwipeAction left;

  /// Дефолты, сохраняющие текущее поведение приложения.
  static const SwipeActionsConfig defaults =
      SwipeActionsConfig(right: SwipeAction.done, left: SwipeAction.skip);

  SwipeActionsConfig copyWith({SwipeAction? right, SwipeAction? left}) =>
      SwipeActionsConfig(
        right: right ?? this.right,
        left: left ?? this.left,
      );

  @override
  bool operator ==(Object other) =>
      other is SwipeActionsConfig &&
      other.right == right &&
      other.left == left;

  @override
  int get hashCode => Object.hash(right, left);
}

const _kRightKey = 'swipe_right_action';
const _kLeftKey = 'swipe_left_action';

class SwipeActionsNotifier extends Notifier<SwipeActionsConfig> {
  @override
  SwipeActionsConfig build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return SwipeActionsConfig(
      right: SwipeActionX.fromKey(
        prefs.getString(_kRightKey),
        SwipeActionsConfig.defaults.right,
      ),
      left: SwipeActionX.fromKey(
        prefs.getString(_kLeftKey),
        SwipeActionsConfig.defaults.left,
      ),
    );
  }

  /// Задать действие для свайпа вправо.
  Future<void> setRight(SwipeAction action) async {
    await ref.read(sharedPreferencesProvider).setString(_kRightKey, action.name);
    state = state.copyWith(right: action);
  }

  /// Задать действие для свайпа влево.
  Future<void> setLeft(SwipeAction action) async {
    await ref.read(sharedPreferencesProvider).setString(_kLeftKey, action.name);
    state = state.copyWith(left: action);
  }
}

/// Настройки свайпов по задачам. Читается в task_list.dart;
/// UI выбора добавляет отдельный агент в Профиле.
final swipeActionsProvider =
    NotifierProvider<SwipeActionsNotifier, SwipeActionsConfig>(
        SwipeActionsNotifier.new);
