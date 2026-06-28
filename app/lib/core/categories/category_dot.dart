// Виджеты для отображения категорийного цвета.
//
// CategoryDot   — заполненный круг 10dp (или произвольного размера) в цвете
//                 категории. Ничего не рендерит (SizedBox.shrink) для пустого тега.
// CategoryChip  — тонкий «пилюльный» чип: точка + текст тега, обводка hairline.
//                 Текст тега = данные пользователя, не переводится.
//
// Оба виджета используют categoryColorFor из category_colors.dart.
// Цвет не зависит от темы приложения.

import 'package:flutter/material.dart';

import 'category_colors.dart';

// ---------------------------------------------------------------------------
// CategoryDot
// ---------------------------------------------------------------------------

/// Заполненный круг размером [size] в детерминированном цвете категории [tag].
///
/// Рендерит [SizedBox.shrink] если [tag] пуст — безопасно вставлять в Row/Column
/// без условий снаружи.
///
/// ```dart
/// CategoryDot(tag: 'math')        // 10dp синяя точка
/// CategoryDot(tag: 'math', size: 8)
/// CategoryDot(tag: '')            // → SizedBox.shrink()
/// ```
class CategoryDot extends StatelessWidget {
  const CategoryDot({
    super.key,
    required this.tag,
    this.size = 10,
  });

  /// Тег категории (первый тег задачи без символа «#»).
  final String tag;

  /// Диаметр точки в логических пикселях. По умолчанию 10 (design-tokens §1.3).
  final double size;

  @override
  Widget build(BuildContext context) {
    // Пустой тег → ничего не рендерим.
    final color = categoryColorForOrNull(tag);
    if (color == null) return const SizedBox.shrink();

    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CategoryChip
// ---------------------------------------------------------------------------

/// Тонкий «пилюльный» чип: маленькая точка категории + текст тега.
///
/// Используется там, где нужно показать метку с цветом (например, в карточке
/// задачи или фильтре), а не просто точку.
///
/// Спецификация:
///   • Обводка hairline (0.5dp) в цвете категории с прозрачностью 50%.
///   • Фон прозрачный (не тянет визуальный вес).
///   • Точка 6dp слева; зазор 5dp; текст в стиле labelSmall темы.
///   • border-radius = pill (999) из design-tokens.
///
/// Рендерит [SizedBox.shrink] если [tag] пуст.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.tag,
    this.dotSize = 6,
  });

  /// Тег категории (без «#»). Отображается как есть — пользовательские данные.
  final String tag;

  /// Диаметр точки внутри чипа. По умолчанию 6dp.
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorForOrNull(tag);
    if (color == null) return const SizedBox.shrink();

    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999), // pill
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 0.5, // hairline из design-tokens §border
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Точка категории
          SizedBox(
            width: dotSize,
            height: dotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          // Текст тега — данные пользователя, не переводятся
          Text(
            tag,
            style: labelStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
