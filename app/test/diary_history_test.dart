// Тесты «История дневника» (diary-1 + diary-edit-window Variant A):
//   1. DayLogsDao.getBetween — выборка записей за период (для раскраски года).
//   2. DiaryHistoryScreen рендерится без overflow на 320px/textScale 1.5
//      (год-провайдер подменён — реальный Drift-запрос за год не нужен в
//      виджет-тесте, источник дедлока под фейковым клоком, см. plan_adaptive_views_test).
//   3. DiaryDayDetailScreen — Variant A (окно правки дневника, решение
//      2026-07-02: 7-дневное окно, ДОБАВЛЯЕМ пропущенное, НИКОГДА не
//      переписываем существующее; revert commit 8ac0743's «правь любой
//      прошлый день»):
//      * день с УЖЕ существующей записью (не сегодня) — read-only: контент
//        виден, кнопки «Edit» нет;
//      * пустой день ВНУТРИ 7-дневного окна — доступна «Add entry», и после
//        сохранения запись реально попадает в БД (реальный Drift, обёрнут в
//        tester.runAsync);
//      * пустой день СТАРШЕ 7 дней — read-only, кнопки «Add entry» тоже нет.
//   4. l10n — новые ключи diary.history_legend / diary.history_add_entry
//      имеют непустые en и ru.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/database/daos/day_logs_dao.dart';
import 'package:app/core/l10n/strings/plan_diary.dart' show planDiaryStrings;
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/diary/diary_day_detail_screen.dart';
import 'package:app/features/diary/diary_history_providers.dart';
import 'package:app/features/diary/diary_history_screen.dart';
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

Widget _harness(
  AppDatabase db,
  SharedPreferences prefs,
  Widget child, {
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      ...extraOverrides,
    ],
    child: MaterialApp(
      theme: _testTheme(),
      home: child,
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. DAO — запрос за период
  // ---------------------------------------------------------------------------
  group('DayLogsDao.getBetween', () {
    late AppDatabase db;
    late DayLogsDao dao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dao = DayLogsDao(db);
    });

    tearDown(() async => db.close());

    test('возвращает только записи внутри [from, to)', () async {
      await dao.saveForDate(date: DateTime(2026, 1, 5), mood: 3);
      await dao.saveForDate(date: DateTime(2026, 6, 15), mood: 5);
      await dao.saveForDate(date: DateTime(2027, 1, 1), mood: 1); // вне периода

      final rows = await dao.getBetween(
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2027, 1, 1),
      );

      expect(rows.length, 2);
      expect(rows.map((r) => r.mood), containsAll([3, 5]));
    });

    test('пустой период без записей возвращает пустой список', () async {
      final rows = await dao.getBetween(
        DateTime.utc(2019, 1, 1),
        DateTime.utc(2020, 1, 1),
      );
      expect(rows, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 2. Год-календарь — рендер без overflow
  // ---------------------------------------------------------------------------
  group('DiaryHistoryScreen', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async => db.close());

    testWidgets('рендерится без overflow на 320px/textScale 1.5',
        (tester) async {
      final year = DateTime.now().year;
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          db,
          prefs,
          MediaQuery(
            data: const MediaQueryData(size: Size(320, 800))
                .copyWith(textScaler: TextScaler.linear(1.5)),
            child: const DiaryHistoryScreen(),
          ),
          extraOverrides: [
            // Год-провайдер подменён фиктивными данными — без обращения к
            // Drift за год (см. комментарий в шапке файла).
            dayLogsInYearProvider(year)
                .overrideWith((ref) async => {'$year-6-15': 5, '$year-6-2': 1}),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      // Заголовок экрана и год видны.
      expect(find.text('Diary History'), findsOneWidget);
      expect(find.text('$year'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. Variant A — окно правки дневника (реальный Drift)
  // ---------------------------------------------------------------------------
  group('DiaryDayDetailScreen — прошлые дни (Variant A)', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async => db.close());

    // Drift закрывает стримы и оставляет zero-duration таймер; размонтируем
    // дерево, чтобы он успел сработать внутри теста.
    Future<void> flush(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets(
        'запись прошлого дня (не сегодня) — read-only: контент виден, Edit скрыт',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final day = DateTime(pastDate.year, pastDate.month, pastDate.day);

      await tester.runAsync(() async {
        final dao = DayLogsDao(db);
        await dao.saveForDate(
          date: day,
          mood: 4,
          note: 'Felt good today\n\nIssues: was_tired',
        );

        await tester.pumpWidget(
          _harness(db, prefs, DiaryDayDetailScreen(date: day)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Контент виден — просмотр разрешён для любого прошлого дня.
        // mood=4 → 4-й эмодзи (индекс 3) в шкале 😞😕😐🙂😄
        expect(find.text('🙂'), findsOneWidget);
        expect(find.text('Felt good today'), findsOneWidget);
        expect(find.text('Was tired'), findsOneWidget); // issue chip (en)
        // Variant A: день НЕ сегодня и запись УЖЕ ЕСТЬ → read-only, кнопки
        // «Edit» нет (существующая запись прошлого не перезаписывается).
        expect(find.text('Edit'), findsNothing);
        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    });

    testWidgets(
        'день без записи ВНУТРИ 7-дневного окна показывает пустое состояние + Add entry',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final day = DateTime(pastDate.year, pastDate.month, pastDate.day);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _harness(db, prefs, DiaryDayDetailScreen(date: day)),
        );
        await tester.pump();
        // Первое обращение к свежей (не «прогретой» предыдущим saveForDate)
        // NativeDatabase может открываться дольше одного кадра — ждём settle.
        await tester.pumpAndSettle();

        expect(find.text('No entry for this day'), findsOneWidget);
        expect(find.text('Add entry'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    });

    testWidgets(
        'день без записи СТАРШЕ 7 дней — read-only, кнопки Add entry нет',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 10));
      final day = DateTime(pastDate.year, pastDate.month, pastDate.day);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          _harness(db, prefs, DiaryDayDetailScreen(date: day)),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text('No entry for this day'), findsOneWidget);
        // За пределами 7-дневного окна правки — добавить нельзя (Variant A).
        expect(find.text('Add entry'), findsNothing);
        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    });

    testWidgets(
        'существующая запись 20-дневной давности — read-only: Edit скрыт, БД не тронута',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 20));
      final day = DateTime(pastDate.year, pastDate.month, pastDate.day);

      await tester.runAsync(() async {
        final dao = DayLogsDao(db);
        await dao.saveForDate(date: day, mood: 2, note: 'Rough day');

        await tester.pumpWidget(
          _harness(db, prefs, DiaryDayDetailScreen(date: day)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Запись видна (просмотр разрешён), но кнопки правки нет — день не
        // сегодня и запись уже существует → read-only (revert commit
        // 8ac0743's «правь любой прошлый день», Variant A per 2026-07-02).
        expect(find.text('😕'), findsOneWidget); // mood=2 → 2-й эмодзи
        expect(find.text('Rough day'), findsOneWidget);
        expect(find.text('Edit'), findsNothing);

        // БД остаётся нетронутой — никакого upsert через этот экран.
        final rows = await dao.getBetween(
          DateTime.utc(day.year, 1, 1),
          DateTime.utc(day.year + 1, 1, 1),
        );
        final existing = rows.where((r) {
          final d = r.date.toUtc();
          return d.year == day.year && d.month == day.month && d.day == day.day;
        }).toList();
        expect(existing.length, 1);
        expect(existing.single.mood, 2);
        expect(existing.single.note, 'Rough day');

        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    });

    testWidgets(
        'добавление записи в пустой день ВНУТРИ окна правки сохраняет в БД',
        (tester) async {
      final pastDate = DateTime.now().subtract(const Duration(days: 3));
      final day = DateTime(pastDate.year, pastDate.month, pastDate.day);

      await tester.runAsync(() async {
        final dao = DayLogsDao(db);

        await tester.pumpWidget(
          _harness(db, prefs, DiaryDayDetailScreen(date: day)),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Пустой день внутри 7-дневного окна — доступна кнопка «Add entry».
        await tester.tap(find.text('Add entry'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Заполняем настроение (5-й эмодзи) и заметку.
        await tester.tap(find.text('😄'));
        await tester.pump();
        await tester.enterText(find.byType(TextField), 'Added later');
        await tester.pump();

        // Сохраняем
        await tester.tap(find.text('Save day'));
        await tester.pumpAndSettle();

        final rows = await dao.getBetween(
          DateTime.utc(day.year, 1, 1),
          DateTime.utc(day.year + 1, 1, 1),
        );
        final saved = rows.where((r) {
          final d = r.date.toUtc();
          return d.year == day.year && d.month == day.month && d.day == day.day;
        }).toList();
        expect(saved.length, 1);
        expect(saved.single.mood, 5);
        expect(saved.single.note, contains('Added later'));

        expect(tester.takeException(), isNull);
      });
      await flush(tester);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. l10n — новые ключи
  // ---------------------------------------------------------------------------
  group('l10n — diary history (новые ключи)', () {
    test('diary.history_legend и diary.history_add_entry имеют en + ru', () {
      for (final key in ['diary.history_legend', 'diary.history_add_entry']) {
        final entry = planDiaryStrings[key];
        expect(entry, isNotNull, reason: 'нет ключа $key');
        expect(entry!['en'], isNotNull, reason: 'нет en для $key');
        expect(entry['en'], isNotEmpty, reason: 'пустой en для $key');
        expect(entry['ru'], isNotNull, reason: 'нет ru для $key');
        expect(entry['ru'], isNotEmpty, reason: 'пустой ru для $key');
      }
    });
  });
}
