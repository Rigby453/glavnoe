// Регресс на RangeError в коротких подписях дня недели (Plan: 3 дня / неделя /
// блочный планер + полоса недели на «Сегодня»).
//
// БАГ: `DateFormat.E().format(day).substring(0, 3)` бросал
// `RangeError (end): Invalid value` на локалях, где аббревиатура дня короче
// 3 символов — ru «пн»/«вт» (2), ja «月»/«日» (1), ko «월»/«일» (1). Падал
// заголовок КАЖДОЙ колонки сетки → красный ErrorWidget повторялся по числу
// колонок (3 в виде «3 дня», 7 в «неделе»). На en/it (3 символа) бага не было,
// поэтому он проявлялся только у части пользователей.
//
// Фикс — `shortWeekdayLabel`, который обрезает по графемам с защитой длины.

import 'package:app/core/utils/weekday_label.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  // Понедельник…воскресенье произвольной недели — проверяем все 7 дней,
  // чтобы поймать любой короткий день недели в каждой локали.
  final week = List<DateTime>.generate(7, (i) => DateTime(2026, 6, 22 + i));

  // Локали с КОРОТКОЙ (1–2 символа) аббревиатурой — на них падал substring(0,3).
  const shortAbbrLocales = ['ru', 'ja', 'ko'];
  // Локали с «нормальной» (3-символьной) аббревиатурой — поведение не меняется.
  const normalAbbrLocales = ['en', 'it', 'de', 'fr'];

  setUpAll(() async {
    for (final l in [...shortAbbrLocales, ...normalAbbrLocales]) {
      await initializeDateFormatting(l);
    }
  });

  tearDown(() {
    Intl.defaultLocale = null;
  });

  test('shortWeekdayLabel не бросает RangeError на коротких локалях (ru/ja/ko)',
      () {
    for (final locale in shortAbbrLocales) {
      Intl.defaultLocale = locale;
      for (final day in week) {
        // Без фикса этот вызов кидал RangeError — тест бы упал здесь.
        final label = shortWeekdayLabel(day);
        expect(label, isNotEmpty, reason: 'locale=$locale day=$day');
        expect(label.characters.length, lessThanOrEqualTo(3),
            reason: 'locale=$locale day=$day label="$label"');
      }
    }
  });

  test('воспроизведение первопричины: сырой substring(0,3) бросает на ru', () {
    Intl.defaultLocale = 'ru';
    // ru-аббревиатуры дня недели = 2 символа («пн», «вт», …) → substring(0,3)
    // выходит за длину строки и бросает RangeError. Это ровно тот вызов, что
    // был в _WeekDayHeader/week_strip до фикса.
    final raw = DateFormat.E().format(week.first);
    expect(raw.length, lessThan(3),
        reason: 'ru abbreviation must be shorter than 3 chars to trigger bug');
    expect(() => raw.substring(0, 3), throwsRangeError);
  });

  test('shortWeekdayLabel безопасно усекает до ≤3 графем для всех локалей', () {
    for (final locale in normalAbbrLocales) {
      Intl.defaultLocale = locale;
      for (final day in week) {
        final raw = DateFormat.E().format(day);
        final label = shortWeekdayLabel(day);
        // Короткую аббревиатуру отдаём как есть; длинную — первые 3 графемы.
        // Никогда не выходим за длину строки (в этом и был баг).
        final expected = raw.characters.length <= 3
            ? raw
            : raw.characters.take(3).toString();
        expect(label, expected, reason: 'locale=$locale day=$day');
        expect(label.characters.length, lessThanOrEqualTo(3),
            reason: 'locale=$locale day=$day label="$label"');
      }
    }
  });
}
