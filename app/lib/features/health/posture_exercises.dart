// Контент упражнений для осанки (SPEC C5 Ф2 «осанка»).
// Нет БД, нет видео — только текстовые инструкции.

/// Одно упражнение для осанки.
class PostureExercise {
  const PostureExercise({
    required this.name,
    required this.steps,
    required this.seconds,
  });

  /// Название упражнения.
  final String name;

  /// Краткие инструкции (2-3 предложения).
  final String steps;

  /// Рекомендуемая длительность в секундах.
  final int seconds;

  /// Форматированная строка длительности (например, '30 sec' или '60 sec').
  String get durationLabel {
    if (seconds < 60) return '$seconds sec';
    final mins = seconds ~/ 60;
    return '$mins min';
  }
}

/// Список упражнений для осанки — 6 штук, без медицинских обещаний.
const postureExercises = <PostureExercise>[
  PostureExercise(
    name: 'Chin tucks',
    steps:
        'Sit tall and gently pull your chin straight back, making a slight double chin. '
        'Hold for 2 seconds, then release slowly. '
        'Keep your eyes level and shoulders relaxed throughout.',
    seconds: 30,
  ),
  PostureExercise(
    name: 'Shoulder blade squeeze',
    steps:
        'Sit or stand with arms at your sides. '
        'Draw your shoulder blades together as if you were trying to hold a pencil between them. '
        'Hold for 3 seconds, then slowly release and repeat.',
    seconds: 30,
  ),
  PostureExercise(
    name: 'Wall angels',
    steps:
        'Stand with your back against a wall, feet a few inches from the base. '
        'Press your lower back, upper back, and head to the wall, then slide your arms up and down like a snow angel. '
        'Move slowly and keep contact with the wall throughout.',
    seconds: 60,
  ),
  PostureExercise(
    name: 'Doorway chest stretch',
    steps:
        'Stand in a doorway and place your forearms on the door frame, elbows at shoulder height. '
        'Lean forward gently until you feel a mild stretch across your chest. '
        'Breathe steadily and hold, then step back to release.',
    seconds: 30,
  ),
  PostureExercise(
    name: 'Upper trap stretch',
    steps:
        'Sit or stand tall and tilt your right ear toward your right shoulder. '
        'Place your right hand lightly on your head for a gentle added stretch — never pull. '
        'Hold, then repeat on the other side.',
    seconds: 30,
  ),
  PostureExercise(
    name: 'Cat-cow',
    steps:
        'Get on your hands and knees with a neutral spine. '
        'Inhale as you drop your belly and lift your gaze (cow); exhale as you round your back toward the ceiling (cat). '
        'Move slowly and let your breath guide the rhythm.',
    seconds: 60,
  ),
];
