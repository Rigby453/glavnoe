// Строки экранов Plan и Diary. Заполнено агентом локализации.
// Формат: 'key': {'en': ..., 'ru': ..., 'de': ...}.
// Ключи из common.dart (nav.*, btn.*, diary.title, diary.mood, diary.note,
// diary.save_day, diary.history, plan.title) — НЕ дублируются здесь.
const Map<String, Map<String, String>> planDiaryStrings = {
  // ---------------------------------------------------------------------------
  // Plan — переключатель вида
  // ---------------------------------------------------------------------------
  'plan.view_day': {'en': 'Day', 'ru': 'День', 'de': 'Tag'},
  'plan.view_week': {'en': 'Week', 'ru': 'Неделя', 'de': 'Woche'},
  'plan.view_month': {'en': 'Month', 'ru': 'Месяц', 'de': 'Monat'},

  // Plan — тулбар
  'plan.today': {'en': 'Today', 'ru': 'Сегодня', 'de': 'Heute'},
  'plan.yesterday': {'en': 'Yesterday', 'ru': 'Вчера', 'de': 'Gestern'},
  'plan.search_tooltip': {
    'en': 'Search tasks',
    'ru': 'Поиск задач',
    'de': 'Aufgaben suchen',
  },
  'plan.search_label': {'en': 'Search', 'ru': 'Поиск', 'de': 'Suche'},
  'plan.goals_tooltip': {
    'en': 'Long-term goals',
    'ru': 'Долгосрочные цели',
    'de': 'Langfristige Ziele',
  },
  'plan.import_label': {'en': 'Import', 'ru': 'Импорт', 'de': 'Importieren'},
  'plan.search_hint': {
    'en': 'Search tasks…',
    'ru': 'Поиск задач…',
    'de': 'Aufgaben suchen…',
  },

  // Plan — DayTimeline: обратный отсчёт
  'plan.countdown_overdue': {'en': 'overdue', 'ru': 'просрочено', 'de': 'überfällig'},
  'plan.countdown_today': {'en': 'today', 'ru': 'сегодня', 'de': 'heute'},
  'plan.countdown_tomorrow': {'en': 'tomorrow', 'ru': 'завтра', 'de': 'morgen'},
  // «in N days» — без интерполяции: делаем форму «through N days» на RU через
  // префиксный шаблон; функция склеивает число отдельно.
  'plan.countdown_in_days_prefix': {'en': 'in ', 'ru': 'через ', 'de': 'in '},
  'plan.countdown_in_days_suffix': {'en': ' days', 'ru': ' дн.', 'de': ' Tage'},

  // Plan — DayTimeline: типы задач (метки значков)
  'plan.type_exam': {'en': 'exam', 'ru': 'экзамен', 'de': 'Prüfung'},
  'plan.type_deadline': {'en': 'DL', 'ru': 'ДЛ', 'de': 'DL'},
  'plan.type_event': {'en': 'event', 'ru': 'событие', 'de': 'Termin'},
  'plan.type_task': {'en': 'task', 'ru': 'задача', 'de': 'Aufgabe'},

  // Plan — DayTimeline: пустое состояние
  'plan.empty_prefix': {
    'en': 'Nothing planned for ',
    'ru': 'Ничего на ',
    'de': 'Nichts geplant für ',
  },
  'plan.empty_hint': {
    'en': 'Tap + to add something',
    'ru': 'Нажми + чтобы добавить',
    'de': 'Tippe +, um etwas hinzuzufügen',
  },

  // Plan — WeekAgenda: клонирование недели
  'plan.clone_week_title': {
    'en': 'Clone week',
    'ru': 'Скопировать неделю',
    'de': 'Woche kopieren',
  },
  'plan.clone_week_body': {
    'en': 'Copy everything scheduled this week to next week (same days & times)?',
    'ru': 'Скопировать все события этой недели на следующую (те же дни и время)?',
    'de': 'Alles dieser Woche auf die nächste Woche kopieren (gleiche Tage & Zeiten)?',
  },
  'plan.clone_week_copy': {'en': 'Copy', 'ru': 'Скопировать', 'de': 'Kopieren'},
  'plan.clone_week_nothing': {
    'en': 'No classes/events this week to copy',
    'ru': 'Нет занятий или событий для копирования',
    'de': 'Keine Kurse/Termine zum Kopieren',
  },
  'plan.clone_week_done_prefix': {'en': 'Copied ', 'ru': 'Скопировано ', 'de': 'Kopiert '},
  'plan.clone_week_done_suffix': {
    'en': ' to next week',
    'ru': ' на следующую неделю',
    'de': ' in die nächste Woche',
  },
  'plan.clone_week_button': {
    'en': 'Clone week → next',
    'ru': 'Скопировать на следующую',
    'de': 'Woche → nächste klonen',
  },
  'plan.week_today_label': {'en': 'today', 'ru': 'сегодня', 'de': 'heute'},

  // Plan — MonthView: подписи дней недели
  'plan.weekday_mon': {'en': 'Mon', 'ru': 'Пн', 'de': 'Mo'},
  'plan.weekday_tue': {'en': 'Tue', 'ru': 'Вт', 'de': 'Di'},
  'plan.weekday_wed': {'en': 'Wed', 'ru': 'Ср', 'de': 'Mi'},
  'plan.weekday_thu': {'en': 'Thu', 'ru': 'Чт', 'de': 'Do'},
  'plan.weekday_fri': {'en': 'Fri', 'ru': 'Пт', 'de': 'Fr'},
  'plan.weekday_sat': {'en': 'Sat', 'ru': 'Сб', 'de': 'Sa'},
  'plan.weekday_sun': {'en': 'Sun', 'ru': 'Вс', 'de': 'So'},

  // Plan — GoalsScreen: AppBar + FAB
  'plan.goals_screen_title': {
    'en': 'Long-term goals',
    'ru': 'Долгосрочные цели',
    'de': 'Langfristige Ziele',
  },
  'plan.goals_new_button': {'en': 'New goal', 'ru': 'Новая цель', 'de': 'Neues Ziel'},

  // Plan — GoalsScreen: пустое состояние
  'plan.goals_empty': {
    'en': 'Set a goal for the month, the year — or the decade',
    'ru': 'Поставь цель на месяц, год — или на десятилетие',
    'de': 'Setze ein Ziel für den Monat, das Jahr — oder das Jahrzehnt',
  },

  // Plan — GoalsScreen: прогресс шагов
  'plan.goals_no_steps': {'en': 'No steps yet', 'ru': 'Шагов пока нет', 'de': 'Noch keine Schritte'},
  'plan.goals_steps_done_prefix': {'en': '', 'ru': '', 'de': ''},
  // Формат: «$done of $total steps» — склеивается в коде
  'plan.goals_steps_of': {'en': 'of', 'ru': 'из', 'de': 'von'},
  'plan.goals_steps_suffix': {'en': ' steps', 'ru': ' шагов', 'de': ' Schritte'},

  // Plan — GoalsScreen: удаление цели
  'plan.goals_delete_title': {
    'en': 'Delete goal?',
    'ru': 'Удалить цель?',
    'de': 'Ziel löschen?',
  },
  'plan.goals_delete_body_suffix': {
    'en': ' and all its steps will be removed.',
    'ru': ' и все её шаги будут удалены.',
    'de': ' und alle Schritte werden entfernt.',
  },
  'plan.goals_delete_button': {'en': 'Delete', 'ru': 'Удалить', 'de': 'Löschen'},

  // Plan — GoalsScreen: шаги
  'plan.goals_plan_today_tooltip': {
    'en': 'Plan today',
    'ru': 'Запланировать на сегодня',
    'de': 'Für heute einplanen',
  },
  'plan.goals_delete_tooltip': {
    'en': 'Delete goal',
    'ru': 'Удалить цель',
    'de': 'Ziel löschen',
  },
  'plan.goals_add_step_hint': {
    'en': 'Add step',
    'ru': 'Добавить шаг',
    'de': 'Schritt hinzufügen',
  },
  'plan.goals_add_step_tooltip': {
    'en': 'Add step',
    'ru': 'Добавить шаг',
    'de': 'Schritt hinzufügen',
  },
  'plan.goals_added_to_today': {
    'en': 'Added to today',
    'ru': 'Добавлено на сегодня',
    'de': 'Für heute hinzugefügt',
  },

  // Plan — GoalsScreen: диалог новой цели
  'plan.goals_new_title': {'en': 'New goal', 'ru': 'Новая цель', 'de': 'Neues Ziel'},
  'plan.goals_new_hint': {
    'en': 'What do you want to achieve?',
    'ru': 'Чего хочешь достичь?',
    'de': 'Was möchtest du erreichen?',
  },
  'plan.goals_horizon_label': {'en': 'Horizon', 'ru': 'Горизонт', 'de': 'Horizont'},
  'plan.goals_create_button': {'en': 'Create', 'ru': 'Создать', 'de': 'Erstellen'},

  // Plan — GoalsScreen: горизонты
  'plan.horizon_month': {'en': 'Month', 'ru': 'Месяц', 'de': 'Monat'},
  'plan.horizon_year': {'en': 'Year', 'ru': 'Год', 'de': 'Jahr'},
  'plan.horizon_five_years': {'en': '5 years', 'ru': '5 лет', 'de': '5 Jahre'},
  'plan.horizon_ten_years': {'en': '10 years', 'ru': '10 лет', 'de': '10 Jahre'},

  // ---------------------------------------------------------------------------
  // Diary — форма
  // ---------------------------------------------------------------------------
  'diary.note_prompt': {
    'en': 'Anything interesting today?',
    'ru': 'Что-нибудь интересное сегодня?',
    'de': 'Etwas Interessantes heute?',
  },
  'diary.note_hint': {
    'en': 'Write a few words…',
    'ru': 'Напиши пару слов…',
    'de': 'Schreib ein paar Worte…',
  },
  'diary.what_went_wrong': {
    'en': 'What went wrong?',
    'ru': 'Что пошло не так?',
    'de': 'Was lief schief?',
  },

  // Diary — теги "What went wrong"
  'diary.issue_social_media': {
    'en': 'Social media',
    'ru': 'Соцсети',
    'de': 'Soziale Medien',
  },
  'diary.issue_went_out': {'en': 'Went out', 'ru': 'Гулял(а)', 'de': 'Ausgegangen'},
  'diary.issue_was_tired': {'en': 'Was tired', 'ru': 'Устал(а)', 'de': 'War müde'},
  'diary.issue_sick': {'en': 'Sick', 'ru': 'Болел(а)', 'de': 'Krank'},
  'diary.issue_other': {'en': 'Other', 'ru': 'Другое', 'de': 'Sonstiges'},

  // Diary — кнопки действий
  'diary.save_day_button': {
    'en': 'Save Day',
    'ru': 'Сохранить день',
    'de': 'Tag speichern',
  },
  'diary.get_insight_button': {
    'en': 'Get insight (Premium)',
    'ru': 'Получить инсайт (Премиум)',
    'de': 'Einblick holen (Premium)',
  },
  'diary.this_week_button': {
    'en': 'This week',
    'ru': 'Эта неделя',
    'de': 'Diese Woche',
  },

  // Diary — снэкбар
  'diary.day_saved': {'en': 'Day saved', 'ru': 'День сохранён', 'de': 'Tag gespeichert'},

  // Diary — диалог AI-инсайта
  'diary.insight_dialog_title': {'en': 'Insight', 'ru': 'Инсайт', 'de': 'Einblick'},

  // Diary — карточка «план vs факт»
  'diary.pvf_title': {
    'en': 'Today: plan vs fact',
    'ru': 'Сегодня: план vs факт',
    'de': 'Heute: Plan vs. Fakt',
  },
  'diary.pvf_planned': {'en': 'Planned', 'ru': 'Запланировано', 'de': 'Geplant'},
  'diary.pvf_done': {'en': 'Done', 'ru': 'Выполнено', 'de': 'Erledigt'},
  'diary.pvf_skipped': {'en': 'Skipped', 'ru': 'Пропущено', 'de': 'Übersprungen'},

  // Diary — карточка недельного инсайта
  'diary.this_week_card_title': {
    'en': 'This week',
    'ru': 'Эта неделя',
    'de': 'Diese Woche',
  },

  // Diary — карточка «жизненные инсайты»
  'diary.life_insights_title': {
    'en': 'Life insights',
    'ru': 'Наблюдения',
    'de': 'Lebenseinblicke',
  },

  // Diary — строки жизненных инсайтов (сон + вода)
  // {avg} заменяется на строку с одним знаком после запятой (avgSleep.toStringAsFixed(1))
  'diary.insight_sleep_low': {
    'en': '😴 You averaged {avg}h sleep — try going to bed 30 min earlier.',
    'ru': '😴 В среднем {avg}ч сна — попробуй ложиться на 30 мин раньше.',
    'de': '😴 Du hast durchschnittlich {avg}h geschlafen — versuche 30 Min früher ins Bett.',
  },
  'diary.insight_sleep_good': {
    'en': '✅ Great sleep this week — {avg}h avg!',
    'ru': '✅ Отличный сон на этой неделе — {avg}ч в среднем!',
    'de': '✅ Super Schlaf diese Woche — {avg}h im Durchschnitt!',
  },
  // {n} заменяется на число дней, когда цель была выполнена
  'diary.insight_water_perfect': {
    'en': '💧 Perfect hydration week — goal met every day!',
    'ru': '💧 Идеальная неделя по воде — цель выполнена каждый день!',
    'de': '💧 Perfekte Hydrationswoche — Ziel jeden Tag erreicht!',
  },
  'diary.insight_water_low': {
    'en': '💧 Only {n}/7 days met your water goal this week. Try keeping a bottle nearby.',
    'ru': '💧 Только {n}/7 дней выполнена норма воды. Держи бутылку под рукой.',
    'de': '💧 Nur {n}/7 Tage Wasserziel erreicht. Halte eine Flasche in der Nähe.',
  },
  'diary.insight_no_data': {
    'en': '📊 Track sleep and water consistently to see personal insights here.',
    'ru': '📊 Регулярно записывай сон и воду — здесь появятся личные наблюдения.',
    'de': '📊 Erfasse Schlaf und Wasser regelmäßig, um persönliche Einblicke zu sehen.',
  },

  // ---------------------------------------------------------------------------
  // Diary History
  // ---------------------------------------------------------------------------
  'diary.history_screen_title': {
    'en': 'Diary History',
    'ru': 'История дневника',
    'de': 'Tagebuchverlauf',
  },
  'diary.history_select_date': {
    'en': 'Select Date',
    'ru': 'Выбери дату',
    'de': 'Datum wählen',
  },
  'diary.history_no_entry': {
    'en': 'No entry for this day',
    'ru': 'Нет записи за этот день',
    'de': 'Kein Eintrag für diesen Tag',
  },
  'diary.history_what_went_wrong': {
    'en': 'What Went Wrong',
    'ru': 'Что пошло не так',
    'de': 'Was schiefgelaufen ist',
  },
  'diary.history_ai_insight': {
    'en': 'AI Insight',
    'ru': 'ИИ-инсайт',
    'de': 'KI-Einblick',
  },
};
