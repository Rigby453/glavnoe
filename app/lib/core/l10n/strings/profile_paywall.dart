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
  'profile.theme_custom': {
    'en': 'My Theme',
    'ru': 'Мой стиль',
    'de': 'Mein Stil',
  },
  'profile.theme_custom_edit': {
    'en': 'Edit my theme',
    'ru': 'Изменить стиль',
    'de': 'Stil bearbeiten',
  },

  // ---- Редактор пользовательской темы ----
  'custom_theme.title': {
    'en': 'My Theme',
    'ru': 'Мой стиль',
    'de': 'Mein Stil',
  },
  'custom_theme.reset': {
    'en': 'Reset',
    'ru': 'Сбросить',
    'de': 'Zurücksetzen',
  },
  'custom_theme.save': {
    'en': 'Save',
    'ru': 'Сохранить',
    'de': 'Speichern',
  },
  'custom_theme.base_mode': {
    'en': 'Base mode',
    'ru': 'Режим',
    'de': 'Basismodus',
  },
  'custom_theme.dark': {
    'en': 'Dark',
    'ru': 'Тёмная',
    'de': 'Dunkel',
  },
  'custom_theme.light': {
    'en': 'Light',
    'ru': 'Светлая',
    'de': 'Hell',
  },
  'custom_theme.accent_color': {
    'en': 'Accent color',
    'ru': 'Акцент',
    'de': 'Akzentfarbe',
  },
  'custom_theme.custom_color': {
    'en': 'Custom color',
    'ru': 'Свой цвет',
    'de': 'Eigene Farbe',
  },
  'custom_theme.customize_more': {
    'en': 'Customize more',
    'ru': 'Дополнительно',
    'de': 'Mehr anpassen',
  },
  'custom_theme.bg_warmth': {
    'en': 'Background warmth',
    'ru': 'Теплота фона',
    'de': 'Hintergrundwärme',
  },
  'custom_theme.preview': {
    'en': 'Preview',
    'ru': 'Предпросмотр',
    'de': 'Vorschau',
  },
  'custom_theme.accent_forced': {
    'en': 'Your color was too close to the background. We adjusted it slightly for readability.',
    'ru': 'Выбранный цвет был слишком близок к фону. Мы чуть скорректировали его для читаемости.',
    'de': 'Deine Farbe war dem Hintergrund zu ähnlich. Wir haben sie leicht angepasst, damit sie lesbar bleibt.',
  },
  'custom_theme.reset_confirm_title': {
    'en': 'Reset theme?',
    'ru': 'Сбросить стиль?',
    'de': 'Stil zurücksetzen?',
  },
  'custom_theme.reset_confirm_body': {
    'en': 'Your custom theme will be deleted and the app will switch back to Focus.',
    'ru': 'Пользовательский стиль будет удалён, а тема вернётся к Focus.',
    'de': 'Dein benutzerdefinierter Stil wird gelöscht und die App wechselt zurück zu Focus.',
  },

  // ---- Profile: размер текста (опции селектора) ----
  'profile.text_size_small': {
    'en': 'Small',
    'ru': 'Маленький',
    'de': 'Klein',
  },
  'profile.text_size_default': {
    'en': 'Default',
    'ru': 'Обычный',
    'de': 'Standard',
  },
  'profile.text_size_large': {
    'en': 'Large',
    'ru': 'Крупный',
    'de': 'Groß',
  },
  'profile.text_size_xlarge': {
    'en': 'Extra large',
    'ru': 'Очень крупный',
    'de': 'Sehr groß',
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
  // Шит просмотра чужого плана
  // {name} — имя владельца
  'profile.plan_of': {
    'en': "{name}'s plan",
    'ru': 'План {name}',
    'de': 'Plan von {name}',
  },
  // {n} — число событий; английская форма с одним словом (без plural-рисков в РУ — используем число)
  'profile.copy_to_my_plan': {
    'en': 'Copy to my plan ({n})',
    'ru': 'Скопировать в мой план ({n})',
    'de': 'In meinen Plan kopieren ({n})',
  },
  // {n} — число скопированных событий
  'profile.events_copied': {
    'en': '{n} events copied to your plan',
    'ru': 'Скопировано событий в ваш план: {n}',
    'de': '{n} Ereignisse in deinen Plan kopiert',
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

  // Речевой пузырь Kai — тёплый, ненавязчивый
  'paywall.kai_bubble': {
    'en': 'I can help you plan smarter.',
    'ru': 'Я помогу планировать умнее.',
    'de': 'Ich helfe dir, smarter zu planen.',
  },

  // Строки планов
  'paywall.plan_monthly': {
    'en': 'Monthly',
    'ru': 'Ежемесячно',
    'de': 'Monatlich',
  },
  'paywall.plan_yearly': {
    'en': 'Yearly',
    'ru': 'Ежегодно',
    'de': 'Jährlich',
  },
  'paywall.per_month': {
    'en': ' / mo',
    'ru': ' / мес',
    'de': ' / Monat',
  },
  'paywall.per_year': {
    'en': ' / yr',
    'ru': ' / год',
    'de': ' / Jahr',
  },
  // {pct} — процент экономии, подставляется в коде
  'paywall.save_badge': {
    'en': 'save {pct}%',
    'ru': 'экономия {pct}%',
    'de': '{pct}% sparen',
  },
  // {price} — месячный эквивалент годовой цены, подставляется в коде
  'paywall.yearly_per_month': {
    'en': '{price} / mo billed yearly',
    'ru': '{price} / мес при оплате за год',
    'de': '{price} / Monat bei Jahreszahlung',
  },

  // Что входит бесплатно (краткая строка под списком функций)
  'paywall.free_includes': {
    'en': 'Free keeps: tasks, streaks, rule-based daily plan, water & diary.',
    'ru': 'Бесплатно: задачи, стрики, правила планирования, вода и дневник.',
    'de': 'Kostenlos: Aufgaben, Serien, regelbasierter Tagesplan, Wasser & Tagebuch.',
  },

  // Основная CTA
  'paywall.cta_start_free': {
    'en': 'Start free',
    'ru': 'Начать бесплатно',
    'de': 'Kostenlos starten',
  },

  // Disclosure под CTA (обязательный Apple/EU текст).
  // {n} = число дней пробного периода, {price} = цена+период, {date} = дата окончания пробного
  'paywall.disclosure': {
    'en': '{n} days free, then {price}. '
        "You'll be charged on {date}. "
        'Cancel anytime in Settings.',
    'ru': '{n} дней бесплатно, затем {price}. '
        'Оплата спишется {date}. '
        'Отмени в любой момент в Настройках.',
    'de': '{n} Tage kostenlos, dann {price}. '
        'Du wirst am {date} belastet. '
        'Jederzeit in den Einstellungen kündbar.',
  },

  // Ссылки нижнего ряда
  'paywall.link_terms': {
    'en': 'Terms',
    'ru': 'Условия',
    'de': 'Nutzungsbedingungen',
  },
  'paywall.link_privacy': {
    'en': 'Privacy',
    'ru': 'Конфиденциальность',
    'de': 'Datenschutz',
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

  // ---- Paywall: список premium-функций (обновлён под compliance) ----

  // 1. AI smart reschedule
  'paywall.benefit_reschedule_title': {
    'en': 'AI smart reschedule',
    'ru': 'Умный перенос задач с ИИ',
    'de': 'KI-Neuplanung',
  },
  'paywall.benefit_reschedule_subtitle': {
    'en': 'AI rebuilds your day around what matters — morning & evening.',
    'ru': 'ИИ перестраивает твой день вокруг главного — утром и вечером.',
    'de': 'KI baut deinen Tag rund um das Wesentliche neu auf — morgens & abends.',
  },

  // 2. AI menu tuned to calories/macros
  'paywall.benefit_menu_title': {
    'en': 'AI menu for your goals',
    'ru': 'ИИ-меню под твои цели',
    'de': 'KI-Menü für deine Ziele',
  },
  'paywall.benefit_menu_subtitle': {
    'en': 'Meal plans tuned to your calorie and macro targets.',
    'ru': 'Меню, подобранное под твои калории и КБЖУ.',
    'de': 'Mahlzeitenpläne abgestimmt auf Kalorien- und Makroziele.',
  },

  // 3. Photo recognition (food + schedule)
  'paywall.benefit_photo_title': {
    'en': 'Photo recognition',
    'ru': 'Распознавание по фото',
    'de': 'Foto-Erkennung',
  },
  'paywall.benefit_photo_subtitle': {
    'en': 'Snap food or your timetable — AI logs it instantly.',
    'ru': 'Сфотографируй еду или расписание — ИИ добавит всё сам.',
    'de': 'Fotografiere Essen oder Stundenplan — KI erfasst es sofort.',
  },

  // 4. Voice input
  'paywall.benefit_voice_title': {
    'en': 'Voice input',
    'ru': 'Голосовой ввод',
    'de': 'Spracheingabe',
  },
  'paywall.benefit_voice_subtitle': {
    'en': 'Add tasks and food by speaking — hands-free.',
    'ru': 'Добавляй задачи и еду голосом — без рук.',
    'de': 'Aufgaben und Essen per Sprache hinzufügen — freihändig.',
  },

  // 5. AI Wrapped weekly/monthly
  'paywall.benefit_wrapped_title': {
    'en': 'AI Wrapped',
    'ru': 'AI Wrapped',
    'de': 'AI Wrapped',
  },
  'paywall.benefit_wrapped_subtitle': {
    'en': 'Weekly & monthly insight: why plans slip and how to fix it.',
    'ru': 'Еженедельный и ежемесячный анализ: почему срываются планы и что делать.',
    'de': 'Wöchentliche & monatliche Auswertung: Warum Pläne scheitern und wie man es behebt.',
  },

  // Устаревшие ключи (сохранены для обратной совместимости — тест и другие экраны могут ссылаться)
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
