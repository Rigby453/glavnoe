// Жесты блока сетки времени (time_grid.dart), проверенные на реальном
// in-memory Drift + настоящем DayTimeGrid:
//   • drag по ТЕЛУ блока стартует перенос С ПЕРВОГО касания (без tap/long-press)
//     и меняет scheduledAt;
//   • нижняя ручка (ЕДИНСТВЕННАЯ — верхняя убрана по решению владельца
//     продукта) меняет длительность (конец), включая на коротких блоках, и
//     срабатывает СРАЗУ и мышью, и пальцем, без предварительного выбора блока.
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
    'нижняя ручка мышью меняет длительность СРАЗУ, без предварительного '
    'выбора/клика по блоку',
    (tester) async {
      // Задача 09:00–11:00 (120 мин, 112px) — обычный блок. Тянем нижнюю ручку
      // ВНИЗ мышью В ПЕРВОМ касании (без предшествующего тапа/выбора) — длина
      // должна вырасти сразу.
      await insertTask(id: 'bottom-mouse', hour: 9, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      final before = await readTask('bottom-mouse');
      expect(before.durationMinutes, 120);

      final blockBox = tester.getRect(find.byKey(const ValueKey('bottom-mouse')));
      // Нижняя ручка занимает последние ~22px блока — целимся в её центр.
      final grabBottom = Offset(blockBox.center.dx, blockBox.bottom - 11);

      final gesture = await tester.startGesture(
        grabBottom,
        kind: PointerDeviceKind.mouse,
      );
      // Никакого предварительного тапа/паузы — сразу тянем вниз на час.
      await gesture.moveBy(const Offset(0, hourHeight));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('bottom-mouse');
      expect(after.durationMinutes, 180,
          reason:
              'мышиный ресайз нижней ручкой сработал с первого касания (+1ч)');
      // Начало НЕ изменилось — верхней ручки больше нет, тянет только низ.
      expect(after.scheduledAt.hour, 9);
      expect(after.scheduledAt.minute, 0);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'верхней ручки больше нет: перенос за верхний край блока двигает блок '
    '(тело), а не меняет начало',
    (tester) async {
      // Раньше верхние ~22px были ручкой resize-начала. Теперь там тело блока —
      // долгое нажатие там должно ПЕРЕНОСИТЬ блок, а не резать длительность.
      await insertTask(id: 'no-top', hour: 9, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      final blockBox = tester.getRect(find.byKey(const ValueKey('no-top')));
      final grabTop = Offset(blockBox.center.dx, blockBox.top + 5);

      final gesture = await tester.startGesture(grabTop);
      await tester.pump(_kBlockPickupDelay + const Duration(milliseconds: 50));
      await gesture.moveBy(const Offset(0, hourHeight));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('no-top');
      // Длительность НЕ изменилась (перенос, не ресайз), время сдвинулось.
      expect(after.durationMinutes, 120,
          reason: 'верхний край теперь тело — перенос, длительность цела');
      expect(after.scheduledAt.hour, 10, reason: 'блок переехал на час вниз');

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
    'И маленький, и большой блок — РОВНО одна (нижняя) ручка ресайза; '
    'верхней больше нет ни у кого',
    (tester) async {
      // Маленький блок: 45 мин = 42px. Большой: 120 мин = 112px. Раньше у
      // большого было 2 ручки (верх+низ) — теперь верхняя убрана совсем, у
      // ОБОИХ ровно одна (нижняя), независимо от высоты.
      await insertTask(id: 'small', hour: 8, minute: 0, durationMinutes: 45);
      await insertTask(id: 'big', hour: 12, minute: 0, durationMinutes: 120);
      await pumpGrid(tester);

      expect(resizeHandleCount(tester, 'small'), 1,
          reason: 'маленький блок: одна нижняя ручка');
      expect(resizeHandleCount(tester, 'big'), 1,
          reason: 'большой блок: тоже одна ручка — верхней больше нет');

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
    'ОЧЕНЬ короткий блок (15 мин, 24px, реальный пол высоты) — ручка ЕСТЬ '
    'и её можно схватить',
    (tester) async {
      // 15 мин → durationToHeight зажимает до 24px — это реальный минимум
      // высоты блока в приложении. Правка владельца продукта: раньше ручек не
      // было совсем; теперь ручка показывается ВСЕГДА (bottomHandleHeight
      // адаптирует её размер, но не убирает).
      await insertTask(id: 'tiny', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      expect(resizeHandleCount(tester, 'tiny'), 1,
          reason: 'даже самый короткий блок имеет ручку ресайза');

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'ОЧЕНЬ короткий блок — нижнюю ручку можно потянуть и увеличить длительность '
    '(тач-путь)',
    (tester) async {
      await insertTask(id: 'tiny-drag', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      final before = await readTask('tiny-drag');
      expect(before.durationMinutes, 15);

      final blockBox = tester.getRect(find.byKey(const ValueKey('tiny-drag')));
      // Блок 24px высотой; ручка адаптивной высоты (16px) прижата к низу —
      // целимся в нижний край блока.
      final grabBottom = Offset(blockBox.center.dx, blockBox.bottom - 4);

      await tester.dragFrom(grabBottom, Offset(0, hourHeight));
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('tiny-drag');
      expect(after.durationMinutes, greaterThan(15),
          reason: 'даже самый короткий блок реально ресайзится за нижний край');
      expect(after.scheduledAt.hour, 8, reason: 'начало не тронуто (нет верхней ручки)');
      expect(after.scheduledAt.minute, 0);

      await unmountAndFlush(tester);
    },
  );

  testWidgets(
    'ОЧЕНЬ короткий блок — мышиный ресайз за нижний край стартует СРАЗУ, без '
    'предварительного выбора блока',
    (tester) async {
      // Ключевой сценарий фидбека владельца продукта: на коротких блоках
      // ресайз мышью "работал только после выбора блока", потому что ручки не
      // было совсем и палец/мышь попадали в тело (перенос). Теперь ручка есть
      // всегда — первое же нажатие-и-протягивание мышью по низу должно менять
      // длительность, БЕЗ какого-либо предшествующего тапа/клика по блоку.
      await insertTask(
          id: 'tiny-mouse', hour: 8, minute: 0, durationMinutes: 15);
      await pumpGrid(tester);

      final blockBox =
          tester.getRect(find.byKey(const ValueKey('tiny-mouse')));
      final grabBottom = Offset(blockBox.center.dx, blockBox.bottom - 4);

      // ПЕРВОЕ и единственное касание — сразу мышиный drag по ручке, без
      // предварительного tap/select.
      final gesture = await tester.startGesture(
        grabBottom,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, hourHeight));
      await tester.pump(const Duration(milliseconds: 16));
      await gesture.up();
      await tester.pump();
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 300));

      final after = await readTask('tiny-mouse');
      expect(after.durationMinutes, greaterThan(15),
          reason:
              'мышиный ресайз короткого блока сработал с первого касания, '
              'без предварительного выбора');

      await unmountAndFlush(tester);
    },
  );
}
