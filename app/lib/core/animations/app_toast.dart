// Тосты приложения — ANIMATIONS.md §3.
// API: showAppToast(context, variant: ..., message: '...', onUndo: ...).
// Максимум 1 тост одновременно; новый вызов мгновенно убирает предыдущий.
//
// Иконки: Phosphor (check / clock / trash).
// Цвета: ext.success / ext.ember / surface — из FocusThemeExtension.
// Foreground: вычисляется по яркости фона (белый или ink).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'constants.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Публичный enum вариантов
// ---------------------------------------------------------------------------

/// Варианты тоста (§3.1–3.3).
enum AppToastVariant {
  /// §3.1 Задача выполнена — success-цвет из темы
  done,

  /// §3.2 Напоминание о дедлайне — ember-цвет из темы
  deadline,

  /// §3.3 Задача удалена — поверхность темы + рамка + кнопка Undo
  removed,
}

// ---------------------------------------------------------------------------
// Публичная точка входа
// ---------------------------------------------------------------------------

/// Показывает тост снизу экрана (§3 ANIMATIONS.md).
/// Максимум 1 тост одновременно — предыдущий убирается немедленно.
/// [onUndo] — только для варианта [AppToastVariant.removed]; таймер = 4 сек.
void showAppToast(
  BuildContext context, {
  required AppToastVariant variant,
  required String message,
  VoidCallback? onUndo,
}) {
  _AppToastManager._dismiss();

  final overlay = Overlay.of(context);
  late OverlayEntry entry;

  void dismiss() => _AppToastManager._dismiss();

  entry = OverlayEntry(
    builder: (_) => _AppToastOverlay(
      variant: variant,
      message: message,
      onUndo: onUndo,
      onDismiss: dismiss,
    ),
  );

  _AppToastManager._current = entry;
  overlay.insert(entry);
}

// ---------------------------------------------------------------------------
// Внутренний менеджер единственного тоста
// ---------------------------------------------------------------------------

class _AppToastManager {
  _AppToastManager._();

  static OverlayEntry? _current;

  static void _dismiss() {
    _current?.remove();
    _current = null;
  }
}

// ---------------------------------------------------------------------------
// Виджет тоста с анимацией
// ---------------------------------------------------------------------------

class _AppToastOverlay extends StatefulWidget {
  const _AppToastOverlay({
    required this.variant,
    required this.message,
    required this.onDismiss,
    this.onUndo,
  });

  final AppToastVariant variant;
  final String message;
  final VoidCallback onDismiss;
  final VoidCallback? onUndo;

  @override
  State<_AppToastOverlay> createState() => _AppToastOverlayState();
}

class _AppToastOverlayState extends State<_AppToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  static const Duration _enterDuration = kDurationNormal; // 280 мс
  static const Duration _exitDuration = Duration(milliseconds: 220);
  static const Curve _exitCurve = Curves.easeInCubic;
  static const double _slidePixels = 80.0;

  // Таймер автоскрытия — храним как Timer (не «голый» Future.delayed), чтобы
  // ГАРАНТИРОВАННО отменить его в dispose(). Ручное закрытие (тап Undo, замена
  // новым тостом) удаляет OverlayEntry раньше срабатывания таймера; без cancel()
  // таймер оставался бы «pending» до конца теста/после ухода с экрана
  // ("A Timer is still pending" в widget-тестах — известный гэп до этого фикса).
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _enterDuration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: kCurveLift),
    );
    _ctrl.forward().then((_) => _scheduleAuto());
  }

  void _scheduleAuto() {
    final hangMs = widget.onUndo != null ? 4000 : 3500;
    _autoTimer = Timer(Duration(milliseconds: hangMs), () {
      if (mounted) _startExit();
    });
  }

  Future<void> _startExit() async {
    if (!mounted) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!reduce) {
      await _ctrl.animateTo(0, duration: _exitDuration, curve: _exitCurve);
    }
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  // --- Цвет фона по варианту ---
  // Используем ext.success / ext.ember — семантические статусные цвета темы.
  // Для 'removed' — surface1 из colorScheme (tema-aware).
  Color _bgColor(ThemeData theme, FocusThemeExtension? ext) {
    switch (widget.variant) {
      case AppToastVariant.done:
        // success — семантический зелёный; достаточно тёмный на светлых темах.
        return ext?.success ?? const Color(0xFF1D9E75);
      case AppToastVariant.deadline:
        // ember — семантический оранжевый.
        return ext?.ember ?? const Color(0xFFC2510C);
      case AppToastVariant.removed:
        return theme.colorScheme.surface;
    }
  }

  // --- Foreground цвет: белый или ink в зависимости от яркости фона ---
  // success/ember на тёмных темах светлее → нужен тёмный текст.
  // На светлых темах они тёмные → нужен белый текст.
  Color _fgColor(ThemeData theme, Color bg, FocusThemeExtension? ext) {
    switch (widget.variant) {
      case AppToastVariant.done:
      case AppToastVariant.deadline:
        // luminance > 0.35 → фон достаточно светлый, нужен тёмный текст
        return bg.computeLuminance() > 0.35
            ? theme.colorScheme.onSurface
            : Colors.white;
      case AppToastVariant.removed:
        return theme.colorScheme.onSurface;
    }
  }

  // --- Phosphor иконка по варианту ---
  IconData _iconData() {
    switch (widget.variant) {
      case AppToastVariant.done:
        return PhosphorIcons.check(PhosphorIconsStyle.regular);
      case AppToastVariant.deadline:
        return PhosphorIcons.clock(PhosphorIconsStyle.regular);
      case AppToastVariant.removed:
        return PhosphorIcons.trash(PhosphorIconsStyle.regular);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final mq = MediaQuery.of(context);
    final reduce = mq.disableAnimations;

    // Отступ снизу: 16px + высота нижней навигации + safe area
    final bottomOffset = 16.0 + kBottomNavigationBarHeight + mq.viewPadding.bottom;

    final bg = _bgColor(theme, ext);
    final fg = _fgColor(theme, bg, ext);
    final iconData = _iconData();

    // Рамка только для removed (hairline 0.5dp)
    final border = widget.variant == AppToastVariant.removed
        ? Border.all(
            color: ext?.border ?? theme.colorScheme.onSurface.withAlpha(40),
            width: 0.5,
          )
        : null;

    return Positioned(
      left: 24,
      right: 24,
      bottom: bottomOffset,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) {
          final curvedValue = reduce
              ? 1.0
              : kCurveLift.transform(_ctrl.value.clamp(0.0, 1.0));
          final dy = (1.0 - curvedValue) * _slidePixels;

          return Transform.translate(
            offset: Offset(0, dy),
            child: Opacity(
              opacity: reduce ? 1.0 : _opacity.value,
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                PhosphorIcon(iconData, size: 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.onUndo != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: fg,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      widget.onUndo!();
                      widget.onDismiss();
                    },
                    child: Text(context.s('common.undo')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
