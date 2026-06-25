// Юнит-тесты чистой функции planSearchMatches (фильтр поиска на экране Plan).
// Покрываем: подстрока заголовка, #хэштег — поле tags (v18) + fallback на
// заголовок, type:exam и голое «exam», комбинацию #math type:exam
// (AND-семантика), пустой запрос (совпадает со всем), регистронезависимость.

import 'package:app/core/database/database.dart';
import 'package:app/features/plan/widgets/plan_providers.dart';
import 'package:flutter_test/flutter_test.dart';

/// Минимальная фабрика item для теста фильтра (поля как в ItemsTableData).
/// [tags] — comma-joined строка тегов в нижнем регистре (поле schemaVersion 18),
/// или null (задача до v18 / без тегов → fallback на заголовок).
ItemsTableData makeItem({
  String title = 'T',
  String type = 'task',
  String? tags,
}) {
  return ItemsTableData(
    id: 'i1',
    userId: 'local',
    title: title,
    type: type,
    priority: 'medium',
    status: 'pending',
    scheduledAt: DateTime(2026, 6, 22, 10),
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: null,
    moduleLink: null,
    color: null,
    tags: tags,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  group('planSearchMatches — пустой запрос', () {
    test('пустая строка совпадает со всем', () {
      expect(planSearchMatches(makeItem(title: 'Anything'), ''), isTrue);
    });
    test('только пробелы совпадают со всем', () {
      expect(planSearchMatches(makeItem(title: 'Anything'), '   '), isTrue);
    });
  });

  group('planSearchMatches — подстрока заголовка', () {
    test('подстрока совпадает', () {
      expect(planSearchMatches(makeItem(title: 'Algebra lecture'), 'lecture'),
          isTrue);
    });
    test('отсутствующая подстрока не совпадает', () {
      expect(planSearchMatches(makeItem(title: 'Algebra lecture'), 'physics'),
          isFalse);
    });
    test('регистронезависимость', () {
      expect(planSearchMatches(makeItem(title: 'Algebra Lecture'), 'LECTURE'),
          isTrue);
      expect(planSearchMatches(makeItem(title: 'ALGEBRA'), 'algebra'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // #хэштег: ищем в поле tags (schemaVersion 18), если оно заполнено
  // ---------------------------------------------------------------------------
  group('planSearchMatches — #тег через поле tags (v18)', () {
    test('#math совпадает с item у которого tags="math"', () {
      expect(
        planSearchMatches(makeItem(title: 'Homework', tags: 'math'), '#math'),
        isTrue,
      );
    });

    test('#math не совпадает, если тег отсутствует в tags', () {
      expect(
        planSearchMatches(
            makeItem(title: 'Homework', tags: 'physics'), '#math'),
        isFalse,
      );
    });

    test('теги регистронезависимы (tags хранятся в нижнем регистре)', () {
      // tags всегда lowercase при сохранении → запрос #MATH → 'math' → совпадение
      expect(
        planSearchMatches(makeItem(title: 'Lab', tags: 'math'), '#MATH'),
        isTrue,
      );
    });

    test('multiple tags: #urgent совпадает если тег в списке', () {
      // tags = "shopping,urgent"
      expect(
        planSearchMatches(
            makeItem(title: 'Buy', tags: 'shopping,urgent'), '#urgent'),
        isTrue,
      );
    });

    test('multiple tags: #absent не совпадает', () {
      expect(
        planSearchMatches(
            makeItem(title: 'Buy', tags: 'shopping,urgent'), '#absent'),
        isFalse,
      );
    });

    test('Кириллический тег совпадает', () {
      expect(
        planSearchMatches(
            makeItem(title: 'Задание', tags: 'учёба'), '#учёба'),
        isTrue,
      );
    });

    test('пустая строка tags → не совпадает (нет тегов)', () {
      expect(
        planSearchMatches(makeItem(title: 'Task', tags: ''), '#math'),
        isFalse,
      );
    });

    test('tags=null (задача до v18) → fallback: ищем в заголовке', () {
      // Обратная совместимость: старые задачи без tags
      expect(
        planSearchMatches(
            makeItem(title: 'Homework #math today', tags: null), '#math'),
        isTrue,
      );
    });

    test(
        'tags=null fallback: #math НЕ совпадает с #mathematics (граница слова)',
        () {
      expect(
        planSearchMatches(
            makeItem(title: 'Read #mathematics book', tags: null), '#math'),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Прежние тесты #хэштег по заголовку — сохраняем для регрессии
  // (теперь используют fallback-ветку: tags=null)
  // ---------------------------------------------------------------------------
  group('planSearchMatches — #хэштег через заголовок (fallback, без tags)', () {
    test('#math совпадает с заголовком, содержащим #math', () {
      expect(
        planSearchMatches(makeItem(title: 'Homework #math today'), '#math'),
        isTrue,
      );
    });
    test('#math НЕ совпадает с #mathematics (граница слова)', () {
      expect(
        planSearchMatches(makeItem(title: 'Read #mathematics book'), '#math'),
        isFalse,
      );
    });
    test('#хэштег регистронезависим', () {
      expect(
        planSearchMatches(makeItem(title: 'Lab #Math'), '#math'),
        isTrue,
      );
    });
    test('хэштег отсутствует — не совпадает', () {
      expect(
        planSearchMatches(makeItem(title: 'Plain title'), '#math'),
        isFalse,
      );
    });
  });

  group('planSearchMatches — фильтр по типу', () {
    test('type:exam совпадает с exam-элементом', () {
      expect(planSearchMatches(makeItem(type: 'exam'), 'type:exam'), isTrue);
    });
    test('type:exam не совпадает с task-элементом', () {
      expect(planSearchMatches(makeItem(type: 'task'), 'type:exam'), isFalse);
    });
    test('голое слово exam совпадает с exam-элементом', () {
      expect(planSearchMatches(makeItem(type: 'exam'), 'exam'), isTrue);
    });
    test('голое слово exam не совпадает с task-элементом', () {
      expect(planSearchMatches(makeItem(type: 'task'), 'exam'), isFalse);
    });
    test('тип регистронезависим', () {
      expect(planSearchMatches(makeItem(type: 'exam'), 'TYPE:EXAM'), isTrue);
      expect(planSearchMatches(makeItem(type: 'exam'), 'EXAM'), isTrue);
    });
  });

  group('planSearchMatches — комбинация токенов (AND)', () {
    test('#math type:exam совпадает только когда оба условия истинны', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Final #math', type: 'exam', tags: 'math'),
          '#math type:exam',
        ),
        isTrue,
      );
    });
    test('#math type:exam не совпадает, если тип не exam', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Final #math', type: 'task', tags: 'math'),
          '#math type:exam',
        ),
        isFalse,
      );
    });
    test('#math type:exam не совпадает, если хэштега нет', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Final review', type: 'exam', tags: null),
          '#math type:exam',
        ),
        isFalse,
      );
    });
    test('подстрока + тип вместе', () {
      expect(
        planSearchMatches(
          makeItem(title: 'Algebra final', type: 'exam'),
          'algebra exam',
        ),
        isTrue,
      );
      expect(
        planSearchMatches(
          makeItem(title: 'Algebra final', type: 'task'),
          'algebra exam',
        ),
        isFalse,
      );
    });

    test('tags + plain text вместе (AND)', () {
      // #work + "report" — оба должны совпасть
      expect(
        planSearchMatches(
          makeItem(title: 'Write report', tags: 'work'),
          '#work report',
        ),
        isTrue,
      );
      expect(
        planSearchMatches(
          makeItem(title: 'Write report', tags: 'work'),
          '#work physics',
        ),
        isFalse,
      );
    });
  });
}
