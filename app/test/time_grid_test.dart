// Юнит-тесты чистой математики сетки времени (time_grid.dart).
// Жесты drag/resize здесь не тестируем (нужна живая проверка на устройстве) —
// покрываем только перевод минут↔смещение, snap, высоту и раскладку перекрытий.

import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const hourHeight = 56.0;

  group('minutesFromMidnight', () {
    test('считает минуты от полуночи по часам/минутам', () {
      expect(minutesFromMidnight(DateTime(2026, 6, 22, 0, 0)), 0);
      expect(minutesFromMidnight(DateTime(2026, 6, 22, 7, 30)), 450);
      expect(minutesFromMidnight(DateTime(2026, 6, 22, 23, 59)), 1439);
    });
  });

  group('minutesToOffset', () {
    test('0 минут → 0px', () {
      expect(minutesToOffset(0, hourHeight), 0);
    });
    test('60 минут → высота часа', () {
      expect(minutesToOffset(60, hourHeight), hourHeight);
    });
    test('7:00 → 7 * hourHeight', () {
      expect(minutesToOffset(420, hourHeight), 7 * hourHeight);
    });
    test('30 минут → половина часа', () {
      expect(minutesToOffset(30, hourHeight), hourHeight / 2);
    });
  });

  group('durationToHeight', () {
    test('60 минут → высота часа', () {
      expect(durationToHeight(60, hourHeight), hourHeight);
    });
    test('30 минут → половина часа', () {
      expect(durationToHeight(30, hourHeight), hourHeight / 2);
    });
    test('очень короткое событие зажимается до минимума', () {
      // 5 минут * 56/60 = ~4.7px < 24 → клипуется до minHeight
      expect(durationToHeight(5, hourHeight), 24.0);
    });
    test('кастомный minHeight уважается', () {
      expect(durationToHeight(1, hourHeight, minHeight: 10), 10.0);
    });
  });

  group('offsetToSnappedMinutes', () {
    test('обратное к minutesToOffset на кратных 15', () {
      final offset = minutesToOffset(450, hourHeight); // 7:30
      expect(offsetToSnappedMinutes(offset, hourHeight), 450);
    });
    test('привязка к 15 минутам — вниз', () {
      // 7 минут от полуночи → ближе к 0
      final offset = minutesToOffset(7, hourHeight);
      expect(offsetToSnappedMinutes(offset, hourHeight), 0);
    });
    test('привязка к 15 минутам — вверх', () {
      // 22 минуты → ближе к 15 (22-15=7 < 30-22=8)
      expect(offsetToSnappedMinutes(minutesToOffset(22, hourHeight), hourHeight),
          15);
      // 24 минуты → ближе к 30 (30-24=6 < 24-15=9)
      expect(offsetToSnappedMinutes(minutesToOffset(24, hourHeight), hourHeight),
          30);
    });
    test('отрицательное смещение зажимается в 0', () {
      expect(offsetToSnappedMinutes(-100, hourHeight), 0);
    });
    test('смещение за пределы суток зажимается в 24:00', () {
      expect(offsetToSnappedMinutes(hourHeight * 30, hourHeight), 24 * 60);
    });
  });

  group('snapDuration', () {
    test('кратное 15 не меняется', () {
      expect(snapDuration(45), 45);
    });
    test('округляет к ближайшим 15', () {
      expect(snapDuration(38), 45);
      expect(snapDuration(37), 30);
    });
    test('минимум 15 минут', () {
      expect(snapDuration(3), 15);
      expect(snapDuration(0), 15);
    });
    test('кастомный шаг/минимум', () {
      expect(snapDuration(50, snapMinutes: 30, minDuration: 30), 60);
      expect(snapDuration(5, snapMinutes: 30, minDuration: 30), 30);
    });
  });

  group('formatMinutesOfDay', () {
    test('форматирует час:минуты с ведущими нулями', () {
      expect(formatMinutesOfDay(0), '00:00');
      expect(formatMinutesOfDay(450), '07:30');
      expect(formatMinutesOfDay(8 * 60 + 5), '08:05');
    });
    test('зажимает отрицательное и за пределы суток', () {
      expect(formatMinutesOfDay(-30), '00:00');
      // 24:00 → отображаем как 00:00 (нормализация по модулю 24)
      expect(formatMinutesOfDay(24 * 60), '00:00');
    });
  });

  group('formatBlockTimeRange', () {
    test('диапазон старт–конец', () {
      expect(
        formatBlockTimeRange(DateTime(2026, 6, 22, 14, 30), 45),
        '14:30–15:15',
      );
    });
    test('целый час', () {
      expect(
        formatBlockTimeRange(DateTime(2026, 6, 22, 9, 0), 60),
        '09:00–10:00',
      );
    });
  });

  group('formatItemTimeRange (форма задачи — task_shape.dart)', () {
    test('block (durationMinutes > 0) — как formatBlockTimeRange', () {
      expect(
        formatItemTimeRange(DateTime(2026, 6, 22, 14, 30), 45),
        '14:30–15:15',
      );
    });
    test('moment (durationMinutes == 0) — только точка, без диапазона', () {
      expect(
        formatItemTimeRange(DateTime(2026, 6, 22, 14, 0), 0),
        '14:00',
      );
    });
    test('open (durationMinutes == -1) — начало с открытым концом', () {
      expect(
        formatItemTimeRange(DateTime(2026, 6, 22, 15, 0), -1),
        '15:00–',
      );
    });
  });

  group('blockContentLevel', () {
    test('низкий блок → ТОЛЬКО заголовок (приоритет названию, время на оси)', () {
      expect(blockContentLevel(20), BlockContentLevel.titleOnly);
      // Порог titleAndTime поднят до 48: на переходных высотах ресайза время
      // не появляется раньше, чем под него реально хватит места.
      expect(blockContentLevel(47.9), BlockContentLevel.titleOnly);
    });
    test('средний блок → заголовок + время (название уже влезло)', () {
      expect(blockContentLevel(48), BlockContentLevel.titleAndTime);
      expect(blockContentLevel(79.9), BlockContentLevel.titleAndTime);
    });
    test('высокий блок → заголовок + время + мета', () {
      expect(blockContentLevel(80), BlockContentLevel.titleTimeAndMeta);
      expect(blockContentLevel(120), BlockContentLevel.titleTimeAndMeta);
    });
  });

  group('compactBlockContent', () {
    test('крошечный блок (узкий ИЛИ низкий) → только цвет', () {
      // Слишком узкий по ширине.
      expect(
        compactBlockContent(kCompactMinTextWidth - 1, 100),
        CompactBlockContent.colorOnly,
      );
      // Слишком низкий по высоте.
      expect(
        compactBlockContent(100, kCompactMinTextHeight - 1),
        CompactBlockContent.colorOnly,
      );
    });
    test('средний блок → только заголовок (без времени)', () {
      // Достаточно для текста, но узок/невысок для диапазона времени.
      expect(
        compactBlockContent(kCompactMinTextWidth, kCompactMinTextHeight),
        CompactBlockContent.titleOnly,
      );
      // Достаточно широкий, но низкий — времени нет.
      expect(
        compactBlockContent(kCompactMinTimeWidth, kCompactMinTimeHeight - 1),
        CompactBlockContent.titleOnly,
      );
      // Достаточно высокий, но узкий — времени нет.
      expect(
        compactBlockContent(kCompactMinTimeWidth - 1, kCompactMinTimeHeight),
        CompactBlockContent.titleOnly,
      );
    });
    test('широкий и высокий блок → заголовок + время', () {
      expect(
        compactBlockContent(kCompactMinTimeWidth, kCompactMinTimeHeight),
        CompactBlockContent.titleAndTime,
      );
      expect(
        compactBlockContent(120, 80),
        CompactBlockContent.titleAndTime,
      );
    });
  });

  group('bottomHandleHeight', () {
    test('обычный блок (>= handleHitHeight + minBodyReserve) → полная ручка', () {
      // По умолчанию handleHitHeight=22, minBodyReserve=8 → порог 30px.
      expect(bottomHandleHeight(30), 22.0);
      expect(bottomHandleHeight(100), 22.0);
    });
    // BUG-FIX (маленький блок нельзя было сразу перетащить — только
    // ресайзить): раньше резерв тела был фиксирован (8px), и на блоке-
    // минимуме (24px) ручка занимала 16px (67% площади) — тело было тонкой
    // полоской 8px (33%), в которую палец не мог надёжно попасть. Теперь
    // резерв растёт для маленьких блоков и достигает половины блока —
    // ручка/тело делят блок 50/50, тело больше не тонкая полоска.
    test('реальный минимум блока (24px, пол durationToHeight) → ручка = '
        'половина блока (12px), тело = половина (было 16/8 — 67% ручке)', () {
      expect(bottomHandleHeight(24), 12.0);
    });
    test('ручка ВСЕГДА показывается, пока блок не совсем вырожденный', () {
      expect(bottomHandleHeight(24), greaterThan(0));
      expect(bottomHandleHeight(10), greaterThan(0));
    });
    test('вырожденный случай (даже половина блока меньше резерва тела) — '
        'ручки НЕТ совсем: весь блок — зона переноса/тапа (не наоборот, как '
        'было раньше — тело было бы 0)', () {
      expect(bottomHandleHeight(5, minBodyReserve: 8), 0.0);
      expect(bottomHandleHeight(0), 0.0);
    });
    test('кастомные handleHitHeight/minBodyReserve уважаются', () {
      expect(
        bottomHandleHeight(50, handleHitHeight: 10, minBodyReserve: 4),
        10.0,
      );
      // threshold=14, blockHeight=12<14 → half=6 > minBodyReserve(4) →
      // reserve=6 → handle=12-6=6 (50/50 split, не 8/4 как раньше).
      expect(
        bottomHandleHeight(12, handleHitHeight: 10, minBodyReserve: 4),
        6.0,
      );
    });
    test('монотонность: высота РУЧКИ ресайза не убывает при росте высоты блока '
        '(грип не дёргается/не скачет вниз на кадрах живого ресайза)', () {
      // Инвариант анти-дёрганья: пока пользователь тянет нижнюю ручку и блок
      // растёт, сама зона хвата ручки НЕ должна сжиматься — иначе палец
      // «соскакивает». Тело (h - handle) при этом НЕ обязано быть монотонным:
      // ниже порога оно намеренно ≥ половины блока (защита мелких блоков, см.
      // соседний тест), а на пороге ручка берёт полные handleHitHeight, из-за
      // чего тело один раз ступенькой уменьшается — это ОК, тела в момент
      // ресайза палец не касается (он на ручке). Два требования (тело ≥ ½ ниже
      // порога И тело монотонно через порог) математически несовместимы —
      // приоритет у стабильности грипа ручки.
      final heights = [0.0, 4.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 30.0, 40.0];
      var prevHandle = 0.0;
      for (final h in heights) {
        final handle = bottomHandleHeight(h);
        expect(handle, greaterThanOrEqualTo(prevHandle - 0.001));
        prevHandle = handle;
      }
    });
    test('тело — не менее половины блока на любой высоте ниже порога '
        '(маленький блок надёжно тянется, а не только ресайзится)', () {
      for (final h in [4.0, 10.0, 18.0, 24.0, 29.0]) {
        final handle = bottomHandleHeight(h);
        final body = h - handle;
        expect(body, greaterThanOrEqualTo(h / 2 - 0.001));
      }
    });
  });

  group('computeOverlapLanes', () {
    test('пустой список', () {
      expect(computeOverlapLanes([]), isEmpty);
    });
    test('одно событие → одна дорожка', () {
      final r = computeOverlapLanes([(startMin: 60, endMin: 120)]);
      expect(r, [(lane: 0, laneCount: 1)]);
    });
    test('два непересекающихся → каждое в своей группе, 1 дорожка', () {
      final r = computeOverlapLanes([
        (startMin: 60, endMin: 120),
        (startMin: 120, endMin: 180),
      ]);
      expect(r, [(lane: 0, laneCount: 1), (lane: 0, laneCount: 1)]);
    });
    test('два пересекающихся → две дорожки', () {
      final r = computeOverlapLanes([
        (startMin: 60, endMin: 120),
        (startMin: 90, endMin: 150),
      ]);
      expect(r[0].laneCount, 2);
      expect(r[1].laneCount, 2);
      expect({r[0].lane, r[1].lane}, {0, 1});
    });
    test('третье после освобождения дорожки переиспользует её', () {
      // A[0..60] B[0..60] пересекаются (2 дорожки), C[60..120] начинается ровно
      // на конце → отдельная группа, 1 дорожка.
      final r = computeOverlapLanes([
        (startMin: 0, endMin: 60),
        (startMin: 0, endMin: 60),
        (startMin: 60, endMin: 120),
      ]);
      expect(r[0].laneCount, 2);
      expect(r[1].laneCount, 2);
      expect(r[2], (lane: 0, laneCount: 1));
    });
    test('цепочка пересечений держит общий laneCount группы', () {
      // A[0..50] B[40..90] C[80..130] — A∩B и B∩C, но A∌C.
      // Все в одной связной группе. Жадно: A→0, B→1, C→0 (A освободилась к 80).
      final r = computeOverlapLanes([
        (startMin: 0, endMin: 50),
        (startMin: 40, endMin: 90),
        (startMin: 80, endMin: 130),
      ]);
      expect(r[0].lane, 0);
      expect(r[1].lane, 1);
      expect(r[2].lane, 0);
      // Максимум одновременно — 2 дорожки → группа laneCount = 2.
      expect(r[0].laneCount, 2);
      expect(r[1].laneCount, 2);
      expect(r[2].laneCount, 2);
    });
  });
}
