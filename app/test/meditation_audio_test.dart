// Виджет-тест аудио-управления в плеере медитаций (ADR-054 Phase 1).
//
// Проверяем (на 320px + textScaleFactor 2.0, как требует app/CLAUDE.md §B):
//   1) панель аудио раскрывается иконкой и не вызывает overflow;
//   2) тумблеры озвучки и эмбиента переключаются без исключений;
//   3) состояния тумблеров и громкость пишутся в SharedPreferences.
//
// Реальные flutter_tts/audioplayers НЕ дёргаются: провайдеры озвучки и эмбиента
// переопределены на Silent*-фейки → платформенные каналы не вызываются.

import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:app/features/health/meditation_audio.dart';
import 'package:app/features/health/meditation_custom_providers.dart';
import 'package:app/features/health/meditation_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpAndOpenPlayer(
  WidgetTester tester,
  SharedPreferences prefs, {
  required double width,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Без пользовательских сессий — нужны только встроенные.
        customMeditationsProvider
            .overrideWith((ref) => Stream.value(const <CustomMeditation>[])),
        // Фейки аудио: никакого реального TTS/проигрывания в юнит-тесте.
        meditationNarratorProvider
            .overrideWithValue(const SilentMeditationNarrator()),
        meditationAmbientPlayerProvider
            .overrideWithValue(const SilentMeditationAmbientPlayer()),
      ],
      child: MaterialApp(
        theme: AppTheme.focusTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const MeditationScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // Список → превью позы → плеер.
  await tester.tap(find.text('Body Scan'));
  await tester.pumpAndSettle();
  // На узком экране при крупном шрифте (320px, scale 2.0) контент превью позы
  // прокручивается, и кнопка «Start» может оказаться ниже сгиба — подматываем,
  // иначе тап промахивается (warnIfMissed) и мы остаёмся на экране позы.
  await tester.ensureVisible(find.text('Start'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start'));
  // НЕ pumpAndSettle: плеер бесконечно крутит Timer.periodic + дугу — settle
  // зависнет. Но pushReplacement-переходу нужно дать доехать (~300мс): пока он
  // едет, AppBar с кнопкой «Sound» стоит у правого края экрана и тап по ней
  // промахивается (центр уезжает за пределы 320–360px). 400мс < 1с, поэтому
  // секундный Timer ещё не тикнет и шаг не сменится.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _endSession(WidgetTester tester) async {
  // Закрываем плеер, чтобы dispose отменил таймер (иначе pending Timer).
  await tester.ensureVisible(find.text('End session'));
  await tester.tap(find.text('End session'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'аудио-панель: тумблеры переключаются и пишутся в prefs (320px, scale 2.0)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await _pumpAndOpenPlayer(tester, prefs, width: 320, textScale: 2.0);

      // Панель скрыта по умолчанию.
      expect(find.text('Narration'), findsNothing);

      // Раскрываем панель аудио через иконку в AppBar.
      await tester.tap(find.byTooltip('Sound'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Narration'), findsOneWidget);
      expect(find.text('Ambient sound'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Включаем озвучку.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Narration'));
      await tester.pump(const Duration(milliseconds: 300));

      // Включаем эмбиент — появляется слайдер громкости.
      await tester.tap(find.widgetWithText(SwitchListTile, 'Ambient sound'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Volume'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Никакого overflow/исключений на 320px при textScale 2.0.
      expect(tester.takeException(), isNull);

      // Настройки сохранены в SharedPreferences.
      expect(prefs.getBool(kMeditationNarrationEnabledKey), isTrue);
      expect(prefs.getBool(kMeditationAmbientEnabledKey), isTrue);

      await _endSession(tester);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('сохранённые настройки восстанавливаются при открытии плеера',
      (tester) async {
    // Эмбиент заранее включён с громкостью 0.7.
    SharedPreferences.setMockInitialValues(<String, Object>{
      kMeditationAmbientEnabledKey: true,
      kMeditationAmbientVolumeKey: 0.7,
    });
    final prefs = await SharedPreferences.getInstance();

    await _pumpAndOpenPlayer(tester, prefs, width: 360, textScale: 1.0);

    // Раскрываем панель — эмбиент уже включён, слайдер на месте, проценты 70%.
    await tester.tap(find.byTooltip('Sound'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _endSession(tester);
    expect(tester.takeException(), isNull);
  });
}
