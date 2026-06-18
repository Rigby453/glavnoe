// Строки Health: Workouts, Breathing, Posture, Meditation, Screen time,
// Sleep report, Water. Наполняется агентом локализации.
const Map<String, Map<String, String>> healthBStrings = {
  // ---------------------------------------------------------------------------
  // workout.*  —  workouts_screen.dart, workout_editor_screen.dart, workout_trainer_screen.dart
  // ---------------------------------------------------------------------------

  'workout.title': {'en': 'Workouts', 'ru': 'Тренировки', 'de': 'Training'},
  'workout.new_workout': {
    'en': 'New workout',
    'ru': 'Новая тренировка',
    'de': 'Neues Training',
  },
  'workout.history': {'en': 'History', 'ru': 'История', 'de': 'Verlauf'},
  'workout.empty_state': {
    'en': 'No workouts yet — create one\nand add exercises to it',
    'ru': 'Тренировок пока нет — создай одну\nи добавь в неё упражнения',
    'de': 'Noch kein Training — erstelle eines\nund füge Übungen hinzu',
  },
  'workout.name_hint': {
    'en': 'Workout name',
    'ru': 'Название тренировки',
    'de': 'Name des Trainings',
  },
  'workout.delete_title': {
    'en': 'Delete workout?',
    'ru': 'Удалить тренировку?',
    'de': 'Training löschen?',
  },
  'workout.delete_body': {
    'en': 'Its exercises will be removed too.',
    'ru': 'Все упражнения в ней тоже удалятся.',
    'de': 'Die dazugehörigen Übungen werden ebenfalls gelöscht.',
  },
  'workout.rename': {
    'en': 'Rename',
    'ru': 'Переименовать',
    'de': 'Umbenennen',
  },
  'workout.rename_title': {
    'en': 'Rename workout',
    'ru': 'Переименовать тренировку',
    'de': 'Training umbenennen',
  },
  'workout.add_exercise': {
    'en': 'Add exercise',
    'ru': 'Добавить упражнение',
    'de': 'Übung hinzufügen',
  },
  'workout.start_workout': {
    'en': 'Start workout',
    'ru': 'Начать тренировку',
    'de': 'Training starten',
  },
  'workout.empty_exercises': {
    'en': 'No exercises yet —\ntap "Add exercise" to get started',
    'ru': 'Упражнений пока нет —\nнажми «Добавить упражнение»',
    'de': 'Noch keine Übungen —\ntippe auf „Übung hinzufügen"',
  },
  'workout.add_exercise_title': {
    'en': 'Add exercise',
    'ru': 'Новое упражнение',
    'de': 'Übung hinzufügen',
  },
  'workout.edit_exercise_title': {
    'en': 'Edit exercise',
    'ru': 'Редактировать упражнение',
    'de': 'Übung bearbeiten',
  },
  'workout.exercise_name': {
    'en': 'Exercise name',
    'ru': 'Название упражнения',
    'de': 'Name der Übung',
  },
  'workout.sets': {'en': 'Sets', 'ru': 'Подходы', 'de': 'Sätze'},
  'workout.reps': {'en': 'Reps', 'ru': 'Повторения', 'de': 'Wiederholungen'},
  'workout.weight_kg': {
    'en': 'Weight (kg)',
    'ru': 'Вес (кг)',
    'de': 'Gewicht (kg)',
  },
  'workout.rest_s': {
    'en': 'Rest (s)',
    'ru': 'Отдых (с)',
    'de': 'Pause (s)',
  },
  'workout.technique_tip': {
    'en': 'Technique tip',
    'ru': 'Совет по технике',
    'de': 'Technik-Tipp',
  },
  'workout.optional': {
    'en': 'optional',
    'ru': 'необязательно',
    'de': 'optional',
  },
  // Trainer screen
  'workout.exercise_of': {
    'en': 'Exercise',
    'ru': 'Упражнение',
    'de': 'Übung',
  },
  'workout.of': {'en': 'of', 'ru': 'из', 'de': 'von'},
  'workout.set_label': {'en': 'Set', 'ru': 'Подход', 'de': 'Satz'},
  'workout.reps_label': {'en': 'reps', 'ru': 'повт.', 'de': 'Wdh.'},
  'workout.next_label': {'en': 'Next', 'ru': 'Далее', 'de': 'Weiter'},
  'workout.stop': {'en': 'Stop', 'ru': 'Остановить', 'de': 'Stopp'},
  'workout.stop_title': {
    'en': 'Stop workout?',
    'ru': 'Прервать тренировку?',
    'de': 'Training abbrechen?',
  },
  'workout.stop_body': {
    'en': "Progress won't be saved.",
    'ru': 'Прогресс не сохранится.',
    'de': 'Fortschritt wird nicht gespeichert.',
  },
  'workout.continue_btn': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Weiter',
  },
  'workout.set_done': {
    'en': 'Set done',
    'ru': 'Подход выполнен',
    'de': 'Satz beendet',
  },
  'workout.rest_phase': {
    'en': 'Rest',
    'ru': 'Отдых',
    'de': 'Pause',
  },
  'workout.skip_rest': {
    'en': 'Skip rest',
    'ru': 'Пропустить отдых',
    'de': 'Pause überspringen',
  },
  'workout.did_it': {
    'en': 'Did it as planned!',
    'ru': 'Сделано по плану!',
    'de': 'Wie geplant erledigt!',
  },

  // ---------------------------------------------------------------------------
  // breathing.*  —  breathing_screen.dart
  // ---------------------------------------------------------------------------

  'breathing.title': {
    'en': 'Breathing',
    'ru': 'Дыхание',
    'de': 'Atemübungen',
  },
  'breathing.choose_technique': {
    'en': 'Choose a technique',
    'ru': 'Выбери технику',
    'de': 'Technik wählen',
  },
  'breathing.duration': {
    'en': 'Duration',
    'ru': 'Длительность',
    'de': 'Dauer',
  },
  'breathing.start': {'en': 'Start', 'ru': 'Начать', 'de': 'Starten'},
  'breathing.stop': {'en': 'Stop', 'ru': 'Остановить', 'de': 'Stopp'},
  'breathing.session_complete': {
    'en': 'Session complete',
    'ru': 'Сессия завершена',
    'de': 'Sitzung abgeschlossen',
  },
  // Фазы дыхания — используются в switch по label из breathing_engine.dart
  'breathing.inhale': {'en': 'Inhale', 'ru': 'Вдох', 'de': 'Einatmen'},
  'breathing.exhale': {'en': 'Exhale', 'ru': 'Выдох', 'de': 'Ausatmen'},
  'breathing.hold': {'en': 'Hold', 'ru': 'Задержка', 'de': 'Halten'},

  // ---------------------------------------------------------------------------
  // posture.*  —  posture_screen.dart
  // ---------------------------------------------------------------------------

  'posture.title': {'en': 'Posture', 'ru': 'Осанка', 'de': 'Haltung'},
  'posture.reminders_title': {
    'en': 'Sit-up-straight reminders',
    'ru': 'Напоминания выпрямиться',
    'de': 'Erinnerungen zur Körperhaltung',
  },
  'posture.reminders_subtitle': {
    'en': 'Every 2 hours, 10:00–18:00',
    'ru': 'Каждые 2 часа, 10:00–18:00',
    'de': 'Alle 2 Stunden, 10:00–18:00',
  },
  'posture.permission_required': {
    'en': 'Notification permission required. Enable it in system settings.',
    'ru': 'Нужно разрешение на уведомления. Включи его в настройках системы.',
    'de': 'Benachrichtigungserlaubnis erforderlich. Aktiviere sie in den Systemeinstellungen.',
  },
  'posture.exercises': {
    'en': 'Exercises',
    'ru': 'Упражнения',
    'de': 'Übungen',
  },

  // ---------------------------------------------------------------------------
  // meditation.*  —  meditation_screen.dart
  // ---------------------------------------------------------------------------

  'meditation.title': {
    'en': 'Meditation',
    'ru': 'Медитация',
    'de': 'Meditation',
  },
  'meditation.session_complete': {
    'en': 'Session complete',
    'ru': 'Сессия завершена',
    'de': 'Sitzung abgeschlossen',
  },
  'meditation.session_complete_body': {
    'en': 'Take a moment to notice how you feel.',
    'ru': 'Отметь, как ты себя чувствуешь.',
    'de': 'Nimm dir einen Moment, um zu bemerken, wie du dich fühlst.',
  },
  'meditation.next': {'en': 'Next', 'ru': 'Далее', 'de': 'Weiter'},
  'meditation.finish': {
    'en': 'Finish',
    'ru': 'Завершить',
    'de': 'Beenden',
  },
  'meditation.end_session': {
    'en': 'End session',
    'ru': 'Завершить сессию',
    'de': 'Sitzung beenden',
  },
  'meditation.step': {
    'en': 'Step',
    'ru': 'Шаг',
    'de': 'Schritt',
  },

  // ---------------------------------------------------------------------------
  // screentime.*  —  screen_time_screen.dart
  // ---------------------------------------------------------------------------

  'screentime.title': {
    'en': 'Screen Time',
    'ru': 'Экранное время',
    'de': 'Bildschirmzeit',
  },
  'screentime.set_daily_limits': {
    'en': 'Set daily limits',
    'ru': 'Установить дневные лимиты',
    'de': 'Tageslimits festlegen',
  },
  'screentime.usage_data': {
    'en': 'Usage data',
    'ru': 'Данные об использовании',
    'de': 'Nutzungsdaten',
  },
  'screentime.usage_coming_soon': {
    'en': 'Usage data requires system permissions not yet available. Coming soon.',
    'ru': 'Данные об использовании требуют системных разрешений — скоро будут доступны.',
    'de': 'Nutzungsdaten erfordern Systemberechtigungen, die noch nicht verfügbar sind.',
  },
  'screentime.tips': {'en': 'Tips', 'ru': 'Советы', 'de': 'Tipps'},
  'screentime.tip_autoplay': {
    'en': 'Turn off autoplay to avoid unintentional binge-watching.',
    'ru': 'Отключи автовоспроизведение, чтобы не засматриваться случайно.',
    'de': 'Deaktiviere die Autoplay-Funktion, um unbeabsichtigtes Binge-Watching zu vermeiden.',
  },
  'screentime.tip_grayscale': {
    'en': 'Use grayscale mode to make your screen less appealing.',
    'ru': 'Включи чёрно-белый режим — экран станет менее привлекательным.',
    'de': 'Nutze den Graustufen-Modus, damit der Bildschirm weniger anziehend wirkt.',
  },
  'screentime.tip_phone_away': {
    'en': 'Keep your phone in another room while studying or sleeping.',
    'ru': 'Во время учёбы или сна убирай телефон в другую комнату.',
    'de': 'Lass dein Handy beim Lernen oder Schlafen in einem anderen Raum.',
  },
  'screentime.no_limit': {
    'en': 'No limit',
    'ru': 'Без лимита',
    'de': 'Kein Limit',
  },
  'screentime.min_per_day': {
    'en': 'min/day',
    'ru': 'мин/день',
    'de': 'Min/Tag',
  },
  'screentime.set_daily_time_limit': {
    'en': 'Set a daily time limit',
    'ru': 'Установить дневной лимит',
    'de': 'Tageslimit festlegen',
  },
  'screentime.remove_limit': {
    'en': 'Remove limit',
    'ru': 'Убрать лимит',
    'de': 'Limit entfernen',
  },

  // ---------------------------------------------------------------------------
  // sleep.*  —  sleep_report_screen.dart
  // ---------------------------------------------------------------------------

  'sleep.report_title': {
    'en': 'Sleep Report',
    'ru': 'Отчёт о сне',
    'de': 'Schlafbericht',
  },
  'sleep.select_date': {
    'en': 'Select date',
    'ru': 'Выбрать дату',
    'de': 'Datum wählen',
  },
  'sleep.history': {
    'en': 'Sleep History',
    'ru': 'История сна',
    'de': 'Schlafverlauf',
  },
  'sleep.no_data': {
    'en': 'No sleep data for this date',
    'ru': 'Нет данных о сне за этот день',
    'de': 'Keine Schlafdaten für dieses Datum',
  },
  'sleep.avg': {
    'en': 'Avg Sleep',
    'ru': 'Среднее',
    'de': 'Durchschn.',
  },
  'sleep.best_night': {
    'en': 'Best Night',
    'ru': 'Лучшая ночь',
    'de': 'Beste Nacht',
  },
  'sleep.total_nights': {
    'en': 'Total Nights',
    'ru': 'Всего ночей',
    'de': 'Nächte gesamt',
  },
  'sleep.in_progress': {
    'en': 'In progress',
    'ru': 'Идёт сейчас',
    'de': 'Läuft gerade',
  },
  'sleep.today': {'en': 'Today', 'ru': 'Сегодня', 'de': 'Heute'},
  'sleep.yesterday': {'en': 'Yesterday', 'ru': 'Вчера', 'de': 'Gestern'},

  // ---------------------------------------------------------------------------
  // water.*  —  water_fullscreen_screen.dart, water_report_screen.dart
  // ---------------------------------------------------------------------------

  'water.title': {'en': 'Water', 'ru': 'Вода', 'de': 'Wasser'},
  'water.history_tooltip': {
    'en': 'History',
    'ru': 'История',
    'de': 'Verlauf',
  },
  'water.undo_last': {
    'en': 'Undo last',
    'ru': 'Отменить последнее',
    'de': 'Letzte rückgängig',
  },
  'water.food_tip': {
    'en': 'Coffee & tea from Food count toward your goal',
    'ru': 'Кофе и чай из раздела «Питание» тоже идут в счёт',
    'de': 'Kaffee & Tee aus der Ernährung zählen zu deinem Ziel',
  },
  'water.drink_reminders': {
    'en': 'Drink reminders',
    'ru': 'Напоминания пить воду',
    'de': 'Trinkerinnerungen',
  },
  'water.reminders_subtitle': {
    'en': 'Every 2 hours, 9:00–21:00',
    'ru': 'Каждые 2 часа, 9:00–21:00',
    'de': 'Alle 2 Stunden, 9:00–21:00',
  },
  // Water report
  'water.report_title': {
    'en': 'Water Report',
    'ru': 'Отчёт о воде',
    'de': 'Wasserbericht',
  },
  'water.logs_section': {
    'en': 'Water Logs',
    'ru': 'Записи',
    'de': 'Einträge',
  },
  'water.no_logs': {
    'en': 'No water logs for this day',
    'ru': 'Нет записей за этот день',
    'de': 'Keine Wassereinträge für diesen Tag',
  },
  'water.stat_total': {'en': 'Total', 'ru': 'Всего', 'de': 'Gesamt'},
  'water.stat_goal': {'en': 'Goal', 'ru': 'Цель', 'de': 'Ziel'},
  'water.stat_status': {'en': 'Status', 'ru': 'Статус', 'de': 'Status'},
  'water.goal_met': {'en': 'Goal Met!', 'ru': 'Цель!', 'de': 'Ziel erreicht!'},
};
