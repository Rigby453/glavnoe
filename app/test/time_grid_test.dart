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
    test('реальный минимум блока (24px, пол durationToHeight) → адаптивная '
        'ручка 16px, резерв тела 8px', () {
      expect(bottomHandleHeight(24), 16.0);
    });
    test('ручка ВСЕГДА показывается — даже на очень коротком блоке', () {
      expect(bottomHandleHeight(24), greaterThan(0));
      expect(bottomHandleHeight(10), greaterThan(0));
    });
    test('вырожденный случай (блок меньше резерва тела) — ручка = весь блок', () {
      expect(bottomHandleHeight(5, minBodyReserve: 8), 5.0);
      expect(bottomHandleHeight(0), 0.0);
    });
    test('кастомные handleHitHeight/minBodyReserve уважаются', () {
      expect(
        bottomHandleHeight(50, handleHitHeight: 10, minBodyReserve: 4),
        10.0,
      );
      expect(
        bottomHandleHeight(12, handleHitHeight: 10, minBodyReserve: 4),
        8.0,
      );
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
