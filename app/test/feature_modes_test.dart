// Юнит-тесты для feature_modes_provider.dart.
// Проверяем: дефолт = false; после set(true) значение сохраняется
// при пересоздании ProviderContainer (тот же SharedPreferences-мок).
// Тестируются все 5 провайдеров (включая waterModeProvider).

import 'package:app/core/settings/feature_modes_provider.dart';
import 'package:app/core/theme/theme_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('feature_modes_provider — дефолт false', () {
    test('nutritionModeProvider: дефолт = false при пустых prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(nutritionModeProvider), isFalse);
    });

    test('workoutModeProvider: дефолт = false при пустых prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(workoutModeProvider), isFalse);
    });

    test('meditationLibraryModeProvider: дефолт = false при пустых prefs',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(meditationLibraryModeProvider), isFalse);
    });

    test('breathingEditorModeProvider: дефолт = false при пустых prefs',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(breathingEditorModeProvider), isFalse);
    });

    test('waterModeProvider: дефолт = false при пустых prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(waterModeProvider), isFalse);
    });
  });

  group('feature_modes_provider — персистентность', () {
    // Ключевой тест по ТЗ: set(true) → пересоздание контейнера → значение true
    test(
        'nutritionModeProvider: set(true) сохраняется при пересоздании провайдера',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Первый контейнер — записываем значение.
      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container1.dispose);

      expect(container1.read(nutritionModeProvider), isFalse);
      await container1.read(nutritionModeProvider.notifier).set(true);
      expect(container1.read(nutritionModeProvider), isTrue);

      // Второй контейнер с тем же prefs-экземпляром — значение должно быть true.
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(nutritionModeProvider), isTrue);
    });

    test('workoutModeProvider: set(true) сохраняется при пересоздании провайдера',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container1.dispose);

      await container1.read(workoutModeProvider.notifier).set(true);
      expect(container1.read(workoutModeProvider), isTrue);

      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(workoutModeProvider), isTrue);
    });

    test(
        'meditationLibraryModeProvider: set(true) сохраняется при пересоздании провайдера',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container1.dispose);

      await container1.read(meditationLibraryModeProvider.notifier).set(true);
      expect(container1.read(meditationLibraryModeProvider), isTrue);

      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(meditationLibraryModeProvider), isTrue);
    });

    test(
        'breathingEditorModeProvider: set(true) сохраняется при пересоздании провайдера',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container1.dispose);

      await container1.read(breathingEditorModeProvider.notifier).set(true);
      expect(container1.read(breathingEditorModeProvider), isTrue);

      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(breathingEditorModeProvider), isTrue);
    });

    test('waterModeProvider: set(true) сохраняется при пересоздании провайдера',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container1.dispose);

      await container1.read(waterModeProvider.notifier).set(true);
      expect(container1.read(waterModeProvider), isTrue);

      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container2.dispose);

      expect(container2.read(waterModeProvider), isTrue);
    });
  });

  group('feature_modes_provider — toggle', () {
    test('toggle переключает с false на true и обратно', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // Начальное состояние — false.
      expect(container.read(nutritionModeProvider), isFalse);

      // Первый toggle → true.
      await container.read(nutritionModeProvider.notifier).toggle();
      expect(container.read(nutritionModeProvider), isTrue);

      // Второй toggle → false.
      await container.read(nutritionModeProvider.notifier).toggle();
      expect(container.read(nutritionModeProvider), isFalse);
    });
  });

  group('feature_modes_provider — разные ключи не конфликтуют', () {
    test('все 5 ключей независимы', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      // Включаем только один флаг.
      await container.read(nutritionModeProvider.notifier).set(true);

      // Остальные должны остаться false.
      expect(container.read(nutritionModeProvider), isTrue);
      expect(container.read(workoutModeProvider), isFalse);
      expect(container.read(meditationLibraryModeProvider), isFalse);
      expect(container.read(breathingEditorModeProvider), isFalse);
      expect(container.read(waterModeProvider), isFalse);
    });
  });
}
