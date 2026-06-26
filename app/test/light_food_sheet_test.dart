// Виджет-тесты лёгкой шторки еды (light_food_sheet.dart).
//
// Проверяем:
// 1. Шторка показывает название приёма пищи (локализованный слот).
// 2. Существующие записи в слоте — только имя блюда, БЕЗ ккал/КБЖУ/граммов.
// 3. Записи другого слота не отображаются.
// 4. После ввода имени и нажатия [+] — запись сохраняется в БД.
//
// БД — in-memory Drift (AppDatabase.forTesting).
// API не тестируем: поиск требует сети; тест фокусируется на DAO + UI-инварианте.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/core/utils/id.dart';
import 'package:app/features/food/light_food_sheet.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема (без GoogleFonts, с FocusThemeExtension)
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

// ---------------------------------------------------------------------------
// Тестовый стенд
// ---------------------------------------------------------------------------
Widget _harness(AppDatabase db, SharedPreferences prefs, Widget child) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: MaterialApp(
      theme: _testTheme(),
      home: Scaffold(body: child),
    ),
  );
}

/// Вставить запись еды напрямую в БД (минуя UI).
Future<void> _insertLog(
  AppDatabase db, {
  required String meal,
  required String name,
  DateTime? date,
}) async {
  final day = date ?? DateTime.utc(2026, 1, 1);
  await db.into(db.foodLogsTable).insert(
        FoodLogsTableCompanion(
          id: Value(uuidV4()),
          date: Value(day),
          meal: Value(meal),
          name: Value(name),
          grams: const Value(100.0),
          createdAt: Value(DateTime.now()),
        ),
      );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------
void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  // Drift закрывает стримы и оставляет zero-duration таймер.
  // Размонтируем дерево, чтобы таймер сработал внутри теста.
  Future<void> flush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  testWidgets('шторка показывает заголовок слота и пустое состояние',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showLightFoodSheet(
                ctx,
                mealSlot: 'breakfast',
                day: DateTime.utc(2026, 1, 1),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();

      // Открываем шторку
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Заголовок — локализованное название слота (EN: 'breakfast' → 'Breakfast')
      expect(find.textContaining('Breakfast'), findsOneWidget);

      // Пустое состояние: ни одной записи нет
      expect(find.textContaining('Nothing here yet'), findsOneWidget);
    });
    await flush(tester);
  });

  testWidgets(
      'записи слота отображаются только по имени — без ккал/КБЖУ/граммов',
      (tester) async {
    await tester.runAsync(() async {
      await _insertLog(db, meal: 'breakfast', name: 'Banana');
      await _insertLog(db, meal: 'breakfast', name: 'Oatmeal');

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showLightFoodSheet(
                ctx,
                mealSlot: 'breakfast',
                day: DateTime.utc(2026, 1, 1),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Имена блюд видны (могут встречаться и в списке, и в чипах «Недавнее»)
      expect(find.textContaining('Banana'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Oatmeal'), findsAtLeastNWidgets(1));

      // Ни одного числового поля КБЖУ в UI:
      // - 'kcal' (калории) / 'кал'
      // - ' g ' (граммы EN) / ' г ' (граммы RU)
      // - 'protein' / 'белк'
      // - 'fat' / 'жир'
      // - 'carb' / 'углевод'
      final allText = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');

      expect(allText.toLowerCase(), isNot(contains('kcal')));
      expect(allText.toLowerCase(), isNot(contains('кал')));
      expect(allText.toLowerCase(), isNot(contains(' g ')));
      expect(allText.toLowerCase(), isNot(contains(' г ')));
      expect(allText.toLowerCase(), isNot(contains('protein')));
      expect(allText.toLowerCase(), isNot(contains('белк')));
      expect(allText.toLowerCase(), isNot(contains(' fat ')));
      expect(allText.toLowerCase(), isNot(contains('жир')));
      expect(allText.toLowerCase(), isNot(contains('carb')));
      expect(allText.toLowerCase(), isNot(contains('углевод')));
    });
    await flush(tester);
  });

  testWidgets('записи другого слота не попадают в список', (tester) async {
    await tester.runAsync(() async {
      await _insertLog(db, meal: 'lunch', name: 'Pizza');
      await _insertLog(db, meal: 'breakfast', name: 'Yogurt');

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showLightFoodSheet(
                ctx,
                mealSlot: 'breakfast',
                day: DateTime.utc(2026, 1, 1),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Yogurt (breakfast) — видно (в списке и/или в чипе «Недавнее»)
      expect(find.textContaining('Yogurt'), findsAtLeastNWidgets(1));
      // Pizza (lunch) — не должна попасть в секцию завтрака (список)
      // Но может быть в чипах «Недавнее» (они показывают все recent по DAO)
      // Проверяем только что Pizza не в ListTile-заголовке
      final listTileTitles = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(ListTile),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data ?? '')
          .toList();
      expect(listTileTitles, isNot(contains('Pizza')));
    });
    await flush(tester);
  });

  testWidgets(
      'поле ввода + кнопка [+] сохраняют запись в DAO (без КБЖУ)',
      (tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showLightFoodSheet(
                ctx,
                mealSlot: 'dinner',
                day: DateTime.utc(2026, 1, 1),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Вводим название
      await tester.enterText(find.byType(TextField), 'Soup');
      await tester.pump();

      // Нажимаем кнопку [+] (иконка add)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Запись должна появиться в списке
      expect(find.textContaining('Soup'), findsOneWidget);

      // Проверяем, что запись сохранена в БД
      final logs = await db.select(db.foodLogsTable).get();
      expect(logs, hasLength(1));
      expect(logs.first.name, 'Soup');
      expect(logs.first.meal, 'dinner');
      // КБЖУ = null (не заполняем в лёгком режиме)
      expect(logs.first.calories, isNull);
      expect(logs.first.protein, isNull);
      expect(logs.first.fat, isNull);
      expect(logs.first.carbs, isNull);
    });
    await flush(tester);
  });
}
