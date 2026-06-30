// Тесты фильтр-панели Plan (B6):
//   (а) planFilterMatches — чистая функция, юнит-тесты:
//       * пустые фильтры пропускают всё;
//       * фильтр приоритета / статуса / типа;
//       * AND-семантика (priority+status, priority+type, все три);
//       * anti-regression: planSearchMatches по-прежнему работает.
//   (б) PlanFilterSheet — виджет-тест:
//       * рендерится без overflow при 320px + textScale 2.0;
//       * рендерится без overflow при 360px + textScale 1.5;
//       * по умолчанию активных фильтров нет (PlanFilters.isEmpty == true).

import 'package:app/core/database/database.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/plan/plan_screen.dart' show PlanFilterSheet;
import 'package:app/features/plan/widgets/plan_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Фабрика ItemsTableData для тестов
// ---------------------------------------------------------------------------

/// Создаёт минимальный ItemsTableData с указанными полями.
ItemsTableData _item({
  String id = 'i1',
  String title = 'Task',
  String type = 'task',
  String priority = 'medium',
  String status = 'pending',
  String? tags,
}) {
  return ItemsTableData(
    id: id,
    userId: 'local',
    title: title,
    type: type,
    priority: priority,
    status: status,
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

// ---------------------------------------------------------------------------
// Тема для виджет-тестов
// ---------------------------------------------------------------------------

ThemeData _testTheme() => ThemeData.dark().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF9E9070),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFF3A3020),
          surfaceElevated: Color(0xFF2E2618),
          textFaint: Color(0xFF736850),
          accentMuted: Color(0xFF26290F),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFF524630),
        ),
      ],
    );

/// Обёртка для виджет-тестов PlanFilterSheet.
Widget _wrap(
  Widget child, {
  Size size = const Size(360, 800),
  double textScale = 1.0,
}) {
  return ProviderScope(
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: _testTheme(),
        home: Scaffold(body: child),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  // ==========================================================================
  // (а) planFilterMatches — юнит-тесты чистой функции
  // ==========================================================================

  group('planFilterMatches — пустые фильтры', () {
    test('const PlanFilters() пропускает любой item', () {
      expect(planFilterMatches(_item(), const PlanFilters()), isTrue);
    });

    test('пустые фильтры пропускают exam/main/done', () {
      expect(
        planFilterMatches(
          _item(type: 'exam', priority: 'main', status: 'done'),
          const PlanFilters(),
        ),
        isTrue,
      );
    });

    test('isEmpty == true для дефолтного PlanFilters', () {
      expect(const PlanFilters().isEmpty, isTrue);
    });

    test('activeCount == 0 для дефолтного PlanFilters', () {
      expect(const PlanFilters().activeCount, 0);
    });
  });

  group('planFilterMatches — фильтр по приоритету', () {
    test('priority=main проходит, если выбран только main', () {
      expect(
        planFilterMatches(
          _item(priority: 'main'),
          const PlanFilters(priorities: {'main'}),
        ),
        isTrue,
      );
    });

    test('priority=low НЕ проходит, если выбран только main', () {
      expect(
        planFilterMatches(
          _item(priority: 'low'),
          const PlanFilters(priorities: {'main'}),
        ),
        isFalse,
      );
    });

    test('priority=high проходит, если выбраны high+medium', () {
      expect(
        planFilterMatches(
          _item(priority: 'high'),
          const PlanFilters(priorities: {'high', 'medium'}),
        ),
        isTrue,
      );
    });

    test('priority=low НЕ проходит, если выбраны high+medium', () {
      expect(
        planFilterMatches(
          _item(priority: 'low'),
          const PlanFilters(priorities: {'high', 'medium'}),
        ),
        isFalse,
      );
    });

    test('activeCount = 2 при двух выбранных приоритетах', () {
      expect(
        const PlanFilters(priorities: {'high', 'medium'}).activeCount,
        2,
      );
    });
  });

  group('planFilterMatches — фильтр по статусу', () {
    test('status=done проходит, если выбран done', () {
      expect(
        planFilterMatches(
          _item(status: 'done'),
          const PlanFilters(statuses: {'done'}),
        ),
        isTrue,
      );
    });

    test('status=pending НЕ проходит, если выбран done', () {
      expect(
        planFilterMatches(
          _item(status: 'pending'),
          const PlanFilters(statuses: {'done'}),
        ),
        isFalse,
      );
    });

    test('status=skipped проходит, если выбраны done+skipped', () {
      expect(
        planFilterMatches(
          _item(status: 'skipped'),
          const PlanFilters(statuses: {'done', 'skipped'}),
        ),
        isTrue,
      );
    });

    test('status=pending НЕ проходит, если выбраны done+skipped', () {
      expect(
        planFilterMatches(
          _item(status: 'pending'),
          const PlanFilters(statuses: {'done', 'skipped'}),
        ),
        isFalse,
      );
    });
  });

  group('planFilterMatches — фильтр по типу', () {
    test('type=exam проходит, если выбран exam', () {
      expect(
        planFilterMatches(
          _item(type: 'exam'),
          const PlanFilters(types: {'exam'}),
        ),
        isTrue,
      );
    });

    test('type=task НЕ проходит, если выбран exam', () {
      expect(
        planFilterMatches(
          _item(type: 'task'),
          const PlanFilters(types: {'exam'}),
        ),
        isFalse,
      );
    });

    test('type=event проходит, если выбраны event+deadline', () {
      expect(
        planFilterMatches(
          _item(type: 'event'),
          const PlanFilters(types: {'event', 'deadline'}),
        ),
        isTrue,
      );
    });

    test('type=task НЕ проходит, если выбраны event+deadline', () {
      expect(
        planFilterMatches(
          _item(type: 'task'),
          const PlanFilters(types: {'event', 'deadline'}),
        ),
        isFalse,
      );
    });
  });

  group('planFilterMatches — AND-семантика (несколько групп)', () {
    test('priority=main AND status=done: проходит item с обоими полями', () {
      expect(
        planFilterMatches(
          _item(priority: 'main', status: 'done'),
          const PlanFilters(priorities: {'main'}, statuses: {'done'}),
        ),
        isTrue,
      );
    });

    test('priority=main AND status=done: НЕ проходит если status=pending', () {
      expect(
        planFilterMatches(
          _item(priority: 'main', status: 'pending'),
          const PlanFilters(priorities: {'main'}, statuses: {'done'}),
        ),
        isFalse,
      );
    });

    test('priority=main AND status=done: НЕ проходит если priority=high', () {
      expect(
        planFilterMatches(
          _item(priority: 'high', status: 'done'),
          const PlanFilters(priorities: {'main'}, statuses: {'done'}),
        ),
        isFalse,
      );
    });

    test('priority AND type: проходит только при совпадении обоих', () {
      expect(
        planFilterMatches(
          _item(priority: 'high', type: 'exam'),
          const PlanFilters(priorities: {'high'}, types: {'exam'}),
        ),
        isTrue,
      );
      expect(
        planFilterMatches(
          _item(priority: 'low', type: 'exam'),
          const PlanFilters(priorities: {'high'}, types: {'exam'}),
        ),
        isFalse,
      );
      expect(
        planFilterMatches(
          _item(priority: 'high', type: 'task'),
          const PlanFilters(priorities: {'high'}, types: {'exam'}),
        ),
        isFalse,
      );
    });

    test('все три группы: проходит при полном совпадении', () {
      final f = const PlanFilters(
        priorities: {'main'},
        statuses: {'pending'},
        types: {'task'},
      );
      expect(
        planFilterMatches(_item(priority: 'main', status: 'pending', type: 'task'), f),
        isTrue,
      );
      // Один промах — не проходит
      expect(
        planFilterMatches(_item(priority: 'main', status: 'done', type: 'task'), f),
        isFalse,
      );
      expect(
        planFilterMatches(_item(priority: 'high', status: 'pending', type: 'task'), f),
        isFalse,
      );
      expect(
        planFilterMatches(_item(priority: 'main', status: 'pending', type: 'event'), f),
        isFalse,
      );
    });

    test('activeCount суммирует все группы', () {
      const f = PlanFilters(
        priorities: {'main', 'high'},
        statuses: {'done'},
        types: {'exam', 'deadline', 'task'},
      );
      expect(f.activeCount, 6);
    });
  });

  group('planFilterMatches — PlanFilters equality', () {
    test('одинаковые множества → равны', () {
      const a = PlanFilters(priorities: {'main', 'high'});
      const b = PlanFilters(priorities: {'high', 'main'});
      expect(a, equals(b));
    });

    test('разные множества → не равны', () {
      const a = PlanFilters(priorities: {'main'});
      const b = PlanFilters(priorities: {'high'});
      expect(a, isNot(equals(b)));
    });
  });

  group('planFilterMatches — anti-regression: planSearchMatches не сломан', () {
    test('пустой запрос по-прежнему совпадает со всем', () {
      expect(planSearchMatches(_item(title: 'Anything'), ''), isTrue);
    });

    test('подстрока title работает', () {
      expect(planSearchMatches(_item(title: 'Algebra'), 'alg'), isTrue);
      expect(planSearchMatches(_item(title: 'Algebra'), 'physics'), isFalse);
    });

    test('type:exam работает', () {
      expect(planSearchMatches(_item(type: 'exam'), 'type:exam'), isTrue);
      expect(planSearchMatches(_item(type: 'task'), 'type:exam'), isFalse);
    });
  });

  // ==========================================================================
  // (б) PlanFilterSheet — виджет-тесты (overflow + дефолт)
  // ==========================================================================

  group('PlanFilterSheet — overflow-гейт', () {
    testWidgets('320px + textScale 2.0: нет RenderFlex overflow',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _wrap(
          const PlanFilterSheet(),
          size: const Size(320, 600),
          textScale: 2.0,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'Overflow при 320px + textScale 2.0');
    });

    testWidgets('360px + textScale 1.5: нет RenderFlex overflow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PlanFilterSheet(),
          size: const Size(360, 800),
          textScale: 1.5,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull,
          reason: 'Overflow при 360px + textScale 1.5');
    });

    testWidgets('обычный размер 390px: нет RenderFlex overflow',
        (tester) async {
      await tester.pumpWidget(
        _wrap(const PlanFilterSheet()),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('PlanFilterSheet — дефолтное состояние', () {
    testWidgets('нет активных фильтров по умолчанию', (tester) async {
      await tester.pumpWidget(_wrap(const PlanFilterSheet()));
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PlanFilterSheet)),
      );
      final filters = container.read(planFiltersProvider);
      expect(filters.isEmpty, isTrue,
          reason: 'По умолчанию фильтры должны быть пустыми');
      expect(filters.activeCount, 0);
    });

    testWidgets('чип «main» появляется на экране', (tester) async {
      await tester.pumpWidget(_wrap(const PlanFilterSheet()));
      await tester.pump();

      // Строки через fallback l10n: en = 'main'
      expect(find.textContaining('main'), findsWidgets);
    });
  });
}
