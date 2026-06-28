// Единый враппер для модальных bottom sheet в приложении.
// Реализует анимацию по ANIMATIONS.md §8.2:
//   появление: translateY(100%→0), 280 мс, easeOutCubic (kDurationNormal)
//   закрытие:  translateY(0→100%), 220 мс, easeInCubic
//   backdrop:  fade 0→0.5 (Colors.black54)
// При reduce motion (MediaQuery.disableAnimations) длительности = Duration.zero.
//
// Компонент контента: AppSheetContent — drag handle + title row + X + content + кнопка.
// Соответствует паттерну §4.3 REDESIGN-KANAME.md.

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'constants.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

// Длительности модалок — ANIMATIONS.md §8.2
const _kSheetOpenDuration = Duration(milliseconds: 280); // kDurationNormal
const _kSheetCloseDuration = Duration(milliseconds: 220);

/// Показывает модальный bottom sheet с анимацией по ANIMATIONS.md §8.2.
///
/// Тонкий враппер над [showModalBottomSheet]; все per-call параметры
/// прокидываются без изменения поведения.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useSafeArea = false,
  Color? backgroundColor,
  Clip? clipBehavior,
  ShapeBorder? shape,
  BoxConstraints? constraints,
  String? barrierLabel,
  bool useRootNavigator = false,
  RouteSettings? routeSettings,
  Offset? anchorPoint,
  AnimationController? transitionAnimationController,
}) {
  final reduce = reduceMotionOf(context);
  final openDuration = reduce ? Duration.zero : _kSheetOpenDuration;
  final closeDuration = reduce ? Duration.zero : _kSheetCloseDuration;

  final animStyle = AnimationStyle(
    duration: openDuration,
    reverseDuration: closeDuration,
  );

  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    useSafeArea: useSafeArea,
    backgroundColor: backgroundColor,
    clipBehavior: clipBehavior,
    shape: shape,
    constraints: constraints,
    barrierLabel: barrierLabel,
    useRootNavigator: useRootNavigator,
    routeSettings: routeSettings,
    anchorPoint: anchorPoint,
    transitionAnimationController: transitionAnimationController,
    barrierColor: Colors.black54,
    sheetAnimationStyle: animStyle,
  );
}

// ---------------------------------------------------------------------------
// AppSheetContent — стандартный контент bottom sheet (§4.3 REDESIGN-KANAME.md)
// ---------------------------------------------------------------------------
// Паттерн: drag handle · title row + Phosphor X close · content · primary button.
// Использование:
//   showAppSheet(context, builder: (ctx) => AppSheetContent(
//     title: context.s('today.add_task'),
//     child: MyFormBody(),
//     primaryButton: FilledButton(onPressed: save, child: Text(context.s('btn.save'))),
//   ));

/// Стандартная обёртка содержимого bottom sheet.
///
/// Обеспечивает единообразный макет по §4.3:
///   - Drag handle (32×4 dp, скруглённый)
///   - Строка заголовка с Phosphor X (закрыть)
///   - Содержимое [child] (за скроллинг отвечает вызывающий код)
///   - Одна primary кнопка [primaryButton] снизу (если передана)
///   - SafeArea снизу
///
/// Overflow-safe: заголовок обрезается с ellipsis; ширина 320px работает.
class AppSheetContent extends StatelessWidget {
  const AppSheetContent({
    super.key,
    required this.title,
    required this.child,
    this.onClose,
    this.primaryButton,
  });

  /// Заголовок листа. Обрезается с ellipsis при переполнении.
  final String title;

  /// Содержимое. Скроллинг реализует вызывающий код (ListView / SingleChildScrollView).
  final Widget child;

  /// Колбэк закрытия. Если null — вызывается [Navigator.of(context).pop()].
  final VoidCallback? onClose;

  /// Одна primary кнопка снизу (FilledButton с accent). null — кнопки нет.
  final Widget? primaryButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>()!;

    return SafeArea(
      // Только нижний safe area (кнопка Home/NavBar)
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Drag handle ---
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: ext.textFaint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),

          // --- Title row ---
          Padding(
            // Левый отступ 24dp; правый 8dp (IconButton имеет свой padding)
            padding: const EdgeInsets.fromLTRB(24, 8, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                // Phosphor X — закрыть лист
                IconButton(
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                  icon: PhosphorIcon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    size: 20,
                  ),
                  tooltip: context.s('btn.close'),
                  style: IconButton.styleFrom(
                    foregroundColor: ext.textMuted,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // --- Содержимое (за overflow отвечает child) ---
          child,

          // --- Primary кнопка (если есть) ---
          if (primaryButton != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: primaryButton!,
              ),
            )
          else
            // Нет кнопки → добавляем отступ снизу
            const SizedBox(height: 24),
        ],
      ),
    );
  }
}
