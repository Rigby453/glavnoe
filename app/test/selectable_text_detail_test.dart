// selectable_text_detail_test.dart
//
// B8 — SelectableText в TaskDetailCard.
//
// Проверяет:
//   1. SelectableText присутствует для заголовка задачи (findsWidgets).
//   2. Конкретный текст заголовка рендерится через SelectableText (byWidgetPredicate).
//   3. Нет RenderFlex overflow при 320px × 760 + textScale 2.0.
//   4. Поле location тоже рендерится через SelectableText при наличии значения.
//
// Паттерн: успешный pump без исключений = нет overflow.
// НЕ используем pumpAndSettle (зависание на Drift-стримах); вместо этого —
// _settle(), идентичный overflow_audit_test.dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/items_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/plan/widgets/task_detail_card.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — идентична overflow_audit_test.dart
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
// Утилиты — копия из overflow_audit_test.dart
// ---------------------------------------------------------------------------

Future<void> _setSize(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// Прокачивает виджет без pumpAndSettle:
///   pump() → runAsync(50ms) → pump(100ms) → pump(600ms).
/// Drift-стримы успевают эмиттить пустые данные; анимаций нет (disableAnimations).
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Размонтирует дерево и прокачивает 1 мс, чтобы Drift-таймеры
/// завершились внутри тела теста (иначе flutter_test ругается на pending timers).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
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

  /// Вставляет тестовую задачу в in-memory БД и возвращает объект данных.
  /// NativeDatabase.memory() — синхронный SQLite, работает без tester.runAsync.
  Future<ItemsTableData> insertItem({
    String id = 'item-b8',
    String title = 'Selectable title for B8 test',
    String? location,
  }) async {
    final now = DateTime(2026, 6, 30, 10, 0);
    final dao = ItemsDao(db);
    await dao.insertItem(ItemsTableCompanion(
      id: Value(id),
      userId: const Value('local'),
      title: Value(title),
      type: const Value('task'),
      priority: const Value('medium'),
      status: const Value('pending'),
      scheduledAt: Value(now),
      durationMinutes: const Value(60),
      isProtected: const Value(false),
      location: Value(location),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));
    return (await dao.getItemById(id))!;
  }

  /// Строит дерево для TaskDetailCard с нужными ProviderScope-overrides.
  /// disableAnimations: true предотвращает pending ImplicitAnimation-таймеры.
  Widget buildHarness(
    ItemsTableData item, {
    double textScale = 1.0,
    Size size = const Size(360, 760),
  }) {
    return ProviderScope(
      overrides: [
        // subtasksDaoProvider и itemAttachmentsDaoProvider зависят от
        // appDatabaseProvider — они автоматически используют тестовую БД.
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
      ],
      child: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(textScale),
          size: size,
          disableAnimations: true,
        ),
        child: MaterialApp(
          theme: _testTheme(),
          home: Scaffold(
            body: TaskDetailCard(item: item, day: item.scheduledAt),
          ),
        ),
      ),
    );
  }

  group('TaskDetailCard — B8 SelectableText', () {
    // -----------------------------------------------------------------------
    // 1. Заголовок задачи рендерится через SelectableText
    // -----------------------------------------------------------------------
    testWidgets('заголовок задачи рендерится через SelectableText', (tester) async {
      final item = await insertItem();
      await _setSize(tester, const Size(360, 760));
      await tester.pumpWidget(buildHarness(item));
      await _settle(tester);

      // findsWidgets: хотя бы один SelectableText в дереве
      expect(find.byType(SelectableText), findsWidgets);

      // Конкретный заголовок через byWidgetPredicate — SelectableText.data
      final titleSelectable = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'Selectable title for B8 test',
      );
      expect(titleSelectable, findsOneWidget);

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    // -----------------------------------------------------------------------
    // 2. Нет overflow при 320px, textScale 2.0
    // -----------------------------------------------------------------------
    testWidgets('нет overflow при 320px + textScale 2.0', (tester) async {
      final item = await insertItem(id: 'item-b8-narrow');
      await _setSize(tester, const Size(320, 760));
      await tester.pumpWidget(
        buildHarness(item, size: const Size(320, 760), textScale: 2.0),
      );
      await _settle(tester);
      // Успешный pump без исключений = нет RenderFlex overflow.
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    // -----------------------------------------------------------------------
    // 3. Нет overflow при 320px, textScale 1.0 (базовый)
    // -----------------------------------------------------------------------
    testWidgets('нет overflow при 320px + textScale 1.0', (tester) async {
      final item = await insertItem(id: 'item-b8-narrow2');
      await _setSize(tester, const Size(320, 760));
      await tester.pumpWidget(
        buildHarness(item, size: const Size(320, 760)),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    // -----------------------------------------------------------------------
    // 4. Поле location рендерится через SelectableText (_DetailRow.selectable)
    // -----------------------------------------------------------------------
    testWidgets('поле location рендерится через SelectableText при наличии значения',
        (tester) async {
      final item = await insertItem(
        id: 'item-b8-loc',
        title: 'Task with location',
        location: 'Аудитория 305',
      );
      await _setSize(tester, const Size(360, 760));
      await tester.pumpWidget(buildHarness(item));
      await _settle(tester);

      // Ожидаем ровно 2 SelectableText: заголовок + location (подзадач нет).
      expect(find.byType(SelectableText), findsNWidgets(2));

      // Заголовок через SelectableText
      final titleSelectable = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'Task with location',
      );
      expect(titleSelectable, findsOneWidget);

      // Локация через SelectableText
      final locationSelectable = find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'Аудитория 305',
      );
      expect(locationSelectable, findsOneWidget);

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });

    // -----------------------------------------------------------------------
    // 5. Метаданные (время, тип·приоритет) НЕ являются SelectableText
    //    (они рендерятся как Text, т.к. _DetailRow.selectable по умолчанию false)
    // -----------------------------------------------------------------------
    testWidgets('метаданные рендерятся обычным Text, не SelectableText', (tester) async {
      final item = await insertItem(id: 'item-b8-meta');
      await _setSize(tester, const Size(360, 760));
      await tester.pumpWidget(buildHarness(item));
      await _settle(tester);

      // Только заголовок SelectableText, метаданные — обычный Text.
      // В пустой БД: нет location, нет подзадач → ровно 1 SelectableText.
      expect(find.byType(SelectableText), findsOneWidget);

      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });
}
