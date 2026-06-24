// Юнит-тесты для tag_parser.dart.
// Запустить только этот файл:
//   flutter test test/tag_parser_test.dart
//
// Контракт parseTaskTags:
//   • Принимает raw title (может содержать #tag-токены).
//   • Возвращает TagParseResult { cleanTitle, tags }:
//       – cleanTitle: заголовок без #tag-токенов, лишние пробелы схлопнуты, trim.
//       – tags: дедуплицированный список тегов (без #), в порядке первого появления.
//
// Что считается тегом:
//   • #<1+ букв/цифр/подчёркиваний> с хотя бы одной буквой
//     (латинской ИЛИ кириллической) — иначе не тег.
//   • Пример: #cs101 — тег (есть буквы); #123 — НЕ тег (только цифры).
//   • Пример: # (одиночный) — НЕ тег.
//   • Пунктуация-разделитель: #math. и (#work) — тег берётся до следующего
//     небуквенного-нецифрового-не_подчёркивания символа.
//
// Регистр:
//   • Теги СОХРАНЯЮТ регистр из ввода (#CS101 → тег "CS101"); дедупликация
//     ЧУВСТВИТЕЛЬНА к регистру (#Math и #math — разные теги).
//
// Граница слова (левая):
//   • #tag должен стоять на левой границе слова (начало строки, пробел,
//     пунктуация) — "prefix#tag" НЕ является тегом.

import 'package:app/core/utils/tag_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // --------------------------------------------------------------------------
  // Вспомогательная функция — короткая форма
  TagParseResult parse(String s) => parseTaskTags(s);

  group('No tags', () {
    test('empty string returns empty clean title and no tags', () {
      final r = parse('');
      expect(r.cleanTitle, '');
      expect(r.tags, isEmpty);
    });

    test('plain title with no hash returns title unchanged', () {
      final r = parse('Buy groceries');
      expect(r.cleanTitle, 'Buy groceries');
      expect(r.tags, isEmpty);
    });

    test('Cyrillic title with no hash returns title unchanged', () {
      final r = parse('Сдать лабораторную работу');
      expect(r.cleanTitle, 'Сдать лабораторную работу');
      expect(r.tags, isEmpty);
    });

    test('solo hash (#) is not a tag', () {
      final r = parse('important # things');
      expect(r.cleanTitle, 'important # things');
      expect(r.tags, isEmpty);
    });

    test('# followed by only digits is not a tag (#123)', () {
      final r = parse('task #123 done');
      expect(r.cleanTitle, 'task #123 done');
      expect(r.tags, isEmpty);
    });

    test('# followed by only underscores is not a tag (#__)', () {
      final r = parse('item #__ here');
      expect(r.cleanTitle, 'item #__ here');
      expect(r.tags, isEmpty);
    });

    test('hash embedded inside a word (prefix#tag) is not a tag', () {
      // нет левой границы слова перед #
      final r = parse('prefix#work item');
      expect(r.cleanTitle, 'prefix#work item');
      expect(r.tags, isEmpty);
    });
  });

  group('Single tag', () {
    test('tag at the end of title', () {
      final r = parse('Buy groceries #shopping');
      expect(r.cleanTitle, 'Buy groceries');
      expect(r.tags, ['shopping']);
    });

    test('tag at the beginning of title', () {
      final r = parse('#work Do the report');
      expect(r.cleanTitle, 'Do the report');
      expect(r.tags, ['work']);
    });

    test('tag in the middle of title', () {
      final r = parse('Do #work the report');
      expect(r.cleanTitle, 'Do the report');
      expect(r.tags, ['work']);
    });

    test('tag is the only content', () {
      final r = parse('#study');
      expect(r.cleanTitle, '');
      expect(r.tags, ['study']);
    });

    test('Cyrillic tag #учёба', () {
      final r = parse('Сдать реферат #учёба');
      expect(r.cleanTitle, 'Сдать реферат');
      expect(r.tags, ['учёба']);
    });

    test('alphanumeric tag with digits #cs101', () {
      final r = parse('Study for #cs101 exam');
      expect(r.cleanTitle, 'Study for exam');
      expect(r.tags, ['cs101']);
    });

    test('tag with underscore #my_project', () {
      final r = parse('Work on #my_project');
      expect(r.cleanTitle, 'Work on');
      expect(r.tags, ['my_project']);
    });

    test('Cyrillic digits-mixed tag #алг2', () {
      final r = parse('Подготовка к #алг2');
      expect(r.cleanTitle, 'Подготовка к');
      expect(r.tags, ['алг2']);
    });
  });

  group('Multiple tags', () {
    test('two tags at the end', () {
      final r = parse('Write report #work #urgent');
      expect(r.cleanTitle, 'Write report');
      expect(r.tags, ['work', 'urgent']);
    });

    test('tags at start, middle, end', () {
      final r = parse('#priority Buy #shopping milk #today');
      expect(r.cleanTitle, 'Buy milk');
      expect(r.tags, ['priority', 'shopping', 'today']);
    });

    test('multiple Cyrillic tags', () {
      final r = parse('Задача #учёба #важное сдать');
      expect(r.cleanTitle, 'Задача сдать');
      expect(r.tags, ['учёба', 'важное']);
    });

    test('mixed Latin and Cyrillic tags', () {
      final r = parse('Exam prep #cs101 #учёба');
      expect(r.cleanTitle, 'Exam prep');
      expect(r.tags, ['cs101', 'учёба']);
    });
  });

  group('Duplicate tags (deduplication)', () {
    test('exact duplicate tags are deduped, first occurrence kept', () {
      final r = parse('Buy milk #shopping buy eggs #shopping');
      expect(r.cleanTitle, 'Buy milk buy eggs');
      expect(r.tags, ['shopping']);
    });

    test('three of the same tag → one in result', () {
      final r = parse('#work task #work another #work');
      expect(r.cleanTitle, 'task another');
      expect(r.tags, ['work']);
    });

    test('case-sensitive dedup: #Math and #math are distinct tags', () {
      final r = parse('Study #Math and #math more');
      expect(r.cleanTitle, 'Study and more');
      expect(r.tags, ['Math', 'math']); // both kept (different case)
    });
  });

  group('Punctuation boundaries', () {
    test('#math. (period after tag) — tag extracted, period stays in text', () {
      // Период — не часть тега. Тег = "math", текст теряет #math. и остаётся с ".".
      // Точнее: #math. — удаляем #math, точка примыкает к пробелу/концу → trim.
      final r = parse('Study #math. tonight');
      expect(r.tags, ['math']);
      // cleanTitle: "Study . tonight" → после схлопывания "Study . tonight"
      // (мы не удаляем знаки препинания — только тег-токен)
      expect(r.cleanTitle, 'Study . tonight');
    });

    test('(#work) — parens around tag, tag extracted', () {
      final r = parse('Do this (#work) now');
      expect(r.tags, ['work']);
      // '(' и ')' остаются, между ними пусто → "Do this () now"
      expect(r.cleanTitle, 'Do this () now');
    });

    test('#tag, with comma after — tag extracted', () {
      final r = parse('Task #study, go home');
      expect(r.tags, ['study']);
      expect(r.cleanTitle, 'Task , go home');
    });

    test('tag after opening paren is still extracted (paren = boundary)', () {
      final r = parse('task (#urgent action)');
      expect(r.tags, ['urgent']);
      expect(r.cleanTitle, 'task ( action)');
    });
  });

  group('Whitespace cleanup', () {
    test('double spaces from tag removal are collapsed to single space', () {
      final r = parse('Do #work the thing');
      expect(r.cleanTitle, 'Do the thing');
      // No double spaces
      expect(r.cleanTitle.contains('  '), isFalse);
    });

    test('tag at beginning leaves no leading space', () {
      final r = parse('#priority Do the work');
      expect(r.cleanTitle, isNot(startsWith(' ')));
      expect(r.cleanTitle, 'Do the work');
    });

    test('tag at end leaves no trailing space', () {
      final r = parse('Do the work #priority');
      expect(r.cleanTitle, isNot(endsWith(' ')));
      expect(r.cleanTitle, 'Do the work');
    });

    test('multiple adjacent tags collapse middle spaces correctly', () {
      final r = parse('Task #a #b #c done');
      expect(r.cleanTitle, 'Task done');
      expect(r.cleanTitle.contains('  '), isFalse);
    });

    test('only tags → cleanTitle is empty string (not spaces)', () {
      final r = parse('#a #b #c');
      expect(r.cleanTitle, '');
      expect(r.tags, ['a', 'b', 'c']);
    });
  });

  group('Case sensitivity', () {
    test('tag preserves original case', () {
      final r = parse('Task #CS101 study');
      expect(r.tags, ['CS101']);
    });

    test('Uppercase-only tag preserved', () {
      final r = parse('meeting #URGENT');
      expect(r.tags, ['URGENT']);
    });

    test('Mixed-case tag preserved', () {
      final r = parse('work #MyTag item');
      expect(r.tags, ['MyTag']);
    });
  });

  group('Edge cases', () {
    test('title is just spaces → cleanTitle is empty, no tags', () {
      final r = parse('   ');
      expect(r.cleanTitle, '');
      expect(r.tags, isEmpty);
    });

    test('## double-hash is not a tag (# is not a letter/digit)', () {
      // ##word: first # not followed by letter/digit/underscore immediately
      // (second # is not a valid tag char)
      final r = parse('task ##note here');
      expect(r.tags, isEmpty);
      expect(r.cleanTitle, 'task ##note here');
    });

    test('numeric-only hash #42 is not a tag', () {
      final r = parse('issue #42');
      expect(r.tags, isEmpty);
      expect(r.cleanTitle, 'issue #42');
    });

    test('title with URL-like #anchor is not treated as tag if embedded', () {
      // "https://example.com#section" — the '#' has no left boundary
      final r = parse('See https://example.com#section for details');
      expect(r.tags, isEmpty);
    });

    test('long tag with underscores and digits', () {
      final r = parse('Review #project_alpha_2024 doc');
      expect(r.tags, ['project_alpha_2024']);
      expect(r.cleanTitle, 'Review doc');
    });

    test('tag with Cyrillic ё character', () {
      final r = parse('Готовиться #ёж exam');
      expect(r.tags, ['ёж']);
      expect(r.cleanTitle, 'Готовиться exam');
    });

    test('preserves order of first appearance for dedup', () {
      // #b appears first, then #a, then #b again
      final r = parse('do #b work #a and #b more');
      expect(r.tags, ['b', 'a']); // b first (first appearance), a second
    });

    test('title with only whitespace and tags collapses correctly', () {
      final r = parse('  #one  #two  ');
      expect(r.cleanTitle, '');
      expect(r.tags, ['one', 'two']);
    });
  });
}
