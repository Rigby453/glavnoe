// Строки экранов Auth, Onboarding, Import, Focus, Wrapped. Наполняется агентом.
const Map<String, Map<String, String>> miscStrings = {
  // ---------------------------------------------------------------------------
  // Auth (auth_screen.dart, forgot_password_screen.dart)
  // ---------------------------------------------------------------------------
  'auth.tagline': {
    'en': "The important stuff won't slip.",
    'ru': 'Главное не ускользнёт.',
    'de': 'Das Wichtige geht nicht verloren.',
  },
  'auth.welcome_back': {
    'en': 'Welcome back',
    'ru': 'С возвращением',
    'de': 'Willkommen zurück',
  },
  'auth.create_account': {
    'en': 'Create your account',
    'ru': 'Создай аккаунт',
    'de': 'Konto erstellen',
  },
  'auth.field_phone': {
    'en': 'Phone (+7…)',
    'ru': 'Телефон (+7…)',
    'de': 'Telefon (+7…)',
  },
  'auth.field_phone_hint': {
    'en': '+7 999 123-45-67',
    'ru': '+7 999 123-45-67',
    'de': '+7 999 123-45-67',
  },
  'auth.field_email': {
    'en': 'Email',
    'ru': 'Эл. почта',
    'de': 'E-Mail',
  },
  'auth.field_password': {
    'en': 'Password',
    'ru': 'Пароль',
    'de': 'Passwort',
  },
  'auth.field_name': {
    'en': 'Name',
    'ru': 'Имя',
    'de': 'Name',
  },
  'auth.tab_phone': {
    'en': 'Phone',
    'ru': 'Телефон',
    'de': 'Telefon',
  },
  'auth.tab_email': {
    'en': 'Email',
    'ru': 'Эл. почта',
    'de': 'E-Mail',
  },
  'auth.btn_login': {
    'en': 'Log in',
    'ru': 'Войти',
    'de': 'Anmelden',
  },
  'auth.btn_signup': {
    'en': 'Sign up',
    'ru': 'Зарегистрироваться',
    'de': 'Registrieren',
  },
  'auth.switch_to_signup': {
    'en': "Don't have an account? Sign up",
    'ru': 'Нет аккаунта? Зарегистрируйся',
    'de': 'Noch kein Konto? Registrieren',
  },
  'auth.switch_to_login': {
    'en': 'Already have an account? Log in',
    'ru': 'Уже есть аккаунт? Войти',
    'de': 'Schon ein Konto? Anmelden',
  },
  'auth.forgot_password': {
    'en': 'Forgot password?',
    'ru': 'Забыл пароль?',
    'de': 'Passwort vergessen?',
  },
  'auth.continue_offline': {
    'en': 'Continue offline',
    'ru': 'Продолжить без аккаунта',
    'de': 'Offline fortfahren',
  },
  // Ошибки валидации
  'auth.err_phone_empty': {
    'en': 'Please enter your phone number',
    'ru': 'Введи номер телефона',
    'de': 'Bitte Telefonnummer eingeben',
  },
  'auth.err_phone_invalid': {
    'en': 'Enter a valid Russian phone number (+7…)',
    'ru': 'Введи российский номер (+7…)',
    'de': 'Gültige russische Nummer eingeben (+7…)',
  },
  'auth.err_email_empty': {
    'en': 'Please enter your email',
    'ru': 'Введи адрес эл. почты',
    'de': 'Bitte E-Mail eingeben',
  },
  'auth.err_password_empty': {
    'en': 'Please enter your password',
    'ru': 'Введи пароль',
    'de': 'Bitte Passwort eingeben',
  },
  'auth.err_name_empty': {
    'en': 'Please enter your name',
    'ru': 'Введи имя',
    'de': 'Bitte Namen eingeben',
  },
  'auth.err_password_short': {
    'en': 'Password must be at least 8 characters',
    'ru': 'Пароль — минимум 8 символов',
    'de': 'Passwort muss mindestens 8 Zeichen haben',
  },
  'auth.err_generic': {
    'en': 'Something went wrong. Please try again.',
    'ru': 'Что-то пошло не так. Попробуй ещё раз.',
    'de': 'Etwas ist schiefgelaufen. Bitte versuche es erneut.',
  },
  // Forgot password
  'auth.reset_title': {
    'en': 'Reset password',
    'ru': 'Сброс пароля',
    'de': 'Passwort zurücksetzen',
  },
  'auth.reset_step1_heading': {
    'en': 'Enter your email',
    'ru': 'Введи свой e-mail',
    'de': 'E-Mail eingeben',
  },
  'auth.reset_step1_body': {
    'en': "We'll send you a 6-digit code to reset your password.",
    'ru': 'Мы отправим тебе 6-значный код для сброса пароля.',
    'de': 'Wir senden dir einen 6-stelligen Code zum Zurücksetzen.',
  },
  'auth.reset_step2_heading': {
    'en': 'Enter the code',
    'ru': 'Введи код',
    'de': 'Code eingeben',
  },
  'auth.reset_step2_body': {
    'en': 'Check your email for a 6-digit code.',
    'ru': 'Проверь почту — там 6-значный код.',
    'de': 'Überprüfe deine E-Mail auf den 6-stelligen Code.',
  },
  'auth.reset_field_code': {
    'en': '6-digit code',
    'ru': '6-значный код',
    'de': '6-stelliger Code',
  },
  'auth.reset_field_new_password': {
    'en': 'New password (min 8 chars)',
    'ru': 'Новый пароль (мин. 8 символов)',
    'de': 'Neues Passwort (min. 8 Zeichen)',
  },
  'auth.reset_btn_send_code': {
    'en': 'Send code',
    'ru': 'Отправить код',
    'de': 'Code senden',
  },
  'auth.reset_btn_reset': {
    'en': 'Reset password',
    'ru': 'Сбросить пароль',
    'de': 'Passwort zurücksetzen',
  },
  'auth.reset_err_code_pw': {
    'en': 'Enter 6-digit code and password (min 8 chars)',
    'ru': 'Введи 6-значный код и пароль (мин. 8 символов)',
    'de': '6-stelligen Code und Passwort (min. 8 Zeichen) eingeben',
  },
  'auth.reset_err_send': {
    'en': 'Failed to send code. Check your email.',
    'ru': 'Не удалось отправить код. Проверь адрес почты.',
    'de': 'Code konnte nicht gesendet werden. E-Mail prüfen.',
  },
  'auth.reset_err_invalid_code': {
    'en': 'Invalid or expired code.',
    'ru': 'Неверный или устаревший код.',
    'de': 'Ungültiger oder abgelaufener Code.',
  },
  'auth.reset_success_snack': {
    'en': 'Password updated! Please sign in.',
    'ru': 'Пароль обновлён! Войди снова.',
    'de': 'Passwort aktualisiert! Bitte anmelden.',
  },

  // ---------------------------------------------------------------------------
  // Onboarding (onboarding_screen.dart)
  // ---------------------------------------------------------------------------
  'onboarding.slide1_title': {
    'en': 'Plan what matters',
    'ru': 'Планируй главное',
    'de': 'Das Wichtige planen',
  },
  'onboarding.slide1_subtitle': {
    'en': 'Mark up to 3 "main" tasks a day and build a streak by finishing them.',
    'ru': 'Отмечай до 3 «главных» задач в день и поддерживай серию их выполнения.',
    'de': 'Markiere bis zu 3 „Hauptaufgaben" pro Tag und halte eine Streak aufrecht.',
  },
  'onboarding.slide2_title': {
    'en': 'Nothing slips',
    'ru': 'Ничего не ускользнёт',
    'de': 'Nichts geht verloren',
  },
  'onboarding.slide2_subtitle': {
    'en': 'Unfinished tasks are carried into today by priority — with your confirmation.',
    'ru': 'Незавершённые задачи переносятся на сегодня по приоритету — с твоим подтверждением.',
    'de': 'Unerledigte Aufgaben werden nach Priorität übertragen — mit deiner Bestätigung.',
  },
  'onboarding.slide3_title': {
    'en': 'Understand why',
    'ru': 'Понимай причины',
    'de': 'Verstehe warum',
  },
  'onboarding.slide3_subtitle': {
    'en': 'A quick diary captures your mood and what got in the way.',
    'ru': 'Краткий дневник фиксирует настроение и то, что мешало.',
    'de': 'Ein kurzes Tagebuch erfasst deine Stimmung und Hindernisse.',
  },
  'onboarding.btn_next': {
    'en': 'Next',
    'ru': 'Далее',
    'de': 'Weiter',
  },
  'onboarding.btn_get_started': {
    'en': 'Get started',
    'ru': 'Начать',
    'de': 'Loslegen',
  },

  // ---------------------------------------------------------------------------
  // Setup flow (setup_flow.dart)
  // ---------------------------------------------------------------------------
  'onboarding.setup_progress': {
    'en': 'Set up',
    'ru': 'Настройка',
    'de': 'Einrichten',
  },
  'onboarding.skip_all': {
    'en': 'Skip all',
    'ru': 'Пропустить всё',
    'de': 'Alles überspringen',
  },
  'onboarding.btn_continue': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Fortfahren',
  },
  'onboarding.btn_start': {
    'en': 'Start',
    'ru': 'Начать',
    'de': 'Starten',
  },
  // Шаг 1: интересы
  'onboarding.interests_title': {
    'en': 'What matters to you?',
    'ru': 'Что для тебя важно?',
    'de': 'Was ist dir wichtig?',
  },
  'onboarding.interests_subtitle': {
    'en': 'Pick areas you want to keep on track. This shapes defaults.',
    'ru': 'Выбери области, за которыми хочешь следить. Это влияет на настройки по умолчанию.',
    'de': 'Wähle Bereiche, die du im Blick behalten möchtest. Das beeinflusst die Standardeinstellungen.',
  },
  // Чипы интересов
  'onboarding.interest_university': {
    'en': 'University',
    'ru': 'Университет',
    'de': 'Universität',
  },
  'onboarding.interest_exams': {
    'en': 'Exams',
    'ru': 'Экзамены',
    'de': 'Prüfungen',
  },
  'onboarding.interest_side_projects': {
    'en': 'Side projects',
    'ru': 'Свои проекты',
    'de': 'Nebenprojekte',
  },
  'onboarding.interest_fitness': {
    'en': 'Fitness',
    'ru': 'Фитнес',
    'de': 'Fitness',
  },
  'onboarding.interest_nutrition': {
    'en': 'Nutrition',
    'ru': 'Питание',
    'de': 'Ernährung',
  },
  'onboarding.interest_sleep': {
    'en': 'Sleep',
    'ru': 'Сон',
    'de': 'Schlaf',
  },
  'onboarding.interest_focus': {
    'en': 'Focus',
    'ru': 'Фокус',
    'de': 'Fokus',
  },
  'onboarding.interest_reading': {
    'en': 'Reading',
    'ru': 'Чтение',
    'de': 'Lesen',
  },
  // Шаг 2: импорт
  'onboarding.import_title': {
    'en': 'Bring your timetable',
    'ru': 'Добавь своё расписание',
    'de': 'Stundenplan importieren',
  },
  'onboarding.import_subtitle': {
    'en':
        'Paste your class schedule as text and Kaizen turns it into events. '
        'You can always do it later from the Plan tab.',
    'ru':
        'Вставь расписание занятий текстом — Kaizen превратит его в события. '
        'Это можно сделать позже во вкладке «План».',
    'de':
        'Füge deinen Stundenplan als Text ein — Kaizen macht daraus Termine. '
        'Das kannst du auch später im Tab „Plan" tun.',
  },
  'onboarding.import_now': {
    'en': 'Import now',
    'ru': 'Импортировать сейчас',
    'de': 'Jetzt importieren',
  },
  'onboarding.import_premium_hint': {
    'en': 'Photo import with AI is available on Premium.',
    'ru': 'Импорт с фото через AI доступен на Premium.',
    'de': 'Foto-Import mit KI ist im Premium verfügbar.',
  },
  // Шаг 3: время разборов
  'onboarding.review_title': {
    'en': 'When should we check in?',
    'ru': 'Когда делать разбор дня?',
    'de': 'Wann soll der Check-in sein?',
  },
  'onboarding.review_subtitle': {
    'en':
        "Morning review re-plans yesterday's loose ends; evening review prepares tomorrow.",
    'ru':
        'Утренний разбор переносит незавершённое; вечерний — готовит завтрашний день.',
    'de':
        'Das Morgen-Review plant Unerledigtes um; das Abend-Review bereitet den nächsten Tag vor.',
  },
  'onboarding.review_morning': {
    'en': 'Morning review',
    'ru': 'Утренний разбор',
    'de': 'Morgen-Review',
  },
  'onboarding.review_evening': {
    'en': 'Evening review',
    'ru': 'Вечерний разбор',
    'de': 'Abend-Review',
  },
  // Шаг 4: тон
  'onboarding.tone_title': {
    'en': 'Pick your tone',
    'ru': 'Выбери тон',
    'de': 'Ton wählen',
  },
  'onboarding.tone_subtitle': {
    'en': 'How should Kaizen talk to you? You can switch any time.',
    'ru': 'Как Kaizen должен общаться с тобой? Можно изменить в любой момент.',
    'de': 'Wie soll Kaizen mit dir sprechen? Jederzeit änderbar.',
  },
  'onboarding.tone_gentle_subtitle': {
    'en':
        '"Yesterday left 3 loose ends — I tucked them into today around what matters."',
    'ru':
        '«Вчера осталось 3 незавершённых дела — я вписал их в сегодня вокруг главного.»',
    'de':
        '„Gestern blieben 3 Dinge offen — ich habe sie rund um das Wichtige eingeplant."',
  },
  'onboarding.tone_harsh_subtitle': {
    'en': '"3 tasks ghosted you yesterday. I sorted them. Don\'t ghost them again."',
    'ru': '«Вчера ты слил 3 задачи. Я разобрался. Больше не сливай.»',
    'de': '„3 Aufgaben hast du gestern ignoriert. Ich habe sie sortiert. Nochmal?"',
  },
  // Шаг 5: тема
  'onboarding.theme_title': {
    'en': 'Choose a theme',
    'ru': 'Выбери тему',
    'de': 'Thema wählen',
  },
  'onboarding.theme_subtitle': {
    'en': 'Each theme has its own face and typography.',
    'ru': 'У каждой темы свой облик и типографика.',
    'de': 'Jedes Thema hat sein eigenes Aussehen und Typografie.',
  },
  // Шаг 6: нормы
  'onboarding.norms_title': {
    'en': 'Daily water goal',
    'ru': 'Дневная норма воды',
    'de': 'Tägliches Wasserziel',
  },
  'onboarding.norms_subtitle': {
    'en': "Enter your stats and we'll suggest a starting point — you can always adjust.",
    'ru': 'Введи параметры — мы подберём норму. Её всегда можно скорректировать.',
    'de': 'Gib deine Daten ein — wir schlagen einen Startwert vor, der jederzeit anpassbar ist.',
  },
  'onboarding.norms_weight': {
    'en': 'Weight (kg)',
    'ru': 'Вес (кг)',
    'de': 'Gewicht (kg)',
  },
  'onboarding.norms_height': {
    'en': 'Height (cm)',
    'ru': 'Рост (см)',
    'de': 'Größe (cm)',
  },
  'onboarding.norms_height_helper': {
    'en': 'For analytics',
    'ru': 'Для аналитики',
    'de': 'Für die Analyse',
  },
  'onboarding.norms_activity': {
    'en': 'Activity level',
    'ru': 'Уровень активности',
    'de': 'Aktivitätslevel',
  },
  'onboarding.activity_low': {
    'en': 'Low',
    'ru': 'Низкий',
    'de': 'Niedrig',
  },
  'onboarding.activity_medium': {
    'en': 'Medium',
    'ru': 'Средний',
    'de': 'Mittel',
  },
  'onboarding.activity_high': {
    'en': 'High',
    'ru': 'Высокий',
    'de': 'Hoch',
  },
  'onboarding.norms_recommended': {
    'en': 'Recommended',
    'ru': 'Рекомендую',
    'de': 'Empfohlen',
  },
  'onboarding.norms_adjust_hint': {
    'en': 'Drag to adjust manually.',
    'ru': 'Потяни, чтобы скорректировать вручную.',
    'de': 'Ziehen zum manuellen Anpassen.',
  },

  // ---------------------------------------------------------------------------
  // Import (import_sheet.dart)
  // ---------------------------------------------------------------------------
  'import.title': {
    'en': 'Import schedule',
    'ru': 'Импорт расписания',
    'de': 'Stundenplan importieren',
  },
  'import.paste_hint_body': {
    'en': 'Paste lines like "09:00 Math lecture", one per line.',
    'ru': 'Вставь строки вида «09:00 Лекция по математике», по одной на строке.',
    'de': 'Zeilen wie „09:00 Mathe-Vorlesung" einfügen, eine pro Zeile.',
  },
  'import.text_hint': {
    'en': '09:00 Math lecture\n14:30 Gym',
    'ru': '09:00 Лекция по математике\n14:30 Спортзал',
    'de': '09:00 Mathematik\n14:30 Sport',
  },
  'import.btn_example': {
    'en': 'Example',
    'ru': 'Пример',
    'de': 'Beispiel',
  },
  'import.btn_import': {
    'en': 'Import',
    'ru': 'Импортировать',
    'de': 'Importieren',
  },
  'import.btn_from_photo': {
    'en': 'From photo (Premium)',
    'ru': 'С фото (Premium)',
    'de': 'Aus Foto (Premium)',
  },
  'import.btn_from_ics': {
    'en': 'From ICS file (Google / Apple / Outlook)',
    'ru': 'Из ICS-файла (Google / Apple / Outlook)',
    'de': 'Aus ICS-Datei (Google / Apple / Outlook)',
  },
  'import.btn_from_todoist': {
    'en': 'From Todoist CSV',
    'ru': 'Из Todoist CSV',
    'de': 'Aus Todoist CSV',
  },
  'import.err_no_lines': {
    'en': 'No valid "HH:MM Title" lines found',
    'ru': 'Не найдено строк вида «ЧЧ:ММ Заголовок»',
    'de': 'Keine gültigen „HH:MM Titel"-Zeilen gefunden',
  },
  'import.err_no_file': {
    'en': 'Could not read file',
    'ru': 'Не удалось прочитать файл',
    'de': 'Datei konnte nicht gelesen werden',
  },
  'import.success_tasks': {
    'en': 'Imported {n} tasks',
    'ru': 'Импортировано задач: {n}',
    'de': '{n} Aufgaben importiert',
  },
  'import.success_todoist': {
    'en': 'Imported {n} tasks from Todoist',
    'ru': 'Импортировано из Todoist: {n} задач',
    'de': '{n} Aufgaben aus Todoist importiert',
  },
  'import.err_no_todoist_tasks': {
    'en': 'No tasks found in Todoist CSV',
    'ru': 'В Todoist CSV не найдено задач',
    'de': 'Keine Aufgaben in der Todoist CSV gefunden',
  },
  'import.photo_premium_snack': {
    'en': 'Premium feature — upgrade to import from a photo',
    'ru': 'Функция Premium — обновись, чтобы импортировать с фото',
    'de': 'Premium-Funktion — Upgrade erforderlich für Foto-Import',
  },
  'import.photo_recognized': {
    'en': 'Recognized {n} items — review & Import',
    'ru': 'Распознано событий: {n} — проверь и нажми «Импортировать»',
    'de': '{n} Elemente erkannt — prüfen und importieren',
  },
  'import.ics_no_events': {
    'en': 'No events found for {date} in this file',
    'ru': 'В файле нет событий за {date}',
    'de': 'Keine Ereignisse für {date} in dieser Datei',
  },
  'import.ics_found': {
    'en': 'Found {n} events on {date} — review & Import',
    'ru': 'Найдено событий за {date}: {n} — проверь и нажми «Импортировать»',
    'de': '{n} Ereignisse am {date} gefunden — prüfen und importieren',
  },

  // ---------------------------------------------------------------------------
  // Focus (focus_screen.dart)
  // ---------------------------------------------------------------------------
  'focus.title': {
    'en': 'Focus',
    'ru': 'Фокус',
    'de': 'Fokus',
  },
  'focus.pick_session': {
    'en': 'Pick a session',
    'ru': 'Выбери сессию',
    'de': 'Sitzung wählen',
  },
  'focus.session_hint': {
    'en': 'Work / break minutes. 67 / 15 is our signature.',
    'ru': 'Минуты работы / перерыва. 67 / 15 — наш фирменный формат.',
    'de': 'Arbeits-/Pausenminuten. 67 / 15 ist unser Signature-Format.',
  },
  'focus.blocks_today': {
    'en': 'Focus blocks today: {n}',
    'ru': 'Блоков фокуса сегодня: {n}',
    'de': 'Fokus-Blöcke heute: {n}',
  },
  'focus.btn_start': {
    'en': 'Start',
    'ru': 'Старт',
    'de': 'Starten',
  },
  'focus.phase_work': {
    'en': 'Focus',
    'ru': 'Работа',
    'de': 'Fokus',
  },
  'focus.phase_break': {
    'en': 'Break',
    'ru': 'Перерыв',
    'de': 'Pause',
  },
  'focus.btn_pause': {
    'en': 'Pause',
    'ru': 'Пауза',
    'de': 'Pause',
  },
  'focus.btn_resume': {
    'en': 'Resume',
    'ru': 'Продолжить',
    'de': 'Fortsetzen',
  },
  'focus.btn_stop': {
    'en': 'Stop',
    'ru': 'Стоп',
    'de': 'Stopp',
  },

  // ---------------------------------------------------------------------------
  // Wrapped (wrapped_screen.dart)
  // ---------------------------------------------------------------------------
  'wrapped.title_week': {
    'en': 'This week',
    'ru': 'Эта неделя',
    'de': 'Diese Woche',
  },
  'wrapped.title_month': {
    'en': 'This month',
    'ru': 'Этот месяц',
    'de': 'Dieser Monat',
  },
  'wrapped.period_label': {
    'en': 'Your last {n} days',
    'ru': 'Твои последние {n} дней',
    'de': 'Deine letzten {n} Tage',
  },
  'wrapped.seg_week': {
    'en': 'Week',
    'ru': 'Неделя',
    'de': 'Woche',
  },
  'wrapped.seg_month': {
    'en': 'Month',
    'ru': 'Месяц',
    'de': 'Monat',
  },
  'wrapped.stat_tasks_done': {
    'en': 'Tasks done',
    'ru': 'Задач выполнено',
    'de': 'Aufgaben erledigt',
  },
  'wrapped.stat_main_done': {
    'en': 'Main done',
    'ru': 'Главных выполнено',
    'de': 'Hauptaufgaben erledigt',
  },
  'wrapped.stat_avg_mood': {
    'en': 'Avg mood',
    'ru': 'Среднее настроение',
    'de': 'Durchschnittliche Stimmung',
  },
  'wrapped.stat_water': {
    'en': 'Water',
    'ru': 'Вода',
    'de': 'Wasser',
  },
  'wrapped.stat_top_setback': {
    'en': 'Top setback',
    'ru': 'Главный сбой',
    'de': 'Häufigster Rückschlag',
  },
  'wrapped.err_load': {
    'en': 'Failed to load: {e}',
    'ru': 'Не удалось загрузить: {e}',
    'de': 'Laden fehlgeschlagen: {e}',
  },
  'wrapped.ai_paragraph_title': {
    'en': 'In a paragraph',
    'ru': 'Одним абзацем',
    'de': 'In einem Absatz',
  },
  'wrapped.ai_writing': {
    'en': 'AI is writing…',
    'ru': 'AI пишет…',
    'de': 'KI schreibt…',
  },
  'wrapped.btn_ai_recap': {
    'en': 'AI recap (Premium)',
    'ru': 'AI-итоги (Premium)',
    'de': 'KI-Zusammenfassung (Premium)',
  },
  'wrapped.ai_premium_snack': {
    'en': 'Premium feature — AI writes your recap',
    'ru': 'Функция Premium — AI пишет твои итоги',
    'de': 'Premium-Funktion — KI schreibt deine Zusammenfassung',
  },
  'wrapped.btn_upgrade': {
    'en': 'Upgrade',
    'ru': 'Обновить',
    'de': 'Upgraden',
  },
};
