// Строки каталога упражнений (exercise_library.dart).
// Шаги техники и типичные ошибки для каждого упражнения.
//
// Формат ключей:
//   exercise.<id>.step1 / step2 / ...  — шаги техники
//   exercise.<id>.mistake1 / ...       — типичные ошибки
//
// Имена упражнений (exercise.<id>) живут в health_b.dart и сюда НЕ дублируются.
//
// Обязательные локали: en + ru. Прочие (de/fr/it/pt/es/id/hi/ja/ko) — fallback на en.
const Map<String, Map<String, String>> workoutsLibraryStrings = {
  // ---------------------------------------------------------------------------
  // barbell_back_squat — Приседания со штангой
  // ---------------------------------------------------------------------------
  'exercise.barbell_back_squat.step1': {
    'en': 'Stand with the bar resting across your upper traps, feet shoulder-width apart and toes slightly out.',
    'ru': 'Встаньте со штангой на верхних трапециях, ноги на ширине плеч, носки немного в стороны.',
  },
  'exercise.barbell_back_squat.step2': {
    'en': 'Take a deep breath, brace your core, and push your hips back as you descend — keep your chest up throughout.',
    'ru': 'Сделайте вдох, напрягите кор, отведите бёдра назад при опускании — грудь держите вверх.',
  },
  'exercise.barbell_back_squat.step3': {
    'en': 'Squat until your thighs are at least parallel to the floor (or deeper if mobility allows).',
    'ru': 'Приседайте до параллели бёдер с полом (или глубже, если позволяет подвижность).',
  },
  'exercise.barbell_back_squat.step4': {
    'en': 'Drive through your heels to stand up, exhale at the top.',
    'ru': 'Давите пятками в пол при подъёме, выдыхайте наверху.',
  },
  'exercise.barbell_back_squat.mistake1': {
    'en': 'Knees caving inward — push your knees out in line with your toes.',
    'ru': 'Колени заваливаются внутрь — давите коленями наружу по линии носков.',
  },
  'exercise.barbell_back_squat.mistake2': {
    'en': 'Heels rising — improve ankle mobility or use a small heel elevation.',
    'ru': 'Пятки отрываются от пола — улучшайте подвижность голеностопа или используйте небольшой подъём под пятки.',
  },

  // ---------------------------------------------------------------------------
  // bodyweight_squat — Приседания без отягощения
  // ---------------------------------------------------------------------------
  'exercise.bodyweight_squat.step1': {
    'en': 'Stand with feet shoulder-width apart, arms extended forward for balance.',
    'ru': 'Встаньте, ноги на ширине плеч, руки вытяните вперёд для баланса.',
  },
  'exercise.bodyweight_squat.step2': {
    'en': 'Push your hips back and bend your knees, lowering until thighs are parallel to the floor.',
    'ru': 'Отведите бёдра назад и согните колени, опускаясь до параллели бёдер с полом.',
  },
  'exercise.bodyweight_squat.step3': {
    'en': 'Press through your heels to return to standing, keeping your back straight throughout.',
    'ru': 'Давите пятками при подъёме, держите спину прямой на протяжении всего движения.',
  },
  'exercise.bodyweight_squat.mistake1': {
    'en': 'Rounding the lower back — keep a neutral spine and engage your core.',
    'ru': 'Скругление поясницы — держите нейтральный изгиб позвоночника и напрягайте кор.',
  },

  // ---------------------------------------------------------------------------
  // barbell_deadlift — Становая тяга
  // ---------------------------------------------------------------------------
  'exercise.barbell_deadlift.step1': {
    'en': 'Stand with the bar over your mid-foot, feet hip-width apart, grip just outside your legs.',
    'ru': 'Встаньте так, чтобы гриф проходил над серединой стопы, ноги на ширине бёдер, хват снаружи ног.',
  },
  'exercise.barbell_deadlift.step2': {
    'en': 'Hinge at the hips, flatten your back, and take a big breath — brace your core like you\'re about to be punched.',
    'ru': 'Согнитесь в тазобедренном суставе, выпрямите спину, сделайте глубокий вдох и создайте внутрибрюшное давление.',
  },
  'exercise.barbell_deadlift.step3': {
    'en': 'Push the floor away through your heels — the bar stays close to your body as you rise.',
    'ru': 'Давите ногами в пол — гриф скользит вдоль ног при подъёме.',
  },
  'exercise.barbell_deadlift.step4': {
    'en': 'Lock out hips and knees at the top, then hinge back down with control.',
    'ru': 'Полностью выпрямите тазобедренный и коленный суставы наверху, затем опустите штангу с контролем.',
  },
  'exercise.barbell_deadlift.mistake1': {
    'en': 'Rounding the lower back — prioritize a neutral spine before adding weight.',
    'ru': 'Скругление поясницы — отработайте нейтральный позвоночник до увеличения веса.',
  },
  'exercise.barbell_deadlift.mistake2': {
    'en': 'Bar drifting away from the body — keep it in contact with your shins.',
    'ru': 'Гриф уходит от тела — держите его прижатым к голеням на протяжении всего подъёма.',
  },

  // ---------------------------------------------------------------------------
  // glute_bridge — Ягодичный мостик
  // ---------------------------------------------------------------------------
  'exercise.glute_bridge.step1': {
    'en': 'Lie on your back with knees bent, feet flat on the floor hip-width apart.',
    'ru': 'Лягте на спину, согните колени, стопы на полу на ширине бёдер.',
  },
  'exercise.glute_bridge.step2': {
    'en': 'Squeeze your glutes and push through your heels to raise your hips until your body forms a straight line from shoulders to knees.',
    'ru': 'Напрягите ягодицы, давите пятками в пол и поднимите таз так, чтобы тело образовало прямую линию от плеч до колен.',
  },
  'exercise.glute_bridge.step3': {
    'en': 'Hold at the top for 1–2 seconds, then lower slowly back to the start.',
    'ru': 'Удерживайте верхнюю точку 1–2 секунды, затем медленно опустите таз.',
  },
  'exercise.glute_bridge.mistake1': {
    'en': 'Hyperextending the lower back at the top — stop when hips are in line with your torso.',
    'ru': 'Переразгибание поясницы в верхней точке — останавливайтесь, когда таз выровнялся с корпусом.',
  },

  // ---------------------------------------------------------------------------
  // push_up — Отжимания
  // ---------------------------------------------------------------------------
  'exercise.push_up.step1': {
    'en': 'Start in a high plank: hands slightly wider than shoulder-width, body in a straight line from head to heels.',
    'ru': 'Примите упор лёжа: руки чуть шире плеч, тело — прямая линия от головы до пяток.',
  },
  'exercise.push_up.step2': {
    'en': 'Lower your chest to the floor by bending your elbows at roughly 45° to your torso.',
    'ru': 'Опускайте грудь к полу, сгибая локти примерно под 45° к корпусу.',
  },
  'exercise.push_up.step3': {
    'en': 'Push through your palms to return to the top, exhaling as you rise.',
    'ru': 'Выжмите себя ладонями обратно в упор, выдыхая при подъёме.',
  },
  'exercise.push_up.mistake1': {
    'en': 'Hips sagging or piking — keep your core tight and body straight throughout.',
    'ru': 'Провисание или подъём таза — держите кор в напряжении, тело должно оставаться прямым.',
  },
  'exercise.push_up.mistake2': {
    'en': 'Flaring elbows wide — keep them at ~45° to protect your shoulders.',
    'ru': 'Локти уходят в стороны — держите угол ~45° для защиты плечевых суставов.',
  },

  // ---------------------------------------------------------------------------
  // barbell_bench_press — Жим штанги лёжа
  // ---------------------------------------------------------------------------
  'exercise.barbell_bench_press.step1': {
    'en': 'Lie on the bench with eyes under the bar, feet flat on the floor and shoulder blades retracted.',
    'ru': 'Лягте на скамью так, чтобы глаза были под грифом; стопы на полу, лопатки сведены.',
  },
  'exercise.barbell_bench_press.step2': {
    'en': 'Grip the bar slightly wider than shoulder-width, unrack with straight arms and bring it over your lower chest.',
    'ru': 'Возьмите гриф чуть шире плеч, снимите со стоек на прямых руках и опустите над нижней частью груди.',
  },
  'exercise.barbell_bench_press.step3': {
    'en': 'Lower the bar under control until it touches your chest — don\'t bounce.',
    'ru': 'Медленно опустите гриф до касания грудью — не отбивайте от груди.',
  },
  'exercise.barbell_bench_press.step4': {
    'en': 'Press the bar back up in a slight arc, exhaling as you lock out.',
    'ru': 'Выжмите гриф по дуге вверх, выдыхая при полном выпрямлении рук.',
  },
  'exercise.barbell_bench_press.mistake1': {
    'en': 'Bouncing the bar off the chest — touch lightly and press with control.',
    'ru': 'Отбив штанги от груди — касайтесь слегка и выжимайте с контролем.',
  },
  'exercise.barbell_bench_press.mistake2': {
    'en': 'Feet raised off the floor — keep them flat for a stable base.',
    'ru': 'Ноги висят в воздухе — держите стопы на полу для устойчивости.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_bench_press — Жим гантелей лёжа
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_bench_press.step1': {
    'en': 'Lie on the bench holding a dumbbell in each hand at chest level, palms facing forward.',
    'ru': 'Лягте на скамью с гантелями у груди, ладони смотрят вперёд.',
  },
  'exercise.dumbbell_bench_press.step2': {
    'en': 'Press both dumbbells up until your arms are fully extended, bringing them slightly together at the top.',
    'ru': 'Выжмите гантели вверх до полного разгибания рук, слегка сближая их наверху.',
  },
  'exercise.dumbbell_bench_press.step3': {
    'en': 'Lower slowly back to the starting position, feeling the stretch across your chest.',
    'ru': 'Медленно опустите обратно в исходное положение, ощущая растяжку грудных мышц.',
  },
  'exercise.dumbbell_bench_press.mistake1': {
    'en': 'Uneven range of motion — lower both dumbbells symmetrically to the same depth.',
    'ru': 'Несимметричная амплитуда — опускайте обе гантели до одинаковой глубины.',
  },

  // ---------------------------------------------------------------------------
  // overhead_barbell_press — Жим штанги стоя
  // ---------------------------------------------------------------------------
  'exercise.overhead_barbell_press.step1': {
    'en': 'Stand with the bar at collarbone height, grip slightly wider than shoulders, elbows just in front of the bar.',
    'ru': 'Встаньте со штангой на уровне ключиц, хват чуть шире плеч, локти немного перед грифом.',
  },
  'exercise.overhead_barbell_press.step2': {
    'en': 'Press the bar straight up, moving your head slightly back to clear it, then push your head forward as the bar passes.',
    'ru': 'Жмите гриф прямо вверх, слегка отводя голову назад для его прохождения, затем возвращая голову вперёд.',
  },
  'exercise.overhead_barbell_press.step3': {
    'en': 'Lock out your arms overhead with the bar directly above your heels; lower back to the start under control.',
    'ru': 'Выпрямите руки так, чтобы гриф был прямо над пятками; опустите с контролем в исходное положение.',
  },
  'exercise.overhead_barbell_press.mistake1': {
    'en': 'Arching the lower back excessively — engage your glutes and core to keep a neutral spine.',
    'ru': 'Чрезмерный прогиб поясницы — напрягите ягодицы и кор для нейтрального положения позвоночника.',
  },
  'exercise.overhead_barbell_press.mistake2': {
    'en': 'Bar path too far forward — keep it close to your face and press vertically.',
    'ru': 'Гриф уходит слишком далеко вперёд — жмите по вертикали, близко к лицу.',
  },

  // ---------------------------------------------------------------------------
  // barbell_row — Тяга штанги в наклоне
  // ---------------------------------------------------------------------------
  'exercise.barbell_row.step1': {
    'en': 'Stand with feet hip-width apart, hinge forward 45–60°, and grip the bar just outside your legs.',
    'ru': 'Ноги на ширине бёдер, наклонитесь на 45–60°, возьмите гриф чуть шире ног.',
  },
  'exercise.barbell_row.step2': {
    'en': 'Keep your back flat and core braced throughout the movement.',
    'ru': 'Держите спину прямой и кор в напряжении на протяжении всего упражнения.',
  },
  'exercise.barbell_row.step3': {
    'en': 'Pull the bar into your lower abdomen, driving your elbows back and squeezing your shoulder blades.',
    'ru': 'Тяните гриф к нижней части живота, отводя локти назад и сводя лопатки.',
  },
  'exercise.barbell_row.step4': {
    'en': 'Lower the bar slowly back to the hanging position.',
    'ru': 'Медленно опустите гриф в исходное положение.',
  },
  'exercise.barbell_row.mistake1': {
    'en': 'Using momentum to swing the bar up — reduce weight and focus on back contraction.',
    'ru': 'Читинг — подбрасывание грифа рывком: снизьте вес и сосредоточьтесь на сокращении спины.',
  },
  'exercise.barbell_row.mistake2': {
    'en': 'Pulling to the upper chest — aim for the lower abdomen to target lats.',
    'ru': 'Тяга к верхней части груди — тяните к нижней части живота для прокачки широчайших.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_row — Тяга гантели в наклоне
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_row.step1': {
    'en': 'Place your knee and hand on a bench, hold a dumbbell with your free arm hanging straight down.',
    'ru': 'Упритесь коленом и рукой в скамью, держите гантель свободной рукой — она висит вертикально.',
  },
  'exercise.dumbbell_row.step2': {
    'en': 'Pull the dumbbell toward your hip, keeping your elbow close to your body.',
    'ru': 'Тяните гантель к бедру, держа локоть близко к телу.',
  },
  'exercise.dumbbell_row.step3': {
    'en': 'Lower slowly to full extension, feeling the stretch in your lat.',
    'ru': 'Медленно опустите до полного разгибания, ощущая растяжку широчайшей.',
  },
  'exercise.dumbbell_row.mistake1': {
    'en': 'Rotating the torso to swing the weight — keep your hips square and use only your arm and back.',
    'ru': 'Разворот корпуса для инерции — держите таз ровно и работайте только рукой и спиной.',
  },

  // ---------------------------------------------------------------------------
  // pull_up — Подтягивания
  // ---------------------------------------------------------------------------
  'exercise.pull_up.step1': {
    'en': 'Hang from the bar with hands slightly wider than shoulder-width, palms facing away (pronated grip).',
    'ru': 'Возьмитесь за перекладину чуть шире плеч прямым хватом (пронация).',
  },
  'exercise.pull_up.step2': {
    'en': 'Engage your lats by pulling your shoulder blades down and back, then pull yourself up until your chin clears the bar.',
    'ru': 'Активируйте широчайшие: потяните лопатки вниз и назад, затем подтягивайтесь до касания подбородком перекладины.',
  },
  'exercise.pull_up.step3': {
    'en': 'Lower yourself slowly to a full hang — resist the urge to drop quickly.',
    'ru': 'Медленно опускайтесь в вис — не бросайте себя вниз.',
  },
  'exercise.pull_up.mistake1': {
    'en': 'Kipping or swinging for momentum — use strict form to build real strength.',
    'ru': 'Инерционные рывки ногами — работайте строго, без рывков.',
  },
  'exercise.pull_up.mistake2': {
    'en': 'Partial range of motion — start from a dead hang and go all the way up each rep.',
    'ru': 'Неполная амплитуда — начинайте из полного виса и поднимайтесь до касания каждый раз.',
  },

  // ---------------------------------------------------------------------------
  // plank — Планка
  // ---------------------------------------------------------------------------
  'exercise.plank.step1': {
    'en': 'Place forearms on the floor with elbows under your shoulders; extend your legs behind you.',
    'ru': 'Упритесь предплечьями в пол, локти под плечами; вытяните ноги назад.',
  },
  'exercise.plank.step2': {
    'en': 'Lift your hips so your body forms a straight line from head to heels — squeeze your glutes and core.',
    'ru': 'Поднимите таз так, чтобы тело образовало прямую линию — напрягите ягодицы и кор.',
  },
  'exercise.plank.step3': {
    'en': 'Hold the position, breathing steadily, without letting your hips sag or rise.',
    'ru': 'Удерживайте позицию, ровно дышите, не давая тазу провисать или подниматься.',
  },
  'exercise.plank.mistake1': {
    'en': 'Hips too high (piking) — lower them until your spine is neutral.',
    'ru': 'Таз поднят слишком высоко — опустите до нейтрального положения позвоночника.',
  },
  'exercise.plank.mistake2': {
    'en': 'Holding your breath — breathe steadily throughout the hold.',
    'ru': 'Задержка дыхания — дышите ровно на протяжении всего удержания.',
  },

  // ---------------------------------------------------------------------------
  // russian_twist — Русский твист
  // ---------------------------------------------------------------------------
  'exercise.russian_twist.step1': {
    'en': 'Sit on the floor with knees bent and feet raised slightly; lean back ~45° to engage your core.',
    'ru': 'Сядьте на пол, согните колени, приподнимите стопы; отклонитесь назад ~45° для нагрузки кора.',
  },
  'exercise.russian_twist.step2': {
    'en': 'Clasp your hands together and rotate your torso from side to side, touching the floor beside each hip.',
    'ru': 'Сложите руки вместе и поворачивайте корпус из стороны в сторону, касаясь пола у каждого бедра.',
  },
  'exercise.russian_twist.step3': {
    'en': 'Keep your back straight and move in a controlled arc — don\'t rush.',
    'ru': 'Держите спину прямой и двигайтесь по контролируемой дуге — не торопитесь.',
  },
  'exercise.russian_twist.mistake1': {
    'en': 'Rounding the lower back — sit taller and reduce the lean-back angle.',
    'ru': 'Скругление поясницы — сидите прямее и уменьшите угол отклонения назад.',
  },

  // ---------------------------------------------------------------------------
  // jumping_jack — Прыжки «звёздочка»
  // ---------------------------------------------------------------------------
  'exercise.jumping_jack.step1': {
    'en': 'Stand upright with feet together and arms at your sides.',
    'ru': 'Встаньте прямо, ноги вместе, руки вдоль тела.',
  },
  'exercise.jumping_jack.step2': {
    'en': 'Jump and simultaneously spread your feet to shoulder width while raising your arms overhead; jump back to start.',
    'ru': 'Прыгните, одновременно разводя ноги на ширину плеч и поднимая руки над головой; прыгните обратно.',
  },

  // ---------------------------------------------------------------------------
  // burpee — Бёрпи
  // ---------------------------------------------------------------------------
  'exercise.burpee.step1': {
    'en': 'Start standing, then squat down and place your hands on the floor.',
    'ru': 'Из стойки присядьте и поставьте ладони на пол.',
  },
  'exercise.burpee.step2': {
    'en': 'Jump your feet back into a high-plank position and perform one push-up.',
    'ru': 'Прыжком отбросьте ноги назад в упор лёжа и сделайте одно отжимание.',
  },
  'exercise.burpee.step3': {
    'en': 'Jump your feet back to your hands and explode upward, reaching arms overhead.',
    'ru': 'Прыжком подтяните ноги к рукам и мощно выпрыгните вверх, вытянув руки над головой.',
  },
  'exercise.burpee.step4': {
    'en': 'Land softly and immediately begin the next rep.',
    'ru': 'Приземлитесь мягко и сразу начинайте следующее повторение.',
  },
  'exercise.burpee.mistake1': {
    'en': 'Skipping the push-up — do a full push-up each rep for the full-body benefit.',
    'ru': 'Пропуск отжимания — выполняйте полное отжимание каждый раз для полноценной нагрузки.',
  },
};
