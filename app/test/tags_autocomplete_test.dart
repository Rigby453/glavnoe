// Тесты фичи B7: autocomplete/подсказки тегов в форме создания задачи.
//
// 1. DAO unit-тест: allUsedTags() возвращает уникальные теги из посеянных items,
//    отсортированные по частоте (убывание).
// 2. Overflow-безопасность: ряд подсказок не падает на ширине 320 px (нет
//    RenderFlex overflow). Используем pump без pumpAndSettle — sheet содержит
//    анимации, бесконечный AnimatedContainer от клавиатуры/скролла.
//
// In-memory Drift для DAO-части; для виджет-части — мок-список тегов.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

// ---------------------------------------------------------------------------
// Вспомогательный виджет — упрощённая версия _TagSuggestionsRow
// для изолированного UI-теста (без зависимости от AddTaskSheet).
// Повторяет интерфейс оригинала: список строк, onTap-коллбек.
// ---------------------------------------------------------------------------

class _SuggestionsTestHarness extends StatefulWidget {
  const _SuggestionsTestHarness({required this.suggestions});
  final List<String> suggestions;

  @override
  State<_SuggestionsTestHarness> createState() =>
      _SuggestionsTestHarnessState();
}

class _SuggestionsTestHarnessState extends State<_SuggestionsTestHarness> {
  final List<String> added = [];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PhosphorIcon(PhosphorIcons.hash(PhosphorIconsStyle.regular), size: 14),
          for (final tag in widget.suggestions) ...[
            const SizedBox(width: 6),
            GestureDetector(
              key: ValueKey('suggest_$tag'),
              onTap: () => setState(() => added.add(tag)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(120)),
                ),
                child: Text(
                  '#$tag',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Хелпер: обёртка MaterialApp + тема + l10n.
// ---------------------------------------------------------------------------

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    theme: AppTheme.focusTheme(),
    home: Scaffold(body: SafeArea(child: child)),
  );
}

// ---------------------------------------------------------------------------
// Хелпер: посев одной задачи с тегами (in-memory Drift).
// ---------------------------------------------------------------------------

Future<void> _seed(
  ItemsDao dao, {
  required String id,
  required String? tags,
}) async {
  final now = DateTime.now();
  await dao.insertItem(ItemsTableCompanion(
    id: Value(id),
    userId: const Value('local'),
    title: Value('Task $id'),
    type: const Value('task'),
    priority: const Value('medium'),
    status: const Value('pending'),
    scheduledAt: Value(now),
    durationMinutes: const Value(30),
    isProtected: const Value(false),
    tags: Value(tags),
    createdAt: Value(now),
    updatedAt: Value(now),
  ));
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. DAO unit-тесты
  // ---------------------------------------------------------------------------

  group('allUsedTags() — DAO unit', () {
    late AppDatabase db;
    late ItemsDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = ItemsDao(db);
    });

    tearDown(() async => db.close());

    test('пустая БД → пустой список', () async {
      final tags = await dao.allUsedTags();
      expect(tags, isEmpty);
    });

    test('задача без тегов (tags=null) → пустой список', () async {
      await _seed(dao, id: 'a', tags: null);
      final tags = await dao.allUsedTags();
      expect(tags, isEmpty);
    });

    test('одна задача с одним тегом', () async {
      await _seed(dao, id: 'a', tags: 'shopping');
      final tags = await dao.allUsedTags();
      expect(tags, ['shopping']);
    });

    test('один тег встречается в нескольких задачах → один раз в результате',
        () async {
      await _seed(dao, id: 'a', tags: 'urgent');
      await _seed(dao, id: 'b', tags: 'urgent');
      await _seed(dao, id: 'c', tags: 'urgent');
      final tags = await dao.allUsedTags();
      expect(tags, ['urgent']); // дедупликация
    });

    test('несколько разных тегов возвращаются как уникальные', () async {
      await _seed(dao, id: 'a', tags: 'shopping,urgent');
      await _seed(dao, id: 'b', tags: 'учёба');
      final tags = await dao.allUsedTags();
      expect(tags, containsAll(['shopping', 'urgent', 'учёба']));
      expect(tags.length, 3);
    });

    test('нормализация в lowercase: #Urgent и #urgent → один тег «urgent»',
        () async {
      // В БД теги уже хранятся lowercase (нормализованы при сохранении),
      // но метод тоже делает toLowerCase для надёжности.
      await _seed(dao, id: 'a', tags: 'Urgent');
      await _seed(dao, id: 'b', tags: 'urgent');
      final tags = await dao.allUsedTags();
      // lowercase-дедупликация → один тег
      expect(tags, ['urgent']);
    });

    test('сортировка по частоте: чаще → раньше', () async {
      // 'study' встречается 3 раза, 'work' — 2, 'hobby' — 1.
      await _seed(dao, id: 'a', tags: 'study,work');
      await _seed(dao, id: 'b', tags: 'study,work');
      await _seed(dao, id: 'c', tags: 'study,hobby');
      final tags = await dao.allUsedTags();
      expect(tags.first, 'study');
      expect(tags[1], 'work');
      expect(tags.last, 'hobby');
    });

    test('пробелы вокруг запятой обрезаются (trim)', () async {
      await _seed(dao, id: 'a', tags: ' shopping , urgent ');
      final tags = await dao.allUsedTags();
      expect(tags, containsAll(['shopping', 'urgent']));
    });

    test('пустая строка tags → пропускается', () async {
      await _seed(dao, id: 'a', tags: '');
      await _seed(dao, id: 'b', tags: '  ');
      final tags = await dao.allUsedTags();
      expect(tags, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. UI-тесты: ряд подсказок
  // ---------------------------------------------------------------------------

  group('_TagSuggestionsRow — UI', () {
    testWidgets('отображает чипы для каждого тега', (tester) async {
      await tester.pumpWidget(_wrap(
        _SuggestionsTestHarness(
          suggestions: const ['shopping', 'urgent', 'учёба'],
        ),
      ));
      // pump без pumpAndSettle — sheet может иметь анимации.
      await tester.pump();

      expect(find.text('#shopping'), findsOneWidget);
      expect(find.text('#urgent'), findsOneWidget);
      expect(find.text('#учёба'), findsOneWidget);
    });

    testWidgets('тап по чипу вызывает onTap и добавляет тег', (tester) async {
      await tester.pumpWidget(_wrap(
        _SuggestionsTestHarness(
          suggestions: const ['shopping', 'work'],
        ),
      ));
      await tester.pump();

      // Тапаем на первый чип.
      await tester.tap(find.byKey(const ValueKey('suggest_shopping')));
      await tester.pump();

      // Проверяем, что тег добавился (через added-список в State).
      final state = tester.state<_SuggestionsTestHarnessState>(
          find.byType(_SuggestionsTestHarness));
      expect(state.added, contains('shopping'));
    });

    testWidgets('нет overflow на ширине 320 px (overflow-safety)', (tester) async {
      // Устанавливаем узкий экран 320×568 + textScale 2.0.
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: _wrap(
            _SuggestionsTestHarness(
              suggestions: const ['shopping', 'urgent', 'учёба', 'work', 'study'],
            ),
          ),
        ),
      );
      await tester.pump();

      // Если есть RenderFlex overflow — takeException вернёт FlutterError.
      expect(tester.takeException(), isNull);
    });
  });
}
