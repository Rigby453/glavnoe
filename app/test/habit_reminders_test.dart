// Тесты напоминаний привычек (ADR-053, slice 4).
//
// Часть 1 (юнит, БЕЗ БД/плагина): чистая функция computeHabitReminders и
// стабильность id (habitReminderBaseId). Реальные уведомления в юнит-тесте
// не срабатывают — проверяем именно расчёт расписания (что/когда/каким id).
//
// Часть 2 (виджет): тумблер напоминания + кнопка времени в диалоге привычки
// рендерятся без overflow на 320px / textScale 1.5. Диалог НЕ обращается к
// сервису уведомлений (планирование живёт в вызывающем экране), поэтому ничего
// реального не планируется и мок сервиса не нужен.

import 'package:app/core/database/daos/habits_dao.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/health/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeHabitReminders — выключено', () {
    test('reminderMinutes == null → пустой список', () {
      final r = computeHabitReminders(
        habitId: 'h1',
        reminderMinutes: null,
        frequencyType: 'daily',
        weekdayMask: 127,
      );
      expect(r, isEmpty);
    });

    test('reminderMinutes вне диапазона (<0 или >1439) → пусто', () {
      expect(
        computeHabitReminders(
          habitId: 'h1',
          reminderMinutes: -1,
          frequencyType: 'daily',
          weekdayMask: 127,
        ),
        isEmpty,
      );
      expect(
        computeHabitReminders(
          habitId: 'h1',
          reminderMinutes: 1440,
          frequencyType: 'daily',
          weekdayMask: 127,
        ),
        isEmpty,
      );
    });
  });

  group('computeHabitReminders — daily / weekly_count', () {
    test('daily → одно ежедневное напоминание (weekday == null)', () {
      final r = computeHabitReminders(
        habitId: 'h1',
        reminderMinutes: 9 * 60, // 09:00
        frequencyType: 'daily',
        weekdayMask: 127,
      );
      expect(r, hasLength(1));
      expect(r.single.weekday, isNull);
      expect(r.single.hour, 9);
      expect(r.single.minute, 0);
      expect(r.single.notificationId, habitReminderBaseId('h1'));
    });

    test('weekly_count → тоже одно ежедневное (v1-упрощение)', () {
      final r = computeHabitReminders(
        habitId: 'h1',
        reminderMinutes: 21 * 60 + 30, // 21:30
        frequencyType: 'weekly_count',
        weekdayMask: 0, // маска не используется для weekly_count
      );
      expect(r, hasLength(1));
      expect(r.single.weekday, isNull);
      expect(r.single.hour, 21);
      expect(r.single.minute, 30);
    });

    test('часы/минуты корректно раскладываются из минут от полуночи', () {
      HabitReminder one(int minutes) => computeHabitReminders(
            habitId: 'h1',
            reminderMinutes: minutes,
            frequencyType: 'daily',
            weekdayMask: 127,
          ).single;
      expect((one(0).hour, one(0).minute), (0, 0)); // 00:00
      expect((one(1439).hour, one(1439).minute), (23, 59)); // 23:59
      expect((one(75).hour, one(75).minute), (1, 15)); // 01:15
    });
  });

  group('computeHabitReminders — weekly_days', () {
    // Пн/Ср/Пт = бит0 + бит2 + бит4 = 21.
    const monWedFri = 1 | 4 | 16;

    test('только дни из маски → по одному напоминанию (Пн=1,Ср=3,Пт=5)', () {
      final r = computeHabitReminders(
        habitId: 'h1',
        reminderMinutes: 8 * 60, // 08:00
        frequencyType: 'weekly_days',
        weekdayMask: monWedFri,
      );
      expect(r, hasLength(3));
      expect(r.map((e) => e.weekday).toList(), [1, 3, 5]);
      // У всех одно и то же время.
      expect(r.every((e) => e.hour == 8 && e.minute == 0), isTrue);
    });

    test('маска всех 7 дней → 7 напоминаний (Пн..Вс)', () {
      final r = computeHabitReminders(
        habitId: 'h1',
        reminderMinutes: 7 * 60,
        frequencyType: 'weekly_days',
        weekdayMask: 127,
      );
      expect(r, hasLength(7));
      expect(r.map((e) => e.weekday).toList(), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('id каждого дня = base + weekday, все различны и стабильны', () {
      final base = habitReminderBaseId('h1');
      final r = computeHabitReminders(
        habitId: 'h1',
        reminderMinutes: 8 * 60,
        frequencyType: 'weekly_days',
        weekdayMask: monWedFri,
      );
      expect(r.map((e) => e.notificationId).toList(),
          [base + 1, base + 3, base + 5]);
      // Все id уникальны.
      expect(r.map((e) => e.notificationId).toSet(), hasLength(3));
    });
  });

  group('habitReminderBaseId — стабильность и разнесение', () {
    test('один и тот же id даёт один base (детерминирован)', () {
      expect(habitReminderBaseId('habit-abc'),
          habitReminderBaseId('habit-abc'));
    });

    test('разные id → разные base', () {
      expect(habitReminderBaseId('habit-a'),
          isNot(habitReminderBaseId('habit-b')));
    });

    test('base вне зоны review/posture/task (>= 2_000_000)', () {
      expect(habitReminderBaseId('whatever') >= 2000000, isTrue);
    });

    test('диапазоны соседних слотов не пересекаются (шаг базы кратен 10)', () {
      // base всегда кратен 10 → +0..+7 одной привычки не наезжает на base
      // другой привычки.
      expect(habitReminderBaseId('x') % 10, 0);
    });
  });

  group('диалог: тумблер напоминания + время', () {
    Future<void> open(
      WidgetTester tester, {
      required double width,
      required double textScale,
    }) async {
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.focusTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  key: const ValueKey('open'),
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => addHabitDialogForTest(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
    }

    testWidgets('включение тумблера показывает кнопку времени, без overflow '
        '(320px, 1.5x)', (tester) async {
      await open(tester, width: 320, textScale: 1.5);

      // Тумблер напоминания присутствует (good — режим по умолчанию).
      final toggle = find.byType(Switch);
      expect(toggle, findsOneWidget);

      // До включения кнопки времени нет.
      expect(find.byType(OutlinedButton), findsNothing);

      // Включаем — появляется кнопка выбора времени.
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.byType(OutlinedButton), findsOneWidget);

      // Главная проверка: ни один pump не выбросил RenderFlex overflow.
      expect(tester.takeException(), isNull);
    });

    testWidgets('обычная ширина (360 / 1.0) — тумблер рендерится без ошибок',
        (tester) async {
      await open(tester, width: 360, textScale: 1.0);
      expect(find.byType(Switch), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
