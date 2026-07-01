// Глобальный error boundary — заменяет фирменный красный ErrorWidget Flutter
// на дружелюбный фолбэк-экран в non-debug сборках (release/profile), чтобы
// тестеры не видели «страшный красный экран» при непойманном исключении.
//
// В debug-режиме поведение НЕ меняется — разработчик по-прежнему видит
// полный ErrorWidget с текстом исключения и стеком.
//
// ErrorWidget.builder не получает BuildContext, поэтому строки резолвятся
// через [sForLocale] (app_strings.dart) по тегу локали, сохранённому в
// [errorBoundaryLocaleTag]. main() выставляет его при старте из
// SharedPreferences, а LocaleNotifier.setLocale обновляет при смене языка.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_strings.dart';

/// Текущий тег локали (напр. 'en', 'ru', 'pt-BR') для фолбэк-экрана ошибок.
/// Обновляется из main() при старте и из LocaleNotifier при смене языка —
/// см. core/l10n/locale_provider.dart. По умолчанию 'en' (безопасный откат).
String errorBoundaryLocaleTag = 'en';

/// Настраивает глобальный перехват ошибок рендеринга. Вызывать один раз в
/// main() до runApp().
void setupErrorBoundary() {
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // В debug — стандартный вывод в консоль с полным стеком.
      FlutterError.presentError(details);
    } else {
      // В релизе не молчим: пишем в debug-лог для локальной диагностики.
      // Полноценный crash-reporting SDK сюда можно добавить позже.
      debugPrint(
        'Kaizen: unhandled error caught by global boundary: '
        '${details.exceptionAsString()}',
      );
    }
    originalOnError?.call(details);
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    if (kDebugMode) {
      // Разработчик должен видеть полную ошибку — не прячем её.
      return ErrorWidget(details.exception);
    }
    return _FriendlyErrorFallback(details: details);
  };
}

/// Минимальный дружелюбный фолбэк, который безопасен даже вне полноценного
/// дерева MaterialApp (свой Directionality/Material/ColoredBox — не зависит
/// от Theme/Localizations выше по дереву).
class _FriendlyErrorFallback extends StatelessWidget {
  const _FriendlyErrorFallback({required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    // Best-effort: Theme.of() всегда возвращает значение (fallback ThemeData,
    // если выше по дереву нет реального Theme), но на всякий случай
    // подстраховываемся try/catch — фолбэк не должен падать сам.
    ThemeData? theme;
    try {
      theme = Theme.of(context);
    } catch (_) {
      theme = null;
    }
    final bgColor = theme?.scaffoldBackgroundColor ?? const Color(0xFFF6F5F2);
    final inkColor = theme?.colorScheme.onSurface ?? const Color(0xFF1B1A18);
    final mutedColor = inkColor.withValues(alpha: 0.7);

    final title = sForLocale(errorBoundaryLocaleTag, 'error_boundary.title');
    final body = sForLocale(errorBoundaryLocaleTag, 'error_boundary.body');
    final backLabel = sForLocale(errorBoundaryLocaleTag, 'btn.back');

    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: bgColor,
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: mutedColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: inkColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: mutedColor, fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton(
                      onPressed: () {
                        // Best-effort «назад» — если навигатора нет или
                        // некуда возвращаться, просто ничего не делаем.
                        try {
                          Navigator.of(context).maybePop();
                        } catch (_) {
                          // Игнорируем — фолбэк не должен падать сам.
                        }
                      },
                      child: Text(backLabel),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
