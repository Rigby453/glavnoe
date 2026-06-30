// Строки экранов Profile, Terms и Paywall.
// Наполнено агентом локализации. EN + RU обязательны, DE — опционально.
const Map<String, Map<String, String>> profilePaywallStrings = {
  // ---- Profile: заголовки секций (корневое меню + подстраницы) ----
  'profile.section_behavior': {
    'en': 'Behavior',
    'ru': 'Поведение',
    'de': 'Verhalten',
    'fr': 'Comportement',
    'it': 'Comportamento',
    'pt': 'Comportamento',
    'es': 'Comportamiento',
    'id': 'Perilaku',
    'hi': 'व्यवहार',
    'ja': '動作',
    'ko': '동작',
  },
  'profile.section_account': {
    'en': 'Account',
    'ru': 'Аккаунт',
    'de': 'Konto',
    'fr': 'Compte',
    'it': 'Account',
    'pt': 'Conta',
    'es': 'Cuenta',
    'id': 'Akun',
    'hi': 'खाता',
    'ja': 'アカウント',
    'ko': '계정',
  },
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
    'en': 'Give yourself a day off — a freeze will keep your streak intact automatically if you miss today.',
    'ru': 'Дай себе выходной — заморозка сохранит стрик, если пропустишь сегодня.',
    'de': 'Gönne dir einen freien Tag — eine Einfrierung hält deine Serie automatisch aufrecht, wenn du heute aussetzt.',
    'fr': 'Accorde-toi un jour de repos — un gel gardera ta série intacte automatiquement si tu rates aujourd\'hui.',
    'it': 'Prenditi un giorno libero — un blocco manterrà automaticamente la tua serie se salti oggi.',
    'pt': 'Dê-se um dia de folga — um congelamento manterá sua sequência intacta automaticamente se você falhar hoje.',
    'es': 'Date un día libre — una congelación mantendrá tu racha intacta automáticamente si fallas hoy.',
    'id': 'Beri dirimu hari libur — pembekuan akan menjaga streakmu tetap utuh secara otomatis jika kamu melewatkan hari ini.',
    'hi': 'खुद को एक दिन की छुट्टी दो — फ्रीज़ आज चूकने पर तुम्हारी स्ट्रीक को अपने आप बनाए रखेगा।',
    'ja': '休みを取ろう — 今日を逃しても、フリーズがストリークを自動的に維持します。',
    'ko': '하루 쉬어도 괜찮아요 — 오늘 놓쳐도 동결이 연속을 자동으로 유지합니다.',
  },

  // ---- Profile: тема (Kaname v4: day/night/black/calm) ----
  'profile.theme_day': {
    'en': 'Day',
    'ru': 'День',
    'de': 'Tag',
    'fr': 'Jour',
    'it': 'Giorno',
    'pt': 'Dia',
    'es': 'Día',
    'id': 'Siang',
    'hi': 'दिन',
    'ja': 'デイ',
    'ko': '낮',
  },
  'profile.theme_night': {
    'en': 'Night',
    'ru': 'Ночь',
    'de': 'Nacht',
    'fr': 'Nuit',
    'it': 'Notte',
    'pt': 'Noite',
    'es': 'Noche',
    'id': 'Malam',
    'hi': 'रात',
    'ja': 'ナイト',
    'ko': '밤',
  },
  // ---- Profile: тема (устаревшие v3, оставлены для резерва) ----
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

  // ---- Дисклеймер о здоровье ----
  'profile.health_disclaimer_title': {
    'en': 'Health & wellness disclaimer',
    'ru': 'Дисклеймер о здоровье',
    'de': 'Gesundheitshinweis',
    'fr': 'Avertissement santé',
    'it': 'Avviso sulla salute',
    'pt': 'Aviso de saúde',
    'es': 'Aviso de salud',
    'id': 'Pernyataan kesehatan',
    'hi': 'स्वास्थ्य संबंधी अस्वीकरण',
    'ja': '健康に関する免責事項',
    'ko': '건강 고지사항',
  },
  'profile.health_disclaimer_body': {
    'en': 'Kaizen is a productivity and lifestyle app. It is NOT a medical device, healthcare provider, or a substitute for professional advice.\n\n'
        'All health-related features — calorie and macro (КБЖУ) targets, water intake, sleep schedule, workouts, posture, breathing, and any AI suggestions — are for general informational and educational purposes only. The numbers are estimates and general guidance, not personalized medical, nutritional, or fitness advice.\n\n'
        'Always consult a qualified doctor, dietitian, or relevant professional before making decisions about your diet, exercise, sleep, or health — especially if you have a medical condition, are pregnant or nursing, or take medication.\n\n'
        'You use these features at your own risk. We are not liable for any outcomes resulting from reliance on the app\'s suggestions.',
    'ru': 'Kaizen — это приложение для продуктивности и образа жизни. Оно НЕ является медицинским устройством, поставщиком медицинских услуг или заменой профессиональной консультации.\n\n'
        'Все функции, связанные со здоровьем, — цели по калориям и КБЖУ, потребление воды, режим сна, тренировки, осанка, дыхание и любые подсказки ИИ — носят исключительно общий информационный и образовательный характер. Приведённые цифры являются оценками и общими ориентирами, а не персональными медицинскими, нутрициологическими или спортивными рекомендациями.\n\n'
        'Перед принятием решений о диете, физических нагрузках, сне или здоровье всегда консультируйся с квалифицированным врачом, диетологом или специалистом — особенно при наличии заболеваний, беременности, кормлении грудью или приёме лекарств.\n\n'
        'Ты используешь эти функции на свой страх и риск. Мы не несём ответственности за последствия, возникшие в результате следования рекомендациям приложения.',
    'de': 'Kaizen ist eine Produktivitäts- und Lifestyle-App. Sie ist KEIN Medizinprodukt, kein Gesundheitsdienstleister und kein Ersatz für professionellen Rat.\n\n'
        'Alle gesundheitsbezogenen Funktionen — Kalorien- und Makronährstoffziele, Wasseraufnahme, Schlafplan, Workouts, Haltung, Atmung und KI-Vorschläge — dienen ausschließlich allgemeinen Informations- und Bildungszwecken. Die Zahlen sind Schätzungen und allgemeine Richtwerte, keine personalisierten medizinischen, ernährungsbezogenen oder sportlichen Empfehlungen.\n\n'
        'Konsultiere immer einen qualifizierten Arzt, Ernährungsberater oder relevanten Fachmann, bevor du Entscheidungen über deine Ernährung, Bewegung, deinen Schlaf oder deine Gesundheit triffst — insbesondere wenn du eine Erkrankung hast, schwanger bist, stillst oder Medikamente nimmst.\n\n'
        'Du nutzt diese Funktionen auf eigenes Risiko. Wir haften nicht für Ergebnisse, die aus dem Vertrauen auf die Vorschläge der App entstehen.',
    'fr': 'Kaizen est une application de productivité et de style de vie. Elle N\'EST PAS un dispositif médical, un prestataire de soins de santé ni un substitut à un avis professionnel.\n\n'
        'Toutes les fonctionnalités liées à la santé — objectifs caloriques et en macronutriments, apport en eau, programme de sommeil, entraînements, posture, respiration et suggestions de l\'IA — sont fournies à des fins d\'information générale et d\'éducation uniquement. Les chiffres sont des estimations et des conseils généraux, non des conseils médicaux, nutritionnels ou sportifs personnalisés.\n\n'
        'Consulte toujours un médecin qualifié, un diététicien ou un professionnel compétent avant de prendre des décisions concernant ton alimentation, ton exercice, ton sommeil ou ta santé — surtout si tu as une condition médicale, si tu es enceinte ou si tu allaitez, ou si tu prends des médicaments.\n\n'
        'Tu utilises ces fonctionnalités à tes propres risques. Nous ne sommes pas responsables des résultats découlant de la confiance accordée aux suggestions de l\'application.',
    'it': 'Kaizen è un\'app di produttività e stile di vita. NON è un dispositivo medico, un fornitore di assistenza sanitaria o un sostituto della consulenza professionale.\n\n'
        'Tutte le funzioni relative alla salute — obiettivi calorici e di macronutrienti, apporto idrico, programma del sonno, allenamenti, postura, respirazione e suggerimenti dell\'IA — sono fornite a soli scopi informativi e educativi generali. I numeri sono stime e linee guida generali, non consigli medici, nutrizionali o di fitness personalizzati.\n\n'
        'Consulta sempre un medico qualificato, un dietologo o un professionista competente prima di prendere decisioni riguardo a dieta, esercizio fisico, sonno o salute — soprattutto se hai una condizione medica, sei incinta o stai allattando, o assumi farmaci.\n\n'
        'Utilizzi queste funzioni a tuo rischio. Non siamo responsabili per eventuali conseguenze derivanti dall\'affidamento ai suggerimenti dell\'app.',
    'pt': 'Kaizen é um app de produtividade e estilo de vida. NÃO é um dispositivo médico, prestador de serviços de saúde ou substituto para orientação profissional.\n\n'
        'Todos os recursos relacionados à saúde — metas de calorias e macros, ingestão de água, horário de sono, treinos, postura, respiração e sugestões de IA — são apenas para fins informativos e educacionais gerais. Os números são estimativas e orientações gerais, não conselhos médicos, nutricionais ou de condicionamento personalizados.\n\n'
        'Consulte sempre um médico qualificado, nutricionista ou profissional relevante antes de tomar decisões sobre dieta, exercício, sono ou saúde — especialmente se tiver uma condição médica, estiver grávida ou amamentando, ou tomar medicamentos.\n\n'
        'Você usa esses recursos por sua própria conta e risco. Não somos responsáveis por quaisquer resultados decorrentes da confiança nas sugestões do app.',
    'es': 'Kaizen es una app de productividad y estilo de vida. NO es un dispositivo médico, proveedor de atención médica ni sustituto del asesoramiento profesional.\n\n'
        'Todas las funciones relacionadas con la salud — objetivos de calorías y macros, ingesta de agua, horario de sueño, entrenamientos, postura, respiración y sugerencias de IA — son únicamente para fines informativos y educativos generales. Los números son estimaciones y orientación general, no consejos médicos, nutricionales o de acondicionamiento personalizados.\n\n'
        'Consulta siempre a un médico calificado, dietista o profesional relevante antes de tomar decisiones sobre tu dieta, ejercicio, sueño o salud — especialmente si tienes una condición médica, estás embarazada o en período de lactancia, o tomas medicación.\n\n'
        'Usas estas funciones bajo tu propio riesgo. No somos responsables de ningún resultado derivado de confiar en las sugerencias de la app.',
    'id': 'Kaizen adalah app produktivitas dan gaya hidup. App ini BUKAN perangkat medis, penyedia layanan kesehatan, atau pengganti saran profesional.\n\n'
        'Semua fitur terkait kesehatan — target kalori dan makro, asupan air, jadwal tidur, olahraga, postur, pernapasan, dan saran AI — hanya untuk tujuan informasi dan edukasi umum. Angka-angka tersebut adalah estimasi dan panduan umum, bukan saran medis, nutrisi, atau kebugaran yang dipersonalisasi.\n\n'
        'Selalu konsultasikan dengan dokter, ahli gizi, atau profesional terkait sebelum membuat keputusan tentang diet, olahraga, tidur, atau kesehatan — terutama jika kamu memiliki kondisi medis, sedang hamil atau menyusui, atau mengonsumsi obat-obatan.\n\n'
        'Kamu menggunakan fitur-fitur ini dengan risiko sendiri. Kami tidak bertanggung jawab atas hasil apa pun yang timbul dari ketergantungan pada saran app.',
    'hi': 'Kaizen एक प्रोडक्टिविटी और लाइफस्टाइल ऐप है। यह कोई मेडिकल डिवाइस, स्वास्थ्य सेवा प्रदाता या पेशेवर सलाह का विकल्प नहीं है।\n\n'
        'सभी स्वास्थ्य-संबंधी फीचर — कैलोरी और मैक्रो (КБЖУ) लक्ष्य, पानी का सेवन, नींद का शेड्यूल, वर्कआउट, पॉस्चर, श्वास और AI सुझाव — केवल सामान्य जानकारी और शैक्षिक उद्देश्यों के लिए हैं। संख्याएं अनुमान और सामान्य मार्गदर्शन हैं, न कि व्यक्तिगत चिकित्सा, पोषण या फिटनेस सलाह।\n\n'
        'आहार, व्यायाम, नींद या स्वास्थ्य के बारे में निर्णय लेने से पहले हमेशा किसी योग्य डॉक्टर, आहार विशेषज्ञ या संबंधित पेशेवर से परामर्श करो — विशेष रूप से यदि तुम्हें कोई चिकित्सीय स्थिति है, गर्भावस्था या स्तनपान है, या दवाएं लेते हो।\n\n'
        'तुम इन फीचर का उपयोग अपनी जोखिम पर करते हो। ऐप के सुझावों पर निर्भरता से होने वाले किसी भी परिणाम के लिए हम उत्तरदायी नहीं हैं।',
    'ja': 'Kaizenは生産性とライフスタイルのアプリです。医療機器、医療サービス提供者、または専門家のアドバイスの代替ではありません。\n\n'
        'カロリー・マクロ栄養素の目標、水分摂取、睡眠スケジュール、ワークアウト、姿勢、呼吸、AIの提案など、健康に関連するすべての機能は、一般的な情報提供および教育目的のみのものです。表示される数値は推定値と一般的な目安であり、個別の医療・栄養・フィットネスアドバイスではありません。\n\n'
        '食事、運動、睡眠、または健康に関する決定を行う前に、必ず資格を持つ医師、管理栄養士、または関連する専門家に相談してください。特に、持病がある場合、妊娠中または授乳中の場合、薬を服用している場合は必ずご相談ください。\n\n'
        'これらの機能はご自身の責任においてご使用ください。アプリの提案を参考にした結果生じたいかなる損害についても、当社は責任を負いません。',
    'ko': 'Kaizen은 생산성 및 라이프스타일 앱입니다. 의료 기기, 의료 서비스 제공자 또는 전문적인 조언을 대체하지 않습니다.\n\n'
        '칼로리 및 영양소 목표, 수분 섭취, 수면 일정, 운동, 자세, 호흡, AI 제안 등 모든 건강 관련 기능은 일반적인 정보 제공 및 교육 목적으로만 제공됩니다. 제시된 수치는 추정값과 일반적인 지침으로, 개인화된 의료, 영양 또는 피트니스 조언이 아닙니다.\n\n'
        '식이요법, 운동, 수면 또는 건강에 관한 결정을 내리기 전에 자격을 갖춘 의사, 영양사 또는 관련 전문가와 반드시 상담하세요. 특히 의학적 질환이 있거나, 임신 중이거나 수유 중이거나, 약을 복용하는 경우에는 더욱 중요합니다.\n\n'
        '이러한 기능은 사용자 본인의 책임 하에 사용됩니다. 앱의 제안에 의존하여 발생한 결과에 대해 당사는 책임을 지지 않습니다.',
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

  // ---------------------------------------------------------------------------
  // Freeze accrual — заморозки стрика (начисление + награды)
  // ---------------------------------------------------------------------------

  // Заголовок секции заморозок в карточке стрика.
  'streak.freeze_progress_label': {
    'en': 'Freeze progress',
    'ru': 'Прогресс заморозок',
    'de': 'Einfrierungsfortschritt',
    'fr': 'Progression des gels',
    'it': 'Progresso blocchi',
    'pt': 'Progresso de congelamentos',
    'es': 'Progreso de congelaciones',
    'id': 'Progres pembekuan',
    'hi': 'फ्रीज़ प्रगति',
    'ja': 'フリーズ進捗',
    'ko': '동결 진행',
  },

  // Прогресс к ближайшей награде. {current}/{target} — числа, {reward} — награда.
  'streak.freeze_progress_to_reward': {
    'en': '{current}/{target} — {reward}',
    'ru': '{current}/{target} — {reward}',
    'de': '{current}/{target} — {reward}',
    'fr': '{current}/{target} — {reward}',
    'it': '{current}/{target} — {reward}',
    'pt': '{current}/{target} — {reward}',
    'es': '{current}/{target} — {reward}',
    'id': '{current}/{target} — {reward}',
    'hi': '{current}/{target} — {reward}',
    'ja': '{current}/{target} — {reward}',
    'ko': '{current}/{target} — {reward}',
  },

  // Описание награды за 10 заморозок.
  'streak.freeze_reward_10': {
    'en': '1 week Premium',
    'ru': '1 неделя Premium',
    'de': '1 Woche Premium',
    'fr': '1 semaine Premium',
    'it': '1 settimana Premium',
    'pt': '1 semana Premium',
    'es': '1 semana Premium',
    'id': '1 minggu Premium',
    'hi': '1 हफ्ते Premium',
    'ja': '1週間のプレミアム',
    'ko': '1주 프리미엄',
  },

  // Описание награды за 25 заморозок.
  'streak.freeze_reward_25': {
    'en': '1 month Premium',
    'ru': '1 месяц Premium',
    'de': '1 Monat Premium',
    'fr': '1 mois Premium',
    'it': '1 mese Premium',
    'pt': '1 mês Premium',
    'es': '1 mes Premium',
    'id': '1 bulan Premium',
    'hi': '1 महीने Premium',
    'ja': '1ヶ月のプレミアム',
    'ko': '1개월 프리미엄',
  },

  // Описание награды за 50 заморозок.
  'streak.freeze_reward_50': {
    'en': '3 months Premium',
    'ru': '3 месяца Premium',
    'de': '3 Monate Premium',
    'fr': '3 mois Premium',
    'it': '3 mesi Premium',
    'pt': '3 meses Premium',
    'es': '3 meses Premium',
    'id': '3 bulan Premium',
    'hi': '3 महीने Premium',
    'ja': '3ヶ月のプレミアム',
    'ko': '3개월 프리미엄',
  },

  // Все пороги достигнуты.
  'streak.freeze_reward_all_claimed': {
    'en': 'All rewards collected!',
    'ru': 'Все награды получены!',
    'de': 'Alle Belohnungen erhalten!',
    'fr': 'Toutes les récompenses obtenues !',
    'it': 'Tutti i premi riscattati!',
    'pt': 'Todas as recompensas coletadas!',
    'es': '¡Todas las recompensas recibidas!',
    'id': 'Semua hadiah terkumpul!',
    'hi': 'सभी पुरस्कार मिल गए!',
    'ja': '全報酬を獲得しました！',
    'ko': '모든 보상 획득!',
  },

  // Снэкбар при начислении новой заморозки. {n} — количество.
  'streak.freeze_accrued': {
    'en': '+{n} freeze accrued',
    'ru': '+{n} заморозка начислена',
    'de': '+{n} Einfrierung gutgeschrieben',
    'fr': '+{n} gel crédité',
    'it': '+{n} blocco accreditato',
    'pt': '+{n} congelamento creditado',
    'es': '+{n} congelación acreditada',
    'id': '+{n} pembekuan dikreditkan',
    'hi': '+{n} फ्रीज़ जमा हुई',
    'ja': '+{n}フリーズ付与',
    'ko': '+{n} 동결 적립',
  },

  // Снэкбар при множественном начислении. {n} — количество.
  'streak.freezes_accrued': {
    'en': '+{n} freezes accrued',
    'ru': '+{n} заморозок начислено',
    'de': '+{n} Einfrierungen gutgeschrieben',
    'fr': '+{n} gels crédités',
    'it': '+{n} blocchi accreditati',
    'pt': '+{n} congelamentos creditados',
    'es': '+{n} congelaciones acreditadas',
    'id': '+{n} pembekuan dikreditkan',
    'hi': '+{n} फ्रीज़ जमा हुई',
    'ja': '+{n}フリーズ付与',
    'ko': '+{n} 동결 적립',
  },

  // Снэкбар при получении награды за накопление. {reward} — описание, напр. «1 неделя Premium».
  'streak.freeze_reward_granted': {
    'en': 'Reward unlocked: {reward}',
    'ru': 'Награда получена: {reward}',
    'de': 'Belohnung freigeschaltet: {reward}',
    'fr': 'Récompense débloquée : {reward}',
    'it': 'Premio sbloccato: {reward}',
    'pt': 'Recompensa desbloqueada: {reward}',
    'es': '¡Recompensa desbloqueada: {reward}!',
    'id': 'Hadiah dibuka: {reward}',
    'hi': 'पुरस्कार मिला: {reward}',
    'ja': '報酬獲得: {reward}',
    'ko': '보상 획득: {reward}',
  },

  // Бонус при покупке Premium (+2 заморозки).
  'streak.freeze_purchase_bonus': {
    'en': '+2 bonus freezes for going Premium!',
    'ru': '+2 заморозки в подарок за Premium!',
    'de': '+2 Bonus-Einfrierungen fürs Premium!',
    'fr': '+2 gels bonus pour être passé Premium !',
    'it': '+2 blocchi bonus per il Premium!',
    'pt': '+2 congelamentos de bônus pelo Premium!',
    'es': '+2 congelaciones de bonificación por Premium!',
    'id': '+2 pembekuan bonus untuk Premium!',
    'hi': 'Premium लेने पर +2 बोनस फ्रीज़!',
    'ja': 'プレミアム登録で+2フリーズボーナス！',
    'ko': 'Premium 전환 보너스 +2 동결!',
  },

  // ---- Kai — упрощённая секция (только показ и тон) ----
  // Новые ключи для компактного _KaiSettingsSection (заменил громоздкий «Mood & Kai» пульт).
  'profile.section_kai': {
    'en': 'Kai',
    'ru': 'Kai',
    'de': 'Kai',
    'fr': 'Kai',
    'it': 'Kai',
    'pt': 'Kai',
    'es': 'Kai',
    'id': 'Kai',
    'hi': 'Kai',
    'ja': 'Kai',
    'ko': 'Kai',
  },
  'profile.kai_tone': {
    'en': 'Tone',
    'ru': 'Тон',
    'de': 'Ton',
    'fr': 'Ton',
    'it': 'Tono',
    'pt': 'Tom',
    'es': 'Tono',
    'id': 'Nada',
    'hi': 'लहजा',
    'ja': 'トーン',
    'ko': '말투',
  },
  'profile.kai_tone_subtitle': {
    'en': 'How Kai talks to you',
    'ru': 'Как Kai с тобой общается',
    'de': 'Wie Kai mit dir spricht',
    'fr': 'Comment Kai te parle',
    'it': 'Come Kai ti parla',
    'pt': 'Como Kai fala com você',
    'es': 'Cómo te habla Kai',
    'id': 'Bagaimana Kai berbicara padamu',
    'hi': 'Kai तुमसे कैसे बात करता है',
    'ja': 'Kaiがあなたに話しかける方法',
    'ko': 'Kai가 당신에게 말하는 방식',
  },

  // ---- Mood & Kai — устаревшая секция пульта (ключи сохранены для совместимости) ----
  'profile.section_mood_kai': {
    'en': 'Mood & Kai',
    'ru': 'Настрой и Kai',
    'de': 'Stimmung & Kai',
    'fr': 'Humeur & Kai',
    'it': 'Umore & Kai',
    'pt': 'Humor & Kai',
    'es': 'Estado de ánimo y Kai',
    'id': 'Suasana Hati & Kai',
    'hi': 'मूड और Kai',
    'ja': 'ムード＆Kai',
    'ko': '분위기 & Kai',
  },

  // Пресет «Спокойный»
  'mood.preset_calm': {
    'en': 'Calm',
    'ru': 'Спокойный',
    'de': 'Ruhig',
    'fr': 'Calme',
    'it': 'Calmo',
    'pt': 'Calmo',
    'es': 'Tranquilo',
    'id': 'Tenang',
    'hi': 'शांत',
    'ja': '穏やか',
    'ko': '평온',
  },
  'mood.preset_calm_subtitle': {
    'en': 'Gentle tone, no reaction to laziness',
    'ru': 'Мягкий тон, без реакции на лень',
    'de': 'Sanfter Ton, keine Reaktion auf Faulheit',
    'fr': 'Ton doux, sans réaction à la paresse',
    'it': 'Tono gentile, nessuna reazione alla pigrizia',
    'pt': 'Tom gentil, sem reação à preguiça',
    'es': 'Tono suave, sin reacción a la pereza',
    'id': 'Nada lembut, tidak bereaksi terhadap kemalasan',
    'hi': 'नरम लहजा, आलस पर कोई प्रतिक्रिया नहीं',
    'ja': '穏やかなトーン、怠惰に反応しない',
    'ko': '부드러운 어조, 게으름에 반응 없음',
  },

  // Пресет «Обычный»
  'mood.preset_normal': {
    'en': 'Normal',
    'ru': 'Обычный',
    'de': 'Normal',
    'fr': 'Normal',
    'it': 'Normale',
    'pt': 'Normal',
    'es': 'Normal',
    'id': 'Normal',
    'hi': 'सामान्य',
    'ja': '普通',
    'ko': '보통',
  },
  'mood.preset_normal_subtitle': {
    'en': 'Gentle tone, slight reaction to laziness',
    'ru': 'Мягкий тон, слабая реакция на лень',
    'de': 'Sanfter Ton, leichte Reaktion auf Faulheit',
    'fr': 'Ton doux, légère réaction à la paresse',
    'it': 'Tono gentile, lieve reazione alla pigrizia',
    'pt': 'Tom gentil, leve reação à preguiça',
    'es': 'Tono suave, leve reacción a la pereza',
    'id': 'Nada lembut, sedikit bereaksi terhadap kemalasan',
    'hi': 'नरम लहजा, आलस पर हल्की प्रतिक्रिया',
    'ja': '穏やかなトーン、怠惰に少し反応',
    'ko': '부드러운 어조, 게으름에 약간 반응',
  },

  // Пресет «Жёсткий тренер»
  'mood.preset_coach': {
    'en': 'Strict Coach',
    'ru': 'Жёсткий тренер',
    'de': 'Strenger Coach',
    'fr': 'Coach strict',
    'it': 'Coach severo',
    'pt': 'Técnico rigoroso',
    'es': 'Entrenador estricto',
    'id': 'Pelatih tegas',
    'hi': 'सख्त कोच',
    'ja': '厳しいコーチ',
    'ko': '엄격한 코치',
  },
  'mood.preset_coach_subtitle': {
    'en': 'Harsh tone, full reaction to laziness',
    'ru': 'Жёсткий тон, полная реакция на лень',
    'de': 'Harter Ton, volle Reaktion auf Faulheit',
    'fr': 'Ton sévère, réaction complète à la paresse',
    'it': 'Tono duro, piena reazione alla pigrizia',
    'pt': 'Tom rigoroso, reação total à preguiça',
    'es': 'Tono duro, reacción completa a la pereza',
    'id': 'Nada keras, reaksi penuh terhadap kemalasan',
    'hi': 'कठोर लहजा, आलस पर पूरी प्रतिक्रिया',
    'ja': '厳しいトーン、怠惰に完全に反応',
    'ko': '엄격한 어조, 게으름에 완전히 반응',
  },

  // Производный пресет «Своё» — индикатор нестандартной комбинации осей (§2.5 ТЗ).
  // Тап по нему — no-op; пользователь меняет оси тонкими контролами ниже.
  'mood.preset_custom': {
    'en': 'Custom',
    'ru': 'Своё',
    'de': 'Eigenes',
    'fr': 'Perso',
    'it': 'Mio',
    'pt': 'Meu',
    'es': 'Mío',
    'id': 'Kustom',
    'hi': 'अपना',
    'ja': 'カスタム',
    'ko': '내 설정',
  },
  'mood.preset_custom_subtitle': {
    'en': 'Your mix',
    'ru': 'Свой набор',
    'de': 'Dein Mix',
    'fr': 'Ton mix',
    'it': 'Il tuo mix',
    'pt': 'Seu mix',
    'es': 'Tu mezcla',
    'id': 'Mixmu',
    'hi': 'तुम्हारा मिश्रण',
    'ja': 'あなたのミックス',
    'ko': '나만의 조합',
  },

  // Тонкая настройка
  'mood.fine_tuning': {
    'en': 'Fine Tuning',
    'ru': 'Тонкая настройка',
    'de': 'Feineinstellung',
    'fr': 'Réglage fin',
    'it': 'Regolazione fine',
    'pt': 'Ajuste fino',
    'es': 'Ajuste fino',
    'id': 'Penyetelan halus',
    'hi': 'फाइन ट्यूनिंग',
    'ja': '微調整',
    'ko': '세밀 조정',
  },

  // Подпись оси напора (§2.3 ТЗ): убрали слово «лень» — заменили на нейтральное
  // «Как часто Каи подсказывает», чтобы не клеймить пользователя.
  'mood.reaction_to_laziness': {
    'en': 'How often Kai nudges',
    'ru': 'Как часто Каи подсказывает',
    'de': 'Wie oft Kai erinnert',
    'fr': 'Fréquence des rappels Kai',
    'it': 'Quanto spesso Kai ricorda',
    'pt': 'Com que frequência Kai lembra',
    'es': 'Con qué frecuencia Kai recuerda',
    'id': 'Seberapa sering Kai mengingatkan',
    'hi': 'Kai कितनी बार सुझाव देता है',
    'ja': 'Kaiがどのくらい促すか',
    'ko': 'Kai가 얼마나 자주 알려주는지',
  },

  // Метки интенсивности
  'mood.intensity_off': {
    'en': 'Off',
    'ru': 'Выкл',
    'de': 'Aus',
    'fr': 'Désact.',
    'it': 'Off',
    'pt': 'Desl.',
    'es': 'Desact.',
    'id': 'Mati',
    'hi': 'बंद',
    'ja': 'オフ',
    'ko': '끄기',
  },
  'mood.intensity_slight': {
    'en': 'Slight',
    'ru': 'Слегка',
    'de': 'Leicht',
    'fr': 'Léger',
    'it': 'Leggero',
    'pt': 'Leve',
    'es': 'Leve',
    'id': 'Sedikit',
    'hi': 'हल्का',
    'ja': '少し',
    'ko': '약간',
  },
  'mood.intensity_full': {
    'en': 'Full',
    'ru': 'Полная',
    'de': 'Voll',
    'fr': 'Complet',
    'it': 'Pieno',
    'pt': 'Total',
    'es': 'Completo',
    'id': 'Penuh',
    'hi': 'पूरी',
    'ja': '完全',
    'ko': '최대',
  },

  // --- Живое превью тона в Профиле: образец фразы Kai ---
  // gentle — поддерживающая, мягкая; harsh — короткая, требовательная.
  'kai.preview_gentle': {
    'en': 'Two tasks left — let’s take them one at a time. You’ve got this.',
    'ru': 'Осталось две задачи — давай по одной, спокойно. У тебя получится.',
    'de': 'Noch zwei Aufgaben — eine nach der anderen. Du schaffst das.',
    'fr': 'Deux tâches restantes — une à la fois. Tu vas y arriver.',
    'it': 'Due compiti rimasti — uno alla volta. Ce la fai.',
    'pt': 'Faltam duas tarefas — uma de cada vez. Você consegue.',
    'es': 'Quedan dos tareas — una a la vez. Tú puedes.',
    'id': 'Tersisa dua tugas — satu per satu. Kamu pasti bisa.',
    'hi': 'दो काम बचे हैं — एक-एक करके करो। तुम कर सकते हो।',
    'ja': 'あと2つ。ひとつずつ、落ち着いていこう。大丈夫。',
    'ko': '두 개 남았어요. 하나씩, 천천히. 할 수 있어요.',
  },
  'kai.preview_harsh': {
    'en': 'Two left. No excuses. Finish them now.',
    'ru': 'Осталось две. Без отговорок. Доделай сейчас.',
    'de': 'Noch zwei. Keine Ausreden. Mach sie jetzt fertig.',
    'fr': 'Deux restantes. Aucune excuse. Termine maintenant.',
    'it': 'Due rimaste. Niente scuse. Finiscile ora.',
    'pt': 'Faltam duas. Sem desculpas. Termine agora.',
    'es': 'Quedan dos. Sin excusas. Termínalas ya.',
    'id': 'Sisa dua. Tanpa alasan. Selesaikan sekarang.',
    'hi': 'दो बचे। कोई बहाना नहीं। अभी पूरा करो।',
    'ja': '残り2つ。言い訳は無し。今すぐ終わらせろ。',
    'ko': '두 개 남았어. 변명 금지. 지금 끝내.',
  },

  // Однословный «вайб» тона для бейджа превью.
  'kai.vibe_gentle': {
    'en': 'Supportive',
    'ru': 'Поддержка',
    'de': 'Unterstützend',
    'fr': 'Bienveillant',
    'it': 'Di supporto',
    'pt': 'Acolhedor',
    'es': 'De apoyo',
    'id': 'Mendukung',
    'hi': 'सहायक',
    'ja': '寄り添う',
    'ko': '응원',
  },
  'kai.vibe_harsh': {
    'en': 'No-excuses',
    'ru': 'Без отговорок',
    'de': 'Keine Ausreden',
    'fr': 'Sans excuses',
    'it': 'Senza scuse',
    'pt': 'Sem desculpas',
    'es': 'Sin excusas',
    'id': 'Tanpa alasan',
    'hi': 'बहाने नहीं',
    'ja': '言い訳なし',
    'ko': '변명 금지',
  },

  // ---------------------------------------------------------------------------
  // Profile: секция «Задачи по умолчанию» (task defaults)
  // ---------------------------------------------------------------------------
  'profile.section_task_defaults': {
    'en': 'Task defaults',
    'ru': 'Задачи по умолчанию',
    'de': 'Aufgaben-Standards',
    'fr': 'Valeurs par défaut des tâches',
    'it': 'Predefiniti delle attività',
    'pt': 'Padrões de tarefas',
    'es': 'Valores por defecto de tareas',
    'id': 'Bawaan tugas',
    'hi': 'कार्य डिफ़ॉल्ट',
    'ja': 'タスクの初期設定',
    'ko': '작업 기본값',
  },
  'profile.task_defaults_note': {
    'en': 'Defaults applied when you create a new task.',
    'ru': 'Применяются при создании новой задачи.',
    'de': 'Werden beim Erstellen einer neuen Aufgabe angewendet.',
    'fr': 'Appliqués lors de la création d’une nouvelle tâche.',
    'it': 'Applicati quando crei una nuova attività.',
    'pt': 'Aplicados ao criar uma nova tarefa.',
    'es': 'Se aplican al crear una nueva tarea.',
    'id': 'Diterapkan saat kamu membuat tugas baru.',
    'hi': 'नया कार्य बनाते समय लागू होते हैं।',
    'ja': '新しいタスクを作成するときに適用されます。',
    'ko': '새 작업을 만들 때 적용됩니다.',
  },

  // ---- Напоминание по умолчанию ----
  'profile.reminder_default_label': {
    'en': 'Default reminder',
    'ru': 'Напоминание по умолчанию',
    'de': 'Standard-Erinnerung',
    'fr': 'Rappel par défaut',
    'it': 'Promemoria predefinito',
    'pt': 'Lembrete padrão',
    'es': 'Recordatorio por defecto',
    'id': 'Pengingat bawaan',
    'hi': 'डिफ़ॉल्ट रिमाइंडर',
    'ja': 'デフォルトのリマインダー',
    'ko': '기본 알림',
  },
  'profile.reminder_mode_none': {
    'en': 'None',
    'ru': 'Нет',
    'de': 'Keine',
    'fr': 'Aucun',
    'it': 'Nessuno',
    'pt': 'Nenhum',
    'es': 'Ninguno',
    'id': 'Tidak ada',
    'hi': 'कोई नहीं',
    'ja': 'なし',
    'ko': '없음',
  },
  'profile.reminder_mode_main': {
    'en': 'Focus only',
    'ru': 'Только фокус',
    'de': 'Nur Fokus',
    'fr': 'Focus seulement',
    'it': 'Solo focus',
    'pt': 'Só foco',
    'es': 'Solo enfoque',
    'id': 'Hanya fokus',
    'hi': 'केवल फ़ोकस',
    'ja': 'フォーカスのみ',
    'ko': '포커스만',
  },
  'profile.reminder_mode_all': {
    'en': 'All tasks',
    'ru': 'Все задачи',
    'de': 'Alle Aufgaben',
    'fr': 'Toutes les tâches',
    'it': 'Tutte le attività',
    'pt': 'Todas as tarefas',
    'es': 'Todas las tareas',
    'id': 'Semua tugas',
    'hi': 'सभी कार्य',
    'ja': 'すべてのタスク',
    'ko': '모든 작업',
  },
  'profile.reminder_when_label': {
    'en': 'Remind before',
    'ru': 'Напомнить за',
    'de': 'Erinnern vorher',
    'fr': 'Rappeler avant',
    'it': 'Avvisa prima',
    'pt': 'Lembrar antes',
    'es': 'Avisar antes',
    'id': 'Ingatkan sebelum',
    'hi': 'पहले याद दिलाएं',
    'ja': '事前に通知',
    'ko': '미리 알림',
  },

  // ---- Пресеты длительности / напоминаний ----
  'profile.duration_presets_label': {
    'en': 'Duration presets',
    'ru': 'Пресеты длительности',
    'de': 'Dauer-Voreinstellungen',
    'fr': 'Préréglages de durée',
    'it': 'Preset di durata',
    'pt': 'Predefinições de duração',
    'es': 'Preajustes de duración',
    'id': 'Preset durasi',
    'hi': 'अवधि प्रीसेट',
    'ja': '所要時間プリセット',
    'ko': '소요 시간 프리셋',
  },
  'profile.reminder_presets_label': {
    'en': 'Reminder presets',
    'ru': 'Пресеты напоминаний',
    'de': 'Erinnerungs-Voreinstellungen',
    'fr': 'Préréglages de rappel',
    'it': 'Preset di promemoria',
    'pt': 'Predefinições de lembrete',
    'es': 'Preajustes de recordatorio',
    'id': 'Preset pengingat',
    'hi': 'रिमाइंडर प्रीसेट',
    'ja': 'リマインダーのプリセット',
    'ko': '알림 프리셋',
  },
  'profile.presets_add': {
    'en': 'Add',
    'ru': 'Добавить',
    'de': 'Hinzufügen',
    'fr': 'Ajouter',
    'it': 'Aggiungi',
    'pt': 'Adicionar',
    'es': 'Añadir',
    'id': 'Tambah',
    'hi': 'जोड़ें',
    'ja': '追加',
    'ko': '추가',
  },
  'profile.presets_add_minutes_title': {
    'en': 'Add minutes',
    'ru': 'Добавить минуты',
    'de': 'Minuten hinzufügen',
    'fr': 'Ajouter des minutes',
    'it': 'Aggiungi minuti',
    'pt': 'Adicionar minutos',
    'es': 'Añadir minutos',
    'id': 'Tambah menit',
    'hi': 'मिनट जोड़ें',
    'ja': '分を追加',
    'ko': '분 추가',
  },
  'profile.presets_minutes_hint': {
    'en': 'Minutes',
    'ru': 'Минуты',
    'de': 'Minuten',
    'fr': 'Minutes',
    'it': 'Minuti',
    'pt': 'Minutos',
    'es': 'Minutos',
    'id': 'Menit',
    'hi': 'मिनट',
    'ja': '分',
    'ko': '분',
  },
  // Чип «в момент начала» (0 минут) для пресетов напоминаний.
  'profile.reminder_at_start': {
    'en': 'At start',
    'ru': 'В момент',
    'de': 'Zum Start',
    'fr': 'Au début',
    'it': 'All’inizio',
    'pt': 'No início',
    'es': 'Al inicio',
    'id': 'Saat mulai',
    'hi': 'शुरू में',
    'ja': '開始時',
    'ko': '시작 시',
  },
  // Короткий суффикс «мин» (минуты) для чипов длительности/напоминаний.
  'profile.minutes_short': {
    'en': 'min',
    'ru': 'мин',
    'de': 'Min',
    'fr': 'min',
    'it': 'min',
    'pt': 'min',
    'es': 'min',
    'id': 'mnt',
    'hi': 'मिनट',
    'ja': '分',
    'ko': '분',
  },

  // ---- Редактор целей (Edit goals screen) ----
  'profile.edit_goals': {
    'en': 'Edit goals',
    'ru': 'Изменить цели',
    'de': 'Ziele bearbeiten',
    'fr': 'Modifier les objectifs',
    'it': 'Modifica obiettivi',
    'pt': 'Editar objetivos',
    'es': 'Editar objetivos',
    'id': 'Edit tujuan',
    'hi': 'लक्ष्य संपादित करो',
    'ja': '目標を編集',
    'ko': '목표 편집',
  },
  'profile.edit_goals_subtitle': {
    'en': 'Weight, height, activity, nutrition & water',
    'ru': 'Вес, рост, активность, питание и вода',
    'de': 'Gewicht, Größe, Aktivität, Ernährung & Wasser',
    'fr': 'Poids, taille, activité, nutrition & eau',
    'it': 'Peso, altezza, attività, nutrizione e acqua',
    'pt': 'Peso, altura, atividade, nutrição e água',
    'es': 'Peso, altura, actividad, nutrición y agua',
    'id': 'Berat, tinggi, aktivitas, nutrisi & air',
    'hi': 'वज़न, ऊंचाई, गतिविधि, पोषण और पानी',
    'ja': '体重、身長、活動量、栄養・水分',
    'ko': '체중, 키, 활동량, 영양 & 수분',
  },
  // ---- Единый экран «Мои данные» (My Data screen) ----
  'profile.my_data': {
    'en': 'My data',
    'ru': 'Мои данные',
    'de': 'Meine Daten',
    'fr': 'Mes données',
    'it': 'I miei dati',
    'pt': 'Meus dados',
    'es': 'Mis datos',
    'id': 'Data saya',
    'hi': 'मेरा डेटा',
    'ja': 'マイデータ',
    'ko': '내 데이터',
  },
  'profile.my_data_subtitle': {
    'en': 'Body, macros, nutrition, health & sleep',
    'ru': 'Тело, КБЖУ, питание, здоровье и сон',
    'de': 'Körper, Makros, Ernährung, Gesundheit & Schlaf',
    'fr': 'Corps, macros, nutrition, santé & sommeil',
    'it': 'Corpo, macro, nutrizione, salute e sonno',
    'pt': 'Corpo, macros, nutrição, saúde e sono',
    'es': 'Cuerpo, macros, nutrición, salud y sueño',
    'id': 'Tubuh, makro, nutrisi, kesehatan & tidur',
    'hi': 'शरीर, मैक्रोज़, पोषण, स्वास्थ्य और नींद',
    'ja': '体・マクロ・栄養・健康・睡眠',
    'ko': '신체, 매크로, 영양, 건강 & 수면',
  },
  'edit_goals.title': {
    'en': 'Edit goals',
    'ru': 'Изменить цели',
    'de': 'Ziele bearbeiten',
    'fr': 'Modifier les objectifs',
    'it': 'Modifica obiettivi',
    'pt': 'Editar objetivos',
    'es': 'Editar objetivos',
    'id': 'Edit tujuan',
    'hi': 'लक्ष्य संपादित करो',
    'ja': '目標を編集',
    'ko': '목표 편집',
  },
  'edit_goals.body_params': {
    'en': 'Body parameters',
    'ru': 'Параметры тела',
    'de': 'Körperparameter',
    'fr': 'Paramètres corporels',
    'it': 'Parametri corporei',
    'pt': 'Parâmetros corporais',
    'es': 'Parámetros corporales',
    'id': 'Parameter tubuh',
    'hi': 'शरीर के पैरामीटर',
    'ja': '体のパラメータ',
    'ko': '신체 파라미터',
  },
  'edit_goals.water_goal_label': {
    'en': 'Daily water goal',
    'ru': 'Дневная норма воды',
    'de': 'Tägliches Wasserziel',
    'fr': "Objectif d'eau quotidien",
    'it': 'Obiettivo idrico giornaliero',
    'pt': 'Meta diária de água',
    'es': 'Meta diaria de agua',
    'id': 'Target air harian',
    'hi': 'दैनिक पानी का लक्ष्य',
    'ja': '1日の水分目標',
    'ko': '하루 수분 목표',
  },
  'edit_goals.targets_preview': {
    'en': 'Computed daily targets',
    'ru': 'Расчётные дневные нормы',
    'de': 'Berechnete Tagesziele',
    'fr': 'Objectifs journaliers calculés',
    'it': 'Obiettivi giornalieri calcolati',
    'pt': 'Metas diárias calculadas',
    'es': 'Objetivos diarios calculados',
    'id': 'Target harian yang dihitung',
    'hi': 'गणना किए गए दैनिक लक्ष्य',
    'ja': '計算された1日の目標',
    'ko': '계산된 일일 목표',
  },
  'edit_goals.targets_note': {
    'en': 'Based on Mifflin–St Jeor formula',
    'ru': 'По формуле Миффлина–Сан-Жеора',
    'de': 'Basierend auf der Mifflin-St.-Jeor-Formel',
    'fr': 'Basé sur la formule de Mifflin–St Jeor',
    'it': 'Basato sulla formula di Mifflin–St Jeor',
    'pt': 'Baseado na fórmula de Mifflin–St Jeor',
    'es': 'Basado en la fórmula de Mifflin–St Jeor',
    'id': 'Berdasarkan rumus Mifflin–St Jeor',
    'hi': 'Mifflin–St Jeor सूत्र पर आधारित',
    'ja': 'Mifflin–St Jeor式に基づく',
    'ko': 'Mifflin–St Jeor 공식 기반',
  },
  'edit_goals.targets_fill_all': {
    'en': 'Fill in weight, height and age to see your targets',
    'ru': 'Заполни вес, рост и возраст, чтобы увидеть нормы',
    'de': 'Gib Gewicht, Größe und Alter ein, um deine Ziele zu sehen',
    'fr': 'Remplis poids, taille et âge pour voir tes objectifs',
    'it': 'Inserisci peso, altezza ed età per vedere i tuoi obiettivi',
    'pt': 'Preencha peso, altura e idade para ver suas metas',
    'es': 'Completa peso, altura y edad para ver tus objetivos',
    'id': 'Isi berat, tinggi, dan usia untuk melihat targetmu',
    'hi': 'लक्ष्य देखने के लिए वज़न, ऊंचाई और आयु भरो',
    'ja': '体重・身長・年齢を入力して目標を確認しましょう',
    'ko': '목표를 보려면 체중, 키, 나이를 입력하세요',
  },
  'edit_goals.preview_kcal': {
    'en': 'Calories',
    'ru': 'Калории',
    'de': 'Kalorien',
    'fr': 'Calories',
    'it': 'Calorie',
    'pt': 'Calorias',
    'es': 'Calorías',
    'id': 'Kalori',
    'hi': 'कैलोरी',
    'ja': 'カロリー',
    'ko': '칼로리',
  },
  'edit_goals.preview_protein': {
    'en': 'Protein',
    'ru': 'Белок',
    'de': 'Eiweiß',
    'fr': 'Protéines',
    'it': 'Proteine',
    'pt': 'Proteína',
    'es': 'Proteína',
    'id': 'Protein',
    'hi': 'प्रोटीन',
    'ja': 'タンパク質',
    'ko': '단백질',
  },
  'edit_goals.preview_fat': {
    'en': 'Fat',
    'ru': 'Жиры',
    'de': 'Fett',
    'fr': 'Lipides',
    'it': 'Grassi',
    'pt': 'Gordura',
    'es': 'Grasas',
    'id': 'Lemak',
    'hi': 'वसा',
    'ja': '脂質',
    'ko': '지방',
  },
  'edit_goals.preview_carbs': {
    'en': 'Carbs',
    'ru': 'Углеводы',
    'de': 'Kohlenhydrate',
    'fr': 'Glucides',
    'it': 'Carboidrati',
    'pt': 'Carboidratos',
    'es': 'Carbohidratos',
    'id': 'Karbohidrat',
    'hi': 'कार्बोहाइड्रेट',
    'ja': '炭水化物',
    'ko': '탄수화물',
  },
  'edit_goals.preview_fiber': {
    'en': 'Fiber',
    'ru': 'Клетчатка',
    'de': 'Ballaststoffe',
    'fr': 'Fibres',
    'it': 'Fibre',
    'pt': 'Fibras',
    'es': 'Fibra',
    'id': 'Serat',
    'hi': 'फाइबर',
    'ja': '食物繊維',
    'ko': '식이섬유',
  },
  'edit_goals.preview_sugar_max': {
    'en': 'Sugar (max)',
    'ru': 'Сахар (макс.)',
    'de': 'Zucker (max.)',
    'fr': 'Sucre (max)',
    'it': 'Zucchero (max)',
    'pt': 'Açúcar (máx.)',
    'es': 'Azúcar (máx.)',
    'id': 'Gula (maks)',
    'hi': 'शुगर (अधिकतम)',
    'ja': '糖質（上限）',
    'ko': '당류 (최대)',
  },
  'edit_goals.unit_kcal': {
    'en': 'kcal',
    'ru': 'ккал',
    'de': 'kcal',
    'fr': 'kcal',
    'it': 'kcal',
    'pt': 'kcal',
    'es': 'kcal',
    'id': 'kkal',
    'hi': 'kcal',
    'ja': 'kcal',
    'ko': 'kcal',
  },
  'edit_goals.unit_g': {
    'en': 'g',
    'ru': 'г',
    'de': 'g',
    'fr': 'g',
    'it': 'g',
    'pt': 'g',
    'es': 'g',
    'id': 'g',
    'hi': 'ग्रा',
    'ja': 'g',
    'ko': 'g',
  },
  'edit_goals.save_btn': {
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
  'edit_goals.saved_snack': {
    'en': 'Goals saved',
    'ru': 'Цели сохранены',
    'de': 'Ziele gespeichert',
    'fr': 'Objectifs sauvegardés',
    'it': 'Obiettivi salvati',
    'pt': 'Metas salvas',
    'es': 'Objetivos guardados',
    'id': 'Tujuan disimpan',
    'hi': 'लक्ष्य सहेजे गए',
    'ja': '目標を保存しました',
    'ko': '목표가 저장됐어요',
  },

  // ---- FAB position setting ----
  'profile.fab_position': {
    'en': 'Button position',
    'ru': 'Положение кнопки «+»',
    'de': 'Schaltflächenposition',
    'fr': 'Position du bouton',
    'it': 'Posizione del pulsante',
    'pt': 'Posição do botão',
    'es': 'Posición del botón',
    'id': 'Posisi tombol',
    'hi': 'बटन की स्थिति',
    'ja': 'ボタンの位置',
    'ko': '버튼 위치',
  },
  'profile.fab_position_left': {
    'en': 'Left',
    'ru': 'Слева',
    'de': 'Links',
    'fr': 'Gauche',
    'it': 'Sinistra',
    'pt': 'Esquerda',
    'es': 'Izquierda',
    'id': 'Kiri',
    'hi': 'बाएं',
    'ja': '左',
    'ko': '왼쪽',
  },
  'profile.fab_position_center': {
    'en': 'Center',
    'ru': 'По центру',
    'de': 'Mitte',
    'fr': 'Centre',
    'it': 'Centro',
    'pt': 'Centro',
    'es': 'Centro',
    'id': 'Tengah',
    'hi': 'केंद्र',
    'ja': '中央',
    'ko': '가운데',
  },
  'profile.fab_position_right': {
    'en': 'Right',
    'ru': 'Справа',
    'de': 'Rechts',
    'fr': 'Droite',
    'it': 'Destra',
    'pt': 'Direita',
    'es': 'Derecha',
    'id': 'Kanan',
    'hi': 'दाएं',
    'ja': '右',
    'ko': '오른쪽',
  },

  // ---- Profile: Расширенные функции (feature mode toggles) ----
  'profile.section_advanced': {
    'en': 'Advanced features',
    'ru': 'Расширенные функции',
    'de': 'Erweiterte Funktionen',
    'fr': 'Fonctions avancées',
    'it': 'Funzioni avanzate',
    'pt': 'Recursos avançados',
    'es': 'Funciones avanzadas',
    'id': 'Fitur lanjutan',
    'hi': 'उन्नत सुविधाएं',
    'ja': '詳細機能',
    'ko': '고급 기능',
  },
  'profile.advanced_section_note': {
    'en': 'Enable only the modules you actually use. Disabled modules stay hidden to keep the app simple.',
    'ru': 'Включи только те модули, которые ты реально используешь. Выключенные будут скрыты для простоты.',
    'de': 'Aktiviere nur die Module, die du wirklich nutzt. Deaktivierte bleiben verborgen, um die App einfach zu halten.',
    'fr': 'Active uniquement les modules que tu utilises vraiment. Les désactivés restent cachés pour garder l\'app simple.',
    'it': 'Attiva solo i moduli che usi davvero. Quelli disattivati restano nascosti per mantenere l\'app semplice.',
    'pt': 'Ative apenas os módulos que você realmente usa. Os desativados ficam ocultos para manter o app simples.',
    'es': 'Activa solo los módulos que realmente usas. Los desactivados quedan ocultos para mantener la app simple.',
    'id': 'Aktifkan hanya modul yang benar-benar kamu gunakan. Yang dinonaktifkan tetap tersembunyi agar app tetap sederhana.',
    'hi': 'केवल वही मॉड्यूल चालू करो जो तुम वास्तव में उपयोग करते हो। बंद मॉड्यूल छिपे रहेंगे।',
    'ja': '実際に使うモジュールだけをオンにしてください。オフのモジュールは非表示になり、アプリがシンプルに保たれます。',
    'ko': '실제로 사용하는 모듈만 활성화하세요. 비활성화된 모듈은 숨겨져 앱이 단순하게 유지됩니다.',
  },
  'profile.advanced_nutrition': {
    'en': 'Calorie & macro tracking',
    'ru': 'Подсчёт калорий и БЖУ',
    'de': 'Kalorien & Makros tracken',
    'fr': 'Suivi des calories et macros',
    'it': 'Conteggio calorie e macros',
    'pt': 'Rastreamento de calorias e macros',
    'es': 'Seguimiento de calorías y macros',
    'id': 'Pelacakan kalori & makro',
    'hi': 'कैलोरी और मैक्रो ट्रैकिंग',
    'ja': 'カロリー・マクロ記録',
    'ko': '칼로리 및 영양소 추적',
  },
  'profile.advanced_nutrition_subtitle': {
    'en': 'Full food log with proteins, fats and carbs',
    'ru': 'Полный журнал еды с белками, жирами и углеводами',
    'de': 'Vollständiges Ernährungsprotokoll mit Proteinen, Fetten und Kohlenhydraten',
    'fr': 'Journal alimentaire complet avec protéines, lipides et glucides',
    'it': 'Registro alimentare completo con proteine, grassi e carboidrati',
    'pt': 'Diário alimentar completo com proteínas, gorduras e carboidratos',
    'es': 'Registro de alimentos completo con proteínas, grasas y carbohidratos',
    'id': 'Log makanan lengkap dengan protein, lemak, dan karbohidrat',
    'hi': 'प्रोटीन, वसा और कार्बोहाइड्रेट के साथ पूर्ण खाद्य लॉग',
    'ja': 'タンパク質・脂質・炭水化物を含む完全な食事記録',
    'ko': '단백질, 지방, 탄수화물이 포함된 전체 식품 기록',
  },
  'profile.advanced_workouts': {
    'en': 'Workout programs',
    'ru': 'Программы тренировок',
    'de': 'Trainingsprogramme',
    'fr': "Programmes d'entraînement",
    'it': 'Programmi di allenamento',
    'pt': 'Programas de treino',
    'es': 'Programas de entrenamiento',
    'id': 'Program latihan',
    'hi': 'व्यायाम कार्यक्रम',
    'ja': 'トレーニングプログラム',
    'ko': '운동 프로그램',
  },
  'profile.advanced_workouts_subtitle': {
    'en': 'Create and track structured workout sessions',
    'ru': 'Создавай и отслеживай структурированные тренировки',
    'de': 'Erstelle und verfolge strukturierte Trainingseinheiten',
    'fr': "Crée et suis des séances d'entraînement structurées",
    'it': 'Crea e segui sessioni di allenamento strutturate',
    'pt': 'Crie e acompanhe sessões de treino estruturadas',
    'es': 'Crea y sigue sesiones de entrenamiento estructuradas',
    'id': 'Buat dan lacak sesi latihan terstruktur',
    'hi': 'संरचित वर्कआउट सत्र बनाओ और ट्रैक करो',
    'ja': '構造化されたトレーニングセッションを作成・追跡',
    'ko': '구조화된 운동 세션 생성 및 추적',
  },
  'profile.advanced_meditation': {
    'en': 'Meditation library',
    'ru': 'Библиотека медитаций',
    'de': 'Meditationsbibliothek',
    'fr': 'Bibliothèque de méditations',
    'it': 'Libreria meditazioni',
    'pt': 'Biblioteca de meditações',
    'es': 'Biblioteca de meditaciones',
    'id': 'Perpustakaan meditasi',
    'hi': 'ध्यान पुस्तकालय',
    'ja': '瞑想ライブラリ',
    'ko': '명상 라이브러리',
  },
  'profile.advanced_meditation_subtitle': {
    'en': 'Guided sessions and custom meditation editor',
    'ru': 'Гайдед-сессии и редактор своих медитаций',
    'de': 'Geführte Sitzungen und benutzerdefinierter Meditationseditor',
    'fr': 'Séances guidées et éditeur de méditations personnalisées',
    'it': 'Sessioni guidate ed editor meditazioni personalizzate',
    'pt': 'Sessões guiadas e editor de meditações personalizadas',
    'es': 'Sesiones guiadas y editor de meditaciones personalizadas',
    'id': 'Sesi terpandu dan editor meditasi kustom',
    'hi': 'गाइडेड सत्र और कस्टम ध्यान संपादक',
    'ja': 'ガイドセッションとカスタム瞑想エディター',
    'ko': '가이드 세션 및 맞춤 명상 편집기',
  },
  'profile.advanced_breathing': {
    'en': 'Breathing technique editor',
    'ru': 'Редактор техник дыхания',
    'de': 'Atemtechnik-Editor',
    'fr': 'Éditeur de techniques de respiration',
    'it': 'Editor tecniche di respirazione',
    'pt': 'Editor de técnicas de respiração',
    'es': 'Editor de técnicas de respiración',
    'id': 'Editor teknik pernapasan',
    'hi': 'श्वास तकनीक संपादक',
    'ja': '呼吸法エディター',
    'ko': '호흡 기법 편집기',
  },
  'profile.advanced_breathing_subtitle': {
    'en': 'Create custom breathing patterns beyond the 3 presets',
    'ru': 'Создавай свои техники дыхания помимо трёх встроенных',
    'de': 'Erstelle eigene Atemübungen über die 3 Voreinstellungen hinaus',
    'fr': 'Crée des exercices de respiration personnalisés au-delà des 3 préréglages',
    'it': 'Crea schemi di respirazione personalizzati oltre i 3 preset',
    'pt': 'Crie padrões de respiração personalizados além dos 3 presets',
    'es': 'Crea patrones de respiración personalizados más allá de los 3 presets',
    'id': 'Buat pola pernapasan kustom di luar 3 preset',
    'hi': '3 प्रीसेट के अलावा कस्टम श्वास पैटर्न बनाओ',
    'ja': '3つのプリセット以外のカスタム呼吸パターンを作成',
    'ko': '3개 프리셋 외에 맞춤 호흡 패턴 생성',
  },

  // ---- Profile: подвал с версией приложения ----
  'profile.version_label': {
    'en': 'Version',
    'ru': 'Версия',
    'de': 'Version',
    'fr': 'Version',
    'it': 'Versione',
    'pt': 'Versão',
    'es': 'Versión',
    'id': 'Versi',
    'hi': 'संस्करण',
    'ja': 'バージョン',
    'ko': '버전',
  },

  // ---- Profile: секция прогресса (геймификация, перенесена из Today) ----
  'profile.section_progress': {
    'en': 'Progress',
    'ru': 'Прогресс',
    'de': 'Fortschritt',
    'fr': 'Progression',
    'it': 'Progresso',
    'pt': 'Progresso',
    'es': 'Progreso',
    'id': 'Kemajuan',
    'hi': 'प्रगति',
    'ja': '進捗',
    'ko': '진행',
  },

  // ---- Profile: доступность ----
  'profile.section_accessibility': {
    'en': 'Accessibility',
    'ru': 'Доступность',
    'de': 'Barrierefreiheit',
    'fr': 'Accessibilité',
    'it': 'Accessibilità',
    'pt': 'Acessibilidade',
    'es': 'Accesibilidad',
    'id': 'Aksesibilitas',
    'hi': 'पहुँच',
    'ja': 'アクセシビリティ',
    'ko': '접근성',
  },
  'profile.high_contrast': {
    'en': 'High contrast',
    'ru': 'Высокий контраст',
    'de': 'Hoher Kontrast',
    'fr': 'Contraste élevé',
    'it': 'Alto contrasto',
    'pt': 'Alto contraste',
    'es': 'Alto contraste',
    'id': 'Kontras tinggi',
    'hi': 'उच्च कंट्रास्ट',
    'ja': 'ハイコントラスト',
    'ko': '높은 대비',
  },
  'profile.high_contrast_subtitle': {
    'en': 'AAA colors & Atkinson Hyperlegible font',
    'ru': 'Цвета AAA и шрифт Atkinson Hyperlegible',
    'de': 'AAA-Farben & Atkinson-Hyperlegible-Schrift',
    'fr': 'Couleurs AAA & police Atkinson Hyperlegible',
    'it': 'Colori AAA & font Atkinson Hyperlegible',
    'pt': 'Cores AAA & fonte Atkinson Hyperlegible',
    'es': 'Colores AAA & fuente Atkinson Hyperlegible',
    'id': 'Warna AAA & font Atkinson Hyperlegible',
    'hi': 'AAA रंग और Atkinson Hyperlegible फ़ॉन्ट',
    'ja': 'AAAカラーとAtkinson Hyperlegibleフォント',
    'ko': 'AAA 색상 및 Atkinson Hyperlegible 글꼴',
  },

  // ---- Profile: умолчания задач/тренировок ----
  'profile.section_defaults': {
    'en': 'Task & workout defaults',
    'ru': 'Умолчания задач и тренировок',
    'de': 'Standard Aufgaben & Training',
    'fr': 'Paramètres tâches & entraînements',
    'it': 'Predefiniti attività & allenamenti',
    'pt': 'Padrões de tarefas & treinos',
    'es': 'Predeterminados de tareas & entrenamientos',
    'id': 'Default tugas & latihan',
    'hi': 'कार्य और वर्कआउट डिफ़ॉल्ट',
    'ja': 'タスク・ワークアウトのデフォルト',
    'ko': '기본 작업 & 운동',
  },

  // ---- Accent picker (profile.accent + accent.* names) ----
  'profile.accent': {
    'en': 'Accent',
    'ru': 'Акцент',
    'de': 'Akzent',
    'fr': 'Accent',
    'it': 'Accento',
    'pt': 'Destaque',
    'es': 'Acento',
    'id': 'Aksen',
    'hi': 'एक्सेंट',
    'ja': 'アクセント',
    'ko': '강조색',
  },
  'accent.indigo': {
    'en': 'Indigo',
    'ru': 'Индиго',
    'de': 'Indigo',
    'fr': 'Indigo',
    'it': 'Indaco',
    'pt': 'Índigo',
    'es': 'Índigo',
    'id': 'Indigo',
    'hi': 'इंडिगो',
    'ja': 'インディゴ',
    'ko': '인디고',
  },
  'accent.emerald': {
    'en': 'Emerald',
    'ru': 'Изумрудный',
    'de': 'Smaragd',
    'fr': 'Émeraude',
    'it': 'Smeraldo',
    'pt': 'Esmeralda',
    'es': 'Esmeralda',
    'id': 'Zamrud',
    'hi': 'पन्ना',
    'ja': 'エメラルド',
    'ko': '에메랄드',
  },
  'accent.violet': {
    'en': 'Violet',
    'ru': 'Фиолетовый',
    'de': 'Violett',
    'fr': 'Violet',
    'it': 'Viola',
    'pt': 'Violeta',
    'es': 'Violeta',
    'id': 'Ungu',
    'hi': 'बैंगनी',
    'ja': 'バイオレット',
    'ko': '바이올렛',
  },
  'accent.ochre': {
    'en': 'Ochre',
    'ru': 'Охра',
    'de': 'Ocker',
    'fr': 'Ocre',
    'it': 'Ocra',
    'pt': 'Ocre',
    'es': 'Ocre',
    'id': 'Oker',
    'hi': 'गेरू',
    'ja': 'オーカー',
    'ko': '황토',
  },
  'accent.rose': {
    'en': 'Rose',
    'ru': 'Розовый',
    'de': 'Rose',
    'fr': 'Rose',
    'it': 'Rosa',
    'pt': 'Rosa',
    'es': 'Rosa',
    'id': 'Mawar',
    'hi': 'गुलाबी',
    'ja': 'ローズ',
    'ko': '로즈',
  },
  'accent.slate': {
    'en': 'Slate',
    'ru': 'Серо-синий',
    'de': 'Schiefer',
    'fr': 'Ardoise',
    'it': 'Ardesia',
    'pt': 'Ardósia',
    'es': 'Pizarra',
    'id': 'Abu-abu biru',
    'hi': 'स्लेट',
    'ja': 'スレート',
    'ko': '슬레이트',
  },

  // ---- Compare plans (Free vs Premium таблица) ----

  // Метка бейджа PremiumLockBadge
  'paywall.lock_badge_label': {
    'en': 'Premium',
    'ru': 'Premium',
    'de': 'Premium',
    'fr': 'Premium',
    'it': 'Premium',
    'pt': 'Premium',
    'es': 'Premium',
    'id': 'Premium',
    'hi': 'Premium',
    'ja': 'Premium',
    'ko': 'Premium',
  },

  // Кнопка открытия шита сравнения (на paywall)
  'paywall.compare_plans_btn': {
    'en': 'Compare plans',
    'ru': 'Сравнить тарифы',
    'de': 'Tarife vergleichen',
    'fr': 'Comparer les formules',
    'it': 'Confronta i piani',
    'pt': 'Comparar planos',
    'es': 'Comparar planes',
    'id': 'Bandingkan paket',
    'hi': 'प्लान तुलना करें',
    'ja': 'プランを比較',
    'ko': '플랜 비교',
  },

  // Заголовок шита сравнения
  'paywall.compare_plans_title': {
    'en': 'Compare plans',
    'ru': 'Сравнение тарифов',
    'de': 'Pläne vergleichen',
    'fr': 'Comparer les formules',
    'it': 'Confronta i piani',
    'pt': 'Comparar planos',
    'es': 'Comparar planes',
    'id': 'Bandingkan paket',
    'hi': 'प्लान तुलना',
    'ja': 'プラン比較',
    'ko': '플랜 비교',
  },

  // Заголовки колонок таблицы
  'paywall.compare_col_free': {
    'en': 'Free',
    'ru': 'Бесплатно',
    'de': 'Kostenlos',
    'fr': 'Gratuit',
    'it': 'Gratuito',
    'pt': 'Grátis',
    'es': 'Gratis',
    'id': 'Gratis',
    'hi': 'मुफ्त',
    'ja': '無料',
    'ko': '무료',
  },
  'paywall.compare_col_premium': {
    'en': 'Premium',
    'ru': 'Premium',
    'de': 'Premium',
    'fr': 'Premium',
    'it': 'Premium',
    'pt': 'Premium',
    'es': 'Premium',
    'id': 'Premium',
    'hi': 'Premium',
    'ja': 'Premium',
    'ko': 'Premium',
  },

  // Заголовки секций таблицы
  'paywall.compare_section_productivity': {
    'en': 'Productivity',
    'ru': 'Продуктивность',
    'de': 'Produktivität',
    'fr': 'Productivité',
    'it': 'Produttività',
    'pt': 'Produtividade',
    'es': 'Productividad',
    'id': 'Produktivitas',
    'hi': 'उत्पादकता',
    'ja': '生産性',
    'ko': '생산성',
  },
  'paywall.compare_section_wellbeing': {
    'en': 'Wellbeing',
    'ru': 'Здоровье',
    'de': 'Wohlbefinden',
    'fr': 'Bien-être',
    'it': 'Benessere',
    'pt': 'Bem-estar',
    'es': 'Bienestar',
    'id': 'Kesehatan',
    'hi': 'स्वास्थ्य',
    'ja': 'ウェルビーイング',
    'ko': '웰빙',
  },
  'paywall.compare_section_ai': {
    'en': 'AI features',
    'ru': 'Функции ИИ',
    'de': 'KI-Funktionen',
    'fr': 'Fonctionnalités IA',
    'it': 'Funzioni AI',
    'pt': 'Recursos de IA',
    'es': 'Funciones de IA',
    'id': 'Fitur AI',
    'hi': 'AI फीचर',
    'ja': 'AI機能',
    'ko': 'AI 기능',
  },

  // Строки продуктивности (Free + Premium)
  'paywall.compare_tasks_planning': {
    'en': 'Tasks & planning',
    'ru': 'Задачи и планирование',
    'de': 'Aufgaben & Planung',
    'fr': 'Tâches et planification',
    'it': 'Attività e pianificazione',
    'pt': 'Tarefas e planejamento',
    'es': 'Tareas y planificación',
    'id': 'Tugas & perencanaan',
    'hi': 'टास्क और प्लानिंग',
    'ja': 'タスクと計画',
    'ko': '작업 및 계획',
  },
  'paywall.compare_priority_limit': {
    'en': 'Up to 3 priority tasks/day',
    'ru': 'До 3 главных задач в день',
    'de': 'Bis zu 3 Prioritätsaufgaben/Tag',
    'fr': "Jusqu'à 3 tâches prioritaires/jour",
    'it': 'Fino a 3 attività prioritarie/giorno',
    'pt': 'Até 3 tarefas prioritárias/dia',
    'es': 'Hasta 3 tareas prioritarias/día',
    'id': 'Hingga 3 tugas prioritas/hari',
    'hi': 'दिन में 3 प्राथमिक टास्क तक',
    'ja': '1日最大3つの優先タスク',
    'ko': '하루 최대 3개 우선 작업',
  },
  'paywall.compare_streaks': {
    'en': 'Streaks & freeze',
    'ru': 'Стрики и заморозки',
    'de': 'Serien & Einfrierungen',
    'fr': 'Séries et gels',
    'it': 'Serie & blocchi',
    'pt': 'Sequências e congelamentos',
    'es': 'Rachas y congelaciones',
    'id': 'Streak & pembekuan',
    'hi': 'स्ट्रीक और फ्रीज़',
    'ja': 'ストリーク＆フリーズ',
    'ko': '연속 및 동결',
  },
  'paywall.compare_review': {
    'en': 'Morning & evening review',
    'ru': 'Утренний и вечерний разбор',
    'de': 'Morgen- & Abendüberprüfung',
    'fr': 'Révision matin et soir',
    'it': 'Revisione mattina e sera',
    'pt': 'Revisão manhã e noite',
    'es': 'Revisión mañana y tarde',
    'id': 'Tinjauan pagi & malam',
    'hi': 'सुबह और शाम की समीक्षा',
    'ja': '朝・夜のレビュー',
    'ko': '아침 & 저녁 복습',
  },
  'paywall.compare_diary': {
    'en': 'Diary & mood tracking',
    'ru': 'Дневник и отслеживание настроения',
    'de': 'Tagebuch & Stimmungsverfolgung',
    'fr': 'Journal et suivi de l\'humeur',
    'it': 'Diario e tracciamento umore',
    'pt': 'Diário e rastreamento de humor',
    'es': 'Diario y seguimiento del ánimo',
    'id': 'Jurnal & pelacakan suasana hati',
    'hi': 'डायरी और मूड ट्रैकिंग',
    'ja': '日記＆気分トラッキング',
    'ko': '일기 & 기분 추적',
  },
  'paywall.compare_plan_sharing': {
    'en': 'Plan sharing (view-only)',
    'ru': 'Шеринг плана (просмотр)',
    'de': 'Plan teilen (nur Ansicht)',
    'fr': 'Partage de plan (lecture seule)',
    'it': 'Condivisione piano (solo lettura)',
    'pt': 'Compartilhamento do plano (leitura)',
    'es': 'Compartir plan (solo lectura)',
    'id': 'Berbagi rencana (lihat saja)',
    'hi': 'प्लान शेयरिंग (सिर्फ देखना)',
    'ja': 'プラン共有（閲覧専用）',
    'ko': '플랜 공유 (읽기 전용)',
  },

  // Строки здоровья (Free + Premium)
  'paywall.compare_water': {
    'en': 'Water tracking',
    'ru': 'Учёт воды',
    'de': 'Wasserverfolgung',
    'fr': 'Suivi de l\'eau',
    'it': 'Monitoraggio acqua',
    'pt': 'Rastreamento de água',
    'es': 'Seguimiento de agua',
    'id': 'Pelacakan air',
    'hi': 'पानी ट्रैकिंग',
    'ja': '水分トラッキング',
    'ko': '물 섭취 추적',
  },
  'paywall.compare_sleep': {
    'en': 'Sleep',
    'ru': 'Сон',
    'de': 'Schlaf',
    'fr': 'Sommeil',
    'it': 'Sonno',
    'pt': 'Sono',
    'es': 'Sueño',
    'id': 'Tidur',
    'hi': 'नींद',
    'ja': '睡眠',
    'ko': '수면',
  },
  'paywall.compare_breathing': {
    'en': 'Breathing & meditation',
    'ru': 'Дыхание и медитация',
    'de': 'Atmung & Meditation',
    'fr': 'Respiration et méditation',
    'it': 'Respirazione e meditazione',
    'pt': 'Respiração e meditação',
    'es': 'Respiración y meditación',
    'id': 'Pernapasan & meditasi',
    'hi': 'श्वास और ध्यान',
    'ja': '呼吸＆瞑想',
    'ko': '호흡 & 명상',
  },
  'paywall.compare_workouts': {
    'en': 'Workouts',
    'ru': 'Тренировки',
    'de': 'Training',
    'fr': 'Entraînements',
    'it': 'Allenamenti',
    'pt': 'Treinos',
    'es': 'Entrenamientos',
    'id': 'Latihan',
    'hi': 'वर्कआउट',
    'ja': 'ワークアウト',
    'ko': '운동',
  },
  'paywall.compare_food_basic': {
    'en': 'Food tracking',
    'ru': 'Учёт питания',
    'de': 'Ernährungsverfolgung',
    'fr': 'Suivi alimentaire',
    'it': 'Monitoraggio alimentare',
    'pt': 'Rastreamento alimentar',
    'es': 'Seguimiento alimentario',
    'id': 'Pelacakan makanan',
    'hi': 'खाना ट्रैकिंग',
    'ja': '食事トラッキング',
    'ko': '음식 추적',
  },

  // Строка AI-инсайтов дневника (Premium only; прочие AI-строки
  // переиспользуют ключи paywall.benefit_*_title)
  'paywall.compare_ai_insights': {
    'en': 'AI diary insights',
    'ru': 'AI-инсайты дневника',
    'de': 'KI-Tagebuch-Einblicke',
    'fr': 'Analyses IA du journal',
    'it': 'Analisi AI del diario',
    'pt': 'Insights de IA do diário',
    'es': 'Análisis IA del diario',
    'id': 'Wawasan AI jurnal',
    'hi': 'AI डायरी अंतर्दृष्टि',
    'ja': 'AI日記インサイト',
    'ko': 'AI 일기 인사이트',
  },

  // ---------------------------------------------------------------------------
  // G1 — шер-карточка стрика (streak.share_*)
  // ---------------------------------------------------------------------------

  // Заголовок строки в профиле (рядом с «Share my week»).
  'streak.share_btn': {
    'en': 'Share streak',
    'ru': 'Поделиться стриком',
    'de': 'Streak teilen',
    'fr': 'Partager la série',
    'it': 'Condividi la serie',
    'pt': 'Compartilhar sequência',
    'es': 'Compartir racha',
    'id': 'Bagikan streak',
    'hi': 'स्ट्रीक शेयर करो',
    'ja': 'ストリークをシェア',
    'ko': '스트릭 공유하기',
  },

  // Подзаголовок строки / заголовок модального шита.
  'streak.share_title': {
    'en': 'Share your progress card',
    'ru': 'Поделись карточкой прогресса',
    'de': 'Teile deine Fortschrittskarte',
    'fr': 'Partage ta carte de progression',
    'it': 'Condividi la tua scheda progressi',
    'pt': 'Compartilhe seu cartão de progresso',
    'es': 'Comparte tu tarjeta de progreso',
    'id': 'Bagikan kartu kemajuanmu',
    'hi': 'अपना प्रगति कार्ड शेयर करो',
    'ja': '進捗カードをシェアする',
    'ko': '내 진행 카드 공유하기',
  },

  // Текст карточки и буфера обмена. {count} — число дней подряд.
  'streak.share_text': {
    'en': '{count} days in a row in Kaname 🔥',
    'ru': '{count} дней подряд в Kaname 🔥',
    'de': '{count} Tage in Folge in Kaname 🔥',
    'fr': '{count} jours d\'affilée dans Kaname 🔥',
    'it': '{count} giorni di fila in Kaname 🔥',
    'pt': '{count} dias seguidos no Kaname 🔥',
    'es': '{count} días seguidos en Kaname 🔥',
    'id': '{count} hari berturut-turut di Kaname 🔥',
    'hi': 'Kaname में {count} दिन लगातार 🔥',
    'ja': 'Kanameで{count}日連続 🔥',
    'ko': 'Kaname에서 {count}일 연속 🔥',
  },

  // Снэкбар при clipboard-fallback (нативный share недоступен).
  'streak.copied': {
    'en': 'Copied to clipboard',
    'ru': 'Скопировано в буфер',
    'de': 'In Zwischenablage kopiert',
    'fr': 'Copié dans le presse-papiers',
    'it': 'Copiato negli appunti',
    'pt': 'Copiado para a área de transferência',
    'es': 'Copiado al portapapeles',
    'id': 'Disalin ke clipboard',
    'hi': 'क्लिपबोर्ड में कॉपी हुआ',
    'ja': 'クリップボードにコピーしました',
    'ko': '클립보드에 복사됨',
  },
};
