// Строки фичи «Зарядка / растяжка» (warmup_routines.dart + warmup_screen.dart).
//
// ПОКА только en + ru — остальные языки фолбэкают на en (как контент поз
// медитаций; решение пользователя — не переводить сейчас). НЕ хардкодить эти
// строки в коде: данные хранят l10n-КЛЮЧИ, UI резолвит через context.s().

const Map<String, Map<String, String>> warmupStrings = {
  // ---------------------------------------------------------------------------
  // Точка входа в Health-хабе + заголовок экрана
  // ---------------------------------------------------------------------------
  'health.warmup': {
    'en': 'Warmup & stretching',
    'ru': 'Зарядка и растяжка',
  },
  'health.warmup_subtitle': {
    'en': 'Short guided routines to wake up',
    'ru': 'Короткие гайдед-комплексы «проснуться»',
  },
  'warmup.title': {
    'en': 'Warmup & stretching',
    'ru': 'Зарядка и растяжка',
  },

  // ---------------------------------------------------------------------------
  // Рутины
  // ---------------------------------------------------------------------------
  'warmup.morning.name': {
    'en': 'Morning warmup',
    'ru': 'Утренняя зарядка',
  },
  'warmup.morning.desc': {
    'en': 'Light joint mobility and swings to wake your body up',
    'ru': 'Лёгкая суставная разминка и махи, чтобы разбудить тело',
  },
  'warmup.stretch.name': {
    'en': 'Stretching',
    'ru': 'Растяжка',
  },
  'warmup.stretch.desc': {
    'en': 'Gentle full-body stretches to loosen up',
    'ru': 'Мягкие растяжки на всё тело, чтобы размяться',
  },

  // ---------------------------------------------------------------------------
  // Плеер (UI)
  // ---------------------------------------------------------------------------
  'warmup.exercise': {
    'en': 'Exercise',
    'ru': 'Упражнение',
  },
  'warmup.start': {
    'en': 'Start',
    'ru': 'Начать',
  },
  'warmup.next': {
    'en': 'Next',
    'ru': 'Дальше',
  },
  'warmup.finish': {
    'en': 'Finish',
    'ru': 'Завершить',
  },
  'warmup.pause': {
    'en': 'Pause',
    'ru': 'Пауза',
  },
  'warmup.resume': {
    'en': 'Resume',
    'ru': 'Продолжить',
  },
  'warmup.end': {
    'en': 'End routine',
    'ru': 'Закончить',
  },
  'warmup.next_up': {
    'en': 'Next up',
    'ru': 'Далее',
  },
  'warmup.complete_title': {
    'en': 'Done!',
    'ru': 'Готово!',
  },
  'warmup.complete_body': {
    'en': "Nice — you're warmed up and ready to go.",
    'ru': 'Отлично — вы размялись и готовы к делу.',
  },

  // ---------------------------------------------------------------------------
  // Упражнения — Утренняя зарядка
  // ---------------------------------------------------------------------------
  'warmup.ex.neck_rolls.name': {
    'en': 'Neck rolls',
    'ru': 'Вращения шеи',
  },
  'warmup.ex.neck_rolls.desc': {
    'en': 'Slowly roll your head in a circle, then switch direction. Keep the movement small and easy.',
    'ru': 'Медленно вращайте головой по кругу, затем смените направление. Двигайтесь плавно и без усилия.',
  },
  'warmup.ex.shoulder_circles.name': {
    'en': 'Shoulder circles',
    'ru': 'Вращения плеч',
  },
  'warmup.ex.shoulder_circles.desc': {
    'en': 'Lift your shoulders and roll them backward in big circles, then forward.',
    'ru': 'Поднимите плечи и вращайте ими назад широкими кругами, затем вперёд.',
  },
  'warmup.ex.arm_swings.name': {
    'en': 'Arm swings',
    'ru': 'Махи руками',
  },
  'warmup.ex.arm_swings.desc': {
    'en': 'Swing both arms across your chest and back open. Stay relaxed and breathe steadily.',
    'ru': 'Скрещивайте руки перед грудью и разводите в стороны. Оставайтесь расслабленными и дышите ровно.',
  },
  'warmup.ex.torso_twists.name': {
    'en': 'Torso twists',
    'ru': 'Повороты корпуса',
  },
  'warmup.ex.torso_twists.desc': {
    'en': 'Stand with feet hip-width apart and gently rotate your torso left and right.',
    'ru': 'Встаньте, стопы на ширине таза, и плавно поворачивайте корпус влево и вправо.',
  },
  'warmup.ex.side_bends.name': {
    'en': 'Side bends',
    'ru': 'Наклоны в стороны',
  },
  'warmup.ex.side_bends.desc': {
    'en': 'Reach one arm overhead and lean to the opposite side, then switch.',
    'ru': 'Поднимите одну руку над головой и наклонитесь в противоположную сторону, затем смените.',
  },
  'warmup.ex.bodyweight_squats.name': {
    'en': 'Bodyweight squats',
    'ru': 'Приседания',
  },
  'warmup.ex.bodyweight_squats.desc': {
    'en': 'Feet shoulder-width apart, sit back and down, then stand tall. Keep your chest up.',
    'ru': 'Стопы на ширине плеч, отведите таз назад и присядьте, затем встаньте. Держите грудь раскрытой.',
  },
  'warmup.ex.jumping_jacks.name': {
    'en': 'Jumping jacks',
    'ru': 'Прыжки «звёздочка»',
  },
  'warmup.ex.jumping_jacks.desc': {
    'en': 'Jump your feet wide while raising your arms overhead, then back. Find a steady rhythm.',
    'ru': 'Прыжком расставьте ноги и поднимите руки над головой, затем обратно. Держите ровный ритм.',
  },

  // ---------------------------------------------------------------------------
  // Упражнения — Растяжка
  // ---------------------------------------------------------------------------
  'warmup.ex.neck_stretch.name': {
    'en': 'Neck stretch',
    'ru': 'Растяжка шеи',
  },
  'warmup.ex.neck_stretch.desc': {
    'en': 'Tilt your right ear toward your right shoulder and hold, then switch sides. Never pull hard.',
    'ru': 'Наклоните правое ухо к правому плечу и удерживайте, затем смените сторону. Не тяните резко.',
  },
  'warmup.ex.shoulder_stretch.name': {
    'en': 'Shoulder stretch',
    'ru': 'Растяжка плеч',
  },
  'warmup.ex.shoulder_stretch.desc': {
    'en': 'Bring one arm across your chest and hug it closer with the other. Hold, then switch.',
    'ru': 'Заведите одну руку перед грудью и мягко прижмите её другой рукой. Удерживайте, затем смените.',
  },
  'warmup.ex.triceps_stretch.name': {
    'en': 'Triceps stretch',
    'ru': 'Растяжка трицепса',
  },
  'warmup.ex.triceps_stretch.desc': {
    'en': 'Raise one arm, bend the elbow behind your head, and ease it with the other hand. Switch sides.',
    'ru': 'Поднимите одну руку, согните локоть за головой и мягко помогите другой рукой. Смените сторону.',
  },
  'warmup.ex.forward_fold.name': {
    'en': 'Standing forward fold',
    'ru': 'Наклон вперёд стоя',
  },
  'warmup.ex.forward_fold.desc': {
    'en': 'Hinge at your hips and let your upper body hang down with soft knees. Relax your neck.',
    'ru': 'Согнитесь в тазобедренных суставах и свесьте корпус вниз, колени мягкие. Расслабьте шею.',
  },
  'warmup.ex.quad_stretch.name': {
    'en': 'Quad stretch',
    'ru': 'Растяжка квадрицепса',
  },
  'warmup.ex.quad_stretch.desc': {
    'en': 'Stand tall, pull one heel toward your glutes, and hold. Use a wall for balance, then switch.',
    'ru': 'Стоя ровно, подтяните одну пятку к ягодице и удерживайте. Опирайтесь о стену, затем смените.',
  },
  'warmup.ex.hamstring_stretch.name': {
    'en': 'Hamstring stretch',
    'ru': 'Растяжка задней поверхности бедра',
  },
  'warmup.ex.hamstring_stretch.desc': {
    'en': 'Place one heel forward, hinge at the hips, and reach toward your toes. Keep your back long.',
    'ru': 'Выставьте одну пятку вперёд, наклонитесь от таза и тянитесь к носку. Держите спину прямой.',
  },
  'warmup.ex.cat_cow_stretch.name': {
    'en': 'Cat-cow stretch',
    'ru': 'Растяжка «кошка-корова»',
  },
  'warmup.ex.cat_cow_stretch.desc': {
    'en': 'On hands and knees, arch and round your back with your breath. Move slowly through the spine.',
    'ru': 'На четвереньках прогибайте и округляйте спину в такт дыханию. Двигайтесь медленно вдоль позвоночника.',
  },
};
