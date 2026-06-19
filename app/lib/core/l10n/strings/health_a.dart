// Строки Health: хаб + Co-study + Habits. Наполняется агентом локализации.
// Формат: 'key': {'en': ..., 'ru': ..., 'de': ...}.
// Ключи health.title / health.water / health.sleep / health.food /
// health.workouts / health.breathing / health.posture живут в common.dart — не дублируем.
const Map<String, Map<String, String>> healthAStrings = {
  // ---------------------------------------------------------------------------
  // Health hub — Water card
  // ---------------------------------------------------------------------------
  'health.water_full_view': {
    'en': 'Full view',
    'ru': 'Подробнее',
    'de': 'Vollansicht',
  },
  'health.water_goal_of': {
    'en': 'of {goal} ml goal',
    'ru': 'из {goal} мл цели',
    'de': 'von {goal} ml Ziel',
  },
  'health.water_undo': {
    'en': 'Undo',
    'ru': 'Отменить',
    'de': 'Rückgängig',
  },
  'health.water_reminders': {
    'en': 'Drink reminders (every 2 h)',
    'ru': 'Напоминания пить (каждые 2 ч)',
    'de': 'Trinkerinnerungen (alle 2 Std.)',
  },
  'health.view_report': {
    'en': 'View Report',
    'ru': 'Смотреть отчёт',
    'de': 'Bericht ansehen',
  },
  'health.water_goal_reached': {
    'en': 'Water goal reached 💧',
    'ru': 'Норма воды выполнена 💧',
    'de': 'Wasserziel erreicht 💧',
  },

  // ---------------------------------------------------------------------------
  // Health hub — Sleep card
  // ---------------------------------------------------------------------------
  'health.sleep_sleeping_since': {
    'en': 'Sleeping since',
    'ru': 'Сплю с',
    'de': 'Schläft seit',
  },
  'health.sleep_im_awake': {
    'en': "I'm awake",
    'ru': 'Проснулся',
    'de': 'Ich bin wach',
  },
  'health.sleep_going_to_bed': {
    'en': 'Going to bed',
    'ru': 'Ложусь спать',
    'de': 'Gehe schlafen',
  },
  'health.sleep_no_nights': {
    'en': 'No nights tracked yet',
    'ru': 'Ночей пока нет',
    'de': 'Noch keine Nächte erfasst',
  },
  // Кнопки добавления воды
  'health.water_add_250': {
    'en': '+250 ml',
    'ru': '+250 мл',
    'de': '+250 ml',
  },
  'health.water_add_500': {
    'en': '+500 ml',
    'ru': '+500 мл',
    'de': '+500 ml',
  },
  // Снэкбар после логирования ночи; {h} — часы, {m} — минуты
  'health.sleep_night_logged': {
    'en': 'Night logged: {h}h {m}m',
    'ru': 'Ночь записана: {h}ч {m}м',
    'de': 'Nacht erfasst: {h}h {m}m',
  },

  // ---------------------------------------------------------------------------
  // Health hub — Nav tiles subtitles (titles reuse health.* from common)
  // ---------------------------------------------------------------------------
  'health.food_subtitle': {
    'en': 'Log meals · КБЖУ from Open Food Facts',
    'ru': 'Питание · КБЖУ из Open Food Facts',
    'de': 'Mahlzeiten · Nährwerte von Open Food Facts',
  },
  'health.focus_session': {
    'en': 'Focus session',
    'ru': 'Фокус-сессия',
    'de': 'Fokus-Session',
  },
  'health.focus_session_subtitle': {
    'en': '25/5 · 50/10 · 67/15 and more',
    'ru': '25/5 · 50/10 · 67/15 и другие',
    'de': '25/5 · 50/10 · 67/15 und mehr',
  },
  'health.workouts_subtitle': {
    'en': 'Your workout plans',
    'ru': 'Твои планы тренировок',
    'de': 'Deine Trainingspläne',
  },
  'health.breathing_subtitle': {
    'en': 'Box 4-4-4-4 · Calm 4-7-8 · Simple 5-5',
    'ru': 'Бокс 4-4-4-4 · Спокойствие 4-7-8 · Простое 5-5',
    'de': 'Box 4-4-4-4 · Ruhe 4-7-8 · Einfach 5-5',
  },
  'health.meditation': {
    'en': 'Meditation',
    'ru': 'Медитация',
    'de': 'Meditation',
  },
  'health.meditation_subtitle': {
    'en': 'Guided text sessions · 5–15 min',
    'ru': 'Текстовые сессии · 5–15 мин',
    'de': 'Geführte Textsitzungen · 5–15 Min.',
  },
  'health.posture_subtitle': {
    'en': 'Exercises · stand-tall reminders',
    'ru': 'Упражнения · напоминания о осанке',
    'de': 'Übungen · Haltungserinnerungen',
  },
  'health.screen_time': {
    'en': 'Screen Time',
    'ru': 'Экранное время',
    'de': 'Bildschirmzeit',
  },
  'health.screen_time_subtitle': {
    'en': 'Set daily limits for distracting apps',
    'ru': 'Ограничь время в отвлекающих приложениях',
    'de': 'Tägliche Limits für ablenkende Apps',
  },

  // ---------------------------------------------------------------------------
  // Co-study screen
  // ---------------------------------------------------------------------------
  'costudy.title': {
    'en': 'Co-study',
    'ru': 'Учёба вместе',
    'de': 'Gemeinsam lernen',
  },
  'costudy.subtitle_hub': {
    'en': 'Study with friends · leaderboard',
    'ru': 'Учись с друзьями · таблица лидеров',
    'de': 'Mit Freunden lernen · Rangliste',
  },
  'costudy.session_in_progress': {
    'en': 'Session in progress',
    'ru': 'Сессия идёт',
    'de': 'Sitzung läuft',
  },
  'costudy.session_code_label': {
    'en': 'Code:',
    'ru': 'Код:',
    'de': 'Code:',
  },
  'costudy.share_code': {
    'en': 'Share this code with a friend',
    'ru': 'Поделись кодом с другом',
    'de': 'Teile diesen Code mit einem Freund',
  },
  'costudy.code_copied': {
    'en': 'Code copied!',
    'ru': 'Код скопирован!',
    'de': 'Code kopiert!',
  },
  'costudy.end_session': {
    'en': 'End session',
    'ru': 'Завершить сессию',
    'de': 'Sitzung beenden',
  },
  'costudy.ready_to_focus': {
    'en': 'Ready to focus?',
    'ru': 'Готов сосредоточиться?',
    'de': 'Bereit für den Fokus?',
  },
  'costudy.session_prompt': {
    'en': "Start a session and your friends will see you're studying",
    'ru': 'Запусти сессию — друзья увидят, что ты учишься',
    'de': 'Starte eine Sitzung — deine Freunde sehen, dass du lernst',
  },
  'costudy.start_session': {
    'en': 'Start session',
    'ru': 'Начать сессию',
    'de': 'Sitzung starten',
  },
  'costudy.join_by_code': {
    'en': 'Join a session by code',
    'ru': 'Войти по коду',
    'de': 'Per Code beitreten',
  },
  'costudy.study_buddies': {
    'en': 'Study buddies',
    'ru': 'Друзья',
    'de': 'Lernpartner',
  },
  'costudy.no_buddies': {
    'en': 'No buddies yet. Add a friend by email!',
    'ru': 'Друзей пока нет. Добавь кого-нибудь по email!',
    'de': 'Noch keine Lernpartner. Füge einen Freund per E-Mail hinzu!',
  },
  'costudy.this_week': {
    'en': 'This week',
    'ru': 'На этой неделе',
    'de': 'Diese Woche',
  },
  'costudy.no_sessions_week': {
    'en': 'No sessions yet this week.',
    'ru': 'На этой неделе сессий ещё не было.',
    'de': 'Diese Woche noch keine Sitzungen.',
  },
  'costudy.add_buddy_title': {
    'en': 'Add study buddy',
    'ru': 'Добавить друга',
    'de': 'Lernpartner hinzufügen',
  },
  'costudy.email_label': {
    'en': 'Email address',
    'ru': 'Адрес электронной почты',
    'de': 'E-Mail-Adresse',
  },
  'costudy.join_session_title': {
    'en': 'Join a session',
    'ru': 'Войти в сессию',
    'de': 'Sitzung beitreten',
  },
  'costudy.session_code_hint_label': {
    'en': 'Session code (8 characters)',
    'ru': 'Код сессии (8 символов)',
    'de': 'Sitzungscode (8 Zeichen)',
  },
  'costudy.join': {
    'en': 'Join',
    'ru': 'Войти',
    'de': 'Beitreten',
  },
  'costudy.study_together': {
    'en': 'Study together',
    'ru': 'Учиться вместе',
    'de': 'Gemeinsam lernen',
  },
  'costudy.start': {
    'en': 'Start',
    'ru': 'Начать',
    'de': 'Starten',
  },
  'costudy.session_not_found': {
    'en': 'Session not found or has ended',
    'ru': 'Сессия не найдена или уже завершена',
    'de': 'Sitzung nicht gefunden oder bereits beendet',
  },
  'costudy.start_too': {
    'en': 'Start too',
    'ru': 'Тоже начать',
    'de': 'Auch starten',
  },
  'costudy.friend_idle': {
    'en': 'Idle',
    'ru': 'Не учится',
    'de': 'Inaktiv',
  },
  'costudy.you': {
    'en': 'You',
    'ru': 'Это ты',
    'de': 'Du',
  },

  // ---------------------------------------------------------------------------
  // Habits screen
  // ---------------------------------------------------------------------------
  'habits.title': {
    'en': 'Habits',
    'ru': 'Привычки',
    'de': 'Gewohnheiten',
  },
  'habits.subtitle_hub': {
    'en': 'Build good habits · break bad ones',
    'ru': 'Формируй хорошие · избавляйся от плохих',
    'de': 'Gute Gewohnheiten aufbauen · schlechte ablegen',
  },
  'habits.empty_title': {
    'en': 'No habits yet',
    'ru': 'Привычек пока нет',
    'de': 'Noch keine Gewohnheiten',
  },
  'habits.empty_body': {
    'en': 'Add good habits to build streaks,\nor track bad ones to break them.',
    'ru': 'Добавь хорошие привычки, чтобы держать стрик,\nили отслеживай плохие, чтобы от них избавиться.',
    'de': 'Füge gute Gewohnheiten hinzu, um Serien aufzubauen,\noder verfolge schlechte, um sie zu brechen.',
  },
  'habits.good_habits': {
    'en': 'Good habits',
    'ru': 'Хорошие привычки',
    'de': 'Gute Gewohnheiten',
  },
  'habits.break_these': {
    'en': 'Break these',
    'ru': 'Избавляемся',
    'de': 'Diese ablegen',
  },
  'habits.new_habit': {
    'en': 'New habit',
    'ru': 'Новая привычка',
    'de': 'Neue Gewohnheit',
  },
  'habits.habit_name': {
    'en': 'Habit name',
    'ru': 'Название привычки',
    'de': 'Name der Gewohnheit',
  },
  'habits.type_label': {
    'en': 'Type:',
    'ru': 'Тип:',
    'de': 'Typ:',
  },
  'habits.type_good': {
    'en': '✅ Good',
    'ru': '✅ Хорошая',
    'de': '✅ Gut',
  },
  'habits.type_bad': {
    'en': '🚫 Bad',
    'ru': '🚫 Плохая',
    'de': '🚫 Schlecht',
  },
  'habits.archive': {
    'en': 'Archive',
    'ru': 'В архив',
    'de': 'Archivieren',
  },
  'habits.done': {
    'en': 'Done! 🎉',
    'ru': 'Сделано! 🎉',
    'de': 'Erledigt! 🎉',
  },

  // ---------------------------------------------------------------------------
  // Health profile (health_profile_provider.dart, setup_flow.dart, profile_screen.dart)
  // ---------------------------------------------------------------------------
  'health_profile.section_title': {
    'en': 'Health profile',
    'ru': 'Профиль здоровья',
    'de': 'Gesundheitsprofil',
  },
  'health_profile.onboarding_title': {
    'en': 'Tell us about your health',
    'ru': 'Расскажи о своём здоровье',
    'de': 'Erzähl uns von deiner Gesundheit',
  },
  'health_profile.onboarding_subtitle': {
    'en': 'Optional — helps the AI menu builder account for allergies and nutrients.',
    'ru': 'Необязательно — помогает AI-конструктору меню учесть аллергии и питательные потребности.',
    'de': 'Optional — hilft dem KI-Menü-Builder, Allergien und Nährstoffe zu berücksichtigen.',
  },
  'health_profile.q_allergies': {
    'en': 'Any allergies or intolerances? Tell us in your own words.',
    'ru': 'Есть ли у тебя аллергии или непереносимость? Напиши своими словами.',
    'de': 'Hast du Allergien oder Unverträglichkeiten? Schildere es in deinen eigenen Worten.',
  },
  'health_profile.q_healing': {
    'en': 'How fast do your wounds heal — fast, normal, slow?',
    'ru': 'Как быстро заживают твои раны — быстро, нормально, медленно?',
    'de': 'Wie schnell heilen deine Wunden — schnell, normal, langsam?',
  },
  'health_profile.q_deficiencies': {
    'en': 'Any vitamins or minerals you know you\'re low on?',
    'ru': 'Знаешь ли ты о дефиците каких-либо витаминов или минералов?',
    'de': 'Weißt du von Vitamin- oder Mineralstoffmängeln bei dir?',
  },
  'health_profile.disclaimer': {
    'en': 'This is not medical advice — for deficiencies, see a doctor.',
    'ru': 'Это не медицинская рекомендация — при дефиците обратись к врачу.',
    'de': 'Dies ist kein medizinischer Rat — bei Mängeln wende dich an einen Arzt.',
  },
  'health_profile.btn_save': {
    'en': 'Save',
    'ru': 'Сохранить',
    'de': 'Speichern',
  },
  'health_profile.saved_snack': {
    'en': 'Health profile saved',
    'ru': 'Профиль здоровья сохранён',
    'de': 'Gesundheitsprofil gespeichert',
  },
  'health_profile.edit_btn': {
    'en': 'Edit',
    'ru': 'Редактировать',
    'de': 'Bearbeiten',
  },
  'health_profile.empty_hint': {
    'en': 'Not filled in yet. Tap Edit to add.',
    'ru': 'Ещё не заполнен. Нажми «Редактировать».',
    'de': 'Noch nicht ausgefüllt. Tippe auf Bearbeiten.',
  },

  // ---------------------------------------------------------------------------
  // Food preferences (food_preferences_provider.dart, profile_screen.dart)
  // ---------------------------------------------------------------------------
  'food_prefs.section_title': {
    'en': 'Food preferences',
    'ru': 'Пищевые предпочтения',
    'de': 'Ernährungspräferenzen',
  },
  'food_prefs.ai_note': {
    'en': 'Used to personalise your AI menu.',
    'ru': 'Используется для персонализации AI-меню.',
    'de': 'Wird zur Personalisierung deines KI-Menüs verwendet.',
  },
  'food_prefs.edit_btn': {
    'en': 'Edit',
    'ru': 'Изменить',
    'de': 'Bearbeiten',
  },
  'food_prefs.btn_save': {
    'en': 'Save',
    'ru': 'Сохранить',
    'de': 'Speichern',
  },
  'food_prefs.saved_snack': {
    'en': 'Food preferences saved',
    'ru': 'Пищевые предпочтения сохранены',
    'de': 'Ernährungspräferenzen gespeichert',
  },
  'food_prefs.empty_hint': {
    'en': 'Not set. Tap Edit to personalise your AI menu.',
    'ru': 'Не указаны. Нажми «Изменить» для персонализации AI-меню.',
    'de': 'Nicht gesetzt. Tippe auf Bearbeiten, um dein KI-Menü zu personalisieren.',
  },

  // Диета
  'food_prefs.diet_label': {
    'en': 'Diet',
    'ru': 'Тип питания',
    'de': 'Ernährungsweise',
  },
  'food_prefs.diet_none': {
    'en': 'None',
    'ru': 'Обычная',
    'de': 'Keine',
  },
  'food_prefs.diet_vegetarian': {
    'en': 'Vegetarian',
    'ru': 'Вегетарианец',
    'de': 'Vegetarisch',
  },
  'food_prefs.diet_vegan': {
    'en': 'Vegan',
    'ru': 'Веган',
    'de': 'Vegan',
  },
  'food_prefs.diet_pescatarian': {
    'en': 'Pescatarian',
    'ru': 'Пескетарианец',
    'de': 'Pescetarisch',
  },
  'food_prefs.diet_halal': {
    'en': 'Halal',
    'ru': 'Халяль',
    'de': 'Halal',
  },
  'food_prefs.diet_kosher': {
    'en': 'Kosher',
    'ru': 'Кошерное',
    'de': 'Koscher',
  },
  'food_prefs.diet_keto': {
    'en': 'Keto',
    'ru': 'Кето',
    'de': 'Keto',
  },
  'food_prefs.diet_other': {
    'en': 'Other',
    'ru': 'Другое',
    'de': 'Sonstiges',
  },

  // Цель
  'food_prefs.goal_label': {
    'en': 'Goal',
    'ru': 'Цель',
    'de': 'Ziel',
  },
  'food_prefs.goal_lose': {
    'en': 'Lose weight',
    'ru': 'Похудеть',
    'de': 'Abnehmen',
  },
  'food_prefs.goal_maintain': {
    'en': 'Maintain',
    'ru': 'Поддержать',
    'de': 'Halten',
  },
  'food_prefs.goal_gain': {
    'en': 'Gain weight',
    'ru': 'Набрать массу',
    'de': 'Zunehmen',
  },

  // Приёмы пищи
  'food_prefs.meals_label': {
    'en': 'Meals per day',
    'ru': 'Приёмов пищи в день',
    'de': 'Mahlzeiten pro Tag',
  },

  // Свободный текст
  'food_prefs.dislikes_label': {
    'en': 'Dislikes (ingredients / dishes to avoid)',
    'ru': 'Не нравится (ингредиенты / блюда избегать)',
    'de': 'Abneigungen (Zutaten / Gerichte meiden)',
  },
  'food_prefs.dislikes_hint': {
    'en': 'e.g. mushrooms, very spicy food',
    'ru': 'напр. грибы, острая еда',
    'de': 'z. B. Pilze, sehr scharfes Essen',
  },
  'food_prefs.likes_label': {
    'en': 'Likes (favourite ingredients / dishes)',
    'ru': 'Нравится (любимые ингредиенты / блюда)',
    'de': 'Vorlieben (Lieblinge Zutaten / Gerichte)',
  },
  'food_prefs.likes_hint': {
    'en': 'e.g. chicken, pasta, avocado',
    'ru': 'напр. курица, паста, авокадо',
    'de': 'z. B. Hähnchen, Pasta, Avocado',
  },

  // Просмотр заполненных значений
  'food_prefs.view_diet': {
    'en': 'Diet',
    'ru': 'Питание',
    'de': 'Diät',
  },
  'food_prefs.view_goal': {
    'en': 'Goal',
    'ru': 'Цель',
    'de': 'Ziel',
  },
  'food_prefs.view_meals': {
    'en': 'Meals/day',
    'ru': 'Приёмов/день',
    'de': 'Mahlzeiten/Tag',
  },
  'food_prefs.view_dislikes': {
    'en': 'Dislikes',
    'ru': 'Не нравится',
    'de': 'Abneigungen',
  },
  'food_prefs.view_likes': {
    'en': 'Likes',
    'ru': 'Нравится',
    'de': 'Vorlieben',
  },
};
