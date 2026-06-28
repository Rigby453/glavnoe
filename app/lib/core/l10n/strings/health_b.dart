// Строки Health: Workouts, Breathing, Posture, Meditation, Screen time,
// Sleep report, Water. Наполняется агентом локализации.
const Map<String, Map<String, String>> healthBStrings = {
  // ---------------------------------------------------------------------------
  // workout.*  —  workouts_screen.dart, workout_editor_screen.dart, workout_trainer_screen.dart
  // ---------------------------------------------------------------------------

  'workout.title': {
    'en': 'Workouts',
    'ru': 'Тренировки',
    'de': 'Training',
    'fr': 'Séances',
    'it': 'Allenamenti',
    'pt': 'Treinos',
    'es': 'Entrenamientos',
    'id': 'Latihan',
    'hi': 'वर्कआउट',
    'ja': 'ワークアウト',
    'ko': '운동',
  },
  'workout.new_workout': {
    'en': 'New workout',
    'ru': 'Новая тренировка',
    'de': 'Neues Training',
    'fr': 'Nouvelle séance',
    'it': 'Nuovo allenamento',
    'pt': 'Novo treino',
    'es': 'Nuevo entrenamiento',
    'id': 'Latihan baru',
    'hi': 'नया वर्कआउट',
    'ja': '新しいワークアウト',
    'ko': '새 운동',
  },
  'workout.history': {
    'en': 'History',
    'ru': 'История',
    'de': 'Verlauf',
    'fr': 'Historique',
    'it': 'Cronologia',
    'pt': 'Histórico',
    'es': 'Historial',
    'id': 'Riwayat',
    'hi': 'इतिहास',
    'ja': '履歴',
    'ko': '기록',
  },
  'workout.empty_state': {
    'en': 'No workouts yet — create one\nand add exercises to it',
    'ru': 'Тренировок пока нет — создай одну\nи добавь в неё упражнения',
    'de': 'Noch kein Training — erstelle eines\nund füge Übungen hinzu',
    'fr': 'Aucune séance — crée-en une\net ajoute des exercices',
    'it': 'Nessun allenamento — creane uno\ne aggiungi esercizi',
    'pt': 'Nenhum treino ainda — crie um\ne adicione exercícios',
    'es': 'Sin entrenamientos — crea uno\ny añade ejercicios',
    'id': 'Belum ada latihan — buat satu\ndan tambahkan latihan',
    'hi': 'अभी कोई वर्कआउट नहीं — एक बनाएं\nऔर उसमें एक्सरसाइज़ जोड़ें',
    'ja': 'ワークアウトなし — 新規作成して\n種目を追加しよう',
    'ko': '운동 없음 — 새로 만들고\n종목을 추가하세요',
  },
  'workout.name_hint': {
    'en': 'Workout name',
    'ru': 'Название тренировки',
    'de': 'Name des Trainings',
    'fr': 'Nom de la séance',
    'it': 'Nome allenamento',
    'pt': 'Nome do treino',
    'es': 'Nombre del entrenamiento',
    'id': 'Nama latihan',
    'hi': 'वर्कआउट का नाम',
    'ja': 'ワークアウト名',
    'ko': '운동 이름',
  },
  'workout.delete_title': {
    'en': 'Delete workout?',
    'ru': 'Удалить тренировку?',
    'de': 'Training löschen?',
    'fr': 'Supprimer la séance ?',
    'it': 'Eliminare l\'allenamento?',
    'pt': 'Excluir treino?',
    'es': '¿Eliminar entrenamiento?',
    'id': 'Hapus latihan?',
    'hi': 'वर्कआउट हटाएं?',
    'ja': 'ワークアウトを削除しますか？',
    'ko': '운동을 삭제할까요?',
  },
  'workout.delete_body': {
    'en': 'Its exercises will be removed too.',
    'ru': 'Все упражнения в ней тоже удалятся.',
    'de': 'Die dazugehörigen Übungen werden ebenfalls gelöscht.',
    'fr': 'Ses exercices seront également supprimés.',
    'it': 'Anche gli esercizi verranno rimossi.',
    'pt': 'Os exercícios também serão removidos.',
    'es': 'Sus ejercicios también se eliminarán.',
    'id': 'Latihan di dalamnya juga akan dihapus.',
    'hi': 'इसके एक्सरसाइज़ भी हटा दिए जाएंगे।',
    'ja': '種目もすべて削除されます。',
    'ko': '포함된 종목도 함께 삭제됩니다.',
  },
  // Undo-snackbar после удаления тренировки через SwipeToDelete
  'workout.removed': {
    'en': 'removed',
    'ru': 'удалена',
    'de': 'entfernt',
    'fr': 'supprimée',
    'it': 'rimosso',
    'pt': 'removido',
    'es': 'eliminado',
    'id': 'dihapus',
    'hi': 'हटाया गया',
    'ja': '削除しました',
    'ko': '삭제됨',
  },
  'workout.rename': {
    'en': 'Rename',
    'ru': 'Переименовать',
    'de': 'Umbenennen',
    'fr': 'Renommer',
    'it': 'Rinomina',
    'pt': 'Renomear',
    'es': 'Renombrar',
    'id': 'Ganti nama',
    'hi': 'नाम बदलें',
    'ja': '名前を変更',
    'ko': '이름 변경',
  },
  'workout.rename_title': {
    'en': 'Rename workout',
    'ru': 'Переименовать тренировку',
    'de': 'Training umbenennen',
    'fr': 'Renommer la séance',
    'it': 'Rinomina allenamento',
    'pt': 'Renomear treino',
    'es': 'Renombrar entrenamiento',
    'id': 'Ganti nama latihan',
    'hi': 'वर्कआउट का नाम बदलें',
    'ja': 'ワークアウト名を変更',
    'ko': '운동 이름 변경',
  },
  'workout.add_exercise': {
    'en': 'Add exercise',
    'ru': 'Добавить упражнение',
    'de': 'Übung hinzufügen',
    'fr': 'Ajouter un exercice',
    'it': 'Aggiungi esercizio',
    'pt': 'Adicionar exercício',
    'es': 'Agregar ejercicio',
    'id': 'Tambah latihan',
    'hi': 'एक्सरसाइज़ जोड़ें',
    'ja': '種目を追加',
    'ko': '종목 추가',
  },
  'workout.start_workout': {
    'en': 'Start workout',
    'ru': 'Начать тренировку',
    'de': 'Training starten',
    'fr': 'Démarrer la séance',
    'it': 'Inizia allenamento',
    'pt': 'Iniciar treino',
    'es': 'Iniciar entrenamiento',
    'id': 'Mulai latihan',
    'hi': 'वर्कआउट शुरू करें',
    'ja': 'ワークアウト開始',
    'ko': '운동 시작',
  },
  'workout.empty_exercises': {
    'en': 'No exercises yet —\ntap "Add exercise" to get started',
    'ru': 'Упражнений пока нет —\nнажми «Добавить упражнение»',
    'de': 'Noch keine Übungen —\ntippe auf „Übung hinzufügen"',
    'fr': 'Aucun exercice —\nappuie sur « Ajouter un exercice »',
    'it': 'Nessun esercizio —\npremi "Aggiungi esercizio"',
    'pt': 'Nenhum exercício —\ntoque em "Adicionar exercício"',
    'es': 'Sin ejercicios —\ntoca "Agregar ejercicio"',
    'id': 'Belum ada latihan —\nketuk "Tambah latihan"',
    'hi': 'अभी कोई एक्सरसाइज़ नहीं —\n"एक्सरसाइज़ जोड़ें" दबाएं',
    'ja': '種目なし —\n「種目を追加」をタップ',
    'ko': '종목 없음 —\n"종목 추가"를 탭하세요',
  },
  'workout.add_exercise_title': {
    'en': 'Add exercise',
    'ru': 'Новое упражнение',
    'de': 'Übung hinzufügen',
    'fr': 'Ajouter un exercice',
    'it': 'Aggiungi esercizio',
    'pt': 'Adicionar exercício',
    'es': 'Agregar ejercicio',
    'id': 'Tambah latihan',
    'hi': 'एक्सरसाइज़ जोड़ें',
    'ja': '種目を追加',
    'ko': '종목 추가',
  },
  'workout.edit_exercise_title': {
    'en': 'Edit exercise',
    'ru': 'Редактировать упражнение',
    'de': 'Übung bearbeiten',
    'fr': 'Modifier l\'exercice',
    'it': 'Modifica esercizio',
    'pt': 'Editar exercício',
    'es': 'Editar ejercicio',
    'id': 'Edit latihan',
    'hi': 'एक्सरसाइज़ संपादित करें',
    'ja': '種目を編集',
    'ko': '종목 편집',
  },
  'workout.exercise_name': {
    'en': 'Exercise name',
    'ru': 'Название упражнения',
    'de': 'Name der Übung',
    'fr': 'Nom de l\'exercice',
    'it': 'Nome esercizio',
    'pt': 'Nome do exercício',
    'es': 'Nombre del ejercicio',
    'id': 'Nama latihan',
    'hi': 'एक्सरसाइज़ का नाम',
    'ja': '種目名',
    'ko': '종목 이름',
  },
  'workout.sets': {
    'en': 'Sets',
    'ru': 'Подходы',
    'de': 'Sätze',
    'fr': 'Séries',
    'it': 'Serie',
    'pt': 'Séries',
    'es': 'Series',
    'id': 'Set',
    'hi': 'सेट',
    'ja': 'セット',
    'ko': '세트',
  },
  'workout.reps': {
    'en': 'Reps',
    'ru': 'Повторения',
    'de': 'Wiederholungen',
    'fr': 'Répétitions',
    'it': 'Ripetizioni',
    'pt': 'Repetições',
    'es': 'Repeticiones',
    'id': 'Repetisi',
    'hi': 'रिपीटिशन',
    'ja': 'レップ',
    'ko': '횟수',
  },
  'workout.weight_kg': {
    'en': 'Weight (kg)',
    'ru': 'Вес (кг)',
    'de': 'Gewicht (kg)',
    'fr': 'Poids (kg)',
    'it': 'Peso (kg)',
    'pt': 'Peso (kg)',
    'es': 'Peso (kg)',
    'id': 'Berat (kg)',
    'hi': 'वज़न (kg)',
    'ja': '重量 (kg)',
    'ko': '무게 (kg)',
  },
  'workout.rest_s': {
    'en': 'Rest (s)',
    'ru': 'Отдых (с)',
    'de': 'Pause (s)',
    'fr': 'Repos (s)',
    'it': 'Riposo (s)',
    'pt': 'Descanso (s)',
    'es': 'Descanso (s)',
    'id': 'Istirahat (s)',
    'hi': 'आराम (s)',
    'ja': '休憩 (s)',
    'ko': '휴식 (s)',
  },
  'workout.technique_tip': {
    'en': 'Technique tip',
    'ru': 'Совет по технике',
    'de': 'Technik-Tipp',
    'fr': 'Conseil technique',
    'it': 'Consiglio tecnico',
    'pt': 'Dica de técnica',
    'es': 'Consejo técnico',
    'id': 'Tips teknik',
    'hi': 'तकनीक टिप',
    'ja': 'テクニックのコツ',
    'ko': '기술 팁',
  },
  'workout.optional': {
    'en': 'optional',
    'ru': 'необязательно',
    'de': 'optional',
    'fr': 'facultatif',
    'it': 'facoltativo',
    'pt': 'opcional',
    'es': 'opcional',
    'id': 'opsional',
    'hi': 'वैकल्पिक',
    'ja': '任意',
    'ko': '선택',
  },
  // A3: формат отдыха «по умолчанию» в карточке редактора и плейсхолдере поля.
  // Параметр {value} заменяется на MM:SS (например «Default (02:00)»).
  'workout.rest_default_fmt': {
    'en': 'Default ({value})',
    'ru': 'По умолчанию ({value})',
    'de': 'Standard ({value})',
    'fr': 'Défaut ({value})',
    'it': 'Predefinito ({value})',
    'pt': 'Padrão ({value})',
    'es': 'Predeterminado ({value})',
    'id': 'Default ({value})',
    'hi': 'डिफ़ॉल्ट ({value})',
    'ja': 'デフォルト ({value})',
    'ko': '기본값 ({value})',
  },
  // Trainer screen
  'workout.exercise_of': {
    'en': 'Exercise',
    'ru': 'Упражнение',
    'de': 'Übung',
    'fr': 'Exercice',
    'it': 'Esercizio',
    'pt': 'Exercício',
    'es': 'Ejercicio',
    'id': 'Latihan',
    'hi': 'एक्सरसाइज़',
    'ja': '種目',
    'ko': '종목',
  },
  'workout.of': {
    'en': 'of',
    'ru': 'из',
    'de': 'von',
    'fr': 'sur',
    'it': 'di',
    'pt': 'de',
    'es': 'de',
    'id': 'dari',
    'hi': 'में से',
    'ja': '/',
    'ko': '/',
  },
  'workout.set_label': {
    'en': 'Set',
    'ru': 'Подход',
    'de': 'Satz',
    'fr': 'Série',
    'it': 'Serie',
    'pt': 'Série',
    'es': 'Serie',
    'id': 'Set',
    'hi': 'सेट',
    'ja': 'セット',
    'ko': '세트',
  },
  'workout.reps_label': {
    'en': 'reps',
    'ru': 'повт.',
    'de': 'Wdh.',
    'fr': 'rép.',
    'it': 'rip.',
    'pt': 'rep.',
    'es': 'rep.',
    'id': 'rep.',
    'hi': 'रेप',
    'ja': 'rep',
    'ko': '회',
  },
  'workout.next_label': {
    'en': 'Next',
    'ru': 'Далее',
    'de': 'Weiter',
    'fr': 'Suivant',
    'it': 'Avanti',
    'pt': 'Próximo',
    'es': 'Siguiente',
    'id': 'Berikutnya',
    'hi': 'अगला',
    'ja': '次へ',
    'ko': '다음',
  },
  'workout.stop': {
    'en': 'Stop',
    'ru': 'Остановить',
    'de': 'Stopp',
    'fr': 'Arrêter',
    'it': 'Ferma',
    'pt': 'Parar',
    'es': 'Detener',
    'id': 'Berhenti',
    'hi': 'रोकें',
    'ja': '停止',
    'ko': '중지',
  },
  'workout.stop_title': {
    'en': 'Stop workout?',
    'ru': 'Прервать тренировку?',
    'de': 'Training abbrechen?',
    'fr': 'Arrêter la séance ?',
    'it': 'Fermare l\'allenamento?',
    'pt': 'Parar o treino?',
    'es': '¿Detener el entrenamiento?',
    'id': 'Hentikan latihan?',
    'hi': 'वर्कआउट रोकें?',
    'ja': 'ワークアウトを停止しますか？',
    'ko': '운동을 중지할까요?',
  },
  'workout.stop_body': {
    'en': 'Progress won\'t be saved.',
    'ru': 'Прогресс не сохранится.',
    'de': 'Fortschritt wird nicht gespeichert.',
    'fr': 'La progression ne sera pas sauvegardée.',
    'it': 'Il progresso non verrà salvato.',
    'pt': 'O progresso não será salvo.',
    'es': 'El progreso no se guardará.',
    'id': 'Progres tidak akan disimpan.',
    'hi': 'प्रगति सहेजी नहीं जाएगी।',
    'ja': '進行状況は保存されません。',
    'ko': '진행 상황이 저장되지 않습니다.',
  },
  'workout.continue_btn': {
    'en': 'Continue',
    'ru': 'Продолжить',
    'de': 'Weiter',
    'fr': 'Continuer',
    'it': 'Continua',
    'pt': 'Continuar',
    'es': 'Continuar',
    'id': 'Lanjutkan',
    'hi': 'जारी रखें',
    'ja': '続ける',
    'ko': '계속',
  },
  'workout.set_done': {
    'en': 'Set done',
    'ru': 'Подход выполнен',
    'de': 'Satz beendet',
    'fr': 'Série terminée',
    'it': 'Serie completata',
    'pt': 'Série concluída',
    'es': 'Serie completada',
    'id': 'Set selesai',
    'hi': 'सेट पूरा हुआ',
    'ja': 'セット完了',
    'ko': '세트 완료',
  },
  'workout.rest_phase': {
    'en': 'Rest',
    'ru': 'Отдых',
    'de': 'Pause',
    'fr': 'Repos',
    'it': 'Riposo',
    'pt': 'Descanso',
    'es': 'Descanso',
    'id': 'Istirahat',
    'hi': 'आराम',
    'ja': '休憩',
    'ko': '휴식',
  },
  'workout.skip_rest': {
    'en': 'Skip rest',
    'ru': 'Пропустить отдых',
    'de': 'Pause überspringen',
    'fr': 'Passer le repos',
    'it': 'Salta riposo',
    'pt': 'Pular descanso',
    'es': 'Saltar descanso',
    'id': 'Lewati istirahat',
    'hi': 'आराम छोड़ें',
    'ja': '休憩をスキップ',
    'ko': '휴식 건너뛰기',
  },
  // Пауза/возобновление обратного отсчёта отдыха (фаза rest тренера)
  'workout.pause_rest': {
    'en': 'Pause',
    'ru': 'Пауза',
    'de': 'Pause',
    'fr': 'Pause',
    'it': 'Pausa',
    'pt': 'Pausar',
    'es': 'Pausar',
    'id': 'Jeda',
    'hi': 'रोकें',
    'ja': '一時停止',
    'ko': '일시정지',
  },
  'workout.resume_rest': {
    'en': 'Resume',
    'ru': 'Продолжить',
    'de': 'Fortsetzen',
    'fr': 'Reprendre',
    'it': 'Riprendi',
    'pt': 'Retomar',
    'es': 'Reanudar',
    'id': 'Lanjutkan',
    'hi': 'जारी रखें',
    'ja': '再開',
    'ko': '계속',
  },
  // Индикатор «на паузе» во время замороженного отсчёта отдыха
  'workout.rest_paused': {
    'en': 'Paused',
    'ru': 'На паузе',
    'de': 'Pausiert',
    'fr': 'En pause',
    'it': 'In pausa',
    'pt': 'Pausado',
    'es': 'En pausa',
    'id': 'Dijeda',
    'hi': 'रुका हुआ',
    'ja': '一時停止中',
    'ko': '일시정지됨',
  },
  // Тултипы кнопок ±15с регулировки времени отдыха
  'workout.add_time': {
    'en': 'Add 15 seconds',
    'ru': 'Добавить 15 секунд',
    'de': '15 Sekunden hinzufügen',
    'fr': 'Ajouter 15 secondes',
    'it': 'Aggiungi 15 secondi',
    'pt': 'Adicionar 15 segundos',
    'es': 'Añadir 15 segundos',
    'id': 'Tambah 15 detik',
    'hi': '15 सेकंड जोड़ें',
    'ja': '15秒追加',
    'ko': '15초 추가',
  },
  'workout.subtract_time': {
    'en': 'Subtract 15 seconds',
    'ru': 'Убрать 15 секунд',
    'de': '15 Sekunden abziehen',
    'fr': 'Retirer 15 secondes',
    'it': 'Togli 15 secondi',
    'pt': 'Remover 15 segundos',
    'es': 'Restar 15 segundos',
    'id': 'Kurangi 15 detik',
    'hi': '15 सेकंड घटाएं',
    'ja': '15秒減らす',
    'ko': '15초 빼기',
  },
  'workout.did_it': {
    'en': 'Did it as planned!',
    'ru': 'Сделано по плану!',
    'de': 'Wie geplant erledigt!',
    'fr': 'Fait comme prévu !',
    'it': 'Fatto come pianificato!',
    'pt': 'Feito conforme planejado!',
    'es': '¡Hecho según lo planeado!',
    'id': 'Selesai sesuai rencana!',
    'hi': 'योजना के अनुसार किया!',
    'ja': '計画通りに完了！',
    'ko': '계획대로 완료!',
  },
  // Уведомление об удалении упражнения (Undo-snackbar в workout_editor_screen)
  'workout.exercise_removed': {
    'en': 'Exercise removed',
    'ru': 'Упражнение удалено',
    'de': 'Übung entfernt',
    'fr': 'Exercice supprimé',
    'it': 'Esercizio rimosso',
    'pt': 'Exercício removido',
    'es': 'Ejercicio eliminado',
    'id': 'Latihan dihapus',
    'hi': 'एक्सरसाइज़ हटाई गई',
    'ja': '種目を削除しました',
    'ko': '종목 삭제됨',
  },

  // ---------------------------------------------------------------------------
  // workout.* (Feature B) — set-by-set дневник: ввод фактических reps/weight
  // в тренажёре + экран истории упражнения (exercise_history_screen.dart)
  // ---------------------------------------------------------------------------

  // Подпись поля «вес» в тренажёре (kg)
  'workout.weight_short': {
    'en': 'kg',
    'ru': 'кг',
    'de': 'kg',
    'fr': 'kg',
    'it': 'kg',
    'pt': 'kg',
    'es': 'kg',
    'id': 'kg',
    'hi': 'किग्रा',
    'ja': 'kg',
    'ko': 'kg',
  },
  // Метка «собственный вес» (когда weight не задан)
  'workout.bodyweight': {
    'en': 'Bodyweight',
    'ru': 'Свой вес',
    'de': 'Körpergewicht',
    'fr': 'Poids du corps',
    'it': 'Corpo libero',
    'pt': 'Peso corporal',
    'es': 'Peso corporal',
    'id': 'Berat badan',
    'hi': 'शरीर का वज़न',
    'ja': '自重',
    'ko': '맨몸',
  },
  // #23: секция «Тренировки» в Профиле + глобальное время отдыха по умолчанию
  'workout.section_defaults': {
    'en': 'Workouts',
    'ru': 'Тренировки',
    'de': 'Training',
    'fr': 'Séances',
    'it': 'Allenamenti',
    'pt': 'Treinos',
    'es': 'Entrenamientos',
    'id': 'Latihan',
    'hi': 'वर्कआउट',
    'ja': 'ワークアウト',
    'ko': '운동',
  },
  'workout.rest_default_label': {
    'en': 'Default rest between sets',
    'ru': 'Отдых между подходами по умолчанию',
    'de': 'Standardpause zwischen Sätzen',
    'fr': 'Repos par défaut entre les séries',
    'it': 'Recupero predefinito tra le serie',
    'pt': 'Descanso padrão entre séries',
    'es': 'Descanso predeterminado entre series',
    'id': 'Istirahat default antar set',
    'hi': 'सेट के बीच डिफ़ॉल्ट आराम',
    'ja': 'セット間の既定の休憩',
    'ko': '세트 간 기본 휴식',
  },
  'workout.rest_default_note': {
    'en': 'Used when an exercise has no rest time of its own.',
    'ru': 'Применяется, когда у упражнения не задано своё время отдыха.',
    'de': 'Wird verwendet, wenn eine Übung keine eigene Pausenzeit hat.',
    'fr': 'Utilisé quand un exercice n\'a pas son propre temps de repos.',
    'it': 'Usato quando un esercizio non ha un proprio tempo di recupero.',
    'pt': 'Usado quando um exercício não tem seu próprio tempo de descanso.',
    'es': 'Se usa cuando un ejercicio no tiene su propio tiempo de descanso.',
    'id': 'Dipakai saat latihan tidak punya waktu istirahat sendiri.',
    'hi': 'जब किसी एक्सरसाइज़ का अपना आराम समय न हो तब उपयोग होता है।',
    'ja': '種目に独自の休憩時間がない場合に使われます。',
    'ko': '종목에 자체 휴식 시간이 없을 때 사용됩니다.',
  },
  'workout.rest_default_dialog_title': {
    'en': 'Default rest (seconds)',
    'ru': 'Отдых по умолчанию (секунды)',
    'de': 'Standardpause (Sekunden)',
    'fr': 'Repos par défaut (secondes)',
    'it': 'Recupero predefinito (secondi)',
    'pt': 'Descanso padrão (segundos)',
    'es': 'Descanso predeterminado (segundos)',
    'id': 'Istirahat default (detik)',
    'hi': 'डिफ़ॉल्ट आराम (सेकंड)',
    'ja': '既定の休憩（秒）',
    'ko': '기본 휴식(초)',
  },
  'workout.seconds_short': {
    'en': 's',
    'ru': 'с',
    'de': 's',
    'fr': 's',
    'it': 's',
    'pt': 's',
    'es': 's',
    'id': 'd',
    'hi': 'से',
    'ja': '秒',
    'ko': '초',
  },
  // #22+F: подпись над полями ввода во время отдыха — какой подход логируется
  'workout.logged_set': {
    'en': 'Logged:',
    'ru': 'Записываем:',
    'de': 'Erfasst:',
    'fr': 'Enregistré :',
    'it': 'Registrato:',
    'pt': 'Registrado:',
    'es': 'Registrado:',
    'id': 'Dicatat:',
    'hi': 'दर्ज:',
    'ja': '記録:',
    'ko': '기록:',
  },
  // Заголовок экрана истории упражнения
  'workout.history_title': {
    'en': 'Exercise history',
    'ru': 'История упражнения',
    'de': 'Übungsverlauf',
    'fr': 'Historique de l\'exercice',
    'it': 'Cronologia esercizio',
    'pt': 'Histórico do exercício',
    'es': 'Historial del ejercicio',
    'id': 'Riwayat latihan',
    'hi': 'एक्सरसाइज़ इतिहास',
    'ja': '種目の履歴',
    'ko': '종목 기록',
  },
  // Пустое состояние истории упражнения — подсказывает, как наполнить историю
  'workout.history_empty': {
    'en': 'No history yet.\nLog your sets during a workout to track your progress.',
    'ru': 'Истории пока нет.\nЛогируй подходы во время тренировки, чтобы видеть динамику.',
    'de': 'Noch kein Verlauf.\nErfasse deine Sätze beim Training, um Fortschritte zu sehen.',
    'fr': 'Pas encore d\'historique.\nEnregistre tes séries pendant l\'entraînement pour suivre ta progression.',
    'it': 'Ancora nessuna cronologia.\nRegistra le serie durante l\'allenamento per seguire i progressi.',
    'pt': 'Sem histórico ainda.\nRegistre suas séries durante o treino para acompanhar o progresso.',
    'es': 'Aún no hay historial.\nRegistra tus series durante el entrenamiento para ver tu progreso.',
    'id': 'Belum ada riwayat.\nCatat set saat latihan untuk melihat progres.',
    'hi': 'अभी कोई इतिहास नहीं।\nप्रगति देखने के लिए वर्कआउट के दौरान अपने सेट लॉग करें।',
    'ja': 'まだ履歴がありません。\nワークアウト中にセットを記録すると進捗が見えます。',
    'ko': '아직 기록이 없습니다.\n운동 중 세트를 기록하면 변화를 확인할 수 있어요.',
  },
  // Вкладка-переключатель «Тренировки» (список программ) — workouts_screen.dart
  'workout.tab_workouts': {
    'en': 'Workouts',
    'ru': 'Тренировки',
    'de': 'Training',
    'fr': 'Séances',
    'it': 'Allenamenti',
    'pt': 'Treinos',
    'es': 'Entrenamientos',
    'id': 'Latihan',
    'hi': 'वर्कआउट',
    'ja': 'ワークアウト',
    'ko': '운동',
  },
  // Вкладка-переключатель «Дневник» (прогресс/история) — workouts_screen.dart
  'workout.tab_diary': {
    'en': 'Diary',
    'ru': 'Дневник',
    'de': 'Tagebuch',
    'fr': 'Journal',
    'it': 'Diario',
    'pt': 'Diário',
    'es': 'Diario',
    'id': 'Jurnal',
    'hi': 'डायरी',
    'ja': '日記',
    'ko': '일지',
  },
  // Заголовок секции «Прошлые сессии» во вкладке «Дневник»
  'workout.diary_sessions': {
    'en': 'Past sessions',
    'ru': 'Прошлые сессии',
    'de': 'Frühere Einheiten',
    'fr': 'Séances passées',
    'it': 'Sessioni passate',
    'pt': 'Sessões anteriores',
    'es': 'Sesiones anteriores',
    'id': 'Sesi sebelumnya',
    'hi': 'पिछले सत्र',
    'ja': '過去のセッション',
    'ko': '지난 세션',
  },
  // Заголовок секции «Прогресс по упражнениям» во вкладке «Дневник»
  'workout.diary_progress': {
    'en': 'Exercise progress',
    'ru': 'Прогресс по упражнениям',
    'de': 'Übungsfortschritt',
    'fr': 'Progression des exercices',
    'it': 'Progressi esercizi',
    'pt': 'Progresso dos exercícios',
    'es': 'Progreso de ejercicios',
    'id': 'Progres latihan',
    'hi': 'एक्सरसाइज़ प्रगति',
    'ja': '種目の進捗',
    'ko': '종목 진행 상황',
  },
  // Пустое состояние всего «Дневника», когда нет ни сессий, ни логов подходов
  'workout.diary_empty': {
    'en': 'No history yet.\nLog your sets during a workout to track your progress.',
    'ru': 'Истории пока нет.\nЛогируй подходы во время тренировки, чтобы видеть динамику.',
    'de': 'Noch kein Verlauf.\nErfasse deine Sätze beim Training, um Fortschritte zu sehen.',
    'fr': 'Pas encore d\'historique.\nEnregistre tes séries pendant l\'entraînement pour suivre ta progression.',
    'it': 'Ancora nessuna cronologia.\nRegistra le serie durante l\'allenamento per seguire i progressi.',
    'pt': 'Sem histórico ainda.\nRegistre suas séries durante o treino para acompanhar o progresso.',
    'es': 'Aún no hay historial.\nRegistra tus series durante el entrenamiento para ver tu progreso.',
    'id': 'Belum ada riwayat.\nCatat set saat latihan untuk melihat progres.',
    'hi': 'अभी कोई इतिहास नहीं।\nप्रगति देखने के लिए वर्कआउट के दौरान अपने सेट लॉग करें।',
    'ja': 'まだ履歴がありません。\nワークアウト中にセットを記録すると進捗が見えます。',
    'ko': '아직 기록이 없습니다.\n운동 중 세트를 기록하면 변화를 확인할 수 있어요.',
  },
  // --- Группы мышц (Part 2): заголовки группировки «Прогресс по упражнениям» ---
  'muscle.push': {
    'en': 'Push (chest · shoulders · triceps)',
    'ru': 'Жим (грудь · плечи · трицепс)',
    'de': 'Druck (Brust · Schultern · Trizeps)',
    'fr': 'Poussée (pecs · épaules · triceps)',
    'it': 'Spinta (petto · spalle · tricipiti)',
    'pt': 'Empurrar (peito · ombros · tríceps)',
    'es': 'Empuje (pecho · hombros · tríceps)',
    'id': 'Dorong (dada · bahu · trisep)',
    'hi': 'पुश (छाती · कंधे · ट्राइसेप्स)',
    'ja': 'プッシュ（胸・肩・三頭）',
    'ko': '푸시 (가슴 · 어깨 · 삼두)',
  },
  'muscle.pull': {
    'en': 'Pull (back · biceps)',
    'ru': 'Тяга (спина · бицепс)',
    'de': 'Zug (Rücken · Bizeps)',
    'fr': 'Tirage (dos · biceps)',
    'it': 'Trazione (schiena · bicipiti)',
    'pt': 'Puxar (costas · bíceps)',
    'es': 'Tirón (espalda · bíceps)',
    'id': 'Tarik (punggung · bisep)',
    'hi': 'पुल (पीठ · बाइसेप्स)',
    'ja': 'プル（背中・二頭）',
    'ko': '풀 (등 · 이두)',
  },
  'muscle.legs': {
    'en': 'Legs (quads · hamstrings · glutes)',
    'ru': 'Ноги (квадрицепс · бицепс бедра · ягодицы)',
    'de': 'Beine (Quadrizeps · Beinbeuger · Gesäß)',
    'fr': 'Jambes (quadriceps · ischio · fessiers)',
    'it': 'Gambe (quadricipiti · femorali · glutei)',
    'pt': 'Pernas (quadríceps · posteriores · glúteos)',
    'es': 'Piernas (cuádriceps · isquios · glúteos)',
    'id': 'Kaki (paha depan · paha belakang · bokong)',
    'hi': 'पैर (क्वाड्स · हैमस्ट्रिंग · ग्लूट्स)',
    'ja': '脚（大腿四頭・ハム・臀部）',
    'ko': '다리 (대퇴사두 · 햄스트링 · 둔근)',
  },
  'muscle.core': {
    'en': 'Core',
    'ru': 'Кор',
    'de': 'Rumpf',
    'fr': 'Gainage',
    'it': 'Core',
    'pt': 'Core',
    'es': 'Core',
    'id': 'Inti tubuh',
    'hi': 'कोर',
    'ja': '体幹',
    'ko': '코어',
  },
  'muscle.cardio': {
    'en': 'Cardio',
    'ru': 'Кардио',
    'de': 'Cardio',
    'fr': 'Cardio',
    'it': 'Cardio',
    'pt': 'Cardio',
    'es': 'Cardio',
    'id': 'Kardio',
    'hi': 'कार्डियो',
    'ja': 'カーディオ',
    'ko': '유산소',
  },
  'muscle.other': {
    'en': 'Other',
    'ru': 'Другое',
    'de': 'Sonstige',
    'fr': 'Autres',
    'it': 'Altro',
    'pt': 'Outros',
    'es': 'Otros',
    'id': 'Lainnya',
    'hi': 'अन्य',
    'ja': 'その他',
    'ko': '기타',
  },
  // ---------------------------------------------------------------------------
  // exercise.detail.* — строки листа деталей упражнения (exercise_detail_sheet.dart)
  // ---------------------------------------------------------------------------

  // Заголовки секций
  'exercise.detail.technique': {
    'en': 'Technique',
    'ru': 'Техника выполнения',
    'de': 'Technik',
    'fr': 'Technique',
    'it': 'Tecnica',
    'pt': 'Técnica',
    'es': 'Técnica',
    'id': 'Teknik',
    'hi': 'तकनीक',
    'ja': 'テクニック',
    'ko': '기술',
  },
  'exercise.detail.mistakes': {
    'en': 'Common mistakes',
    'ru': 'Типичные ошибки',
    'de': 'Häufige Fehler',
    'fr': 'Erreurs courantes',
    'it': 'Errori comuni',
    'pt': 'Erros comuns',
    'es': 'Errores frecuentes',
    'id': 'Kesalahan umum',
    'hi': 'सामान्य गलतियाँ',
    'ja': 'よくあるミス',
    'ko': '자주 하는 실수',
  },
  // Видео-кнопка и уведомление
  'exercise.detail.watch_video': {
    'en': 'Watch technique video',
    'ru': 'Смотреть видео техники',
    'de': 'Technik-Video ansehen',
    'fr': 'Voir la vidéo technique',
    'it': 'Guarda il video tecnico',
    'pt': 'Assistir ao vídeo técnico',
    'es': 'Ver video de técnica',
    'id': 'Tonton video teknik',
    'hi': 'तकनीक वीडियो देखें',
    'ja': 'テクニック動画を見る',
    'ko': '기술 영상 보기',
  },
  'exercise.detail.link_copied': {
    'en': 'Link copied',
    'ru': 'Ссылка скопирована',
    'de': 'Link kopiert',
    'fr': 'Lien copié',
    'it': 'Link copiato',
    'pt': 'Link copiado',
    'es': 'Enlace copiado',
    'id': 'Tautan disalin',
    'hi': 'लिंक कॉपी हो गया',
    'ja': 'リンクをコピーしました',
    'ko': '링크 복사됨',
  },
  // Метка «отдых» в строке параметров по умолчанию
  'exercise.detail.rest': {
    'en': 'rest',
    'ru': 'отдых',
    'de': 'Pause',
    'fr': 'repos',
    'it': 'riposo',
    'pt': 'descanso',
    'es': 'descanso',
    'id': 'istirahat',
    'hi': 'आराम',
    'ja': '休憩',
    'ko': '휴식',
  },
  // Тултип кнопки «инфо» в тренажёре
  'exercise.detail.info_tooltip': {
    'en': 'Technique guide',
    'ru': 'Руководство по технике',
    'de': 'Technik-Leitfaden',
    'fr': 'Guide de technique',
    'it': 'Guida alla tecnica',
    'pt': 'Guia de técnica',
    'es': 'Guía de técnica',
    'id': 'Panduan teknik',
    'hi': 'तकनीक गाइड',
    'ja': 'テクニックガイド',
    'ko': '기술 가이드',
  },

  // ---------------------------------------------------------------------------
  // muscle_group.* — чип «группа мышц» в exercise_detail_sheet.dart
  // (без пересечения с muscle.push/pull/legs/core/cardio/other — новые ключи)
  // ---------------------------------------------------------------------------

  'muscle_group.legs': {
    'en': 'Legs',
    'ru': 'Ноги',
    'de': 'Beine',
    'fr': 'Jambes',
    'it': 'Gambe',
    'pt': 'Pernas',
    'es': 'Piernas',
    'id': 'Kaki',
    'hi': 'पैर',
    'ja': '脚',
    'ko': '다리',
  },
  'muscle_group.back': {
    'en': 'Back',
    'ru': 'Спина',
    'de': 'Rücken',
    'fr': 'Dos',
    'it': 'Schiena',
    'pt': 'Costas',
    'es': 'Espalda',
    'id': 'Punggung',
    'hi': 'पीठ',
    'ja': '背中',
    'ko': '등',
  },
  'muscle_group.chest': {
    'en': 'Chest',
    'ru': 'Грудь',
    'de': 'Brust',
    'fr': 'Pectoraux',
    'it': 'Petto',
    'pt': 'Peito',
    'es': 'Pecho',
    'id': 'Dada',
    'hi': 'छाती',
    'ja': '胸',
    'ko': '가슴',
  },
  'muscle_group.shoulders': {
    'en': 'Shoulders',
    'ru': 'Плечи',
    'de': 'Schultern',
    'fr': 'Épaules',
    'it': 'Spalle',
    'pt': 'Ombros',
    'es': 'Hombros',
    'id': 'Bahu',
    'hi': 'कंधे',
    'ja': '肩',
    'ko': '어깨',
  },
  'muscle_group.arms': {
    'en': 'Arms',
    'ru': 'Руки',
    'de': 'Arme',
    'fr': 'Bras',
    'it': 'Braccia',
    'pt': 'Braços',
    'es': 'Brazos',
    'id': 'Lengan',
    'hi': 'बाँहें',
    'ja': '腕',
    'ko': '팔',
  },
  'muscle_group.core': {
    'en': 'Core',
    'ru': 'Кор',
    'de': 'Rumpf',
    'fr': 'Gainage',
    'it': 'Core',
    'pt': 'Core',
    'es': 'Core',
    'id': 'Inti tubuh',
    'hi': 'कोर',
    'ja': '体幹',
    'ko': '코어',
  },
  'muscle_group.full_body': {
    'en': 'Full body',
    'ru': 'Всё тело',
    'de': 'Ganzkörper',
    'fr': 'Corps entier',
    'it': 'Corpo intero',
    'pt': 'Corpo inteiro',
    'es': 'Cuerpo completo',
    'id': 'Seluruh tubuh',
    'hi': 'पूरा शरीर',
    'ja': '全身',
    'ko': '전신',
  },
  'muscle_group.cardio': {
    'en': 'Cardio',
    'ru': 'Кардио',
    'de': 'Cardio',
    'fr': 'Cardio',
    'it': 'Cardio',
    'pt': 'Cardio',
    'es': 'Cardio',
    'id': 'Kardio',
    'hi': 'कार्डियो',
    'ja': 'カーディオ',
    'ko': '유산소',
  },

  // ---------------------------------------------------------------------------
  // equipment.* — чип «инвентарь» в exercise_detail_sheet.dart
  // ---------------------------------------------------------------------------

  'equipment.none': {
    'en': 'No equipment',
    'ru': 'Без инвентаря',
    'de': 'Kein Gerät',
    'fr': 'Sans équipement',
    'it': 'Nessuna attrezzatura',
    'pt': 'Sem equipamento',
    'es': 'Sin equipamiento',
    'id': 'Tanpa alat',
    'hi': 'कोई उपकरण नहीं',
    'ja': '器具なし',
    'ko': '기구 없음',
  },
  'equipment.dumbbell': {
    'en': 'Dumbbell',
    'ru': 'Гантель',
    'de': 'Kurzhantel',
    'fr': 'Haltère',
    'it': 'Manubrio',
    'pt': 'Haltere',
    'es': 'Mancuerna',
    'id': 'Dumbel',
    'hi': 'डंबल',
    'ja': 'ダンベル',
    'ko': '덤벨',
  },
  'equipment.barbell': {
    'en': 'Barbell',
    'ru': 'Штанга',
    'de': 'Langhantel',
    'fr': 'Barre',
    'it': 'Bilanciere',
    'pt': 'Barra',
    'es': 'Barra',
    'id': 'Barbel',
    'hi': 'बारबेल',
    'ja': 'バーベル',
    'ko': '바벨',
  },
  'equipment.machine': {
    'en': 'Machine',
    'ru': 'Тренажёр',
    'de': 'Gerät',
    'fr': 'Machine',
    'it': 'Macchina',
    'pt': 'Máquina',
    'es': 'Máquina',
    'id': 'Mesin',
    'hi': 'मशीन',
    'ja': 'マシン',
    'ko': '기계',
  },
  'equipment.bodyweight': {
    'en': 'Bodyweight',
    'ru': 'Без отягощений',
    'de': 'Körpergewicht',
    'fr': 'Poids du corps',
    'it': 'Corpo libero',
    'pt': 'Peso corporal',
    'es': 'Peso corporal',
    'id': 'Berat badan',
    'hi': 'शरीर के वज़न से',
    'ja': '自重',
    'ko': '맨몸',
  },
  'equipment.band': {
    'en': 'Resistance band',
    'ru': 'Резиновая лента',
    'de': 'Widerstandsband',
    'fr': 'Élastique',
    'it': 'Elastico',
    'pt': 'Faixa elástica',
    'es': 'Banda elástica',
    'id': 'Resistance band',
    'hi': 'रेज़िस्टेंस बैंड',
    'ja': 'チューブ',
    'ko': '밴드',
  },
  'equipment.kettlebell': {
    'en': 'Kettlebell',
    'ru': 'Гиря',
    'de': 'Kettlebell',
    'fr': 'Kettlebell',
    'it': 'Kettlebell',
    'pt': 'Kettlebell',
    'es': 'Pesa rusa',
    'id': 'Kettlebell',
    'hi': 'केटलबेल',
    'ja': 'ケトルベル',
    'ko': '케틀벨',
  },

  // ---------------------------------------------------------------------------
  // difficulty.* — чип «сложность» в exercise_detail_sheet.dart
  // ---------------------------------------------------------------------------

  'difficulty.beginner': {
    'en': 'Beginner',
    'ru': 'Начинающий',
    'de': 'Anfänger',
    'fr': 'Débutant',
    'it': 'Principiante',
    'pt': 'Iniciante',
    'es': 'Principiante',
    'id': 'Pemula',
    'hi': 'शुरुआती',
    'ja': '初級',
    'ko': '초급',
  },
  'difficulty.intermediate': {
    'en': 'Intermediate',
    'ru': 'Средний уровень',
    'de': 'Mittelstufe',
    'fr': 'Intermédiaire',
    'it': 'Intermedio',
    'pt': 'Intermediário',
    'es': 'Intermedio',
    'id': 'Menengah',
    'hi': 'मध्यम',
    'ja': '中級',
    'ko': '중급',
  },
  'difficulty.advanced': {
    'en': 'Advanced',
    'ru': 'Продвинутый',
    'de': 'Fortgeschritten',
    'fr': 'Avancé',
    'it': 'Avanzato',
    'pt': 'Avançado',
    'es': 'Avanzado',
    'id': 'Lanjutan',
    'hi': 'उन्नत',
    'ja': '上級',
    'ko': '고급',
  },

  // Журнал одной сессии (Part 1): заголовок-fallback, если дата не передана
  'workout.session_title': {
    'en': 'Workout',
    'ru': 'Тренировка',
    'de': 'Training',
    'fr': 'Séance',
    'it': 'Allenamento',
    'pt': 'Treino',
    'es': 'Entrenamiento',
    'id': 'Latihan',
    'hi': 'वर्कआउट',
    'ja': 'ワークアウト',
    'ko': '운동',
  },
  // Пустой журнал сессии — подходы в этой тренировке не логировались
  'workout.session_empty': {
    'en': 'No sets were logged in this workout.',
    'ru': 'В этой тренировке подходы не логировались.',
    'de': 'In diesem Training wurden keine Sätze erfasst.',
    'fr': 'Aucune série enregistrée pour cette séance.',
    'it': 'Nessuna serie registrata in questo allenamento.',
    'pt': 'Nenhuma série registrada neste treino.',
    'es': 'No se registraron series en este entrenamiento.',
    'id': 'Tidak ada set yang dicatat di latihan ini.',
    'hi': 'इस वर्कआउट में कोई सेट लॉग नहीं हुआ।',
    'ja': 'このワークアウトではセットが記録されていません。',
    'ko': '이 운동에는 기록된 세트가 없습니다.',
  },
  // Префикс подхода с номером в журнале сессии: «Set {n}» / «Подход {n}»
  'workout.set_n': {
    'en': 'Set {n}',
    'ru': 'Подход {n}',
    'de': 'Satz {n}',
    'fr': 'Série {n}',
    'it': 'Serie {n}',
    'pt': 'Série {n}',
    'es': 'Serie {n}',
    'id': 'Set {n}',
    'hi': 'सेट {n}',
    'ja': 'セット{n}',
    'ko': '{n}세트',
  },
  // Имя-fallback, если упражнение удалено из шаблона, но его логи остались
  'workout.deleted_exercise': {
    'en': 'Deleted exercise',
    'ru': 'Удалённое упражнение',
    'de': 'Gelöschte Übung',
    'fr': 'Exercice supprimé',
    'it': 'Esercizio eliminato',
    'pt': 'Exercício excluído',
    'es': 'Ejercicio eliminado',
    'id': 'Latihan dihapus',
    'hi': 'हटाई गई एक्सरसाइज़',
    'ja': '削除された種目',
    'ko': '삭제된 종목',
  },
  // Подпись над спарклайном динамики веса
  'workout.weight_dynamics': {
    'en': 'Top working weight',
    'ru': 'Рабочий вес (макс.)',
    'de': 'Top-Arbeitsgewicht',
    'fr': 'Charge de travail max',
    'it': 'Peso di lavoro max',
    'pt': 'Carga de trabalho máx.',
    'es': 'Peso de trabajo máx.',
    'id': 'Beban kerja tertinggi',
    'hi': 'टॉप वर्किंग वेट',
    'ja': '最大ワーキング重量',
    'ko': '최고 작업 중량',
  },
  // Подсказка/кнопка перехода к истории упражнения (tooltip)
  'workout.view_history': {
    'en': 'History',
    'ru': 'История',
    'de': 'Verlauf',
    'fr': 'Historique',
    'it': 'Cronologia',
    'pt': 'Histórico',
    'es': 'Historial',
    'id': 'Riwayat',
    'hi': 'इतिहास',
    'ja': '履歴',
    'ko': '기록',
  },

  // ---------------------------------------------------------------------------
  // breathing.*  —  breathing_screen.dart
  // ---------------------------------------------------------------------------

  'breathing.title': {
    'en': 'Breathing',
    'ru': 'Дыхание',
    'de': 'Atemübungen',
    'fr': 'Respiration',
    'it': 'Respirazione',
    'pt': 'Respiração',
    'es': 'Respiración',
    'id': 'Pernapasan',
    'hi': 'श्वास',
    'ja': '呼吸',
    'ko': '호흡',
  },
  'breathing.choose_technique': {
    'en': 'Choose a technique',
    'ru': 'Выбери технику',
    'de': 'Technik wählen',
    'fr': 'Choisir une technique',
    'it': 'Scegli una tecnica',
    'pt': 'Escolha uma técnica',
    'es': 'Elige una técnica',
    'id': 'Pilih teknik',
    'hi': 'एक तकनीक चुनें',
    'ja': 'テクニックを選ぶ',
    'ko': '기법 선택',
  },
  'breathing.duration': {
    'en': 'Duration',
    'ru': 'Длительность',
    'de': 'Dauer',
    'fr': 'Durée',
    'it': 'Durata',
    'pt': 'Duração',
    'es': 'Duración',
    'id': 'Durasi',
    'hi': 'अवधि',
    'ja': '時間',
    'ko': '시간',
  },
  'breathing.start': {
    'en': 'Start',
    'ru': 'Начать',
    'de': 'Starten',
    'fr': 'Démarrer',
    'it': 'Inizia',
    'pt': 'Iniciar',
    'es': 'Iniciar',
    'id': 'Mulai',
    'hi': 'शुरू करें',
    'ja': '開始',
    'ko': '시작',
  },
  'breathing.stop': {
    'en': 'Stop',
    'ru': 'Остановить',
    'de': 'Stopp',
    'fr': 'Arrêter',
    'it': 'Ferma',
    'pt': 'Parar',
    'es': 'Detener',
    'id': 'Berhenti',
    'hi': 'रोकें',
    'ja': '停止',
    'ko': '중지',
  },
  'breathing.session_complete': {
    'en': 'Session complete',
    'ru': 'Сессия завершена',
    'de': 'Sitzung abgeschlossen',
    'fr': 'Séance terminée',
    'it': 'Sessione completata',
    'pt': 'Sessão concluída',
    'es': 'Sesión completada',
    'id': 'Sesi selesai',
    'hi': 'सत्र पूरा हुआ',
    'ja': 'セッション完了',
    'ko': '세션 완료',
  },
  // Фазы дыхания — используются в switch по label из breathing_engine.dart
  'breathing.inhale': {
    'en': 'Inhale',
    'ru': 'Вдох',
    'de': 'Einatmen',
    'fr': 'Inspirez',
    'it': 'Inspira',
    'pt': 'Inspire',
    'es': 'Inhala',
    'id': 'Hirup',
    'hi': 'सांस लें',
    'ja': '吸う',
    'ko': '들이쉬기',
  },
  'breathing.exhale': {
    'en': 'Exhale',
    'ru': 'Выдох',
    'de': 'Ausatmen',
    'fr': 'Expirez',
    'it': 'Espira',
    'pt': 'Expire',
    'es': 'Exhala',
    'id': 'Hembuskan',
    'hi': 'सांस छोड़ें',
    'ja': '吐く',
    'ko': '내쉬기',
  },
  'breathing.hold': {
    'en': 'Hold',
    'ru': 'Задержка',
    'de': 'Halten',
    'fr': 'Retenez',
    'it': 'Trattieni',
    'pt': 'Segure',
    'es': 'Retén',
    'id': 'Tahan',
    'hi': 'रोकें',
    'ja': '止める',
    'ko': '참기',
  },

  // Пользовательские техники — breathing_editor_screen.dart / breathing_screen.dart
  'breathing.create_title': {
    'en': 'Create technique',
    'ru': 'Создать технику',
    'de': 'Technik erstellen',
    'fr': 'Créer une technique',
    'it': 'Crea tecnica',
    'pt': 'Criar técnica',
    'es': 'Crear técnica',
    'id': 'Buat teknik',
    'hi': 'तकनीक बनाएं',
    'ja': 'テクニックを作成',
    'ko': '기법 만들기',
  },
  'breathing.create_button': {
    'en': 'New technique',
    'ru': 'Новая техника',
    'de': 'Neue Technik',
    'fr': 'Nouvelle technique',
    'it': 'Nuova tecnica',
    'pt': 'Nova técnica',
    'es': 'Nueva técnica',
    'id': 'Teknik baru',
    'hi': 'नई तकनीक',
    'ja': '新しいテクニック',
    'ko': '새 기법',
  },
  'breathing.name_label': {
    'en': 'Technique name',
    'ru': 'Название техники',
    'de': 'Name der Technik',
    'fr': 'Nom de la technique',
    'it': 'Nome della tecnica',
    'pt': 'Nome da técnica',
    'es': 'Nombre de la técnica',
    'id': 'Nama teknik',
    'hi': 'तकनीक का नाम',
    'ja': 'テクニック名',
    'ko': '기법 이름',
  },
  'breathing.phases': {
    'en': 'Phases',
    'ru': 'Фазы',
    'de': 'Phasen',
    'fr': 'Phases',
    'it': 'Fasi',
    'pt': 'Fases',
    'es': 'Fases',
    'id': 'Fase',
    'hi': 'चरण',
    'ja': 'フェーズ',
    'ko': '단계',
  },
  'breathing.add_phase': {
    'en': 'Add phase',
    'ru': 'Добавить фазу',
    'de': 'Phase hinzufügen',
    'fr': 'Ajouter une phase',
    'it': 'Aggiungi fase',
    'pt': 'Adicionar fase',
    'es': 'Añadir fase',
    'id': 'Tambah fase',
    'hi': 'चरण जोड़ें',
    'ja': 'フェーズを追加',
    'ko': '단계 추가',
  },
  'breathing.cycles': {
    'en': 'Cycles',
    'ru': 'Циклы',
    'de': 'Zyklen',
    'fr': 'Cycles',
    'it': 'Cicli',
    'pt': 'Ciclos',
    'es': 'Ciclos',
    'id': 'Siklus',
    'hi': 'चक्र',
    'ja': 'サイクル',
    'ko': '주기',
  },
  'breathing.total': {
    'en': 'Total',
    'ru': 'Итого',
    'de': 'Gesamt',
    'fr': 'Total',
    'it': 'Totale',
    'pt': 'Total',
    'es': 'Total',
    'id': 'Total',
    'hi': 'कुल',
    'ja': '合計',
    'ko': '총',
  },
  'breathing.removed': {
    'en': 'removed',
    'ru': 'удалена',
    'de': 'entfernt',
    'fr': 'supprimée',
    'it': 'rimossa',
    'pt': 'removida',
    'es': 'eliminada',
    'id': 'dihapus',
    'hi': 'हटाया गया',
    'ja': '削除しました',
    'ko': '삭제됨',
  },
  'breathing.preset_box': {
    'en': 'Box 4-4-4-4',
    'ru': 'Квадрат 4-4-4-4',
    'de': 'Box 4-4-4-4',
    'fr': 'Box 4-4-4-4',
    'it': 'Box 4-4-4-4',
    'pt': 'Caixa 4-4-4-4',
    'es': 'Caja 4-4-4-4',
    'id': 'Kotak 4-4-4-4',
    'hi': 'बॉक्स 4-4-4-4',
    'ja': 'ボックス 4-4-4-4',
    'ko': '박스 4-4-4-4',
  },
  'breathing.preset_calm': {
    'en': 'Calm 4-7-8',
    'ru': 'Спокойствие 4-7-8',
    'de': 'Ruhe 4-7-8',
    'fr': 'Calme 4-7-8',
    'it': 'Calma 4-7-8',
    'pt': 'Calma 4-7-8',
    'es': 'Calma 4-7-8',
    'id': 'Tenang 4-7-8',
    'hi': 'शांति 4-7-8',
    'ja': '落ち着き 4-7-8',
    'ko': '평온 4-7-8',
  },
  'breathing.preset_simple': {
    'en': 'Simple 5-5',
    'ru': 'Простое 5-5',
    'de': 'Einfach 5-5',
    'fr': 'Simple 5-5',
    'it': 'Semplice 5-5',
    'pt': 'Simples 5-5',
    'es': 'Simple 5-5',
    'id': 'Sederhana 5-5',
    'hi': 'सरल 5-5',
    'ja': 'シンプル 5-5',
    'ko': '심플 5-5',
  },

  // ---------------------------------------------------------------------------
  // posture.*  —  posture_screen.dart
  // ---------------------------------------------------------------------------

  'posture.title': {
    'en': 'Posture',
    'ru': 'Осанка',
    'de': 'Haltung',
    'fr': 'Posture',
    'it': 'Postura',
    'pt': 'Postura',
    'es': 'Postura',
    'id': 'Postur',
    'hi': 'आसन',
    'ja': '姿勢',
    'ko': '자세',
  },
  'posture.reminders_title': {
    'en': 'Sit-up-straight reminders',
    'ru': 'Напоминания выпрямиться',
    'de': 'Erinnerungen zur Körperhaltung',
    'fr': 'Rappels de redressement',
    'it': 'Promemoria postura dritta',
    'pt': 'Lembretes para sentar ereto',
    'es': 'Recordatorios de postura',
    'id': 'Pengingat duduk tegak',
    'hi': 'सीधे बैठने के रिमाइंडर',
    'ja': '姿勢を正すリマインダー',
    'ko': '바른 자세 알림',
  },
  'posture.reminders_subtitle': {
    'en': 'Every 2 hours, 10:00–18:00',
    'ru': 'Каждые 2 часа, 10:00–18:00',
    'de': 'Alle 2 Stunden, 10:00–18:00',
    'fr': 'Toutes les 2 heures, 10:00–18:00',
    'it': 'Ogni 2 ore, 10:00–18:00',
    'pt': 'A cada 2 horas, 10:00–18:00',
    'es': 'Cada 2 horas, 10:00–18:00',
    'id': 'Setiap 2 jam, 10:00–18:00',
    'hi': 'हर 2 घंटे, 10:00–18:00',
    'ja': '2時間ごと、10:00–18:00',
    'ko': '2시간마다, 10:00–18:00',
  },
  'posture.permission_required': {
    'en': 'Notification permission required. Enable it in system settings.',
    'ru': 'Нужно разрешение на уведомления. Включи его в настройках системы.',
    'de': 'Benachrichtigungserlaubnis erforderlich. Aktiviere sie in den Systemeinstellungen.',
    'fr': 'Autorisation de notification requise. Active-la dans les paramètres système.',
    'it': 'Permesso notifiche richiesto. Abilitalo nelle impostazioni di sistema.',
    'pt': 'Permissão de notificação necessária. Ative nas configurações do sistema.',
    'es': 'Se requiere permiso de notificaciones. Actívalo en los ajustes del sistema.',
    'id': 'Izin notifikasi diperlukan. Aktifkan di pengaturan sistem.',
    'hi': 'नोटिफिकेशन की अनुमति आवश्यक है। सिस्टम सेटिंग्स में सक्षम करें।',
    'ja': '通知の許可が必要です。システム設定で有効にしてください。',
    'ko': '알림 권한이 필요합니다. 시스템 설정에서 활성화하세요.',
  },
  'posture.exercises': {
    'en': 'Exercises',
    'ru': 'Упражнения',
    'de': 'Übungen',
    'fr': 'Exercices',
    'it': 'Esercizi',
    'pt': 'Exercícios',
    'es': 'Ejercicios',
    'id': 'Latihan',
    'hi': 'एक्सरसाइज़',
    'ja': 'エクササイズ',
    'ko': '운동',
  },

  // ---------------------------------------------------------------------------
  // meditation.*  —  meditation_screen.dart
  // ---------------------------------------------------------------------------

  'meditation.title': {
    'en': 'Meditation',
    'ru': 'Медитация',
    'de': 'Meditation',
    'fr': 'Méditation',
    'it': 'Meditazione',
    'pt': 'Meditação',
    'es': 'Meditación',
    'id': 'Meditasi',
    'hi': 'ध्यान',
    'ja': '瞑想',
    'ko': '명상',
  },
  'meditation.session_complete': {
    'en': 'Session complete',
    'ru': 'Сессия завершена',
    'de': 'Sitzung abgeschlossen',
    'fr': 'Séance terminée',
    'it': 'Sessione completata',
    'pt': 'Sessão concluída',
    'es': 'Sesión completada',
    'id': 'Sesi selesai',
    'hi': 'सत्र पूरा हुआ',
    'ja': 'セッション完了',
    'ko': '세션 완료',
  },
  'meditation.session_complete_body': {
    'en': 'Take a moment to notice how you feel.',
    'ru': 'Отметь, как ты себя чувствуешь.',
    'de': 'Nimm dir einen Moment, um zu bemerken, wie du dich fühlst.',
    'fr': 'Prends un moment pour remarquer ce que tu ressens.',
    'it': 'Prenditi un momento per notare come ti senti.',
    'pt': 'Reserve um momento para perceber como você se sente.',
    'es': 'Tómate un momento para notar cómo te sientes.',
    'id': 'Luangkan waktu untuk merasakan kondisimu.',
    'hi': 'एक पल रुककर महसूस करें कि आप कैसा महसूस कर रहे हैं।',
    'ja': '今の気持ちを静かに感じてみましょう。',
    'ko': '잠시 멈추고 지금 내 상태를 느껴보세요.',
  },
  'meditation.next': {
    'en': 'Next',
    'ru': 'Далее',
    'de': 'Weiter',
    'fr': 'Suivant',
    'it': 'Avanti',
    'pt': 'Próximo',
    'es': 'Siguiente',
    'id': 'Berikutnya',
    'hi': 'अगला',
    'ja': '次へ',
    'ko': '다음',
  },
  'meditation.finish': {
    'en': 'Finish',
    'ru': 'Завершить',
    'de': 'Beenden',
    'fr': 'Terminer',
    'it': 'Finisci',
    'pt': 'Concluir',
    'es': 'Finalizar',
    'id': 'Selesai',
    'hi': 'समाप्त करें',
    'ja': '終了',
    'ko': '완료',
  },
  'meditation.end_session': {
    'en': 'End session',
    'ru': 'Завершить сессию',
    'de': 'Sitzung beenden',
    'fr': 'Terminer la séance',
    'it': 'Termina sessione',
    'pt': 'Encerrar sessão',
    'es': 'Finalizar sesión',
    'id': 'Akhiri sesi',
    'hi': 'सत्र समाप्त करें',
    'ja': 'セッションを終了',
    'ko': '세션 종료',
  },
  'meditation.step': {
    'en': 'Step',
    'ru': 'Шаг',
    'de': 'Schritt',
    'fr': 'Étape',
    'it': 'Passo',
    'pt': 'Etapa',
    'es': 'Paso',
    'id': 'Langkah',
    'hi': 'चरण',
    'ja': 'ステップ',
    'ko': '단계',
  },

  // Диалог завершения сессии: подзаголовок с приглашением отметить настроение.
  // Старый ключ session_complete_body («Отметь, как ты себя чувствуешь.») оставлен
  // для обратной совместимости; в диалоге теперь используется mood_prompt.
  'meditation.mood_prompt': {
    'en': 'How do you feel right now?',
    'ru': 'Как ты себя чувствуешь?',
    'de': 'Wie fühlst du dich gerade?',
    'fr': 'Comment te sens-tu en ce moment ?',
    'it': 'Come ti senti adesso?',
    'pt': 'Como você se sente agora?',
    'es': '¿Cómo te sientes ahora?',
    'id': 'Bagaimana perasaanmu sekarang?',
    'hi': 'अभी तुम कैसा महसूस कर रहे हो?',
    'ja': '今、気分はいかがですか？',
    'ko': '지금 기분이 어떤가요?',
  },
  // Подпись над полем заметки (необязательная)
  'meditation.mood_note_hint': {
    'en': 'Optional note…',
    'ru': 'Заметка (необязательно)…',
    'de': 'Optionale Notiz…',
    'fr': 'Note facultative…',
    'it': 'Nota opzionale…',
    'pt': 'Nota opcional…',
    'es': 'Nota opcional…',
    'id': 'Catatan opsional…',
    'hi': 'वैकल्पिक नोट…',
    'ja': '任意のメモ…',
    'ko': '선택 메모…',
  },
  // Снэкбар-подтверждение при сохранении настроения
  'meditation.mood_saved': {
    'en': 'Mood logged',
    'ru': 'Настроение сохранено',
    'de': 'Stimmung gespeichert',
    'fr': 'Humeur enregistrée',
    'it': 'Umore salvato',
    'pt': 'Humor registrado',
    'es': 'Estado de ánimo guardado',
    'id': 'Suasana hati dicatat',
    'hi': 'मूड दर्ज किया',
    'ja': '気分を記録しました',
    'ko': '기분 기록됨',
  },

  // --- Редактор пользовательской сессии (meditation_editor_screen.dart) ---
  'meditation.create_title': {
    'en': 'Create session',
    'ru': 'Создать сессию',
    'de': 'Sitzung erstellen',
    'fr': 'Créer une séance',
    'it': 'Crea sessione',
    'pt': 'Criar sessão',
    'es': 'Crear sesión',
    'id': 'Buat sesi',
    'hi': 'सत्र बनाएं',
    'ja': 'セッションを作成',
    'ko': '세션 만들기',
  },
  'meditation.create_button': {
    'en': 'New session',
    'ru': 'Новая сессия',
    'de': 'Neue Sitzung',
    'fr': 'Nouvelle séance',
    'it': 'Nuova sessione',
    'pt': 'Nova sessão',
    'es': 'Nueva sesión',
    'id': 'Sesi baru',
    'hi': 'नया सत्र',
    'ja': '新しいセッション',
    'ko': '새 세션',
  },
  'meditation.name_label': {
    'en': 'Session name',
    'ru': 'Название сессии',
    'de': 'Name der Sitzung',
    'fr': 'Nom de la séance',
    'it': 'Nome della sessione',
    'pt': 'Nome da sessão',
    'es': 'Nombre de la sesión',
    'id': 'Nama sesi',
    'hi': 'सत्र का नाम',
    'ja': 'セッション名',
    'ko': '세션 이름',
  },
  'meditation.steps': {
    'en': 'Steps',
    'ru': 'Шаги',
    'de': 'Schritte',
    'fr': 'Étapes',
    'it': 'Passi',
    'pt': 'Etapas',
    'es': 'Pasos',
    'id': 'Langkah',
    'hi': 'चरण',
    'ja': 'ステップ',
    'ko': '단계',
  },
  'meditation.add_step': {
    'en': 'Add step',
    'ru': 'Добавить шаг',
    'de': 'Schritt hinzufügen',
    'fr': 'Ajouter une étape',
    'it': 'Aggiungi passo',
    'pt': 'Adicionar etapa',
    'es': 'Añadir paso',
    'id': 'Tambah langkah',
    'hi': 'चरण जोड़ें',
    'ja': 'ステップを追加',
    'ko': '단계 추가',
  },
  'meditation.instruction_hint': {
    'en': 'Instruction for this step…',
    'ru': 'Инструкция для этого шага…',
    'de': 'Anweisung für diesen Schritt…',
    'fr': 'Instruction pour cette étape…',
    'it': 'Istruzione per questo passo…',
    'pt': 'Instrução para esta etapa…',
    'es': 'Instrucción para este paso…',
    'id': 'Instruksi untuk langkah ini…',
    'hi': 'इस चरण के लिए निर्देश…',
    'ja': 'このステップの説明…',
    'ko': '이 단계에 대한 안내…',
  },
  'meditation.total': {
    'en': 'Total',
    'ru': 'Итого',
    'de': 'Gesamt',
    'fr': 'Total',
    'it': 'Totale',
    'pt': 'Total',
    'es': 'Total',
    'id': 'Total',
    'hi': 'कुल',
    'ja': '合計',
    'ko': '총',
  },
  'meditation.removed': {
    'en': 'removed',
    'ru': 'удалена',
    'de': 'entfernt',
    'fr': 'supprimée',
    'it': 'rimossa',
    'pt': 'removida',
    'es': 'eliminada',
    'id': 'dihapus',
    'hi': 'हटाया गया',
    'ja': '削除しました',
    'ko': '삭제됨',
  },

  // ---------------------------------------------------------------------------
  // posture.* exercise content  —  posture_exercises.dart
  // ---------------------------------------------------------------------------

  'posture.chin_tucks.name': {
    'en': 'Chin tucks',
    'ru': 'Подтягивание подбородка',
  },
  'posture.chin_tucks.steps': {
    'en':
        'Sit tall and gently pull your chin straight back, making a slight double chin. '
        'Hold for 2 seconds, then release slowly. '
        'Keep your eyes level and shoulders relaxed throughout.',
    'ru':
        'Сядьте ровно и мягко потяните подбородок прямо назад, слегка образовав второй подбородок. '
        'Удерживайте 2 секунды, затем медленно отпустите. '
        'На протяжении всего упражнения смотрите прямо, плечи расслаблены.',
  },
  'posture.shoulder_blade_squeeze.name': {
    'en': 'Shoulder blade squeeze',
    'ru': 'Сведение лопаток',
  },
  'posture.shoulder_blade_squeeze.steps': {
    'en':
        'Sit or stand with arms at your sides. '
        'Draw your shoulder blades together as if you were trying to hold a pencil between them. '
        'Hold for 3 seconds, then slowly release and repeat.',
    'ru':
        'Сядьте или встаньте, руки вдоль тела. '
        'Сведите лопатки вместе, словно пытаетесь зажать карандаш между ними. '
        'Удерживайте 3 секунды, затем медленно расслабьтесь и повторите.',
  },
  'posture.wall_angels.name': {
    'en': 'Wall angels',
    'ru': 'Ангел у стены',
  },
  'posture.wall_angels.steps': {
    'en':
        'Stand with your back against a wall, feet a few inches from the base. '
        'Press your lower back, upper back, and head to the wall, then slide your arms up and down like a snow angel. '
        'Move slowly and keep contact with the wall throughout.',
    'ru':
        'Встаньте спиной к стене, стопы на несколько сантиметров от плинтуса. '
        'Прижмите поясницу, верхнюю часть спины и голову к стене, затем плавно поднимайте и опускайте руки, как при рисовании ангела на снегу. '
        'Двигайтесь медленно, не теряя контакта со стеной.',
  },
  'posture.doorway_chest_stretch.name': {
    'en': 'Doorway chest stretch',
    'ru': 'Растяжка грудных в дверном проёме',
  },
  'posture.doorway_chest_stretch.steps': {
    'en':
        'Stand in a doorway and place your forearms on the door frame, elbows at shoulder height. '
        'Lean forward gently until you feel a mild stretch across your chest. '
        'Breathe steadily and hold, then step back to release.',
    'ru':
        'Встаньте в дверном проёме и опритесь предплечьями о косяки, локти на уровне плеч. '
        'Плавно наклонитесь вперёд, пока не почувствуете лёгкое растяжение в груди. '
        'Дышите ровно и удерживайте позицию, затем шагните назад.',
  },
  'posture.upper_trap_stretch.name': {
    'en': 'Upper trap stretch',
    'ru': 'Растяжка верхней трапеции',
  },
  'posture.upper_trap_stretch.steps': {
    'en':
        'Sit or stand tall and tilt your right ear toward your right shoulder. '
        'Place your right hand lightly on your head for a gentle added stretch — never pull. '
        'Hold, then repeat on the other side.',
    'ru':
        'Сядьте или встаньте ровно и наклоните правое ухо к правому плечу. '
        'Слегка положите правую руку на голову для мягкого дополнительного растяжения — не тяните резко. '
        'Удерживайте, затем повторите на другую сторону.',
  },
  'posture.cat_cow.name': {
    'en': 'Cat-cow',
    'ru': 'Кошка-корова',
  },
  'posture.cat_cow.steps': {
    'en':
        'Get on your hands and knees with a neutral spine. '
        'Inhale as you drop your belly and lift your gaze (cow); exhale as you round your back toward the ceiling (cat). '
        'Move slowly and let your breath guide the rhythm.',
    'ru':
        'Встаньте на четвереньки, спина в нейтральном положении. '
        'На вдохе опустите живот и поднимите взгляд (корова); на выдохе округлите спину к потолку (кошка). '
        'Двигайтесь медленно, пусть дыхание задаёт ритм.',
  },

  // ---------------------------------------------------------------------------
  // meditation.* session content  —  meditation_screen.dart
  // ---------------------------------------------------------------------------

  // — Body Scan (10 min, 6 steps) —
  'meditation.body_scan.name': {
    'en': 'Body Scan',
    'ru': 'Сканирование тела',
    'de': 'Körperscan',
    'fr': 'Scan corporel',
    'it': 'Scansione corporea',
    'pt': 'Escaneamento corporal',
    'es': 'Exploración corporal',
    'id': 'Pemindaian tubuh',
    'hi': 'बॉडी स्कैन',
    'ja': 'ボディスキャン',
    'ko': '바디 스캔',
  },
  'meditation.body_scan.desc': {
    'en': 'Release tension from head to toe',
    'ru': 'Снимите напряжение с головы до пят',
    'de': 'Löse Spannungen von Kopf bis Fuß',
    'fr': 'Libère les tensions de la tête aux pieds',
    'it': 'Rilascia la tensione dalla testa ai piedi',
    'pt': 'Libere a tensão da cabeça aos pés',
    'es': 'Libera la tensión de la cabeza a los pies',
    'id': 'Lepaskan ketegangan dari kepala hingga kaki',
    'hi': 'सिर से पैर तक तनाव मुक्त करें',
    'ja': '頭からつま先まで緊張を解放する',
    'ko': '머리부터 발끝까지 긴장 해소',
  },
  'meditation.body_scan.step1': {
    'en':
        'Find a comfortable position — sitting or lying down. Close your eyes gently and take three slow, deep breaths. Let your body settle.',
    'ru':
        'Примите удобное положение — сидя или лёжа. Мягко закройте глаза и сделайте три медленных, глубоких вдоха. Позвольте телу расслабиться.',
    'de':
        'Finde eine bequeme Position — sitzend oder liegend. Schließe die Augen sanft und nimm drei langsame, tiefe Atemzüge. Lass deinen Körper zur Ruhe kommen.',
    'fr':
        'Trouve une position confortable — assis ou allongé. Ferme doucement les yeux et prends trois respirations lentes et profondes. Laisse ton corps se poser.',
    'it':
        'Trova una posizione comoda — seduto o sdraiato. Chiudi gli occhi delicatamente e fai tre respiri lenti e profondi. Lascia che il tuo corpo si rilassi.',
    'pt':
        'Encontre uma posição confortável — sentado ou deitado. Feche os olhos suavemente e faça três respirações lentas e profundas. Deixe seu corpo se acomodar.',
    'es':
        'Encuentra una posición cómoda — sentado o acostado. Cierra los ojos suavemente y toma tres respiraciones lentas y profundas. Deja que tu cuerpo se asiente.',
    'id':
        'Temukan posisi yang nyaman — duduk atau berbaring. Pejamkan mata dengan lembut dan ambil tiga napas dalam yang lambat. Biarkan tubuhmu tenang.',
    'hi':
        'एक आरामदायक स्थिति खोजें — बैठकर या लेटकर। आंखें धीरे से बंद करें और तीन धीमी, गहरी सांसें लें। अपने शरीर को स्थिर होने दें।',
    'ja':
        '座るか横になる楽な姿勢を見つけてください。目をゆっくり閉じて、ゆっくりと深い呼吸を三回行います。身体の力を抜きましょう。',
    'ko':
        '편한 자세를 찾으세요 — 앉거나 누운 자세로. 눈을 부드럽게 감고 천천히 깊게 세 번 호흡하세요. 몸이 편히 쉬도록 두세요.',
  },
  'meditation.body_scan.step2': {
    'en':
        'Bring your attention to the top of your head. Notice any sensations — tingling, warmth, or pressure. Simply observe without judgment.',
    'ru':
        'Перенесите внимание на макушку головы. Замечайте любые ощущения — покалывание, тепло или давление. Просто наблюдайте, не оценивая.',
    'de':
        'Richte deine Aufmerksamkeit auf den Scheitel deines Kopfes. Bemerke alle Empfindungen — Kribbeln, Wärme oder Druck. Beobachte sie einfach ohne Urteil.',
    'fr':
        'Porte ton attention sur le sommet de ta tête. Remarque toutes les sensations — picotements, chaleur ou pression. Observe simplement sans jugement.',
    'it':
        'Porta la tua attenzione sulla sommità della testa. Nota qualsiasi sensazione — formicolio, calore o pressione. Osserva semplicemente senza giudicare.',
    'pt':
        'Traga sua atenção para o topo da cabeça. Note qualquer sensação — formigamento, calor ou pressão. Simplesmente observe sem julgamento.',
    'es':
        'Lleva tu atención a la cima de tu cabeza. Observa cualquier sensación — hormigueo, calor o presión. Simplemente observa sin juzgar.',
    'id':
        'Bawa perhatianmu ke puncak kepala. Perhatikan sensasi apapun — kesemutan, kehangatan, atau tekanan. Cukup amati tanpa menghakimi.',
    'hi':
        'अपना ध्यान सिर के शीर्ष पर लाएं। किसी भी संवेदना पर ध्यान दें — झुनझुनाहट, गर्माहट या दबाव। बिना निर्णय के बस देखें।',
    'ja':
        '頭頂部に注意を向けてください。くすぐったさ、温かさ、または圧力などの感覚に気づきましょう。ただ判断せずに観察するだけでよいです。',
    'ko':
        '머리 꼭대기에 주의를 집중하세요. 따끔거림, 온기, 또는 압박감 같은 감각을 느껴보세요. 판단하지 말고 그냥 관찰하세요.',
  },
  'meditation.body_scan.step3': {
    'en':
        'Slowly move your awareness down through your face, neck, and shoulders. If you feel tension, breathe into that area and let it soften on the exhale.',
    'ru':
        'Медленно перемещайте внимание вниз — по лицу, шее и плечам. Если чувствуете напряжение, направьте туда дыхание и позвольте ему раствориться на выдохе.',
    'de':
        'Bewege dein Bewusstsein langsam durch Gesicht, Hals und Schultern. Wenn du Spannung spürst, atme in diesen Bereich und lass ihn beim Ausatmen weicher werden.',
    'fr':
        'Déplace lentement ta conscience vers le bas, à travers le visage, le cou et les épaules. Si tu ressens une tension, respire dans cette zone et laisse-la s\'adoucir à l\'expiration.',
    'it':
        'Sposta lentamente la consapevolezza verso il basso attraverso viso, collo e spalle. Se senti tensione, respira in quell\'area e lasciala ammorbidire con l\'espirazione.',
    'pt':
        'Mova lentamente sua consciência para baixo pelo rosto, pescoço e ombros. Se sentir tensão, respire para essa área e deixe-a suavizar na expiração.',
    'es':
        'Mueve lentamente tu conciencia hacia abajo por la cara, el cuello y los hombros. Si sientes tensión, respira hacia esa zona y deja que se suavice en la exhalación.',
    'id':
        'Perlahan gerakkan kesadaranmu ke bawah melalui wajah, leher, dan bahu. Jika merasakan ketegangan, hirup napas ke area itu dan biarkan melembut saat menghembuskan napas.',
    'hi':
        'धीरे-धीरे अपनी चेतना को नीचे चेहरे, गर्दन और कंधों की ओर ले जाएं। यदि तनाव महसूस हो, उस क्षेत्र में सांस भेजें और सांस छोड़ते समय उसे नरम होने दें।',
    'ja':
        '顔、首、肩へとゆっくり意識を下げていきましょう。緊張を感じたら、その部位に呼吸を届け、息を吐くときに緩むのを感じましょう。',
    'ko':
        '얼굴, 목, 어깨를 따라 천천히 의식을 아래로 이동하세요. 긴장이 느껴지면 그 부위로 숨을 불어넣고 내쉴 때 부드럽게 풀어주세요.',
  },
  'meditation.body_scan.step4': {
    'en':
        'Scan through your chest, belly, and lower back. Notice the gentle rise and fall of your breath. You don\'t need to change anything.',
    'ru':
        'Сканируйте грудь, живот и поясницу. Замечайте мягкий подъём и опускание при дыхании. Вам ничего не нужно менять.',
    'de':
        'Scanne durch deine Brust, deinen Bauch und deinen unteren Rücken. Bemerke das sanfte Heben und Senken deines Atems. Du musst nichts verändern.',
    'fr':
        'Scanne ta poitrine, ton ventre et le bas de ton dos. Remarque la douce montée et descente de ta respiration. Tu n\'as besoin de rien changer.',
    'it':
        'Scansiona il tuo petto, la pancia e la zona lombare. Nota il delicato alzarsi e abbassarsi del respiro. Non hai bisogno di cambiare nulla.',
    'pt':
        'Escaneie seu peito, barriga e parte inferior das costas. Observe a suave ascensão e queda de sua respiração. Não há necessidade de mudar nada.',
    'es':
        'Escanea tu pecho, vientre y zona lumbar. Observa el suave ascenso y descenso de tu respiración. No necesitas cambiar nada.',
    'id':
        'Pindai dada, perut, dan punggung bawahmu. Perhatikan naik turunnya napas yang lembut. Kamu tidak perlu mengubah apa pun.',
    'hi':
        'अपनी छाती, पेट और पीठ के निचले हिस्से को स्कैन करें। सांस के धीमे उठने-गिरने पर ध्यान दें। आपको कुछ बदलने की जरूरत नहीं।',
    'ja':
        '胸、お腹、腰の下部をスキャンしましょう。呼吸のやさしい上下に気づいてください。何も変える必要はありません。',
    'ko':
        '가슴, 배, 하부 등을 스캔하세요. 호흡의 부드러운 오르내림을 느껴보세요. 아무것도 바꿀 필요가 없습니다.',
  },
  'meditation.body_scan.step5': {
    'en':
        'Move your attention down through your legs, ankles, and feet. Feel each toe. Your whole body is now relaxed and at ease.',
    'ru':
        'Переведите внимание вниз — по ногам, лодыжкам и ступням. Почувствуйте каждый палец. Всё ваше тело теперь расслаблено и спокойно.',
    'de':
        'Richte deine Aufmerksamkeit durch die Beine, Knöchel und Füße nach unten. Spüre jeden Zeh. Dein ganzer Körper ist jetzt entspannt und ruhig.',
    'fr':
        'Déplace ton attention vers le bas, à travers les jambes, les chevilles et les pieds. Sens chaque orteil. Tout ton corps est maintenant détendu et à l\'aise.',
    'it':
        'Sposta la tua attenzione verso il basso attraverso le gambe, le caviglie e i piedi. Senti ogni dito del piede. Il tuo intero corpo è ora rilassato e a proprio agio.',
    'pt':
        'Mova sua atenção para baixo pelas pernas, tornozelos e pés. Sinta cada dedo do pé. Todo o seu corpo está agora relaxado e em paz.',
    'es':
        'Mueve tu atención hacia abajo por las piernas, tobillos y pies. Siente cada dedo del pie. Todo tu cuerpo está ahora relajado y a gusto.',
    'id':
        'Gerakkan perhatianmu ke bawah melalui kaki, pergelangan kaki, dan telapak kaki. Rasakan setiap jari kaki. Seluruh tubuhmu kini rileks dan nyaman.',
    'hi':
        'अपना ध्यान नीचे पैरों, टखनों और पैरों की ओर ले जाएं। हर अंगुली को महसूस करें। आपका पूरा शरीर अब शांत और सहज है।',
    'ja':
        '脚、足首、足へと注意を下げていきましょう。つま先一本一本を感じてください。体全体がリラックスして楽になっています。',
    'ko':
        '다리, 발목, 발 아래로 주의를 이동하세요. 발가락 하나하나를 느껴보세요. 온몸이 이제 편안하게 이완되었습니다.',
  },
  'meditation.body_scan.step6': {
    'en':
        'Rest in this state of calm awareness for a moment. When you\'re ready, gently wiggle your fingers and toes and slowly open your eyes.',
    'ru':
        'Побудьте в этом состоянии спокойной осознанности. Когда будете готовы, мягко пошевелите пальцами рук и ног и медленно откройте глаза.',
    'de':
        'Ruhe für einen Moment in diesem Zustand ruhiger Bewusstheit. Wenn du bereit bist, bewege sanft deine Finger und Zehen und öffne langsam die Augen.',
    'fr':
        'Repose-toi un moment dans cet état de conscience calme. Quand tu es prêt, bouge doucement tes doigts et tes orteils, puis ouvre lentement les yeux.',
    'it':
        'Riposati per un momento in questo stato di consapevolezza calma. Quando sei pronto, muovi delicatamente le dita delle mani e dei piedi e apri lentamente gli occhi.',
    'pt':
        'Descanse por um momento neste estado de consciência calma. Quando estiver pronto, mova suavemente os dedos das mãos e dos pés e abra lentamente os olhos.',
    'es':
        'Descansa por un momento en este estado de consciencia tranquila. Cuando estés listo, mueve suavemente los dedos de las manos y los pies y abre lentamente los ojos.',
    'id':
        'Beristirahatlah sejenak dalam keadaan kesadaran yang tenang ini. Saat siap, gerakkan jari tangan dan kaki dengan lembut lalu perlahan buka matamu.',
    'hi':
        'कुछ देर इस शांत जागरूकता की अवस्था में विश्राम करें। जब तैयार हों, धीरे से हाथ-पैर की उंगलियां हिलाएं और धीरे-धीरे आंखें खोलें।',
    'ja':
        'しばらくこの穏やかな気づきの状態で休みましょう。準備ができたら、指とつま先をそっと動かし、ゆっくりと目を開けてください。',
    'ko':
        '잠시 이 고요한 알아차림 상태에서 쉬어보세요. 준비가 되면 손가락과 발가락을 부드럽게 움직이고 천천히 눈을 뜨세요.',
  },

  // — Focus Reset (5 min, 5 steps) —
  'meditation.focus_reset.name': {
    'en': 'Focus Reset',
    'ru': 'Перезапуск фокуса',
    'de': 'Fokus-Reset',
    'fr': 'Réinitialisation du focus',
    'it': 'Reset della concentrazione',
    'pt': 'Redefinição do foco',
    'es': 'Reinicio del enfoque',
    'id': 'Setel ulang fokus',
    'hi': 'फोकस रीसेट',
    'ja': 'フォーカスリセット',
    'ko': '집중력 리셋',
  },
  'meditation.focus_reset.desc': {
    'en': 'Clear mental fog between study blocks',
    'ru': 'Разгоните туман в голове между блоками учёбы',
    'de': 'Geistigen Nebel zwischen Lernblöcken beseitigen',
    'fr': 'Dissipe le brouillard mental entre les blocs d\'étude',
    'it': 'Elimina la nebbia mentale tra i blocchi di studio',
    'pt': 'Elimine o nevoeiro mental entre os blocos de estudo',
    'es': 'Despeja la niebla mental entre bloques de estudio',
    'id': 'Bersihkan kabut pikiran di antara sesi belajar',
    'hi': 'अध्ययन सत्रों के बीच मानसिक धुंध साफ करें',
    'ja': '学習ブロックの間に頭の霧を晴らす',
    'ko': '공부 블록 사이에 정신적 흐림 해소',
  },
  'meditation.focus_reset.step1': {
    'en':
        'Sit upright, feet flat on the floor. Set your intention: you are clearing your mind to return to peak focus.',
    'ru':
        'Сядьте прямо, стопы плоско на полу. Поставьте намерение: вы очищаете разум, чтобы вернуться к максимальной концентрации.',
    'de':
        'Sitze aufrecht, Füße flach auf dem Boden. Setze deine Absicht: Du klärst deinen Geist, um zur maximalen Konzentration zurückzukehren.',
    'fr':
        'Assieds-toi droit, les pieds à plat sur le sol. Pose ton intention : tu clarifie ton esprit pour retrouver une concentration maximale.',
    'it':
        'Siediti dritto, piedi piatti sul pavimento. Stabilisci la tua intenzione: stai liberando la mente per tornare alla massima concentrazione.',
    'pt':
        'Sente-se ereto, pés apoiados no chão. Defina sua intenção: você está limpando a mente para retornar ao foco máximo.',
    'es':
        'Siéntate erguido, pies apoyados en el suelo. Establece tu intención: estás despejando la mente para volver al máximo enfoque.',
    'id':
        'Duduklah tegak, kaki rata di lantai. Tetapkan niatmu: kamu sedang menjernihkan pikiran untuk kembali ke fokus optimal.',
    'hi':
        'सीधे बैठें, पैर जमीन पर सपाट। अपना इरादा तय करें: आप अपने दिमाग को साफ कर रहे हैं ताकि पूरी एकाग्रता पर वापस आ सकें।',
    'ja':
        '背筋を伸ばして座り、両足を床に平らにつけましょう。意図を定めてください：最高の集中力を取り戻すために心を整えています。',
    'ko':
        '등을 똑바로 세워 발을 바닥에 평평하게 앉으세요. 의도를 설정하세요: 최고의 집중력을 되찾기 위해 마음을 정리하고 있습니다.',
  },
  'meditation.focus_reset.step2': {
    'en':
        'Take a deep breath in for 4 counts, hold for 4, and exhale for 4. Repeat this twice more at your own pace.',
    'ru':
        'Сделайте глубокий вдох на 4 счёта, задержите на 4, выдохните на 4. Повторите ещё дважды в своём темпе.',
    'de':
        'Atme tief für 4 Zählungen ein, halte für 4 an und atme für 4 aus. Wiederhole dies zweimal in deinem eigenen Tempo.',
    'fr':
        'Inspire profondément pendant 4 temps, retiens pendant 4 et expire pendant 4. Répète cela deux fois de plus à ton propre rythme.',
    'it':
        'Fai un respiro profondo per 4 tempi, trattieni per 4 ed espira per 4. Ripeti altre due volte al tuo ritmo.',
    'pt':
        'Inspire profundamente por 4 tempos, segure por 4 e expire por 4. Repita isso mais duas vezes no seu próprio ritmo.',
    'es':
        'Inhala profundamente durante 4 tiempos, retén durante 4 y exhala durante 4. Repite esto dos veces más a tu propio ritmo.',
    'id':
        'Tarik napas dalam selama 4 hitungan, tahan selama 4, dan hembuskan selama 4. Ulangi dua kali lagi sesuai kecepatanmu.',
    'hi':
        '4 गिनती तक गहरी सांस लें, 4 गिनती तक रोकें, और 4 गिनती तक छोड़ें। अपनी गति से इसे दो बार और दोहराएं।',
    'ja':
        '4カウントで深く息を吸い、4カウント止め、4カウントで吐き出します。自分のペースでこれをさらに2回繰り返してください。',
    'ko':
        '4박자로 깊게 들이쉬고, 4박자 멈추고, 4박자로 내쉬세요. 자신의 페이스로 두 번 더 반복하세요.',
  },
  'meditation.focus_reset.step3': {
    'en':
        'Picture a blank, white screen in your mind. If any thoughts appear, gently acknowledge them and let them drift off the screen.',
    'ru':
        'Представьте в уме чистый белый экран. Если появляются мысли, мягко признайте их и позвольте им уплыть с экрана.',
    'de':
        'Stelle dir einen leeren, weißen Bildschirm in deinem Geist vor. Wenn Gedanken auftauchen, erkenne sie sanft an und lass sie vom Bildschirm wegdriften.',
    'fr':
        'Imagine un écran blanc vide dans ton esprit. Si des pensées apparaissent, reconnais-les doucement et laisse-les dériver hors de l\'écran.',
    'it':
        'Immagina uno schermo bianco vuoto nella tua mente. Se appaiono pensieri, riconoscili delicatamente e lasciali allontanare dallo schermo.',
    'pt':
        'Imagine uma tela branca em branco em sua mente. Se pensamentos aparecerem, reconheça-os suavemente e deixe-os se afastar da tela.',
    'es':
        'Imagina una pantalla blanca en blanco en tu mente. Si aparecen pensamientos, reconócelos suavemente y deja que se alejen de la pantalla.',
    'id':
        'Bayangkan layar putih kosong di benakmu. Jika ada pikiran yang muncul, akui dengan lembut dan biarkan mengapung menjauh dari layar.',
    'hi':
        'मन में एक सफेद खाली स्क्रीन की कल्पना करें। यदि कोई विचार आए, उन्हें धीरे से स्वीकार करें और स्क्रीन से दूर जाने दें।',
    'ja':
        '心の中に白い空白の画面を思い浮かべてください。考えが浮かんだら、優しく認めてそれを画面から流れ去らせましょう。',
    'ko':
        '마음속에 하얗고 텅 빈 화면을 상상하세요. 생각이 떠오르면 부드럽게 인식하고 화면에서 멀어지도록 두세요.',
  },
  'meditation.focus_reset.step4': {
    'en':
        'Bring to mind one clear goal for your next work session. See it briefly, then release the image.',
    'ru':
        'Представьте одну чёткую цель для следующего рабочего блока. Увидьте её на мгновение, затем отпустите образ.',
    'de':
        'Ruf dir ein klares Ziel für deine nächste Arbeitssession ins Gedächtnis. Sieh es kurz, dann lass das Bild los.',
    'fr':
        'Rappelle-toi un objectif clair pour ta prochaine session de travail. Vois-le brièvement, puis relâche l\'image.',
    'it':
        'Porta in mente un obiettivo chiaro per la tua prossima sessione di lavoro. Visualizzalo brevemente, poi lascia andare l\'immagine.',
    'pt':
        'Traga à mente um objetivo claro para a próxima sessão de trabalho. Veja-o brevemente, depois solte a imagem.',
    'es':
        'Trae a la mente un objetivo claro para tu próxima sesión de trabajo. Míralo brevemente, luego suelta la imagen.',
    'id':
        'Bayangkan satu tujuan yang jelas untuk sesi kerja berikutnya. Lihat sebentar, lalu lepaskan gambar itu.',
    'hi':
        'अगले कार्य-सत्र के लिए एक स्पष्ट लक्ष्य मन में लाएं। उसे एक पल देखें, फिर छवि छोड़ दें।',
    'ja':
        '次の作業セッションのための明確な目標を心に浮かべてください。少しの間イメージし、そのイメージを手放します。',
    'ko':
        '다음 작업 세션을 위한 명확한 목표 하나를 떠올리세요. 잠시 보고 나서 이미지를 놓아주세요.',
  },
  'meditation.focus_reset.step5': {
    'en': 'Take one final deep breath. Open your eyes. You are ready to focus.',
    'ru': 'Сделайте последний глубокий вдох. Откройте глаза. Вы готовы сосредоточиться.',
    'de': 'Nimm einen letzten tiefen Atemzug. Öffne die Augen. Du bist bereit, dich zu konzentrieren.',
    'fr': 'Prends une dernière grande inspiration. Ouvre les yeux. Tu es prêt à te concentrer.',
    'it': 'Fai un ultimo respiro profondo. Apri gli occhi. Sei pronto per concentrarti.',
    'pt': 'Faça uma última respiração profunda. Abra os olhos. Você está pronto para focar.',
    'es': 'Toma una última respiración profunda. Abre los ojos. Estás listo para concentrarte.',
    'id': 'Ambil satu napas dalam terakhir. Buka matamu. Kamu siap untuk fokus.',
    'hi': 'एक आखिरी गहरी सांस लें। आंखें खोलें। आप ध्यान केंद्रित करने के लिए तैयार हैं।',
    'ja': '最後に深く一息吸ってください。目を開けましょう。集中する準備ができています。',
    'ko': '마지막으로 깊게 한 번 숨을 들이쉬세요. 눈을 뜨세요. 이제 집중할 준비가 되었습니다.',
  },

  // — Exam Calm (7 min, 5 steps) —
  'meditation.exam_calm.name': {
    'en': 'Exam Calm',
    'ru': 'Спокойствие перед экзаменом',
    'de': 'Prüfungsruhe',
    'fr': 'Calme avant l\'examen',
    'it': 'Calma prima dell\'esame',
    'pt': 'Calma para a prova',
    'es': 'Calma antes del examen',
    'id': 'Tenang sebelum ujian',
    'hi': 'परीक्षा से पहले शांति',
    'ja': '試験前の落ち着き',
    'ko': '시험 전 평정심',
  },
  'meditation.exam_calm.desc': {
    'en': 'Ease anxiety before tests and presentations',
    'ru': 'Снимите тревогу перед тестами и выступлениями',
    'de': 'Angst vor Prüfungen und Präsentationen abbauen',
    'fr': 'Apaise l\'anxiété avant les examens et présentations',
    'it': 'Allevia l\'ansia prima dei test e delle presentazioni',
    'pt': 'Alivie a ansiedade antes de provas e apresentações',
    'es': 'Alivia la ansiedad antes de exámenes y presentaciones',
    'id': 'Kurangi kecemasan sebelum ujian dan presentasi',
    'hi': 'परीक्षाओं और प्रस्तुतियों से पहले चिंता कम करें',
    'ja': 'テストや発表前の不安を和らげる',
    'ko': '시험과 발표 전 불안 완화',
  },
  'meditation.exam_calm.step1': {
    'en':
        'Acknowledge that some nervousness is normal — it means you care. Take a slow breath and remind yourself: you have prepared for this.',
    'ru':
        'Признайте, что небольшое волнение — это нормально: значит, вам важно. Сделайте медленный вдох и напомните себе: вы готовились к этому.',
    'de':
        'Erkenne an, dass etwas Nervosität normal ist — es bedeutet, dass dir etwas wichtig ist. Atme langsam und erinnere dich: Du hast dich darauf vorbereitet.',
    'fr':
        'Reconnais qu\'une certaine nervosité est normale — cela signifie que tu tiens à quelque chose. Prends une respiration lente et rappelle-toi : tu t\'es préparé pour ça.',
    'it':
        'Riconosci che un po\' di nervosismo è normale — significa che ci tieni. Fai un respiro lento e ricorda a te stesso: ti sei preparato per questo.',
    'pt':
        'Reconheça que algum nervosismo é normal — significa que você se importa. Faça uma respiração lenta e lembre-se: você se preparou para isso.',
    'es':
        'Reconoce que algo de nerviosismo es normal — significa que te importa. Haz una respiración lenta y recuérdate: te has preparado para esto.',
    'id':
        'Akui bahwa sedikit gugup itu wajar — itu berarti kamu peduli. Tarik napas perlahan dan ingatkan dirimu: kamu sudah mempersiapkan diri untuk ini.',
    'hi':
        'मानें कि थोड़ी घबराहट सामान्य है — इसका मतलब है कि आपको परवाह है। धीमी सांस लें और खुद को याद दिलाएं: आपने इसके लिए तैयारी की है।',
    'ja':
        '少し緊張するのは正常だと認めましょう — それはあなたが気にかけている証拠です。ゆっくり息を吸い、自分に思い出させましょう：あなたはこのために準備してきました。',
    'ko':
        '약간의 긴장감은 정상임을 인정하세요 — 그것은 당신이 신경 쓴다는 뜻입니다. 천천히 숨을 들이쉬고 스스로 상기시키세요: 당신은 이것을 위해 준비했습니다.',
  },
  'meditation.exam_calm.step2': {
    'en':
        'Inhale deeply through your nose for 4 counts. Hold gently for 4 counts. Exhale slowly through your mouth for 6 counts. Repeat three times.',
    'ru':
        'Глубоко вдохните через нос на 4 счёта. Мягко задержите на 4 счёта. Медленно выдохните через рот на 6 счётов. Повторите трижды.',
    'de':
        'Atme 4 Zählungen tief durch die Nase ein. Halte sanft 4 Zählungen an. Atme 6 Zählungen langsam durch den Mund aus. Dreimal wiederholen.',
    'fr':
        'Inspire profondément par le nez pendant 4 temps. Retiens doucement pendant 4 temps. Expire lentement par la bouche pendant 6 temps. Répète trois fois.',
    'it':
        'Inspira profondamente dal naso per 4 tempi. Trattieni delicatamente per 4 tempi. Espira lentamente dalla bocca per 6 tempi. Ripeti tre volte.',
    'pt':
        'Inspire profundamente pelo nariz por 4 tempos. Segure suavemente por 4 tempos. Expire lentamente pela boca por 6 tempos. Repita três vezes.',
    'es':
        'Inhala profundamente por la nariz durante 4 tiempos. Retén suavemente durante 4 tiempos. Exhala lentamente por la boca durante 6 tiempos. Repite tres veces.',
    'id':
        'Hirup napas dalam melalui hidung selama 4 hitungan. Tahan dengan lembut selama 4 hitungan. Hembuskan perlahan melalui mulut selama 6 hitungan. Ulangi tiga kali.',
    'hi':
        'नाक से 4 गिनती तक गहरी सांस लें। धीरे से 4 गिनती तक रोकें। मुंह से 6 गिनती तक धीरे-धीरे सांस छोड़ें। तीन बार दोहराएं।',
    'ja':
        '鼻から4カウントで深く息を吸います。4カウントやさしく止めます。口から6カウントでゆっくり吐きます。三回繰り返します。',
    'ko':
        '코로 4박자 동안 깊게 들이쉬세요. 4박자 동안 부드럽게 멈추세요. 입으로 6박자 동안 천천히 내쉬세요. 세 번 반복하세요.',
  },
  'meditation.exam_calm.step3': {
    'en':
        'Name five things you can see around you. Four things you can touch. Three things you can hear. This grounds you in the present moment.',
    'ru':
        'Назовите пять вещей, которые вы видите вокруг. Четыре вещи, которые можно потрогать. Три звука, которые слышите. Это возвращает вас в настоящий момент.',
    'de':
        'Benenne fünf Dinge, die du um dich herum siehst. Vier Dinge, die du berühren kannst. Drei Dinge, die du hören kannst. Das erdet dich im gegenwärtigen Moment.',
    'fr':
        'Nomme cinq choses que tu peux voir autour de toi. Quatre choses que tu peux toucher. Trois choses que tu peux entendre. Cela t\'ancre dans le moment présent.',
    'it':
        'Nomina cinque cose che puoi vedere intorno a te. Quattro cose che puoi toccare. Tre cose che puoi sentire. Questo ti radica nel momento presente.',
    'pt':
        'Nomeie cinco coisas que você pode ver ao seu redor. Quatro coisas que pode tocar. Três coisas que pode ouvir. Isso te ancora no momento presente.',
    'es':
        'Nombra cinco cosas que puedes ver a tu alrededor. Cuatro cosas que puedes tocar. Tres cosas que puedes escuchar. Esto te ancla en el momento presente.',
    'id':
        'Sebutkan lima hal yang bisa kamu lihat di sekitarmu. Empat hal yang bisa kamu sentuh. Tiga hal yang bisa kamu dengar. Ini membumi kamu di saat ini.',
    'hi':
        'अपने आसपास दिखने वाली पांच चीजें बताएं। चार चीजें जो छू सकते हैं। तीन आवाजें जो सुन सकते हैं। यह आपको वर्तमान क्षण में लाता है।',
    'ja':
        'あなたの周りに見えるものを5つ挙げましょう。触れるものを4つ。聞こえるものを3つ。これがあなたを今この瞬間に引き戻します。',
    'ko':
        '주변에서 보이는 것 다섯 가지를 말하세요. 만질 수 있는 것 네 가지. 들을 수 있는 것 세 가지. 이것이 현재 순간에 당신을 닻 내리게 합니다.',
  },
  'meditation.exam_calm.step4': {
    'en':
        'Recall one moment when you succeeded despite feeling anxious. Feel that memory in your body — the relief, the confidence that followed.',
    'ru':
        'Вспомните момент, когда вы справились, несмотря на тревогу. Почувствуйте это воспоминание в теле — облегчение, уверенность, которая пришла следом.',
    'de':
        'Erinnere dich an einen Moment, in dem du trotz Nervosität erfolgreich warst. Spüre diese Erinnerung in deinem Körper — die Erleichterung, das Vertrauen, das folgte.',
    'fr':
        'Rappelle-toi un moment où tu as réussi malgré l\'anxiété. Ressens ce souvenir dans ton corps — le soulagement, la confiance qui ont suivi.',
    'it':
        'Ricorda un momento in cui hai avuto successo nonostante l\'ansia. Senti quel ricordo nel tuo corpo — il sollievo, la fiducia che ne è seguita.',
    'pt':
        'Lembre-se de um momento em que você teve sucesso apesar da ansiedade. Sinta essa memória no seu corpo — o alívio, a confiança que se seguiu.',
    'es':
        'Recuerda un momento en que tuviste éxito a pesar de sentirte ansioso. Siente ese recuerdo en tu cuerpo — el alivio, la confianza que vino después.',
    'id':
        'Ingat satu momen ketika kamu berhasil meski merasa cemas. Rasakan kenangan itu di tubuhmu — kelegaan, keyakinan yang menyusul.',
    'hi':
        'उस पल को याद करें जब आप चिंतित होने के बावजूद सफल हुए। उस याद को शरीर में महसूस करें — राहत, जो आत्मविश्वास उसके बाद आया।',
    'ja':
        '不安を感じながらも成功した瞬間を思い出してください。その記憶を体で感じましょう — 安堵感、その後に続いた自信を。',
    'ko':
        '불안함에도 불구하고 성공했던 순간을 떠올리세요. 그 기억을 몸으로 느껴보세요 — 안도감, 뒤따라온 자신감을.',
  },
  'meditation.exam_calm.step5': {
    'en':
        'Silently tell yourself: "I am calm, I am clear, I know what to do." Take one final deep breath and step forward with confidence.',
    'ru':
        'Тихо скажите себе: «Я спокоен, я ясен, я знаю, что делать». Сделайте последний глубокий вдох и уверенно двигайтесь вперёд.',
    'de':
        'Sage still zu dir selbst: „Ich bin ruhig, ich bin klar, ich weiß, was zu tun ist." Nimm einen letzten tiefen Atemzug und gehe zuversichtlich vorwärts.',
    'fr':
        'Dis-toi silencieusement : « Je suis calme, je suis clair, je sais quoi faire. » Prends une dernière grande inspiration et avance avec confiance.',
    'it':
        'Dì silenziosamente a te stesso: "Sono calmo, sono lucido, so cosa fare." Fai un ultimo respiro profondo e vai avanti con fiducia.',
    'pt':
        'Diga silenciosamente para si mesmo: "Estou calmo, estou claro, sei o que fazer." Faça uma última respiração profunda e avance com confiança.',
    'es':
        'Dite en silencio: "Estoy tranquilo, estoy claro, sé qué hacer." Toma una última respiración profunda y avanza con confianza.',
    'id':
        'Katakan dalam hati: "Aku tenang, aku jernih, aku tahu apa yang harus dilakukan." Ambil satu napas dalam terakhir dan melangkah maju dengan percaya diri.',
    'hi':
        'चुपचाप खुद से कहें: "मैं शांत हूं, मैं स्पष्ट हूं, मुझे पता है क्या करना है।" एक आखिरी गहरी सांस लें और आत्मविश्वास से आगे बढ़ें।',
    'ja':
        '「私は落ち着いている、頭が明晰だ、何をすべきか分かっている」と心の中で言いましょう。最後にもう一度深呼吸し、自信を持って前に進んでください。',
    'ko':
        '마음속으로 스스로에게 말하세요: "나는 평온하다, 나는 명확하다, 무엇을 해야 할지 안다." 마지막으로 깊게 한 번 숨을 쉬고 자신 있게 앞으로 나아가세요.',
  },

  // — Sleep Prep (15 min, 7 steps) —
  'meditation.sleep_prep.name': {
    'en': 'Sleep Prep',
    'ru': 'Подготовка ко сну',
    'de': 'Schlafvorbereitung',
    'fr': 'Préparation au sommeil',
    'it': 'Preparazione al sonno',
    'pt': 'Preparação para o sono',
    'es': 'Preparación para dormir',
    'id': 'Persiapan tidur',
    'hi': 'नींद की तैयारी',
    'ja': '睡眠準備',
    'ko': '수면 준비',
  },
  'meditation.sleep_prep.desc': {
    'en': 'Wind down and ease into restful sleep',
    'ru': 'Успокойтесь и плавно погрузитесь в спокойный сон',
    'de': 'Entspanne dich und gleite in ruhigen Schlaf',
    'fr': 'Décompresse et glisse vers un sommeil réparateur',
    'it': 'Rallenta e scivolate in un sonno riposante',
    'pt': 'Relaxe e entre em um sono reparador',
    'es': 'Desconéctate y deslízate hacia un sueño reparador',
    'id': 'Tenangkan diri dan masuk ke tidur nyenyak',
    'hi': 'शांत हों और आरामदायक नींद में उतरें',
    'ja': '落ち着いて安らかな眠りへと移行する',
    'ko': '긴장을 풀고 편안한 수면으로 이어지기',
  },
  'meditation.sleep_prep.step1': {
    'en':
        'Lie down in a comfortable position. Dim any remaining lights. Let your arms rest at your sides and allow your body to feel heavy and supported.',
    'ru':
        'Лягте в удобное положение. Приглушите оставшийся свет. Позвольте рукам лечь вдоль тела и ощутите, как тело тяжелеет и расслабляется.',
    'de':
        'Leg dich in eine bequeme Position. Dimme das restliche Licht. Lass deine Arme an deinen Seiten ruhen und spüre, wie dein Körper schwer und getragen wird.',
    'fr':
        'Allonge-toi dans une position confortable. Tamise les lumières restantes. Laisse tes bras reposer le long du corps et permets à ton corps de se sentir lourd et soutenu.',
    'it':
        'Sdraiati in una posizione comoda. Attenua le luci rimanenti. Lascia le braccia riposare ai lati e permetti al tuo corpo di sentirsi pesante e sostenuto.',
    'pt':
        'Deite-se em uma posição confortável. Diminua as luzes restantes. Deixe os braços descansarem ao lado do corpo e permita que ele pareça pesado e sustentado.',
    'es':
        'Túmbate en una posición cómoda. Atenúa las luces restantes. Deja los brazos descansar a los lados y permite que tu cuerpo se sienta pesado y apoyado.',
    'id':
        'Berbaringlah dalam posisi yang nyaman. Redupkan cahaya yang tersisa. Biarkan lenganmu beristirahat di sisi tubuh dan biarkan tubuhmu terasa berat dan tertopang.',
    'hi':
        'आरामदायक स्थिति में लेट जाएं। बची हुई रोशनी मद्धिम करें। हाथों को बगल में आराम दें और शरीर को भारी और सहारे में महसूस करने दें।',
    'ja':
        '楽な姿勢で横になりましょう。残りの光を暗くしてください。腕を体の横に休ませ、体が重く支えられているように感じさせましょう。',
    'ko':
        '편안한 자세로 누우세요. 남은 불빛을 어둡게 하세요. 팔을 양옆에 놓고 몸이 무겁고 지지받는 느낌이 들게 두세요.',
  },
  'meditation.sleep_prep.step2': {
    'en':
        'Take five long, slow breaths. With each exhale, feel yourself sinking a little deeper into the mattress. There is nothing you need to do right now.',
    'ru':
        'Сделайте пять длинных, медленных вдохов. С каждым выдохом ощущайте, как всё глубже погружаетесь в матрас. Прямо сейчас вам ничего не нужно делать.',
    'de':
        'Nimm fünf lange, langsame Atemzüge. Mit jedem Ausatmen spüre, wie du ein wenig tiefer in die Matratze sinkst. Es gibt nichts, was du jetzt tun musst.',
    'fr':
        'Prends cinq longues et lentes respirations. À chaque expiration, sens-toi t\'enfoncer un peu plus dans le matelas. Il n\'y a rien que tu doives faire maintenant.',
    'it':
        'Fai cinque respiri lunghi e lenti. Ad ogni espirazione, senti di affondare un po\' più in profondità nel materasso. Non c\'è nulla che tu debba fare in questo momento.',
    'pt':
        'Faça cinco respirações longas e lentas. A cada expiração, sinta-se afundando um pouco mais no colchão. Não há nada que você precise fazer agora.',
    'es':
        'Toma cinco respiraciones largas y lentas. Con cada exhalación, siéntete hundiéndote un poco más en el colchón. No hay nada que necesites hacer ahora mismo.',
    'id':
        'Ambil lima napas panjang dan lambat. Dengan setiap embusan napas, rasakan dirimu sedikit lebih dalam ke kasur. Tidak ada yang perlu kamu lakukan sekarang.',
    'hi':
        'पांच लंबी, धीमी सांसें लें। हर सांस छोड़ते समय महसूस करें कि आप थोड़ा और गद्दे में धंस रहे हैं। अभी आपको कुछ भी करने की जरूरत नहीं है।',
    'ja':
        '5回、長くゆっくりと呼吸しましょう。息を吐くたびに、少しずつマットレスに沈んでいくのを感じてください。今は何もする必要はありません。',
    'ko':
        '길고 느리게 다섯 번 숨을 쉬세요. 내쉴 때마다 매트리스 속으로 조금씩 더 가라앉는 느낌을 받으세요. 지금 당장 해야 할 일은 아무것도 없습니다.',
  },
  'meditation.sleep_prep.step3': {
    'en':
        'Relax your face completely — forehead, eyes, jaw. Let your tongue rest softly on the floor of your mouth. Release any held expression.',
    'ru':
        'Полностью расслабьте лицо — лоб, глаза, челюсть. Пусть язык мягко ляжет на дно рта. Отпустите любое напряжение в мимике.',
    'de':
        'Entspanne dein Gesicht vollständig — Stirn, Augen, Kiefer. Lass deine Zunge sanft auf dem Boden deines Mundes ruhen. Löse jeden gehaltenen Ausdruck.',
    'fr':
        'Détends complètement ton visage — front, yeux, mâchoire. Laisse ta langue reposer doucement sur le plancher de ta bouche. Relâche toute expression retenue.',
    'it':
        'Rilassa completamente il viso — fronte, occhi, mascella. Lascia che la lingua riposi dolcemente sul fondo della bocca. Libera qualsiasi espressione trattenuta.',
    'pt':
        'Relaxe completamente o rosto — testa, olhos, maxilar. Deixe a língua descansar suavemente no assoalho da boca. Libere qualquer expressão retida.',
    'es':
        'Relaja completamente el rostro — frente, ojos, mandíbula. Deja que tu lengua descanse suavemente en el suelo de la boca. Libera cualquier expresión retenida.',
    'id':
        'Rilekskan wajahmu sepenuhnya — dahi, mata, rahang. Biarkan lidah beristirahat lembut di dasar mulut. Lepaskan ekspresi apa pun yang tertahan.',
    'hi':
        'अपना चेहरा पूरी तरह ढीला करें — माथा, आंखें, जबड़ा। जीभ को मुंह के तल पर धीरे से टिकने दें। कोई भी रुकी हुई अभिव्यक्ति छोड़ दें।',
    'ja':
        '顔を完全にリラックスさせましょう — 額、目、顎。舌を口の底にそっと置きましょう。抱えている表情をすべて解放してください。',
    'ko':
        '얼굴을 완전히 이완시키세요 — 이마, 눈, 턱. 혀를 입 바닥에 부드럽게 내려두세요. 굳어있는 표정을 풀어주세요.',
  },
  'meditation.sleep_prep.step4': {
    'en':
        'Soften your shoulders, chest, and arms. Feel warmth spreading through your hands and fingers as your muscles let go.',
    'ru':
        'Расслабьте плечи, грудь и руки. Почувствуйте тепло, распространяющееся по ладоням и пальцам, по мере того как мышцы отпускают.',
    'de':
        'Entspanne deine Schultern, Brust und Arme. Spüre Wärme, die sich durch deine Hände und Finger ausbreitet, wenn deine Muskeln loslassen.',
    'fr':
        'Assouplis tes épaules, ta poitrine et tes bras. Sens la chaleur se répandre dans tes mains et tes doigts au fur et à mesure que tes muscles se relâchent.',
    'it':
        'Ammorbidisci le spalle, il petto e le braccia. Senti il calore diffondersi attraverso le mani e le dita mentre i muscoli si rilassano.',
    'pt':
        'Amoleça os ombros, o peito e os braços. Sinta o calor se espalhando pelas mãos e dedos enquanto os músculos relaxam.',
    'es':
        'Suaviza los hombros, el pecho y los brazos. Siente el calor extendiéndose por las manos y los dedos mientras los músculos se sueltan.',
    'id':
        'Lembutkan bahu, dada, dan lenganmu. Rasakan kehangatan yang menyebar melalui tangan dan jari-jari saat ototmu mengendur.',
    'hi':
        'कंधे, सीना और बाहें नरम करें। जैसे-जैसे मांसपेशियां ढीली होती हैं, हाथों और उंगलियों में फैलती गर्माहट महसूस करें।',
    'ja':
        '肩、胸、腕をゆるめましょう。筋肉が解けるにつれ、手と指に温かさが広がるのを感じてください。',
    'ko':
        '어깨, 가슴, 팔의 긴장을 풀어주세요. 근육이 이완되면서 손과 손가락에 온기가 퍼지는 것을 느껴보세요.',
  },
  'meditation.sleep_prep.step5': {
    'en':
        'Let your legs become heavy. Release your thighs, calves, and feet. Imagine the tension flowing down and out through your toes.',
    'ru':
        'Пусть ноги потяжелеют. Расслабьте бёдра, икры и ступни. Представьте, как напряжение стекает вниз и уходит через кончики пальцев.',
    'de':
        'Lass deine Beine schwer werden. Entspanne deine Oberschenkel, Waden und Füße. Stelle dir vor, wie die Spannung nach unten fließt und durch deine Zehen herauskommt.',
    'fr':
        'Laisse tes jambes devenir lourdes. Relâche tes cuisses, mollets et pieds. Imagine la tension qui coule vers le bas et sort par tes orteils.',
    'it':
        'Lascia che le gambe diventino pesanti. Rilascia le cosce, i polpacci e i piedi. Immagina la tensione che scorre verso il basso e fuoriesce dalle dita dei piedi.',
    'pt':
        'Deixe suas pernas ficarem pesadas. Solte as coxas, panturrilhas e pés. Imagine a tensão fluindo para baixo e saindo pelos dedos dos pés.',
    'es':
        'Deja que tus piernas se vuelvan pesadas. Suelta los muslos, pantorrillas y pies. Imagina la tensión fluyendo hacia abajo y saliendo por los dedos de los pies.',
    'id':
        'Biarkan kakimu menjadi berat. Lepaskan paha, betis, dan telapak kaki. Bayangkan ketegangan mengalir ke bawah dan keluar melalui jari-jari kakimu.',
    'hi':
        'पैरों को भारी होने दें। जांघें, पिंडलियां और पैर ढीले करें। कल्पना करें कि तनाव नीचे बह रहा है और पैर की उंगलियों से बाहर जा रहा है।',
    'ja':
        '脚を重くしましょう。太もも、ふくらはぎ、足をゆるめてください。緊張が下に流れ、つま先から抜け出るイメージをしましょう。',
    'ko':
        '다리가 무거워지도록 두세요. 허벅지, 종아리, 발을 풀어주세요. 긴장감이 아래로 흘러 발가락을 통해 빠져나가는 것을 상상하세요.',
  },
  'meditation.sleep_prep.step6': {
    'en':
        'Picture a quiet, safe place — a forest path, a calm shore, a cozy room. You are safe, warm, and completely at rest. Let sleep come naturally.',
    'ru':
        'Представьте тихое, безопасное место — лесная тропинка, спокойный берег, уютная комната. Вы в безопасности, вам тепло, вы полностью расслаблены. Позвольте сну прийти естественно.',
    'de':
        'Stell dir einen ruhigen, sicheren Ort vor — einen Waldweg, ein ruhiges Ufer, ein gemütliches Zimmer. Du bist sicher, warm und vollkommen ruhig. Lass den Schlaf natürlich kommen.',
    'fr':
        'Imagine un endroit calme et sûr — un chemin forestier, un rivage paisible, une chambre douillette. Tu es en sécurité, au chaud et complètement au repos. Laisse le sommeil venir naturellement.',
    'it':
        'Immagina un luogo tranquillo e sicuro — un sentiero nel bosco, una riva calma, una stanza accogliente. Sei al sicuro, al caldo e completamente a riposo. Lascia che il sonno venga naturalmente.',
    'pt':
        'Imagine um lugar tranquilo e seguro — um caminho na floresta, uma costa calma, uma sala aconchegante. Você está seguro, aquecido e completamente em repouso. Deixe o sono vir naturalmente.',
    'es':
        'Imagina un lugar tranquilo y seguro — un sendero en el bosque, una orilla tranquila, una habitación acogedora. Estás seguro, abrigado y completamente en reposo. Deja que el sueño llegue naturalmente.',
    'id':
        'Bayangkan tempat yang tenang dan aman — jalan setapak hutan, pantai yang tenang, ruangan yang nyaman. Kamu aman, hangat, dan benar-benar beristirahat. Biarkan tidur datang secara alami.',
    'hi':
        'एक शांत, सुरक्षित जगह की कल्पना करें — जंगल की पगडंडी, शांत किनारा, आरामदायक कमरा। आप सुरक्षित, गर्म और पूरी तरह आराम में हैं। नींद को स्वाभाविक रूप से आने दें।',
    'ja':
        '静かで安全な場所をイメージしましょう — 森の小道、穏やかな岸辺、居心地の良い部屋。あなたは安全で、温かく、完全に安らいでいます。眠りが自然に訪れるにまかせましょう。',
    'ko':
        '조용하고 안전한 장소를 상상하세요 — 숲속 오솔길, 잔잔한 해변, 아늑한 방. 당신은 안전하고 따뜻하며 완전히 쉬고 있습니다. 잠이 자연스럽게 오도록 두세요.',
  },
  'meditation.sleep_prep.step7': {
    'en':
        'There is nowhere to be, nothing to do. Your only task now is to rest. Breathe slowly... and drift...',
    'ru':
        'Вам некуда спешить, нечего делать. Ваша единственная задача сейчас — отдыхать. Дышите медленно... и уплывайте...',
    'de':
        'Es gibt keinen Ort, an dem du sein musst, nichts zu tun. Deine einzige Aufgabe jetzt ist es, auszuruhen. Atme langsam... und treibe dahin...',
    'fr':
        'Il n\'y a nulle part où être, rien à faire. Ta seule tâche maintenant est de te reposer. Respire lentement... et dérive...',
    'it':
        'Non c\'è nessun posto dove essere, niente da fare. Il tuo unico compito ora è riposare. Respira lentamente... e lasciati andare...',
    'pt':
        'Não há lugar para estar, nada para fazer. Sua única tarefa agora é descansar. Respire devagar... e deixe-se levar...',
    'es':
        'No hay ningún lugar donde estar, nada que hacer. Tu única tarea ahora es descansar. Respira despacio... y déjate llevar...',
    'id':
        'Tidak ada tempat yang harus didatangi, tidak ada yang harus dilakukan. Satu-satunya tugasmu sekarang adalah beristirahat. Bernapaslah perlahan... dan mengalir...',
    'hi':
        'कहीं जाना नहीं है, कुछ करना नहीं है। अभी आपका एकमात्र काम है आराम करना। धीरे-धीरे सांस लें... और बह जाएं...',
    'ja':
        'どこにも行く必要はなく、何もする必要はありません。今のあなたの唯一の仕事は休むことです。ゆっくりと呼吸して... 漂いましょう...',
    'ko':
        '있어야 할 곳도, 해야 할 일도 없습니다. 지금 당신의 유일한 임무는 쉬는 것입니다. 천천히 숨을 쉬세요... 그리고 흘러가세요...',
  },

  // — Stress Relief (8 min, 6 steps) —
  'meditation.stress_relief.name': {
    'en': 'Stress Relief',
    'ru': 'Снятие стресса',
    'de': 'Stressabbau',
    'fr': 'Soulagement du stress',
    'it': 'Sollievo dallo stress',
    'pt': 'Alívio do estresse',
    'es': 'Alivio del estrés',
    'id': 'Pelepas stres',
    'hi': 'तनाव से राहत',
    'ja': 'ストレス解消',
    'ko': '스트레스 해소',
  },
  'meditation.stress_relief.desc': {
    'en': 'Release tension and restore balance',
    'ru': 'Снимите напряжение и восстановите равновесие',
    'de': 'Spannung lösen und Gleichgewicht wiederherstellen',
    'fr': 'Libère les tensions et restore l\'équilibre',
    'it': 'Rilascia la tensione e ripristina l\'equilibrio',
    'pt': 'Libere a tensão e restaure o equilíbrio',
    'es': 'Libera la tensión y restaura el equilibrio',
    'id': 'Lepaskan ketegangan dan pulihkan keseimbangan',
    'hi': 'तनाव छोड़ें और संतुलन बहाल करें',
    'ja': '緊張を解放してバランスを回復する',
    'ko': '긴장을 풀고 균형을 회복하기',
  },
  'meditation.stress_relief.step1': {
    'en':
        'Stop what you\'re doing. Sit or stand comfortably. Acknowledge: right now, in this moment, you are safe.',
    'ru':
        'Остановитесь. Сядьте или встаньте удобно. Признайте: прямо сейчас, в эту минуту, вы в безопасности.',
    'de':
        'Höre mit dem auf, was du tust. Sitze oder stehe bequem. Erkenne an: Gerade jetzt, in diesem Moment, bist du sicher.',
    'fr':
        'Arrête ce que tu fais. Assieds-toi ou tiens-toi debout confortablement. Reconnais : là, en ce moment, tu es en sécurité.',
    'it':
        'Smetti di fare quello che stai facendo. Siediti o stai in piedi comodamente. Riconosci: proprio ora, in questo momento, sei al sicuro.',
    'pt':
        'Pare o que está fazendo. Sente-se ou fique de pé confortavelmente. Reconheça: agora, neste momento, você está seguro.',
    'es':
        'Detente en lo que estás haciendo. Siéntate o ponte de pie cómodamente. Reconoce: ahora mismo, en este momento, estás a salvo.',
    'id':
        'Hentikan apa yang sedang kamu lakukan. Duduklah atau berdirilah dengan nyaman. Akui: saat ini, di momen ini, kamu aman.',
    'hi':
        'जो कर रहे हैं उसे रोकें। आराम से बैठें या खड़े हों। स्वीकार करें: अभी, इस पल में, आप सुरक्षित हैं।',
    'ja':
        'やっていることを止めましょう。楽な姿勢で座るか立ちましょう。認識してください：今この瞬間、あなたは安全です。',
    'ko':
        '하던 일을 멈추세요. 편안하게 앉거나 서세요. 인정하세요: 바로 지금 이 순간, 당신은 안전합니다.',
  },
  'meditation.stress_relief.step2': {
    'en':
        'Breathe in through your nose for 4 counts. Hold for 2. Breathe out through your mouth for 6. Feel your nervous system begin to slow.',
    'ru':
        'Вдохните через нос на 4 счёта. Задержите на 2. Выдохните через рот на 6. Почувствуйте, как нервная система начинает замедляться.',
    'de':
        'Atme 4 Zählungen durch die Nase ein. Halte für 2 an. Atme 6 Zählungen durch den Mund aus. Spüre, wie dein Nervensystem beginnt, langsamer zu werden.',
    'fr':
        'Inspire par le nez pendant 4 temps. Retiens pendant 2. Expire par la bouche pendant 6. Sens ton système nerveux commencer à ralentir.',
    'it':
        'Inspira dal naso per 4 tempi. Trattieni per 2. Espira dalla bocca per 6. Senti il tuo sistema nervoso iniziare a rallentare.',
    'pt':
        'Inspire pelo nariz por 4 tempos. Segure por 2. Expire pela boca por 6. Sinta seu sistema nervoso começar a desacelerar.',
    'es':
        'Inhala por la nariz durante 4 tiempos. Retén durante 2. Exhala por la boca durante 6. Siente tu sistema nervioso empezar a calmarse.',
    'id':
        'Hirup napas melalui hidung selama 4 hitungan. Tahan selama 2. Hembuskan melalui mulut selama 6. Rasakan sistem sarafmu mulai melambat.',
    'hi':
        'नाक से 4 गिनती तक सांस लें। 2 गिनती रोकें। मुंह से 6 गिनती तक छोड़ें। तंत्रिका तंत्र को धीमा होता महसूस करें।',
    'ja':
        '鼻から4カウントで吸います。2カウント止めます。口から6カウントで吐きます。神経系がゆっくりになり始めるのを感じましょう。',
    'ko':
        '코로 4박자 동안 들이쉬세요. 2박자 멈추세요. 입으로 6박자 동안 내쉬세요. 신경계가 진정되기 시작하는 것을 느껴보세요.',
  },
  'meditation.stress_relief.step3': {
    'en':
        'Tense every muscle in your body for 5 seconds — fists, shoulders, face, legs. Then release all at once. Notice the flood of relaxation.',
    'ru':
        'Напрягите все мышцы тела на 5 секунд — кулаки, плечи, лицо, ноги. Затем отпустите всё сразу. Почувствуйте волну расслабления.',
    'de':
        'Spanne jeden Muskel in deinem Körper für 5 Sekunden an — Fäuste, Schultern, Gesicht, Beine. Dann alles auf einmal loslassen. Bemerke die Welle der Entspannung.',
    'fr':
        'Contracte chaque muscle de ton corps pendant 5 secondes — poings, épaules, visage, jambes. Puis relâche tout d\'un coup. Remarque le flot de relaxation.',
    'it':
        'Contrai ogni muscolo del corpo per 5 secondi — pugni, spalle, viso, gambe. Poi rilascia tutto in una volta. Nota l\'ondata di relax.',
    'pt':
        'Contraia todos os músculos do seu corpo por 5 segundos — punhos, ombros, rosto, pernas. Depois solte tudo de uma vez. Perceba a onda de relaxamento.',
    'es':
        'Tensa todos los músculos de tu cuerpo durante 5 segundos — puños, hombros, cara, piernas. Luego suelta todo a la vez. Nota la ola de relajación.',
    'id':
        'Tegangkan setiap otot di tubuhmu selama 5 detik — kepalan tangan, bahu, wajah, kaki. Kemudian lepaskan semuanya sekaligus. Rasakan gelombang relaksasi.',
    'hi':
        'शरीर की हर मांसपेशी को 5 सेकंड के लिए कसें — मुट्ठियां, कंधे, चेहरा, पैर। फिर एक साथ सब छोड़ दें। शांति की लहर महसूस करें।',
    'ja':
        '体の全ての筋肉を5秒間緊張させましょう — 拳、肩、顔、脚。そして一度に全て解放します。リラクゼーションの波に気づきましょう。',
    'ko':
        '온몸의 근육을 5초 동안 긴장시키세요 — 주먹, 어깨, 얼굴, 다리. 그런 다음 한꺼번에 모두 풀어주세요. 이완의 물결을 느껴보세요.',
  },
  'meditation.stress_relief.step4': {
    'en':
        'Observe what is stressing you from a distance — as if watching clouds pass across a sky. The clouds are not the sky. The stress is not you.',
    'ru':
        'Наблюдайте за источником стресса издалека — словно смотрите на облака, плывущие по небу. Облака — не небо. Стресс — не вы.',
    'de':
        'Beobachte, was dich stresst, aus der Distanz — als würdest du Wolken über einen Himmel ziehen sehen. Die Wolken sind nicht der Himmel. Der Stress bist nicht du.',
    'fr':
        'Observe ce qui te stresse à distance — comme si tu regardais des nuages passer dans un ciel. Les nuages ne sont pas le ciel. Le stress n\'est pas toi.',
    'it':
        'Osserva ciò che ti stresa da lontano — come se guardassi le nuvole passare nel cielo. Le nuvole non sono il cielo. Lo stress non sei tu.',
    'pt':
        'Observe o que está te estressando à distância — como se estivesse vendo nuvens passar pelo céu. As nuvens não são o céu. O estresse não é você.',
    'es':
        'Observa lo que te estresa desde la distancia — como si vieras nubes pasar por un cielo. Las nubes no son el cielo. El estrés no eres tú.',
    'id':
        'Amati apa yang membuatmu stres dari jarak jauh — seolah melihat awan berlalu di langit. Awan bukanlah langit. Stres bukan dirimu.',
    'hi':
        'जो आपको तनाव दे रहा है उसे दूरी से देखें — जैसे आसमान पर बादल गुजरते देखते हैं। बादल आसमान नहीं हैं। तनाव आप नहीं हैं।',
    'ja':
        'ストレスの原因を距離を置いて観察してください — 空を流れる雲を眺めるように。雲は空ではありません。ストレスはあなたではありません。',
    'ko':
        '당신을 스트레스 받게 하는 것을 거리를 두고 관찰하세요 — 하늘을 지나는 구름을 바라보듯이. 구름은 하늘이 아닙니다. 스트레스는 당신이 아닙니다.',
  },
  'meditation.stress_relief.step5': {
    'en':
        'Think of one small action you can take after this session. Just one. Set everything else aside for now.',
    'ru':
        'Подумайте об одном небольшом действии, которое сделаете после этой сессии. Всего одно. Всё остальное пока отложите в сторону.',
    'de':
        'Denke an eine kleine Handlung, die du nach dieser Sitzung unternehmen kannst. Nur eine. Stelle alles andere vorerst beiseite.',
    'fr':
        'Pense à une petite action que tu peux entreprendre après cette séance. Juste une. Mets tout le reste de côté pour l\'instant.',
    'it':
        'Pensa a una piccola azione che puoi intraprendere dopo questa sessione. Solo una. Metti tutto il resto da parte per ora.',
    'pt':
        'Pense em uma pequena ação que você pode fazer após esta sessão. Apenas uma. Coloque todo o resto de lado por enquanto.',
    'es':
        'Piensa en una pequeña acción que puedas realizar después de esta sesión. Solo una. Deja todo lo demás de lado por ahora.',
    'id':
        'Pikirkan satu tindakan kecil yang bisa kamu lakukan setelah sesi ini. Hanya satu. Sisihkan yang lainnya untuk saat ini.',
    'hi':
        'इस सत्र के बाद एक छोटी सी कार्रवाई के बारे में सोचें जो आप कर सकते हैं। बस एक। बाकी सब कुछ अभी के लिए एक तरफ रख दें।',
    'ja':
        'このセッションの後にできる小さなアクションを一つ考えましょう。ただ一つだけ。他のことは今は置いておきましょう。',
    'ko':
        '이 세션 후에 할 수 있는 작은 행동 하나를 생각해보세요. 딱 하나만. 다른 것들은 지금은 잠시 내려두세요.',
  },
  'meditation.stress_relief.step6': {
    'en':
        'Take three final deep breaths. With each exhale, release a little more tension. You are more resilient than you know.',
    'ru':
        'Сделайте три последних глубоких вдоха. С каждым выдохом отпускайте чуть больше напряжения. Вы устойчивее, чем думаете.',
    'de':
        'Nimm drei letzte tiefe Atemzüge. Mit jedem Ausatmen lasse etwas mehr Spannung los. Du bist widerstandsfähiger als du denkst.',
    'fr':
        'Prends trois dernières profondes respirations. À chaque expiration, relâche un peu plus de tension. Tu es plus résilient que tu ne le crois.',
    'it':
        'Fai tre ultimi respiri profondi. Ad ogni espirazione, lascia andare un po\' più di tensione. Sei più resiliente di quanto pensi.',
    'pt':
        'Faça três últimas respirações profundas. A cada expiração, libere um pouco mais de tensão. Você é mais resiliente do que sabe.',
    'es':
        'Toma tres últimas respiraciones profundas. Con cada exhalación, suelta un poco más de tensión. Eres más resistente de lo que crees.',
    'id':
        'Ambil tiga napas dalam terakhir. Dengan setiap embusan napas, lepaskan sedikit lebih banyak ketegangan. Kamu lebih tangguh dari yang kamu tahu.',
    'hi':
        'तीन आखिरी गहरी सांसें लें। हर सांस छोड़ते समय थोड़ा और तनाव छोड़ें। आप जितना सोचते हैं उससे ज्यादा मजबूत हैं।',
    'ja':
        '最後に三回深呼吸しましょう。息を吐くたびに、もう少し緊張を手放してください。あなたは自分が思っているより強いのです。',
    'ko':
        '마지막으로 깊게 세 번 숨을 쉬세요. 내쉴 때마다 조금씩 더 긴장을 풀어주세요. 당신은 스스로 아는 것보다 더 강합니다.',
  },

  // — Anxiety Reset (5 min, 5 steps) —
  'meditation.anxiety_reset.name': {
    'en': 'Anxiety Reset',
    'ru': 'Сброс тревоги',
    'de': 'Angst-Reset',
    'fr': 'Réinitialisation de l\'anxiété',
    'it': 'Reset dell\'ansia',
    'pt': 'Redefinição da ansiedade',
    'es': 'Reinicio de la ansiedad',
    'id': 'Setel ulang kecemasan',
    'hi': 'चिंता रीसेट',
    'ja': '不安リセット',
    'ko': '불안 리셋',
  },
  'meditation.anxiety_reset.desc': {
    'en': 'Defuse anxiety fast — no fluff, just the essentials',
    'ru': 'Быстро сбросьте тревогу — без лишних слов, только суть',
    'de': 'Angst schnell abbauen — keine Floskeln, nur das Wesentliche',
    'fr': 'Désamorcer l\'anxiété rapidement — sans fioritures, juste l\'essentiel',
    'it': 'Disinnescare l\'ansia velocemente — senza fronzoli, solo l\'essenziale',
    'pt': 'Eliminar a ansiedade rapidamente — sem rodeios, só o essencial',
    'es': 'Disipar la ansiedad rápido — sin rodeos, solo lo esencial',
    'id': 'Redakan kecemasan dengan cepat — langsung ke intinya',
    'hi': 'जल्दी से चिंता दूर करें — बिना बेकार बातों के, बस जरूरी',
    'ja': '不安を素早く解消する — 余計なことなし、本質だけ',
    'ko': '빠르게 불안을 해소하기 — 군더더기 없이 핵심만',
  },
  'meditation.anxiety_reset.pose_name': {
    'en': 'Grounded seat',
    'ru': 'Устойчивая посадка',
    'de': 'Geerdetete Sitzhaltung',
    'fr': 'Assise ancrée',
    'it': 'Seduta radicata',
    'pt': 'Assento firme',
    'es': 'Asiento estable',
    'id': 'Duduk stabil',
    'hi': 'स्थिर बैठक',
    'ja': '安定した座位',
    'ko': '안정된 앉은 자세',
  },
  'meditation.anxiety_reset.pose_desc': {
    'en':
        'Sit down wherever you are — a chair, the floor, or a step. Both feet flat. Hands on your thighs, palms down. You don\'t need to fix anything right now.',
    'ru':
        'Сядьте где угодно — на стул, на пол, на ступеньку. Обе стопы плоско. Руки на бёдрах ладонями вниз. Вам не нужно ничего решать прямо сейчас.',
    'de':
        'Setze dich hin, wo du bist — auf einen Stuhl, den Boden oder eine Stufe. Beide Füße flach. Hände auf den Oberschenkeln, Handflächen nach unten. Du musst jetzt nichts reparieren.',
    'fr':
        'Assieds-toi où tu es — sur une chaise, le sol ou une marche. Les deux pieds à plat. Mains sur les cuisses, paumes vers le bas. Tu n\'as pas besoin de régler quoi que ce soit maintenant.',
    'it':
        'Siediti dove sei — su una sedia, il pavimento o un gradino. Entrambi i piedi piatti. Mani sulle cosce, palmi verso il basso. Non hai bisogno di risolvere nulla adesso.',
    'pt':
        'Sente-se onde estiver — numa cadeira, no chão ou num degrau. Ambos os pés apoiados. Mãos nas coxas, palmas para baixo. Você não precisa resolver nada agora.',
    'es':
        'Siéntate donde estés — en una silla, el suelo o un escalón. Ambos pies apoyados. Manos en los muslos, palmas hacia abajo. No necesitas arreglar nada ahora mismo.',
    'id':
        'Duduklah di mana saja kamu berada — kursi, lantai, atau tangga. Kedua kaki rata. Tangan di paha, telapak menghadap ke bawah. Kamu tidak perlu memperbaiki apa pun sekarang.',
    'hi':
        'जहां भी हों, बैठ जाएं — कुर्सी, फर्श, या सीढ़ी पर। दोनों पैर सपाट। हाथ जांघों पर, हथेलियां नीचे। अभी कुछ ठीक करने की जरूरत नहीं है।',
    'ja':
        '今いる場所に座りましょう — 椅子、床、または段差の上。両足を平らに。手を太ももの上に置き、手のひらを下に向けます。今すぐ何かを直す必要はありません。',
    'ko':
        '지금 있는 자리에 앉으세요 — 의자, 바닥, 또는 계단. 양 발을 평평하게. 손을 허벅지 위에 놓고 손바닥이 아래를 향하게 하세요. 지금 당장 무언가를 고칠 필요는 없습니다.',
  },
  'meditation.anxiety_reset.step1': {
    'en':
        'Stop. Sit down if you can. Put your hands on your thighs, palms down. You don\'t have to fix anything right now.',
    'ru':
        'Остановитесь. Сядьте, если можете. Положите руки на бёдра ладонями вниз. Прямо сейчас вам ничего не нужно исправлять.',
    'de':
        'Halt inne. Setze dich hin, wenn du kannst. Lege deine Hände auf die Oberschenkel, Handflächen nach unten. Du musst jetzt nichts reparieren.',
    'fr':
        'Arrête-toi. Assieds-toi si tu peux. Pose tes mains sur les cuisses, paumes vers le bas. Tu n\'as pas à régler quoi que ce soit maintenant.',
    'it':
        'Fermati. Siediti se puoi. Metti le mani sulle cosce, palmi verso il basso. Non devi sistemare nulla in questo momento.',
    'pt':
        'Pare. Sente-se se puder. Coloque as mãos nas coxas, palmas para baixo. Não precisa resolver nada agora.',
    'es':
        'Para. Siéntate si puedes. Pon las manos en los muslos, palmas hacia abajo. No tienes que arreglar nada ahora mismo.',
    'id':
        'Berhenti. Duduklah jika bisa. Letakkan tanganmu di paha, telapak menghadap ke bawah. Kamu tidak perlu memperbaiki apa pun sekarang.',
    'hi':
        'रुकें। बैठ सकें तो बैठ जाएं। हाथ जांघों पर, हथेलियां नीचे। अभी कुछ ठीक करने की जरूरत नहीं।',
    'ja':
        '止まりましょう。できれば座ってください。手を太ももの上に置き、手のひらを下にします。今すぐ何も直す必要はありません。',
    'ko':
        '멈추세요. 앉을 수 있다면 앉으세요. 손을 허벅지에 올리고 손바닥이 아래를 향하게 하세요. 지금 당장 아무것도 고칠 필요가 없습니다.',
  },
  'meditation.anxiety_reset.step2': {
    'en':
        'Breathe in through your nose for 4 counts, hold for 4, out through your mouth for 4. This tells your body: the danger is not real. Do it three times.',
    'ru':
        'Вдохните через нос на 4 счёта, задержите на 4, выдохните через рот на 4. Это говорит телу: опасности нет. Повторите трижды.',
    'de':
        'Atme 4 Zählungen durch die Nase ein, halte für 4 an, atme 4 Zählungen durch den Mund aus. Das sagt deinem Körper: Die Gefahr ist nicht real. Mache es dreimal.',
    'fr':
        'Inspire par le nez pendant 4 temps, retiens pendant 4, expire par la bouche pendant 4. Cela dit à ton corps : le danger n\'est pas réel. Fais-le trois fois.',
    'it':
        'Inspira dal naso per 4 tempi, trattieni per 4, espira dalla bocca per 4. Questo dice al tuo corpo: il pericolo non è reale. Fallo tre volte.',
    'pt':
        'Inspire pelo nariz por 4 tempos, segure por 4, expire pela boca por 4. Isso diz ao seu corpo: o perigo não é real. Faça três vezes.',
    'es':
        'Inhala por la nariz durante 4 tiempos, retén durante 4, exhala por la boca durante 4. Esto le dice a tu cuerpo: el peligro no es real. Hazlo tres veces.',
    'id':
        'Hirup melalui hidung selama 4 hitungan, tahan selama 4, hembuskan melalui mulut selama 4. Ini memberitahu tubuhmu: bahayanya tidak nyata. Lakukan tiga kali.',
    'hi':
        'नाक से 4 गिनती सांस लें, 4 गिनती रोकें, मुंह से 4 गिनती छोड़ें। यह शरीर को बताता है: खतरा असली नहीं है। तीन बार करें।',
    'ja':
        '鼻から4カウントで吸い、4カウント止め、口から4カウントで吐きます。これが体に伝えます：危険は現実ではありません。三回繰り返しましょう。',
    'ko':
        '코로 4박자 들이쉬고, 4박자 멈추고, 입으로 4박자 내쉬세요. 이것이 몸에게 말합니다: 위험은 실재가 아닙니다. 세 번 하세요.',
  },
  'meditation.anxiety_reset.step3': {
    'en':
        'Notice your feet on the floor. Press them gently into the ground. Feel the surface. Notice your weight in the chair. You are here.',
    'ru':
        'Ощутите стопы на полу. Слегка вдавите их в пол. Почувствуйте поверхность. Ощутите вес тела на стуле. Вы здесь.',
    'de':
        'Bemerke deine Füße auf dem Boden. Drücke sie sanft in den Boden. Spüre die Oberfläche. Bemerke dein Gewicht auf dem Stuhl. Du bist hier.',
    'fr':
        'Remarque tes pieds sur le sol. Appuie-les doucement dans le sol. Sens la surface. Remarque ton poids dans la chaise. Tu es là.',
    'it':
        'Nota i tuoi piedi sul pavimento. Premi delicatamente nel suolo. Senti la superficie. Nota il tuo peso sulla sedia. Sei qui.',
    'pt':
        'Perceba seus pés no chão. Pressione-os suavemente no chão. Sinta a superfície. Perceba seu peso na cadeira. Você está aqui.',
    'es':
        'Nota tus pies en el suelo. Presiónales suavemente en el suelo. Siente la superficie. Nota tu peso en la silla. Estás aquí.',
    'id':
        'Perhatikan kakimu di lantai. Tekan lembut ke lantai. Rasakan permukaannya. Rasakan beratmu di kursi. Kamu ada di sini.',
    'hi':
        'जमीन पर पैरों को महसूस करें। उन्हें हल्के से जमीन में दबाएं। सतह को महसूस करें। कुर्सी पर अपना भार नोटिस करें। आप यहां हैं।',
    'ja':
        '床の上の足に気づきましょう。優しく床に押し付けてください。表面を感じましょう。椅子の上の自分の体重を感じましょう。あなたはここにいます。',
    'ko':
        '바닥에 닿은 발을 인식하세요. 바닥에 부드럽게 눌러보세요. 표면을 느껴보세요. 의자 위 몸무게를 느껴보세요. 당신은 여기에 있습니다.',
  },
  'meditation.anxiety_reset.step4': {
    'en':
        'The anxiety is a signal — not a fact. Ask yourself: what is the one concrete thing in front of me right now? Just one.',
    'ru':
        'Тревога — это сигнал, не факт. Спросите себя: что прямо сейчас передо мной — одно конкретное дело? Только одно.',
    'de':
        'Die Angst ist ein Signal — keine Tatsache. Frage dich: Was ist das eine konkrete Ding, das gerade vor mir liegt? Nur eines.',
    'fr':
        'L\'anxiété est un signal — pas un fait. Demande-toi : quelle est la chose concrète qui est devant moi maintenant ? Une seule.',
    'it':
        'L\'ansia è un segnale — non un fatto. Chiediti: qual è la cosa concreta davanti a me in questo momento? Solo una.',
    'pt':
        'A ansiedade é um sinal — não um fato. Pergunte-se: qual é a coisa concreta à minha frente agora? Só uma.',
    'es':
        'La ansiedad es una señal — no un hecho. Pregúntate: ¿cuál es la cosa concreta que tengo delante ahora mismo? Solo una.',
    'id':
        'Kecemasan adalah sinyal — bukan fakta. Tanyakan dirimu: apa satu hal nyata yang ada di hadapanku sekarang? Hanya satu.',
    'hi':
        'चिंता एक संकेत है — तथ्य नहीं। खुद से पूछें: अभी मेरे सामने एक ठोस चीज क्या है? बस एक।',
    'ja':
        '不安はシグナルです — 事実ではありません。自問してください：今この瞬間、目の前にある一つの具体的なことは何でしょう？ただ一つだけ。',
    'ko':
        '불안은 신호입니다 — 사실이 아닙니다. 스스로에게 물어보세요: 지금 내 앞에 있는 한 가지 구체적인 것은 무엇인가요? 딱 하나만.',
  },
  'meditation.anxiety_reset.step5': {
    'en':
        'Take a slow breath. Name one thing you can do in the next 10 minutes. Decide to start there. Open your eyes.',
    'ru':
        'Сделайте медленный вдох. Назовите одно действие, которое можно сделать за следующие 10 минут. Решите начать с него. Откройте глаза.',
    'de':
        'Atme langsam ein. Nenne eine Sache, die du in den nächsten 10 Minuten tun kannst. Entscheide dich, dort anzufangen. Öffne die Augen.',
    'fr':
        'Prends une respiration lente. Nomme une chose que tu peux faire dans les 10 prochaines minutes. Décide de commencer par là. Ouvre les yeux.',
    'it':
        'Fai un respiro lento. Nomina una cosa che puoi fare nei prossimi 10 minuti. Decidi di iniziare da lì. Apri gli occhi.',
    'pt':
        'Respire devagar. Nomeie uma coisa que você pode fazer nos próximos 10 minutos. Decida começar por lá. Abra os olhos.',
    'es':
        'Respira despacio. Nombra una cosa que puedas hacer en los próximos 10 minutos. Decide empezar por ahí. Abre los ojos.',
    'id':
        'Tarik napas perlahan. Sebutkan satu hal yang bisa kamu lakukan dalam 10 menit ke depan. Putuskan untuk mulai dari situ. Buka matamu.',
    'hi':
        'धीमी सांस लें। अगले 10 मिनट में कर सकने वाली एक चीज बताएं। वहीं से शुरू करने का फैसला करें। आंखें खोलें।',
    'ja':
        'ゆっくりと息を吸ってください。次の10分でできることを一つ挙げましょう。そこから始めると決めましょう。目を開けてください。',
    'ko':
        '천천히 숨을 들이쉬세요. 앞으로 10분 안에 할 수 있는 것 하나를 말해보세요. 거기서부터 시작하기로 결정하세요. 눈을 뜨세요.',
  },

  // — Morning Energizer (5 min, 5 steps) —
  'meditation.morning_wake.name': {
    'en': 'Morning Energizer',
    'ru': 'Утренний заряд',
    'de': 'Morgenenergie',
    'fr': 'Énergie du matin',
    'it': 'Energia mattutina',
    'pt': 'Energia matinal',
    'es': 'Energía matutina',
    'id': 'Energi pagi',
    'hi': 'सुबह की ऊर्जा',
    'ja': '朝のエネルギー充填',
    'ko': '아침 에너지 충전',
  },
  'meditation.morning_wake.desc': {
    'en': 'Wake up your mind and set a clear intention for the day',
    'ru': 'Разбудите разум и поставьте чёткое намерение на день',
    'de': 'Wecke deinen Geist und setze eine klare Absicht für den Tag',
    'fr': 'Réveille ton esprit et fixe une intention claire pour la journée',
    'it': 'Sveglia la mente e stabilisci un\'intenzione chiara per la giornata',
    'pt': 'Acorde sua mente e defina uma intenção clara para o dia',
    'es': 'Despierta tu mente y establece una intención clara para el día',
    'id': 'Bangunkan pikiranmu dan tetapkan niat yang jelas untuk hari ini',
    'hi': 'दिमाग को जगाएं और दिन के लिए स्पष्ट इरादा तय करें',
    'ja': '心を目覚めさせ、その日の明確な意図を設定する',
    'ko': '마음을 깨우고 하루를 위한 명확한 의도를 세우기',
  },
  'meditation.morning_wake.pose_name': {
    'en': 'Upright seat',
    'ru': 'Прямая посадка',
    'de': 'Aufrechte Sitzhaltung',
    'fr': 'Assise droite',
    'it': 'Seduta eretta',
    'pt': 'Postura ereta',
    'es': 'Asiento erguido',
    'id': 'Duduk tegak',
    'hi': 'सीधी बैठक',
    'ja': '背筋を伸ばした座位',
    'ko': '바른 앉은 자세',
  },
  'meditation.morning_wake.pose_desc': {
    'en':
        'Sit up straight or stand. Shoulders back. Take a full breath and let it out slowly. Today has not started yet — you get a clean slate.',
    'ru':
        'Сядьте прямо или встаньте. Плечи назад. Сделайте полный вдох и медленно выдохните. День ещё не начался — перед вами чистый лист.',
    'de':
        'Sitze aufrecht oder stehe. Schultern zurück. Atme tief durch und lass es langsam heraus. Der Tag hat noch nicht begonnen — du hast einen sauberen Anfang.',
    'fr':
        'Assieds-toi droit ou tiens-toi debout. Épaules en arrière. Prends une grande inspiration et laisse-la sortir lentement. La journée n\'a pas encore commencé — tu pars d\'une page blanche.',
    'it':
        'Siediti dritto o stai in piedi. Spalle indietro. Fai un respiro profondo e lascialo uscire lentamente. La giornata non è ancora iniziata — hai una lavagna pulita.',
    'pt':
        'Sente-se ereto ou fique em pé. Ombros para trás. Respire fundo e solte lentamente. O dia ainda não começou — você tem uma folha em branco.',
    'es':
        'Siéntate erguido o ponte de pie. Hombros hacia atrás. Haz una respiración completa y suéltala lentamente. El día todavía no ha comenzado — tienes una pizarra en blanco.',
    'id':
        'Duduklah tegak atau berdirilah. Bahu ke belakang. Ambil napas penuh dan hembuskan perlahan. Hari belum dimulai — kamu punya lembaran bersih.',
    'hi':
        'सीधे बैठें या खड़े हों। कंधे पीछे। पूरी सांस लें और धीरे से छोड़ें। दिन अभी शुरू नहीं हुआ — आपके पास साफ स्लेट है।',
    'ja':
        '背筋を伸ばして座るか立ちましょう。肩を後ろに引いてください。大きく息を吸って、ゆっくりと吐き出しましょう。まだ一日は始まっていません — 白紙のスタートです。',
    'ko':
        '똑바로 앉거나 서세요. 어깨를 뒤로 당기세요. 깊게 한 번 숨을 쉬고 천천히 내쉬세요. 오늘 하루는 아직 시작되지 않았습니다 — 깨끗한 출발입니다.',
  },
  'meditation.morning_wake.step1': {
    'en':
        'Sit or stand. Shoulders back. Take a full breath and let it go slowly. Today has not yet happened — you have a clean slate.',
    'ru':
        'Сядьте или встаньте. Плечи назад. Сделайте полный вдох и медленно выдохните. Сегодня ещё не наступило — перед вами чистый лист.',
    'de':
        'Sitze oder stehe. Schultern zurück. Nimm einen vollen Atemzug und lass ihn langsam heraus. Der heutige Tag ist noch nicht passiert — du hast einen Neustart.',
    'fr':
        'Assieds-toi ou tiens-toi debout. Épaules en arrière. Prends une grande inspiration et laisse-la partir lentement. Aujourd\'hui n\'est pas encore arrivé — tu as un nouveau départ.',
    'it':
        'Siediti o stai in piedi. Spalle indietro. Fai un respiro completo e lascialo andare lentamente. Oggi non è ancora successo — hai un nuovo inizio.',
    'pt':
        'Sente-se ou fique em pé. Ombros para trás. Faça uma respiração completa e deixe-a sair lentamente. O dia de hoje ainda não aconteceu — você tem um novo começo.',
    'es':
        'Siéntate o ponte de pie. Hombros hacia atrás. Haz una respiración completa y déjala salir lentamente. El día de hoy aún no ha ocurrido — tienes un nuevo comienzo.',
    'id':
        'Duduk atau berdiri. Bahu ke belakang. Ambil napas penuh dan hembuskan perlahan. Hari ini belum terjadi — kamu punya awal yang bersih.',
    'hi':
        'बैठें या खड़े हों। कंधे पीछे। पूरी सांस लें और धीरे छोड़ें। आज अभी हुआ नहीं है — आपके पास नई शुरुआत है।',
    'ja':
        '座るか立ちましょう。肩を後ろに引いてください。大きく息を吸って、ゆっくりと手放しましょう。今日はまだ起きていません — 白紙のスタートです。',
    'ko':
        '앉거나 서세요. 어깨를 뒤로 당기세요. 깊게 숨을 들이쉬고 천천히 내쉬세요. 오늘은 아직 일어나지 않았습니다 — 새로운 시작입니다.',
  },
  'meditation.morning_wake.step2': {
    'en':
        'Roll your shoulders back three times. Stretch your neck side to side. Blink a few times. Your body is waking up.',
    'ru':
        'Трижды прокатите плечи назад. Потяните шею в обе стороны. Несколько раз моргните. Ваше тело просыпается.',
    'de':
        'Rolle deine Schultern dreimal nach hinten. Strecke deinen Nacken zur Seite. Blinzle ein paarmal. Dein Körper erwacht.',
    'fr':
        'Fais tourner tes épaules en arrière trois fois. Étire ton cou de chaque côté. Cligne des yeux quelques fois. Ton corps se réveille.',
    'it':
        'Ruota le spalle indietro tre volte. Stira il collo da un lato all\'altro. Sbatti le ciglia alcune volte. Il tuo corpo si sta svegliando.',
    'pt':
        'Role os ombros para trás três vezes. Estique o pescoço de lado a lado. Pisque algumas vezes. Seu corpo está acordando.',
    'es':
        'Rueda los hombros hacia atrás tres veces. Estira el cuello de lado a lado. Parpadea unas veces. Tu cuerpo se está despertando.',
    'id':
        'Putar bahu ke belakang tiga kali. Regangkan leher ke kanan dan kiri. Kedip beberapa kali. Tubuhmu sedang bangun.',
    'hi':
        'कंधों को तीन बार पीछे घुमाएं। गर्दन को दोनों तरफ खींचें। कुछ बार पलकें झपकाएं। आपका शरीर जाग रहा है।',
    'ja':
        '肩を後ろに三回まわしましょう。首を左右に伸ばしましょう。数回まばたきしてください。体が目覚めてきます。',
    'ko':
        '어깨를 뒤로 세 번 돌리세요. 목을 좌우로 스트레칭하세요. 눈을 몇 번 깜빡이세요. 몸이 깨어나고 있습니다.',
  },
  'meditation.morning_wake.step3': {
    'en':
        'Think of one thing that genuinely matters to you today. Not a task list — one real thing. Hold it in mind.',
    'ru':
        'Подумайте об одном, что действительно важно для вас сегодня. Не список дел — одна настоящая вещь. Держите её в уме.',
    'de':
        'Denke an eine Sache, die dir heute wirklich wichtig ist. Keine Aufgabenliste — eine echte Sache. Behalte sie im Gedächtnis.',
    'fr':
        'Pense à une chose qui compte vraiment pour toi aujourd\'hui. Pas une liste de tâches — une vraie chose. Garde-la à l\'esprit.',
    'it':
        'Pensa a una cosa che conta davvero per te oggi. Non una lista di compiti — una cosa vera. Tienila in mente.',
    'pt':
        'Pense em uma coisa que realmente importa para você hoje. Não uma lista de tarefas — uma coisa real. Mantenha-a em mente.',
    'es':
        'Piensa en una cosa que realmente te importe hoy. No una lista de tareas — una cosa real. Tenla en mente.',
    'id':
        'Pikirkan satu hal yang benar-benar penting bagimu hari ini. Bukan daftar tugas — satu hal nyata. Ingatlah itu.',
    'hi':
        'आज जो चीज सच में आपके लिए मायने रखती है उसके बारे में सोचें। कार्य सूची नहीं — एक असली चीज। उसे मन में रखें।',
    'ja':
        '今日本当に大切だと感じることを一つ思い浮かべましょう。タスクリストではなく — 一つの本当のことを。それを心に留めましょう。',
    'ko':
        '오늘 진정으로 중요한 것 하나를 생각해보세요. 할 일 목록이 아닌 — 진짜 하나의 것. 그것을 마음에 새기세요.',
  },
  'meditation.morning_wake.step4': {
    'en':
        'Picture the end of today: what would make you feel that the day was worth it? Keep it small and real.',
    'ru':
        'Представьте конец сегодняшнего дня: что даст вам ощущение, что день был не зря? Пусть это будет конкретным и реальным.',
    'de':
        'Stelle dir das Ende des heutigen Tages vor: Was würde dir das Gefühl geben, dass der Tag es wert war? Halte es klein und real.',
    'fr':
        'Imagine la fin de la journée : qu\'est-ce qui te ferait sentir que la journée en valait la peine ? Garde ça petit et réel.',
    'it':
        'Immagina la fine di oggi: cosa ti farebbe sentire che la giornata è valsa la pena? Mantienilo piccolo e reale.',
    'pt':
        'Imagine o final de hoje: o que faria você sentir que o dia valeu a pena? Mantenha pequeno e real.',
    'es':
        'Imagina el final de hoy: ¿qué te haría sentir que el día valió la pena? Mantenlo pequeño y real.',
    'id':
        'Bayangkan akhir hari ini: apa yang membuatmu merasa hari ini berharga? Buat sederhana dan nyata.',
    'hi':
        'आज के अंत की कल्पना करें: क्या चीज आपको महसूस कराएगी कि दिन सार्थक रहा? इसे छोटा और असली रखें।',
    'ja':
        '今日の終わりを想像してください：何があれば一日が価値あるものだったと感じますか？小さく、具体的に考えましょう。',
    'ko':
        '오늘 하루의 끝을 상상해보세요: 무엇이 있어야 하루가 의미 있었다고 느낄까요? 작고 현실적으로 생각하세요.',
  },
  'meditation.morning_wake.step5': {
    'en':
        'Take three energizing breaths: short sharp inhale, slow exhale. Open your eyes. You are ready to start.',
    'ru':
        'Сделайте три бодрящих вдоха: короткий резкий вдох, медленный выдох. Откройте глаза. Вы готовы начинать.',
    'de':
        'Nimm drei energiespendende Atemzüge: kurzes scharfes Einatmen, langsames Ausatmen. Öffne die Augen. Du bist bereit zu beginnen.',
    'fr':
        'Prends trois respirations énergisantes : inspire court et vif, expire lentement. Ouvre les yeux. Tu es prêt à commencer.',
    'it':
        'Fai tre respiri energizzanti: breve e decisa inspirazione, lenta espirazione. Apri gli occhi. Sei pronto per iniziare.',
    'pt':
        'Faça três respirações energizantes: inspiração curta e intensa, expiração lenta. Abra os olhos. Você está pronto para começar.',
    'es':
        'Haz tres respiraciones energizantes: inspiración corta y enérgica, exhalación lenta. Abre los ojos. Estás listo para empezar.',
    'id':
        'Ambil tiga napas yang menyegarkan: hirup singkat dan tajam, hembuskan perlahan. Buka matamu. Kamu siap untuk memulai.',
    'hi':
        'तीन ऊर्जादायक सांसें लें: छोटी तेज सांस लें, धीरे छोड़ें। आंखें खोलें। आप शुरू करने के लिए तैयार हैं।',
    'ja':
        'エネルギーを充填する呼吸を三回しましょう：短く鋭く吸い込み、ゆっくり吐きます。目を開けてください。始める準備ができています。',
    'ko':
        '에너지 충전 호흡을 세 번 하세요: 짧고 강하게 들이쉬고, 천천히 내쉬세요. 눈을 뜨세요. 시작할 준비가 되었습니다.',
  },

  // — Gratitude Reset (8 min, 5 steps) —
  'meditation.gratitude_reset.name': {
    'en': 'Gratitude Reset',
    'ru': 'Перезагрузка благодарностью',
    'de': 'Dankbarkeits-Reset',
    'fr': 'Réinitialisation par la gratitude',
    'it': 'Reset con la gratitudine',
    'pt': 'Redefinição pela gratidão',
    'es': 'Reinicio de gratitud',
    'id': 'Setel ulang dengan rasa syukur',
    'hi': 'कृतज्ञता रीसेट',
    'ja': '感謝リセット',
    'ko': '감사 리셋',
  },
  'meditation.gratitude_reset.desc': {
    'en': 'Rediscover what is already working in your life',
    'ru': 'Заново откройте то, что уже работает в вашей жизни',
    'de': 'Entdecke neu, was in deinem Leben bereits funktioniert',
    'fr': 'Redécouvre ce qui fonctionne déjà dans ta vie',
    'it': 'Riscopri ciò che funziona già nella tua vita',
    'pt': 'Redescubra o que já está funcionando na sua vida',
    'es': 'Redescubre lo que ya funciona en tu vida',
    'id': 'Temukan kembali apa yang sudah berjalan baik dalam hidupmu',
    'hi': 'फिर से खोजें कि आपके जीवन में क्या पहले से काम कर रहा है',
    'ja': '自分の生活で既に機能していることを再発見する',
    'ko': '삶에서 이미 잘 되고 있는 것을 다시 발견하기',
  },
  'meditation.gratitude_reset.pose_name': {
    'en': 'Comfortable seat',
    'ru': 'Удобная посадка',
    'de': 'Bequeme Sitzhaltung',
    'fr': 'Assise confortable',
    'it': 'Seduta comoda',
    'pt': 'Assento confortável',
    'es': 'Asiento cómodo',
    'id': 'Duduk nyaman',
    'hi': 'आरामदायक बैठक',
    'ja': 'ゆったりした座位',
    'ko': '편안한 앉은 자세',
  },
  'meditation.gratitude_reset.pose_desc': {
    'en':
        'Sit or lie down in any position that is comfortable — this session is about settling in, not technique. Let your eyes close or soften your gaze.',
    'ru':
        'Сядьте или лягте в любое удобное положение — эта сессия об успокоении, а не о технике. Закройте глаза или мягко опустите взгляд.',
    'de':
        'Sitze oder liege in einer beliebigen bequemen Position — es geht bei dieser Sitzung um das Eingewöhnen, nicht um Technik. Schließe die Augen oder entspanne deinen Blick.',
    'fr':
        'Assieds-toi ou allonge-toi dans n\'importe quelle position confortable — cette séance concerne le fait de t\'installer, pas la technique. Ferme les yeux ou assouplis ton regard.',
    'it':
        'Siediti o sdraiati in qualsiasi posizione comoda — questa sessione riguarda il mettersi a proprio agio, non la tecnica. Chiudi gli occhi o ammorbidisci lo sguardo.',
    'pt':
        'Sente-se ou deite-se em qualquer posição confortável — esta sessão é sobre acomodar-se, não sobre técnica. Feche os olhos ou suavize o olhar.',
    'es':
        'Siéntate o túmbate en cualquier posición cómoda — esta sesión trata de acomodarse, no de técnica. Cierra los ojos o suaviza la mirada.',
    'id':
        'Duduklah atau berbaringlah dalam posisi apa pun yang nyaman — sesi ini tentang merasa nyaman, bukan teknik. Pejamkan mata atau lembutkan pandangan.',
    'hi':
        'किसी भी आरामदायक स्थिति में बैठें या लेटें — यह सत्र सहज होने के बारे में है, तकनीक के बारे में नहीं। आंखें बंद करें या नजर नरम करें।',
    'ja':
        '座るか横になるか、楽な姿勢をとりましょう — このセッションは落ち着くことが目的であり、技術ではありません。目を閉じるか、視線をやさしくします。',
    'ko':
        '편안한 어떤 자세로든 앉거나 누우세요 — 이 세션은 편히 자리 잡는 것에 관한 것이지 기술이 아닙니다. 눈을 감거나 시선을 부드럽게 하세요.',
  },
  'meditation.gratitude_reset.step1': {
    'en':
        'Settle in. There is no task here — just a pause. Let your breathing slow on its own.',
    'ru':
        'Устройтесь поудобнее. Здесь нет задач — только пауза. Позвольте дыханию замедлиться самому.',
    'de':
        'Mache es dir bequem. Hier gibt es keine Aufgabe — nur eine Pause. Lass deinen Atem von selbst langsamer werden.',
    'fr':
        'Installe-toi. Il n\'y a pas de tâche ici — juste une pause. Laisse ta respiration ralentir d\'elle-même.',
    'it':
        'Mettiti comodo. Non c\'è nessun compito qui — solo una pausa. Lascia che il tuo respiro rallenti da solo.',
    'pt':
        'Acomode-se. Não há tarefa aqui — apenas uma pausa. Deixe sua respiração desacelerar por conta própria.',
    'es':
        'Acomódate. No hay tarea aquí — solo una pausa. Deja que tu respiración se ralentice sola.',
    'id':
        'Berikan dirimu ruang. Tidak ada tugas di sini — hanya jeda. Biarkan napasmu melambat dengan sendirinya.',
    'hi':
        'बैठ जाएं। यहां कोई काम नहीं — बस एक विराम। अपनी सांस को खुद-ब-खुद धीमी होने दें।',
    'ja':
        '落ち着きましょう。ここにタスクはありません — ただの休憩です。呼吸が自然にゆっくりになるにまかせましょう。',
    'ko':
        '편히 자리를 잡으세요. 여기에는 할 일이 없습니다 — 그냥 잠깐의 멈춤입니다. 호흡이 스스로 느려지도록 두세요.',
  },
  'meditation.gratitude_reset.step2': {
    'en':
        'Think of three moments from the past week that felt good — however small. A coffee. A message from someone. A task that clicked. Let each one come to mind without rushing.',
    'ru':
        'Вспомните три момента из прошлой недели, когда вам было хорошо — как бы малы они ни были. Чашка кофе. Сообщение от кого-то. Задача, которая щёлкнула. Пусть каждый всплывёт без спешки.',
    'de':
        'Denke an drei Momente der letzten Woche, die sich gut angefühlt haben — so klein sie auch sein mögen. Ein Kaffee. Eine Nachricht von jemandem. Eine Aufgabe, die klickte. Lass jeden einzelnen ohne Eile kommen.',
    'fr':
        'Pense à trois moments de la semaine passée qui t\'ont fait du bien — si petits soient-ils. Un café. Un message de quelqu\'un. Une tâche qui a cliqué. Laisse chacun venir sans te presser.',
    'it':
        'Pensa a tre momenti della settimana scorsa che ti sono sembrati belli — per quanto piccoli. Un caffè. Un messaggio da qualcuno. Un compito che ha funzionato. Lascia che ognuno venga in mente senza fretta.',
    'pt':
        'Pense em três momentos da semana passada que pareceram bons — por menores que sejam. Um café. Uma mensagem de alguém. Uma tarefa que se encaixou. Deixe cada um vir à mente sem pressa.',
    'es':
        'Piensa en tres momentos de la semana pasada que se sintieron bien — por pequeños que sean. Un café. Un mensaje de alguien. Una tarea que encajó. Deja que cada uno venga sin apresurarte.',
    'id':
        'Pikirkan tiga momen dari minggu lalu yang terasa menyenangkan — sekecil apa pun. Secangkir kopi. Pesan dari seseorang. Tugas yang berhasil. Biarkan masing-masing muncul tanpa terburu-buru.',
    'hi':
        'पिछले हफ्ते के तीन ऐसे पल याद करें जो अच्छे लगे — चाहे कितने भी छोटे हों। एक कप चाय। किसी का संदेश। एक काम जो जुड़ा। हर एक को बिना जल्दबाजी के आने दें।',
    'ja':
        '先週の良かった瞬間を三つ思い浮かべましょう — どんなに小さくても。コーヒー一杯。誰かからのメッセージ。うまくいったタスク。それぞれを急がずに心に浮かべましょう。',
    'ko':
        '지난 주에 좋았던 순간 세 가지를 생각해보세요 — 아무리 작아도. 커피 한 잔. 누군가의 메시지. 잘 맞아 떨어진 일. 서두르지 말고 하나하나 떠올리세요.',
  },
  'meditation.gratitude_reset.step3': {
    'en':
        'Think of one person who made something easier for you recently. You don\'t need to tell them. Just feel it.',
    'ru':
        'Вспомните одного человека, который недавно облегчил вам что-то. Не нужно говорить ему об этом. Просто почувствуйте.',
    'de':
        'Denke an eine Person, die dir kürzlich etwas leichter gemacht hat. Du musst es ihr nicht sagen. Spüre es einfach.',
    'fr':
        'Pense à une personne qui t\'a facilité quelque chose récemment. Tu n\'as pas besoin de le lui dire. Sens-le simplement.',
    'it':
        'Pensa a una persona che ti ha facilitato qualcosa di recente. Non hai bisogno di dirglielo. Sentilo e basta.',
    'pt':
        'Pense em uma pessoa que tornou algo mais fácil para você recentemente. Não precisa dizer a ela. Apenas sinta.',
    'es':
        'Piensa en una persona que hizo algo más fácil para ti recientemente. No necesitas decírselo. Simplemente siéntelo.',
    'id':
        'Pikirkan satu orang yang memudahkan sesuatu bagimu belakangan ini. Kamu tidak perlu memberitahu mereka. Cukup rasakan.',
    'hi':
        'उस एक व्यक्ति के बारे में सोचें जिसने हाल ही में आपके लिए कुछ आसान किया। उन्हें बताने की जरूरत नहीं। बस महसूस करें।',
    'ja':
        '最近、何かを楽にしてくれた人を一人思い浮かべてください。その人に伝える必要はありません。ただ感じるだけでいいです。',
    'ko':
        '최근에 무언가를 더 쉽게 만들어준 사람 한 명을 생각해보세요. 그에게 말할 필요는 없습니다. 그냥 느껴보세요.',
  },
  'meditation.gratitude_reset.step4': {
    'en':
        'Notice what is working in your life right now. Not everything — just something. It counts.',
    'ru':
        'Замечайте, что работает в вашей жизни прямо сейчас. Не всё — просто что-то. Это важно.',
    'de':
        'Bemerke, was in deinem Leben gerade funktioniert. Nicht alles — nur etwas. Es zählt.',
    'fr':
        'Remarque ce qui fonctionne dans ta vie en ce moment. Pas tout — juste quelque chose. Ça compte.',
    'it':
        'Nota cosa funziona nella tua vita in questo momento. Non tutto — solo qualcosa. Conta.',
    'pt':
        'Perceba o que está funcionando em sua vida agora. Não tudo — apenas algo. Isso conta.',
    'es':
        'Observa lo que está funcionando en tu vida ahora mismo. No todo — solo algo. Cuenta.',
    'id':
        'Perhatikan apa yang berjalan baik dalam hidupmu saat ini. Tidak semuanya — cukup sesuatu. Itu berarti.',
    'hi':
        'अभी आपके जीवन में क्या काम कर रहा है इस पर ध्यान दें। सब कुछ नहीं — बस कुछ। यह मायने रखता है।',
    'ja':
        '今の自分の生活で機能していることに気づきましょう。全てではなく — 何か一つだけ。それで十分です。',
    'ko':
        '지금 당신의 삶에서 잘 되고 있는 것을 인식하세요. 전부가 아니어도 — 그냥 무언가. 그것으로 충분합니다.',
  },
  'meditation.gratitude_reset.step5': {
    'en':
        'Carry this sense of fullness with you for the rest of the day. Small good things exist alongside the hard ones. Breathe slowly and open your eyes.',
    'ru':
        'Несите это ощущение наполненности с собой до конца дня. Маленькие хорошие вещи существуют рядом с тяжёлыми. Дышите медленно и открывайте глаза.',
    'de':
        'Trage dieses Gefühl der Fülle für den Rest des Tages mit dir. Kleine gute Dinge existieren neben den schweren. Atme langsam und öffne die Augen.',
    'fr':
        'Porte ce sentiment de plénitude avec toi pour le reste de la journée. Les petites bonnes choses coexistent avec les difficiles. Respire lentement et ouvre les yeux.',
    'it':
        'Porta con te questo senso di pienezza per il resto della giornata. Le piccole cose buone esistono accanto a quelle difficili. Respira lentamente e apri gli occhi.',
    'pt':
        'Carregue essa sensação de plenitude pelo resto do dia. Coisas boas pequenas existem ao lado das difíceis. Respire devagar e abra os olhos.',
    'es':
        'Lleva ese sentido de plenitud contigo el resto del día. Las pequeñas cosas buenas existen junto a las difíciles. Respira despacio y abre los ojos.',
    'id':
        'Bawa rasa penuh ini bersamamu sepanjang hari. Hal-hal kecil yang baik ada berdampingan dengan yang berat. Bernapaslah perlahan dan buka matamu.',
    'hi':
        'इस परिपूर्णता की भावना को दिन के बाकी समय के साथ ले जाएं। छोटी अच्छी चीजें कठिन चीजों के साथ भी मौजूद रहती हैं। धीरे सांस लें और आंखें खोलें।',
    'ja':
        'この満ち足りた感覚を一日の残りの時間も持ち続けましょう。小さな良いことは、辛いことと並んで存在しています。ゆっくりと呼吸して目を開けてください。',
    'ko':
        '이 충만함의 감각을 하루의 나머지 시간 동안 가지고 가세요. 작은 좋은 것들은 어려운 것들과 함께 존재합니다. 천천히 숨을 쉬고 눈을 뜨세요.',
  },

  // — Deep Work Entry (4 min, 4 steps) —
  'meditation.deep_work_entry.name': {
    'en': 'Deep Work Entry',
    'ru': 'Вход в глубокую работу',
    'de': 'Einstieg in Tiefarbeit',
    'fr': 'Entrée en travail profond',
    'it': 'Ingresso al lavoro profondo',
    'pt': 'Entrada no trabalho profundo',
    'es': 'Entrada al trabajo profundo',
    'id': 'Masuk kerja mendalam',
    'hi': 'गहरे काम में प्रवेश',
    'ja': 'ディープワーク開始',
    'ko': '심층 작업 진입',
  },
  'meditation.deep_work_entry.desc': {
    'en': 'Prime your mind for a focused, distraction-free work block',
    'ru': 'Настройте разум на сосредоточенный рабочий блок без отвлечений',
    'de': 'Bereite deinen Geist auf einen konzentrierten, ablenkungsfreien Arbeitsblock vor',
    'fr': 'Prépare ton esprit pour un bloc de travail concentré sans distractions',
    'it': 'Prepara la mente per un blocco di lavoro focalizzato senza distrazioni',
    'pt': 'Prepare sua mente para um bloco de trabalho concentrado e sem distrações',
    'es': 'Prepara tu mente para un bloque de trabajo concentrado sin distracciones',
    'id': 'Siapkan pikiranmu untuk sesi kerja fokus tanpa gangguan',
    'hi': 'बिना विकर्षण के एक केंद्रित कार्य-ब्लॉक के लिए दिमाग तैयार करें',
    'ja': '集中した、気の散らない作業ブロックのために心を整える',
    'ko': '집중적이고 산만함 없는 작업 블록을 위해 마음을 준비하기',
  },
  'meditation.deep_work_entry.pose_name': {
    'en': 'Desk-ready seat',
    'ru': 'Рабочая посадка',
    'de': 'Arbeitsbereit',
    'fr': 'Assis prêt au bureau',
    'it': 'Postura pronta alla scrivania',
    'pt': 'Postura de trabalho',
    'es': 'Postura lista para trabajar',
    'id': 'Posisi siap kerja',
    'hi': 'काम के लिए तैयार बैठक',
    'ja': '作業準備完了の座位',
    'ko': '작업 준비 자세',
  },
  'meditation.deep_work_entry.pose_desc': {
    'en':
        'Sit at your desk with your back straight. Put your phone out of reach. Close all unnecessary tabs. Both feet on the floor. You are about to do real work.',
    'ru':
        'Сядьте за рабочий стол, спина прямая. Уберите телефон подальше. Закройте лишние вкладки. Обе стопы на полу. Вы готовитесь к настоящей работе.',
    'de':
        'Sitze an deinem Schreibtisch mit geradem Rücken. Lege dein Telefon außer Reichweite. Schließe alle unnötigen Tabs. Beide Füße auf dem Boden. Du bist dabei, echte Arbeit zu leisten.',
    'fr':
        'Assieds-toi à ton bureau avec le dos droit. Mets ton téléphone hors de portée. Ferme tous les onglets inutiles. Les deux pieds sur le sol. Tu vas faire du vrai travail.',
    'it':
        'Siediti alla scrivania con la schiena dritta. Metti il telefono fuori portata. Chiudi tutte le schede non necessarie. Entrambi i piedi sul pavimento. Stai per fare del vero lavoro.',
    'pt':
        'Sente-se à mesa com as costas eretas. Coloque o telefone fora do alcance. Feche todas as abas desnecessárias. Ambos os pés no chão. Você está prestes a fazer um trabalho real.',
    'es':
        'Siéntate en tu escritorio con la espalda recta. Pon el teléfono fuera de tu alcance. Cierra todas las pestañas innecesarias. Ambos pies en el suelo. Estás a punto de hacer trabajo real.',
    'id':
        'Duduklah di mejamu dengan punggung tegak. Jauhkan ponselmu. Tutup semua tab yang tidak perlu. Kedua kaki di lantai. Kamu akan melakukan pekerjaan nyata.',
    'hi':
        'अपनी मेज पर सीधे बैठें। फोन को पहुंच से दूर रखें। सभी अनावश्यक टैब बंद करें। दोनों पैर जमीन पर। आप असली काम करने वाले हैं।',
    'ja':
        '机に向かって背筋を伸ばして座りましょう。スマートフォンを手の届かない場所に置いてください。不要なタブを全て閉じましょう。両足を床につけます。本当の仕事を始めるときです。',
    'ko':
        '책상 앞에 등을 똑바로 세우고 앉으세요. 휴대폰을 손에 닿지 않는 곳에 두세요. 불필요한 탭을 모두 닫으세요. 양 발을 바닥에. 당신은 진짜 작업을 시작하려 합니다.',
  },
  'meditation.deep_work_entry.step1': {
    'en':
        'You are about to work. Put your phone out of reach. Close anything you don\'t need. Sit with both feet on the floor.',
    'ru':
        'Вы собираетесь работать. Уберите телефон подальше. Закройте всё ненужное. Сядьте, обе ноги на полу.',
    'de':
        'Du bist dabei zu arbeiten. Lege dein Telefon außer Reichweite. Schließe alles, was du nicht brauchst. Sitze mit beiden Füßen auf dem Boden.',
    'fr':
        'Tu vas travailler. Mets ton téléphone hors de portée. Ferme tout ce dont tu n\'as pas besoin. Assieds-toi avec les deux pieds sur le sol.',
    'it':
        'Stai per lavorare. Metti il telefono fuori portata. Chiudi tutto ciò di cui non hai bisogno. Siediti con entrambi i piedi sul pavimento.',
    'pt':
        'Você vai trabalhar. Coloque o telefone fora do alcance. Feche tudo que não precisa. Sente-se com os dois pés no chão.',
    'es':
        'Vas a trabajar. Pon el teléfono fuera de tu alcance. Cierra todo lo que no necesitas. Siéntate con ambos pies en el suelo.',
    'id':
        'Kamu akan bekerja. Jauhkan ponselmu. Tutup semua yang tidak kamu butuhkan. Duduklah dengan kedua kaki di lantai.',
    'hi':
        'आप काम करने वाले हैं। फोन को दूर रखें। जो नहीं चाहिए उसे बंद करें। दोनों पैर जमीन पर रखकर बैठें।',
    'ja':
        'これから仕事をします。スマートフォンを手の届かない場所に置きましょう。不要なものを全て閉じましょう。両足を床につけて座ります。',
    'ko':
        '이제 작업을 시작할 것입니다. 휴대폰을 손에 닿지 않는 곳에 두세요. 필요하지 않은 것들을 닫으세요. 양 발을 바닥에 두고 앉으세요.',
  },
  'meditation.deep_work_entry.step2': {
    'en':
        'Take three slow breaths. With each one, let go of what you were just doing. The past hour is done. What is in front of you now?',
    'ru':
        'Сделайте три медленных вдоха. С каждым отпускайте то, что делали только что. Прошлый час позади. Что перед вами сейчас?',
    'de':
        'Nimm drei langsame Atemzüge. Lass mit jedem das loslassen, was du gerade getan hast. Die vergangene Stunde ist vorbei. Was liegt jetzt vor dir?',
    'fr':
        'Prends trois respirations lentes. À chaque fois, laisse partir ce que tu faisais juste avant. La dernière heure est terminée. Qu\'as-tu devant toi maintenant ?',
    'it':
        'Fai tre respiri lenti. Con ognuno, lascia andare quello che stavi facendo. L\'ultima ora è finita. Cosa hai davanti adesso?',
    'pt':
        'Faça três respirações lentas. Com cada uma, solte o que estava fazendo. A hora passada acabou. O que está à sua frente agora?',
    'es':
        'Toma tres respiraciones lentas. Con cada una, suelta lo que estabas haciendo. La hora pasada terminó. ¿Qué tienes delante ahora?',
    'id':
        'Ambil tiga napas perlahan. Dengan setiap napas, lepaskan apa yang baru saja kamu lakukan. Jam lalu sudah selesai. Apa yang ada di depanmu sekarang?',
    'hi':
        'तीन धीमी सांसें लें। हर एक के साथ, जो अभी कर रहे थे उसे छोड़ दें। पिछला घंटा खत्म हो गया। अभी आपके सामने क्या है?',
    'ja':
        'ゆっくりと三回呼吸しましょう。それぞれで、さっきまでやっていたことを手放します。過去一時間は終わりました。今あなたの前にあるのは何ですか？',
    'ko':
        '천천히 세 번 숨을 쉬세요. 각각의 숨과 함께, 방금 하던 것을 내려놓으세요. 지난 한 시간은 끝났습니다. 지금 당신 앞에는 무엇이 있나요?',
  },
  'meditation.deep_work_entry.step3': {
    'en':
        'Speak to yourself: what is the one thing this session needs to produce? Not a list — one output. Fix it in your mind.',
    'ru':
        'Скажите себе: что должна произвести эта сессия — одна вещь? Не список — один результат. Зафиксируйте его в уме.',
    'de':
        'Sage dir selbst: Was muss diese Sitzung hervorbringen? Kein Plan — eine Ausgabe. Verankere es in deinem Geist.',
    'fr':
        'Dis-toi : quelle est la chose que cette séance doit produire ? Pas une liste — un résultat. Fixe-le dans ton esprit.',
    'it':
        'Dì a te stesso: qual è la cosa che questa sessione deve produrre? Non una lista — un output. Fissalo nella mente.',
    'pt':
        'Diga a si mesmo: qual é a única coisa que esta sessão precisa produzir? Não uma lista — um resultado. Fixe-o em sua mente.',
    'es':
        'Dite a ti mismo: ¿cuál es la única cosa que esta sesión necesita producir? No una lista — un resultado. Fíjalo en tu mente.',
    'id':
        'Katakan pada dirimu: apa satu hal yang perlu dihasilkan sesi ini? Bukan daftar — satu output. Tanamkan dalam pikiranmu.',
    'hi':
        'खुद से कहें: इस सत्र को एक चीज क्या पैदा करनी है? सूची नहीं — एक परिणाम। उसे मन में स्थिर करें।',
    'ja':
        '自分に問いかけましょう：このセッションで生み出すべき一つのことは何ですか？リストではなく — 一つの成果物。それを心に刻みましょう。',
    'ko':
        '스스로에게 말하세요: 이 세션이 만들어야 할 단 하나의 것은 무엇인가요? 목록이 아닌 — 하나의 결과물. 그것을 마음에 새기세요.',
  },
  'meditation.deep_work_entry.step4': {
    'en':
        'Set your timer for your working block. Take one more breath. Begin.',
    'ru':
        'Поставьте таймер на рабочий блок. Сделайте ещё один вдох. Начинайте.',
    'de':
        'Stelle deinen Timer für den Arbeitsblock. Nimm noch einen Atemzug. Beginne.',
    'fr':
        'Règle ta minuterie pour ton bloc de travail. Prends encore une respiration. Commence.',
    'it':
        'Imposta il timer per il tuo blocco di lavoro. Fai un altro respiro. Inizia.',
    'pt':
        'Defina o temporizador para o seu bloco de trabalho. Faça mais uma respiração. Comece.',
    'es':
        'Establece el temporizador para tu bloque de trabajo. Toma un respiro más. Comienza.',
    'id':
        'Atur timer untuk sesi kerjamu. Ambil satu napas lagi. Mulai.',
    'hi':
        'अपने कार्य-ब्लॉक के लिए टाइमर सेट करें। एक और सांस लें। शुरू करें।',
    'ja':
        '作業ブロックのタイマーをセットしましょう。もう一息吸います。始めましょう。',
    'ko':
        '작업 블록을 위한 타이머를 설정하세요. 한 번 더 숨을 들이쉬세요. 시작하세요.',
  },

  // — Evening Unwind (10 min, 6 steps) —
  'meditation.evening_unwind.name': {
    'en': 'Evening Unwind',
    'ru': 'Вечернее расслабление',
    'de': 'Abend-Entspannung',
    'fr': 'Détente du soir',
    'it': 'Distensione serale',
    'pt': 'Relaxamento noturno',
    'es': 'Relajación vespertina',
    'id': 'Relaksasi malam',
    'hi': 'शाम का आराम',
    'ja': '夜のリラックス',
    'ko': '저녁 긴장 풀기',
  },
  'meditation.evening_unwind.desc': {
    'en': 'Let the day go and transition into rest',
    'ru': 'Отпустите день и перейдите к отдыху',
    'de': 'Lass den Tag los und wechsle in die Ruhe',
    'fr': 'Laisse partir la journée et passe au repos',
    'it': 'Lascia andare la giornata e passa al riposo',
    'pt': 'Deixe o dia ir e faça a transição para o descanso',
    'es': 'Deja ir el día y transita hacia el descanso',
    'id': 'Lepaskan hari ini dan beralih ke istirahat',
    'hi': 'दिन को जाने दें और आराम की ओर बढ़ें',
    'ja': '一日を手放し、休息へと移行する',
    'ko': '하루를 보내고 휴식으로 전환하기',
  },
  'meditation.evening_unwind.pose_name': {
    'en': 'Resting pose',
    'ru': 'Поза покоя',
    'de': 'Ruhepose',
    'fr': 'Posture de repos',
    'it': 'Posizione di riposo',
    'pt': 'Postura de descanso',
    'es': 'Postura de descanso',
    'id': 'Posisi istirahat',
    'hi': 'विश्राम मुद्रा',
    'ja': '休息ポーズ',
    'ko': '휴식 자세',
  },
  'meditation.evening_unwind.pose_desc': {
    'en':
        'Lie down on your back or sit back in a chair. Arms relaxed at your sides. Legs uncrossed. Let your body be heavy. The day is done.',
    'ru':
        'Лягте на спину или откиньтесь на спинку стула. Руки расслабленно вдоль тела. Ноги не скрещены. Пусть тело потяжелеет. День закончен.',
    'de':
        'Lege dich auf den Rücken oder lehn dich in einem Stuhl zurück. Arme entspannt an den Seiten. Beine nicht gekreuzt. Lass deinen Körper schwer werden. Der Tag ist vorbei.',
    'fr':
        'Allonge-toi sur le dos ou assieds-toi dans un fauteuil. Bras détendus le long du corps. Jambes non croisées. Laisse ton corps peser lourd. La journée est terminée.',
    'it':
        'Sdraiati sulla schiena o siediti su una sedia. Braccia rilassate ai lati. Gambe non incrociate. Lascia che il corpo diventi pesante. La giornata è finita.',
    'pt':
        'Deite-se de costas ou recline em uma cadeira. Braços relaxados ao lado do corpo. Pernas não cruzadas. Deixe o corpo ficar pesado. O dia acabou.',
    'es':
        'Túmbate boca arriba o recuéstate en una silla. Brazos relajados a los lados. Piernas sin cruzar. Deja que tu cuerpo se sienta pesado. El día ha terminado.',
    'id':
        'Berbaringlah telentang atau bersandar di kursi. Lengan rileks di sisi tubuh. Kaki tidak bersilang. Biarkan tubuhmu menjadi berat. Hari sudah selesai.',
    'hi':
        'पीठ के बल लेटें या कुर्सी में पीछे झुकें। हाथ बगल में ढीले। पैर न मोड़ें। शरीर को भारी होने दें। दिन खत्म हो गया।',
    'ja':
        '仰向けになるか椅子に背もたれてください。腕は体の横にリラックス。脚は組まない。体を重くしましょう。一日が終わりました。',
    'ko':
        '등을 대고 눕거나 의자에 기대세요. 팔은 옆에 편안하게. 다리는 꼬지 않게. 몸이 무거워지도록 두세요. 하루가 끝났습니다.',
  },
  'meditation.evening_unwind.step1': {
    'en':
        'The day is done. You can stop working now. Lie down or sit back and let your body be heavy.',
    'ru':
        'День закончен. Можно остановить работу. Лягте или откиньтесь и позвольте телу потяжелеть.',
    'de':
        'Der Tag ist vorbei. Du kannst jetzt aufhören zu arbeiten. Lege dich hin oder lehne dich zurück und lass deinen Körper schwer werden.',
    'fr':
        'La journée est terminée. Tu peux arrêter de travailler maintenant. Allonge-toi ou assieds-toi en arrière et laisse ton corps peser lourd.',
    'it':
        'La giornata è finita. Puoi smettere di lavorare ora. Sdraiati o siediti e lascia che il tuo corpo diventi pesante.',
    'pt':
        'O dia acabou. Você pode parar de trabalhar agora. Deite-se ou sente-se de volta e deixe seu corpo ficar pesado.',
    'es':
        'El día ha terminado. Puedes dejar de trabajar ahora. Túmbate o siéntate hacia atrás y deja que tu cuerpo se vuelva pesado.',
    'id':
        'Hari sudah selesai. Kamu bisa berhenti bekerja sekarang. Berbaringlah atau bersandar dan biarkan tubuhmu menjadi berat.',
    'hi':
        'दिन खत्म हो गया। आप अब काम बंद कर सकते हैं। लेटें या पीछे झुकें और शरीर को भारी होने दें।',
    'ja':
        '一日が終わりました。もう仕事を止められます。横になるか背もたれて、体を重くしましょう。',
    'ko':
        '하루가 끝났습니다. 이제 일을 멈출 수 있습니다. 눕거나 뒤로 기대어 몸이 무거워지도록 두세요.',
  },
  'meditation.evening_unwind.step2': {
    'en':
        'Scan what happened today without judging it. What went as planned? What didn\'t? Just notice — no analysis needed.',
    'ru':
        'Просмотрите, что случилось сегодня, не оценивая. Что прошло по плану? Что нет? Просто замечайте — анализ не нужен.',
    'de':
        'Scanne, was heute passiert ist, ohne zu urteilen. Was ging wie geplant? Was nicht? Bemerke es einfach — keine Analyse nötig.',
    'fr':
        'Passe en revue ce qui s\'est passé aujourd\'hui sans le juger. Qu\'est-ce qui s\'est passé comme prévu ? Qu\'est-ce qui ne l\'a pas fait ? Remarque juste — pas d\'analyse nécessaire.',
    'it':
        'Esamina cosa è successo oggi senza giudicare. Cos\'è andato come previsto? Cosa no? Nota e basta — nessuna analisi necessaria.',
    'pt':
        'Revise o que aconteceu hoje sem julgamento. O que foi conforme planejado? O que não foi? Apenas observe — sem análise necessária.',
    'es':
        'Revisa lo que pasó hoy sin juzgarlo. ¿Qué salió según lo planeado? ¿Qué no? Solo observa — sin necesidad de análisis.',
    'id':
        'Tinjau apa yang terjadi hari ini tanpa menghakimi. Apa yang berjalan sesuai rencana? Apa yang tidak? Cukup perhatikan — tidak perlu analisis.',
    'hi':
        'आज क्या हुआ, बिना निर्णय लिए देखें। क्या योजना के अनुसार हुआ? क्या नहीं? बस नोटिस करें — विश्लेषण की जरूरत नहीं।',
    'ja':
        '今日何が起きたかを、判断せずに振り返りましょう。計画通りだったことは？そうでなかったことは？ただ気づくだけで、分析は不要です。',
    'ko':
        '오늘 있었던 일을 판단하지 말고 돌아보세요. 계획대로 된 것은? 그렇지 않은 것은? 그냥 인식만 하세요 — 분석은 필요 없습니다.',
  },
  'meditation.evening_unwind.step3': {
    'en':
        'Let go of anything still pulling at your mind. It will be there tomorrow. You don\'t have to solve it tonight.',
    'ru':
        'Отпустите всё, что ещё тянет мысли. Это будет там завтра. Вам не нужно решать это сегодня ночью.',
    'de':
        'Lass alles los, was noch an deinem Geist zieht. Es wird morgen noch da sein. Du musst es heute Nacht nicht lösen.',
    'fr':
        'Laisse partir tout ce qui tire encore ton esprit. Ce sera là demain. Tu n\'as pas à le résoudre ce soir.',
    'it':
        'Lascia andare tutto ciò che ancora attira la tua mente. Sarà lì domani. Non devi risolverlo stanotte.',
    'pt':
        'Solte tudo que ainda está puxando sua mente. Estará lá amanhã. Você não precisa resolver isso esta noite.',
    'es':
        'Suelta todo lo que todavía tira de tu mente. Estará ahí mañana. No tienes que resolverlo esta noche.',
    'id':
        'Lepaskan apa pun yang masih menarik pikiranmu. Itu akan ada besok. Kamu tidak harus menyelesaikannya malam ini.',
    'hi':
        'जो भी अभी भी मन को खींच रहा है उसे जाने दें। यह कल भी वहां रहेगा। आज रात इसे हल नहीं करना है।',
    'ja':
        'まだ心を引っ張っているものを手放しましょう。明日も残っています。今夜解決する必要はありません。',
    'ko':
        '아직도 마음을 당기는 것들을 놓아주세요. 내일도 거기 있을 것입니다. 오늘 밤 그것을 해결할 필요는 없습니다.',
  },
  'meditation.evening_unwind.step4': {
    'en':
        'Bring to mind something small that worked today. One thing. Enough.',
    'ru':
        'Вспомните что-то маленькое, что удалось сегодня. Одно. Достаточно.',
    'de':
        'Ruf dir etwas Kleines ins Gedächtnis, das heute funktioniert hat. Eine Sache. Genug.',
    'fr':
        'Rappelle-toi quelque chose de petit qui a fonctionné aujourd\'hui. Une chose. C\'est suffisant.',
    'it':
        'Porta alla mente qualcosa di piccolo che ha funzionato oggi. Una cosa. Basta.',
    'pt':
        'Lembre-se de algo pequeno que funcionou hoje. Uma coisa. Suficiente.',
    'es':
        'Recuerda algo pequeño que funcionó hoy. Una cosa. Es suficiente.',
    'id':
        'Ingat sesuatu yang kecil yang berhasil hari ini. Satu hal. Cukup.',
    'hi':
        'आज जो एक छोटी सी चीज सही हुई उसे याद करें। बस एक। काफी है।',
    'ja':
        '今日うまくいった小さなことを一つ思い浮かべましょう。一つで十分です。',
    'ko':
        '오늘 잘 된 작은 것 하나를 마음에 떠올리세요. 하나면 충분합니다.',
  },
  'meditation.evening_unwind.step5': {
    'en':
        'Relax your face. Release your jaw, your shoulders, your hands. Breathe slowly and deeply. You are off duty.',
    'ru':
        'Расслабьте лицо. Отпустите челюсть, плечи, руки. Дышите медленно и глубоко. Вы не на смене.',
    'de':
        'Entspanne dein Gesicht. Löse deinen Kiefer, deine Schultern, deine Hände. Atme langsam und tief. Du hast Feierabend.',
    'fr':
        'Détends ton visage. Relâche ta mâchoire, tes épaules, tes mains. Respire lentement et profondément. Tu es en dehors du service.',
    'it':
        'Rilassa il viso. Lascia andare la mascella, le spalle, le mani. Respira lentamente e profondamente. Sei fuori servizio.',
    'pt':
        'Relaxe o rosto. Solte a mandíbula, os ombros, as mãos. Respire devagar e profundamente. Você está fora do serviço.',
    'es':
        'Relaja el rostro. Suelta la mandíbula, los hombros, las manos. Respira despacio y profundo. Estás fuera de servicio.',
    'id':
        'Rilekskan wajahmu. Kendurkan rahang, bahu, dan tanganmu. Bernapaslah perlahan dan dalam. Kamu sudah selesai bertugas.',
    'hi':
        'चेहरा ढीला करें। जबड़ा, कंधे, हाथ छोड़ें। धीरे और गहरी सांस लें। आप ड्यूटी से मुक्त हैं।',
    'ja':
        '顔の力を抜きましょう。顎、肩、手を解放してください。ゆっくりと深く呼吸しましょう。勤務終了です。',
    'ko':
        '얼굴의 긴장을 푸세요. 턱, 어깨, 손을 놓아주세요. 천천히 깊게 숨을 쉬세요. 오늘 근무가 끝났습니다.',
  },
  'meditation.evening_unwind.step6': {
    'en':
        'Stay here as long as you like. There is nowhere to be. Just rest.',
    'ru':
        'Оставайтесь здесь столько, сколько хотите. Вам некуда спешить. Просто отдыхайте.',
    'de':
        'Bleibe hier so lange du möchtest. Es gibt keinen Ort, an dem du sein musst. Ruh dich einfach aus.',
    'fr':
        'Reste ici aussi longtemps que tu veux. Il n\'y a nulle part où être. Repose-toi simplement.',
    'it':
        'Rimani qui quanto vuoi. Non c\'è nessun posto dove essere. Riposati semplicemente.',
    'pt':
        'Fique aqui pelo tempo que quiser. Não há lugar para estar. Apenas descanse.',
    'es':
        'Quédate aquí el tiempo que quieras. No hay ningún lugar donde estar. Simplemente descansa.',
    'id':
        'Tinggal di sini selama kamu mau. Tidak ada tempat yang harus didatangi. Cukup beristirahat.',
    'hi':
        'यहां जितना चाहें रहें। कहीं जाना नहीं है। बस आराम करें।',
    'ja':
        '好きなだけここにいましょう。どこにも行く必要はありません。ただ休んでください。',
    'ko':
        '원하는 만큼 여기에 머무세요. 있어야 할 곳이 없습니다. 그냥 쉬세요.',
  },

  // ---------------------------------------------------------------------------
  // meditation.* pose preview  —  shown BEFORE the player starts.
  // Все языки заполнены в этом блоке.
  // ---------------------------------------------------------------------------

  // Кнопка запуска сессии из экрана-превью позы.
  'meditation.start': {
    'en': 'Start',
    'ru': 'Начать',
    'de': 'Starten',
    'fr': 'Démarrer',
    'it': 'Inizia',
    'pt': 'Iniciar',
    'es': 'Iniciar',
    'id': 'Mulai',
    'hi': 'शुरू करें',
    'ja': '開始',
    'ko': '시작',
  },
  // Подпись-заголовок над позой на экране превью.
  'meditation.pose_heading': {
    'en': 'Take this pose',
    'ru': 'Примите эту позу',
    'de': 'Diese Haltung einnehmen',
    'fr': 'Adopte cette posture',
    'it': 'Assumi questa posizione',
    'pt': 'Adote esta postura',
    'es': 'Adopta esta postura',
    'id': 'Ambil posisi ini',
    'hi': 'यह मुद्रा अपनाएं',
    'ja': 'このポーズをとる',
    'ko': '이 자세를 취하세요',
  },

  // — Аудио-управление в плеере (ADR-054 Phase 1) —
  // Тултип иконки, раскрывающей компактную панель аудио.
  'meditation.audio.controls': {
    'en': 'Sound',
    'ru': 'Звук',
    'de': 'Ton',
    'fr': 'Son',
    'it': 'Audio',
    'pt': 'Som',
    'es': 'Sonido',
    'id': 'Suara',
    'hi': 'ध्वनि',
    'ja': '音声',
    'ko': '소리',
  },
  // Тумблер озвучки шагов (системный TTS).
  'meditation.audio.narration': {
    'en': 'Narration',
    'ru': 'Озвучка',
    'de': 'Erzählung',
    'fr': 'Narration',
    'it': 'Narrazione',
    'pt': 'Narração',
    'es': 'Narración',
    'id': 'Narasi',
    'hi': 'कथन',
    'ja': 'ナレーション',
    'ko': '내레이션',
  },
  // Тумблер фонового эмбиента (коричневый шум).
  'meditation.audio.ambient': {
    'en': 'Ambient sound',
    'ru': 'Фоновый звук',
    'de': 'Hintergrundgeräusch',
    'fr': 'Son ambiant',
    'it': 'Suono ambientale',
    'pt': 'Som ambiente',
    'es': 'Sonido ambiental',
    'id': 'Suara latar',
    'hi': 'परिवेश ध्वनि',
    'ja': '環境音',
    'ko': '배경음',
  },
  // Подпись слайдера громкости эмбиента.
  'meditation.audio.volume': {
    'en': 'Volume',
    'ru': 'Громкость',
    'de': 'Lautstärke',
    'fr': 'Volume',
    'it': 'Volume',
    'pt': 'Volume',
    'es': 'Volumen',
    'id': 'Volume',
    'hi': 'वॉल्यूम',
    'ja': '音量',
    'ko': '볼륨',
  },

  // — Body Scan: лёжа на спине —
  'meditation.body_scan.pose_name': {
    'en': 'Resting pose',
    'ru': 'Поза покоя',
    'de': 'Ruhepose',
    'fr': 'Posture de repos',
    'it': 'Posizione di riposo',
    'pt': 'Postura de descanso',
    'es': 'Postura de descanso',
    'id': 'Posisi istirahat',
    'hi': 'विश्राम मुद्रा',
    'ja': '休息ポーズ',
    'ko': '휴식 자세',
  },
  'meditation.body_scan.pose_desc': {
    'en':
        'Lie comfortably on your back with your legs slightly apart and your arms resting at your sides, palms facing up. Let your eyes close softly and your breath settle into its own gentle rhythm.',
    'ru':
        'Лягте удобно на спину, ноги слегка разведены, руки лежат вдоль тела ладонями вверх. Мягко закройте глаза и позвольте дыханию течь в своём спокойном ритме.',
    'de':
        'Lege dich bequem auf den Rücken, die Beine leicht geöffnet und die Arme locker an den Seiten, Handflächen nach oben. Schließe die Augen sanft und lass deinen Atem in seinen eigenen ruhigen Rhythmus finden.',
    'fr':
        'Allonge-toi confortablement sur le dos, les jambes légèrement écartées et les bras le long du corps, paumes vers le haut. Ferme doucement les yeux et laisse ta respiration trouver son propre rythme.',
    'it':
        'Sdraiati comodamente sulla schiena con le gambe leggermente divaricate e le braccia lungo i fianchi, palmi rivolti verso l\'alto. Chiudi gli occhi delicatamente e lascia che il tuo respiro trovi il suo ritmo.',
    'pt':
        'Deite-se confortavelmente de costas, com as pernas levemente abertas e os braços ao lado do corpo, palmas para cima. Feche os olhos suavemente e deixe a respiração encontrar seu próprio ritmo.',
    'es':
        'Túmbate cómodamente boca arriba, con las piernas ligeramente abiertas y los brazos a los lados, palmas hacia arriba. Cierra los ojos suavemente y deja que tu respiración encuentre su propio ritmo.',
    'id':
        'Berbaringlah dengan nyaman telentang dengan kaki sedikit terbuka dan lengan di sisi tubuh, telapak tangan menghadap ke atas. Pejamkan mata dengan lembut dan biarkan napasmu menemukan ritme yang tenang.',
    'hi':
        'अपनी पीठ के बल आराम से लेटें, पैर थोड़े खुले और हाथ बगल में, हथेलियां ऊपर की ओर। आंखें धीरे से बंद करें और अपनी सांस को शांत गति में बहने दें।',
    'ja':
        '脚を少し開いて仰向けになり、腕を体の横に置いて手のひらを上に向けます。目をゆっくり閉じて、呼吸が自然なリズムを見つけるにまかせましょう。',
    'ko':
        '등을 대고 편안하게 누워 다리를 약간 벌리고 팔은 양옆에 놓되 손바닥이 위를 향하게 하세요. 눈을 부드럽게 감고 호흡이 자연스러운 리듬을 찾도록 두세요.',
  },

  // — Focus Reset: прямая посадка на стуле —
  'meditation.focus_reset.pose_name': {
    'en': 'Upright seat',
    'ru': 'Прямая посадка',
    'de': 'Aufrechte Sitzhaltung',
    'fr': 'Assise droite',
    'it': 'Seduta eretta',
    'pt': 'Postura ereta',
    'es': 'Asiento erguido',
    'id': 'Duduk tegak',
    'hi': 'सीधी बैठक',
    'ja': '背筋を伸ばした座位',
    'ko': '바른 앉은 자세',
  },
  'meditation.focus_reset.pose_desc': {
    'en':
        'Sit tall in your chair with both feet flat on the floor and your hands resting on your thighs. Lengthen your spine, relax your shoulders, and let your gaze soften or your eyes close.',
    'ru':
        'Сядьте ровно на стул, обе стопы плоско на полу, руки лежат на бёдрах. Вытяните позвоночник, расслабьте плечи и мягко опустите взгляд или закройте глаза.',
    'de':
        'Sitze aufrecht auf deinem Stuhl, beide Füße flach auf dem Boden, Hände auf den Oberschenkeln. Strecke die Wirbelsäule, entspanne die Schultern und lass den Blick weich werden oder schließe die Augen.',
    'fr':
        'Assieds-toi bien droit sur ta chaise, les deux pieds à plat sur le sol et les mains sur les cuisses. Allonge ta colonne vertébrale, détends tes épaules et laisse ton regard se détendre ou ferme les yeux.',
    'it':
        'Siediti dritto sulla sedia con entrambi i piedi piatti sul pavimento e le mani sulle cosce. Allunga la colonna vertebrale, rilassa le spalle e lascia che lo sguardo si ammorbidisca o chiudi gli occhi.',
    'pt':
        'Sente-se ereto na cadeira com os dois pés apoiados no chão e as mãos sobre as coxas. Alongue a coluna, relaxe os ombros e deixe o olhar suavizar ou feche os olhos.',
    'es':
        'Siéntate erguido en tu silla con ambos pies apoyados en el suelo y las manos sobre los muslos. Alarga tu columna, relaja los hombros y deja que tu mirada se suavice o cierra los ojos.',
    'id':
        'Duduklah tegak di kursi dengan kedua kaki rata di lantai dan tangan di atas paha. Panjangkan tulang belakang, rilekskan bahu, dan biarkan pandanganmu melunak atau tutup mata.',
    'hi':
        'कुर्सी पर सीधे बैठें, दोनों पैर जमीन पर सपाट और हाथ जांघों पर। रीढ़ को लंबा करें, कंधे ढीले करें और आंखें धीरे से बंद करें।',
    'ja':
        '椅子にまっすぐ座り、両足を床に平らにつけ、手を太ももの上に置きます。背筋を伸ばし、肩の力を抜いて、視線を柔らかくするか目を閉じましょう。',
    'ko':
        '의자에 똑바로 앉아 두 발을 바닥에 평평하게 두고 손은 허벅지 위에 올리세요. 척추를 길게 늘이고 어깨의 긴장을 풀고 시선을 부드럽게 하거나 눈을 감으세요.',
  },

  // — Exam Calm: устойчивая, заземлённая посадка —
  'meditation.exam_calm.pose_name': {
    'en': 'Grounded seat',
    'ru': 'Устойчивая посадка',
    'de': 'Geerdetete Sitzhaltung',
    'fr': 'Assise ancrée',
    'it': 'Seduta radicata',
    'pt': 'Assento firme',
    'es': 'Asiento estable',
    'id': 'Duduk stabil',
    'hi': 'स्थिर बैठक',
    'ja': '安定した座位',
    'ko': '안정된 앉은 자세',
  },
  'meditation.exam_calm.pose_desc': {
    'en':
        'Sit upright with your feet planted firmly on the ground and your hands resting open on your knees. Feel the steady support beneath you and take one slow breath to arrive.',
    'ru':
        'Сядьте прямо, стопы уверенно стоят на полу, раскрытые ладони лежат на коленях. Почувствуйте надёжную опору под собой и сделайте один медленный вдох, чтобы настроиться.',
    'de':
        'Sitze aufrecht mit fest auf dem Boden stehenden Füßen und den offenen Händen auf den Knien. Spüre die stabile Unterstützung unter dir und atme einmal langsam ein, um anzukommen.',
    'fr':
        'Assieds-toi droit, les pieds bien ancrés dans le sol et les mains ouvertes sur les genoux. Ressens le soutien solide sous toi et prends une lente inspiration pour t\'installer.',
    'it':
        'Siediti dritto con i piedi saldamente piantati sul suolo e le mani aperte sulle ginocchia. Senti il supporto stabile sotto di te e fai un respiro lento per arrivare.',
    'pt':
        'Sente-se ereto com os pés firmemente apoiados no chão e as mãos abertas sobre os joelhos. Sinta o apoio estável abaixo de você e faça uma respiração lenta para se instalar.',
    'es':
        'Siéntate erguido con los pies firmemente apoyados en el suelo y las manos abiertas sobre las rodillas. Siente el apoyo estable debajo de ti y toma una respiración lenta para llegar.',
    'id':
        'Duduklah tegak dengan kaki menapak kuat di lantai dan tangan terbuka di atas lutut. Rasakan dukungan yang kokoh di bawahmu dan tarik napas perlahan untuk tiba.',
    'hi':
        'सीधे बैठें, पैर जमीन पर मजबूती से टिके और हथेलियां घुटनों पर खुली रखें। नीचे मजबूत सहारा महसूस करें और एक धीमी सांस लेकर खुद को स्थिर करें।',
    'ja':
        '足をしっかりと床につけ、手を膝の上に開いて置いてまっすぐ座ります。あなたの下にある安定したサポートを感じ、ゆっくりと一呼吸して落ち着きましょう。',
    'ko':
        '두 발을 바닥에 단단히 딛고 손을 무릎 위에 펼쳐 놓으며 똑바로 앉으세요. 아래의 안정된 지지감을 느끼고 천천히 한 번 숨을 들이쉬어 자리를 잡으세요.',
  },

  // — Sleep Prep: лёжа в постели —
  'meditation.sleep_prep.pose_name': {
    'en': 'Lying at rest',
    'ru': 'Поза лёжа',
    'de': 'Liegende Ruheposition',
    'fr': 'Allongé au repos',
    'it': 'Posizione distesa',
    'pt': 'Posição deitada',
    'es': 'Posición tumbada',
    'id': 'Posisi berbaring',
    'hi': 'लेटने की मुद्रा',
    'ja': '横たわった休息姿勢',
    'ko': '누운 휴식 자세',
  },
  'meditation.sleep_prep.pose_desc': {
    'en':
        'Lie down on your back in bed, arms resting gently at your sides and legs relaxed. Close your eyes, let your body sink into the mattress, and breathe slowly.',
    'ru':
        'Лягте на спину в постели, руки мягко лежат вдоль тела, ноги расслаблены. Закройте глаза, позвольте телу погрузиться в матрас и дышите медленно.',
    'de':
        'Lege dich auf den Rücken ins Bett, die Arme sanft an den Seiten und die Beine entspannt. Schließe die Augen, lass deinen Körper in die Matratze sinken und atme langsam.',
    'fr':
        'Allonge-toi sur le dos dans ton lit, les bras posés doucement le long du corps et les jambes détendues. Ferme les yeux, laisse ton corps s\'enfoncer dans le matelas et respire lentement.',
    'it':
        'Sdraiati sulla schiena nel letto, con le braccia adagiate delicatamente ai lati e le gambe rilassate. Chiudi gli occhi, lascia che il tuo corpo affondi nel materasso e respira lentamente.',
    'pt':
        'Deite-se de costas na cama, com os braços repousando suavemente ao lado do corpo e as pernas relaxadas. Feche os olhos, deixe seu corpo afundar no colchão e respire devagar.',
    'es':
        'Túmbate boca arriba en la cama, con los brazos descansando suavemente a los lados y las piernas relajadas. Cierra los ojos, deja que tu cuerpo se hunda en el colchón y respira despacio.',
    'id':
        'Berbaringlah telentang di kasur dengan lengan di sisi tubuh dan kaki yang rileks. Tutup mata, biarkan tubuhmu tenggelam ke dalam kasur, dan bernapaslah perlahan.',
    'hi':
        'बिस्तर पर पीठ के बल लेटें, हाथ धीरे से बगल में और पैर ढीले। आंखें बंद करें, शरीर को गद्दे में समाने दें और धीरे-धीरे सांस लें।',
    'ja':
        'ベッドで仰向けになり、腕を体の横にそっと置いて足をリラックスさせます。目を閉じて、体がマットレスに沈むのを感じながらゆっくりと呼吸しましょう。',
    'ko':
        '침대에 등을 대고 누워 팔을 양옆에 부드럽게 놓고 다리를 편안하게 풀어주세요. 눈을 감고 몸이 매트리스 속으로 가라앉도록 두며 천천히 숨을 쉬세요.',
  },

  // — Stress Relief: удобная поза сидя —
  'meditation.stress_relief.pose_name': {
    'en': 'Easy cross-legged seat',
    'ru': 'Удобная поза сидя',
    'de': 'Bequemer Schneidersitz',
    'fr': 'Assise en tailleur détendue',
    'it': 'Seduta a gambe incrociate',
    'pt': 'Assento com pernas cruzadas',
    'es': 'Postura sentada cómoda',
    'id': 'Duduk bersila nyaman',
    'hi': 'आसान क्रॉस-लेग्ड बैठक',
    'ja': 'ゆったりあぐら座位',
    'ko': '편안한 책상다리 자세',
  },
  'meditation.stress_relief.pose_desc': {
    'en':
        'Sit comfortably cross-legged or on a cushion, with your hands resting on your knees and your back gently upright. Soften your shoulders, unclench your jaw, and let your breath slow down.',
    'ru':
        'Сядьте удобно по-турецки или на подушку, руки лежат на коленях, спина мягко выпрямлена. Расслабьте плечи, разожмите челюсть и позвольте дыханию замедлиться.',
    'de':
        'Sitze bequem im Schneidersitz oder auf einem Kissen, Hände auf den Knien, Rücken sanft aufgerichtet. Entspanne deine Schultern, locker die Kiefer und lass deinen Atem langsamer werden.',
    'fr':
        'Assieds-toi confortablement en tailleur ou sur un coussin, les mains sur les genoux et le dos légèrement droit. Détends tes épaules, desserre ta mâchoire et laisse ta respiration ralentir.',
    'it':
        'Siediti comodamente a gambe incrociate o su un cuscino, con le mani sulle ginocchia e la schiena delicatamente eretta. Ammorbidisci le spalle, rilassa la mascella e lascia che il respiro rallenti.',
    'pt':
        'Sente-se confortavelmente com as pernas cruzadas ou sobre uma almofada, com as mãos sobre os joelhos e as costas levemente eretas. Suavize os ombros, solte a mandíbula e deixe a respiração desacelerar.',
    'es':
        'Siéntate cómodamente con las piernas cruzadas o sobre un cojín, con las manos sobre las rodillas y la espalda suavemente erguida. Suaviza los hombros, relaja la mandíbula y deja que tu respiración se ralentice.',
    'id':
        'Duduklah dengan nyaman bersila atau di atas bantal, dengan tangan di lutut dan punggung tegak dengan lembut. Rilekskan bahu, kendurkan rahang, dan biarkan napasmu melambat.',
    'hi':
        'आराम से क्रॉस-लेग्ड बैठें या गद्दे पर, हाथ घुटनों पर और पीठ हल्की सीधी। कंधे नरम करें, जबड़ा ढीला छोड़ें और सांस को धीमा होने दें।',
    'ja':
        'あぐらまたはクッションの上に楽に座り、手を膝の上に置いて背筋をやさしく伸ばします。肩の力を抜き、顎の緊張をほぐして、呼吸がゆっくりになるにまかせましょう。',
    'ko':
        '책상다리로 편안하게 앉거나 쿠션 위에 앉아 손을 무릎 위에 놓고 등을 살짝 세우세요. 어깨를 부드럽게 하고 턱의 힘을 빼고 호흡이 느려지도록 두세요.',
  },

  // ---------------------------------------------------------------------------
  // screentime.*  —  screen_time_screen.dart
  // ---------------------------------------------------------------------------

  'screentime.title': {
    'en': 'Screen Time',
    'ru': 'Экранное время',
    'de': 'Bildschirmzeit',
    'fr': 'Temps d\'écran',
    'it': 'Tempo schermo',
    'pt': 'Tempo de tela',
    'es': 'Tiempo de pantalla',
    'id': 'Waktu layar',
    'hi': 'स्क्रीन टाइम',
    'ja': 'スクリーンタイム',
    'ko': '화면 시간',
  },
  'screentime.set_daily_limits': {
    'en': 'Set daily limits',
    'ru': 'Установить дневные лимиты',
    'de': 'Tageslimits festlegen',
    'fr': 'Définir des limites quotidiennes',
    'it': 'Imposta limiti giornalieri',
    'pt': 'Definir limites diários',
    'es': 'Establecer límites diarios',
    'id': 'Atur batas harian',
    'hi': 'दैनिक सीमाएं निर्धारित करें',
    'ja': '1日の上限を設定',
    'ko': '일일 한도 설정',
  },
  'screentime.usage_data': {
    'en': 'Usage data',
    'ru': 'Данные об использовании',
    'de': 'Nutzungsdaten',
    'fr': 'Données d\'utilisation',
    'it': 'Dati di utilizzo',
    'pt': 'Dados de uso',
    'es': 'Datos de uso',
    'id': 'Data penggunaan',
    'hi': 'उपयोग डेटा',
    'ja': '利用データ',
    'ko': '사용 데이터',
  },
  'screentime.tips': {
    'en': 'Tips',
    'ru': 'Советы',
    'de': 'Tipps',
    'fr': 'Conseils',
    'it': 'Consigli',
    'pt': 'Dicas',
    'es': 'Consejos',
    'id': 'Tips',
    'hi': 'सुझाव',
    'ja': 'ヒント',
    'ko': '팁',
  },
  'screentime.tip_autoplay': {
    'en': 'Turn off autoplay to avoid unintentional binge-watching.',
    'ru': 'Отключи автовоспроизведение, чтобы не засматриваться случайно.',
    'de': 'Deaktiviere die Autoplay-Funktion, um unbeabsichtigtes Binge-Watching zu vermeiden.',
    'fr': 'Désactive la lecture automatique pour éviter de regarder trop longtemps sans le vouloir.',
    'it': 'Disattiva la riproduzione automatica per evitare binge-watching involontario.',
    'pt': 'Desative a reprodução automática para evitar maratonas involuntárias.',
    'es': 'Desactiva la reproducción automática para evitar el vicio de ver episodios sin querer.',
    'id': 'Matikan putar otomatis agar tidak menonton berlebihan tanpa sadar.',
    'hi': 'अनजाने में ज़्यादा देखने से बचने के लिए ऑटोप्ले बंद करें।',
    'ja': '意図せず見続けるのを防ぐため、自動再生をオフにしましょう。',
    'ko': '의도치 않은 연속 시청을 막으려면 자동 재생을 꺼두세요.',
  },
  'screentime.tip_grayscale': {
    'en': 'Use grayscale mode to make your screen less appealing.',
    'ru': 'Включи чёрно-белый режим — экран станет менее привлекательным.',
    'de': 'Nutze den Graustufen-Modus, damit der Bildschirm weniger anziehend wirkt.',
    'fr': 'Utilise le mode niveaux de gris pour rendre l\'écran moins attrayant.',
    'it': 'Usa la modalità scala di grigi per rendere lo schermo meno attraente.',
    'pt': 'Use o modo escala de cinza para tornar a tela menos atraente.',
    'es': 'Usa el modo escala de grises para que la pantalla sea menos atractiva.',
    'id': 'Gunakan mode grayscale agar layar kurang menarik.',
    'hi': 'स्क्रीन को कम आकर्षक बनाने के लिए ग्रेस्केल मोड का उपयोग करें।',
    'ja': 'グレースケールモードで画面の魅力を下げましょう。',
    'ko': '화면을 덜 매력적으로 만들려면 흑백 모드를 사용하세요.',
  },
  'screentime.tip_phone_away': {
    'en': 'Keep your phone in another room while studying or sleeping.',
    'ru': 'Во время учёбы или сна убирай телефон в другую комнату.',
    'de': 'Lass dein Handy beim Lernen oder Schlafen in einem anderen Raum.',
    'fr': 'Laisse ton téléphone dans une autre pièce quand tu étudies ou dors.',
    'it': 'Tieni il telefono in un\'altra stanza mentre studi o dormi.',
    'pt': 'Deixe o celular em outro cômodo enquanto estuda ou dorme.',
    'es': 'Deja el teléfono en otra habitación mientras estudias o duermes.',
    'id': 'Simpan ponselmu di ruangan lain saat belajar atau tidur.',
    'hi': 'पढ़ाई या सोते समय फोन दूसरे कमरे में रखें।',
    'ja': '勉強中や睡眠中はスマホを別の部屋に置きましょう。',
    'ko': '공부하거나 잘 때는 다른 방에 폰을 두세요.',
  },
  'screentime.no_limit': {
    'en': 'No limit',
    'ru': 'Без лимита',
    'de': 'Kein Limit',
    'fr': 'Sans limite',
    'it': 'Nessun limite',
    'pt': 'Sem limite',
    'es': 'Sin límite',
    'id': 'Tanpa batas',
    'hi': 'कोई सीमा नहीं',
    'ja': '制限なし',
    'ko': '제한 없음',
  },
  'screentime.min_per_day': {
    'en': 'min/day',
    'ru': 'мин/день',
    'de': 'Min/Tag',
    'fr': 'min/jour',
    'it': 'min/giorno',
    'pt': 'min/dia',
    'es': 'min/día',
    'id': 'mnt/hari',
    'hi': 'मिनट/दिन',
    'ja': '分/日',
    'ko': '분/일',
  },
  'screentime.set_daily_time_limit': {
    'en': 'Set a daily time limit',
    'ru': 'Установить дневной лимит',
    'de': 'Tageslimit festlegen',
    'fr': 'Définir une limite quotidienne',
    'it': 'Imposta un limite giornaliero',
    'pt': 'Definir um limite diário',
    'es': 'Establecer un límite diario',
    'id': 'Atur batas waktu harian',
    'hi': 'दैनिक समय सीमा निर्धारित करें',
    'ja': '1日の上限を設定する',
    'ko': '일일 시간 한도 설정',
  },
  'screentime.remove_limit': {
    'en': 'Remove limit',
    'ru': 'Убрать лимит',
    'de': 'Limit entfernen',
    'fr': 'Supprimer la limite',
    'it': 'Rimuovi limite',
    'pt': 'Remover limite',
    'es': 'Eliminar límite',
    'id': 'Hapus batas',
    'hi': 'सीमा हटाएं',
    'ja': '制限を解除',
    'ko': '한도 제거',
  },
  'screentime.grant_access_title': {
    'en': 'Track real usage',
    'ru': 'Отслеживать реальное время',
    'de': 'Echte Nutzung verfolgen',
    'fr': 'Suivre l\'usage réel',
    'it': 'Monitora l\'uso reale',
    'pt': 'Acompanhar uso real',
    'es': 'Seguir el uso real',
    'id': 'Lacak penggunaan nyata',
    'hi': 'वास्तविक उपयोग ट्रैक करें',
    'ja': '実際の利用時間を計測',
    'ko': '실제 사용 시간 추적',
  },
  'screentime.grant_access_body': {
    'en': 'Grant Usage Access so we can show your real time per category and warn you when you go over a limit. We never block apps.',
    'ru': 'Дай доступ к данным об использовании — покажем реальное время по категориям и предупредим при превышении лимита. Приложения мы не блокируем.',
    'de': 'Erteile Nutzungszugriff, damit wir deine echte Zeit pro Kategorie zeigen und dich bei Überschreitung warnen können. Wir blockieren keine Apps.',
    'fr': 'Autorise l\'accès à l\'usage pour voir ton temps réel par catégorie et être averti en cas de dépassement. Nous ne bloquons jamais d\'applis.',
    'it': 'Concedi l\'accesso all\'uso per mostrare il tempo reale per categoria e avvisarti se superi un limite. Non blocchiamo le app.',
    'pt': 'Conceda Acesso ao Uso para mostrarmos seu tempo real por categoria e avisar quando passar do limite. Nunca bloqueamos apps.',
    'es': 'Concede Acceso de Uso para mostrar tu tiempo real por categoría y avisarte cuando superes un límite. Nunca bloqueamos apps.',
    'id': 'Berikan Akses Penggunaan agar kami bisa menampilkan waktu nyata per kategori dan memperingatkan saat melebihi batas. Kami tidak memblokir aplikasi.',
    'hi': 'उपयोग एक्सेस दें ताकि हम श्रेणी के अनुसार आपका वास्तविक समय दिखा सकें और सीमा पार होने पर चेतावनी दे सकें। हम ऐप्स ब्लॉक नहीं करते।',
    'ja': '利用データへのアクセスを許可すると、カテゴリ別の実際の時間を表示し、上限超過時に警告します。アプリはブロックしません。',
    'ko': '사용 데이터 접근을 허용하면 카테고리별 실제 시간을 보여주고 한도 초과 시 알려드립니다. 앱을 차단하지는 않습니다.',
  },
  'screentime.grant_access_btn': {
    'en': 'Grant access',
    'ru': 'Дать доступ',
    'de': 'Zugriff erteilen',
    'fr': 'Autoriser',
    'it': 'Concedi accesso',
    'pt': 'Conceder acesso',
    'es': 'Conceder acceso',
    'id': 'Berikan akses',
    'hi': 'एक्सेस दें',
    'ja': 'アクセスを許可',
    'ko': '접근 허용',
  },
  'screentime.used_today': {
    'en': 'Used today',
    'ru': 'Использовано сегодня',
    'de': 'Heute genutzt',
    'fr': 'Utilisé aujourd\'hui',
    'it': 'Usato oggi',
    'pt': 'Usado hoje',
    'es': 'Usado hoy',
    'id': 'Digunakan hari ini',
    'hi': 'आज उपयोग किया',
    'ja': '今日の利用',
    'ko': '오늘 사용',
  },
  'screentime.over_limit': {
    'en': 'Over by',
    'ru': 'Превышение на',
    'de': 'Über um',
    'fr': 'Dépassé de',
    'it': 'Superato di',
    'pt': 'Excedeu em',
    'es': 'Excedido en',
    'id': 'Lebih',
    'hi': 'अधिक',
    'ja': '超過',
    'ko': '초과',
  },
  'screentime.limit_reached': {
    'en': 'Limit reached',
    'ru': 'Лимит достигнут',
    'de': 'Limit erreicht',
    'fr': 'Limite atteinte',
    'it': 'Limite raggiunto',
    'pt': 'Limite atingido',
    'es': 'Límite alcanzado',
    'id': 'Batas tercapai',
    'hi': 'सीमा पर पहुंच गए',
    'ja': '上限に到達',
    'ko': '한도 도달',
  },
  'screentime.refresh': {
    'en': 'Refresh',
    'ru': 'Обновить',
    'de': 'Aktualisieren',
    'fr': 'Actualiser',
    'it': 'Aggiorna',
    'pt': 'Atualizar',
    'es': 'Actualizar',
    'id': 'Segarkan',
    'hi': 'रिफ्रेश',
    'ja': '更新',
    'ko': '새로고침',
  },
  'screentime.usage_error': {
    'en': 'Could not read usage data. Pull to refresh.',
    'ru': 'Не удалось прочитать данные об использовании. Потяни, чтобы обновить.',
    'de': 'Nutzungsdaten konnten nicht gelesen werden. Zum Aktualisieren ziehen.',
    'fr': 'Impossible de lire les données d\'utilisation. Tire pour actualiser.',
    'it': 'Impossibile leggere i dati di utilizzo. Trascina per aggiornare.',
    'pt': 'Não foi possível ler os dados de uso. Puxe para atualizar.',
    'es': 'No se pudieron leer los datos de uso. Desliza para actualizar.',
    'id': 'Tidak dapat membaca data penggunaan. Tarik untuk menyegarkan.',
    'hi': 'उपयोग डेटा नहीं पढ़ सका। रिफ्रेश करने के लिए खींचें।',
    'ja': '利用データを読み取れませんでした。引っ張って更新してください。',
    'ko': '사용 데이터를 읽을 수 없습니다. 당겨서 새로고침하세요.',
  },
  'screentime.no_usage_yet': {
    'en': 'No tracked usage in these categories today.',
    'ru': 'Сегодня в этих категориях использования не зафиксировано.',
    'de': 'Heute keine erfasste Nutzung in diesen Kategorien.',
    'fr': 'Aucun usage suivi dans ces catégories aujourd\'hui.',
    'it': 'Nessun utilizzo registrato in queste categorie oggi.',
    'pt': 'Nenhum uso registrado nessas categorias hoje.',
    'es': 'No hay uso registrado en estas categorías hoy.',
    'id': 'Belum ada penggunaan tercatat di kategori ini hari ini.',
    'hi': 'आज इन श्रेणियों में कोई उपयोग दर्ज नहीं हुआ।',
    'ja': '今日これらのカテゴリの利用は記録されていません。',
    'ko': '오늘 이 카테고리에서 기록된 사용이 없습니다.',
  },

  // Категория «Other» — приложения, не попавшие в основные категории.
  'screentime.category_other': {
    'en': 'Other',
    'ru': 'Другое',
    'de': 'Sonstige',
    'fr': 'Autres',
    'it': 'Altro',
    'pt': 'Outros',
    'es': 'Otros',
    'id': 'Lainnya',
    'hi': 'अन्य',
    'ja': 'その他',
    'ko': '기타',
  },

  // Строка «Total today» — суммарное экранное время за день.
  'screentime.total_today': {
    'en': 'Total today',
    'ru': 'Всего сегодня',
    'de': 'Heute gesamt',
    'fr': 'Total aujourd\'hui',
    'it': 'Totale oggi',
    'pt': 'Total hoje',
    'es': 'Total hoy',
    'id': 'Total hari ini',
    'hi': 'आज कुल',
    'ja': '今日の合計',
    'ko': '오늘 합계',
  },

  // ---------------------------------------------------------------------------
  // screentime_advice_*  —  screen_time_advice.dart (бесплатные «зашитые» фразы)
  //   <category>_<ok|much|too_much>_<gentle|harsh>. 5×3×2 = 30 ключей.
  //   Заданы en + ru; прочие локали падают на en (резолвер S делает fallback).
  //   Первый черновик — пользователь будет править формулировки.
  // ---------------------------------------------------------------------------

  // --- social ---------------------------------------------------------------
  'screentime_advice_social_ok_gentle': {
    'en': 'Nice balance with social today.',
    'ru': 'Хороший баланс с соцсетями сегодня.',
  },
  'screentime_advice_social_ok_harsh': {
    'en': 'Social is in check. Keep it there.',
    'ru': 'Соцсети под контролем. Так и держи.',
  },
  'screentime_advice_social_much_gentle': {
    'en': 'Social is adding up — maybe a short break?',
    'ru': 'Соцсети накапливаются — может, сделаешь паузу?',
  },
  'screentime_advice_social_much_harsh': {
    'en': 'Social is climbing fast. Put it down.',
    'ru': 'Соцсети растут слишком быстро. Отложи телефон.',
  },
  'screentime_advice_social_too_much_gentle': {
    'en': 'Lots of social today — time to step away.',
    'ru': 'Сегодня много соцсетей — пора отвлечься.',
  },
  'screentime_advice_social_too_much_harsh': {
    'en': 'Way too much social. Close the app now.',
    'ru': 'Соцсетей слишком много. Закрой приложение.',
  },

  // --- video ----------------------------------------------------------------
  'screentime_advice_video_ok_gentle': {
    'en': 'Your video time looks healthy today.',
    'ru': 'Время на видео сегодня в норме.',
  },
  'screentime_advice_video_ok_harsh': {
    'en': 'Video is fine so far. Stay sharp.',
    'ru': 'Видео пока в порядке. Не расслабляйся.',
  },
  'screentime_advice_video_much_gentle': {
    'en': 'Quite a bit of video — a pause could help.',
    'ru': 'Видео уже немало — пауза не помешает.',
  },
  'screentime_advice_video_much_harsh': {
    'en': 'Video is piling up. Stop the next one.',
    'ru': 'Видео копится. Не запускай следующее.',
  },
  'screentime_advice_video_too_much_gentle': {
    'en': 'That\'s a lot of video — give your eyes a rest.',
    'ru': 'Это много видео — дай глазам отдохнуть.',
  },
  'screentime_advice_video_too_much_harsh': {
    'en': 'Too much video. Turn it off.',
    'ru': 'Видео слишком много. Выключай.',
  },

  // --- games ----------------------------------------------------------------
  'screentime_advice_games_ok_gentle': {
    'en': 'Gaming time is nicely balanced today.',
    'ru': 'Время на игры сегодня в балансе.',
  },
  'screentime_advice_games_ok_harsh': {
    'en': 'Games under control. Keep it tight.',
    'ru': 'Игры под контролем. Не теряй хватку.',
  },
  'screentime_advice_games_much_gentle': {
    'en': 'Games are adding up — maybe wrap up soon.',
    'ru': 'Игры накапливаются — пора заканчивать.',
  },
  'screentime_advice_games_much_harsh': {
    'en': 'Games are eating your time. Finish the match.',
    'ru': 'Игры съедают время. Доигрывай и хватит.',
  },
  'screentime_advice_games_too_much_gentle': {
    'en': 'Long gaming session — time for a break.',
    'ru': 'Долгая игровая сессия — пора передохнуть.',
  },
  'screentime_advice_games_too_much_harsh': {
    'en': 'Too much gaming. Quit and move on.',
    'ru': 'Игр слишком много. Выходи и займись делом.',
  },

  // --- browsing -------------------------------------------------------------
  'screentime_advice_browsing_ok_gentle': {
    'en': 'Browsing time looks fine today.',
    'ru': 'Время в браузере сегодня в норме.',
  },
  'screentime_advice_browsing_ok_harsh': {
    'en': 'Browsing is in check. Don\'t drift.',
    'ru': 'Браузер под контролем. Не залипай.',
  },
  'screentime_advice_browsing_much_gentle': {
    'en': 'A fair bit of browsing — maybe refocus?',
    'ru': 'Браузера уже немало — может, вернёшься к делу?',
  },
  'screentime_advice_browsing_much_harsh': {
    'en': 'Browsing is creeping up. Close the tabs.',
    'ru': 'Браузер растёт. Закрывай вкладки.',
  },
  'screentime_advice_browsing_too_much_gentle': {
    'en': 'Lots of browsing today — time to log off.',
    'ru': 'Сегодня много браузера — пора закрывать.',
  },
  'screentime_advice_browsing_too_much_harsh': {
    'en': 'Too much aimless browsing. Stop scrolling.',
    'ru': 'Бесцельного браузинга слишком много. Хватит листать.',
  },

  // --- messaging ------------------------------------------------------------
  'screentime_advice_messaging_ok_gentle': {
    'en': 'Messaging time is well balanced today.',
    'ru': 'Время в мессенджерах сегодня в балансе.',
  },
  'screentime_advice_messaging_ok_harsh': {
    'en': 'Messaging is fine. Keep replies quick.',
    'ru': 'Мессенджеры в порядке. Отвечай коротко.',
  },
  'screentime_advice_messaging_much_gentle': {
    'en': 'Messaging is adding up — pause the chats?',
    'ru': 'Мессенджеры накапливаются — может, пауза в чатах?',
  },
  'screentime_advice_messaging_much_harsh': {
    'en': 'Chats are taking over. Mute them a while.',
    'ru': 'Чаты захватывают время. Поставь на паузу.',
  },
  'screentime_advice_messaging_too_much_gentle': {
    'en': 'A lot of messaging today — take a breather.',
    'ru': 'Сегодня много переписок — выдохни.',
  },
  'screentime_advice_messaging_too_much_harsh': {
    'en': 'Too much time in chats. Put the phone down.',
    'ru': 'В чатах слишком много времени. Отложи телефон.',
  },

  // ---------------------------------------------------------------------------
  // sleep.*  —  sleep_report_screen.dart
  // ---------------------------------------------------------------------------

  'sleep.report_title': {
    'en': 'Sleep Report',
    'ru': 'Отчёт о сне',
    'de': 'Schlafbericht',
    'fr': 'Rapport de sommeil',
    'it': 'Report sonno',
    'pt': 'Relatório de sono',
    'es': 'Informe de sueño',
    'id': 'Laporan tidur',
    'hi': 'नींद रिपोर्ट',
    'ja': '睡眠レポート',
    'ko': '수면 리포트',
  },
  'sleep.select_date': {
    'en': 'Select date',
    'ru': 'Выбрать дату',
    'de': 'Datum wählen',
    'fr': 'Sélectionner une date',
    'it': 'Seleziona data',
    'pt': 'Selecionar data',
    'es': 'Seleccionar fecha',
    'id': 'Pilih tanggal',
    'hi': 'तारीख चुनें',
    'ja': '日付を選択',
    'ko': '날짜 선택',
  },
  'sleep.history': {
    'en': 'Sleep History',
    'ru': 'История сна',
    'de': 'Schlafverlauf',
    'fr': 'Historique de sommeil',
    'it': 'Cronologia sonno',
    'pt': 'Histórico de sono',
    'es': 'Historial de sueño',
    'id': 'Riwayat tidur',
    'hi': 'नींद का इतिहास',
    'ja': '睡眠履歴',
    'ko': '수면 기록',
  },
  'sleep.no_data': {
    'en': 'No sleep data for this date',
    'ru': 'Нет данных о сне за этот день',
    'de': 'Keine Schlafdaten für dieses Datum',
    'fr': 'Aucune donnée de sommeil pour cette date',
    'it': 'Nessun dato sonno per questa data',
    'pt': 'Sem dados de sono para esta data',
    'es': 'Sin datos de sueño para esta fecha',
    'id': 'Tidak ada data tidur untuk tanggal ini',
    'hi': 'इस तारीख के लिए कोई नींद डेटा नहीं',
    'ja': 'この日の睡眠データなし',
    'ko': '이 날짜의 수면 데이터 없음',
  },
  'sleep.avg': {
    'en': 'Avg Sleep',
    'ru': 'Среднее',
    'de': 'Durchschn.',
    'fr': 'Moy. sommeil',
    'it': 'Media sonno',
    'pt': 'Média sono',
    'es': 'Prom. sueño',
    'id': 'Rata-rata tidur',
    'hi': 'औसत नींद',
    'ja': '平均睡眠',
    'ko': '평균 수면',
  },
  'sleep.best_night': {
    'en': 'Best Night',
    'ru': 'Лучшая ночь',
    'de': 'Beste Nacht',
    'fr': 'Meilleure nuit',
    'it': 'Notte migliore',
    'pt': 'Melhor noite',
    'es': 'Mejor noche',
    'id': 'Malam terbaik',
    'hi': 'सबसे अच्छी रात',
    'ja': 'ベストの夜',
    'ko': '최고의 밤',
  },
  'sleep.total_nights': {
    'en': 'Total Nights',
    'ru': 'Всего ночей',
    'de': 'Nächte gesamt',
    'fr': 'Nuits totales',
    'it': 'Notti totali',
    'pt': 'Total de noites',
    'es': 'Noches totales',
    'id': 'Total malam',
    'hi': 'कुल रातें',
    'ja': '合計夜数',
    'ko': '총 수면일',
  },
  'sleep.in_progress': {
    'en': 'In progress',
    'ru': 'Идёт сейчас',
    'de': 'Läuft gerade',
    'fr': 'En cours',
    'it': 'In corso',
    'pt': 'Em andamento',
    'es': 'En curso',
    'id': 'Sedang berlangsung',
    'hi': 'जारी है',
    'ja': '進行中',
    'ko': '진행 중',
  },
  'sleep.today': {
    'en': 'Today',
    'ru': 'Сегодня',
    'de': 'Heute',
    'fr': 'Aujourd\'hui',
    'it': 'Oggi',
    'pt': 'Hoje',
    'es': 'Hoy',
    'id': 'Hari ini',
    'hi': 'आज',
    'ja': '今日',
    'ko': '오늘',
  },
  'sleep.yesterday': {
    'en': 'Yesterday',
    'ru': 'Вчера',
    'de': 'Gestern',
    'fr': 'Hier',
    'it': 'Ieri',
    'pt': 'Ontem',
    'es': 'Ayer',
    'id': 'Kemarin',
    'hi': 'कल',
    'ja': '昨日',
    'ko': '어제',
  },
  // Краткое обозначение «часов» после числового значения (6.5h / 6.5ч)
  'sleep.h_unit': {
    'en': 'h',
    'ru': 'ч',
    'de': 'h',
    'fr': 'h',
    'it': 'h',
    'pt': 'h',
    'es': 'h',
    'id': 'j',
    'hi': 'घ',
    'ja': '時間',
    'ko': '시간',
  },
  // Кнопка пустого состояния — перейти к записи сна
  'sleep.log_sleep': {
    'en': 'Log sleep',
    'ru': 'Записать сон',
    'de': 'Schlaf erfassen',
    'fr': 'Enregistrer le sommeil',
    'it': 'Registra sonno',
    'pt': 'Registrar sono',
    'es': 'Registrar sueño',
    'id': 'Catat tidur',
    'hi': 'नींद दर्ज करें',
    'ja': '睡眠を記録',
    'ko': '수면 기록하기',
  },
  // Подзаголовок пустого состояния в sleep report
  'sleep.empty_hint': {
    'en': 'Track your nights to see patterns',
    'ru': 'Фиксируй ночи — и увидишь закономерности',
    'de': 'Erfasse deine Nächte, um Muster zu sehen',
    'fr': 'Suivez vos nuits pour repérer des tendances',
    'it': 'Monitora le tue notti per trovare pattern',
    'pt': 'Acompanhe suas noites para ver padrões',
    'es': 'Registra tus noches para ver patrones',
    'id': 'Catat malammu untuk melihat pola',
    'hi': 'अपनी रातें ट्रैक करें और पैटर्न देखें',
    'ja': '夜を記録してパターンを確認しよう',
    'ko': '밤을 기록하면 패턴이 보여요',
  },

  // ---------------------------------------------------------------------------
  // water.*  —  water_fullscreen_screen.dart, water_report_screen.dart
  // ---------------------------------------------------------------------------

  'water.title': {
    'en': 'Water',
    'ru': 'Вода',
    'de': 'Wasser',
    'fr': 'Eau',
    'it': 'Acqua',
    'pt': 'Água',
    'es': 'Agua',
    'id': 'Air',
    'hi': 'पानी',
    'ja': '水分',
    'ko': '수분',
  },
  'water.history_tooltip': {
    'en': 'History',
    'ru': 'История',
    'de': 'Verlauf',
    'fr': 'Historique',
    'it': 'Cronologia',
    'pt': 'Histórico',
    'es': 'Historial',
    'id': 'Riwayat',
    'hi': 'इतिहास',
    'ja': '履歴',
    'ko': '기록',
  },
  'water.undo_last': {
    'en': 'Undo last',
    'ru': 'Отменить последнее',
    'de': 'Letzte rückgängig',
    'fr': 'Annuler le dernier',
    'it': 'Annulla ultimo',
    'pt': 'Desfazer último',
    'es': 'Deshacer último',
    'id': 'Batalkan terakhir',
    'hi': 'अंतिम पूर्ववत करें',
    'ja': '最後の操作を元に戻す',
    'ko': '마지막 실행 취소',
  },
  'water.food_tip': {
    'en': 'Coffee & tea from Food count toward your goal',
    'ru': 'Кофе и чай из раздела «Питание» тоже идут в счёт',
    'de': 'Kaffee & Tee aus der Ernährung zählen zu deinem Ziel',
    'fr': 'Le café et le thé de la section Alimentation comptent dans ton objectif',
    'it': 'Caffè e tè dalla sezione Alimentazione contano verso il tuo obiettivo',
    'pt': 'Café e chá da seção Alimentação contam para sua meta',
    'es': 'El café y el té de la sección Alimentación cuentan para tu objetivo',
    'id': 'Kopi & teh dari bagian Makanan dihitung ke tujuanmu',
    'hi': 'फूड सेक्शन की कॉफी और चाय भी आपके लक्ष्य में गिनी जाती है',
    'ja': 'フードセクションのコーヒー・紅茶も目標にカウントされます',
    'ko': '음식 섹션의 커피와 차도 목표에 포함됩니다',
  },
  'water.drink_reminders': {
    'en': 'Drink reminders',
    'ru': 'Напоминания пить воду',
    'de': 'Trinkerinnerungen',
    'fr': 'Rappels de boisson',
    'it': 'Promemoria idratazione',
    'pt': 'Lembretes de hidratação',
    'es': 'Recordatorios de hidratación',
    'id': 'Pengingat minum',
    'hi': 'पीने के रिमाइंडर',
    'ja': '水分補給リマインダー',
    'ko': '음수 알림',
  },
  'water.reminders_subtitle': {
    'en': 'Every 2 hours, 9:00–21:00',
    'ru': 'Каждые 2 часа, 9:00–21:00',
    'de': 'Alle 2 Stunden, 9:00–21:00',
    'fr': 'Toutes les 2 heures, 9:00–21:00',
    'it': 'Ogni 2 ore, 9:00–21:00',
    'pt': 'A cada 2 horas, 9:00–21:00',
    'es': 'Cada 2 horas, 9:00–21:00',
    'id': 'Setiap 2 jam, 9:00–21:00',
    'hi': 'हर 2 घंटे, 9:00–21:00',
    'ja': '2時間ごと、9:00–21:00',
    'ko': '2시간마다, 9:00–21:00',
  },
  // Water report
  'water.report_title': {
    'en': 'Water Report',
    'ru': 'Отчёт о воде',
    'de': 'Wasserbericht',
    'fr': 'Rapport hydratation',
    'it': 'Report idratazione',
    'pt': 'Relatório de água',
    'es': 'Informe de agua',
    'id': 'Laporan air',
    'hi': 'पानी रिपोर्ट',
    'ja': '水分レポート',
    'ko': '수분 리포트',
  },
  'water.logs_section': {
    'en': 'Water Logs',
    'ru': 'Записи',
    'de': 'Einträge',
    'fr': 'Journaux d\'eau',
    'it': 'Registrazioni acqua',
    'pt': 'Registros de água',
    'es': 'Registros de agua',
    'id': 'Log air',
    'hi': 'पानी लॉग',
    'ja': '水分ログ',
    'ko': '수분 기록',
  },
  'water.no_logs': {
    'en': 'No water logs for this day',
    'ru': 'Нет записей за этот день',
    'de': 'Keine Wassereinträge für diesen Tag',
    'fr': 'Aucun journal d\'eau pour ce jour',
    'it': 'Nessuna registrazione acqua per questo giorno',
    'pt': 'Sem registros de água para este dia',
    'es': 'Sin registros de agua para este día',
    'id': 'Tidak ada log air untuk hari ini',
    'hi': 'इस दिन के लिए कोई पानी लॉग नहीं',
    'ja': 'この日の水分ログなし',
    'ko': '이 날의 수분 기록 없음',
  },
  'water.stat_total': {
    'en': 'Total',
    'ru': 'Всего',
    'de': 'Gesamt',
    'fr': 'Total',
    'it': 'Totale',
    'pt': 'Total',
    'es': 'Total',
    'id': 'Total',
    'hi': 'कुल',
    'ja': '合計',
    'ko': '합계',
  },
  'water.stat_goal': {
    'en': 'Goal',
    'ru': 'Цель',
    'de': 'Ziel',
    'fr': 'Objectif',
    'it': 'Obiettivo',
    'pt': 'Meta',
    'es': 'Meta',
    'id': 'Target',
    'hi': 'लक्ष्य',
    'ja': '目標',
    'ko': '목표',
  },
  'water.stat_status': {
    'en': 'Status',
    'ru': 'Статус',
    'de': 'Status',
    'fr': 'Statut',
    'it': 'Stato',
    'pt': 'Status',
    'es': 'Estado',
    'id': 'Status',
    'hi': 'स्थिति',
    'ja': 'ステータス',
    'ko': '상태',
  },
  'water.goal_met': {
    'en': 'Goal Met!',
    'ru': 'Цель!',
    'de': 'Ziel erreicht!',
    'fr': 'Objectif atteint !',
    'it': 'Obiettivo raggiunto!',
    'pt': 'Meta atingida!',
    'es': '¡Meta cumplida!',
    'id': 'Target tercapai!',
    'hi': 'लक्ष्य पूरा हुआ!',
    'ja': '目標達成！',
    'ko': '목표 달성!',
  },

  // Формат кнопки быстрого добавления объёма — «+{ml} мл».
  // {ml} заменяется на значение в коде.
  'water.add_ml_fmt': {
    'en': '+{ml} ml',
    'ru': '+{ml} мл',
    'de': '+{ml} ml',
    'fr': '+{ml} ml',
    'it': '+{ml} ml',
    'pt': '+{ml} ml',
    'es': '+{ml} ml',
    'id': '+{ml} ml',
    'hi': '+{ml} मिली',
    'ja': '+{ml} ml',
    'ko': '+{ml} ml',
  },
  // Кнопка «Своё количество» — открывает диалог ввода произвольного объёма.
  'water.custom_btn': {
    'en': 'Custom',
    'ru': 'Своё',
    'de': 'Eigene',
    'fr': 'Autre',
    'it': 'Altro',
    'pt': 'Outro',
    'es': 'Otro',
    'id': 'Lainnya',
    'hi': 'कस्टम',
    'ja': 'カスタム',
    'ko': '직접 입력',
  },
  // Заголовок диалога «Своё количество».
  'water.custom_amount_title': {
    'en': 'Custom amount',
    'ru': 'Своё количество',
    'de': 'Eigene Menge',
    'fr': 'Quantité personnalisée',
    'it': 'Quantità personalizzata',
    'pt': 'Quantidade personalizada',
    'es': 'Cantidad personalizada',
    'id': 'Jumlah kustom',
    'hi': 'कस्टम मात्रा',
    'ja': 'カスタム量',
    'ko': '직접 입력',
  },
  // Подсказка поля ввода в диалоге «Своё количество».
  'water.custom_amount_hint': {
    'en': 'Amount in ml',
    'ru': 'Количество в мл',
    'de': 'Menge in ml',
    'fr': 'Quantité en ml',
    'it': 'Quantità in ml',
    'pt': 'Quantidade em ml',
    'es': 'Cantidad en ml',
    'id': 'Jumlah dalam ml',
    'hi': 'मात्रा मिलीलीटर में',
    'ja': 'ml単位の量',
    'ko': 'ml 단위로 입력',
  },

  // Прогресс воды «N из M мл» — подпись под hero-% на полном экране воды.
  // {total} и {goal} — числа, подставляются кодом; единицы — часть перевода.
  'water.progress_fmt': {
    'en': '{total} of {goal} ml',
    'ru': '{total} из {goal} мл',
    'de': '{total} von {goal} ml',
    'fr': '{total} sur {goal} ml',
    'it': '{total} di {goal} ml',
    'pt': '{total} de {goal} ml',
    'es': '{total} de {goal} ml',
    'id': '{total} / {goal} ml',
    'hi': '{total} / {goal} मिली',
    'ja': '{total} / {goal} ml',
    'ko': '{total} / {goal} ml',
  },

  // Объём в мл без знака «+» — для отображения записей в отчёте воды.
  // {ml} заменяется числом кодом; единица — часть перевода.
  'water.amt_ml_fmt': {
    'en': '{ml} ml',
    'ru': '{ml} мл',
    'de': '{ml} ml',
    'fr': '{ml} ml',
    'it': '{ml} ml',
    'pt': '{ml} ml',
    'es': '{ml} ml',
    'id': '{ml} ml',
    'hi': '{ml} मिली',
    'ja': '{ml} ml',
    'ko': '{ml} ml',
  },

  // Кнопка для пустого состояния отчёта (нет записей за выбранный день).
  'water.log_water_btn': {
    'en': 'Log water',
    'ru': 'Записать воду',
    'de': 'Wasser erfassen',
    'fr': 'Consigner l\'eau',
    'it': 'Registra acqua',
    'pt': 'Registrar água',
    'es': 'Registrar agua',
    'id': 'Catat air',
    'hi': 'पानी लॉग करें',
    'ja': '水分を記録',
    'ko': '물 기록',
  },

  // ---------------------------------------------------------------------------
  // workout.ai_* (Feature A) — анкета + лист «AI / шаблонная программа»
  // (ai_workout_sheet.dart). EN/RU; остальные языки откатываются на EN.
  // ---------------------------------------------------------------------------

  'workout.ai_program': {
    'en': 'AI program',
    'ru': 'AI-программа',
  },
  'workout.ai_title': {
    'en': 'Build a program',
    'ru': 'Собрать программу',
  },
  'workout.ai_goal': {
    'en': 'Goal',
    'ru': 'Цель',
  },
  'workout.ai_goal_strength': {
    'en': 'Strength',
    'ru': 'Сила',
  },
  'workout.ai_goal_muscle': {
    'en': 'Muscle',
    'ru': 'Мышцы',
  },
  'workout.ai_goal_fat_loss': {
    'en': 'Fat loss',
    'ru': 'Жиросжигание',
  },
  'workout.ai_goal_endurance': {
    'en': 'Endurance',
    'ru': 'Выносливость',
  },
  'workout.ai_goal_general': {
    'en': 'General',
    'ru': 'Общая форма',
  },
  'workout.ai_experience': {
    'en': 'Experience',
    'ru': 'Опыт',
  },
  'workout.ai_exp_beginner': {
    'en': 'Beginner',
    'ru': 'Новичок',
  },
  'workout.ai_exp_intermediate': {
    'en': 'Intermediate',
    'ru': 'Средний',
  },
  'workout.ai_exp_advanced': {
    'en': 'Advanced',
    'ru': 'Продвинутый',
  },
  'workout.ai_equipment': {
    'en': 'Equipment',
    'ru': 'Инвентарь',
  },
  'workout.ai_eq_barbell': {
    'en': 'Barbell',
    'ru': 'Штанга',
  },
  'workout.ai_eq_dumbbells': {
    'en': 'Dumbbells',
    'ru': 'Гантели',
  },
  'workout.ai_eq_pullup_bar': {
    'en': 'Pull-up bar',
    'ru': 'Турник',
  },
  'workout.ai_eq_bodyweight': {
    'en': 'Bodyweight',
    'ru': 'Свой вес',
  },
  'workout.ai_eq_full_gym': {
    'en': 'Full gym',
    'ru': 'Зал',
  },
  'workout.ai_days': {
    'en': 'Days per week',
    'ru': 'Дней в неделю',
  },
  'workout.ai_minutes': {
    'en': 'Minutes per session',
    'ru': 'Минут на тренировку',
  },
  'workout.ai_focus': {
    'en': 'Focus (optional)',
    'ru': 'Акцент (необязательно)',
  },
  'workout.ai_focus_hint': {
    'en': 'e.g. chest, deadlift',
    'ru': 'напр. грудь, становая',
  },
  'workout.ai_limitations': {
    'en': 'Limitations (optional)',
    'ru': 'Ограничения (необязательно)',
  },
  'workout.ai_limitations_hint': {
    'en': 'e.g. bad knee, no jumping',
    'ru': 'напр. колено, без прыжков',
  },
  'workout.ai_build_free': {
    'en': 'Build program',
    'ru': 'Собрать программу',
  },
  'workout.ai_build_ai': {
    'en': 'Build with AI',
    'ru': 'Собрать с AI',
  },
  'workout.ai_rebuild': {
    'en': 'Rebuild',
    'ru': 'Пересобрать',
  },
  'workout.ai_save': {
    'en': 'Save program',
    'ru': 'Сохранить программу',
  },
  'workout.ai_saved': {
    'en': 'Program saved to your workouts',
    'ru': 'Программа сохранена в тренировки',
  },
  'workout.ai_loading': {
    'en': 'Coaching your program…',
    'ru': 'Собираю программу…',
  },
  'workout.ai_empty': {
    'en': 'Could not build a program. Try again.',
    'ru': 'Не удалось собрать программу. Попробуйте ещё раз.',
  },
  'workout.ai_try_again': {
    'en': 'Try again',
    'ru': 'Попробовать снова',
  },
  'workout.ai_premium_feature': {
    'en': 'AI workout program',
    'ru': 'AI-программа тренировок',
  },
  // ---------------------------------------------------------------------------
  // Шаблонные имена тренировок: программы, дни, упражнения (workout_templates.dart).
  // Ключи-слаги генерируются в buildTemplateProgram, переводятся в
  // localizeWorkoutProgram перед сохранением в БД.
  // ---------------------------------------------------------------------------
  'workout.program_strength': {
    'en': 'Strength Program',
    'ru': 'Силовая программа',
    'de': 'Kraftprogramm',
    'fr': 'Programme de force',
    'it': 'Programma di forza',
    'pt': 'Programa de força',
    'es': 'Programa de fuerza',
    'id': 'Program Kekuatan',
    'hi': 'शक्ति कार्यक्रम',
    'ja': 'ストレングスプログラム',
    'ko': '근력 프로그램',
  },
  'workout.program_muscle': {
    'en': 'Muscle Builder',
    'ru': 'Набор мышечной массы',
    'de': 'Muskelaufbau',
    'fr': 'Prise de muscle',
    'it': 'Costruzione muscolare',
    'pt': 'Construção muscular',
    'es': 'Desarrollo muscular',
    'id': 'Pembentukan Otot',
    'hi': 'मांसपेशी निर्माण',
    'ja': '筋肉増強',
    'ko': '근육 증강',
  },
  'workout.program_fat_loss': {
    'en': 'Fat Loss Program',
    'ru': 'Программа жиросжигания',
    'de': 'Fettabbau-Programm',
    'fr': 'Programme de perte de graisse',
    'it': 'Programma dimagrante',
    'pt': 'Programa de perda de gordura',
    'es': 'Programa de pérdida de grasa',
    'id': 'Program Pembakaran Lemak',
    'hi': 'वसा घटाने का कार्यक्रम',
    'ja': '脂肪燃焼プログラム',
    'ko': '체지방 감량 프로그램',
  },
  'workout.program_endurance': {
    'en': 'Endurance Program',
    'ru': 'Программа на выносливость',
    'de': 'Ausdauerprogramm',
    'fr': "Programme d'endurance",
    'it': 'Programma di resistenza',
    'pt': 'Programa de resistência',
    'es': 'Programa de resistencia',
    'id': 'Program Daya Tahan',
    'hi': 'सहनशक्ति कार्यक्रम',
    'ja': '持久力プログラム',
    'ko': '지구력 프로그램',
  },
  'workout.program_general': {
    'en': 'General Fitness',
    'ru': 'Общая физическая подготовка',
    'de': 'Allgemeine Fitness',
    'fr': 'Forme générale',
    'it': 'Fitness generale',
    'pt': 'Condicionamento geral',
    'es': 'Fitness general',
    'id': 'Kebugaran Umum',
    'hi': 'सामान्य फिटनेस',
    'ja': '総合フィットネス',
    'ko': '일반 피트니스',
  },
  'workout.day_push': {
    'en': 'Push Day',
    'ru': 'День жимов',
    'de': 'Push-Tag',
    'fr': 'Jour poussée',
    'it': 'Giorno di spinta',
    'pt': 'Dia de empurrar',
    'es': 'Día de empuje',
    'id': 'Hari Dorong',
    'hi': 'पुश डे',
    'ja': 'プッシュの日',
    'ko': '미는 날',
  },
  'workout.day_pull': {
    'en': 'Pull Day',
    'ru': 'День тяг',
    'de': 'Pull-Tag',
    'fr': 'Jour tirage',
    'it': 'Giorno di tirata',
    'pt': 'Dia de puxar',
    'es': 'Día de tirón',
    'id': 'Hari Tarik',
    'hi': 'पुल डे',
    'ja': 'プルの日',
    'ko': '당기는 날',
  },
  'workout.day_legs': {
    'en': 'Leg Day',
    'ru': 'День ног',
    'de': 'Bein-Tag',
    'fr': 'Jour jambes',
    'it': 'Giorno gambe',
    'pt': 'Dia de pernas',
    'es': 'Día de piernas',
    'id': 'Hari Kaki',
    'hi': 'लेग डे',
    'ja': '脚の日',
    'ko': '다리 운동 날',
  },
  'workout.day_upper': {
    'en': 'Upper Body',
    'ru': 'Верх тела',
    'de': 'Oberkörper',
    'fr': 'Haut du corps',
    'it': 'Parte superiore',
    'pt': 'Parte superior',
    'es': 'Tren superior',
    'id': 'Tubuh Atas',
    'hi': 'ऊपरी शरीर',
    'ja': '上半身',
    'ko': '상체',
  },
  'workout.day_lower': {
    'en': 'Lower Body',
    'ru': 'Низ тела',
    'de': 'Unterkörper',
    'fr': 'Bas du corps',
    'it': 'Parte inferiore',
    'pt': 'Parte inferior',
    'es': 'Tren inferior',
    'id': 'Tubuh Bawah',
    'hi': 'निचला शरीर',
    'ja': '下半身',
    'ko': '하체',
  },
  'workout.day_core': {
    'en': 'Core & Conditioning',
    'ru': 'Кор и кондиция',
    'de': 'Core & Kondition',
    'fr': 'Gainage et cardio',
    'it': 'Core e condizionamento',
    'pt': 'Core e condicionamento',
    'es': 'Core y acondicionamiento',
    'id': 'Inti & Pengondisian',
    'hi': 'कोर और कंडीशनिंग',
    'ja': 'コア＆コンディショニング',
    'ko': '코어 & 컨디셔닝',
  },
  'workout.day_full': {
    'en': 'Full Body {n}',
    'ru': 'Всё тело {n}',
    'de': 'Ganzkörper {n}',
    'fr': 'Corps entier {n}',
    'it': 'Corpo intero {n}',
    'pt': 'Corpo inteiro {n}',
    'es': 'Cuerpo completo {n}',
    'id': 'Seluruh Tubuh {n}',
    'hi': 'पूरा शरीर {n}',
    'ja': '全身 {n}',
    'ko': '전신 {n}',
  },
  'exercise.barbell_bench_press': {
    'en': 'Barbell Bench Press',
    'ru': 'Жим штанги лёжа',
    'de': 'Langhantel-Bankdrücken',
    'fr': 'Développé couché à la barre',
    'it': 'Distensioni su panca con bilanciere',
    'pt': 'Supino com barra',
    'es': 'Press de banca con barra',
    'id': 'Bench Press Barbel',
    'hi': 'बारबेल बेंच प्रेस',
    'ja': 'バーベルベンチプレス',
    'ko': '바벨 벤치 프레스',
  },
  'exercise.overhead_barbell_press': {
    'en': 'Overhead Barbell Press',
    'ru': 'Жим штанги стоя',
    'de': 'Langhantel-Schulterdrücken',
    'fr': 'Développé militaire à la barre',
    'it': 'Lento avanti con bilanciere',
    'pt': 'Desenvolvimento com barra',
    'es': 'Press militar con barra',
    'id': 'Overhead Press Barbel',
    'hi': 'ओवरहेड बारबेल प्रेस',
    'ja': 'バーベルオーバーヘッドプレス',
    'ko': '바벨 오버헤드 프레스',
  },
  'exercise.dumbbell_bench_press': {
    'en': 'Dumbbell Bench Press',
    'ru': 'Жим гантелей лёжа',
    'de': 'Kurzhantel-Bankdrücken',
    'fr': 'Développé couché aux haltères',
    'it': 'Distensioni su panca con manubri',
    'pt': 'Supino com halteres',
    'es': 'Press de banca con mancuernas',
    'id': 'Bench Press Dumbel',
    'hi': 'डंबल बेंच प्रेस',
    'ja': 'ダンベルベンチプレス',
    'ko': '덤벨 벤치 프레스',
  },
  'exercise.dumbbell_shoulder_press': {
    'en': 'Dumbbell Shoulder Press',
    'ru': 'Жим гантелей сидя',
    'de': 'Kurzhantel-Schulterdrücken',
    'fr': 'Développé épaules aux haltères',
    'it': 'Lento con manubri',
    'pt': 'Desenvolvimento com halteres',
    'es': 'Press de hombros con mancuernas',
    'id': 'Shoulder Press Dumbel',
    'hi': 'डंबल शोल्डर प्रेस',
    'ja': 'ダンベルショルダープレス',
    'ko': '덤벨 숄더 프레스',
  },
  'exercise.dumbbell_lateral_raise': {
    'en': 'Dumbbell Lateral Raise',
    'ru': 'Махи гантелями в стороны',
    'de': 'Kurzhantel-Seitheben',
    'fr': 'Élévations latérales aux haltères',
    'it': 'Alzate laterali con manubri',
    'pt': 'Elevação lateral com halteres',
    'es': 'Elevaciones laterales con mancuernas',
    'id': 'Lateral Raise Dumbel',
    'hi': 'डंबल लेटरल रेज़',
    'ja': 'ダンベルサイドレイズ',
    'ko': '덤벨 레터럴 레이즈',
  },
  'exercise.push_up': {
    'en': 'Push-Up',
    'ru': 'Отжимания',
    'de': 'Liegestütze',
    'fr': 'Pompes',
    'it': 'Piegamenti',
    'pt': 'Flexões',
    'es': 'Flexiones',
    'id': 'Push-Up',
    'hi': 'पुश-अप',
    'ja': '腕立て伏せ',
    'ko': '푸시업',
  },
  'exercise.pike_push_up': {
    'en': 'Pike Push-Up',
    'ru': 'Отжимания «уголком»',
    'de': 'Pike-Liegestütze',
    'fr': 'Pompes piquées',
    'it': 'Piegamenti a pica',
    'pt': 'Flexões pike',
    'es': 'Flexiones pike',
    'id': 'Pike Push-Up',
    'hi': 'पाइक पुश-अप',
    'ja': 'パイクプッシュアップ',
    'ko': '파이크 푸시업',
  },
  'exercise.dip': {
    'en': 'Dip',
    'ru': 'Отжимания на брусьях',
    'de': 'Dips',
    'fr': 'Dips',
    'it': 'Dip',
    'pt': 'Mergulho',
    'es': 'Fondos',
    'id': 'Dip',
    'hi': 'डिप',
    'ja': 'ディップス',
    'ko': '딥스',
  },
  'exercise.barbell_row': {
    'en': 'Barbell Row',
    'ru': 'Тяга штанги в наклоне',
    'de': 'Langhantelrudern',
    'fr': 'Rowing à la barre',
    'it': 'Rematore con bilanciere',
    'pt': 'Remada com barra',
    'es': 'Remo con barra',
    'id': 'Row Barbel',
    'hi': 'बारबेल रो',
    'ja': 'バーベルロウ',
    'ko': '바벨 로우',
  },
  'exercise.barbell_curl': {
    'en': 'Barbell Curl',
    'ru': 'Подъём штанги на бицепс',
    'de': 'Langhantel-Curl',
    'fr': 'Curl à la barre',
    'it': 'Curl con bilanciere',
    'pt': 'Rosca com barra',
    'es': 'Curl con barra',
    'id': 'Curl Barbel',
    'hi': 'बारबेल कर्ल',
    'ja': 'バーベルカール',
    'ko': '바벨 컬',
  },
  'exercise.dumbbell_row': {
    'en': 'Dumbbell Row',
    'ru': 'Тяга гантели в наклоне',
    'de': 'Kurzhantelrudern',
    'fr': 'Rowing à un bras',
    'it': 'Rematore con manubrio',
    'pt': 'Remada com haltere',
    'es': 'Remo con mancuerna',
    'id': 'Row Dumbel',
    'hi': 'डंबल रो',
    'ja': 'ダンベルロウ',
    'ko': '덤벨 로우',
  },
  'exercise.dumbbell_curl': {
    'en': 'Dumbbell Curl',
    'ru': 'Подъём гантелей на бицепс',
    'de': 'Kurzhantel-Curl',
    'fr': 'Curl aux haltères',
    'it': 'Curl con manubri',
    'pt': 'Rosca com halteres',
    'es': 'Curl con mancuernas',
    'id': 'Curl Dumbel',
    'hi': 'डंबल कर्ल',
    'ja': 'ダンベルカール',
    'ko': '덤벨 컬',
  },
  'exercise.pull_up': {
    'en': 'Pull-Up',
    'ru': 'Подтягивания',
    'de': 'Klimmzüge',
    'fr': 'Tractions',
    'it': 'Trazioni',
    'pt': 'Barra fixa',
    'es': 'Dominadas',
    'id': 'Pull-Up',
    'hi': 'पुल-अप',
    'ja': '懸垂',
    'ko': '풀업',
  },
  'exercise.chin_up': {
    'en': 'Chin-Up',
    'ru': 'Подтягивания обратным хватом',
    'de': 'Klimmzüge im Untergriff',
    'fr': 'Tractions supination',
    'it': 'Trazioni presa supina',
    'pt': 'Barra fixa supinada',
    'es': 'Dominadas supinas',
    'id': 'Chin-Up',
    'hi': 'चिन-अप',
    'ja': 'チンアップ',
    'ko': '친업',
  },
  'exercise.inverted_row': {
    'en': 'Inverted Row',
    'ru': 'Австралийские подтягивания',
    'de': 'Umgekehrtes Rudern',
    'fr': 'Rowing inversé',
    'it': 'Rematore inverso',
    'pt': 'Remada invertida',
    'es': 'Remo invertido',
    'id': 'Inverted Row',
    'hi': 'इनवर्टेड रो',
    'ja': 'インバーテッドロウ',
    'ko': '인버티드 로우',
  },
  'exercise.superman_hold': {
    'en': 'Superman Hold',
    'ru': 'Удержание «супермен»',
    'de': 'Superman-Halten',
    'fr': 'Gainage superman',
    'it': 'Tenuta superman',
    'pt': 'Prancha superman',
    'es': 'Plancha superman',
    'id': 'Tahan Superman',
    'hi': 'सुपरमैन होल्ड',
    'ja': 'スーパーマンホールド',
    'ko': '슈퍼맨 홀드',
  },
  'exercise.barbell_back_squat': {
    'en': 'Barbell Back Squat',
    'ru': 'Приседания со штангой',
    'de': 'Langhantel-Kniebeuge',
    'fr': 'Squat à la barre',
    'it': 'Squat con bilanciere',
    'pt': 'Agachamento com barra',
    'es': 'Sentadilla con barra',
    'id': 'Back Squat Barbel',
    'hi': 'बारबेल बैक स्क्वाट',
    'ja': 'バーベルバックスクワット',
    'ko': '바벨 백 스쿼트',
  },
  'exercise.barbell_deadlift': {
    'en': 'Barbell Deadlift',
    'ru': 'Становая тяга',
    'de': 'Langhantel-Kreuzheben',
    'fr': 'Soulevé de terre',
    'it': 'Stacco da terra',
    'pt': 'Levantamento terra',
    'es': 'Peso muerto',
    'id': 'Deadlift Barbel',
    'hi': 'बारबेल डेडलिफ्ट',
    'ja': 'バーベルデッドリフト',
    'ko': '바벨 데드리프트',
  },
  'exercise.barbell_romanian_deadlift': {
    'en': 'Barbell Romanian Deadlift',
    'ru': 'Румынская становая тяга',
    'de': 'Rumänisches Kreuzheben',
    'fr': 'Soulevé de terre roumain',
    'it': 'Stacco rumeno',
    'pt': 'Levantamento terra romeno',
    'es': 'Peso muerto rumano',
    'id': 'Romanian Deadlift Barbel',
    'hi': 'रोमानियन डेडलिफ्ट',
    'ja': 'ルーマニアンデッドリフト',
    'ko': '루마니안 데드리프트',
  },
  'exercise.dumbbell_goblet_squat': {
    'en': 'Dumbbell Goblet Squat',
    'ru': 'Гоблет-приседания с гантелью',
    'de': 'Kurzhantel-Goblet-Squat',
    'fr': 'Goblet squat aux haltères',
    'it': 'Goblet squat con manubrio',
    'pt': 'Agachamento goblet com haltere',
    'es': 'Sentadilla goblet con mancuerna',
    'id': 'Goblet Squat Dumbel',
    'hi': 'डंबल गॉब्लेट स्क्वाट',
    'ja': 'ダンベルゴブレットスクワット',
    'ko': '덤벨 고블릿 스쿼트',
  },
  'exercise.dumbbell_lunge': {
    'en': 'Dumbbell Lunge',
    'ru': 'Выпады с гантелями',
    'de': 'Kurzhantel-Ausfallschritte',
    'fr': 'Fentes aux haltères',
    'it': 'Affondi con manubri',
    'pt': 'Afundo com halteres',
    'es': 'Zancadas con mancuernas',
    'id': 'Lunge Dumbel',
    'hi': 'डंबल लंज',
    'ja': 'ダンベルランジ',
    'ko': '덤벨 런지',
  },
  'exercise.bodyweight_squat': {
    'en': 'Bodyweight Squat',
    'ru': 'Приседания без отягощения',
    'de': 'Kniebeuge mit Körpergewicht',
    'fr': 'Squat au poids du corps',
    'it': 'Squat a corpo libero',
    'pt': 'Agachamento livre',
    'es': 'Sentadilla con peso corporal',
    'id': 'Squat Berat Badan',
    'hi': 'बॉडीवेट स्क्वाट',
    'ja': '自重スクワット',
    'ko': '맨몸 스쿼트',
  },
  'exercise.bulgarian_split_squat': {
    'en': 'Bulgarian Split Squat',
    'ru': 'Болгарские выпады',
    'de': 'Bulgarische Split-Kniebeuge',
    'fr': 'Squat bulgare',
    'it': 'Affondo bulgaro',
    'pt': 'Agachamento búlgaro',
    'es': 'Sentadilla búlgara',
    'id': 'Bulgarian Split Squat',
    'hi': 'बल्गेरियन स्प्लिट स्क्वाट',
    'ja': 'ブルガリアンスプリットスクワット',
    'ko': '불가리안 스플릿 스쿼트',
  },
  'exercise.glute_bridge': {
    'en': 'Glute Bridge',
    'ru': 'Ягодичный мостик',
    'de': 'Glute Bridge',
    'fr': 'Pont fessier',
    'it': 'Ponte per glutei',
    'pt': 'Ponte de glúteos',
    'es': 'Puente de glúteos',
    'id': 'Glute Bridge',
    'hi': 'ग्लूट ब्रिज',
    'ja': 'ヒップリフト',
    'ko': '글루트 브리지',
  },
  'exercise.plank': {
    'en': 'Plank',
    'ru': 'Планка',
    'de': 'Unterarmstütz',
    'fr': 'Planche',
    'it': 'Plank',
    'pt': 'Prancha',
    'es': 'Plancha',
    'id': 'Plank',
    'hi': 'प्लैंक',
    'ja': 'プランク',
    'ko': '플랭크',
  },
  'exercise.hanging_knee_raise': {
    'en': 'Hanging Knee Raise',
    'ru': 'Подъём коленей в висе',
    'de': 'Hängendes Knieheben',
    'fr': 'Relevé de genoux suspendu',
    'it': 'Sollevamento ginocchia in sospensione',
    'pt': 'Elevação de joelhos na barra',
    'es': 'Elevación de rodillas colgado',
    'id': 'Hanging Knee Raise',
    'hi': 'हैंगिंग नी रेज़',
    'ja': 'ハンギングニーレイズ',
    'ko': '행잉 니 레이즈',
  },
  'exercise.hollow_body_hold': {
    'en': 'Hollow Body Hold',
    'ru': 'Удержание «лодочка»',
    'de': 'Hollow-Body-Halten',
    'fr': 'Gainage hollow body',
    'it': 'Hollow body hold',
    'pt': 'Hollow body hold',
    'es': 'Hollow body hold',
    'id': 'Hollow Body Hold',
    'hi': 'हॉलो बॉडी होल्ड',
    'ja': 'ホロウボディホールド',
    'ko': '할로우 바디 홀드',
  },
  'exercise.russian_twist': {
    'en': 'Russian Twist',
    'ru': 'Русский твист',
    'de': 'Russian Twist',
    'fr': 'Russian twist',
    'it': 'Russian twist',
    'pt': 'Russian twist',
    'es': 'Giro ruso',
    'id': 'Russian Twist',
    'hi': 'रशियन ट्विस्ट',
    'ja': 'ロシアンツイスト',
    'ko': '러시안 트위스트',
  },
  'exercise.burpee': {
    'en': 'Burpee',
    'ru': 'Бёрпи',
    'de': 'Burpee',
    'fr': 'Burpee',
    'it': 'Burpee',
    'pt': 'Burpee',
    'es': 'Burpee',
    'id': 'Burpee',
    'hi': 'बर्पी',
    'ja': 'バーピー',
    'ko': '버피',
  },
  'exercise.mountain_climber': {
    'en': 'Mountain Climber',
    'ru': 'Скалолаз',
    'de': 'Mountain Climber',
    'fr': 'Mountain climber',
    'it': 'Mountain climber',
    'pt': 'Escalador',
    'es': 'Escalador',
    'id': 'Mountain Climber',
    'hi': 'माउंटेन क्लाइंबर',
    'ja': 'マウンテンクライマー',
    'ko': '마운틴 클라이머',
  },
  'exercise.jumping_jack': {
    'en': 'Jumping Jack',
    'ru': 'Прыжки «звёздочка»',
    'de': 'Hampelmann',
    'fr': 'Jumping jack',
    'it': 'Jumping jack',
    'pt': 'Polichinelo',
    'es': 'Salto de tijera',
    'id': 'Jumping Jack',
    'hi': 'जंपिंग जैक',
    'ja': 'ジャンピングジャック',
    'ko': '점핑잭',
  },
  'exercise.high_knees': {
    'en': 'High Knees',
    'ru': 'Бег с высоким подниманием колен',
    'de': 'Knieheben im Lauf',
    'fr': 'Montées de genoux',
    'it': 'Corsa con ginocchia alte',
    'pt': 'Joelhos altos',
    'es': 'Rodillas altas',
    'id': 'High Knees',
    'hi': 'हाई नीज़',
    'ja': 'もも上げ',
    'ko': '하이 니',
  },

  // ---------------------------------------------------------------------------
  // Имена 18 новых упражнений каталога — все 11 языков
  // ---------------------------------------------------------------------------
  'exercise.front_squat': {
    'en': 'Front Squat',
    'ru': 'Фронтальный присед',
    'de': 'Frontkniebeuge',
    'fr': 'Squat avant',
    'it': 'Squat frontale',
    'pt': 'Agachamento frontal',
    'es': 'Sentadilla frontal',
    'id': 'Front Squat',
    'hi': 'फ्रंट स्क्वाट',
    'ja': 'フロントスクワット',
    'ko': '프론트 스쿼트',
  },
  'exercise.goblet_squat': {
    'en': 'Goblet Squat',
    'ru': 'Гоблет-присед',
    'de': 'Goblet-Squat',
    'fr': 'Goblet squat',
    'it': 'Goblet squat',
    'pt': 'Goblet squat',
    'es': 'Sentadilla goblet',
    'id': 'Goblet Squat',
    'hi': 'गॉब्लेट स्क्वाट',
    'ja': 'ゴブレットスクワット',
    'ko': '고블릿 스쿼트',
  },
  'exercise.walking_lunge': {
    'en': 'Walking Lunge',
    'ru': 'Выпады в ходьбе',
    'de': 'Ausfallschritte gehend',
    'fr': 'Fentes marchées',
    'it': 'Affondi camminati',
    'pt': 'Afundo caminhando',
    'es': 'Zancadas caminando',
    'id': 'Walking Lunge',
    'hi': 'वॉकिंग लंज',
    'ja': 'ウォーキングランジ',
    'ko': '워킹 런지',
  },
  'exercise.leg_press': {
    'en': 'Leg Press',
    'ru': 'Жим ногами',
    'de': 'Beinpresse',
    'fr': 'Presse à jambes',
    'it': 'Leg press',
    'pt': 'Leg press',
    'es': 'Prensa de piernas',
    'id': 'Leg Press',
    'hi': 'लेग प्रेस',
    'ja': 'レッグプレス',
    'ko': '레그 프레스',
  },
  'exercise.romanian_deadlift': {
    'en': 'Romanian Deadlift',
    'ru': 'Румынская становая тяга',
    'de': 'Rumänisches Kreuzheben',
    'fr': 'Soulevé de terre roumain',
    'it': 'Stacco rumeno',
    'pt': 'Levantamento terra romeno',
    'es': 'Peso muerto rumano',
    'id': 'Romanian Deadlift',
    'hi': 'रोमानियन डेडलिफ्ट',
    'ja': 'ルーマニアンデッドリフト',
    'ko': '루마니안 데드리프트',
  },
  'exercise.leg_curl': {
    'en': 'Leg Curl',
    'ru': 'Сгибание ног в тренажёре',
    'de': 'Beinbeuger',
    'fr': 'Curl jambes',
    'it': 'Leg curl',
    'pt': 'Leg curl',
    'es': 'Curl de piernas',
    'id': 'Leg Curl',
    'hi': 'लेग कर्ल',
    'ja': 'レッグカール',
    'ko': '레그 컬',
  },
  'exercise.leg_extension': {
    'en': 'Leg Extension',
    'ru': 'Разгибание ног в тренажёре',
    'de': 'Beinstrecker',
    'fr': 'Extension jambes',
    'it': 'Leg extension',
    'pt': 'Leg extension',
    'es': 'Extensión de piernas',
    'id': 'Leg Extension',
    'hi': 'लेग एक्सटेंशन',
    'ja': 'レッグエクステンション',
    'ko': '레그 익스텐션',
  },
  'exercise.standing_calf_raise': {
    'en': 'Standing Calf Raise',
    'ru': 'Подъём на носки стоя',
    'de': 'Wadenheben stehend',
    'fr': 'Élévation des mollets debout',
    'it': 'Calf raise in piedi',
    'pt': 'Elevação de panturrilha em pé',
    'es': 'Elevación de talones de pie',
    'id': 'Standing Calf Raise',
    'hi': 'स्टैंडिंग कॉफ रेज़',
    'ja': 'スタンディングカーフレイズ',
    'ko': '서서 종아리 올리기',
  },
  'exercise.hip_thrust': {
    'en': 'Hip Thrust',
    'ru': 'Ягодичный мост со штангой',
    'de': 'Hip Thrust',
    'fr': 'Hip thrust',
    'it': 'Hip thrust',
    'pt': 'Hip thrust',
    'es': 'Empuje de cadera',
    'id': 'Hip Thrust',
    'hi': 'हिप थ्रस्ट',
    'ja': 'ヒップスラスト',
    'ko': '힙 스러스트',
  },
  'exercise.lat_pulldown': {
    'en': 'Lat Pulldown',
    'ru': 'Тяга верхнего блока',
    'de': 'Latzug',
    'fr': 'Tirage vertical',
    'it': 'Lat pulldown',
    'pt': 'Puxada alta',
    'es': 'Jalón al pecho',
    'id': 'Lat Pulldown',
    'hi': 'लैट पुलडाउन',
    'ja': 'ラットプルダウン',
    'ko': '랫 풀다운',
  },
  'exercise.seated_cable_row': {
    'en': 'Seated Cable Row',
    'ru': 'Тяга нижнего блока сидя',
    'de': 'Sitzrudern am Kabel',
    'fr': 'Rowing poulie basse assis',
    'it': 'Rematore al cavo seduto',
    'pt': 'Remada no cabo sentado',
    'es': 'Remo en polea baja sentado',
    'id': 'Seated Cable Row',
    'hi': 'सीटेड केबल रो',
    'ja': 'シーテッドケーブルロウ',
    'ko': '시티드 케이블 로우',
  },
  'exercise.face_pull': {
    'en': 'Face Pull',
    'ru': 'Тяга к лицу',
    'de': 'Face Pull',
    'fr': 'Tirage visage',
    'it': 'Face pull',
    'pt': 'Face pull',
    'es': 'Jalón a la cara',
    'id': 'Face Pull',
    'hi': 'फेस पुल',
    'ja': 'フェイスプル',
    'ko': '페이스 풀',
  },
  'exercise.t_bar_row': {
    'en': 'T-Bar Row',
    'ru': 'Тяга Т-образного грифа',
    'de': 'T-Hantel-Rudern',
    'fr': 'Rowing barre T',
    'it': 'Rematore con T-bar',
    'pt': 'Remada barra T',
    'es': 'Remo en T',
    'id': 'T-Bar Row',
    'hi': 'टी-बार रो',
    'ja': 'Tバーロウ',
    'ko': 'T바 로우',
  },
  'exercise.incline_barbell_bench_press': {
    'en': 'Incline Barbell Bench Press',
    'ru': 'Жим штанги на наклонной скамье',
    'de': 'Schrägbankdrücken mit Langhantel',
    'fr': 'Développé couché incliné à la barre',
    'it': 'Panca inclinata con bilanciere',
    'pt': 'Supino inclinado com barra',
    'es': 'Press de banca inclinado con barra',
    'id': 'Incline Bench Press Barbel',
    'hi': 'इनक्लाइन बारबेल बेंच प्रेस',
    'ja': 'インクラインバーベルベンチプレス',
    'ko': '인클라인 바벨 벤치 프레스',
  },
  'exercise.incline_dumbbell_press': {
    'en': 'Incline Dumbbell Press',
    'ru': 'Жим гантелей на наклонной скамье',
    'de': 'Schrägbankdrücken mit Kurzhanteln',
    'fr': 'Développé couché incliné aux haltères',
    'it': 'Panca inclinata con manubri',
    'pt': 'Supino inclinado com halteres',
    'es': 'Press inclinado con mancuernas',
    'id': 'Incline Dumbbell Press',
    'hi': 'इनक्लाइन डंबल प्रेस',
    'ja': 'インクラインダンベルプレス',
    'ko': '인클라인 덤벨 프레스',
  },
  'exercise.chest_dip': {
    'en': 'Chest Dip',
    'ru': 'Отжимания на брусьях (грудь)',
    'de': 'Dips (Brust)',
    'fr': 'Dips (pectoraux)',
    'it': 'Dip (petto)',
    'pt': 'Mergulho (peitoral)',
    'es': 'Fondos (pecho)',
    'id': 'Chest Dip',
    'hi': 'चेस्ट डिप',
    'ja': 'チェストディップス',
    'ko': '체스트 딥스',
  },

  // ---------------------------------------------------------------------------
  // Имена 17 новых упражнений каталога — все 11 языков
  // dumbbell_shoulder_press, barbell_curl, dumbbell_curl, mountain_climber
  // уже присутствуют выше (добавлены предыдущим агентом).
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_fly': {
    'en': 'Dumbbell Fly',
    'ru': 'Разведение гантелей лёжа',
    'de': 'Kurzhantel-Fliegende',
    'fr': 'Écarté haltères',
    'it': 'Croci con manubri',
    'pt': 'Crucifixo com halteres',
    'es': 'Aperturas con mancuernas',
    'id': 'Dumbbell Fly',
    'hi': 'डंबल फ्लाई',
    'ja': 'ダンベルフライ',
    'ko': '덤벨 플라이',
  },
  'exercise.cable_crossover': {
    'en': 'Cable Crossover',
    'ru': 'Кроссовер на блоках',
    'de': 'Kabelkreuzziehen',
    'fr': 'Croisé poulie',
    'it': 'Croci ai cavi',
    'pt': 'Crucifixo no cabo',
    'es': 'Cruce de poleas',
    'id': 'Cable Crossover',
    'hi': 'केबल क्रॉसओवर',
    'ja': 'ケーブルクロスオーバー',
    'ko': '케이블 크로스오버',
  },
  'exercise.lateral_raise': {
    'en': 'Lateral Raise',
    'ru': 'Махи гантелями в стороны',
    'de': 'Seitheben',
    'fr': 'Élévations latérales',
    'it': 'Alzate laterali',
    'pt': 'Elevação lateral',
    'es': 'Elevaciones laterales',
    'id': 'Lateral Raise',
    'hi': 'लेटरल रेज़',
    'ja': 'サイドレイズ',
    'ko': '레터럴 레이즈',
  },
  'exercise.front_raise': {
    'en': 'Front Raise',
    'ru': 'Махи гантелями вперёд',
    'de': 'Frontheben',
    'fr': 'Élévations frontales',
    'it': 'Alzate frontali',
    'pt': 'Elevação frontal',
    'es': 'Elevaciones frontales',
    'id': 'Front Raise',
    'hi': 'फ्रंट रेज़',
    'ja': 'フロントレイズ',
    'ko': '프론트 레이즈',
  },
  'exercise.rear_delt_fly': {
    'en': 'Rear Delt Fly',
    'ru': 'Разведение гантелей в наклоне',
    'de': 'Hintere Schulter Fliegende',
    'fr': 'Écarté arrière',
    'it': 'Croci posteriori',
    'pt': 'Crucifixo posterior',
    'es': 'Aperturas para deltoides posteriores',
    'id': 'Rear Delt Fly',
    'hi': 'रियर डेल्ट फ्लाई',
    'ja': 'リアデルトフライ',
    'ko': '리어 델트 플라이',
  },
  'exercise.arnold_press': {
    'en': 'Arnold Press',
    'ru': 'Жим Арнольда',
    'de': 'Arnold-Press',
    'fr': 'Développé Arnold',
    'it': 'Arnold press',
    'pt': 'Press Arnold',
    'es': 'Press Arnold',
    'id': 'Arnold Press',
    'hi': 'अर्नोल्ड प्रेस',
    'ja': 'アーノルドプレス',
    'ko': '아놀드 프레스',
  },
  'exercise.hammer_curl': {
    'en': 'Hammer Curl',
    'ru': 'Молотковый подъём',
    'de': 'Hammer-Curl',
    'fr': 'Curl marteau',
    'it': 'Hammer curl',
    'pt': 'Rosca martelo',
    'es': 'Curl martillo',
    'id': 'Hammer Curl',
    'hi': 'हैमर कर्ल',
    'ja': 'ハンマーカール',
    'ko': '해머 컬',
  },
  'exercise.triceps_pushdown': {
    'en': 'Triceps Pushdown',
    'ru': 'Разгибание рук на блоке',
    'de': 'Trizepsdrücken am Kabel',
    'fr': 'Pushdown triceps',
    'it': 'Pushdown tricipiti',
    'pt': 'Extensão de tríceps no cabo',
    'es': 'Extensión de tríceps en polea',
    'id': 'Triceps Pushdown',
    'hi': 'ट्राइसेप्स पुशडाउन',
    'ja': 'トライセプスプッシュダウン',
    'ko': '트라이셉스 푸시다운',
  },
  'exercise.overhead_triceps_extension': {
    'en': 'Overhead Triceps Extension',
    'ru': 'Французский жим с гантелью',
    'de': 'Trizepsstreckung über Kopf',
    'fr': 'Extension triceps au-dessus de la tête',
    'it': 'Estensione tricipiti sopra la testa',
    'pt': 'Extensão de tríceps acima da cabeça',
    'es': 'Extensión de tríceps sobre la cabeza',
    'id': 'Overhead Triceps Extension',
    'hi': 'ओवरहेड ट्राइसेप्स एक्सटेंशन',
    'ja': 'オーバーヘッドトライセプスエクステンション',
    'ko': '오버헤드 트라이셉스 익스텐션',
  },
  'exercise.close_grip_bench_press': {
    'en': 'Close-Grip Bench Press',
    'ru': 'Жим штанги узким хватом',
    'de': 'Bankdrücken enger Griff',
    'fr': 'Développé couché prise serrée',
    'it': 'Panca presa stretta',
    'pt': 'Supino pegada fechada',
    'es': 'Press de banca con agarre cerrado',
    'id': 'Close-Grip Bench Press',
    'hi': 'क्लोज़-ग्रिप बेंच प्रेस',
    'ja': 'ナローグリップベンチプレス',
    'ko': '클로즈 그립 벤치 프레스',
  },
  'exercise.hanging_leg_raise': {
    'en': 'Hanging Leg Raise',
    'ru': 'Подъём ног в висе',
    'de': 'Hängendes Beinheben',
    'fr': 'Relevé de jambes suspendu',
    'it': 'Sollevamento gambe in sospensione',
    'pt': 'Elevação de pernas na barra',
    'es': 'Elevación de piernas colgado',
    'id': 'Hanging Leg Raise',
    'hi': 'हैंगिंग लेग रेज़',
    'ja': 'ハンギングレッグレイズ',
    'ko': '행잉 레그 레이즈',
  },
  'exercise.crunch': {
    'en': 'Crunch',
    'ru': 'Скручивания',
    'de': 'Crunch',
    'fr': 'Crunch',
    'it': 'Crunch',
    'pt': 'Abdominal',
    'es': 'Crunch',
    'id': 'Crunch',
    'hi': 'क्रंच',
    'ja': 'クランチ',
    'ko': '크런치',
  },
  'exercise.kettlebell_swing': {
    'en': 'Kettlebell Swing',
    'ru': 'Махи гирей',
    'de': 'Kettlebell-Swing',
    'fr': 'Balancé au kettlebell',
    'it': 'Swing con kettlebell',
    'pt': 'Swing com kettlebell',
    'es': 'Swing con pesa rusa',
    'id': 'Kettlebell Swing',
    'hi': 'केटलबेल स्विंग',
    'ja': 'ケトルベルスイング',
    'ko': '케틀벨 스윙',
  },

  // ---------------------------------------------------------------------------
  // screentime.signal.*  —  компактный сигнал экранного времени
  // Используется в EveningReviewCard (inline) и DiaryScreen (карточка).
  // ---------------------------------------------------------------------------

  'screentime.signal_label': {
    'en': 'Screen time',
    'ru': 'Экранное время',
    'de': 'Bildschirmzeit',
    'fr': 'Temps d\'écran',
    'it': 'Tempo schermo',
    'pt': 'Tempo de tela',
    'es': 'Tiempo de pantalla',
    'id': 'Waktu layar',
    'hi': 'स्क्रीन समय',
    'ja': 'スクリーンタイム',
    'ko': '스크린 타임',
  },
  'screentime.signal_card_title': {
    'en': 'Screen time today',
    'ru': 'Экранное время сегодня',
    'de': 'Bildschirmzeit heute',
    'fr': 'Temps d\'écran aujourd\'hui',
    'it': 'Tempo schermo oggi',
    'pt': 'Tempo de tela hoje',
    'es': 'Tiempo de pantalla hoy',
    'id': 'Waktu layar hari ini',
    'hi': 'आज का स्क्रीन समय',
    'ja': '本日のスクリーンタイム',
    'ko': '오늘 스크린 타임',
  },
  'screentime.signal_details': {
    'en': 'Details',
    'ru': 'Подробнее',
    'de': 'Details',
    'fr': 'Détails',
    'it': 'Dettagli',
    'pt': 'Detalhes',
    'es': 'Detalles',
    'id': 'Detail',
    'hi': 'विवरण',
    'ja': '詳細',
    'ko': '자세히',
  },
  // {h} → часы, {m} → минуты; напр. «1h 30min» / «1ч 30мин»
  'screentime.fmt_h_min': {
    'en': '{h}h {m}min',
    'ru': '{h}ч {m}мин',
    'de': '{h}h {m}min',
    'fr': '{h}h {m}min',
    'it': '{h}h {m}min',
    'pt': '{h}h {m}min',
    'es': '{h}h {m}min',
    'id': '{h}j {m}mnt',
    'hi': '{h}घं {m}मि',
    'ja': '{h}時間{m}分',
    'ko': '{h}시간 {m}분',
  },
  // {m} → минуты; напр. «45min» / «45мин»
  'screentime.fmt_min': {
    'en': '{m}min',
    'ru': '{m}мин',
    'de': '{m}min',
    'fr': '{m}min',
    'it': '{m}min',
    'pt': '{m}min',
    'es': '{m}min',
    'id': '{m}mnt',
    'hi': '{m}मि',
    'ja': '{m}分',
    'ko': '{m}분',
  },
  'screentime.cat_social': {
    'en': 'Social media',
    'ru': 'Соцсети',
    'de': 'Soziale Medien',
    'fr': 'Réseaux sociaux',
    'it': 'Social media',
    'pt': 'Redes sociais',
    'es': 'Redes sociales',
    'id': 'Media sosial',
    'hi': 'सोशल मीडिया',
    'ja': 'SNS',
    'ko': '소셜 미디어',
  },
  'screentime.cat_video': {
    'en': 'Video',
    'ru': 'Видео',
    'de': 'Video',
    'fr': 'Vidéo',
    'it': 'Video',
    'pt': 'Vídeo',
    'es': 'Vídeo',
    'id': 'Video',
    'hi': 'वीडियो',
    'ja': '動画',
    'ko': '동영상',
  },
  'screentime.cat_games': {
    'en': 'Games',
    'ru': 'Игры',
    'de': 'Spiele',
    'fr': 'Jeux',
    'it': 'Giochi',
    'pt': 'Jogos',
    'es': 'Juegos',
    'id': 'Game',
    'hi': 'गेम्स',
    'ja': 'ゲーム',
    'ko': '게임',
  },
  'screentime.cat_browsing': {
    'en': 'Browsing',
    'ru': 'Браузер',
    'de': 'Browser',
    'fr': 'Navigation',
    'it': 'Navigazione',
    'pt': 'Navegação',
    'es': 'Navegación',
    'id': 'Browsing',
    'hi': 'ब्राउज़िंग',
    'ja': 'ブラウジング',
    'ko': '브라우징',
  },
  'screentime.cat_messaging': {
    'en': 'Messaging',
    'ru': 'Мессенджеры',
    'de': 'Nachrichten',
    'fr': 'Messagerie',
    'it': 'Messaggistica',
    'pt': 'Mensagens',
    'es': 'Mensajería',
    'id': 'Pesan',
    'hi': 'मैसेजिंग',
    'ja': 'メッセージ',
    'ko': '메시징',
  },
  'screentime.cat_other': {
    'en': 'Other',
    'ru': 'Другое',
    'de': 'Sonstiges',
    'fr': 'Autre',
    'it': 'Altro',
    'pt': 'Outros',
    'es': 'Otros',
    'id': 'Lainnya',
    'hi': 'अन्य',
    'ja': 'その他',
    'ko': '기타',
  },

  // ---------------------------------------------------------------------------
  // screentime overrides — per-app category reassignment UI
  // screen_time_screen.dart: _AppsBreakdownSection / _AppCategoryPickerSheet
  // ---------------------------------------------------------------------------

  // Заголовок подраздела «Приложения» в карточке «Usage data».
  'screentime.apps_section': {
    'en': 'Apps',
    'ru': 'Приложения',
    'de': 'Apps',
    'fr': 'Applications',
    'it': 'App',
    'pt': 'Aplicativos',
    'es': 'Aplicaciones',
    'id': 'Aplikasi',
    'hi': 'ऐप्स',
    'ja': 'アプリ',
    'ko': '앱',
  },

  // Заголовок нижнего листа выбора категории для приложения.
  'screentime.reassign_title': {
    'en': 'Change category',
    'ru': 'Изменить категорию',
    'de': 'Kategorie ändern',
    'fr': 'Changer la catégorie',
    'it': 'Cambia categoria',
    'pt': 'Mudar categoria',
    'es': 'Cambiar categoría',
    'id': 'Ubah kategori',
    'hi': 'श्रेणी बदलें',
    'ja': 'カテゴリを変更',
    'ko': '카테고리 변경',
  },

  // Подтверждение сохранения (Snackbar).
  'screentime.category_changed': {
    'en': 'Category saved',
    'ru': 'Категория сохранена',
    'de': 'Kategorie gespeichert',
    'fr': 'Catégorie enregistrée',
    'it': 'Categoria salvata',
    'pt': 'Categoria salva',
    'es': 'Categoría guardada',
    'id': 'Kategori disimpan',
    'hi': 'श्रेणी सहेजी गई',
    'ja': 'カテゴリを保存しました',
    'ko': '카테고리가 저장됐어요',
  },

  // Сброс пользовательского оверрайда (возврат к автоопределению).
  'screentime.reset_to_default': {
    'en': 'Reset to default',
    'ru': 'Вернуть по умолчанию',
    'de': 'Auf Standard zurücksetzen',
    'fr': 'Rétablir par défaut',
    'it': 'Ripristina predefinito',
    'pt': 'Redefinir padrão',
    'es': 'Restablecer por defecto',
    'id': 'Kembalikan ke default',
    'hi': 'डिफ़ॉल्ट पर रीसेट करें',
    'ja': 'デフォルトに戻す',
    'ko': '기본값으로 재설정',
  },

  // ---------------------------------------------------------------------------
  // Новые ключи Kaname-restyle — screen_time_screen.dart
  // ---------------------------------------------------------------------------

  // Формат «N часов» без минут (720 мин = «12h» / «12ч»).
  // Используется в _fmtDuration когда minutes % 60 == 0.
  'screentime.fmt_h_only': {
    'en': '{h}h',
    'ru': '{h}ч',
    'de': '{h}h',
    'fr': '{h}h',
    'it': '{h}h',
    'pt': '{h}h',
    'es': '{h}h',
    'id': '{h}j',
    'hi': '{h}घं',
    'ja': '{h}時間',
    'ko': '{h}시간',
  },

  // Кнопка «Показать ещё N» в per-app breakdown (apps > 8).
  // {n} — количество скрытых строк.
  'screentime.apps_show_more': {
    'en': 'Show {n} more',
    'ru': 'Ещё {n}',
    'de': '{n} weitere anzeigen',
    'fr': 'Voir {n} de plus',
    'it': 'Mostra altri {n}',
    'pt': 'Ver mais {n}',
    'es': 'Ver {n} más',
    'id': 'Tampilkan {n} lagi',
    'hi': '{n} और दिखाएं',
    'ja': 'あと{n}件表示',
    'ko': '{n}개 더 보기',
  },

  // Кнопка «Свернуть» в per-app breakdown (expanded → collapsed).
  'screentime.apps_collapse': {
    'en': 'Collapse',
    'ru': 'Свернуть',
    'de': 'Einklappen',
    'fr': 'Réduire',
    'it': 'Comprimi',
    'pt': 'Recolher',
    'es': 'Contraer',
    'id': 'Ciutkan',
    'hi': 'संकुचित करें',
    'ja': '折りたたむ',
    'ko': '접기',
  },
};
