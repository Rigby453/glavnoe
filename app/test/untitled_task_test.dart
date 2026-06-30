// Юнит-тесты для фичи B1: сохранение задачи с пустым названием.
//
// Проверяем логику, зеркально воспроизводящую _save() в AddTaskSheet:
//   final storedTitle = buildStoredTitle(cleanTitle, tags);
//   final title = storedTitle.trim().isEmpty ? placeholder : storedTitle;
//
// Тесты не используют Flutter/Drift/Riverpod — только чистые функции.

import 'package:app/core/utils/tag_parser.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Зеркало логики выбора финального заголовка из _save() в AddTaskSheet.
// Вынесено в чистую функцию для тестируемости.
// ---------------------------------------------------------------------------

/// Воспроизводит выбор заголовка из _save():
///   buildStoredTitle + fallback на [placeholder] если пусто.
String resolveEffectiveTitle(
  String cleanTitle,
  List<String> tags,
  String placeholder,
) {
  final stored = buildStoredTitle(cleanTitle, tags);
  return stored.trim().isEmpty ? placeholder : stored;
}

// ---------------------------------------------------------------------------
// Константа плейсхолдера (EN — язык по умолчанию в тестах без контекста).
// ---------------------------------------------------------------------------
const _kPlaceholder = 'Untitled';

void main() {
  // ---------------------------------------------------------------------------
  // buildStoredTitle — контракт утилиты (не меняли, регрессия)
  // ---------------------------------------------------------------------------

  group('buildStoredTitle — контракт', () {
    test('пустой заголовок и нет тегов → пустая строка', () {
      expect(buildStoredTitle('', []), '');
    });

    test('пустой заголовок с тегами → только теги', () {
      expect(buildStoredTitle('', ['shopping']), '#shopping');
    });

    test('заголовок без тегов → заголовок без изменений', () {
      expect(buildStoredTitle('Buy milk', []), 'Buy milk');
    });

    test('заголовок с тегами → заголовок + теги через пробел', () {
      expect(
        buildStoredTitle('Buy milk', ['shopping', 'urgent']),
        'Buy milk #shopping #urgent',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // resolveEffectiveTitle — логика выбора плейсхолдера (фича B1)
  // ---------------------------------------------------------------------------

  group('resolveEffectiveTitle — фича B1', () {
    test('нет текста, нет тегов → плейсхолдер', () {
      final result = resolveEffectiveTitle('', [], _kPlaceholder);
      expect(result, _kPlaceholder);
    });

    test('пробельный текст, нет тегов → плейсхолдер', () {
      // trim() должен схлопнуть «  » в '' → плейсхолдер
      final result = resolveEffectiveTitle('   ', [], _kPlaceholder);
      expect(result, _kPlaceholder);
    });

    test('нет текста, есть теги → title из тегов (не плейсхолдер)', () {
      // buildStoredTitle('', ['shopping']) == '#shopping' — не пусто
      final result = resolveEffectiveTitle('', ['shopping'], _kPlaceholder);
      expect(result, '#shopping');
      expect(result, isNot(_kPlaceholder));
    });

    test('несколько тегов без текста → все теги (не плейсхолдер)', () {
      final result =
          resolveEffectiveTitle('', ['math', 'cs101'], _kPlaceholder);
      expect(result, '#math #cs101');
      expect(result, isNot(_kPlaceholder));
    });

    test('обычный заголовок без тегов → заголовок без изменений', () {
      final result = resolveEffectiveTitle('Buy milk', [], _kPlaceholder);
      expect(result, 'Buy milk');
      expect(result, isNot(_kPlaceholder));
    });

    test('заголовок с тегами → заголовок + теги (не плейсхолдер)', () {
      final result =
          resolveEffectiveTitle('Buy milk', ['shopping'], _kPlaceholder);
      expect(result, 'Buy milk #shopping');
      expect(result, isNot(_kPlaceholder));
    });

    test('русский заголовок → сохраняется без изменений', () {
      final result =
          resolveEffectiveTitle('Купить молоко', [], _kPlaceholder);
      expect(result, 'Купить молоко');
    });

    test('русские теги без текста → теги (не плейсхолдер)', () {
      final result =
          resolveEffectiveTitle('', ['учёба', 'срочно'], _kPlaceholder);
      expect(result, '#учёба #срочно');
      expect(result, isNot(_kPlaceholder));
    });
  });
}
