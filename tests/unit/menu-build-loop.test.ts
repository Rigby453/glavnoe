/**
 * ADR-046: bounded validation + re-prompt loop в buildMenu.
 * Мокаем provider.generateText (никаких реальных вызовов модели) и прогоняем
 * НАСТОЯЩУЮ логику buildMenu: серверный расчёт итогов, ретрай при промахе,
 * cap в 1 ретрай, off_target, распределение по приёмам.
 *
 * Также проверяем толерантное матчинг имён (A-fix): Gemini возвращает имена
 * в другом регистре/с пробелами — должны матчиться и возвращать canonical name.
 */
import { buildMenu, normalizeName } from '../../backend/src/ai/menuBuild';

// generateText замокан — он же используется внутри buildMenu через callAndClean.
jest.mock('../../backend/src/ai/provider', () => {
  const actual = jest.requireActual('../../backend/src/ai/provider');
  return {
    ...actual,
    generateText: jest.fn(),
  };
});

// eslint-disable-next-line @typescript-eslint/no-var-requires
const { generateText } = require('../../backend/src/ai/provider') as {
  generateText: jest.Mock;
};

// Простые кандидаты с известными per-100g, чтобы итоги были предсказуемыми.
// "Chicken": на 100 г = 200 kcal / 30 P / 8 F / 0 C / 0 sugar / 0 fiber.
// "Rice":    на 100 г = 100 kcal / 2 P / 0 F / 22 C / 0 sugar / 1 fiber.
// "Broccoli":на 100 г = 35 kcal / 3 P / 0 F / 7 C / 1.5 sugar / 3 fiber.
const candidates = [
  { name: 'Chicken', per100g: { calories: 200, protein: 30, fat: 8, carbs: 0, sugar: 0, fiber: 0 } },
  { name: 'Rice', per100g: { calories: 100, protein: 2, fat: 0, carbs: 22, sugar: 0, fiber: 1 } },
  { name: 'Broccoli', per100g: { calories: 35, protein: 3, fat: 0, carbs: 7, sugar: 1.5, fiber: 3 } },
  { name: 'Egg', per100g: { calories: 150, protein: 13, fat: 11, carbs: 1, sugar: 0, fiber: 0 } },
  { name: 'Oats', per100g: { calories: 380, protein: 13, fat: 7, carbs: 67, sugar: 1, fiber: 10 } },
];

function menuJson(meals: { meal: string; items: { name: string; grams: number }[] }[]): string {
  return JSON.stringify({ meals, note: 'ok' });
}

beforeEach(() => {
  generateText.mockReset();
});

test('re-prompts exactly once when first response is off-target, accepts the second', async () => {
  // Цели: 2000 kcal, 75 P. Первая раскладка сильно мимо по калориям (низко).
  const offTarget = menuJson([
    { meal: 'breakfast', items: [{ name: 'Rice', grams: 100 }] }, // 100 kcal, 2 P
  ]);
  // Вторая раскладка попадает: Chicken 300 (600/90) + Rice 1400→cap... используем
  // несколько позиций в пределах 30..500 г/кратно 10.
  // Chicken 250g = 500kcal/75P; Oats 300g = 1140kcal/39P→ перебор. Подберём:
  // Chicken 250 (500/75), Rice 500 (500/10), Oats 250 (950/32.5) = 1950 kcal / ~117 P.
  // Калории 1950 в ±5% от 2000 (1900..2100) — ок; белок ≥ 75 — ок.
  const onTarget = menuJson([
    { meal: 'breakfast', items: [{ name: 'Oats', grams: 250 }] },
    { meal: 'lunch', items: [{ name: 'Chicken', grams: 250 }] },
    { meal: 'dinner', items: [{ name: 'Rice', grams: 500 }] },
  ]);

  generateText.mockResolvedValueOnce(offTarget).mockResolvedValueOnce(onTarget);

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  expect(generateText).toHaveBeenCalledTimes(2); // ровно один ретрай
  expect(result.offTarget).toBe(false);
  // Итоги посчитаны КОДОМ из per-100g (а не взяты у модели).
  expect(result.totals.calories).toBeGreaterThanOrEqual(1900);
  expect(result.totals.calories).toBeLessThanOrEqual(2100);
  expect(result.totals.protein).toBeGreaterThanOrEqual(75);
});

test('correction hint is included in the retry user prompt', async () => {
  const off = menuJson([{ meal: 'breakfast', items: [{ name: 'Rice', grams: 100 }] }]);
  const onTarget = menuJson([
    { meal: 'breakfast', items: [{ name: 'Oats', grams: 250 }] },
    { meal: 'lunch', items: [{ name: 'Chicken', grams: 250 }] },
    { meal: 'dinner', items: [{ name: 'Rice', grams: 500 }] },
  ]);
  generateText.mockResolvedValueOnce(off).mockResolvedValueOnce(onTarget);

  await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  const secondCallUser = generateText.mock.calls[1]![0].user as string;
  expect(secondCallUser).toContain('CORRECTION');
  expect(secondCallUser).toContain('Calories');
});

test('caps at 1 retry (max 2 calls) and sets off_target when still off', async () => {
  // Обе попытки заведомо мимо (только 100 kcal при цели 2000).
  const off = menuJson([{ meal: 'breakfast', items: [{ name: 'Rice', grams: 100 }] }]);
  generateText.mockResolvedValue(off);

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  expect(generateText).toHaveBeenCalledTimes(2); // не больше 2 — нет бесконечного цикла
  expect(result.offTarget).toBe(true);
  expect(result.totals.calories).toBeLessThan(2000); // лучшая (единственная) попытка
});

test('no retry when first response already within tolerance (single call)', async () => {
  const onTarget = menuJson([
    { meal: 'breakfast', items: [{ name: 'Oats', grams: 250 }] },
    { meal: 'lunch', items: [{ name: 'Chicken', grams: 250 }] },
    { meal: 'dinner', items: [{ name: 'Rice', grams: 500 }] },
  ]);
  generateText.mockResolvedValueOnce(onTarget);

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  expect(generateText).toHaveBeenCalledTimes(1); // ретрай не понадобился
  expect(result.offTarget).toBe(false);
});

test('full macro targets (fat/carbs/sugar/fiber) appear in the system prompt', async () => {
  const someMenu = menuJson([
    { meal: 'breakfast', items: [{ name: 'Oats', grams: 250 }] },
    { meal: 'lunch', items: [{ name: 'Chicken', grams: 250 }] },
    { meal: 'dinner', items: [{ name: 'Rice', grams: 500 }] },
  ]);
  // Любой вызов (включая возможный ретрай) отдаёт валидный JSON — здесь нас
  // интересует только содержимое промпта, не попадание в цели.
  generateText.mockResolvedValue(someMenu);

  await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    fatGoalG: 65,
    carbsGoalG: 250,
    sugarMaxG: 40,
    fiberMinG: 25,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  const system = generateText.mock.calls[0]![0].system as string;
  expect(system).toContain('Fat: 65');
  expect(system).toContain('Carbs: 250');
  expect(system).toContain('Sugar');
  expect(system).toContain('Fiber');
  expect(system).toMatch(/whole.*food/i); // предпочтение цельной еды
});

test('meals count honored: meals_per_day expands meal slots and distributes foods', async () => {
  // Просим 4 приёма через meals_per_day, передав только 1 имя в meals[].
  // Модель «вернёт» 4 слота — buildMenu должен принять все 4 (имена из resolveMealNames).
  const fourMeals = menuJson([
    { meal: 'breakfast', items: [{ name: 'Oats', grams: 100 }] },
    { meal: 'lunch', items: [{ name: 'Chicken', grams: 200 }] },
    { meal: 'dinner', items: [{ name: 'Rice', grams: 200 }] },
    { meal: 'snack', items: [{ name: 'Broccoli', grams: 100 }] },
  ]);
  generateText.mockResolvedValueOnce(fourMeals).mockResolvedValueOnce(fourMeals);

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast'],
    tone: 'gentle',
    foodPrefs: { mealsPerDay: 4 },
  });

  // Системный промпт должен просить ровно 4 приёма с дополненными именами.
  const system = generateText.mock.calls[0]![0].system as string;
  expect(system).toContain('breakfast, lunch, dinner, snack');
  // Все 4 слота с едой сохранены (не свалено в один приём).
  const nonEmpty = result.meals.filter((m) => m.items.length > 0);
  expect(nonEmpty.length).toBe(4);
});

test('parses menu JSON wrapped in markdown fences', async () => {
  const inner = JSON.stringify({
    meals: [
      { meal: 'breakfast', items: [{ name: 'Oats', grams: 250 }] },
      { meal: 'lunch', items: [{ name: 'Chicken', grams: 250 }] },
      { meal: 'dinner', items: [{ name: 'Rice', grams: 500 }] },
    ],
    note: 'ok',
  });
  generateText.mockResolvedValueOnce('```json\n' + inner + '\n```');

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });
  expect(result.meals.length).toBe(3);
});

test('extracts the first balanced JSON object when prose surrounds it', async () => {
  const inner = JSON.stringify({
    meals: [
      { meal: 'breakfast', items: [{ name: 'Oats', grams: 250 }] },
      { meal: 'lunch', items: [{ name: 'Chicken', grams: 250 }] },
      { meal: 'dinner', items: [{ name: 'Rice', grams: 500 }] },
    ],
    note: 'ok',
  });
  // Модель добавила болтовню до и после JSON — JSON.parse упадёт,
  // должен сработать balanced-object fallback.
  generateText.mockResolvedValueOnce(
    'Here is your menu: ' + inner + ' Enjoy your day!'
  );

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });
  expect(result.meals.length).toBe(3);
});

test('throws unparseable JSON error when no JSON object is present', async () => {
  generateText.mockResolvedValue('Sorry, I cannot help with that.');

  await expect(
    buildMenu({
      candidates,
      calorieGoal: 2000,
      proteinGoalG: 75,
      meals: ['breakfast', 'lunch', 'dinner'],
      tone: 'gentle',
    })
  ).rejects.toThrow('unparseable JSON');
});

test('totals are computed by code from candidates, never taken from the model', async () => {
  // Модель НЕ возвращает чисел КБЖУ — только name+grams. Проверяем точный расчёт:
  // Chicken 100g = 200 kcal / 30 P / 8 F.
  const single = menuJson([{ meal: 'breakfast', items: [{ name: 'Chicken', grams: 100 }] }]);
  generateText.mockResolvedValue(single); // обе попытки одинаковы (заведомо off-target)

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  expect(result.totals.calories).toBe(200);
  expect(result.totals.protein).toBe(30);
  expect(result.totals.fat).toBe(8);
});

// ---------------------------------------------------------------------------
// A-fix: толерантное матчинг имён (регистр / пробелы / локализация Gemini)
// ---------------------------------------------------------------------------

test('normalizeName: trim, lowercase, collapse whitespace', () => {
  expect(normalizeName('  Chicken Breast  ')).toBe('chicken breast');
  expect(normalizeName('OATS')).toBe('oats');
  expect(normalizeName('brown  rice')).toBe('brown rice');
  expect(normalizeName('greek  yogurt ')).toBe('greek yogurt');
});

test('name matching is tolerant: model casing/whitespace normalized to canonical name', async () => {
  // Кандидат в БД — "Chicken Breast" (с заглавными). Gemini вернул разные варианты.
  const candidatesBreast = [
    { name: 'Chicken Breast', per100g: { calories: 165, protein: 31, fat: 3.6, carbs: 0, sugar: 0, fiber: 0 } },
    { name: 'Rice',           per100g: { calories: 100, protein: 2,  fat: 0,   carbs: 22, sugar: 0, fiber: 1 } },
    { name: 'Egg',            per100g: { calories: 150, protein: 13, fat: 11,  carbs: 1,  sugar: 0, fiber: 0 } },
    { name: 'Oats',           per100g: { calories: 380, protein: 13, fat: 7,   carbs: 67, sugar: 1, fiber: 10 } },
    { name: 'Broccoli',       per100g: { calories: 35,  protein: 3,  fat: 0,   carbs: 7,  sugar: 1.5, fiber: 3 } },
  ];

  // Модель вернула имена: лишние пробелы + другой регистр
  const modelResponse = JSON.stringify({
    meals: [
      // "  chicken breast  " → должен смэтчиться с "Chicken Breast"
      { meal: 'breakfast', items: [{ name: '  chicken breast  ', grams: 200 }] },
      { meal: 'lunch',     items: [{ name: 'Rice', grams: 300 }] },
      // "EGG" → должен смэтчиться с "Egg"
      { meal: 'dinner',    items: [{ name: 'EGG', grams: 100 }] },
    ],
    note: 'ok',
  });
  generateText.mockResolvedValue(modelResponse);

  const result = await buildMenu({
    candidates: candidatesBreast,
    calorieGoal: 1500,
    proteinGoalG: 50,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  // "  chicken breast  " → canonical "Chicken Breast"
  const breakfast = result.meals.find((m) => m.meal === 'breakfast');
  expect(breakfast?.items[0]?.name).toBe('Chicken Breast');

  // "EGG" → canonical "Egg"
  const dinner = result.meals.find((m) => m.meal === 'dinner');
  expect(dinner?.items[0]?.name).toBe('Egg');

  // КБЖУ посчитаны корректно — имена не выброшены, byName находит кандидатов
  expect(result.totals.protein).toBeGreaterThan(0);
  expect(result.totals.calories).toBeGreaterThan(0);
});

test('items with completely unrecognized names are discarded even after normalization', async () => {
  // Галлюцинация: "Grilled Unicorn" — вообще нет среди кандидатов → выбрасываем.
  // Остальные позиции (реальные кандидаты) — сохраняем.
  const mixedResponse = JSON.stringify({
    meals: [
      {
        meal: 'breakfast',
        items: [
          { name: 'Oats',           grams: 100 }, // валидный
          { name: 'Grilled Unicorn', grams: 200 }, // галлюцинация
        ],
      },
      { meal: 'lunch',  items: [{ name: 'Chicken', grams: 200 }] },
      { meal: 'dinner', items: [{ name: 'Rice', grams: 300 }] },
    ],
    note: 'ok',
  });
  generateText.mockResolvedValue(mixedResponse);

  const result = await buildMenu({
    candidates,
    calorieGoal: 2000,
    proteinGoalG: 75,
    meals: ['breakfast', 'lunch', 'dinner'],
    tone: 'gentle',
  });

  const breakfast = result.meals.find((m) => m.meal === 'breakfast');
  // Только "Oats" остался; "Grilled Unicorn" выброшен
  expect(breakfast?.items).toHaveLength(1);
  expect(breakfast?.items[0]?.name).toBe('Oats');
});
