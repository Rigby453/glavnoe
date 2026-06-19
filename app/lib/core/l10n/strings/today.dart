// Строки экрана Today и нижней навигации. Наполнено агентом локализации.
// Ключи nav.* и today.greeting_* и today.add_food и today.main_tasks и today.later
// уже определены в common.dart — здесь только то, чего там нет.
const Map<String, Map<String, String>> todayStrings = {
  // Заголовок AppBar (мобильный ScaffoldWithNavBar._tabTitle и NavigationRail)
  'nav.fallback': {'en': 'Kaizen', 'ru': 'Kaizen'},

  // Переключатель тона в шапке Today
  'today.tone_gentle': {'en': 'Gentle', 'ru': 'Мягко', 'de': 'Sanft'},
  'today.tone_harsh': {'en': 'Harsh', 'ru': 'Строго', 'de': 'Streng'},

  // Пустое состояние списка задач
  'today.empty':
      {'en': 'Nothing planned yet.\nTap + to add your first task.', 'ru': 'Ничего не запланировано.\nНажми + и добавь первое дело.', 'de': 'Noch nichts geplant.\nTippe auf +, um deine erste Aufgabe hinzuzufügen.'},

  // Заголовок секции «Позже» в TaskList (короткий)
  'today.later_section': {'en': 'Later', 'ru': 'Позже', 'de': 'Später'},

  // Тултип щита у main-задачи
  'today.shield_tooltip': {'en': 'Protected from replanning', 'ru': 'Защищено от переноса', 'de': 'Vor Umplanung geschützt'},

  // Toast: задача отмечена выполненной (шаблон, без title — интерполируем вне перевода)
  'today.marked_done': {'en': 'marked as done', 'ru': 'отмечено выполненным', 'de': 'als erledigt markiert'},

  // Форма добавления/редактирования задачи
  'today.new_task': {'en': 'New task', 'ru': 'Новое дело', 'de': 'Neue Aufgabe'},
  'today.edit_task': {'en': 'Edit task', 'ru': 'Редактировать', 'de': 'Aufgabe bearbeiten'},
  'today.task_hint': {'en': 'What needs doing?', 'ru': 'Что нужно сделать?', 'de': 'Was steht an?'},
  'today.type_label': {'en': 'Type', 'ru': 'Тип', 'de': 'Typ'},
  'today.recent_subjects': {'en': 'Recent subjects', 'ru': 'Недавние предметы', 'de': 'Letzte Fächer'},
  'today.priority_label': {'en': 'Priority', 'ru': 'Приоритет', 'de': 'Priorität'},
  'today.priority_tooltip': {'en': 'Protected from replanning', 'ru': 'Защищено от переноса', 'de': 'Vor Umplanung geschützt'},
  'today.protected_hint': {'en': 'Protected: replanning never moves it', 'ru': 'Защищено — перенос его не коснётся', 'de': 'Geschützt: Umplanung verschiebt es nicht'},
  'today.main_limit': {'en': '3 main tasks max — keeps focus sharp', 'ru': 'Максимум 3 главных дела — иначе фокус теряется', 'de': 'Maximal 3 Hauptaufgaben — für klaren Fokus'},
  'today.max_main_snackbar': {'en': 'Max 3 main tasks', 'ru': 'Не больше 3 главных дел', 'de': 'Max. 3 Hauptaufgaben'},
  'today.duration_label': {'en': 'Duration', 'ru': 'Длительность', 'de': 'Dauer'},
  'today.duration_min_hint': {'en': 'min', 'ru': 'мин', 'de': 'Min'},
  'today.end_time': {'en': 'End time', 'ru': 'Конец', 'de': 'Endzeit'},
  'today.end_time_error': {'en': 'End time must be after start time', 'ru': 'Время конца должно быть позже начала', 'de': 'Endzeit muss nach der Startzeit liegen'},
  'today.attachments_label': {'en': 'Attachments', 'ru': 'Вложения', 'de': 'Anhänge'},
  'today.save_changes': {'en': 'Save changes', 'ru': 'Сохранить', 'de': 'Änderungen speichern'},
  'today.add_task_btn': {'en': 'Add task', 'ru': 'Добавить', 'de': 'Aufgabe hinzufügen'},
  'today.delete_task_btn': {'en': 'Delete task', 'ru': 'Удалить дело', 'de': 'Aufgabe löschen'},
  'today.title_required': {'en': 'Title is required', 'ru': 'Введи название', 'de': 'Titel ist erforderlich'},
  'today.task_removed': {'en': 'Task removed', 'ru': 'Дело удалено', 'de': 'Aufgabe gelöscht'},
  'today.remove_attachment_title': {'en': 'Remove attachment?', 'ru': 'Удалить вложение?', 'de': 'Anhang entfernen?'},
  'today.remove_attachment_btn': {'en': 'Remove', 'ru': 'Удалить', 'de': 'Entfernen'},
  'today.delete_task_title': {'en': 'Delete task?', 'ru': 'Удалить дело?', 'de': 'Aufgabe löschen?'},
  'today.photo_camera': {'en': 'Photo from camera', 'ru': 'Фото с камеры', 'de': 'Foto mit Kamera'},
  'today.photo_gallery': {'en': 'Photo from gallery', 'ru': 'Фото из галереи', 'de': 'Foto aus Galerie'},
  'today.video_gallery': {'en': 'Video from gallery', 'ru': 'Видео из галереи', 'de': 'Video aus Galerie'},

  // Утренний разбор
  'today.morning_review': {'en': 'Morning review', 'ru': 'Утренний разбор', 'de': 'Morgenrückblick'},
  'today.ai_nudge_tooltip': {'en': 'AI nudge (Premium)', 'ru': 'AI-подсказка (Premium)', 'de': 'KI-Hinweis (Premium)'},
  'today.review_btn': {'en': 'Review', 'ru': 'Разобраться', 'de': 'Überprüfen'},
  'today.carry_over': {'en': 'Carry over', 'ru': 'Перенести', 'de': 'Übertragen'},
  'today.move_all_today': {'en': 'Move all to today', 'ru': 'Всё на сегодня', 'de': 'Alles auf heute'},
  'today.smart_plans': {'en': 'Smart plans (free)', 'ru': 'Умные варианты (бесплатно)', 'de': 'Smarte Pläne (kostenlos)'},
  'today.ai_smarter_plan': {'en': 'Smarter plan with AI (Premium)', 'ru': 'Умнее с AI (Premium)', 'de': 'Klügerer Plan mit KI (Premium)'},
  'today.ai_plans': {'en': 'AI plans', 'ru': 'AI-варианты', 'de': 'KI-Pläne'},
  'today.all_caught_up': {'en': 'All caught up', 'ru': 'Всё в порядке', 'de': 'Alles erledigt'},
  'today.move_to_today_btn': {'en': 'Today', 'ru': 'Сегодня', 'de': 'Heute'},
  'today.skip_tooltip': {'en': 'Skip', 'ru': 'Пропустить', 'de': 'Überspringen'},
  'today.ai_nothing_reschedule': {'en': 'AI had nothing to reschedule', 'ru': 'AI не нашёл что перенести', 'de': 'KI hatte nichts umzuplanen'},

  // Вечерний разбор
  'today.plan_tomorrow': {'en': 'Plan tomorrow', 'ru': 'Планируем завтра', 'de': 'Morgen planen'},
  'today.plan_tomorrow_btn': {'en': 'Plan', 'ru': 'Запланировать', 'de': 'Planen'},
  'today.move_all_tomorrow': {'en': 'Move all to tomorrow', 'ru': 'Всё на завтра', 'de': 'Alles auf morgen'},
  'today.nothing_left': {'en': 'Nothing left for today', 'ru': 'На сегодня всё', 'de': 'Heute nichts mehr übrig'},
  'today.move_to_tomorrow_btn': {'en': 'Tomorrow', 'ru': 'Завтра', 'de': 'Morgen'},
  'today.ai_nothing_schedule': {'en': 'AI had nothing to schedule', 'ru': 'AI не нашёл что запланировать', 'de': 'KI hatte nichts zu planen'},

  // Карточка варианта раскладки
  'today.apply_btn': {'en': 'Apply', 'ru': 'Применить', 'de': 'Anwenden'},

  // Варианты раскладки (rule-based; AI-варианты приходят с бэкенда и не локализуются здесь)
  'variant.frontloaded': {'en': 'Front-loaded', 'ru': 'В начале дня', 'de': 'Früh starten'},
  'variant.frontloaded_reason': {
    'en': 'Earliest free slots, important first',
    'ru': 'Ранние свободные слоты, важное в приоритете',
    'de': 'Früheste freie Slots, Wichtiges zuerst',
  },
  'variant.spread_out': {'en': 'Spread out', 'ru': 'Свободнее', 'de': 'Verteilt'},
  'variant.spread_out_reason': {
    'en': 'More breathing room between tasks',
    'ru': 'Больше пространства между делами',
    'de': 'Mehr Luft zwischen den Aufgaben',
  },
  'variant.afternoon_start': {
    'en': 'Afternoon start',
    'ru': 'Со второй половины',
    'de': 'Nachmittag-Start',
  },
  'variant.afternoon_start_reason': {
    'en': 'Ease in, tackle them after noon',
    'ru': 'Плавное начало, главное — после полудня',
    'de': 'Sanft starten, Aufgaben nach dem Mittag',
  },

  // Экран завершения дня (CelebrationOverlay)
  'today.day_complete': {'en': 'Day complete', 'ru': 'День закрыт', 'de': 'Tag abgeschlossen'},
  'today.day_complete_sub': {'en': 'All the important stuff — done', 'ru': 'Всё главное — сделано', 'de': 'Das Wichtigste — erledigt'},

  // Привязка к модулю (add_task_sheet → module link picker)
  'today.module_link_label': {'en': 'Open in module', 'ru': 'Открыть в модуле', 'de': 'Im Modul öffnen'},
  'today.module_link_none': {'en': 'None', 'ru': 'Нет', 'de': 'Keine'},
  'today.module_link_workout': {'en': 'Workout', 'ru': 'Тренировка', 'de': 'Training'},
  'today.module_link_breakfast': {'en': 'Breakfast', 'ru': 'Завтрак', 'de': 'Frühstück'},
  'today.module_link_lunch': {'en': 'Lunch', 'ru': 'Обед', 'de': 'Mittagessen'},
  'today.module_link_dinner': {'en': 'Dinner', 'ru': 'Ужин', 'de': 'Abendessen'},
  'today.module_link_sleep': {'en': 'Sleep', 'ru': 'Сон', 'de': 'Schlaf'},

  // Кольцо прогресса — подпись «main» внутри кольца
  'today.ring_main': {'en': 'main', 'ru': 'главных', 'de': 'Haupt'},

  // Типы задач (чипы в форме добавления)
  'today.type_task': {'en': 'task', 'ru': 'задача', 'de': 'Aufgabe'},
  'today.type_event': {'en': 'event', 'ru': 'событие', 'de': 'Termin'},
  'today.type_exam': {'en': 'exam', 'ru': 'экзамен', 'de': 'Prüfung'},
  'today.type_deadline': {'en': 'deadline', 'ru': 'дедлайн', 'de': 'Frist'},

  // Приоритеты (чипы в форме добавления)
  'today.priority_low': {'en': 'low', 'ru': 'низкий', 'de': 'niedrig'},
  'today.priority_medium': {'en': 'medium', 'ru': 'средний', 'de': 'mittel'},
  'today.priority_high': {'en': 'high', 'ru': 'высокий', 'de': 'hoch'},
  'today.priority_main': {'en': 'main', 'ru': 'главное', 'de': 'Haupt'},

  // FAB «+ Добавить»
  'today.fab_add': {'en': '+ Add', 'ru': '+ Добавить', 'de': '+ Hinzufügen'},

  // Строка streak — «день/дней»
  'today.streak_day': {'en': 'day', 'ru': 'день', 'de': 'Tag'},
  'today.streak_days': {'en': 'days', 'ru': 'дн.', 'de': 'Tage'},

  // ---------------------------------------------------------------------------
  // ToneCopy: Kai говорит эти строки в речевом пузыре (MASCOT.md §4, SPEC B6).
  // Gentle / harsh варианты; интерполированные строки через {count}.
  // ---------------------------------------------------------------------------

  // Утренний разбор (gentle)
  'kai.morning_review_gentle_one': {
    'en': 'Yesterday left 1 loose end — let\'s tuck it into today.',
    'ru': 'Вчера осталось одно незавершённое — разберёмся сегодня.',
    'de': 'Gestern blieb 1 offener Punkt — lass uns das heute lösen.',
  },
  'kai.morning_review_gentle_many': {
    'en': 'Yesterday left {count} loose ends — let\'s fit them around what matters.',
    'ru': 'Вчера осталось {count} незавершённых — впишем их вокруг главного.',
    'de': 'Gestern blieben {count} offene Punkte — lass uns sie einplanen.',
  },

  // Утренний разбор (harsh)
  'kai.morning_review_harsh_one': {
    'en': '1 task ghosted you. Sort it before it piles up.',
    'ru': '1 задача тебя обошла. Разберись, пока не накопилось.',
    'de': '1 Aufgabe hat dich verpasst. Löse es, bevor es sich häuft.',
  },
  'kai.morning_review_harsh_many': {
    'en': '{count} tasks ghosted you. I lined them up — don\'t ghost them again.',
    'ru': '{count} задач тебя обошли. Я их выстроил — не игнорируй снова.',
    'de': '{count} Aufgaben haben dich verpasst. Ich habe sie aufgelistet — ignoriere sie nicht wieder.',
  },

  // Всё выполнено (gentle)
  'kai.all_done_gentle': {
    'en': 'Everything that mattered — done. Proud of you.',
    'ru': 'Всё главное — сделано. Горжусь тобой.',
    'de': 'Alles Wichtige — erledigt. Stolz auf dich.',
  },

  // Всё выполнено (harsh)
  'kai.all_done_harsh': {
    'en': 'Everything done. Don\'t get cocky.',
    'ru': 'Всё сделано. Не расслабляйся.',
    'de': 'Alles erledigt. Werd nicht übermütig.',
  },

  // Вечерний разбор (gentle, нет незавершённых)
  'kai.evening_none_gentle': {
    'en': 'Want tomorrow handled? I\'ve got a plan ready.',
    'ru': 'Хочешь, чтобы завтра было под контролем? Есть план.',
    'de': 'Soll morgen alles klappen? Ich habe einen Plan.',
  },

  // Вечерний разбор (gentle, есть незавершённые)
  'kai.evening_pending_gentle': {
    'en': '{count} unfinished today — want me to fit them into tomorrow?',
    'ru': '{count} незавершённых сегодня — вписать их в завтра?',
    'de': '{count} heute unfertig — soll ich sie für morgen einplanen?',
  },

  // Вечерний разбор (harsh, нет незавершённых)
  'kai.evening_none_harsh': {
    'en': 'Plan tomorrow now, or wing it and panic. Your call.',
    'ru': 'Планируй завтра сейчас, или потом паникуй. Твой выбор.',
    'de': 'Plane morgen jetzt, oder improvisiere und panik. Deine Wahl.',
  },

  // Вечерний разбор (harsh, есть незавершённые)
  'kai.evening_pending_harsh': {
    'en': '{count} left over today. Plan tomorrow now or wing it and panic.',
    'ru': '{count} осталось сегодня. Планируй завтра сейчас или паникуй.',
    'de': '{count} heute übrig. Plane morgen jetzt oder improvisiere und panik.',
  },

  // Kai — пустой день / ничего не запланировано
  'kai.empty_day_gentle': {
    'en': 'Nothing planned yet. Add something that matters.',
    'ru': 'Ничего не запланировано. Добавь то, что важно.',
    'de': 'Noch nichts geplant. Füge etwas Wichtiges hinzu.',
  },
  'kai.empty_day_harsh': {
    'en': 'Empty day. That\'s on you.',
    'ru': 'Пустой день. Ну и кто виноват?',
    'de': 'Leerer Tag. Das liegt bei dir.',
  },

  // Kai — нейтральное приветствие (idle, несколько задач)
  'kai.idle_morning_gentle': {
    'en': 'Ready when you are.',
    'ru': 'Готов, когда ты.',
    'de': 'Bereit, wenn du es bist.',
  },
  'kai.idle_afternoon_gentle': {
    'en': 'Keep going — you\'re doing great.',
    'ru': 'Продолжай — всё идёт хорошо.',
    'de': 'Weiter so — du machst das gut.',
  },
  'kai.idle_evening_gentle': {
    'en': 'Almost there. Finish strong.',
    'ru': 'Почти финиш. Закончи сильно.',
    'de': 'Fast geschafft. Stark zu Ende.',
  },
  'kai.idle_morning_harsh': {
    'en': 'Stop reading this. Start working.',
    'ru': 'Хватит читать. Начинай работать.',
    'de': 'Hör auf zu lesen. Fang an zu arbeiten.',
  },
  'kai.idle_afternoon_harsh': {
    'en': 'Time is ticking. Focus.',
    'ru': 'Время идёт. Сосредоточься.',
    'de': 'Die Zeit läuft. Fokus.',
  },
  'kai.idle_evening_harsh': {
    'en': 'Don\'t let the day slip. Finish it.',
    'ru': 'Не упусти день. Заверши его.',
    'de': 'Lass den Tag nicht gleiten. Beende ihn.',
  },
};
