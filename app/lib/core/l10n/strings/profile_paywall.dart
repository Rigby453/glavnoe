// Строки экранов Profile, Terms и Paywall.
// Наполнено агентом локализации. EN + RU обязательны, DE — опционально.
const Map<String, Map<String, String>> profilePaywallStrings = {
  // ---- Profile: заголовки секций ----
  'profile.section_appearance': {
    'en': 'Appearance',
    'ru': 'Внешний вид',
    'de': 'Erscheinungsbild',
    'fr': 'Apparence',
    'it': 'Aspetto',
    'pt': 'Aparência',
    'es': 'Apariencia',
    'id': 'Tampilan',
    'hi': 'दिखावट',
    'ja': '外観',
    'ko': '외관',
  },
  'profile.section_preferences': {
    'en': 'Preferences',
    'ru': 'Настройки',
    'de': 'Einstellungen',
    'fr': 'Paramètres',
    'it': 'Impostazioni',
    'pt': 'Configurações',
    'es': 'Ajustes',
    'id': 'Pengaturan',
    'hi': 'सेटिंग्स',
    'ja': '設定',
    'ko': '설정',
  },
  'profile.section_support': {
    'en': 'Support',
    'ru': 'Поддержка',
    'de': 'Support',
    'fr': 'Assistance',
    'it': 'Supporto',
    'pt': 'Suporte',
    'es': 'Soporte',
    'id': 'Dukungan',
    'hi': 'सहायता',
    'ja': 'サポート',
    'ko': '지원',
  },

  // ---- Profile: офлайн-режим ----
  'profile.offline_mode': {
    'en': 'Offline mode',
    'ru': 'Офлайн-режим',
    'de': 'Offline-Modus',
    'fr': 'Mode hors ligne',
    'it': 'Modalità offline',
    'pt': 'Modo offline',
    'es': 'Modo sin conexión',
    'id': 'Mode offline',
    'hi': 'ऑफ़लाइन मोड',
    'ja': 'オフラインモード',
    'ko': '오프라인 모드',
  },
  'profile.offline_subtitle': {
    'en': 'Your tasks are stored on this device only. Sign in to sync across devices.',
    'ru': 'Задачи хранятся только на этом устройстве. Войди, чтобы синхронизировать их.',
    'de': 'Deine Aufgaben werden nur auf diesem Gerät gespeichert. Melde dich an, um sie zu synchronisieren.',
    'fr': 'Tes tâches sont stockées uniquement sur cet appareil. Connecte-toi pour les synchroniser.',
    'it': 'Le tue attività sono salvate solo su questo dispositivo. Accedi per sincronizzarle.',
    'pt': 'Suas tarefas estão salvas apenas neste dispositivo. Faça login para sincronizar.',
    'es': 'Tus tareas están guardadas solo en este dispositivo. Inicia sesión para sincronizarlas.',
    'id': 'Tugasmu tersimpan hanya di perangkat ini. Masuk untuk menyinkronkan.',
    'hi': 'तुम्हारे टास्क केवल इस डिवाइस पर हैं। सिंक करने के लिए साइन इन करो।',
    'ja': 'タスクはこのデバイスにのみ保存されています。デバイス間で同期するにはサインインしてください。',
    'ko': '작업이 이 기기에만 저장되어 있습니다. 기기 간 동기화하려면 로그인하세요.',
  },
  'profile.you': {
    'en': 'You',
    'ru': 'Ты',
    'de': 'Du',
    'fr': 'Toi',
    'it': 'Tu',
    'pt': 'Você',
    'es': 'Tú',
    'id': 'Kamu',
    'hi': 'तुम',
    'ja': 'あなた',
    'ko': '나',
  },

  // ---- Profile: streak ----
  'profile.streak': {
    'en': 'Streak',
    'ru': 'Стрик',
    'de': 'Serie',
    'fr': 'Série',
    'it': 'Serie',
    'pt': 'Sequência',
    'es': 'Racha',
    'id': 'Streak',
    'hi': 'स्ट्रीक',
    'ja': 'ストリーク',
    'ko': '연속',
  },
  'profile.streak_best': {
    'en': 'Best',
    'ru': 'Рекорд',
    'de': 'Bestleistung',
    'fr': 'Record',
    'it': 'Record',
    'pt': 'Recorde',
    'es': 'Récord',
    'id': 'Terbaik',
    'hi': 'सर्वश्रेष्ठ',
    'ja': 'ベスト',
    'ko': '최고',
  },
  'profile.streak_freezes': {
    'en': 'Freezes ❄️',
    'ru': 'Заморозки ❄️',
    'de': 'Einfrierungen ❄️',
    'fr': 'Gels ❄️',
    'it': 'Blocchi ❄️',
    'pt': 'Congelamentos ❄️',
    'es': 'Congelaciones ❄️',
    'id': 'Pembekuan ❄️',
    'hi': 'फ्रीज़ ❄️',
    'ja': 'フリーズ ❄️',
    'ko': '동결 ❄️',
  },
  'profile.freeze_hint': {
    'en': 'Give yourself a day off — a freeze will protect your streak automatically if you miss today.',
    'ru': 'Дай себе выходной — заморозка защитит стрик, если пропустишь сегодня.',
    'de': 'Gönne dir einen freien Tag — eine Einfrierung schützt deine Serie automatisch, wenn du heute aussetzt.',
    'fr': 'Accorde-toi un jour de repos — un gel protégera automatiquement ta série si tu rates aujourd\'hui.',
    'it': 'Prenditi un giorno libero — un blocco proteggerà automaticamente la tua serie se salti oggi.',
    'pt': 'Dê-se um dia de folga — um congelamento protegerá sua sequência automaticamente se você falhar hoje.',
    'es': 'Date un día libre — una congelación protegerá tu racha automáticamente si fallas hoy.',
    'id': 'Beri dirimu hari libur — pembekuan akan melindungi streakmu secara otomatis jika kamu melewatkan hari ini.',
    'hi': 'खुद को एक दिन की छुट्टी दो — फ्रीज़ आज चूकने पर तुम्हारी स्ट्रीक को अपने आप बचाएगा।',
    'ja': '休みを取ろう — 今日を逃しても、フリーズがストリークを自動的に守ります。',
    'ko': '하루 쉬어도 괜찮아요 — 오늘 놓쳐도 동결이 연속을 자동으로 보호합니다.',
  },

  // ---- Profile: тема ----
  'profile.theme_focus': {
    'en': 'Focus',
    'ru': 'Focus',
    'de': 'Focus',
    'fr': 'Focus',
    'it': 'Focus',
    'pt': 'Focus',
    'es': 'Focus',
    'id': 'Focus',
    'hi': 'Focus',
    'ja': 'Focus',
    'ko': 'Focus',
  },
  'profile.theme_calm': {
    'en': 'Calm',
    'ru': 'Calm',
    'de': 'Calm',
    'fr': 'Calm',
    'it': 'Calm',
    'pt': 'Calm',
    'es': 'Calm',
    'id': 'Calm',
    'hi': 'Calm',
    'ja': 'Calm',
    'ko': 'Calm',
  },
  'profile.theme_black': {
    'en': 'Black',
    'ru': 'Black',
    'de': 'Black',
    'fr': 'Black',
    'it': 'Black',
    'pt': 'Black',
    'es': 'Black',
    'id': 'Black',
    'hi': 'Black',
    'ja': 'Black',
    'ko': 'Black',
  },
  'profile.theme_white': {
    'en': 'White',
    'ru': 'White',
    'de': 'White',
    'fr': 'White',
    'it': 'White',
    'pt': 'White',
    'es': 'White',
    'id': 'White',
    'hi': 'White',
    'ja': 'White',
    'ko': 'White',
  },
  'profile.theme_contrast': {
    'en': 'Contrast',
    'ru': 'Contrast',
    'de': 'Contrast',
    'fr': 'Contrast',
    'it': 'Contrast',
    'pt': 'Contrast',
    'es': 'Contrast',
    'id': 'Contrast',
    'hi': 'Contrast',
    'ja': 'Contrast',
    'ko': 'Contrast',
  },
  'profile.theme_custom': {
    'en': 'My Theme',
    'ru': 'Мой стиль',
    'de': 'Mein Stil',
    'fr': 'Mon thème',
    'it': 'Il mio tema',
    'pt': 'Meu tema',
    'es': 'Mi tema',
    'id': 'Tema saya',
    'hi': 'मेरा थीम',
    'ja': 'マイテーマ',
    'ko': '내 테마',
  },
  'profile.theme_custom_edit': {
    'en': 'Edit my theme',
    'ru': 'Изменить стиль',
    'de': 'Stil bearbeiten',
    'fr': 'Modifier mon thème',
    'it': 'Modifica il mio tema',
    'pt': 'Editar meu tema',
    'es': 'Editar mi tema',
    'id': 'Edit tema saya',
    'hi': 'मेरा थीम संपादित करो',
    'ja': 'テーマを編集',
    'ko': '내 테마 편집',
  },

  // ---- Редактор пользовательской темы ----
  'custom_theme.title': {
    'en': 'My Theme',
    'ru': 'Мой стиль',
    'de': 'Mein Stil',
    'fr': 'Mon thème',
    'it': 'Il mio tema',
    'pt': 'Meu tema',
    'es': 'Mi tema',
    'id': 'Tema saya',
    'hi': 'मेरा थीम',
    'ja': 'マイテーマ',
    'ko': '내 테마',
  },
  'custom_theme.reset': {
    'en': 'Reset',
    'ru': 'Сбросить',
    'de': 'Zurücksetzen',
    'fr': 'Réinitialiser',
    'it': 'Ripristina',
    'pt': 'Redefinir',
    'es': 'Restablecer',
    'id': 'Reset',
    'hi': 'रीसेट',
    'ja': 'リセット',
    'ko': '초기화',
  },
  'custom_theme.save': {
    'en': 'Save',
    'ru': 'Сохранить',
    'de': 'Speichern',
    'fr': 'Enregistrer',
    'it': 'Salva',
    'pt': 'Salvar',
    'es': 'Guardar',
    'id': 'Simpan',
    'hi': 'सहेजें',
    'ja': '保存',
    'ko': '저장',
  },
  'custom_theme.base_mode': {
    'en': 'Base mode',
    'ru': 'Режим',
    'de': 'Basismodus',
    'fr': 'Mode de base',
    'it': 'Modalità base',
    'pt': 'Modo base',
    'es': 'Modo base',
    'id': 'Mode dasar',
    'hi': 'बेस मोड',
    'ja': 'ベースモード',
    'ko': '기본 모드',
  },
  'custom_theme.dark': {
    'en': 'Dark',
    'ru': 'Тёмная',
    'de': 'Dunkel',
    'fr': 'Sombre',
    'it': 'Scuro',
    'pt': 'Escuro',
    'es': 'Oscuro',
    'id': 'Gelap',
    'hi': 'डार्क',
    'ja': 'ダーク',
    'ko': '다크',
  },
  'custom_theme.light': {
    'en': 'Light',
    'ru': 'Светлая',
    'de': 'Hell',
    'fr': 'Clair',
    'it': 'Chiaro',
    'pt': 'Claro',
    'es': 'Claro',
    'id': 'Terang',
    'hi': 'लाइट',
    'ja': 'ライト',
    'ko': '라이트',
  },
  'custom_theme.accent_color': {
    'en': 'Accent color',
    'ru': 'Акцент',
    'de': 'Akzentfarbe',
    'fr': 'Couleur d\'accent',
    'it': 'Colore accento',
    'pt': 'Cor de destaque',
    'es': 'Color de acento',
    'id': 'Warna aksen',
    'hi': 'एक्सेंट रंग',
    'ja': 'アクセントカラー',
    'ko': '강조 색상',
  },
  'custom_theme.custom_color': {
    'en': 'Custom color',
    'ru': 'Свой цвет',
    'de': 'Eigene Farbe',
    'fr': 'Couleur personnalisée',
    'it': 'Colore personalizzato',
    'pt': 'Cor personalizada',
    'es': 'Color personalizado',
    'id': 'Warna kustom',
    'hi': 'कस्टम रंग',
    'ja': 'カスタムカラー',
    'ko': '사용자 지정 색상',
  },
  'custom_theme.customize_more': {
    'en': 'Customize more',
    'ru': 'Дополнительно',
    'de': 'Mehr anpassen',
    'fr': 'Personnaliser plus',
    'it': 'Personalizza di più',
    'pt': 'Personalizar mais',
    'es': 'Personalizar más',
    'id': 'Kustomisasi lebih',
    'hi': 'और कस्टमाइज़ करो',
    'ja': 'さらにカスタマイズ',
    'ko': '더 맞춤설정',
  },
  'custom_theme.bg_warmth': {
    'en': 'Background warmth',
    'ru': 'Теплота фона',
    'de': 'Hintergrundwärme',
    'fr': 'Chaleur du fond',
    'it': 'Calore dello sfondo',
    'pt': 'Calor do fundo',
    'es': 'Calidez del fondo',
    'id': 'Kehangatan latar',
    'hi': 'बैकग्राउंड गर्माहट',
    'ja': '背景の温かみ',
    'ko': '배경 온도감',
  },
  'custom_theme.preview': {
    'en': 'Preview',
    'ru': 'Предпросмотр',
    'de': 'Vorschau',
    'fr': 'Aperçu',
    'it': 'Anteprima',
    'pt': 'Pré-visualização',
    'es': 'Vista previa',
    'id': 'Pratinjau',
    'hi': 'प्रीव्यू',
    'ja': 'プレビュー',
    'ko': '미리보기',
  },
  'custom_theme.accent_forced': {
    'en': 'Your color was too close to the background. We adjusted it slightly for readability.',
    'ru': 'Выбранный цвет был слишком близок к фону. Мы чуть скорректировали его для читаемости.',
    'de': 'Deine Farbe war dem Hintergrund zu ähnlich. Wir haben sie leicht angepasst, damit sie lesbar bleibt.',
    'fr': 'Ta couleur était trop proche du fond. Nous l\'avons légèrement ajustée pour la lisibilité.',
    'it': 'Il tuo colore era troppo simile allo sfondo. Lo abbiamo leggermente modificato per la leggibilità.',
    'pt': 'Sua cor estava muito próxima do fundo. Ajustamos levemente para melhor legibilidade.',
    'es': 'Tu color estaba muy cerca del fondo. Lo ajustamos ligeramente para mayor legibilidad.',
    'id': 'Warnamu terlalu dekat dengan latar belakang. Kami menyesuaikannya sedikit untuk keterbacaan.',
    'hi': 'तुम्हारा रंग बैकग्राउंड से बहुत करीब था। हमने पठनीयता के लिए इसे थोड़ा समायोजित किया।',
    'ja': '色が背景に近すぎました。読みやすさのために少し調整しました。',
    'ko': '색상이 배경과 너무 가까웠습니다. 가독성을 위해 약간 조정했습니다.',
  },
  'custom_theme.reset_confirm_title': {
    'en': 'Reset theme?',
    'ru': 'Сбросить стиль?',
    'de': 'Stil zurücksetzen?',
    'fr': 'Réinitialiser le thème ?',
    'it': 'Ripristinare il tema?',
    'pt': 'Redefinir tema?',
    'es': '¿Restablecer tema?',
    'id': 'Reset tema?',
    'hi': 'थीम रीसेट करें?',
    'ja': 'テーマをリセットしますか？',
    'ko': '테마를 초기화할까요?',
  },
  'custom_theme.reset_confirm_body': {
    'en': 'Your custom theme will be deleted and the app will switch back to Focus.',
    'ru': 'Пользовательский стиль будет удалён, а тема вернётся к Focus.',
    'de': 'Dein benutzerdefinierter Stil wird gelöscht und die App wechselt zurück zu Focus.',
    'fr': 'Ton thème personnalisé sera supprimé et l\'app reviendra à Focus.',
    'it': 'Il tuo tema personalizzato verrà eliminato e l\'app tornerà a Focus.',
    'pt': 'Seu tema personalizado será excluído e o app voltará para Focus.',
    'es': 'Tu tema personalizado se eliminará y la app volverá a Focus.',
    'id': 'Tema kustommu akan dihapus dan app kembali ke Focus.',
    'hi': 'तुम्हारा कस्टम थीम हटा दिया जाएगा और ऐप Focus पर वापस आ जाएगा।',
    'ja': 'カスタムテーマが削除され、アプリはFocusに戻ります。',
    'ko': '사용자 지정 테마가 삭제되고 앱이 Focus로 돌아갑니다.',
  },

  // ---- Profile: размер текста (опции селектора) ----
  'profile.text_size_small': {
    'en': 'Small',
    'ru': 'Маленький',
    'de': 'Klein',
    'fr': 'Petit',
    'it': 'Piccolo',
    'pt': 'Pequeno',
    'es': 'Pequeño',
    'id': 'Kecil',
    'hi': 'छोटा',
    'ja': '小',
    'ko': '작음',
  },
  'profile.text_size_default': {
    'en': 'Default',
    'ru': 'Обычный',
    'de': 'Standard',
    'fr': 'Défaut',
    'it': 'Predefinito',
    'pt': 'Padrão',
    'es': 'Estándar',
    'id': 'Standar',
    'hi': 'डिफ़ॉल्ट',
    'ja': '標準',
    'ko': '기본',
  },
  'profile.text_size_large': {
    'en': 'Large',
    'ru': 'Крупный',
    'de': 'Groß',
    'fr': 'Grand',
    'it': 'Grande',
    'pt': 'Grande',
    'es': 'Grande',
    'id': 'Besar',
    'hi': 'बड़ा',
    'ja': '大',
    'ko': '큼',
  },
  'profile.text_size_xlarge': {
    'en': 'Extra large',
    'ru': 'Очень крупный',
    'de': 'Sehr groß',
    'fr': 'Très grand',
    'it': 'Extra grande',
    'pt': 'Extra grande',
    'es': 'Extra grande',
    'id': 'Sangat besar',
    'hi': 'बहुत बड़ा',
    'ja': '特大',
    'ko': '매우 큼',
  },

  // ---- Profile: тон ----
  'profile.default_tone': {
    'en': 'Default tone',
    'ru': 'Тон по умолчанию',
    'de': 'Standardton',
    'fr': 'Ton par défaut',
    'it': 'Tono predefinito',
    'pt': 'Tom padrão',
    'es': 'Tono estándar',
    'id': 'Nada default',
    'hi': 'डिफ़ॉल्ट टोन',
    'ja': 'デフォルトのトーン',
    'ko': '기본 톤',
  },

  // ---- Profile: уведомления ----
  'profile.notifications_subtitle': {
    'en': 'Morning & evening review nudges',
    'ru': 'Напоминания утреннего и вечернего разбора',
    'de': 'Morgen- und Abenderinnerungen',
    'fr': 'Rappels matin et soir',
    'it': 'Promemoria mattina e sera',
    'pt': 'Lembretes de revisão manhã e noite',
    'es': 'Recordatorios de revisión mañana y tarde',
    'id': 'Pengingat tinjauan pagi & malam',
    'hi': 'सुबह और शाम की समीक्षा के अनुस्मारक',
    'ja': '朝と夜のレビューリマインダー',
    'ko': '아침·저녁 복습 알림',
  },
  'profile.notifications_snackbar': {
    'en': 'Enable notifications in system settings to use reminders',
    'ru': 'Разреши уведомления в настройках системы, чтобы использовать напоминания',
    'de': 'Aktiviere Benachrichtigungen in den Systemeinstellungen, um Erinnerungen zu nutzen',
    'fr': 'Active les notifications dans les paramètres système pour utiliser les rappels',
    'it': 'Attiva le notifiche nelle impostazioni di sistema per usare i promemoria',
    'pt': 'Ative as notificações nas configurações do sistema para usar lembretes',
    'es': 'Activa las notificaciones en los ajustes del sistema para usar recordatorios',
    'id': 'Aktifkan notifikasi di pengaturan sistem untuk menggunakan pengingat',
    'hi': 'रिमाइंडर उपयोग करने के लिए सिस्टम सेटिंग्स में नोटिफिकेशन चालू करो',
    'ja': 'リマインダーを使うにはシステム設定で通知を有効にしてください',
    'ko': '알림을 사용하려면 시스템 설정에서 알림을 활성화하세요',
  },

  // ---- Profile: маскот Kai ----
  'profile.show_kai': {
    'en': 'Show Kai',
    'ru': 'Показывать Kai',
    'de': 'Kai anzeigen',
    'fr': 'Afficher Kai',
    'it': 'Mostra Kai',
    'pt': 'Mostrar Kai',
    'es': 'Mostrar Kai',
    'id': 'Tampilkan Kai',
    'hi': 'Kai दिखाओ',
    'ja': 'Kaiを表示',
    'ko': 'Kai 표시',
  },
  'profile.show_kai_subtitle': {
    'en': 'The AI presence on your Today screen',
    'ru': 'ИИ-помощник на экране «Сегодня»',
    'de': 'Die KI-Präsenz auf deinem Heute-Bildschirm',
    'fr': 'La présence IA sur ton écran Aujourd\'hui',
    'it': 'La presenza AI nella schermata Oggi',
    'pt': 'A presença de IA na tela de Hoje',
    'es': 'La presencia de IA en tu pantalla de Hoy',
    'id': 'Kehadiran AI di layar Hari Ini',
    'hi': 'तुम्हारी आज की स्क्रीन पर AI की उपस्थिति',
    'ja': '今日の画面でのAIプレゼンス',
    'ko': '오늘 화면의 AI 존재감',
  },

  // ---- Profile: поддержка ----
  'profile.rate_app': {
    'en': 'Rate the app',
    'ru': 'Оценить приложение',
    'de': 'App bewerten',
    'fr': 'Évaluer l\'app',
    'it': 'Valuta l\'app',
    'pt': 'Avaliar o app',
    'es': 'Valorar la app',
    'id': 'Beri nilai app',
    'hi': 'ऐप को रेट करो',
    'ja': 'アプリを評価する',
    'ko': '앱 평가하기',
  },
  'profile.rate_coming_soon': {
    'en': "Coming soon — we're not in the store yet 😊",
    'ru': 'Скоро — нас пока нет в магазине 😊',
    'de': 'Kommt bald — wir sind noch nicht im Store 😊',
    'fr': 'Bientôt — nous ne sommes pas encore dans le store 😊',
    'it': 'Prossimamente — non siamo ancora nello store 😊',
    'pt': 'Em breve — ainda não estamos na loja 😊',
    'es': 'Próximamente — aún no estamos en la tienda 😊',
    'id': 'Segera hadir — kami belum ada di store 😊',
    'hi': 'जल्द आ रहा है — हम अभी स्टोर में नहीं हैं 😊',
    'ja': 'もうすぐ — まだストアには出ていません 😊',
    'ko': '곧 출시 — 아직 스토어에 없어요 😊',
  },
  'profile.send_feedback': {
    'en': 'Send feedback',
    'ru': 'Написать в поддержку',
    'de': 'Feedback senden',
    'fr': 'Envoyer un retour',
    'it': 'Invia feedback',
    'pt': 'Enviar feedback',
    'es': 'Enviar comentarios',
    'id': 'Kirim umpan balik',
    'hi': 'फीडबैक भेजो',
    'ja': 'フィードバックを送る',
    'ko': '피드백 보내기',
  },
  'profile.feedback_subtitle': {
    'en': 'Report a bug or suggest a feature',
    'ru': 'Сообщить об ошибке или предложить идею',
    'de': 'Fehler melden oder Feature vorschlagen',
    'fr': 'Signaler un bug ou proposer une fonctionnalité',
    'it': 'Segnala un bug o suggerisci una funzione',
    'pt': 'Reportar um bug ou sugerir uma funcionalidade',
    'es': 'Reportar un error o sugerir una función',
    'id': 'Laporkan bug atau usulkan fitur',
    'hi': 'बग रिपोर्ट करो या कोई फीचर सुझाओ',
    'ja': 'バグを報告するか機能を提案する',
    'ko': '버그 신고 또는 기능 제안',
  },
  'profile.feedback_email': {
    'en': 'Email us: support@kaizen.app',
    'ru': 'Напиши нам: support@kaizen.app',
    'de': 'Schreib uns: support@kaizen.app',
    'fr': 'Écris-nous : support@kaizen.app',
    'it': 'Scrivici: support@kaizen.app',
    'pt': 'Escreva para: support@kaizen.app',
    'es': 'Escríbenos: support@kaizen.app',
    'id': 'Email kami: support@kaizen.app',
    'hi': 'हमें ईमेल करो: support@kaizen.app',
    'ja': 'メールはこちら: support@kaizen.app',
    'ko': '이메일: support@kaizen.app',
  },
  'profile.terms_privacy': {
    'en': 'Terms & Privacy',
    'ru': 'Условия и конфиденциальность',
    'de': 'Nutzungsbedingungen & Datenschutz',
    'fr': 'CGU & Confidentialité',
    'it': 'Termini & Privacy',
    'pt': 'Termos & Privacidade',
    'es': 'Términos & Privacidad',
    'id': 'Syarat & Privasi',
    'hi': 'नियम और गोपनीयता',
    'ja': '利用規約 & プライバシー',
    'ko': '이용약관 & 개인정보',
  },

  // ---- Profile: реферал ----
  'profile.invite_title': {
    'en': 'Invite a friend',
    'ru': 'Пригласи друга',
    'de': 'Freund einladen',
    'fr': 'Inviter un ami',
    'it': 'Invita un amico',
    'pt': 'Convidar um amigo',
    'es': 'Invitar a un amigo',
    'id': 'Undang teman',
    'hi': 'दोस्त को आमंत्रित करो',
    'ja': '友達を招待する',
    'ko': '친구 초대하기',
  },
  'profile.invite_subtitle': {
    'en': 'Get 1 week free Premium for each friend who joins',
    'ru': 'Получи 1 неделю Premium бесплатно за каждого друга',
    'de': '1 Woche Premium kostenlos für jeden Freund, der beitritt',
    'fr': 'Obtiens 1 semaine de Premium gratuit pour chaque ami qui s\'inscrit',
    'it': 'Ottieni 1 settimana di Premium gratis per ogni amico che si unisce',
    'pt': 'Ganhe 1 semana de Premium grátis por cada amigo que entrar',
    'es': 'Obtén 1 semana de Premium gratis por cada amigo que se una',
    'id': 'Dapatkan 1 minggu Premium gratis untuk setiap teman yang bergabung',
    'hi': 'हर दोस्त के जुड़ने पर 1 हफ्ते का मुफ्त Premium पाओ',
    'ja': '友達が参加するごとに1週間の無料Premiumをもらえます',
    'ko': '친구가 가입할 때마다 1주 무료 Premium 획득',
  },
  'profile.share_kaizen': {
    'en': 'Share Kaizen',
    'ru': 'Поделиться Kaizen',
    'de': 'Kaizen teilen',
    'fr': 'Partager Kaizen',
    'it': 'Condividi Kaizen',
    'pt': 'Compartilhar Kaizen',
    'es': 'Compartir Kaizen',
    'id': 'Bagikan Kaizen',
    'hi': 'Kaizen शेयर करो',
    'ja': 'Kaizenをシェア',
    'ko': 'Kaizen 공유하기',
  },
  'profile.referral_coming_soon': {
    'en': 'Referral links coming after App Store launch 🚀',
    'ru': 'Реферальные ссылки появятся после запуска в App Store 🚀',
    'de': 'Empfehlungslinks kommen nach dem App-Store-Launch 🚀',
    'fr': 'Les liens de parrainage arrivent après le lancement sur l\'App Store 🚀',
    'it': 'I link di referral arriveranno dopo il lancio sull\'App Store 🚀',
    'pt': 'Links de indicação chegam após o lançamento na App Store 🚀',
    'es': 'Los enlaces de referido llegan tras el lanzamiento en la App Store 🚀',
    'id': 'Link referral hadir setelah peluncuran App Store 🚀',
    'hi': 'App Store लॉन्च के बाद रेफरल लिंक आएंगे 🚀',
    'ja': 'App Store ローンチ後に紹介リンクが届きます 🚀',
    'ko': 'App Store 출시 후 추천 링크가 추가됩니다 🚀',
  },

  // ---- Profile: карточка подписки ----
  'profile.premium_badge': {
    'en': 'Kaizen Premium',
    'ru': 'Kaizen Premium',
    'de': 'Kaizen Premium',
    'fr': 'Kaizen Premium',
    'it': 'Kaizen Premium',
    'pt': 'Kaizen Premium',
    'es': 'Kaizen Premium',
    'id': 'Kaizen Premium',
    'hi': 'Kaizen Premium',
    'ja': 'Kaizen Premium',
    'ko': 'Kaizen Premium',
  },
  'profile.free_plan': {
    'en': 'Free plan',
    'ru': 'Бесплатный план',
    'de': 'Kostenloser Plan',
    'fr': 'Plan gratuit',
    'it': 'Piano gratuito',
    'pt': 'Plano gratuito',
    'es': 'Plan gratuito',
    'id': 'Paket gratis',
    'hi': 'मुफ्त प्लान',
    'ja': '無料プラン',
    'ko': '무료 플랜',
  },
  'profile.premium_unlocked': {
    'en': 'AI features unlocked',
    'ru': 'Функции ИИ открыты',
    'de': 'KI-Funktionen freigeschaltet',
    'fr': 'Fonctionnalités IA débloquées',
    'it': 'Funzioni AI sbloccate',
    'pt': 'Recursos de IA desbloqueados',
    'es': 'Funciones de IA desbloqueadas',
    'id': 'Fitur AI terbuka',
    'hi': 'AI फीचर अनलॉक हैं',
    'ja': 'AI機能が解放されました',
    'ko': 'AI 기능 잠금 해제됨',
  },
  'profile.premium_unlock_cta': {
    'en': r'Unlock AI — $10/mo',
    'ru': r'Открой ИИ — $10/мес',
    'de': r'KI freischalten — $10/Monat',
    'fr': "Débloquer l'IA — \$10/mois",
    'it': "Sblocca l'AI — \$10/mese",
    'pt': r'Desbloquear IA — $10/mês',
    'es': r'Desbloquear IA — $10/mes',
    'id': r'Buka AI — $10/bln',
    'hi': r'AI अनलॉक करो — $10/माह',
    'ja': r'AIを解放 — $10/月',
    'ko': r'AI 잠금 해제 — $10/월',
  },

  // ---- Profile: «Поделиться неделей» ----
  'profile.share_week': {
    'en': 'Share my week',
    'ru': 'Поделиться неделей',
    'de': 'Meine Woche teilen',
    'fr': 'Partager ma semaine',
    'it': 'Condividi la mia settimana',
    'pt': 'Compartilhar minha semana',
    'es': 'Compartir mi semana',
    'id': 'Bagikan minggu saya',
    'hi': 'मेरा हफ्ता शेयर करो',
    'ja': '今週をシェア',
    'ko': '이번 주 공유하기',
  },
  'profile.share_week_subtitle': {
    'en': 'View-only web link · friends need no app',
    'ru': 'Ссылка только для просмотра · друзьям не нужно приложение',
    'de': 'Nur-Ansicht-Link · Freunde brauchen keine App',
    'fr': 'Lien lecture seule · les amis n\'ont pas besoin de l\'app',
    'it': 'Link solo visualizzazione · gli amici non hanno bisogno dell\'app',
    'pt': 'Link somente leitura · amigos não precisam do app',
    'es': 'Enlace solo lectura · los amigos no necesitan la app',
    'id': 'Link hanya lihat · teman tidak perlu app',
    'hi': 'सिर्फ देखने का लिंक · दोस्तों को ऐप की जरूरत नहीं',
    'ja': '閲覧専用リンク · 友達にアプリ不要',
    'ko': '읽기 전용 링크 · 친구에게 앱 필요 없음',
  },
  'profile.share_sign_in': {
    'en': 'Sign in to share your plan',
    'ru': 'Войди, чтобы поделиться планом',
    'de': 'Melde dich an, um deinen Plan zu teilen',
    'fr': 'Connecte-toi pour partager ton plan',
    'it': 'Accedi per condividere il tuo piano',
    'pt': 'Faça login para compartilhar seu plano',
    'es': 'Inicia sesión para compartir tu plan',
    'id': 'Masuk untuk berbagi rencanamu',
    'hi': 'अपना प्लान शेयर करने के लिए साइन इन करो',
    'ja': 'プランをシェアするにはサインインしてください',
    'ko': '플랜을 공유하려면 로그인하세요',
  },
  'profile.share_link_copied': {
    'en': 'Link copied — valid for 7 days, view-only',
    'ru': 'Ссылка скопирована — действует 7 дней, только просмотр',
    'de': 'Link kopiert — gültig für 7 Tage, nur Ansicht',
    'fr': 'Lien copié — valable 7 jours, lecture seule',
    'it': 'Link copiato — valido 7 giorni, solo visualizzazione',
    'pt': 'Link copiado — válido por 7 dias, somente leitura',
    'es': 'Enlace copiado — válido 7 días, solo lectura',
    'id': 'Link disalin — berlaku 7 hari, hanya lihat',
    'hi': 'लिंक कॉपी हुआ — 7 दिन वैध, सिर्फ देखने के लिए',
    'ja': 'リンクをコピーしました — 7日間有効、閲覧専用',
    'ko': '링크 복사됨 — 7일 유효, 읽기 전용',
  },

  // ---- Profile: «Поделились со мной» ----
  'profile.shared_with_me': {
    'en': 'Shared with me',
    'ru': 'Поделились со мной',
    'de': 'Mit mir geteilt',
    'fr': 'Partagé avec moi',
    'it': 'Condiviso con me',
    'pt': 'Compartilhado comigo',
    'es': 'Compartido conmigo',
    'id': 'Dibagikan ke saya',
    'hi': 'मेरे साथ शेयर किया',
    'ja': '共有された',
    'ko': '나와 공유됨',
  },
  'profile.shared_with_me_subtitle': {
    'en': "Open a friend's plan link",
    'ru': 'Открыть ссылку на план друга',
    'de': "Link zum Plan eines Freundes öffnen",
    'fr': 'Ouvrir le lien du plan d\'un ami',
    'it': 'Apri il link del piano di un amico',
    'pt': 'Abrir link do plano de um amigo',
    'es': 'Abrir el enlace del plan de un amigo',
    'id': 'Buka link rencana teman',
    'hi': 'दोस्त का प्लान लिंक खोलो',
    'ja': '友達のプランリンクを開く',
    'ko': '친구 플랜 링크 열기',
  },
  'profile.paste_link_hint': {
    'en': 'Paste link or token',
    'ru': 'Вставь ссылку или токен',
    'de': 'Link oder Token einfügen',
    'fr': 'Colle le lien ou le jeton',
    'it': 'Incolla link o token',
    'pt': 'Cole o link ou token',
    'es': 'Pega el enlace o token',
    'id': 'Tempel link atau token',
    'hi': 'लिंक या टोकन पेस्ट करो',
    'ja': 'リンクまたはトークンを貼り付け',
    'ko': '링크 또는 토큰 붙여넣기',
  },
  'profile.open': {
    'en': 'Open',
    'ru': 'Открыть',
    'de': 'Öffnen',
    'fr': 'Ouvrir',
    'it': 'Apri',
    'pt': 'Abrir',
    'es': 'Abrir',
    'id': 'Buka',
    'hi': 'खोलो',
    'ja': '開く',
    'ko': '열기',
  },
  'profile.invalid_link': {
    'en': 'Invalid link or token',
    'ru': 'Неверная ссылка или токен',
    'de': 'Ungültiger Link oder Token',
    'fr': 'Lien ou jeton invalide',
    'it': 'Link o token non valido',
    'pt': 'Link ou token inválido',
    'es': 'Enlace o token inválido',
    'id': 'Link atau token tidak valid',
    'hi': 'अमान्य लिंक या टोकन',
    'ja': '無効なリンクまたはトークン',
    'ko': '잘못된 링크 또는 토큰',
  },
  'profile.network_error': {
    'en': 'Network error — check your connection',
    'ru': 'Ошибка сети — проверь подключение',
    'de': 'Netzwerkfehler — überprüfe deine Verbindung',
    'fr': 'Erreur réseau — vérifie ta connexion',
    'it': 'Errore di rete — controlla la connessione',
    'pt': 'Erro de rede — verifique sua conexão',
    'es': 'Error de red — revisa tu conexión',
    'id': 'Kesalahan jaringan — periksa koneksimu',
    'hi': 'नेटवर्क त्रुटि — कनेक्शन जांचो',
    'ja': 'ネットワークエラー — 接続を確認してください',
    'ko': '네트워크 오류 — 연결을 확인하세요',
  },
  'profile.no_events': {
    'en': 'No events in this plan',
    'ru': 'В этом плане нет событий',
    'de': 'Keine Ereignisse in diesem Plan',
    'fr': 'Aucun événement dans ce plan',
    'it': 'Nessun evento in questo piano',
    'pt': 'Nenhum evento neste plano',
    'es': 'Sin eventos en este plan',
    'id': 'Tidak ada acara dalam rencana ini',
    'hi': 'इस प्लान में कोई इवेंट नहीं',
    'ja': 'このプランにイベントはありません',
    'ko': '이 플랜에 일정 없음',
  },
  // Шит просмотра чужого плана
  // {name} — имя владельца
  'profile.plan_of': {
    'en': "{name}'s plan",
    'ru': 'План {name}',
    'de': 'Plan von {name}',
    'fr': 'Plan de {name}',
    'it': 'Piano di {name}',
    'pt': 'Plano de {name}',
    'es': 'Plan de {name}',
    'id': 'Rencana {name}',
    'hi': '{name} का प्लान',
    'ja': '{name}のプラン',
    'ko': '{name}의 플랜',
  },
  // {n} — число событий; английская форма с одним словом (без plural-рисков в РУ — используем число)
  'profile.copy_to_my_plan': {
    'en': 'Copy to my plan ({n})',
    'ru': 'Скопировать в мой план ({n})',
    'de': 'In meinen Plan kopieren ({n})',
    'fr': 'Copier dans mon plan ({n})',
    'it': 'Copia nel mio piano ({n})',
    'pt': 'Copiar para meu plano ({n})',
    'es': 'Copiar a mi plan ({n})',
    'id': 'Salin ke rencana saya ({n})',
    'hi': 'मेरे प्लान में कॉपी करो ({n})',
    'ja': '自分のプランにコピー ({n})',
    'ko': '내 플랜에 복사 ({n})',
  },
  // {n} — число скопированных событий
  'profile.events_copied': {
    'en': '{n} events copied to your plan',
    'ru': 'Скопировано событий в ваш план: {n}',
    'de': '{n} Ereignisse in deinen Plan kopiert',
    'fr': '{n} événements copiés dans ton plan',
    'it': '{n} eventi copiati nel tuo piano',
    'pt': '{n} eventos copiados para o seu plano',
    'es': '{n} eventos copiados a tu plan',
    'id': '{n} acara disalin ke rencanamu',
    'hi': '{n} इवेंट तुम्हारे प्लान में कॉपी हुए',
    'ja': '{n}件のイベントをプランにコピーしました',
    'ko': '{n}개 일정이 플랜에 복사됨',
  },

  // ---- Terms ----
  'profile.terms_title': {
    'en': 'Terms of Service',
    'ru': 'Условия использования',
    'de': 'Nutzungsbedingungen',
    'fr': 'Conditions d\'utilisation',
    'it': 'Termini di servizio',
    'pt': 'Termos de Serviço',
    'es': 'Términos de servicio',
    'id': 'Syarat Layanan',
    'hi': 'सेवा की शर्तें',
    'ja': '利用規約',
    'ko': '서비스 약관',
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
    'fr': 'Dernière mise à jour : juin 2026\n\n'
        'En utilisant Kaizen (« l\'application »), tu acceptes ces conditions. '
        'Kaizen est un outil de productivité personnelle pour les étudiants.\n\n'
        '1. Utilise l\'application uniquement à des fins légales.\n'
        '2. Tu es responsable de la sécurité de tes identifiants.\n'
        '3. Nous pouvons mettre à jour l\'application et ces conditions à tout moment.\n'
        '4. L\'application est fournie « telle quelle » sans aucune garantie.\n'
        '5. Les frais d\'abonnement ne sont pas remboursables sauf si la loi l\'exige.',
    'it': 'Ultimo aggiornamento: giugno 2026\n\n'
        'Utilizzando Kaizen («l\'app»), accetti questi termini. '
        'Kaizen è uno strumento di produttività personale per studenti.\n\n'
        '1. Usa l\'app solo per scopi leciti.\n'
        '2. Sei responsabile della sicurezza delle tue credenziali.\n'
        '3. Possiamo aggiornare l\'app e questi termini in qualsiasi momento.\n'
        '4. L\'app è fornita «così com\'è» senza garanzie di alcun tipo.\n'
        '5. Le quote di abbonamento non sono rimborsabili salvo quanto richiesto dalla legge.',
    'pt': 'Última atualização: junho de 2026\n\n'
        'Ao usar o Kaizen ("o app"), você concorda com estes termos. '
        'Kaizen é uma ferramenta de produtividade pessoal para estudantes.\n\n'
        '1. Use o app apenas para fins legais.\n'
        '2. Você é responsável por manter suas credenciais seguras.\n'
        '3. Podemos atualizar o app e estes termos a qualquer momento.\n'
        '4. O app é fornecido "como está" sem garantias de qualquer tipo.\n'
        '5. As taxas de assinatura não são reembolsáveis, exceto conforme exigido por lei.',
    'es': 'Última actualización: junio de 2026\n\n'
        'Al usar Kaizen («la app»), aceptas estos términos. '
        'Kaizen es una herramienta de productividad personal para estudiantes.\n\n'
        '1. Usa la app solo para fines legales.\n'
        '2. Eres responsable de mantener tus credenciales seguras.\n'
        '3. Podemos actualizar la app y estos términos en cualquier momento.\n'
        '4. La app se proporciona «tal cual» sin garantías de ningún tipo.\n'
        '5. Las cuotas de suscripción no son reembolsables salvo lo exigido por ley.',
    'id': 'Terakhir diperbarui: Juni 2026\n\n'
        'Dengan menggunakan Kaizen ("app"), kamu menyetujui ketentuan ini. '
        'Kaizen adalah alat produktivitas pribadi untuk pelajar.\n\n'
        '1. Gunakan app hanya untuk tujuan yang sah.\n'
        '2. Kamu bertanggung jawab menjaga keamanan kredensial akunmu.\n'
        '3. Kami dapat memperbarui app dan ketentuan ini kapan saja.\n'
        '4. App disediakan "apa adanya" tanpa jaminan apa pun.\n'
        '5. Biaya langganan tidak dapat dikembalikan kecuali diwajibkan oleh hukum.',
    'hi': 'अंतिम अपडेट: जून 2026\n\n'
        'Kaizen («ऐप») का उपयोग करके, तुम इन शर्तों से सहमत हो। '
        'Kaizen छात्रों के लिए एक व्यक्तिगत उत्पादकता टूल है।\n\n'
        '1. ऐप का उपयोग केवल कानूनी उद्देश्यों के लिए करो।\n'
        '2. अपने अकाउंट क्रेडेंशियल सुरक्षित रखने की जिम्मेदारी तुम्हारी है।\n'
        '3. हम कभी भी ऐप और इन शर्तों को अपडेट कर सकते हैं।\n'
        '4. ऐप किसी भी वारंटी के बिना «जैसा है» प्रदान किया जाता है।\n'
        '5. सदस्यता शुल्क वापस नहीं होता, जब तक कानून द्वारा आवश्यक न हो।',
    'ja': '最終更新：2026年6月\n\n'
        'Kaizen（「アプリ」）を使用することで、これらの利用規約に同意したものとみなされます。'
        'Kaizenは学生向けの個人生産性ツールです。\n\n'
        '1. アプリは合法的な目的にのみ使用してください。\n'
        '2. アカウント認証情報の安全管理はご自身の責任です。\n'
        '3. 当社はいつでもアプリとこの規約を更新できます。\n'
        '4. アプリはいかなる保証もなく「現状のまま」提供されます。\n'
        '5. サブスクリプション料金は、法律で義務付けられている場合を除き返金不可です。',
    'ko': '최종 업데이트: 2026년 6월\n\n'
        'Kaizen(«앱»)을 사용함으로써 이 약관에 동의합니다. '
        'Kaizen은 학생을 위한 개인 생산성 도구입니다.\n\n'
        '1. 앱은 합법적인 목적으로만 사용하세요.\n'
        '2. 계정 자격 증명의 보안 유지는 본인의 책임입니다.\n'
        '3. 당사는 언제든지 앱과 이 약관을 업데이트할 수 있습니다.\n'
        '4. 앱은 어떠한 보증 없이 «있는 그대로» 제공됩니다.\n'
        '5. 구독료는 법률에서 요구하는 경우를 제외하고 환불되지 않습니다.',
  },
  'profile.privacy_title': {
    'en': 'Privacy Policy',
    'ru': 'Политика конфиденциальности',
    'de': 'Datenschutzrichtlinie',
    'fr': 'Politique de confidentialité',
    'it': 'Informativa sulla privacy',
    'pt': 'Política de Privacidade',
    'es': 'Política de privacidad',
    'id': 'Kebijakan Privasi',
    'hi': 'गोपनीयता नीति',
    'ja': 'プライバシーポリシー',
    'ko': '개인정보처리방침',
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
    'fr': 'Dernière mise à jour : juin 2026\n\n'
        'Nous prenons ta vie privée au sérieux.\n\n'
        'Ce que nous collectons :\n'
        '• Informations de compte (e-mail, nom) — pour identifier ton compte.\n'
        '• Tâches, entrées de journal, journaux de santé — synchronisés pour fournir le service.\n'
        '• Données d\'utilisation (anonymes) — pour améliorer l\'application.\n\n'
        'Ce que nous ne faisons pas :\n'
        '• Nous ne vendons pas tes données à des tiers.\n'
        '• Nous ne montrons pas de publicités aux utilisateurs Premium.\n'
        '• Nous ne partageons pas de données personnelles avec des annonceurs.\n\n'
        'Fonctionnalités IA (Premium) :\n'
        'Lorsque tu utilises les fonctionnalités IA, tes tâches et résumés de journal sont envoyés '
        'à notre fournisseur IA (Google Gemini ou Anthropic Claude) pour générer des réponses. '
        'Ces données ne sont pas utilisées pour entraîner leurs modèles selon nos accords.\n\n'
        'Stockage des données :\n'
        'Tes données sont stockées sur des serveurs dans l\'UE/États-Unis. '
        'Tu peux supprimer ton compte et toutes les données à tout moment en contactant support@kaizen.app.\n\n'
        'Contact : support@kaizen.app',
    'it': 'Ultimo aggiornamento: giugno 2026\n\n'
        'Prendiamo sul serio la tua privacy.\n\n'
        'Cosa raccogliamo:\n'
        '• Informazioni account (email, nome) — per identificare il tuo account.\n'
        '• Attività, voci del diario, log di salute — sincronizzati per fornire il servizio.\n'
        '• Dati di utilizzo (anonimi) — per migliorare l\'app.\n\n'
        'Cosa non facciamo:\n'
        '• Non vendiamo i tuoi dati a terzi.\n'
        '• Non mostriamo pubblicità agli utenti Premium.\n'
        '• Non condividiamo dati personali con inserzionisti.\n\n'
        'Funzioni AI (Premium):\n'
        'Quando usi le funzioni AI, le tue attività e i riepiloghi del diario vengono inviati '
        'al nostro provider AI (Google Gemini o Anthropic Claude) per generare risposte. '
        'Questi dati non vengono usati per addestrare i loro modelli secondo i nostri accordi.\n\n'
        'Archiviazione dati:\n'
        'I tuoi dati sono archiviati su server nell\'UE/USA. '
        'Puoi eliminare il tuo account e tutti i dati in qualsiasi momento contattando support@kaizen.app.\n\n'
        'Contatto: support@kaizen.app',
    'pt': 'Última atualização: junho de 2026\n\n'
        'Levamos sua privacidade a sério.\n\n'
        'O que coletamos:\n'
        '• Informações da conta (email, nome) — para identificar sua conta.\n'
        '• Tarefas, entradas do diário, registros de saúde — sincronizados para fornecer o serviço.\n'
        '• Dados de uso (anônimos) — para melhorar o app.\n\n'
        'O que não fazemos:\n'
        '• Não vendemos seus dados a terceiros.\n'
        '• Não exibimos anúncios a usuários Premium.\n'
        '• Não compartilhamos dados pessoais com anunciantes.\n\n'
        'Recursos de IA (Premium):\n'
        'Quando você usa os recursos de IA, suas tarefas e resumos do diário são enviados '
        'ao nosso provedor de IA (Google Gemini ou Anthropic Claude) para gerar respostas. '
        'Esses dados não são usados para treinar seus modelos conforme nossos acordos.\n\n'
        'Armazenamento de dados:\n'
        'Seus dados são armazenados em servidores na UE/EUA. '
        'Você pode excluir sua conta e todos os dados a qualquer momento entrando em contato com support@kaizen.app.\n\n'
        'Contato: support@kaizen.app',
    'es': 'Última actualización: junio de 2026\n\n'
        'Nos tomamos tu privacidad en serio.\n\n'
        'Qué recopilamos:\n'
        '• Información de cuenta (email, nombre) — para identificar tu cuenta.\n'
        '• Tareas, entradas del diario, registros de salud — sincronizados para brindar el servicio.\n'
        '• Datos de uso (anónimos) — para mejorar la app.\n\n'
        'Qué no hacemos:\n'
        '• No vendemos tus datos a terceros.\n'
        '• No mostramos anuncios a usuarios Premium.\n'
        '• No compartimos datos personales con anunciantes.\n\n'
        'Funciones de IA (Premium):\n'
        'Cuando usas las funciones de IA, tus tareas y resúmenes del diario se envían '
        'a nuestro proveedor de IA (Google Gemini o Anthropic Claude) para generar respuestas. '
        'Estos datos no se usan para entrenar sus modelos según nuestros acuerdos.\n\n'
        'Almacenamiento de datos:\n'
        'Tus datos se almacenan en servidores en la UE/EE. UU. '
        'Puedes eliminar tu cuenta y todos los datos en cualquier momento contactando a support@kaizen.app.\n\n'
        'Contacto: support@kaizen.app',
    'id': 'Terakhir diperbarui: Juni 2026\n\n'
        'Kami serius menjaga privasimu.\n\n'
        'Yang kami kumpulkan:\n'
        '• Info akun (email, nama) — untuk mengidentifikasi akunmu.\n'
        '• Tugas, entri jurnal, log kesehatan — disinkronkan untuk menyediakan layanan.\n'
        '• Data penggunaan (anonim) — untuk meningkatkan app.\n\n'
        'Yang tidak kami lakukan:\n'
        '• Kami tidak menjual datamu kepada pihak ketiga.\n'
        '• Kami tidak menampilkan iklan kepada pengguna Premium.\n'
        '• Kami tidak berbagi data pribadi dengan pengiklan.\n\n'
        'Fitur AI (Premium):\n'
        'Saat kamu menggunakan fitur AI, tugas dan ringkasan jurnalmu dikirim '
        'ke penyedia AI kami (Google Gemini atau Anthropic Claude) untuk menghasilkan respons. '
        'Data ini tidak digunakan untuk melatih model mereka sesuai perjanjian kami.\n\n'
        'Penyimpanan data:\n'
        'Datamu disimpan di server di UE/AS. '
        'Kamu dapat menghapus akun dan semua data kapan saja dengan menghubungi support@kaizen.app.\n\n'
        'Kontak: support@kaizen.app',
    'hi': 'अंतिम अपडेट: जून 2026\n\n'
        'हम तुम्हारी गोपनीयता को गंभीरता से लेते हैं।\n\n'
        'हम क्या इकट्ठा करते हैं:\n'
        '• अकाउंट जानकारी (ईमेल, नाम) — तुम्हारे अकाउंट की पहचान के लिए।\n'
        '• टास्क, डायरी एंट्री, हेल्थ लॉग — सेवा प्रदान करने के लिए सिंक किए जाते हैं।\n'
        '• उपयोग डेटा (अनाम) — ऐप को बेहतर बनाने के लिए।\n\n'
        'हम क्या नहीं करते:\n'
        '• हम तुम्हारा डेटा तृतीय पक्षों को नहीं बेचते।\n'
        '• हम Premium उपयोगकर्ताओं को विज्ञापन नहीं दिखाते।\n'
        '• हम विज्ञापनदाताओं के साथ व्यक्तिगत डेटा साझा नहीं करते।\n\n'
        'AI फीचर (Premium):\n'
        'जब तुम AI फीचर का उपयोग करते हो, तुम्हारे टास्क और डायरी सारांश '
        'हमारे AI प्रदाता (Google Gemini या Anthropic Claude) को भेजे जाते हैं। '
        'हमारे समझौतों के अनुसार यह डेटा उनके मॉडल को प्रशिक्षित करने के लिए उपयोग नहीं किया जाता।\n\n'
        'डेटा संग्रहण:\n'
        'तुम्हारा डेटा EU/US के सर्वर पर संग्रहीत है। '
        'तुम कभी भी support@kaizen.app से संपर्क करके अकाउंट और सभी डेटा हटा सकते हो।\n\n'
        'संपर्क: support@kaizen.app',
    'ja': '最終更新：2026年6月\n\n'
        'お客様のプライバシーを真剣に考えています。\n\n'
        '収集する情報：\n'
        '• アカウント情報（メール、名前）— アカウントの識別のため。\n'
        '• タスク、日記エントリ、健康ログ — サービス提供のために同期。\n'
        '• 使用データ（匿名）— アプリ改善のため。\n\n'
        '行わないこと：\n'
        '• データを第三者に販売しません。\n'
        '• Premiumユーザーに広告を表示しません。\n'
        '• 個人データを広告主と共有しません。\n\n'
        'AI機能（Premium）：\n'
        'AI機能を使用すると、タスクと日記のサマリーが当社のAIプロバイダー'
        '（Google GeminiまたはAnthropic Claude）に送信されます。'
        '契約に基づき、このデータはモデルの学習には使用されません。\n\n'
        'データ保存：\n'
        'データはEU/米国のサーバーに保存されます。'
        'いつでもsupport@kaizen.appに連絡してアカウントとすべてのデータを削除できます。\n\n'
        '連絡先：support@kaizen.app',
    'ko': '최종 업데이트: 2026년 6월\n\n'
        '귀하의 개인정보를 소중히 여깁니다.\n\n'
        '수집하는 정보:\n'
        '• 계정 정보(이메일, 이름) — 계정 식별을 위해.\n'
        '• 작업, 일기 항목, 건강 기록 — 서비스 제공을 위해 동기화.\n'
        '• 사용 데이터(익명) — 앱 개선을 위해.\n\n'
        '하지 않는 것:\n'
        '• 데이터를 제3자에게 판매하지 않습니다.\n'
        '• Premium 사용자에게 광고를 표시하지 않습니다.\n'
        '• 개인 데이터를 광고주와 공유하지 않습니다.\n\n'
        'AI 기능(Premium):\n'
        'AI 기능을 사용하면 작업 및 일기 요약이 당사의 AI 공급자'
        '(Google Gemini 또는 Anthropic Claude)에게 전송됩니다.'
        '계약에 따라 이 데이터는 모델 훈련에 사용되지 않습니다.\n\n'
        '데이터 저장:\n'
        '데이터는 EU/미국 서버에 저장됩니다.'
        '언제든지 support@kaizen.app에 연락하여 계정과 모든 데이터를 삭제할 수 있습니다.\n\n'
        '연락처: support@kaizen.app',
  },
  'profile.tagline': {
    'en': "Kaizen — the important stuff won't slip.",
    'ru': 'Kaizen — главное не упустишь.',
    'de': 'Kaizen — das Wichtige geht nicht unter.',
    'fr': 'Kaizen — l\'essentiel ne t\'échappera pas.',
    'it': 'Kaizen — le cose importanti non ti sfuggiranno.',
    'pt': 'Kaizen — o que importa não vai escapar.',
    'es': 'Kaizen — lo importante no se te escapará.',
    'id': 'Kaizen — hal penting tidak akan terlewat.',
    'hi': 'Kaizen — जरूरी चीजें कभी नहीं चूकेंगी।',
    'ja': 'Kaizen — 大事なことは見逃さない。',
    'ko': 'Kaizen — 중요한 것은 놓치지 않아요.',
  },

  // ---- Paywall ----
  'paywall.title': {
    'en': 'Kaizen Premium',
    'ru': 'Kaizen Premium',
    'de': 'Kaizen Premium',
    'fr': 'Kaizen Premium',
    'it': 'Kaizen Premium',
    'pt': 'Kaizen Premium',
    'es': 'Kaizen Premium',
    'id': 'Kaizen Premium',
    'hi': 'Kaizen Premium',
    'ja': 'Kaizen Premium',
    'ko': 'Kaizen Premium',
  },
  'paywall.headline': {
    'en': 'Unlock the AI',
    'ru': 'Открой возможности ИИ',
    'de': 'KI freischalten',
    'fr': 'Débloquer l\'IA',
    'it': 'Sblocca l\'AI',
    'pt': 'Desbloquear a IA',
    'es': 'Desbloquear la IA',
    'id': 'Buka AI',
    'hi': 'AI अनलॉक करो',
    'ja': 'AIを解放する',
    'ko': 'AI 잠금 해제',
  },
  'paywall.subheadline': {
    'en': 'The important stuff, planned for you.',
    'ru': 'Главное — спланировано за тебя.',
    'de': 'Das Wichtige, für dich geplant.',
    'fr': 'L\'essentiel, planifié pour toi.',
    'it': 'Le cose importanti, pianificate per te.',
    'pt': 'O que importa, planejado para você.',
    'es': 'Lo importante, planificado para ti.',
    'id': 'Hal penting, direncanakan untukmu.',
    'hi': 'जरूरी चीजें, तुम्हारे लिए प्लान की गईं।',
    'ja': '大切なことが、あなたのためにプランされます。',
    'ko': '중요한 것, 당신을 위해 계획됩니다.',
  },

  // Речевой пузырь Kai — тёплый, ненавязчивый
  'paywall.kai_bubble': {
    'en': 'I can help you plan smarter.',
    'ru': 'Я помогу планировать умнее.',
    'de': 'Ich helfe dir, smarter zu planen.',
    'fr': 'Je peux t\'aider à planifier plus intelligemment.',
    'it': 'Posso aiutarti a pianificare in modo più intelligente.',
    'pt': 'Posso te ajudar a planejar com mais inteligência.',
    'es': 'Puedo ayudarte a planificar de forma más inteligente.',
    'id': 'Aku bisa membantu kamu merencanakan lebih cerdas.',
    'hi': 'मैं तुम्हें स्मार्ट तरीके से प्लान करने में मदद कर सकता हूं।',
    'ja': 'もっとスマートに計画する手助けができます。',
    'ko': '더 스마트하게 계획하도록 도와드릴게요.',
  },

  // Строки планов
  'paywall.plan_monthly': {
    'en': 'Monthly',
    'ru': 'Ежемесячно',
    'de': 'Monatlich',
    'fr': 'Mensuel',
    'it': 'Mensile',
    'pt': 'Mensal',
    'es': 'Mensual',
    'id': 'Bulanan',
    'hi': 'मासिक',
    'ja': '月払い',
    'ko': '월간',
  },
  'paywall.plan_yearly': {
    'en': 'Yearly',
    'ru': 'Ежегодно',
    'de': 'Jährlich',
    'fr': 'Annuel',
    'it': 'Annuale',
    'pt': 'Anual',
    'es': 'Anual',
    'id': 'Tahunan',
    'hi': 'वार्षिक',
    'ja': '年払い',
    'ko': '연간',
  },
  'paywall.per_month': {
    'en': ' / mo',
    'ru': ' / мес',
    'de': ' / Monat',
    'fr': ' / mois',
    'it': ' / mese',
    'pt': ' / mês',
    'es': ' / mes',
    'id': ' / bln',
    'hi': ' / माह',
    'ja': ' / 月',
    'ko': ' / 월',
  },
  'paywall.per_year': {
    'en': ' / yr',
    'ru': ' / год',
    'de': ' / Jahr',
    'fr': ' / an',
    'it': ' / anno',
    'pt': ' / ano',
    'es': ' / año',
    'id': ' / thn',
    'hi': ' / वर्ष',
    'ja': ' / 年',
    'ko': ' / 년',
  },
  // {pct} — процент экономии, подставляется в коде
  'paywall.save_badge': {
    'en': 'save {pct}%',
    'ru': 'экономия {pct}%',
    'de': '{pct}% sparen',
    'fr': 'économise {pct}%',
    'it': 'risparmia {pct}%',
    'pt': 'economize {pct}%',
    'es': 'ahorra {pct}%',
    'id': 'hemat {pct}%',
    'hi': '{pct}% बचाओ',
    'ja': '{pct}%お得',
    'ko': '{pct}% 절약',
  },
  // {price} — месячный эквивалент годовой цены, подставляется в коде
  'paywall.yearly_per_month': {
    'en': '{price} / mo billed yearly',
    'ru': '{price} / мес при оплате за год',
    'de': '{price} / Monat bei Jahreszahlung',
    'fr': '{price} / mois facturé annuellement',
    'it': '{price} / mese fatturato annualmente',
    'pt': '{price} / mês cobrado anualmente',
    'es': '{price} / mes facturado anualmente',
    'id': '{price} / bln ditagih tahunan',
    'hi': '{price} / माह, वार्षिक बिलिंग',
    'ja': '{price} / 月（年払い）',
    'ko': '{price} / 월 연간 청구',
  },

  // Что входит бесплатно (краткая строка под списком функций)
  'paywall.free_includes': {
    'en': 'Free keeps: tasks, streaks, rule-based daily plan, water & diary.',
    'ru': 'Бесплатно: задачи, стрики, правила планирования, вода и дневник.',
    'de': 'Kostenlos: Aufgaben, Serien, regelbasierter Tagesplan, Wasser & Tagebuch.',
    'fr': 'Gratuit inclut : tâches, séries, plan quotidien, eau & journal.',
    'it': 'Gratuito include: attività, serie, piano giornaliero, acqua & diario.',
    'pt': 'Grátis inclui: tarefas, sequências, plano diário, água & diário.',
    'es': 'Gratis incluye: tareas, rachas, plan diario, agua & diario.',
    'id': 'Gratis mencakup: tugas, streak, rencana harian, air & jurnal.',
    'hi': 'मुफ्त में: टास्क, स्ट्रीक, नियम-आधारित प्लान, पानी और डायरी।',
    'ja': '無料プランには：タスク、ストリーク、ルールベースの日次プラン、水分＆日記が含まれます。',
    'ko': '무료 포함: 작업, 연속, 규칙 기반 일일 계획, 물 & 일기.',
  },

  // Основная CTA
  'paywall.cta_start_free': {
    'en': 'Start free',
    'ru': 'Начать бесплатно',
    'de': 'Kostenlos starten',
    'fr': 'Commencer gratuitement',
    'it': 'Inizia gratis',
    'pt': 'Começar grátis',
    'es': 'Empezar gratis',
    'id': 'Mulai gratis',
    'hi': 'मुफ्त शुरू करो',
    'ja': '無料で始める',
    'ko': '무료로 시작하기',
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
    'fr': '{n} jours gratuits, puis {price}. '
        'Tu seras facturé le {date}. '
        'Annule à tout moment dans les Paramètres.',
    'it': '{n} giorni gratis, poi {price}. '
        'Sarai addebitato il {date}. '
        'Annulla in qualsiasi momento nelle Impostazioni.',
    'pt': '{n} dias grátis, depois {price}. '
        'Você será cobrado em {date}. '
        'Cancele a qualquer momento nas Configurações.',
    'es': '{n} días gratis, luego {price}. '
        'Se te cobrará el {date}. '
        'Cancela en cualquier momento en Ajustes.',
    'id': '{n} hari gratis, lalu {price}. '
        'Kamu akan ditagih pada {date}. '
        'Batalkan kapan saja di Pengaturan.',
    'hi': '{n} दिन मुफ्त, फिर {price}। '
        'तुम्हें {date} को चार्ज किया जाएगा। '
        'सेटिंग्स में कभी भी रद्द करो।',
    'ja': '{n}日間無料、その後{price}。'
        '{date}に請求されます。'
        '設定でいつでもキャンセルできます。',
    'ko': '{n}일 무료, 이후 {price}. '
        '{date}에 청구됩니다. '
        '설정에서 언제든지 취소하세요.',
  },

  // Ссылки нижнего ряда
  'paywall.link_terms': {
    'en': 'Terms',
    'ru': 'Условия',
    'de': 'Nutzungsbedingungen',
    'fr': 'CGU',
    'it': 'Termini',
    'pt': 'Termos',
    'es': 'Términos',
    'id': 'Syarat',
    'hi': 'शर्तें',
    'ja': '規約',
    'ko': '약관',
  },
  'paywall.link_privacy': {
    'en': 'Privacy',
    'ru': 'Конфиденциальность',
    'de': 'Datenschutz',
    'fr': 'Confidentialité',
    'it': 'Privacy',
    'pt': 'Privacidade',
    'es': 'Privacidad',
    'id': 'Privasi',
    'hi': 'गोपनीयता',
    'ja': 'プライバシー',
    'ko': '개인정보',
  },

  'paywall.sign_in_hint': {
    'en': 'Sign in to subscribe and sync premium across devices.',
    'ru': 'Войди, чтобы подписаться и синхронизировать Premium на всех устройствах.',
    'de': 'Melde dich an, um zu abonnieren und Premium geräteübergreifend zu synchronisieren.',
    'fr': 'Connecte-toi pour t\'abonner et synchroniser Premium sur tous tes appareils.',
    'it': 'Accedi per abbonarti e sincronizzare Premium su tutti i dispositivi.',
    'pt': 'Faça login para assinar e sincronizar o Premium em todos os dispositivos.',
    'es': 'Inicia sesión para suscribirte y sincronizar Premium en todos tus dispositivos.',
    'id': 'Masuk untuk berlangganan dan sinkronkan Premium di semua perangkat.',
    'hi': 'सभी डिवाइस पर Premium सिंक करने के लिए साइन इन करो और सदस्यता लो।',
    'ja': 'サインインしてサブスクし、すべてのデバイスでPremiumを同期しましょう。',
    'ko': '로그인하여 구독하고 모든 기기에서 Premium을 동기화하세요.',
  },
  'paywall.subscribe': {
    'en': 'Subscribe',
    'ru': 'Подписаться',
    'de': 'Abonnieren',
    'fr': 'S\'abonner',
    'it': 'Abbonati',
    'pt': 'Assinar',
    'es': 'Suscribirse',
    'id': 'Berlangganan',
    'hi': 'सदस्यता लो',
    'ja': '購読する',
    'ko': '구독하기',
  },
  'paywall.restore': {
    'en': 'Restore purchases',
    'ru': 'Восстановить покупки',
    'de': 'Käufe wiederherstellen',
    'fr': 'Restaurer les achats',
    'it': 'Ripristina acquisti',
    'pt': 'Restaurar compras',
    'es': 'Restaurar compras',
    'id': 'Pulihkan pembelian',
    'hi': 'खरीदारी पुनर्स्थापित करो',
    'ja': '購入を復元する',
    'ko': '구매 복원',
  },
  'paywall.cancel_hint': {
    'en': 'Cancel anytime. Free tier keeps tasks, streaks, rule-based plans, water & diary.',
    'ru': 'Отмени в любой момент. Бесплатный план сохраняет задачи, стрики, правила планирования, воду и дневник.',
    'de': 'Jederzeit kündbar. Im Free-Tarif bleiben Aufgaben, Serien, regelbasierte Pläne, Wasser & Tagebuch erhalten.',
    'fr': 'Annule à tout moment. Le plan gratuit garde tâches, séries, plans, eau & journal.',
    'it': 'Annulla in qualsiasi momento. Il piano gratuito mantiene attività, serie, piani, acqua & diario.',
    'pt': 'Cancele a qualquer momento. O plano gratuito mantém tarefas, sequências, planos, água & diário.',
    'es': 'Cancela cuando quieras. El plan gratis mantiene tareas, rachas, planes, agua & diario.',
    'id': 'Batalkan kapan saja. Paket gratis menyimpan tugas, streak, rencana, air & jurnal.',
    'hi': 'कभी भी रद्द करो। मुफ्त प्लान में टास्क, स्ट्रीक, प्लान, पानी और डायरी रहती है।',
    'ja': 'いつでもキャンセル可能。無料プランにはタスク、ストリーク、プラン、水分＆日記が含まれます。',
    'ko': '언제든지 취소 가능. 무료 플랜은 작업, 연속, 플랜, 물 & 일기를 유지합니다.',
  },
  'paywall.welcome_premium': {
    'en': 'Welcome to Premium!',
    'ru': 'Добро пожаловать в Premium!',
    'de': 'Willkommen bei Premium!',
    'fr': 'Bienvenue dans Premium !',
    'it': 'Benvenuto in Premium!',
    'pt': 'Bem-vindo ao Premium!',
    'es': '¡Bienvenido a Premium!',
    'id': 'Selamat datang di Premium!',
    'hi': 'Premium में आपका स्वागत है!',
    'ja': 'Premiumへようこそ！',
    'ko': 'Premium에 오신 것을 환영합니다!',
  },
  'paywall.coming_soon': {
    'en': 'Subscriptions launch soon — payments are coming in the next update.',
    'ru': 'Подписки скоро появятся — оплата будет в следующем обновлении.',
    'de': 'Abonnements kommen bald — Zahlungen folgen im nächsten Update.',
    'fr': 'Les abonnements arrivent bientôt — les paiements seront dans la prochaine mise à jour.',
    'it': 'Gli abbonamenti arrivano presto — i pagamenti saranno nel prossimo aggiornamento.',
    'pt': 'As assinaturas chegam em breve — os pagamentos virão na próxima atualização.',
    'es': 'Las suscripciones llegan pronto — los pagos vienen en la próxima actualización.',
    'id': 'Langganan segera hadir — pembayaran akan ada di pembaruan berikutnya.',
    'hi': 'सदस्यताएं जल्द आ रही हैं — अगले अपडेट में भुगतान आएगा।',
    'ja': 'サブスクはまもなく開始 — 次のアップデートで支払いが追加されます。',
    'ko': '구독이 곧 출시됩니다 — 다음 업데이트에서 결제가 추가됩니다.',
  },
  'paywall.error_generic': {
    'en': 'Something went wrong. Please try again.',
    'ru': 'Что-то пошло не так. Попробуй ещё раз.',
    'de': 'Etwas ist schiefgelaufen. Bitte versuche es erneut.',
    'fr': 'Quelque chose s\'est mal passé. Réessaie.',
    'it': 'Qualcosa è andato storto. Riprova.',
    'pt': 'Algo deu errado. Por favor, tente novamente.',
    'es': 'Algo salió mal. Por favor, inténtalo de nuevo.',
    'id': 'Ada yang salah. Coba lagi.',
    'hi': 'कुछ गलत हो गया। कृपया फिर कोशिश करो।',
    'ja': '問題が発生しました。もう一度お試しください。',
    'ko': '문제가 발생했습니다. 다시 시도해 주세요.',
  },
  'paywall.sign_in_to_subscribe': {
    'en': 'Sign in first to subscribe.',
    'ru': 'Сначала войди, чтобы подписаться.',
    'de': 'Melde dich zuerst an, um zu abonnieren.',
    'fr': 'Connecte-toi d\'abord pour t\'abonner.',
    'it': 'Accedi prima per abbonarti.',
    'pt': 'Faça login primeiro para assinar.',
    'es': 'Inicia sesión primero para suscribirte.',
    'id': 'Masuk dulu untuk berlangganan.',
    'hi': 'सदस्यता लेने के लिए पहले साइन इन करो।',
    'ja': 'まずサインインして購読してください。',
    'ko': '구독하려면 먼저 로그인하세요.',
  },
  'paywall.restored': {
    'en': 'Purchases restored!',
    'ru': 'Покупки восстановлены!',
    'de': 'Käufe wiederhergestellt!',
    'fr': 'Achats restaurés !',
    'it': 'Acquisti ripristinati!',
    'pt': 'Compras restauradas!',
    'es': '¡Compras restauradas!',
    'id': 'Pembelian dipulihkan!',
    'hi': 'खरीदारी पुनर्स्थापित हो गई!',
    'ja': '購入が復元されました！',
    'ko': '구매가 복원되었습니다!',
  },
  'paywall.nothing_to_restore': {
    'en': 'Nothing to restore yet — payments are coming soon.',
    'ru': 'Нечего восстанавливать — оплата появится скоро.',
    'de': 'Noch nichts wiederherzustellen — Zahlungen kommen bald.',
    'fr': 'Rien à restaurer pour l\'instant — les paiements arrivent bientôt.',
    'it': 'Niente da ripristinare ancora — i pagamenti arrivano presto.',
    'pt': 'Nada para restaurar ainda — os pagamentos chegam em breve.',
    'es': 'Nada que restaurar aún — los pagos llegan pronto.',
    'id': 'Belum ada yang perlu dipulihkan — pembayaran segera hadir.',
    'hi': 'अभी पुनर्स्थापित करने के लिए कुछ नहीं — भुगतान जल्द आएगा।',
    'ja': 'まだ復元するものがありません — 支払いはまもなく対応予定です。',
    'ko': '아직 복원할 것이 없습니다 — 결제가 곧 추가됩니다.',
  },
  'paywall.restore_error': {
    'en': 'Could not restore purchases.',
    'ru': 'Не удалось восстановить покупки.',
    'de': 'Käufe konnten nicht wiederhergestellt werden.',
    'fr': 'Impossible de restaurer les achats.',
    'it': 'Impossibile ripristinare gli acquisti.',
    'pt': 'Não foi possível restaurar as compras.',
    'es': 'No se pudieron restaurar las compras.',
    'id': 'Tidak dapat memulihkan pembelian.',
    'hi': 'खरीदारी पुनर्स्थापित नहीं हो सकी।',
    'ja': '購入を復元できませんでした。',
    'ko': '구매를 복원할 수 없습니다.',
  },
  'paywall.upgrade': {
    'en': 'Upgrade',
    'ru': 'Улучшить',
    'de': 'Upgraden',
    'fr': 'Améliorer',
    'it': 'Aggiorna',
    'pt': 'Fazer upgrade',
    'es': 'Mejorar',
    'id': 'Upgrade',
    'hi': 'अपग्रेड करो',
    'ja': 'アップグレード',
    'ko': '업그레이드',
  },

  // ---- Paywall: список premium-функций (обновлён под compliance) ----

  // 1. AI smart reschedule
  'paywall.benefit_reschedule_title': {
    'en': 'AI smart reschedule',
    'ru': 'Умный перенос задач с ИИ',
    'de': 'KI-Neuplanung',
    'fr': 'Reprogrammation intelligente par IA',
    'it': 'Riprogrammazione intelligente con AI',
    'pt': 'Reagendamento inteligente com IA',
    'es': 'Reprogramación inteligente con IA',
    'id': 'Penjadwalan ulang cerdas AI',
    'hi': 'AI स्मार्ट रीशेड्यूल',
    'ja': 'AIスマート再スケジュール',
    'ko': 'AI 스마트 일정 재조정',
  },
  'paywall.benefit_reschedule_subtitle': {
    'en': 'AI rebuilds your day around what matters — morning & evening.',
    'ru': 'ИИ перестраивает твой день вокруг главного — утром и вечером.',
    'de': 'KI baut deinen Tag rund um das Wesentliche neu auf — morgens & abends.',
    'fr': 'L\'IA reconstruit ta journée autour de l\'essentiel — matin & soir.',
    'it': 'L\'AI ricostruisce la tua giornata attorno a ciò che conta — mattina & sera.',
    'pt': 'A IA reconstrói seu dia ao redor do que importa — manhã & noite.',
    'es': 'La IA reconstruye tu día alrededor de lo que importa — mañana & tarde.',
    'id': 'AI membangun ulang harimu di sekitar hal penting — pagi & malam.',
    'hi': 'AI तुम्हारे दिन को जरूरी चीजों के इर्द-गिर्द बनाता है — सुबह और शाम।',
    'ja': 'AIが大切なことを中心に1日を再構築します — 朝と夜。',
    'ko': 'AI가 중요한 것 중심으로 하루를 재구성합니다 — 아침 & 저녁.',
  },

  // 2. AI menu tuned to calories/macros
  'paywall.benefit_menu_title': {
    'en': 'AI menu for your goals',
    'ru': 'ИИ-меню под твои цели',
    'de': 'KI-Menü für deine Ziele',
    'fr': 'Menu IA pour tes objectifs',
    'it': 'Menu AI per i tuoi obiettivi',
    'pt': 'Menu IA para suas metas',
    'es': 'Menú IA para tus metas',
    'id': 'Menu AI untuk tujuanmu',
    'hi': 'तुम्हारे लक्ष्यों के लिए AI मेनू',
    'ja': 'あなたの目標に合ったAIメニュー',
    'ko': '목표에 맞는 AI 메뉴',
  },
  'paywall.benefit_menu_subtitle': {
    'en': 'Meal plans tuned to your calorie and macro targets.',
    'ru': 'Меню, подобранное под твои калории и КБЖУ.',
    'de': 'Mahlzeitenpläne abgestimmt auf Kalorien- und Makroziele.',
    'fr': 'Plans de repas adaptés à tes objectifs caloriques et en macros.',
    'it': 'Piani pasto calibrati sulle tue calorie e macro.',
    'pt': 'Planos alimentares ajustados às suas metas calóricas e de macros.',
    'es': 'Planes de comidas ajustados a tus metas de calorías y macros.',
    'id': 'Rencana makan disesuaikan dengan target kalori dan makromu.',
    'hi': 'तुम्हारी कैलोरी और मैक्रो लक्ष्यों के अनुसार भोजन योजना।',
    'ja': 'カロリーとマクロの目標に合わせた食事プラン。',
    'ko': '칼로리 및 매크로 목표에 맞춘 식단 계획.',
  },

  // 3. Photo recognition (food + schedule)
  'paywall.benefit_photo_title': {
    'en': 'Photo recognition',
    'ru': 'Распознавание по фото',
    'de': 'Foto-Erkennung',
    'fr': 'Reconnaissance photo',
    'it': 'Riconoscimento foto',
    'pt': 'Reconhecimento de foto',
    'es': 'Reconocimiento por foto',
    'id': 'Pengenalan foto',
    'hi': 'फोटो पहचान',
    'ja': '写真認識',
    'ko': '사진 인식',
  },
  'paywall.benefit_photo_subtitle': {
    'en': 'Snap food or your timetable — AI logs it instantly.',
    'ru': 'Сфотографируй еду или расписание — ИИ добавит всё сам.',
    'de': 'Fotografiere Essen oder Stundenplan — KI erfasst es sofort.',
    'fr': 'Prends en photo la nourriture ou ton emploi du temps — l\'IA l\'enregistre instantanément.',
    'it': 'Fotografa il cibo o il tuo orario — l\'AI lo registra all\'istante.',
    'pt': 'Fotografe comida ou seu horário — a IA registra na hora.',
    'es': 'Fotografía comida o tu horario — la IA lo registra al instante.',
    'id': 'Foto makanan atau jadwalmu — AI langsung mencatatnya.',
    'hi': 'खाना या टाइमटेबल की फोटो लो — AI तुरंत दर्ज करेगा।',
    'ja': '食べ物や時間割を撮るだけ — AIが即座に記録します。',
    'ko': '음식이나 시간표를 찍으면 AI가 즉시 기록합니다.',
  },

  // 4. Voice input
  'paywall.benefit_voice_title': {
    'en': 'Voice input',
    'ru': 'Голосовой ввод',
    'de': 'Spracheingabe',
    'fr': 'Saisie vocale',
    'it': 'Input vocale',
    'pt': 'Entrada por voz',
    'es': 'Entrada por voz',
    'id': 'Input suara',
    'hi': 'आवाज़ इनपुट',
    'ja': '音声入力',
    'ko': '음성 입력',
  },
  'paywall.benefit_voice_subtitle': {
    'en': 'Add tasks and food by speaking — hands-free.',
    'ru': 'Добавляй задачи и еду голосом — без рук.',
    'de': 'Aufgaben und Essen per Sprache hinzufügen — freihändig.',
    'fr': 'Ajoute des tâches et de la nourriture en parlant — mains libres.',
    'it': 'Aggiungi attività e cibo parlando — mani libere.',
    'pt': 'Adicione tarefas e comida falando — sem usar as mãos.',
    'es': 'Agrega tareas y comida hablando — sin usar las manos.',
    'id': 'Tambah tugas dan makanan dengan berbicara — bebas tangan.',
    'hi': 'बोलकर टास्क और खाना जोड़ो — हैंड्स-फ्री।',
    'ja': '話すだけでタスクや食事を追加 — ハンズフリー。',
    'ko': '말하기로 작업과 음식 추가 — 핸즈프리.',
  },

  // 5. AI Wrapped weekly/monthly
  'paywall.benefit_wrapped_title': {
    'en': 'AI Wrapped',
    'ru': 'AI Wrapped',
    'de': 'AI Wrapped',
    'fr': 'AI Wrapped',
    'it': 'AI Wrapped',
    'pt': 'AI Wrapped',
    'es': 'AI Wrapped',
    'id': 'AI Wrapped',
    'hi': 'AI Wrapped',
    'ja': 'AI Wrapped',
    'ko': 'AI Wrapped',
  },
  'paywall.benefit_wrapped_subtitle': {
    'en': 'Weekly & monthly insight: why plans slip and how to fix it.',
    'ru': 'Еженедельный и ежемесячный анализ: почему срываются планы и что делать.',
    'de': 'Wöchentliche & monatliche Auswertung: Warum Pläne scheitern und wie man es behebt.',
    'fr': 'Bilan hebdomadaire & mensuel : pourquoi les plans dérapent et comment y remédier.',
    'it': 'Analisi settimanale & mensile: perché i piani slittano e come rimediare.',
    'pt': 'Análise semanal & mensal: por que os planos falham e como corrigir.',
    'es': 'Análisis semanal & mensual: por qué los planes fallan y cómo solucionarlo.',
    'id': 'Wawasan mingguan & bulanan: mengapa rencana meleset dan cara memperbaikinya.',
    'hi': 'साप्ताहिक और मासिक विश्लेषण: प्लान क्यों फिसलते हैं और कैसे ठीक करें।',
    'ja': '週次・月次インサイト：プランが崩れる理由とその改善策。',
    'ko': '주간 & 월간 인사이트: 계획이 어긋나는 이유와 해결 방법.',
  },

  // Устаревшие ключи (сохранены для обратной совместимости — тест и другие экраны могут ссылаться)
  'paywall.benefit_smarter_title': {
    'en': 'Smarter plans',
    'ru': 'Умнее планировать',
    'de': 'Intelligentere Pläne',
    'fr': 'Plans plus intelligents',
    'it': 'Piani più intelligenti',
    'pt': 'Planos mais inteligentes',
    'es': 'Planes más inteligentes',
    'id': 'Rencana lebih cerdas',
    'hi': 'स्मार्ट प्लान',
    'ja': 'よりスマートなプラン',
    'ko': '더 스마트한 계획',
  },
  'paywall.benefit_smarter_subtitle': {
    'en': 'AI rebuilds your day around what matters — morning & evening.',
    'ru': 'ИИ перестраивает твой день вокруг главного — утром и вечером.',
    'de': 'KI baut deinen Tag rund um das Wesentliche neu auf — morgens & abends.',
    'fr': 'L\'IA reconstruit ta journée autour de l\'essentiel — matin & soir.',
    'it': 'L\'AI ricostruisce la tua giornata attorno a ciò che conta — mattina & sera.',
    'pt': 'A IA reconstrói seu dia ao redor do que importa — manhã & noite.',
    'es': 'La IA reconstruye tu día alrededor de lo que importa — mañana & tarde.',
    'id': 'AI membangun ulang harimu di sekitar hal penting — pagi & malam.',
    'hi': 'AI तुम्हारे दिन को जरूरी चीजों के इर्द-गिर्द बनाता है — सुबह और शाम।',
    'ja': 'AIが大切なことを中心に1日を再構築します — 朝と夜。',
    'ko': 'AI가 중요한 것 중심으로 하루를 재구성합니다 — 아침 & 저녁.',
  },
  'paywall.benefit_tone_title': {
    'en': 'Tone-aware nudges',
    'ru': 'Напоминания в нужном тоне',
    'de': 'Tongerechte Erinnerungen',
    'fr': 'Rappels adaptés au ton',
    'it': 'Promemoria adattati al tono',
    'pt': 'Lembretes com tom adaptado',
    'es': 'Recordatorios con tono adaptado',
    'id': 'Pengingat berbasis nada',
    'hi': 'टोन-अवेयर रिमाइंडर',
    'ja': 'トーン対応のリマインダー',
    'ko': '톤 인식 알림',
  },
  'paywall.benefit_tone_subtitle': {
    'en': 'Gentle or harsh — AI messages that actually land.',
    'ru': 'Мягко или строго — сообщения ИИ, которые действительно работают.',
    'de': 'Sanft oder streng — KI-Nachrichten, die wirklich ankommen.',
    'fr': 'Doux ou sévère — des messages IA qui touchent vraiment.',
    'it': 'Gentile o severo — messaggi AI che colpiscono davvero.',
    'pt': 'Suave ou firme — mensagens de IA que realmente funcionam.',
    'es': 'Suave o estricto — mensajes de IA que realmente impactan.',
    'id': 'Lembut atau tegas — pesan AI yang benar-benar sampai.',
    'hi': 'नरम या सख्त — AI संदेश जो वाकई असर करते हैं।',
    'ja': '穏やかでも厳しくても — 本当に届くAIメッセージ。',
    'ko': '부드럽거나 엄격하거나 — 실제로 효과 있는 AI 메시지.',
  },
  'paywall.benefit_diary_title': {
    'en': 'Deeper diary insights',
    'ru': 'Глубокий анализ дневника',
    'de': 'Tiefere Tagebuch-Einblicke',
    'fr': 'Analyses de journal approfondies',
    'it': 'Analisi diario più profonde',
    'pt': 'Insights mais profundos do diário',
    'es': 'Análisis más profundos del diario',
    'id': 'Wawasan jurnal lebih dalam',
    'hi': 'डायरी की गहरी अंतर्दृष्टि',
    'ja': '日記のより深いインサイト',
    'ko': '더 깊은 일기 인사이트',
  },
  'paywall.benefit_diary_subtitle': {
    'en': 'Understand why plans slip, beyond the free weekly summary.',
    'ru': 'Узнай, почему срываются планы — больше, чем бесплатная недельная сводка.',
    'de': 'Verstehe, warum Pläne scheitern — über die kostenlose Wochenzusammenfassung hinaus.',
    'fr': 'Comprends pourquoi les plans dévient, au-delà du résumé hebdomadaire gratuit.',
    'it': 'Capisci perché i piani slittano, oltre al riepilogo settimanale gratuito.',
    'pt': 'Entenda por que os planos falham, além do resumo semanal gratuito.',
    'es': 'Entiende por qué los planes fallan, más allá del resumen semanal gratis.',
    'id': 'Pahami mengapa rencana meleset, lebih dari ringkasan mingguan gratis.',
    'hi': 'जानो कि प्लान क्यों फिसलते हैं — मुफ्त साप्ताहिक सारांश से आगे।',
    'ja': 'プランが崩れる理由を理解しよう — 無料の週次サマリーを超えて。',
    'ko': '계획이 어긋나는 이유 파악 — 무료 주간 요약 그 이상.',
  },
  'paywall.benefit_noads_title': {
    'en': 'No ads',
    'ru': 'Без рекламы',
    'de': 'Keine Werbung',
    'fr': 'Sans publicités',
    'it': 'Nessuna pubblicità',
    'pt': 'Sem anúncios',
    'es': 'Sin anuncios',
    'id': 'Tanpa iklan',
    'hi': 'विज्ञापन-मुक्त',
    'ja': '広告なし',
    'ko': '광고 없음',
  },
  'paywall.benefit_noads_subtitle': {
    'en': 'Calm, focused, ad-free.',
    'ru': 'Спокойно, сосредоточенно, без рекламы.',
    'de': 'Ruhig, fokussiert, werbefrei.',
    'fr': 'Calme, concentré, sans pub.',
    'it': 'Tranquillo, concentrato, senza pubblicità.',
    'pt': 'Calmo, focado, sem anúncios.',
    'es': 'Tranquilo, enfocado, sin anuncios.',
    'id': 'Tenang, fokus, bebas iklan.',
    'hi': 'शांत, केंद्रित, विज्ञापन-मुक्त।',
    'ja': '穏やか、集中、広告ゼロ。',
    'ko': '조용하고, 집중되고, 광고 없음.',
  },

  // Апселл-снэкбар при обращении к premium-функции.
  // {feature} — название функции, подставляется в коде.
  'paywall.premium_feature_upsell': {
    'en': 'Premium feature — upgrade for {feature}',
    'ru': 'Premium-функция — открой за {feature}',
    'de': 'Premium-Funktion — upgrade für {feature}',
    'fr': 'Fonctionnalité Premium — abonnez-vous pour {feature}',
    'it': 'Funzione Premium — abbonati per {feature}',
    'pt': 'Função Premium — assine para {feature}',
    'es': 'Función Premium — actualiza para {feature}',
    'id': 'Fitur Premium — upgrade untuk {feature}',
    'hi': 'Premium फीचर — {feature} के लिए अपग्रेड करो',
    'ja': 'Premium機能 — {feature}のためにアップグレード',
    'ko': 'Premium 기능 — {feature}을(를) 위해 업그레이드',
  },
};
