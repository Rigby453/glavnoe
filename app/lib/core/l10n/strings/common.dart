// Общие строки (навигация, кнопки, разделяемые подписи).
// Часть системы переводов S (см. ../app_strings.dart).
// Формат: 'key': {'en': ..., 'ru': ..., 'de': ...}.
// Эти ключи переиспользуются всеми экранами — не дублировать в других фрагментах.
const Map<String, Map<String, String>> commonStrings = {
  // Навигация
  'nav.today': {'en': 'Today', 'ru': 'Сегодня', 'de': 'Heute'},
  'nav.plan': {'en': 'Plan', 'ru': 'План', 'de': 'Plan'},
  'nav.health': {'en': 'Health', 'ru': 'Здоровье', 'de': 'Gesundheit'},
  'nav.diary': {'en': 'Diary', 'ru': 'Дневник', 'de': 'Tagebuch'},
  // Общие кнопки
  'btn.save': {'en': 'Save', 'ru': 'Сохранить', 'de': 'Speichern'},
  'btn.cancel': {'en': 'Cancel', 'ru': 'Отмена', 'de': 'Abbrechen'},
  'btn.add': {'en': 'Add', 'ru': 'Добавить', 'de': 'Hinzufügen'},
  'btn.delete': {'en': 'Delete', 'ru': 'Удалить', 'de': 'Löschen'},
  'btn.done': {'en': 'Done', 'ru': 'Готово', 'de': 'Fertig'},
  'btn.skip': {'en': 'Skip', 'ru': 'Пропустить', 'de': 'Überspringen'},
  'btn.back': {'en': 'Back', 'ru': 'Назад', 'de': 'Zurück'},
  'btn.close': {'en': 'Close', 'ru': 'Закрыть', 'de': 'Schließen'},
  'btn.sign_out': {'en': 'Sign out', 'ru': 'Выйти', 'de': 'Abmelden'},
  'btn.sign_in': {
    'en': 'Sign in / Sign up',
    'ru': 'Войти / Зарегистрироваться',
    'de': 'Anmelden / Registrieren',
  },
  // Today (общие)
  'today.greeting_morning': {
    'en': 'Good morning',
    'ru': 'Доброе утро',
    'de': 'Guten Morgen',
  },
  'today.greeting_afternoon': {
    'en': 'Good afternoon',
    'ru': 'Добрый день',
    'de': 'Guten Tag',
  },
  'today.greeting_evening': {
    'en': 'Good evening',
    'ru': 'Добрый вечер',
    'de': 'Guten Abend',
  },
  'today.add_food': {
    'en': 'Add food',
    'ru': 'Добавить еду',
    'de': 'Essen hinzufügen',
  },
  'today.main_tasks': {
    'en': 'Main today',
    'ru': 'Главное сегодня',
    'de': 'Hauptaufgaben heute',
  },
  'today.later': {'en': 'Later today', 'ru': 'Позже сегодня', 'de': 'Später heute'},
  // Профиль (общие)
  'profile.title': {'en': 'Profile', 'ru': 'Профиль', 'de': 'Profil'},
  'profile.language': {'en': 'Language', 'ru': 'Язык', 'de': 'Sprache'},
  'profile.theme': {'en': 'Theme', 'ru': 'Тема', 'de': 'Thema'},
  'profile.notifications': {
    'en': 'Daily reminders',
    'ru': 'Ежедневные напоминания',
    'de': 'Tägliche Erinnerungen',
  },
  'profile.text_size': {
    'en': 'Text size',
    'ru': 'Размер текста',
    'de': 'Textgröße',
  },
  'profile.tone': {'en': 'Tone', 'ru': 'Тон', 'de': 'Ton'},
  // Health (хаб)
  'health.title': {'en': 'Health', 'ru': 'Здоровье', 'de': 'Gesundheit'},
  'health.water': {'en': 'Water', 'ru': 'Вода', 'de': 'Wasser'},
  'health.sleep': {'en': 'Sleep', 'ru': 'Сон', 'de': 'Schlaf'},
  'health.food': {'en': 'Food', 'ru': 'Питание', 'de': 'Ernährung'},
  'health.workouts': {
    'en': 'Workouts',
    'ru': 'Тренировки',
    'de': 'Training',
  },
  'health.breathing': {
    'en': 'Breathing',
    'ru': 'Дыхание',
    'de': 'Atemübungen',
  },
  'health.posture': {'en': 'Posture', 'ru': 'Осанка', 'de': 'Haltung'},
  // Diary
  'diary.title': {
    'en': 'How was today?',
    'ru': 'Как прошёл день?',
    'de': 'Wie war dein Tag?',
  },
  'diary.mood': {'en': 'Mood', 'ru': 'Настроение', 'de': 'Stimmung'},
  'diary.note': {'en': 'Note', 'ru': 'Заметка', 'de': 'Notiz'},
  'diary.save_day': {
    'en': 'Save day',
    'ru': 'Сохранить день',
    'de': 'Tag speichern',
  },
  'diary.history': {'en': 'View History', 'ru': 'История', 'de': 'Verlauf'},
  // Plan
  'plan.title': {'en': 'Plan', 'ru': 'План', 'de': 'Plan'},
  // Еда (общие)
  'food.add': {'en': 'Add food', 'ru': 'Добавить еду', 'de': 'Essen hinzufügen'},
  'food.search_hint': {
    'en': 'Search a product…',
    'ru': 'Найти продукт…',
    'de': 'Produkt suchen…',
  },
  'food.nothing_today': {
    'en': 'Nothing logged today.\nTap "Add food" to search a product.',
    'ru': 'Ничего не добавлено.\nНажми «Добавить еду» для поиска.',
    'de': 'Noch nichts eingetragen.\nTippe auf „Essen hinzufügen".',
  },
  // Стрики
  'streak.freeze': {
    'en': 'Freeze streak',
    'ru': 'Заморозить стрик',
    'de': 'Streak einfrieren',
  },
  // Настройки тона
  'settings.gentle': {'en': 'Gentle', 'ru': 'Мягкий', 'de': 'Sanft'},
  'settings.harsh': {'en': 'Harsh', 'ru': 'Строгий', 'de': 'Streng'},
};
