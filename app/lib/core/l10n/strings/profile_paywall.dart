// Строки экранов Profile, Terms и Paywall.
// Наполнено агентом локализации. EN + RU обязательны, DE — опционально.
const Map<String, Map<String, String>> profilePaywallStrings = {
  // ---- Profile: заголовки секций ----
  'profile.section_appearance': {
    'en': 'Appearance',
    'ru': 'Внешний вид',
    'de': 'Erscheinungsbild',
  },
  'profile.section_preferences': {
    'en': 'Preferences',
    'ru': 'Настройки',
    'de': 'Einstellungen',
  },
  'profile.section_support': {
    'en': 'Support',
    'ru': 'Поддержка',
    'de': 'Support',
  },

  // ---- Profile: офлайн-режим ----
  'profile.offline_mode': {
    'en': 'Offline mode',
    'ru': 'Офлайн-режим',
    'de': 'Offline-Modus',
  },
  'profile.offline_subtitle': {
    'en': 'Your tasks are stored on this device only. Sign in to sync across devices.',
    'ru': 'Задачи хранятся только на этом устройстве. Войди, чтобы синхронизировать их.',
    'de': 'Deine Aufgaben werden nur auf diesem Gerät gespeichert. Melde dich an, um sie zu synchronisieren.',
  },
  'profile.you': {
    'en': 'You',
    'ru': 'Ты',
    'de': 'Du',
  },

  // ---- Profile: streak ----
  'profile.streak': {
    'en': 'Streak',
    'ru': 'Стрик',
    'de': 'Serie',
  },
  'profile.streak_best': {
    'en': 'Best',
    'ru': 'Рекорд',
    'de': 'Bestleistung',
  },
  'profile.streak_freezes': {
    'en': 'Freezes ❄️',
    'ru': 'Заморозки ❄️',
    'de': 'Einfrierungen ❄️',
  },
  'profile.freeze_hint': {
    'en': 'Give yourself a day off — a freeze will protect your streak automatically if you miss today.',
    'ru': 'Дай себе выходной — заморозка защитит стрик, если пропустишь сегодня.',
    'de': 'Gönne dir einen freien Tag — eine Einfrierung schützt deine Serie automatisch, wenn du heute aussetzt.',
  },

  // ---- Profile: тема ----
  'profile.theme_focus': {
    'en': 'Focus',
    'ru': 'Focus',
    'de': 'Focus',
  },
  'profile.theme_calm': {
    'en': 'Calm',
    'ru': 'Calm',
    'de': 'Calm',
  },
  'profile.theme_black': {
    'en': 'Black',
    'ru': 'Black',
    'de': 'Black',
  },
  'profile.theme_white': {
    'en': 'White',
    'ru': 'White',
    'de': 'White',
  },
  'profile.theme_contrast': {
    'en': 'Contrast',
    'ru': 'Contrast',
    'de': 'Contrast',
  },

  // ---- Profile: тон ----
  'profile.default_tone': {
    'en': 'Default tone',
    'ru': 'Тон по умолчанию',
    'de': 'Standardton',
  },

  // ---- Profile: уведомления ----
  'profile.notifications_subtitle': {
    'en': 'Morning & evening review nudges',
    'ru': 'Напоминания утреннего и вечернего разбора',
    'de': 'Morgen- und Abenderinnerungen',
  },
  'profile.notifications_snackbar': {
    'en': 'Enable notifications in system settings to use reminders',
    'ru': 'Разреши уведомления в настройках системы, чтобы использовать напоминания',
    'de': 'Aktiviere Benachrichtigungen in den Systemeinstellungen, um Erinnerungen zu nutzen',
  },

  // ---- Profile: маскот Kai ----
  'profile.show_kai': {
    'en': 'Show Kai',
    'ru': 'Показывать Kai',
    'de': 'Kai anzeigen',
  },
  'profile.show_kai_subtitle': {
    'en': 'The AI presence on your Today screen',
    'ru': 'ИИ-помощник на экране «Сегодня»',
    'de': 'Die KI-Präsenz auf deinem Heute-Bildschirm',
  },

  // ---- Profile: поддержка ----
  'profile.rate_app': {
    'en': 'Rate the app',
    'ru': 'Оценить приложение',
    'de': 'App bewerten',
  },
  'profile.rate_coming_soon': {
    'en': "Coming soon — we're not in the store yet 😊",
    'ru': 'Скоро — нас пока нет в магазине 😊',
    'de': 'Kommt bald — wir sind noch nicht im Store 😊',
  },
  'profile.send_feedback': {
    'en': 'Send feedback',
    'ru': 'Написать в поддержку',
    'de': 'Feedback senden',
  },
  'profile.feedback_subtitle': {
    'en': 'Report a bug or suggest a feature',
    'ru': 'Сообщить об ошибке или предложить идею',
    'de': 'Fehler melden oder Feature vorschlagen',
  },
  'profile.feedback_email': {
    'en': 'Email us: support@kaizen.app',
    'ru': 'Напиши нам: support@kaizen.app',
    'de': 'Schreib uns: support@kaizen.app',
  },
  'profile.terms_privacy': {
    'en': 'Terms & Privacy',
    'ru': 'Условия и конфиденциальность',
    'de': 'Nutzungsbedingungen & Datenschutz',
  },

  // ---- Profile: реферал ----
  'profile.invite_title': {
    'en': 'Invite a friend',
    'ru': 'Пригласи друга',
    'de': 'Freund einladen',
  },
  'profile.invite_subtitle': {
    'en': 'Get 1 week free Premium for each friend who joins',
    'ru': 'Получи 1 неделю Premium бесплатно за каждого друга',
    'de': '1 Woche Premium kostenlos für jeden Freund, der beitritt',
  },
  'profile.share_kaizen': {
    'en': 'Share Kaizen',
    'ru': 'Поделиться Kaizen',
    'de': 'Kaizen teilen',
  },
  'profile.referral_coming_soon': {
    'en': 'Referral links coming after App Store launch 🚀',
    'ru': 'Реферальные ссылки появятся после запуска в App Store 🚀',
    'de': 'Empfehlungslinks kommen nach dem App-Store-Launch 🚀',
  },

  // ---- Profile: карточка подписки ----
  'profile.premium_badge': {
    'en': 'Kaizen Premium',
    'ru': 'Kaizen Premium',
    'de': 'Kaizen Premium',
  },
  'profile.free_plan': {
    'en': 'Free plan',
    'ru': 'Бесплатный план',
    'de': 'Kostenloser Plan',
  },
  'profile.premium_unlocked': {
    'en': 'AI features unlocked',
    'ru': 'Функции ИИ открыты',
    'de': 'KI-Funktionen freigeschaltet',
  },
  'profile.premium_unlock_cta': {
    'en': r'Unlock AI — $10/mo',
    'ru': r'Открой ИИ — $10/мес',
    'de': r'KI freischalten — $10/Monat',
  },

  // ---- Profile: «Поделиться неделей» ----
  'profile.share_week': {
    'en': 'Share my week',
    'ru': 'Поделиться неделей',
    'de': 'Meine Woche teilen',
  },
  'profile.share_week_subtitle': {
    'en': 'View-only web link · friends need no app',
    'ru': 'Ссылка только для просмотра · друзьям не нужно приложение',
    'de': 'Nur-Ansicht-Link · Freunde brauchen keine App',
  },
  'profile.share_sign_in': {
    'en': 'Sign in to share your plan',
    'ru': 'Войди, чтобы поделиться планом',
    'de': 'Melde dich an, um deinen Plan zu teilen',
  },
  'profile.share_link_copied': {
    'en': 'Link copied — valid for 7 days, view-only',
    'ru': 'Ссылка скопирована — действует 7 дней, только просмотр',
    'de': 'Link kopiert — gültig für 7 Tage, nur Ansicht',
  },

  // ---- Profile: «Поделились со мной» ----
  'profile.shared_with_me': {
    'en': 'Shared with me',
    'ru': 'Поделились со мной',
    'de': 'Mit mir geteilt',
  },
  'profile.shared_with_me_subtitle': {
    'en': "Open a friend's plan link",
    'ru': 'Открыть ссылку на план друга',
    'de': "Link zum Plan eines Freundes öffnen",
  },
  'profile.paste_link_hint': {
    'en': 'Paste link or token',
    'ru': 'Вставь ссылку или токен',
    'de': 'Link oder Token einfügen',
  },
  'profile.open': {
    'en': 'Open',
    'ru': 'Открыть',
    'de': 'Öffnen',
  },
  'profile.invalid_link': {
    'en': 'Invalid link or token',
    'ru': 'Неверная ссылка или токен',
    'de': 'Ungültiger Link oder Token',
  },
  'profile.network_error': {
    'en': 'Network error — check your connection',
    'ru': 'Ошибка сети — проверь подключение',
    'de': 'Netzwerkfehler — überprüfe deine Verbindung',
  },
  'profile.no_events': {
    'en': 'No events in this plan',
    'ru': 'В этом плане нет событий',
    'de': 'Keine Ereignisse in diesem Plan',
  },

  // ---- Terms ----
  'profile.terms_title': {
    'en': 'Terms of Service',
    'ru': 'Условия использования',
    'de': 'Nutzungsbedingungen',
  },
  'profile.terms_body': {
    'en': 'Last updated: June 2026\n\n'
        'By using Kaizen ("the app"), you agree to these terms. '
        'Kaizen is a personal productivity tool for students.\n\n'
        '1. Use the app for lawful purposes only.\n'
        '2. You are responsible for keeping your account credentials secure.\n'
        '3. We may update the app and these terms at any time.\n'
        '4. The app is provided "as is" without warranties of any kind.\n'
        '5. Subscription fees are non-refundable except as required by law.',
    'ru': 'Последнее обновление: июнь 2026 г.\n\n'
        'Используя Kaizen («приложение»), ты принимаешь эти условия. '
        'Kaizen — персональный инструмент планирования для студентов.\n\n'
        '1. Используй приложение только в законных целях.\n'
        '2. Ты несёшь ответственность за безопасность учётных данных.\n'
        '3. Мы можем обновлять приложение и эти условия в любое время.\n'
        '4. Приложение предоставляется «как есть» без каких-либо гарантий.\n'
        '5. Плата за подписку не возвращается, если иное не предусмотрено законом.',
    'de': 'Zuletzt aktualisiert: Juni 2026\n\n'
        'Durch die Nutzung von Kaizen („die App") stimmst du diesen Bedingungen zu. '
        'Kaizen ist ein persönliches Produktivitätswerkzeug für Studierende.\n\n'
        '1. Nutze die App nur für rechtmäßige Zwecke.\n'
        '2. Du bist für die Sicherheit deiner Zugangsdaten verantwortlich.\n'
        '3. Wir können die App und diese Bedingungen jederzeit aktualisieren.\n'
        '4. Die App wird „wie besehen" ohne jegliche Gewährleistung bereitgestellt.\n'
        '5. Abonnementgebühren sind nicht erstattungsfähig, sofern gesetzlich nichts anderes vorgeschrieben ist.',
  },
  'profile.privacy_title': {
    'en': 'Privacy Policy',
    'ru': 'Политика конфиденциальности',
    'de': 'Datenschutzrichtlinie',
  },
  'profile.privacy_body': {
    'en': 'Last updated: June 2026\n\n'
        'We take your privacy seriously.\n\n'
        'What we collect:\n'
        '• Account info (email, name) — to identify your account.\n'
        '• Tasks, diary entries, health logs — synced to provide the service.\n'
        '• Usage data (anonymous) — to improve the app.\n\n'
        "What we don't do:\n"
        '• We do not sell your data to third parties.\n'
        '• We do not show ads to Premium users.\n'
        '• We do not share personal data with advertisers.\n\n'
        'AI features (Premium):\n'
        'When you use AI features, your tasks and diary summaries are sent to '
        'our AI provider (Google Gemini or Anthropic Claude) to generate responses. '
        'This data is not used to train their models per our agreements.\n\n'
        'Data storage:\n'
        'Your data is stored on servers in the EU/US. '
        'You can delete your account and all data at any time by contacting support@kaizen.app.\n\n'
        'Contact: support@kaizen.app',
    'ru': 'Последнее обновление: июнь 2026 г.\n\n'
        'Мы серьёзно относимся к твоей конфиденциальности.\n\n'
        'Что мы собираем:\n'
        '• Данные аккаунта (email, имя) — для идентификации.\n'
        '• Задачи, записи дневника, логи здоровья — синхронизируются для работы сервиса.\n'
        '• Анонимные данные использования — для улучшения приложения.\n\n'
        'Что мы не делаем:\n'
        '• Мы не продаём твои данные третьим лицам.\n'
        '• Мы не показываем рекламу пользователям Premium.\n'
        '• Мы не передаём личные данные рекламодателям.\n\n'
        'Функции ИИ (Premium):\n'
        'При использовании функций ИИ твои задачи и краткое содержание дневника отправляются '
        'нашему провайдеру ИИ (Google Gemini или Anthropic Claude) для генерации ответов. '
        'Эти данные не используются для обучения моделей согласно нашим соглашениям.\n\n'
        'Хранение данных:\n'
        'Твои данные хранятся на серверах в ЕС/США. '
        'Ты можешь удалить аккаунт и все данные в любое время, написав на support@kaizen.app.\n\n'
        'Контакт: support@kaizen.app',
    'de': 'Zuletzt aktualisiert: Juni 2026\n\n'
        'Wir nehmen deine Privatsphäre ernst.\n\n'
        'Was wir erfassen:\n'
        '• Kontodaten (E-Mail, Name) — zur Identifikation deines Kontos.\n'
        '• Aufgaben, Tagebucheinträge, Gesundheitsprotokolle — synchronisiert zur Bereitstellung des Dienstes.\n'
        '• Nutzungsdaten (anonym) — zur Verbesserung der App.\n\n'
        'Was wir nicht tun:\n'
        '• Wir verkaufen deine Daten nicht an Dritte.\n'
        '• Wir zeigen Premium-Nutzern keine Werbung.\n'
        '• Wir teilen keine persönlichen Daten mit Werbetreibenden.\n\n'
        'KI-Funktionen (Premium):\n'
        'Wenn du KI-Funktionen nutzt, werden deine Aufgaben und Tagebuchzusammenfassungen '
        'an unseren KI-Anbieter (Google Gemini oder Anthropic Claude) zur Antworterstellung gesendet. '
        'Diese Daten werden gemäß unseren Vereinbarungen nicht zum Training ihrer Modelle verwendet.\n\n'
        'Datenspeicherung:\n'
        'Deine Daten werden auf Servern in der EU/den USA gespeichert. '
        'Du kannst dein Konto und alle Daten jederzeit löschen, indem du support@kaizen.app kontaktierst.\n\n'
        'Kontakt: support@kaizen.app',
  },
  'profile.tagline': {
    'en': "Kaizen — the important stuff won't slip.",
    'ru': 'Kaizen — главное не упустишь.',
    'de': 'Kaizen — das Wichtige geht nicht unter.',
  },

  // ---- Paywall ----
  'paywall.title': {
    'en': 'Kaizen Premium',
    'ru': 'Kaizen Premium',
    'de': 'Kaizen Premium',
  },
  'paywall.headline': {
    'en': 'Unlock the AI',
    'ru': 'Открой возможности ИИ',
    'de': 'KI freischalten',
  },
  'paywall.subheadline': {
    'en': 'The important stuff, planned for you.',
    'ru': 'Главное — спланировано за тебя.',
    'de': 'Das Wichtige, für dich geplant.',
  },
  'paywall.per_month': {
    'en': ' / month',
    'ru': ' / мес',
    'de': ' / Monat',
  },
  'paywall.sign_in_hint': {
    'en': 'Sign in to subscribe and sync premium across devices.',
    'ru': 'Войди, чтобы подписаться и синхронизировать Premium на всех устройствах.',
    'de': 'Melde dich an, um zu abonnieren und Premium geräteübergreifend zu synchronisieren.',
  },
  'paywall.subscribe': {
    'en': 'Subscribe',
    'ru': 'Подписаться',
    'de': 'Abonnieren',
  },
  'paywall.restore': {
    'en': 'Restore purchases',
    'ru': 'Восстановить покупки',
    'de': 'Käufe wiederherstellen',
  },
  'paywall.cancel_hint': {
    'en': 'Cancel anytime. Free tier keeps tasks, streaks, rule-based plans, water & diary.',
    'ru': 'Отмени в любой момент. Бесплатный план сохраняет задачи, стрики, правила планирования, воду и дневник.',
    'de': 'Jederzeit kündbar. Im Free-Tarif bleiben Aufgaben, Serien, regelbasierte Pläne, Wasser & Tagebuch erhalten.',
  },
  'paywall.welcome_premium': {
    'en': 'Welcome to Premium!',
    'ru': 'Добро пожаловать в Premium!',
    'de': 'Willkommen bei Premium!',
  },
  'paywall.coming_soon': {
    'en': 'Subscriptions launch soon — payments are coming in the next update.',
    'ru': 'Подписки скоро появятся — оплата будет в следующем обновлении.',
    'de': 'Abonnements kommen bald — Zahlungen folgen im nächsten Update.',
  },
  'paywall.error_generic': {
    'en': 'Something went wrong. Please try again.',
    'ru': 'Что-то пошло не так. Попробуй ещё раз.',
    'de': 'Etwas ist schiefgelaufen. Bitte versuche es erneut.',
  },
  'paywall.sign_in_to_subscribe': {
    'en': 'Sign in first to subscribe.',
    'ru': 'Сначала войди, чтобы подписаться.',
    'de': 'Melde dich zuerst an, um zu abonnieren.',
  },
  'paywall.restored': {
    'en': 'Purchases restored!',
    'ru': 'Покупки восстановлены!',
    'de': 'Käufe wiederhergestellt!',
  },
  'paywall.nothing_to_restore': {
    'en': 'Nothing to restore yet — payments are coming soon.',
    'ru': 'Нечего восстанавливать — оплата появится скоро.',
    'de': 'Noch nichts wiederherzustellen — Zahlungen kommen bald.',
  },
  'paywall.restore_error': {
    'en': 'Could not restore purchases.',
    'ru': 'Не удалось восстановить покупки.',
    'de': 'Käufe konnten nicht wiederhergestellt werden.',
  },
  'paywall.upgrade': {
    'en': 'Upgrade',
    'ru': 'Улучшить',
    'de': 'Upgraden',
  },

  // ---- Paywall: преимущества ----
  'paywall.benefit_smarter_title': {
    'en': 'Smarter plans',
    'ru': 'Умнее планировать',
    'de': 'Intelligentere Pläne',
  },
  'paywall.benefit_smarter_subtitle': {
    'en': 'AI rebuilds your day around what matters — morning & evening.',
    'ru': 'ИИ перестраивает твой день вокруг главного — утром и вечером.',
    'de': 'KI baut deinen Tag rund um das Wesentliche neu auf — morgens & abends.',
  },
  'paywall.benefit_tone_title': {
    'en': 'Tone-aware nudges',
    'ru': 'Напоминания в нужном тоне',
    'de': 'Tongerechte Erinnerungen',
  },
  'paywall.benefit_tone_subtitle': {
    'en': 'Gentle or harsh — AI messages that actually land.',
    'ru': 'Мягко или строго — сообщения ИИ, которые действительно работают.',
    'de': 'Sanft oder streng — KI-Nachrichten, die wirklich ankommen.',
  },
  'paywall.benefit_diary_title': {
    'en': 'Deeper diary insights',
    'ru': 'Глубокий анализ дневника',
    'de': 'Tiefere Tagebuch-Einblicke',
  },
  'paywall.benefit_diary_subtitle': {
    'en': 'Understand why plans slip, beyond the free weekly summary.',
    'ru': 'Узнай, почему срываются планы — больше, чем бесплатная недельная сводка.',
    'de': 'Verstehe, warum Pläne scheitern — über die kostenlose Wochenzusammenfassung hinaus.',
  },
  'paywall.benefit_photo_title': {
    'en': 'Photo schedule import',
    'ru': 'Импорт расписания по фото',
    'de': 'Stundenplan per Foto importieren',
  },
  'paywall.benefit_photo_subtitle': {
    'en': 'Snap your timetable — AI turns it into tasks.',
    'ru': 'Сфотографируй расписание — ИИ превратит его в задачи.',
    'de': 'Fotografiere deinen Stundenplan — KI wandelt ihn in Aufgaben um.',
  },
  'paywall.benefit_noads_title': {
    'en': 'No ads',
    'ru': 'Без рекламы',
    'de': 'Keine Werbung',
  },
  'paywall.benefit_noads_subtitle': {
    'en': 'Calm, focused, ad-free.',
    'ru': 'Спокойно, сосредоточенно, без рекламы.',
    'de': 'Ruhig, fokussiert, werbefrei.',
  },
};
