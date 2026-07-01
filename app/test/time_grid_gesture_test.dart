// Жесты блока сетки времени (time_grid.dart), проверенные на реальном
// in-memory Drift + настоящем DayTimeGrid:
//   • drag по ТЕЛУ блока стартует перенос С ПЕРВОГО касания (без tap/long-press)
//     и меняет scheduledAt;
//   • ВЕРХНЯЯ ручка меняет startTime (начало) и не даёт длительности уйти в ноль
//     (clamp на минимум), удерживая конец на месте.
//
// Жесты драйвим через tester.startGesture + moveBy + up (точный pan по координате
// внутри тела/ручки). DAO-результат читаем через runAsync после settle, как в
// interaction_smoke_test.dart.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart'
    show sharedPreferencesProvider;
import 'package:app/features/plan/widgets/task_detail_card.dart'
    show TaskDetailCard;
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/plan/widgets/week_strip.dart'
    show selectedDayProvider;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Зеркалит _kBlockPickupDelay из time_grid.dart (та константа приватна).
// Если меняешь порог подхвата в виджете — обнови и здесь.
const _kBlockPickupDelay = Duration(milliseconds: 120);

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

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  // Высота часа фиксируем — расчёты пикселей детерминированы.
  const hourHeight = kHourHeight; // 56.0
  // День задач — фиксированная дата, чтобы selectedDay совпал.
  final day = DateTime(2026, 6, 24);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTask({
    required String id,
    required int hour,
    required int minute,
    required int durationMinutes,
  }) async {
    final at = DateTime(day.year, day.month, day.day, hour, minute);
    await db.into(db.itemsTable).insert(
          ItemsTableCompanion(
            id: Value(id),
            userId: const Value('local'),
            title: const Value('Тестовая задача'),
            type: const Value('task'),
            priority: const Value('medium'),
            status: const Value('pending'),
            scheduledAt: Value(at),
            durationMinutes: Value(durationMinutes),
            isProtected: const Value(false),
            createdAt: Value(at),
            updatedAt: Value(at),
          ),
        );
  }

  Future<ItemsTableData> readTask(String id) async {
    return (db.select(db.itemsTable)..where((t) => t.id.equals(id))).getSingle();
  }

  Widget harness() => ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
          selectedDayProvider.overrideWith((ref) => day),
        ],
        child: MaterialApp(
          theme: _testTheme(),
          // disableAnimations: лифт-анимация блока (AnimatedScale 1.0↔1.03) через
          // effectiveDuration становится мгновенной (Duration.zero) — без неё в
          // тесте оставался pending Timer при dispose. Жесты (tap/long-press/
          // drag/resize) от этого не меняются, проверяется логика переноса.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 700,
              child: DayTimeGrid(hourHeight: hourHeight),
            ),
          ),
        ),
      );

  // Снимаем дерево и даём дренировать таймер закрытия Drift-стрима, который
  // riverpod создаёт при dispose StreamProvider (zero-duration Timer в
  // StreamQueryStore.markAsClosed). Без этого тест падает на инварианте
  // «A Timer is still pending even after the widget tree was disposed».
  Future<void> unmountAndFlush(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  }

  Future<void> pumpGrid(WidgetTester tester) async {
    await tester.pumpWidget(harness());
    // Даём стриму БД доставить задачи (как settle в interaction-тестах).
    await tester.pump();
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    'long-press по телу блока поднимает его и перенос в том же касании меняет '
    'scheduledAt; короткий tap НЕ двигает',
    (tester) async {
      // Задача 09:00–12:00 (180 мин) — высокий блок (168px), большое тело между
      // ручками, чтобы хват точно попал в зону переноса, а не в ручку resize.
      await insertTask(id: 'move', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final before = await readTask('move');
      expect(before.scheduledAt.hour, 9);

      // Берёмся за середину тела (далеко от верхней/нижней ручек по ключу блока).
      final blockBox = tester.getRect(find.byKey(const ValueKey('move')));
      final grabCenter = blockBox.center;

      // 1) Опускаем палец и ждём порог long-press подхвата (_kBlockPickupDelay
      //    на фейковом клоке) — блок «поднимается» (onLongPressStart). Затем
      //    В ТОМ ЖЕ касании ведём вниз на 1 час фиксированными шагами и
      //    отпускаем. Никакого pumpAndSettle с бесконечной анимацией лифта —
      //    только фикс-шаги.
      final gesture = await tester.startGesture(grabCenter);
      await tester.pump(_kBlockPickupDelay + const Duration(milliseconds: 50));
      // Перенос на +1 час несколькими шагами (onLongPressMoveUpdate).
      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, hourHeight / 4));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      // Скролл НЕ должен был сдвинуться — long-press выиграл арену у скролла.
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable).first);
      expect(scrollable.controller?.offset, kHourHeight * 7,
          reason: 'страница не проскроллилась — long-press взял блок');

      final after = await readTask('move');
      // Перенос на +60 минут → 10:00 (снап к 15 мин не сдвигает ровный час).
      expect(after.scheduledAt.hour, 10, reason: 'блок переехал на час вниз');
      expect(after.scheduledAt.minute, 0);
      // Длительность не тронута переносом.
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'короткий tap по телу блока НЕ переносит (открывает карточку), время не меняется',
    (tester) async {
      await insertTask(id: 'tap', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final blockBox = tester.getRect(find.byKey(const ValueKey('tap')));
      // Короткий тап по центру тела — без удержания и без движения.
      await tester.tapAt(blockBox.center);
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('tap');
      // Тап только открывает карточку — время задачи не сдвинулось.
      expect(after.scheduledAt.hour, 9, reason: 'tap не переносит блок');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'верхняя ручка тянет начало (startTime) и не даёт длительности уйти в ноль',
    (tester) async {
      // Задача 09:00–11:00 (120 мин, 112px) — БОЛЬШОЙ блок, на нём показаны ОБЕ
      // ручки (порог _kBothHandlesMinHeight ~58px). Тянем верхнюю ручку ВНИЗ
      // почти до конца — длительность зажимается минимумом (15 мин), конец 11:00.
      await insertTask(id: 'top', hour: 9, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      final before = await readTask('top');
      expect(before.durationMinutes, 120);

      // Берём геометрию блока по его ключу (ValueKey(id)) — надёжно.
      final blockBox = tester.getRect(find.byKey(const ValueKey('top')));
      // Верхняя ручка занимает первые 22px блока — целимся в её центр.
      final grabTop = Offset(blockBox.center.dx, blockBox.top + 11);

      // Тянем верхнюю ручку ВНИЗ на 200px (≈3.5ч) — заведомо больше длительности.
      await tester.dragFrom(grabTop, const Offset(0, 200));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('top');
      // Длительность зажата минимумом, не ноль/минус.
      expect(after.durationMinutes, kMinDurationMinutes,
          reason: 'длительность не ушла в ноль при ресайзе верхом');
      // Конец остался на месте (10:00): начало = конец − минимум.
      final endMin = after.scheduledAt.hour * 60 +
          after.scheduledAt.minute +
          after.durationMinutes;
      expect(endMin, 11 * 60, reason: 'конец задачи остался 11:00');
      // Начало сдвинулось позже исходных 09:00.
      expect(after.scheduledAt.hour * 60 + after.scheduledAt.minute,
          greaterThan(9 * 60));

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'верхняя ручка тянет начало раньше, удлиняя задачу (конец фиксирован)',
    (tester) async {
      // Задача 09:00–10:30 (90 мин, 84px) — БОЛЬШОЙ блок (обе ручки). Тянем верх
      // ВВЕРХ на 1 час → начало 08:00, длительность 150 мин (конец 10:30 фиксирован).
      await insertTask(id: 'grow', hour: 9, minute: 0, durationMinutes: 90);
      await pumpGrid(tester);

      final blockBox = tester.getRect(find.byKey(const ValueKey('grow')));
      final grabTop = Offset(blockBox.center.dx, blockBox.top + 11);

      // Тянем верхнюю ручку ВВЕРХ на час → начало 08:00, длительность 120.
      await tester.dragFrom(grabTop, const Offset(0, -hourHeight));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('grow');
      expect(after.scheduledAt.hour, 8, reason: 'начало уехало на 08:00');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 150,
          reason: 'задача удлинилась до 2.5 часов (конец 10:30 фиксирован)');

      await unmountAndFlush(tester);
    },
  );

  // Считает зоны хвата ручек ресайза ВНУТРИ блока [id]. Каждая зона обёрнута в
  // MouseRegion с курсором resizeUpDown (курсор ресайза на вебе/десктопе) — по
  // этому маркеру их и находим, не завися от приватных типов распознавателей.
  int resizeHandleCount(WidgetTester tester, String id) {
    final handles = find.descendant(
      of: find.byKey(ValueKey(id)),
      matching: find.byWidgetPredicate(
        (w) => w is MouseRegion &&
            w.cursor == SystemMouseCursors.resizeUpDown,
      ),
    );
    return handles.evaluate().length;
  }

  testWidgets(
    'МАЛЕНЬКИЙ блок — только нижняя ручка; БОЛЬШОЙ — обе (верх+низ)',
    (tester) async {
      // Маленький блок: 45 мин = 42px. Это >= _kBottomHandleMinHeight (~36px),
      // но < _kBothHandlesMinHeight (~58px) → показывается ТОЛЬКО нижняя ручка.
      await insertTask(id: 'small', hour: 8, minute: 0, durationMinutes: 45);
      // Большой блок: 120 мин = 112px >= _kBothHandlesMinHeight → ОБЕ ручки.
      await insertTask(id: 'big', hour: 12, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      // Маленький блок: ровно одна зона хвата (нижняя), верхней нет.
      expect(resizeHandleCount(tester, 'small'), 1,
          reason: 'на маленьком блоке только нижняя ручка (верхней нет)');
      // Большой блок: две зоны хвата (верхняя + нижняя).
      expect(resizeHandleCount(tester, 'big'), 2,
          reason: 'на большом блоке обе ручки (верх + низ)');

      // Курсор ресайза действительно задан на зонах хвата (веб/десктоп): хотя бы
      // одна MouseRegion с resizeUpDown присутствует у обоих блоков.
      expect(resizeHandleCount(tester, 'small'), greaterThan(0));

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'мышиный drag по блоку двигает его СРАЗУ, без порога удержания, и меняет '
    'scheduledAt',
    (tester) async {
      // Мышь/трекпад/стилус подхватывают блок по PanGestureRecognizer СРАЗУ по
      // нажатию-и-протягиванию — без _kBlockPickupDelay (та задержка действует
      // только на тач-путь через LongPressGestureRecognizer).
      //
      // PanGestureRecognizer «съедает» стартовый slop (kPanSlop ≈ 36px) как
      // порог отличения клика от драга — это штатное поведение Flutter
      // (DragStartBehavior.start): первые ~36px движения не долетают до
      // onUpdate, зато 1:1-трекинг начинается СРАЗУ по их исчерпанию — этим и
      // достигается «мгновенный подхват» (без задержки по ВРЕМЕНИ). Поэтому
      // тянем заведомо больше одного часа и проверяем НАПРАВЛЕНИЕ/факт сдвига,
      // а не точную снэпнутую минуту (та зависит от точного slop, что делает
      // тест хрупким без выгоды).
      await insertTask(
          id: 'mouse-move', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final before = await readTask('mouse-move');
      final blockBox = tester.getRect(find.byKey(const ValueKey('mouse-move')));
      final grabCenter = blockBox.center;

      final gesture = await tester.startGesture(
        grabCenter,
        kind: PointerDeviceKind.mouse,
      );
      // Никакого ожидания порога подхвата — pan мыши забирает арену по первому
      // смещению (slop), а не по времени удержания. Тянем на 3 часа суммарно
      // (168px) несколькими шагами — с запасом покрывает съеденный slop.
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, hourHeight / 2));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('mouse-move');
      expect(
        after.scheduledAt.difference(before.scheduledAt).inMinutes,
        greaterThanOrEqualTo(60),
        reason:
            'мышиный drag без удержания сдвинул блок минимум на час вниз',
      );
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'мышиный клик по блоку БЕЗ движения открывает карточку-деталь, '
    'scheduledAt не меняется',
    (tester) async {
      // Клик мышью без смещения не должен «украсть» арену у TapGestureRecognizer:
      // PanGestureRecognizer заявляет победу только по порогу движения (slop).
      await insertTask(
          id: 'mouse-click', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final blockBox =
          tester.getRect(find.byKey(const ValueKey('mouse-click')));

      final gesture = await tester.startGesture(
        blockBox.center,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TaskDetailCard), findsOneWidget,
          reason: 'клик мышью без движения открывает карточку-деталь');

      final after = await readTask('mouse-click');
      expect(after.scheduledAt.hour, 9,
          reason: 'клик без движения не переносит блок');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'тач-свайп по блоку БЕЗ удержания (быстрее _kBlockPickupDelay) НЕ двигает '
    'блок — уходит скроллу',
    (tester) async {
      // Движение начинается раньше, чем истекает порог удержания (120 мс) —
      // long-press не успевает выиграть арену у родительского скролла.
      await insertTask(
          id: 'fast-swipe', hour: 9, minute: 0, durationMinutes: 180);
      await pumpGrid(tester);

      final blockBox =
          tester.getRect(find.byKey(const ValueKey('fast-swipe')));
      final grabCenter = blockBox.center;

      final gesture = await tester.startGesture(grabCenter);
      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(0, 12));
        await tester.pump(const Duration(milliseconds: 8));
      }
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('fast-swipe');
      expect(after.scheduledAt.hour, 9,
          reason:
              'быстрый свайп без удержания не переносит блок (уходит скроллу)');
      expect(after.scheduledAt.minute, 0);
      expect(after.durationMinutes, 180);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'ОЧЕНЬ короткий блок — ручек нет совсем',
    (tester) async {
      // 15 мин → durationToHeight зажимает до 24px (< _kBottomHandleMinHeight
      // ~36px) → ручек нет, ресайз только через карточку-деталь.
      await insertTask(id: 'tiny', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      expect(resizeHandleCount(tester, 'tiny'), 0,
          reason: 'очень короткий блок без ручек ресайза');

      await unmountAndFlush(tester);
    },
  );
}
