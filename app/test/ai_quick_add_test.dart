// Тесты ИИ-квик-адда (Волна 6, этап 2, ai_quick_add_sheet.dart).
//
// 1) Юнит-тесты чистой функции parseQuickAddResponse (маппинг deadline —
//    решение C, note→AddTaskPrefill.note, пустой заголовок → null).
// 2) Виджет-тесты листа: рендер 320px + textScale 2.0 без overflow;
//    успешный путь (ввод → отправка → превью-подтверждение add_task_sheet
//    открывается ПРЕДЗАПОЛНЕННЫМ); ошибка API (503) → снекбар с retry.
//
// Харнесс (ProviderScope + in-memory Drift + SharedPreferences) скопирован
// из ai_workout_sheet_test.dart. isPremiumProvider переопределяется напрямую
// (как в paywall_screen_test.dart) — без дурного возни с prefs-датами.

import 'package:app/core/database/database.dart';
import 'package:app/core/database/database_providers.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart' show sharedPreferencesProvider;
import 'package:app/features/auth/auth_controller.dart' show isPremiumProvider;
import 'package:app/features/today/widgets/ai_quick_add_sheet.dart';
import 'package:app/services/api/api_client.dart';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Мок платформенного канала flutter_timezone (харнесс-фикс — канал
/// недоступен в тесте, как path_provider в interaction_smoke_test.dart).
/// resolveQuickAddTimezone в проде уже ловит любую ошибку канала и падает
/// на 'UTC', но немок-канал в некоторых версиях binding не отвечает вовсе —
/// мокаем явно, чтобы тест не зависел от этой неопределённости.
void _mockFlutterTimezone() {
  const channel = MethodChannel('flutter_timezone');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async => 'UTC');
}

ThemeData _testTheme() {
  return ThemeData.dark().copyWith(
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
}

/// Фейковый ApiClient: aiQuickAdd возвращает заготовленный ответ или бросает
/// заготовленную ошибку — сеть НЕ трогаем.
class _FakeApiClient extends ApiClient {
  _FakeApiClient(super.prefs, {this.response, this.error});

  final Map<String, dynamic>? response;
  final ApiException? error;

  @override
  Future<Map<String, dynamic>> aiQuickAdd({
    required String text,
    required String date,
    required String timezone,
    String? locale,
  }) async {
    if (error != null) throw error!;
    return response!;
  }
}

void main() {
  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    _mockFlutterTimezone();
  });

  tearDown(() async {
    await db.close();
  });

  // Крошечный харнесс: кнопка, открывающая лист через showAiQuickAddSheet.
  Widget harness(
    ApiClient apiClient, {
    bool premium = true,
    Size size = const Size(400, 800),
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(apiClient),
        isPremiumProvider.overrideWith((ref) async => premium),
      ],
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(textScale)),
        child: MaterialApp(
          theme: _testTheme(),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: ElevatedButton(
                  onPressed: () => showAiQuickAddSheet(context, ref),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Открывает лист (тап + прогон async premium-гейта + анимация открытия).
  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pump(); // запускает showAiQuickAddSheet
    await tester.pump(); // резолвит isPremiumProvider.future
    await tester.pump(const Duration(milliseconds: 350)); // анимация листа
  }

  group('parseQuickAddResponse (чистая функция)', () {
    test('обычная задача с scheduled_at', () {
      final prefill = parseQuickAddResponse({
        'task': {
          'title': 'Buy milk',
          'type': 'task',
          'priority': 'medium',
          'scheduled_at': '2026-07-03T10:00:00.000Z',
          'duration_minutes': 15,
        },
      });
      expect(prefill, isNotNull);
      expect(prefill!.title, 'Buy milk');
      expect(prefill.type, 'task');
      expect(prefill.priority, 'medium');
      expect(prefill.durationMinutes, 15);
      expect(prefill.scheduledAt, isNotNull);
    });

    test('deadline без scheduled_at → type=deadline, scheduledAt=deadline (решение C)', () {
      final prefill = parseQuickAddResponse({
        'task': {
          'title': 'Submit report',
          'type': 'task',
          'priority': 'high',
          'deadline': '2026-07-10T23:59:00.000Z',
        },
      });
      expect(prefill, isNotNull);
      expect(prefill!.type, 'deadline');
      expect(
        prefill.scheduledAt,
        DateTime.parse('2026-07-10T23:59:00.000Z').toLocal(),
      );
    });

    test('scheduled_at имеет приоритет над deadline, если оба заданы', () {
      final prefill = parseQuickAddResponse({
        'task': {
          'title': 'Both',
          'scheduled_at': '2026-07-05T09:00:00.000Z',
          'deadline': '2026-07-10T23:59:00.000Z',
          'type': 'event',
        },
      });
      expect(prefill!.type, 'event'); // НЕ перезаписан в deadline
      expect(
        prefill.scheduledAt,
        DateTime.parse('2026-07-05T09:00:00.000Z').toLocal(),
      );
    });

    test('note маппится в AddTaskPrefill.note (место/детали)', () {
      final prefill = parseQuickAddResponse({
        'task': {'title': 'Meeting', 'note': 'Butovo office'},
      });
      expect(prefill!.note, 'Butovo office');
    });

    test('пустой/отсутствующий заголовок → null', () {
      expect(parseQuickAddResponse({'task': {'title': ''}}), isNull);
      expect(parseQuickAddResponse({'task': {'title': '   '}}), isNull);
      expect(parseQuickAddResponse({}), isNull);
      expect(parseQuickAddResponse({'task': 'not a map'}), isNull);
    });
  });

  testWidgets('320px + textScale 2.0 — рендер без overflow', (tester) async {
    await tester.pumpWidget(harness(
      _FakeApiClient(prefs, response: const {
        'task': {'title': 'x'},
      }),
      size: const Size(320, 700),
      textScale: 2.0,
    ));
    await tester.pump();

    await openSheet(tester);

    // Лист открылся — заголовок виден, overflow не бросился (pump бы упал).
    expect(find.text('AI quick add'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets(
      'успешный путь: ввод → отправка → превью-подтверждение открывается предзаполненным',
      (tester) async {
    await tester.pumpWidget(harness(_FakeApiClient(
      prefs,
      response: const {
        'task': {
          'title': 'Buy milk',
          'type': 'task',
          'priority': 'medium',
          'duration_minutes': 20,
        },
      },
    )));
    await tester.pump();

    await openSheet(tester);
    expect(find.text('AI quick add'), findsOneWidget);

    // Вводим текст (голосовое поле — обычный TextField снаружи).
    await tester.enterText(find.byType(TextField).first, 'buy milk tomorrow');
    await tester.pump();

    // Тап «Add with AI». Несколько «пустых» pump прогоняют цепочку await
    // внутри _send (resolveQuickAddTimezone → locale/date → aiQuickAdd → pop).
    await tester.tap(find.text('Add with AI'));
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 350)); // закрытие квик-адд листа
    await tester.pump(const Duration(milliseconds: 350)); // открытие add_task_sheet

    // Превью-подтверждение — это AddTaskSheet ("New task"), предзаполненный.
    expect(find.text('New task'), findsOneWidget);
    expect(find.text('Buy milk'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('ошибка API (503) → снекбар с текстом ошибки и кнопкой Retry',
      (tester) async {
    await tester.pumpWidget(harness(_FakeApiClient(
      prefs,
      error: const ApiException('Service unavailable', 503),
    )));
    await tester.pump();

    await openSheet(tester);

    await tester.enterText(find.byType(TextField).first, 'meeting at 5pm');
    await tester.pump();

    await tester.tap(find.text('Add with AI'));
    // Несколько «пустых» pump — прогоняем цепочку await внутри _send
    // (resolveQuickAddTimezone → locale/date → aiQuickAdd → catch → setState).
    for (var i = 0; i < 6; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300)); // снекбар анимация

    expect(find.text('AI is unavailable right now. Try again.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // Лист НЕ закрылся — заголовок листа всё ещё виден.
    expect(find.text('AI quick add'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}
