// KaiLoader — загрузочный индикатор на базе маскота Kai.
// Заменяет стандартный CircularProgressIndicator во всех экранах, где идёт
// ожидание (AI-ответ, синхронизация, загрузка данных).
//
// Использование:
//   const KaiLoader()                          — базовый, без подписи
//   const KaiLoader(label: 'Thinking…')       — с подписью
//   const KaiLoader(size: 72, label: 'Hold on') — крупнее
//
// Fallback:
//   • showKaiProvider == false → CircularProgressIndicator + label
//   • reduceMotion == true     → CircularProgressIndicator + label
// Оба случая используют цвета темы (colorScheme.primary + textMuted).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../animations/constants.dart';
import '../settings/mascot_provider.dart';
import '../settings/tone_provider.dart';
import '../theme/app_theme.dart';
import '../../features/mascot/kai_mascot.dart';

/// Drop-in замена спиннера. Показывает Kai в состоянии `thinking`.
///
/// При [showKai]=false или [reduceMotion]=true — минималистичный
/// [CircularProgressIndicator] с необязательной подписью.
class KaiLoader extends ConsumerWidget {
  const KaiLoader({
    super.key,
    this.label,
    this.size = 56.0,
  });

  /// Необязательная подпись ниже маскота (напр. «Thinking…»).
  final String? label;

  /// Сторона квадрата маскота / диаметр fallback-спиннера. По умолчанию 56.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showKai = ref.watch(showKaiProvider);
    final tone = ref.watch(toneProvider);
    final reduce = reduceMotionOf(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ext = theme.extension<FocusThemeExtension>();

    // Цвет подписи — ext.textMuted (токен v4); fallback = onSurface ~55%
    final mutedColor = ext?.textMuted ?? colorScheme.onSurface.withAlpha(140);

    // Fallback: Kai отключён пользователем или включён reduce-motion
    if (!showKai || reduce) {
      return _FallbackLoader(
        size: size,
        label: label,
        mutedColor: mutedColor,
        accentColor: colorScheme.primary,
      );
    }

    // Основной путь: Kai в состоянии thinking
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        KaiMascot(
          size: size,
          emotion: KaiEmotion.thinking,
          isHarsh: tone == AppTone.harsh,
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  letterSpacing: 0.2,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Минималистичный fallback когда Kai скрыт или reduce-motion включён.
class _FallbackLoader extends StatelessWidget {
  const _FallbackLoader({
    required this.size,
    required this.label,
    required this.mutedColor,
    required this.accentColor,
  });

  final double size;
  final String? label;
  final Color mutedColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    // Диаметр спиннера совпадает с размером Kai для визуального паритета
    final spinnerSize = size * 0.5; // немного меньше — CircularProgressIndicator имеет padding
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: spinnerSize,
          height: spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(accentColor),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 10),
          Text(
            label!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  letterSpacing: 0.2,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
