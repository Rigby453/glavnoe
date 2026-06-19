// Юнит-тесты чистой функции computeKaiWidgetEmotion (§4 WIDGET.md).
// Проверяет все 4 ветки, граничный случай ровно 2 дней и lastOpenedAt==null.

import 'package:app/services/widget/kai_widget_emotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Опорный «сейчас» для тестов
  final now = DateTime(2026, 6, 19, 12, 0);

  group('computeKaiWidgetEmotion', () {
    // ------------------------------------------------------------------
    // Ветка 1: away — не заходил >= 2 дней
    // ------------------------------------------------------------------
    test('returns away when last opened exactly 2 days ago', () {
      final lastOpened = now.subtract(const Duration(days: 2));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 0,
          mainTotal: 3,
          hasOverdue: false,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'away',
      );
    });

    test('returns away when last opened more than 2 days ago', () {
      final lastOpened = now.subtract(const Duration(days: 5));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 1,
          mainTotal: 3,
          hasOverdue: true, // away должен быть выше anxious
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'away',
      );
    });

    // Граница: ровно 1 день 23 ч 59 м — НЕ away
    test('does not return away when last opened 1 day 23h ago', () {
      final lastOpened = now.subtract(
        const Duration(days: 1, hours: 23, minutes: 59),
      );
      final result = computeKaiWidgetEmotion(
        mainDone: 0,
        mainTotal: 3,
        hasOverdue: false,
        lastOpenedAt: lastOpened,
        now: now,
      );
      expect(result, isNot('away'));
    });

    // ------------------------------------------------------------------
    // Ветка 2: anxious — есть просрочка (и заходил недавно)
    // ------------------------------------------------------------------
    test('returns anxious when hasOverdue and recently opened', () {
      final lastOpened = now.subtract(const Duration(hours: 2));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 0,
          mainTotal: 3,
          hasOverdue: true,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'anxious',
      );
    });

    // ------------------------------------------------------------------
    // Ветка 3: success — все главные завершены
    // ------------------------------------------------------------------
    test('returns success when all main tasks done', () {
      final lastOpened = now.subtract(const Duration(hours: 1));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 3,
          mainTotal: 3,
          hasOverdue: false,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'success',
      );
    });

    test('returns success when mainDone > mainTotal (safety)', () {
      final lastOpened = now.subtract(const Duration(hours: 1));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 4,
          mainTotal: 3,
          hasOverdue: false,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'success',
      );
    });

    // ------------------------------------------------------------------
    // Ветка 4: neutral — иначе
    // ------------------------------------------------------------------
    test('returns neutral in normal in-progress state', () {
      final lastOpened = now.subtract(const Duration(hours: 3));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 1,
          mainTotal: 3,
          hasOverdue: false,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'neutral',
      );
    });

    test('returns neutral when mainTotal == 0', () {
      final lastOpened = now.subtract(const Duration(hours: 1));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 0,
          mainTotal: 0,
          hasOverdue: false,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'neutral',
      );
    });

    // ------------------------------------------------------------------
    // Граничный случай: lastOpenedAt == null → не away
    // ------------------------------------------------------------------
    test('returns neutral (not away) when lastOpenedAt is null', () {
      expect(
        computeKaiWidgetEmotion(
          mainDone: 0,
          mainTotal: 2,
          hasOverdue: false,
          lastOpenedAt: null,
          now: now,
        ),
        'neutral',
      );
    });

    test('returns anxious (not away) when null lastOpenedAt and hasOverdue', () {
      expect(
        computeKaiWidgetEmotion(
          mainDone: 0,
          mainTotal: 2,
          hasOverdue: true,
          lastOpenedAt: null,
          now: now,
        ),
        'anxious',
      );
    });

    // ------------------------------------------------------------------
    // Проверка порядка: away перекрывает success и anxious
    // ------------------------------------------------------------------
    test('away overrides success when last opened 3 days ago', () {
      final lastOpened = now.subtract(const Duration(days: 3));
      expect(
        computeKaiWidgetEmotion(
          mainDone: 3,
          mainTotal: 3,
          hasOverdue: false,
          lastOpenedAt: lastOpened,
          now: now,
        ),
        'away',
      );
    });
  });
}
