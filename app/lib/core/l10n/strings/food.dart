// Строки модуля Food (Ф1, SPEC C5).
// Ключи btn.* / food.add / food.search_hint / food.nothing_today / health.food
// определены в common.dart — здесь их НЕ повторяем, просто вызываем context.s().
const Map<String, Map<String, String>> foodStrings = {
  // ---------------------------------------------------------------------------
  // Общий экран Food
  // ---------------------------------------------------------------------------
  'food.my_recipes_tooltip': {
    'en': 'My recipes',
    'ru': 'Мои рецепты',
    'de': 'Meine Rezepte',
  },
  'food.shopping_list_tooltip': {
    'en': 'Shopping list',
    'ru': 'Список покупок',
    'de': 'Einkaufsliste',
  },
  'food.totals_today': {
    'en': 'Today',
    'ru': 'Сегодня',
    'de': 'Heute',
  },
  'food.macro_protein': {
    'en': 'Protein',
    'ru': 'Белки',
    'de': 'Eiweiß',
  },
  'food.macro_fat': {
    'en': 'Fat',
    'ru': 'Жиры',
    'de': 'Fette',
  },
  'food.macro_carbs': {
    'en': 'Carbs',
    'ru': 'Углеводы',
    'de': 'Kohlenhydrate',
  },
  'food.remove_tooltip': {
    'en': 'Remove',
    'ru': 'Убрать',
    'de': 'Entfernen',
  },
  // ---------------------------------------------------------------------------
  // Баланс рациона
  // ---------------------------------------------------------------------------
  'food.balance_title': {
    'en': 'Balance',
    'ru': 'Баланс',
    'de': 'Balance',
  },
  'food.balance_ok': {
    'en': 'Nicely balanced today — calories, protein, fiber and sugar all on track.',
    'ru': 'Отличный баланс — калории, белки, клетчатка и сахар в норме.',
    'de': 'Super ausgewogen heute — Kalorien, Eiweiß, Ballaststoffe und Zucker passen.',
  },
  // Подсказки (ключи хранятся в DayBalance.hints, резолвятся в UI)
  'food.hint_cal_low': {
    'en': "You're under your calorie goal — one more proper meal could help.",
    'ru': 'Ты немного не добрал(а) по калориям — ещё один нормальный приём пищи не помешает.',
    'de': 'Du bist unter deinem Kalorienziel — eine weitere Mahlzeit könnte helfen.',
  },
  'food.hint_cal_high': {
    'en': 'A bit over the calorie goal today — tomorrow is a fresh start.',
    'ru': 'Сегодня немного перебор по калориям — завтра начнём заново.',
    'de': 'Heute etwas über dem Kalorienziel — morgen ist ein neuer Anfang.',
  },
  'food.hint_protein_low': {
    'en': 'Protein is a bit low — eggs, dairy, fish or beans could help.',
    'ru': 'Белков маловато — попробуй яйца, молочку, рыбу или бобовые.',
    'de': 'Etwas wenig Eiweiß — Eier, Milchprodukte, Fisch oder Hülsenfrüchte helfen.',
  },
  'food.hint_fiber_low': {
    'en': 'Add some fiber — veggies, fruit or whole grains.',
    'ru': 'Добавь клетчатки — овощи, фрукты или цельнозерновые.',
    'de': 'Mehr Ballaststoffe — Gemüse, Obst oder Vollkornprodukte.',
  },
  'food.hint_sugar_high': {
    'en': 'Sugar is above the guideline — maybe swap one sweet snack.',
    'ru': 'Сахара больше нормы — попробуй заменить один сладкий перекус.',
    'de': 'Zucker über dem Richtwert — vielleicht einen Süßsnack tauschen.',
  },
  // ---------------------------------------------------------------------------
  // Поиск продукта / лист добавления
  // ---------------------------------------------------------------------------
  'food.voice_input': {
    'en': 'Voice input',
    'ru': 'Голосовой ввод',
    'de': 'Spracheingabe',
  },
  'food.voice_stop': {
    'en': 'Stop listening',
    'ru': 'Остановить',
    'de': 'Aufnahme stoppen',
  },
  'food.scan_barcode_tooltip': {
    'en': 'Scan barcode',
    'ru': 'Сканировать штрихкод',
    'de': 'Barcode scannen',
  },
  'food.ai_photo_btn': {
    'en': 'AI photo (Premium)',
    'ru': 'ИИ-фото (Премиум)',
    'de': 'KI-Foto (Premium)',
  },
  'food.speech_unavailable': {
    'en': 'Speech recognition is not available on this device',
    'ru': 'Распознавание речи недоступно на этом устройстве',
    'de': 'Spracherkennung ist auf diesem Gerät nicht verfügbar',
  },
  'food.nothing_found': {
    'en': 'Nothing found',
    'ru': 'Ничего не найдено',
    'de': 'Nichts gefunden',
  },
  'food.unknown_product': {
    'en': 'Unknown',
    'ru': 'Неизвестно',
    'de': 'Unbekannt',
  },
  'food.ai_photo_premium_msg': {
    'en': 'Premium feature — AI recognizes food photos',
    'ru': 'Функция Премиума — ИИ распознаёт фото еды',
    'de': 'Premium-Funktion — KI erkennt Essensfotos',
  },
  'food.upgrade_btn': {
    'en': 'Upgrade',
    'ru': 'Перейти',
    'de': 'Upgraden',
  },
  'food.ai_photo_fail': {
    'en': "Couldn't recognize the food — try again",
    'ru': 'Не удалось распознать еду — попробуй ещё раз',
    'de': 'Essen konnte nicht erkannt werden — erneut versuchen',
  },
  // ---------------------------------------------------------------------------
  // Диалог порции
  // ---------------------------------------------------------------------------
  'food.grams_label': {
    'en': 'Grams',
    'ru': 'Граммы',
    'de': 'Gramm',
  },
  'food.meal_breakfast': {
    'en': 'breakfast',
    'ru': 'завтрак',
    'de': 'Frühstück',
  },
  'food.meal_lunch': {
    'en': 'lunch',
    'ru': 'обед',
    'de': 'Mittagessen',
  },
  'food.meal_dinner': {
    'en': 'dinner',
    'ru': 'ужин',
    'de': 'Abendessen',
  },
  'food.meal_snack': {
    'en': 'snack',
    'ru': 'перекус',
    'de': 'Snack',
  },
  // ---------------------------------------------------------------------------
  // Список покупок
  // ---------------------------------------------------------------------------
  'food.shopping_list_title': {
    'en': 'Shopping list',
    'ru': 'Список покупок',
    'de': 'Einkaufsliste',
  },
  'food.clear_checked': {
    'en': 'Clear checked',
    'ru': 'Убрать отмеченные',
    'de': 'Abgehakte löschen',
  },
  'food.shopping_add_hint': {
    'en': 'Add item…',
    'ru': 'Добавить позицию…',
    'de': 'Artikel hinzufügen…',
  },
  'food.shopping_empty': {
    'en': 'Nothing here yet — add groceries above',
    'ru': 'Список пуст — добавь продукты выше',
    'de': 'Noch nichts hier — füge oben Lebensmittel hinzu',
  },
  // ---------------------------------------------------------------------------
  // Рецепты
  // ---------------------------------------------------------------------------
  'food.my_recipes_title': {
    'en': 'My recipes',
    'ru': 'Мои рецепты',
    'de': 'Meine Rezepte',
  },
  'food.new_recipe': {
    'en': 'New recipe',
    'ru': 'Новый рецепт',
    'de': 'Neues Rezept',
  },
  'food.delete_recipe_body': {
    'en': 'Its ingredients will be removed too.',
    'ru': 'Все ингредиенты тоже будут удалены.',
    'de': 'Die Zutaten werden ebenfalls entfernt.',
  },
  'food.recipes_empty': {
    'en': 'No recipes yet — create one\nand build it from ingredients',
    'ru': 'Рецептов пока нет — создай первый\nи добавь ингредиенты',
    'de': 'Noch keine Rezepte — erstelle eines\nund füge Zutaten hinzu',
  },
  'food.recipe_name_hint': {
    'en': 'Recipe name',
    'ru': 'Название рецепта',
    'de': 'Rezeptname',
  },
  // ---------------------------------------------------------------------------
  // Редактор рецепта
  // ---------------------------------------------------------------------------
  'food.rename_recipe': {
    'en': 'Rename recipe',
    'ru': 'Переименовать рецепт',
    'de': 'Rezept umbenennen',
  },
  'food.rename_tooltip': {
    'en': 'Rename',
    'ru': 'Переименовать',
    'de': 'Umbenennen',
  },
  'food.add_ingredient': {
    'en': 'Add ingredient',
    'ru': 'Добавить ингредиент',
    'de': 'Zutat hinzufügen',
  },
  'food.log_recipe_btn': {
    'en': 'Log this recipe',
    'ru': 'Записать рецепт',
    'de': 'Rezept eintragen',
  },
  'food.ingredients_empty': {
    'en': 'No ingredients yet —\nadd products from the food base',
    'ru': 'Ингредиентов пока нет —\nдобавь продукты из базы',
    'de': 'Noch keine Zutaten —\nProdukte aus der Datenbank hinzufügen',
  },
  // Уведомление об удалении ингредиента (Undo-snackbar в recipe_editor_screen)
  'food.ingredient_removed': {
    'en': 'Ingredient removed',
    'ru': 'Ингредиент удалён',
    'de': 'Zutat entfernt',
  },
  'food.ok_btn': {
    'en': 'OK',
    'ru': 'ОК',
    'de': 'OK',
  },
  'food.grams_eaten_label': {
    'en': 'Grams eaten',
    'ru': 'Съедено (г)',
    'de': 'Gegessene Gramm',
  },
  'food.log_btn': {
    'en': 'Log',
    'ru': 'Записать',
    'de': 'Eintragen',
  },
  // ---------------------------------------------------------------------------
  // AI-меню
  // ---------------------------------------------------------------------------
  'food.ai_menu_title': {
    'en': 'AI menu for today',
    'ru': 'ИИ-меню на сегодня',
    'de': 'KI-Menü für heute',
  },
  'food.ai_menu_btn': {
    'en': 'Build my day with AI (Premium)',
    'ru': 'Собрать день с ИИ (Премиум)',
    'de': 'Tag mit KI planen (Premium)',
  },
  'food.ai_composing': {
    'en': 'AI is composing your day…',
    'ru': 'ИИ составляет твой день…',
    'de': 'KI plant deinen Tag…',
  },
  'food.ai_empty_menu': {
    'en': 'AI returned an empty menu — try again.',
    'ru': 'ИИ вернул пустое меню — попробуй ещё раз.',
    'de': 'KI hat ein leeres Menü zurückgegeben — erneut versuchen.',
  },
  'food.try_again': {
    'en': 'Try again',
    'ru': 'Попробовать снова',
    'de': 'Erneut versuchen',
  },
  'food.rebuild_btn': {
    'en': 'Rebuild',
    'ru': 'Пересобрать',
    'de': 'Neu erstellen',
  },
  'food.log_all_btn': {
    'en': 'Log all',
    'ru': 'Записать всё',
    'de': 'Alles eintragen',
  },
  'food.menu_logged': {
    'en': 'Menu logged — enjoy your day!',
    'ru': 'Меню записано — хорошего дня!',
    'de': 'Menü eingetragen — genieße deinen Tag!',
  },
  // ---------------------------------------------------------------------------
  // Сканер штрихкода
  // ---------------------------------------------------------------------------
  // Снэкбар «нужно больше продуктов» для AI-меню; {n} — минимальное число
  'food.ai_menu_need_more': {
    'en': 'Need at least {n} foods to build a menu — log a few meals or create recipes first.',
    'ru': 'Нужно хотя бы {n} продукта(ов), чтобы составить меню — запиши пару приёмов пищи или создай рецепты.',
    'de': 'Mindestens {n} Lebensmittel erforderlich — trage einige Mahlzeiten ein oder erstelle Rezepte.',
  },

  // Снэкбар после записи рецепта; {name} — имя рецепта, {meal} — приём пищи
  'food.recipe_logged_snack': {
    'en': '"{name}" logged as {meal}',
    'ru': '«{name}» записан как {meal}',
    'de': '„{name}" als {meal} eingetragen',
  },

  'food.scan_barcode_title': {
    'en': 'Scan barcode',
    'ru': 'Сканирование штрихкода',
    'de': 'Barcode scannen',
  },
  'food.torch_on': {
    'en': 'Torch on',
    'ru': 'Фонарик вкл.',
    'de': 'Taschenlampe an',
  },
  'food.torch_off': {
    'en': 'Torch off',
    'ru': 'Фонарик выкл.',
    'de': 'Taschenlampe aus',
  },
  'food.scan_instruction': {
    'en': 'Point the camera at the product barcode',
    'ru': 'Наведи камеру на штрихкод продукта',
    'de': 'Kamera auf den Produktbarcode richten',
  },
};
