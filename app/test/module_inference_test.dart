// Юнит-тесты для inferModuleLink() — автоматического определения moduleLink
// по заголовку задачи.
//
// Покрываем: RU-слова, EN-слова, регистронезависимость, отсутствие совпадения,
// конкретные meal-слоты, граничные случаи (стем vs целое слово).

import 'package:app/core/utils/module_inference.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // workout
  // ---------------------------------------------------------------------------
  group('workout', () {
    test('тренировка → workout', () {
      expect(inferModuleLink('тренировка'), 'workout');
    });

    test('Утренняя тренировка → workout', () {
      expect(inferModuleLink('Утренняя тренировка'), 'workout');
    });

    test('трен (отдельное слово) → workout', () {
      expect(inferModuleLink('трен'), 'workout');
    });

    test('Утренний трен → workout', () {
      expect(inferModuleLink('Утренний трен'), 'workout');
    });

    test('тренд (НЕ workout — не является отдельным словом «трен»)', () {
      // «тренд» не должен срабатывать: «трен» — wholeWord, а в «тренд» нет правой границы после «трен»
      expect(inferModuleLink('тренд дня'), isNull);
    });

    test('качалка → workout', () {
      expect(inferModuleLink('качалка'), 'workout');
    });

    test('Пойти в спортзал → workout', () {
      expect(inferModuleLink('Пойти в спортзал'), 'workout');
    });

    test('отжимания → workout', () {
      expect(inferModuleLink('отжимания'), 'workout');
    });

    test('приседания → workout', () {
      expect(inferModuleLink('приседания'), 'workout');
    });

    test('пробежка → workout', () {
      expect(inferModuleLink('пробежка'), 'workout');
    });

    test('бег (отдельное слово) → workout', () {
      expect(inferModuleLink('утренний бег'), 'workout');
    });

    test('победа (НЕ workout — «бег» не является границей в «победа»)', () {
      expect(inferModuleLink('победа'), isNull);
    });

    test('берег (НЕ workout)', () {
      expect(inferModuleLink('берег моря'), isNull);
    });

    test('йога → workout', () {
      expect(inferModuleLink('Вечерняя йога'), 'workout');
    });

    // EN
    test('workout (EN) → workout', () {
      expect(inferModuleLink('Morning workout'), 'workout');
    });

    test('gym (EN, отдельное слово) → workout', () {
      expect(inferModuleLink('Go to gym'), 'workout');
    });

    test('run (EN, отдельное слово) → workout', () {
      expect(inferModuleLink('Morning run'), 'workout');
    });

    test('exercise (EN) → workout', () {
      expect(inferModuleLink('Daily exercise'), 'workout');
    });

    test('yoga (EN) → workout', () {
      expect(inferModuleLink('yoga class'), 'workout');
    });

    // Регистронезависимость
    test('ТРЕНИРОВКА (верхний регистр) → workout', () {
      expect(inferModuleLink('ТРЕНИРОВКА'), 'workout');
    });

    test('Workout (смешанный регистр) → workout', () {
      expect(inferModuleLink('Workout'), 'workout');
    });
  });

  // ---------------------------------------------------------------------------
  // meal:breakfast
  // ---------------------------------------------------------------------------
  group('meal:breakfast', () {
    test('завтрак → meal:breakfast', () {
      expect(inferModuleLink('завтрак'), 'meal:breakfast');
    });

    test('Приготовить завтрак → meal:breakfast', () {
      expect(inferModuleLink('Приготовить завтрак'), 'meal:breakfast');
    });

    test('breakfast (EN) → meal:breakfast', () {
      expect(inferModuleLink('breakfast'), 'meal:breakfast');
    });

    test('Have breakfast → meal:breakfast', () {
      expect(inferModuleLink('Have breakfast'), 'meal:breakfast');
    });

    test('ЗАВТРАК (верхний регистр) → meal:breakfast', () {
      expect(inferModuleLink('ЗАВТРАК'), 'meal:breakfast');
    });
  });

  // ---------------------------------------------------------------------------
  // meal:lunch
  // ---------------------------------------------------------------------------
  group('meal:lunch', () {
    test('обед → meal:lunch', () {
      expect(inferModuleLink('обед'), 'meal:lunch');
    });

    test('пообедать → meal:lunch', () {
      expect(inferModuleLink('пообедать'), 'meal:lunch');
    });

    test('Обедаю с друзьями → meal:lunch', () {
      expect(inferModuleLink('Обедаю с друзьями'), 'meal:lunch');
    });

    test('lunch (EN) → meal:lunch', () {
      expect(inferModuleLink('lunch'), 'meal:lunch');
    });

    test('Grab lunch → meal:lunch', () {
      expect(inferModuleLink('Grab lunch'), 'meal:lunch');
    });
  });

  // ---------------------------------------------------------------------------
  // meal:dinner
  // ---------------------------------------------------------------------------
  group('meal:dinner', () {
    test('ужин → meal:dinner', () {
      expect(inferModuleLink('ужин'), 'meal:dinner');
    });

    test('ужин с другом → meal:dinner', () {
      expect(inferModuleLink('ужин с другом'), 'meal:dinner');
    });

    test('Приготовить ужин → meal:dinner', () {
      expect(inferModuleLink('Приготовить ужин'), 'meal:dinner');
    });

    test('dinner (EN) → meal:dinner', () {
      expect(inferModuleLink('dinner'), 'meal:dinner');
    });

    test('supper (EN) → meal:dinner', () {
      expect(inferModuleLink('supper'), 'meal:dinner');
    });
  });

  // ---------------------------------------------------------------------------
  // sleep
  // ---------------------------------------------------------------------------
  group('sleep', () {
    test('сон → sleep', () {
      expect(inferModuleLink('сон'), 'sleep');
    });

    test('спать → sleep', () {
      expect(inferModuleLink('спать'), 'sleep');
    });

    test('поспать днём → sleep', () {
      expect(inferModuleLink('поспать днём'), 'sleep');
    });

    test('выспаться → sleep', () {
      expect(inferModuleLink('выспаться'), 'sleep');
    });

    test('лечь спать → sleep', () {
      expect(inferModuleLink('лечь спать'), 'sleep');
    });

    test('sleep (EN) → sleep', () {
      expect(inferModuleLink('sleep'), 'sleep');
    });

    test('nap (EN) → sleep', () {
      expect(inferModuleLink('afternoon nap'), 'sleep');
    });

    test('bedtime (EN) → sleep', () {
      expect(inferModuleLink('bedtime'), 'sleep');
    });

    test('sleeping (EN стем) → sleep', () {
      expect(inferModuleLink('Start sleeping'), 'sleep');
    });

    // Граничные случаи — слова, содержащие «сон» как подстроку, но НЕ целое слово
    test('соната (НЕ sleep — «сон» wholeWord)', () {
      expect(inferModuleLink('соната Бетховена'), isNull);
    });

    test('персональный тренер (НЕ workout и НЕ sleep — «тренер» не совпадает ни с одним ключом)', () {
      // «тренер» содержит «трен», но «трен» — wholeWord, а «тренер» не заканчивается границей после «трен».
      // «тренировк» — стем, не совпадает. Итого: null.
      expect(inferModuleLink('персональный тренер'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // null — нет совпадения
  // ---------------------------------------------------------------------------
  group('no match → null', () {
    test('Купить молоко → null', () {
      expect(inferModuleLink('Купить молоко'), isNull);
    });

    test('Позвонить маме → null', () {
      expect(inferModuleLink('Позвонить маме'), isNull);
    });

    test('пустая строка → null', () {
      expect(inferModuleLink(''), isNull);
    });

    test('Call me → null', () {
      expect(inferModuleLink('Call me'), isNull);
    });

    // «еда», «поесть» и т.п. без слота не определяют moduleLink
    test('поесть (без слота) → null', () {
      expect(inferModuleLink('поесть что-нибудь'), isNull);
    });

    test('еда → null', () {
      expect(inferModuleLink('еда готова'), isNull);
    });

    test('eat (EN, без слота) → null', () {
      expect(inferModuleLink('eat something'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Приоритет: первое совпадение побеждает
  // ---------------------------------------------------------------------------
  group('priority — первое совпадение', () {
    test('тренировка перед завтраком → workout (workout раньше в списке)', () {
      final result = inferModuleLink('тренировка перед завтраком');
      expect(result, 'workout');
    });

    test('завтрак после тренировки → workout (workout раньше в списке)', () {
      // workout-ключевые слова стоят раньше meal:breakfast в _kInferenceKeywords
      final result = inferModuleLink('завтрак после тренировки');
      expect(result, 'workout');
    });
  });

  // ---------------------------------------------------------------------------
  // Параметр type (пока не влияет на результат — reserved для будущего)
  // ---------------------------------------------------------------------------
  group('type parameter (no-op currently)', () {
    test('workout с type=task → workout', () {
      expect(inferModuleLink('тренировка', type: 'task'), 'workout');
    });

    test('без ключевых слов с type=event → null', () {
      expect(inferModuleLink('лекция по физике', type: 'event'), isNull);
    });
  });
}
