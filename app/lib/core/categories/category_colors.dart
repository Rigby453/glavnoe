// Утилита цветов категорий для редизайна Kaname.
//
// Категория = первый тег задачи (#tag). Цвет — детерминированный,
// не зависит от темы, не меняется при смене темы (design-tokens.json §categories).
// Точка 10dp или тонкий чип — единственный способ показа цвета категории.
//
// Хеш-функция: FNV-1a 32-bit.
//   1. Тег приводится к нижнему регистру и обрезается.
//   2. Каждый байт (codeUnit) обрабатывается через XOR + умножение на простое.
//   3. Результат берётся по модулю 8.
//
// Свойства:
//   • Детерминированный: один и тот же тег → всегда один и тот же цвет.
//   • Стабильный: не зависит от версии Dart (не используется Object.hashCode).
//   • Равномерный: FNV-1a хорошо распределяет короткие строки по 8 корзинам.

import 'package:flutter/painting.dart';

// ---------------------------------------------------------------------------
// Палитра (фиксированная, 8 цветов, из design-tokens.json §categories)
// ---------------------------------------------------------------------------

/// Фиксированная палитра из 8 цветов категорий.
///
/// Порядок: blue, green, amber, coral, rose, violet, teal, gray.
/// Цвета НЕ зависят от темы и одинаковы в светлой и тёмной теме.
const List<Color> kCategoryPalette = [
  Color(0xFF378ADD), // blue   — #378ADD
  Color(0xFF639922), // green  — #639922
  Color(0xFFBA7517), // amber  — #BA7517
  Color(0xFFD85A30), // coral  — #D85A30
  Color(0xFFD4537E), // rose   — #D4537E
  Color(0xFF7F77DD), // violet — #7F77DD
  Color(0xFF1D9E75), // teal   — #1D9E75
  Color(0xFF888780), // gray   — #888780 (также нейтральный fallback)
];

/// Индекс серого в палитре — используется как нейтральный fallback.
const int _kGrayIndex = 7;

// ---------------------------------------------------------------------------
// Публичный API
// ---------------------------------------------------------------------------

/// Возвращает цвет категории для тега [tag].
///
/// • Маппинг детерминированный и стабильный: один тег → один цвет всегда.
/// • Пустой тег → нейтральный серый (kCategoryPalette[7]).
/// • Регистр и пробелы игнорируются (lowercased + trim).
Color categoryColorFor(String tag) {
  final key = tag.trim().toLowerCase();
  if (key.isEmpty) return kCategoryPalette[_kGrayIndex];
  return kCategoryPalette[_fnv1a32(key) % kCategoryPalette.length];
}

/// Возвращает цвет категории или `null`, если тег пуст или равен `null`.
///
/// Используйте, когда отсутствие тега означает «не показывать точку вообще».
Color? categoryColorForOrNull(String? tag) {
  if (tag == null) return null;
  final key = tag.trim().toLowerCase();
  if (key.isEmpty) return null;
  return kCategoryPalette[_fnv1a32(key) % kCategoryPalette.length];
}

// ---------------------------------------------------------------------------
// Хеш-функция (внутренняя)
// ---------------------------------------------------------------------------

/// FNV-1a 32-bit хеш строки.
///
/// Алгоритм:
///   hash = 2166136261 (FNV offset basis)
///   для каждого codeUnit:
///     hash = (hash XOR codeUnit) * 16777619 (FNV prime), маска 32 бита
///
/// Результат всегда неотрицателен и стабилен между запусками.
int _fnv1a32(String s) {
  // FNV offset basis (32-bit): 2166136261
  var hash = 2166136261;
  for (final unit in s.codeUnits) {
    hash ^= unit;
    // Умножаем на FNV prime (16777619) и маскируем до 32 бит.
    // Dart работает с 64-bit int, поэтому маска обязательна для консистентности.
    hash = (hash * 16777619) & 0xFFFFFFFF;
  }
  return hash;
}
