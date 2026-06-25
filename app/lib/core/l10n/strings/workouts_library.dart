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
    'de': 'Stehe mit der Stange auf den oberen Trapezius-Muskeln, Füße schulterbreit, Zehen leicht auswärts.',
    'fr': 'Placez la barre sur les trapèzes supérieurs, pieds écartés à la largeur des épaules, orteils légèrement ouverts.',
    'it': 'Posiziona il bilanciere sui trapezi superiori, piedi alla larghezza delle spalle, punte leggermente verso l\'esterno.',
    'pt': 'Fique em pé com a barra apoiada nos trapézios superiores, pés na largura dos ombros e dedos levemente apontados para fora.',
    'es': 'Párate con la barra apoyada en los trapecios superiores, pies al ancho de los hombros y puntas ligeramente hacia afuera.',
    'id': 'Berdiri dengan bar bertumpu di trapezius atas, kaki selebar bahu dan jari kaki sedikit mengarah ke luar.',
  },
  'exercise.barbell_back_squat.step2': {
    'en': 'Take a deep breath, brace your core, and push your hips back as you descend — keep your chest up throughout.',
    'ru': 'Сделайте вдох, напрягите кор, отведите бёдра назад при опускании — грудь держите вверх.',
    'de': 'Tief einatmen, Core anspannen, Hüfte nach hinten schieben beim Absenken — Brust stets aufrecht halten.',
    'fr': 'Inspirez profondément, gainéz le tronc, reculez les hanches en descendant — gardez la poitrine haute tout au long.',
    'it': 'Inspira profondamente, contrai il core, spingi i fianchi indietro mentre scendi — mantieni il petto alto per tutto il movimento.',
    'pt': 'Inspire fundo, contraia o core e empurre os quadris para trás ao descer — mantenha o peito erguido durante todo o movimento.',
    'es': 'Inspira profundo, activa el core y empuja las caderas hacia atrás al bajar — mantén el pecho erguido en todo momento.',
    'id': 'Tarik napas dalam, kencangkan core, dan dorong pinggul ke belakang saat turun — jaga dada tetap tegak sepanjang gerakan.',
  },
  'exercise.barbell_back_squat.step3': {
    'en': 'Squat until your thighs are at least parallel to the floor (or deeper if mobility allows).',
    'ru': 'Приседайте до параллели бёдер с полом (или глубже, если позволяет подвижность).',
    'de': 'Squatte bis die Oberschenkel mindestens parallel zum Boden sind (tiefer, wenn die Mobilität es erlaubt).',
    'fr': 'Descendez jusqu\'à ce que les cuisses soient au moins parallèles au sol (ou plus bas si la mobilité le permet).',
    'it': 'Scendi finché le cosce sono almeno parallele al pavimento (o più in basso se la mobilità lo consente).',
    'pt': 'Agache até que as coxas fiquem pelo menos paralelas ao chão (ou mais fundo se a mobilidade permitir).',
    'es': 'Agáchate hasta que los muslos queden al menos paralelos al suelo (o más profundo si la movilidad lo permite).',
    'id': 'Jongkok hingga paha setidaknya sejajar dengan lantai (atau lebih dalam jika mobilitas memungkinkan).',
  },
  'exercise.barbell_back_squat.step4': {
    'en': 'Drive through your heels to stand up, exhale at the top.',
    'ru': 'Давите пятками в пол при подъёме, выдыхайте наверху.',
    'de': 'Drücke durch die Fersen hoch, oben ausatmen.',
    'fr': 'Poussez à travers les talons pour vous relever, expirez en haut.',
    'it': 'Spingi attraverso i talloni per risalire, espira in cima.',
    'pt': 'Empurre pelos calcanhares para se levantar, expire no topo.',
    'es': 'Empuja a través de los talones para levantarte, exhala en la parte superior.',
    'id': 'Dorong melalui tumit untuk berdiri, hembuskan napas di posisi atas.',
  },
  'exercise.barbell_back_squat.mistake1': {
    'en': 'Knees caving inward — push your knees out in line with your toes.',
    'ru': 'Колени заваливаются внутрь — давите коленями наружу по линии носков.',
    'de': 'Knie fallen nach innen — drücke sie in Richtung der Zehen nach außen.',
    'fr': 'Genoux qui rentrent vers l\'intérieur — poussez-les vers l\'extérieur dans l\'axe des orteils.',
    'it': 'Ginocchia che cedono verso l\'interno — spingi le ginocchia verso l\'esterno in linea con le punte.',
    'pt': 'Joelhos cedendo para dentro — empurre os joelhos para fora alinhados com os dedos dos pés.',
    'es': 'Rodillas colapsando hacia adentro — empuja las rodillas hacia afuera alineadas con los dedos de los pies.',
    'id': 'Lutut roboh ke dalam — dorong lutut ke luar sejajar dengan jari kaki.',
  },
  'exercise.barbell_back_squat.mistake2': {
    'en': 'Heels rising — improve ankle mobility or use a small heel elevation.',
    'ru': 'Пятки отрываются от пола — улучшайте подвижность голеностопа или используйте небольшой подъём под пятки.',
    'de': 'Fersen heben sich — Sprunggelenk-Mobilität verbessern oder eine leichte Fersenerhöhung verwenden.',
    'fr': 'Talons qui se soulèvent — améliorez la mobilité de la cheville ou utilisez une légère élévation sous les talons.',
    'it': 'I talloni si sollevano — migliora la mobilità della caviglia o usa una piccola elevazione sotto i talloni.',
    'pt': 'Calcanhares se levantando — melhore a mobilidade do tornozelo ou use uma pequena elevação sob os calcanhares.',
    'es': 'Talones que se levantan — mejora la movilidad del tobillo o usa una pequeña elevación bajo los talones.',
    'id': 'Tumit terangkat — tingkatkan mobilitas pergelangan kaki atau gunakan elevasi kecil di bawah tumit.',
  },

  // ---------------------------------------------------------------------------
  // bodyweight_squat — Приседания без отягощения
  // ---------------------------------------------------------------------------
  'exercise.bodyweight_squat.step1': {
    'en': 'Stand with feet shoulder-width apart, arms extended forward for balance.',
    'ru': 'Встаньте, ноги на ширине плеч, руки вытяните вперёд для баланса.',
    'de': 'Stehe schulterbreit, Arme zur Balance nach vorne gestreckt.',
    'fr': 'Tenez-vous debout, pieds écartés à la largeur des épaules, bras tendus devant pour l\'équilibre.',
    'it': 'Stai in piedi con i piedi alla larghezza delle spalle, braccia tese in avanti per l\'equilibrio.',
    'pt': 'Fique em pé com os pés na largura dos ombros, braços estendidos à frente para equilíbrio.',
    'es': 'Párate con los pies al ancho de los hombros, brazos extendidos al frente para equilibrio.',
    'id': 'Berdiri dengan kaki selebar bahu, lengan terentang ke depan untuk keseimbangan.',
  },
  'exercise.bodyweight_squat.step2': {
    'en': 'Push your hips back and bend your knees, lowering until thighs are parallel to the floor.',
    'ru': 'Отведите бёдра назад и согните колени, опускаясь до параллели бёдер с полом.',
    'de': 'Hüfte nach hinten schieben und Knie beugen, bis die Oberschenkel parallel zum Boden sind.',
    'fr': 'Reculez les hanches et fléchissez les genoux jusqu\'à ce que les cuisses soient parallèles au sol.',
    'it': 'Spingi i fianchi indietro e piega le ginocchia scendendo fino a che le cosce siano parallele al pavimento.',
    'pt': 'Empurre os quadris para trás e dobre os joelhos, descendo até as coxas ficarem paralelas ao chão.',
    'es': 'Empuja las caderas hacia atrás y dobla las rodillas, bajando hasta que los muslos queden paralelos al suelo.',
    'id': 'Dorong pinggul ke belakang dan tekuk lutut, turun hingga paha sejajar dengan lantai.',
  },
  'exercise.bodyweight_squat.step3': {
    'en': 'Press through your heels to return to standing, keeping your back straight throughout.',
    'ru': 'Давите пятками при подъёме, держите спину прямой на протяжении всего движения.',
    'de': 'Durch die Fersen hochdrücken und den Rücken während der gesamten Bewegung gerade halten.',
    'fr': 'Poussez à travers les talons pour revenir debout en gardant le dos droit tout au long du mouvement.',
    'it': 'Spingi attraverso i talloni per tornare in piedi, mantenendo la schiena dritta per tutto il movimento.',
    'pt': 'Pressione pelos calcanhares para voltar à posição em pé, mantendo as costas retas durante todo o movimento.',
    'es': 'Presiona a través de los talones para volver a pararte, manteniendo la espalda recta durante todo el movimiento.',
    'id': 'Tekan melalui tumit untuk kembali berdiri, jaga punggung tetap lurus sepanjang gerakan.',
  },
  'exercise.bodyweight_squat.mistake1': {
    'en': 'Rounding the lower back — keep a neutral spine and engage your core.',
    'ru': 'Скругление поясницы — держите нейтральный изгиб позвоночника и напрягайте кор.',
    'de': 'Rundrücken im Lendenwirbelbereich — neutrale Wirbelsäule halten und Core aktivieren.',
    'fr': 'Dos lombaire arrondi — gardez une colonne vertébrale neutre et contractez le gainage.',
    'it': 'Schiena lombare arrotondata — mantieni la colonna vertebrale neutra e contrai il core.',
    'pt': 'Curvatura da lombar — mantenha a coluna neutra e contraia o core.',
    'es': 'Redondear la zona lumbar — mantén la columna neutra y activa el core.',
    'id': 'Punggung bawah membulat — jaga tulang belakang netral dan kencangkan core.',
  },

  // ---------------------------------------------------------------------------
  // barbell_deadlift — Становая тяга
  // ---------------------------------------------------------------------------
  'exercise.barbell_deadlift.step1': {
    'en': 'Stand with the bar over your mid-foot, feet hip-width apart, grip just outside your legs.',
    'ru': 'Встаньте так, чтобы гриф проходил над серединой стопы, ноги на ширине бёдер, хват снаружи ног.',
    'de': 'Stehe so, dass die Stange über der Mitte des Fußes liegt, Füße hüftbreit, Griff knapp außerhalb der Beine.',
    'fr': 'Placez-vous avec la barre au-dessus du milieu du pied, pieds écartés à la largeur des hanches, prise juste à l\'extérieur des jambes.',
    'it': 'Posizionati con il bilanciere sopra il centro del piede, piedi alla larghezza dei fianchi, presa appena fuori dalle gambe.',
    'pt': 'Fique em pé com a barra sobre o meio do pé, pés na largura dos quadris, pegada logo fora das pernas.',
    'es': 'Párate con la barra sobre la mitad del pie, pies al ancho de las caderas, agarre justo fuera de las piernas.',
    'id': 'Berdiri dengan bar di atas bagian tengah kaki, kaki selebar pinggul, pegangan tepat di luar kaki.',
  },
  'exercise.barbell_deadlift.step2': {
    'en': 'Hinge at the hips, flatten your back, and take a big breath — brace your core like you\'re about to be punched.',
    'ru': 'Согнитесь в тазобедренном суставе, выпрямите спину, сделайте глубокий вдох и создайте внутрибрюшное давление.',
    'de': 'Aus der Hüfte beugen, Rücken abflachen, tief einatmen — Core anspannen wie vor einem Schlag in den Bauch.',
    'fr': 'Charnière aux hanches, dos plat, grande inspiration — gainéz le tronc comme si vous alliez recevoir un coup.',
    'it': 'Cerniera sui fianchi, schiena piatta, respiro profondo — contrai il core come se stessi per ricevere un pugno.',
    'pt': 'Articule nos quadris, achate as costas e inspire fundo — contraia o core como se fosse levar um soco.',
    'es': 'Bisagra en las caderas, espalda plana e inspira profundo — activa el core como si fueras a recibir un golpe.',
    'id': 'Engsel di pinggul, ratakan punggung, dan tarik napas besar — kencangkan core seperti akan dipukul.',
  },
  'exercise.barbell_deadlift.step3': {
    'en': 'Push the floor away through your heels — the bar stays close to your body as you rise.',
    'ru': 'Давите ногами в пол — гриф скользит вдоль ног при подъёме.',
    'de': 'Durch die Fersen den Boden wegdrücken — die Stange bleibt beim Hochgehen nah am Körper.',
    'fr': 'Repoussez le sol à travers les talons — la barre reste proche du corps en montant.',
    'it': 'Spingi il pavimento attraverso i talloni — il bilanciere rimane vicino al corpo durante la salita.',
    'pt': 'Empurre o chão pelos calcanhares — a barra fica próxima ao corpo enquanto você sobe.',
    'es': 'Empuja el suelo a través de los talones — la barra permanece cerca del cuerpo al subir.',
    'id': 'Dorong lantai melalui tumit — bar tetap dekat dengan tubuh saat Anda naik.',
  },
  'exercise.barbell_deadlift.step4': {
    'en': 'Lock out hips and knees at the top, then hinge back down with control.',
    'ru': 'Полностью выпрямите тазобедренный и коленный суставы наверху, затем опустите штангу с контролем.',
    'de': 'Hüfte und Knie oben vollständig strecken, dann kontrolliert wieder hinunterbeugen.',
    'fr': 'Verrouillez hanches et genoux en haut, puis redescendez en contrôle avec charnière.',
    'it': 'Blocca fianchi e ginocchia in cima, poi ridiscendi controllando la cerniera.',
    'pt': 'Trave quadris e joelhos no topo, depois articule de volta para baixo com controle.',
    'es': 'Bloquea caderas y rodillas arriba, luego articula de vuelta hacia abajo con control.',
    'id': 'Kunci pinggul dan lutut di atas, lalu engsel kembali ke bawah dengan terkontrol.',
  },
  'exercise.barbell_deadlift.mistake1': {
    'en': 'Rounding the lower back — prioritize a neutral spine before adding weight.',
    'ru': 'Скругление поясницы — отработайте нейтральный позвоночник до увеличения веса.',
    'de': 'Rundrücken im Lendenwirbelbereich — neutrale Wirbelsäule priorisieren, bevor Gewicht erhöht wird.',
    'fr': 'Dos lombaire arrondi — maîtrisez une colonne neutre avant d\'augmenter la charge.',
    'it': 'Schiena lombare arrotondata — padroneggia la colonna neutra prima di aumentare il peso.',
    'pt': 'Curvatura da lombar — domine a coluna neutra antes de adicionar carga.',
    'es': 'Redondear la zona lumbar — domina la columna neutra antes de agregar peso.',
    'id': 'Punggung bawah membulat — kuasai tulang belakang netral sebelum menambah beban.',
  },
  'exercise.barbell_deadlift.mistake2': {
    'en': 'Bar drifting away from the body — keep it in contact with your shins.',
    'ru': 'Гриф уходит от тела — держите его прижатым к голеням на протяжении всего подъёма.',
    'de': 'Stange driftet vom Körper weg — sie muss die Schienbeine während des gesamten Zuges berühren.',
    'fr': 'La barre s\'éloigne du corps — gardez-la en contact avec les tibias tout au long de la montée.',
    'it': 'Il bilanciere si allontana dal corpo — tienilo a contatto con le tibie per tutta la salita.',
    'pt': 'Barra se afastando do corpo — mantenha-a em contato com as canelas durante toda a subida.',
    'es': 'La barra se aleja del cuerpo — mantenla en contacto con las espinillas durante toda la subida.',
    'id': 'Bar menjauh dari tubuh — jaga kontak dengan tulang kering sepanjang angkatan.',
  },

  // ---------------------------------------------------------------------------
  // glute_bridge — Ягодичный мостик
  // ---------------------------------------------------------------------------
  'exercise.glute_bridge.step1': {
    'en': 'Lie on your back with knees bent, feet flat on the floor hip-width apart.',
    'ru': 'Лягте на спину, согните колени, стопы на полу на ширине бёдер.',
    'de': 'Auf den Rücken legen, Knie beugen, Füße hüftbreit flach auf dem Boden.',
    'fr': 'Allongez-vous sur le dos, genoux fléchis, pieds à plat à la largeur des hanches.',
    'it': 'Sdraiati sulla schiena con le ginocchia piegate, piedi piatti sul pavimento alla larghezza dei fianchi.',
    'pt': 'Deite de costas com os joelhos dobrados, pés planos no chão na largura dos quadris.',
    'es': 'Recuéstate boca arriba con las rodillas dobladas, pies planos en el suelo al ancho de las caderas.',
    'id': 'Berbaring telentang dengan lutut ditekuk, kaki rata di lantai selebar pinggul.',
  },
  'exercise.glute_bridge.step2': {
    'en': 'Squeeze your glutes and push through your heels to raise your hips until your body forms a straight line from shoulders to knees.',
    'ru': 'Напрягите ягодицы, давите пятками в пол и поднимите таз так, чтобы тело образовало прямую линию от плеч до колен.',
    'de': 'Gesäß anspannen, durch die Fersen drücken und Hüfte heben, bis der Körper eine gerade Linie von Schultern bis Knie bildet.',
    'fr': 'Contractez les fessiers, poussez à travers les talons et soulevez les hanches jusqu\'à former une ligne droite des épaules aux genoux.',
    'it': 'Contrai i glutei, spingi attraverso i talloni e solleva i fianchi finché il corpo forma una linea retta dalle spalle alle ginocchia.',
    'pt': 'Contraia os glúteos e empurre pelos calcanhares para elevar os quadris até o corpo formar uma linha reta dos ombros aos joelhos.',
    'es': 'Aprieta los glúteos y empuja a través de los talones para elevar las caderas hasta que el cuerpo forme una línea recta de hombros a rodillas.',
    'id': 'Kencangkan glute dan dorong melalui tumit untuk mengangkat pinggul hingga tubuh membentuk garis lurus dari bahu ke lutut.',
  },
  'exercise.glute_bridge.step3': {
    'en': 'Hold at the top for 1–2 seconds, then lower slowly back to the start.',
    'ru': 'Удерживайте верхнюю точку 1–2 секунды, затем медленно опустите таз.',
    'de': '1–2 Sekunden oben halten, dann langsam absenken.',
    'fr': 'Maintenez en haut 1 à 2 secondes, puis redescendez lentement.',
    'it': 'Tieni la posizione in alto 1–2 secondi, poi abbassa lentamente.',
    'pt': 'Segure no topo por 1–2 segundos, depois abaixe lentamente ao início.',
    'es': 'Mantén en la parte superior 1–2 segundos, luego baja lentamente al inicio.',
    'id': 'Tahan di atas selama 1–2 detik, lalu turunkan perlahan ke posisi awal.',
  },
  'exercise.glute_bridge.mistake1': {
    'en': 'Hyperextending the lower back at the top — stop when hips are in line with your torso.',
    'ru': 'Переразгибание поясницы в верхней точке — останавливайтесь, когда таз выровнялся с корпусом.',
    'de': 'Lendenwirbelsäule oben überstrecken — aufhören, wenn die Hüfte mit dem Rumpf ausgerichtet ist.',
    'fr': 'Hyperextension du bas du dos en haut — arrêtez quand les hanches sont alignées avec le tronc.',
    'it': 'Iperestensione della zona lombare in cima — fermati quando i fianchi sono allineati con il busto.',
    'pt': 'Hiperextensão da lombar no topo — pare quando os quadris estiverem alinhados com o tronco.',
    'es': 'Hiperextensión de la zona lumbar en la parte superior — detente cuando las caderas estén alineadas con el tronco.',
    'id': 'Hiperekstensi punggung bawah di atas — berhenti saat pinggul sejajar dengan batang tubuh.',
  },

  // ---------------------------------------------------------------------------
  // push_up — Отжимания
  // ---------------------------------------------------------------------------
  'exercise.push_up.step1': {
    'en': 'Start in a high plank: hands slightly wider than shoulder-width, body in a straight line from head to heels.',
    'ru': 'Примите упор лёжа: руки чуть шире плеч, тело — прямая линия от головы до пяток.',
    'de': 'Hoher Plank: Hände leicht breiter als schulterbreit, Körper von Kopf bis Ferse in einer geraden Linie.',
    'fr': 'Adoptez une position de planche haute : mains légèrement plus larges que les épaules, corps aligné de la tête aux talons.',
    'it': 'Posizionati in plank alto: mani leggermente più larghe delle spalle, corpo in linea retta dalla testa ai talloni.',
    'pt': 'Comece em prancha alta: mãos ligeiramente mais largas que os ombros, corpo em linha reta da cabeça aos calcanhares.',
    'es': 'Comienza en plancha alta: manos ligeramente más anchas que los hombros, cuerpo en línea recta de la cabeza a los talones.',
    'id': 'Mulai dalam posisi plank tinggi: tangan sedikit lebih lebar dari bahu, tubuh dalam garis lurus dari kepala ke tumit.',
  },
  'exercise.push_up.step2': {
    'en': 'Lower your chest to the floor by bending your elbows at roughly 45° to your torso.',
    'ru': 'Опускайте грудь к полу, сгибая локти примерно под 45° к корпусу.',
    'de': 'Brust zum Boden absenken, Ellenbogen ca. 45° zum Rumpf beugen.',
    'fr': 'Abaissez la poitrine vers le sol en fléchissant les coudes à environ 45° du tronc.',
    'it': 'Abbassa il petto verso il pavimento piegando i gomiti a circa 45° rispetto al busto.',
    'pt': 'Abaixe o peito em direção ao chão dobrando os cotovelos a aproximadamente 45° em relação ao tronco.',
    'es': 'Baja el pecho hacia el suelo doblando los codos aproximadamente 45° respecto al tronco.',
    'id': 'Turunkan dada ke lantai dengan menekuk siku sekitar 45° terhadap batang tubuh.',
  },
  'exercise.push_up.step3': {
    'en': 'Push through your palms to return to the top, exhaling as you rise.',
    'ru': 'Выжмите себя ладонями обратно в упор, выдыхая при подъёме.',
    'de': 'Durch die Handflächen hochdrücken, beim Aufsteigen ausatmen.',
    'fr': 'Poussez sur les paumes pour revenir en haut, expirez en montant.',
    'it': 'Spingi attraverso i palmi per tornare in alto, espira mentre sali.',
    'pt': 'Empurre pelas palmas para voltar ao topo, expirando ao subir.',
    'es': 'Empuja a través de las palmas para volver arriba, expira al subir.',
    'id': 'Dorong melalui telapak tangan untuk kembali ke atas, hembuskan napas saat naik.',
  },
  'exercise.push_up.mistake1': {
    'en': 'Hips sagging or piking — keep your core tight and body straight throughout.',
    'ru': 'Провисание или подъём таза — держите кор в напряжении, тело должно оставаться прямым.',
    'de': 'Hüfte sackt ab oder zeigt nach oben — Core straff halten und Körper gerade.',
    'fr': 'Hanches qui s\'affaissent ou se soulèvent — contractez le gainage et gardez le corps droit.',
    'it': 'Fianchi che cedono o si alzano — tieni il core teso e il corpo dritto per tutto il movimento.',
    'pt': 'Quadris afundando ou subindo — mantenha o core firme e o corpo reto durante todo o movimento.',
    'es': 'Caderas hundiéndose o elevándose — mantén el core firme y el cuerpo recto durante todo el movimiento.',
    'id': 'Pinggul melorot atau terangkat — jaga core tetap kencang dan tubuh lurus sepanjang gerakan.',
  },
  'exercise.push_up.mistake2': {
    'en': 'Flaring elbows wide — keep them at ~45° to protect your shoulders.',
    'ru': 'Локти уходят в стороны — держите угол ~45° для защиты плечевых суставов.',
    'de': 'Ellenbogen zu weit abspreizen — ca. 45° halten, um die Schultern zu schützen.',
    'fr': 'Coudes trop écartés — gardez-les à environ 45° pour protéger les épaules.',
    'it': 'Gomiti troppo aperti — mantienili a circa 45° per proteggere le spalle.',
    'pt': 'Cotovelos muito abertos — mantenha-os a ~45° para proteger os ombros.',
    'es': 'Codos muy abiertos — mantenlos a ~45° para proteger los hombros.',
    'id': 'Siku terlalu melebar — jaga sudut ~45° untuk melindungi bahu.',
  },

  // ---------------------------------------------------------------------------
  // barbell_bench_press — Жим штанги лёжа
  // ---------------------------------------------------------------------------
  'exercise.barbell_bench_press.step1': {
    'en': 'Lie on the bench with eyes under the bar, feet flat on the floor and shoulder blades retracted.',
    'ru': 'Лягте на скамью так, чтобы глаза были под грифом; стопы на полу, лопатки сведены.',
    'de': 'Auf die Bank legen: Augen unter der Stange, Füße flach, Schulterblätter zusammengezogen.',
    'fr': 'Allongez-vous sur le banc, yeux sous la barre, pieds à plat, omoplates rétractées.',
    'it': 'Sdraiati sulla panca con gli occhi sotto il bilanciere, piedi piatti, scapole retratte.',
    'pt': 'Deite no banco com os olhos sob a barra, pés planos no chão e escápulas retraídas.',
    'es': 'Recuéstate en el banco con los ojos bajo la barra, pies planos en el suelo y escápulas retraídas.',
    'id': 'Berbaring di bangku dengan mata di bawah bar, kaki rata di lantai dan skapula ditarik ke belakang.',
  },
  'exercise.barbell_bench_press.step2': {
    'en': 'Grip the bar slightly wider than shoulder-width, unrack with straight arms and bring it over your lower chest.',
    'ru': 'Возьмите гриф чуть шире плеч, снимите со стоек на прямых руках и опустите над нижней частью груди.',
    'de': 'Stange leicht breiter als schulterbreit greifen, mit gestreckten Armen abheben und über die untere Brust bringen.',
    'fr': 'Saisissez la barre un peu plus large que les épaules, sortez du rack les bras tendus et amenez-la au-dessus du bas de la poitrine.',
    'it': 'Afferra il bilanciere leggermente più largo delle spalle, toglilo dal rack con le braccia tese e portalo sopra la parte bassa del petto.',
    'pt': 'Pegue a barra ligeiramente mais larga que os ombros, tire do rack com os braços estendidos e posicione sobre a parte inferior do peito.',
    'es': 'Agarra la barra ligeramente más ancha que los hombros, sácala del rack con los brazos extendidos y llévala sobre la parte inferior del pecho.',
    'id': 'Pegang bar sedikit lebih lebar dari bahu, angkat dari rack dengan lengan lurus dan bawa ke atas dada bagian bawah.',
  },
  'exercise.barbell_bench_press.step3': {
    'en': 'Lower the bar under control until it touches your chest — don\'t bounce.',
    'ru': 'Медленно опустите гриф до касания грудью — не отбивайте от груди.',
    'de': 'Stange kontrolliert absenken bis sie die Brust berührt — nicht abprallen lassen.',
    'fr': 'Descendez la barre sous contrôle jusqu\'à toucher la poitrine — ne rebondissez pas.',
    'it': 'Abbassa il bilanciere con controllo fino a toccare il petto — non rimbalzare.',
    'pt': 'Abaixe a barra com controle até tocar o peito — não rebata.',
    'es': 'Baja la barra con control hasta tocar el pecho — no rebotar.',
    'id': 'Turunkan bar dengan terkontrol hingga menyentuh dada — jangan memantulkan.',
  },
  'exercise.barbell_bench_press.step4': {
    'en': 'Press the bar back up in a slight arc, exhaling as you lock out.',
    'ru': 'Выжмите гриф по дуге вверх, выдыхая при полном выпрямлении рук.',
    'de': 'Stange leicht bogenförmig hochdrücken, beim Durchstrecken ausatmen.',
    'fr': 'Repoussez la barre en légère courbe vers le haut en expirant au verrouillage.',
    'it': 'Spingi il bilanciere verso l\'alto con un leggero arco, espira al blocco.',
    'pt': 'Empurre a barra de volta para cima em um leve arco, expirando ao travar os cotovelos.',
    'es': 'Empuja la barra hacia arriba en un ligero arco, expirando al bloquear los codos.',
    'id': 'Dorong bar ke atas dalam busur kecil, hembuskan napas saat mengunci siku.',
  },
  'exercise.barbell_bench_press.mistake1': {
    'en': 'Bouncing the bar off the chest — touch lightly and press with control.',
    'ru': 'Отбив штанги от груди — касайтесь слегка и выжимайте с контролем.',
    'de': 'Stange von der Brust abprallen lassen — leicht berühren und kontrolliert drücken.',
    'fr': 'Rebondir la barre sur la poitrine — touchez légèrement et poussez avec contrôle.',
    'it': 'Far rimbalzare il bilanciere sul petto — tocca leggermente e premi con controllo.',
    'pt': 'Quicar a barra no peito — toque levemente e pressione com controle.',
    'es': 'Rebotar la barra en el pecho — toca levemente y presiona con control.',
    'id': 'Memantulkan bar di dada — sentuh dengan ringan dan tekan dengan terkontrol.',
  },
  'exercise.barbell_bench_press.mistake2': {
    'en': 'Feet raised off the floor — keep them flat for a stable base.',
    'ru': 'Ноги висят в воздухе — держите стопы на полу для устойчивости.',
    'de': 'Füße vom Boden abheben — flach halten für eine stabile Basis.',
    'fr': 'Pieds décollés du sol — gardez-les à plat pour une base stable.',
    'it': 'Piedi sollevati dal pavimento — tienili piatti per una base stabile.',
    'pt': 'Pés levantados do chão — mantenha-os planos para uma base estável.',
    'es': 'Pies levantados del suelo — mantenlos planos para una base estable.',
    'id': 'Kaki terangkat dari lantai — jaga tetap rata untuk tumpuan yang stabil.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_bench_press — Жим гантелей лёжа
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_bench_press.step1': {
    'en': 'Lie on the bench holding a dumbbell in each hand at chest level, palms facing forward.',
    'ru': 'Лягте на скамью с гантелями у груди, ладони смотрят вперёд.',
    'de': 'Auf die Bank legen, je eine Hantel auf Brusthöhe halten, Handflächen nach vorne.',
    'fr': 'Allongez-vous sur le banc en tenant un haltère dans chaque main à hauteur de poitrine, paumes vers l\'avant.',
    'it': 'Sdraiati sulla panca tenendo un manubrio in ogni mano all\'altezza del petto, palmi rivolti in avanti.',
    'pt': 'Deite no banco segurando um haltere em cada mão na altura do peito, palmas voltadas para frente.',
    'es': 'Recuéstate en el banco sosteniendo una mancuerna en cada mano a la altura del pecho, palmas hacia adelante.',
    'id': 'Berbaring di bangku sambil memegang dumbbell di setiap tangan setinggi dada, telapak menghadap ke depan.',
  },
  'exercise.dumbbell_bench_press.step2': {
    'en': 'Press both dumbbells up until your arms are fully extended, bringing them slightly together at the top.',
    'ru': 'Выжмите гантели вверх до полного разгибания рук, слегка сближая их наверху.',
    'de': 'Beide Hanteln hochdrücken bis die Arme gestreckt sind, oben leicht zusammenführen.',
    'fr': 'Poussez les deux haltères vers le haut jusqu\'à extension complète, les rapprochant légèrement en haut.',
    'it': 'Spingi entrambi i manubri verso l\'alto fino a estensione completa, avvicinandoli leggermente in cima.',
    'pt': 'Pressione ambos os halteres para cima até os braços ficarem totalmente estendidos, aproximando-os levemente no topo.',
    'es': 'Presiona ambas mancuernas hacia arriba hasta que los brazos estén totalmente extendidos, acercándolas ligeramente en la parte superior.',
    'id': 'Tekan kedua dumbbell ke atas hingga lengan sepenuhnya terentang, sedikit mendekatkan keduanya di atas.',
  },
  'exercise.dumbbell_bench_press.step3': {
    'en': 'Lower slowly back to the starting position, feeling the stretch across your chest.',
    'ru': 'Медленно опустите обратно в исходное положение, ощущая растяжку грудных мышц.',
    'de': 'Langsam in die Ausgangsposition absenken und die Dehnung in der Brust spüren.',
    'fr': 'Redescendez lentement à la position de départ en ressentant l\'étirement pectoral.',
    'it': 'Abbassa lentamente alla posizione di partenza, percependo lo stretching del petto.',
    'pt': 'Abaixe lentamente à posição inicial, sentindo o alongamento no peito.',
    'es': 'Baja lentamente a la posición inicial, sintiendo el estiramiento en el pecho.',
    'id': 'Turunkan perlahan ke posisi awal, rasakan regangan di seluruh dada.',
  },
  'exercise.dumbbell_bench_press.mistake1': {
    'en': 'Uneven range of motion — lower both dumbbells symmetrically to the same depth.',
    'ru': 'Несимметричная амплитуда — опускайте обе гантели до одинаковой глубины.',
    'de': 'Ungleichmäßige Bewegungsamplitude — beide Hanteln symmetrisch auf gleiche Tiefe absenken.',
    'fr': 'Amplitude de mouvement asymétrique — abaissez les deux haltères symétriquement à la même profondeur.',
    'it': 'Ampiezza di movimento asimmetrica — abbassa entrambi i manubri simmetricamente alla stessa profondità.',
    'pt': 'Amplitude de movimento assimétrica — abaixe ambos os halteres simetricamente à mesma profundidade.',
    'es': 'Amplitud de movimiento asimétrica — baja ambas mancuernas simétricamente a la misma profundidad.',
    'id': 'Rentang gerak tidak merata — turunkan kedua dumbbell secara simetris ke kedalaman yang sama.',
  },

  // ---------------------------------------------------------------------------
  // overhead_barbell_press — Жим штанги стоя
  // ---------------------------------------------------------------------------
  'exercise.overhead_barbell_press.step1': {
    'en': 'Stand with the bar at collarbone height, grip slightly wider than shoulders, elbows just in front of the bar.',
    'ru': 'Встаньте со штангой на уровне ключиц, хват чуть шире плеч, локти немного перед грифом.',
    'de': 'Stehe mit der Stange auf Schlüsselbeinhöhe, Griff leicht schulterbreiter, Ellenbogen knapp vor der Stange.',
    'fr': 'Tenez-vous debout avec la barre à hauteur des clavicules, prise légèrement plus large que les épaules, coudes juste devant la barre.',
    'it': 'Stai in piedi con il bilanciere all\'altezza delle clavicole, presa leggermente più larga delle spalle, gomiti appena davanti al bilanciere.',
    'pt': 'Fique em pé com a barra na altura das clavículas, pegada levemente mais larga que os ombros, cotovelos levemente à frente da barra.',
    'es': 'Párate con la barra a la altura de las clavículas, agarre ligeramente más ancho que los hombros, codos justo delante de la barra.',
    'id': 'Berdiri dengan bar setinggi tulang selangka, pegangan sedikit lebih lebar dari bahu, siku tepat di depan bar.',
  },
  'exercise.overhead_barbell_press.step2': {
    'en': 'Press the bar straight up, moving your head slightly back to clear it, then push your head forward as the bar passes.',
    'ru': 'Жмите гриф прямо вверх, слегка отводя голову назад для его прохождения, затем возвращая голову вперёд.',
    'de': 'Stange senkrecht hochdrücken, Kopf leicht zurückziehen damit sie passiert, dann Kopf wieder vordrücken.',
    'fr': 'Poussez la barre verticalement, inclinez légèrement la tête en arrière pour la laisser passer, puis revenez en avant.',
    'it': 'Spingi il bilanciere verticalmente verso l\'alto, inclina leggermente la testa indietro per farlo passare, poi riportala avanti.',
    'pt': 'Pressione a barra direto para cima, recuando levemente a cabeça para ela passar e depois avançando-a conforme a barra sobe.',
    'es': 'Presiona la barra directo hacia arriba, moviendo levemente la cabeza hacia atrás para dejarla pasar y luego empujando la cabeza hacia adelante.',
    'id': 'Tekan bar lurus ke atas, gerakkan kepala sedikit ke belakang agar bar melewati, lalu dorong kepala ke depan setelah bar lewat.',
  },
  'exercise.overhead_barbell_press.step3': {
    'en': 'Lock out your arms overhead with the bar directly above your heels; lower back to the start under control.',
    'ru': 'Выпрямите руки так, чтобы гриф был прямо над пятками; опустите с контролем в исходное положение.',
    'de': 'Arme überkopf durchstrecken, Stange direkt über den Fersen; kontrolliert absenken.',
    'fr': 'Verrouillez les bras au-dessus de la tête, barre directement au-dessus des talons ; redescendez sous contrôle.',
    'it': 'Blocca le braccia sopra la testa con il bilanciere direttamente sopra i talloni; abbassa controllando il movimento.',
    'pt': 'Trave os braços acima da cabeça com a barra diretamente sobre os calcanhares; abaixe com controle até o início.',
    'es': 'Bloquea los brazos sobre la cabeza con la barra directamente sobre los talones; baja con control hasta el inicio.',
    'id': 'Kunci lengan di atas kepala dengan bar tepat di atas tumit; turunkan dengan terkontrol ke posisi awal.',
  },
  'exercise.overhead_barbell_press.mistake1': {
    'en': 'Arching the lower back excessively — engage your glutes and core to keep a neutral spine.',
    'ru': 'Чрезмерный прогиб поясницы — напрягите ягодицы и кор для нейтрального положения позвоночника.',
    'de': 'Zu starkes Hohlkreuz — Gesäß und Core aktivieren, um die Wirbelsäule neutral zu halten.',
    'fr': 'Creuser excessivement les lombaires — contractez les fessiers et le gainage pour une colonne neutre.',
    'it': 'Eccessiva lordosi lombare — contrai glutei e core per mantenere la colonna vertebrale neutra.',
    'pt': 'Arqueamento excessivo da lombar — contraia glúteos e core para manter a coluna neutra.',
    'es': 'Arqueamiento excesivo de la zona lumbar — activa glúteos y core para mantener la columna neutra.',
    'id': 'Melengkungkan punggung bawah secara berlebihan — kencangkan glute dan core untuk menjaga tulang belakang netral.',
  },
  'exercise.overhead_barbell_press.mistake2': {
    'en': 'Bar path too far forward — keep it close to your face and press vertically.',
    'ru': 'Гриф уходит слишком далеко вперёд — жмите по вертикали, близко к лицу.',
    'de': 'Stangenpfad zu weit nach vorne — nah am Gesicht halten und senkrecht drücken.',
    'fr': 'Trajectoire de barre trop en avant — gardez-la proche du visage et poussez verticalement.',
    'it': 'Traiettoria del bilanciere troppo in avanti — tienilo vicino al viso e spingi verticalmente.',
    'pt': 'Trajetória da barra muito à frente — mantenha-a próxima ao rosto e pressione verticalmente.',
    'es': 'Trayectoria de la barra muy al frente — mantenla cerca del rostro y presiona verticalmente.',
    'id': 'Jalur bar terlalu jauh ke depan — jaga dekat wajah dan tekan secara vertikal.',
  },

  // ---------------------------------------------------------------------------
  // barbell_row — Тяга штанги в наклоне
  // ---------------------------------------------------------------------------
  'exercise.barbell_row.step1': {
    'en': 'Stand with feet hip-width apart, hinge forward 45–60°, and grip the bar just outside your legs.',
    'ru': 'Ноги на ширине бёдер, наклонитесь на 45–60°, возьмите гриф чуть шире ног.',
    'de': 'Füße hüftbreit, 45–60° nach vorne beugen, Stange knapp außerhalb der Beine greifen.',
    'fr': 'Pieds écartés à la largeur des hanches, penchez-vous 45–60° en avant et saisissez la barre juste à l\'extérieur des jambes.',
    'it': 'Piedi alla larghezza dei fianchi, inclinati in avanti di 45–60° e afferra il bilanciere appena fuori dalle gambe.',
    'pt': 'Pés na largura dos quadris, incline para frente 45–60° e pegue a barra logo fora das pernas.',
    'es': 'Pies al ancho de las caderas, inclínate 45–60° hacia adelante y agarra la barra justo fuera de las piernas.',
    'id': 'Kaki selebar pinggul, engsel ke depan 45–60°, dan pegang bar tepat di luar kaki.',
  },
  'exercise.barbell_row.step2': {
    'en': 'Keep your back flat and core braced throughout the movement.',
    'ru': 'Держите спину прямой и кор в напряжении на протяжении всего упражнения.',
    'de': 'Rücken während der gesamten Bewegung flach und Core angespannt halten.',
    'fr': 'Gardez le dos plat et le gainage actif tout au long du mouvement.',
    'it': 'Mantieni la schiena piatta e il core contratto per tutto il movimento.',
    'pt': 'Mantenha as costas retas e o core contraído durante todo o movimento.',
    'es': 'Mantén la espalda plana y el core activo durante todo el movimiento.',
    'id': 'Jaga punggung tetap rata dan core kencang sepanjang gerakan.',
  },
  'exercise.barbell_row.step3': {
    'en': 'Pull the bar into your lower abdomen, driving your elbows back and squeezing your shoulder blades.',
    'ru': 'Тяните гриф к нижней части живота, отводя локти назад и сводя лопатки.',
    'de': 'Stange zum Unterbauch ziehen, Ellenbogen nach hinten treiben und Schulterblätter zusammenziehen.',
    'fr': 'Tirez la barre vers le bas du ventre en poussant les coudes vers l\'arrière et en serrant les omoplates.',
    'it': 'Tira il bilanciere verso il basso addome, spingendo i gomiti indietro e stringendo le scapole.',
    'pt': 'Puxe a barra para o abdômen inferior, empurrando os cotovelos para trás e contraindo as escápulas.',
    'es': 'Jala la barra hacia el abdomen inferior, empujando los codos hacia atrás y apretando las escápulas.',
    'id': 'Tarik bar ke perut bagian bawah, dorong siku ke belakang dan kencangkan skapula.',
  },
  'exercise.barbell_row.step4': {
    'en': 'Lower the bar slowly back to the hanging position.',
    'ru': 'Медленно опустите гриф в исходное положение.',
    'de': 'Stange langsam in die hängende Ausgangsposition absenken.',
    'fr': 'Redescendez lentement la barre en position suspendue.',
    'it': 'Abbassa lentamente il bilanciere alla posizione di partenza.',
    'pt': 'Abaixe a barra lentamente de volta à posição pendente.',
    'es': 'Baja la barra lentamente de vuelta a la posición colgante.',
    'id': 'Turunkan bar perlahan kembali ke posisi menggantung.',
  },
  'exercise.barbell_row.mistake1': {
    'en': 'Using momentum to swing the bar up — reduce weight and focus on back contraction.',
    'ru': 'Читинг — подбрасывание грифа рывком: снизьте вес и сосредоточьтесь на сокращении спины.',
    'de': 'Schwung nutzen, um die Stange hochzuschwingen — Gewicht reduzieren und auf Rückenkontraktion konzentrieren.',
    'fr': 'Utiliser l\'élan pour balancer la barre — réduisez la charge et concentrez-vous sur la contraction dorsale.',
    'it': 'Usare lo slancio per alzare il bilanciere — riduci il peso e concentrati sulla contrazione della schiena.',
    'pt': 'Usar embalo para balançar a barra — reduza o peso e foque na contração das costas.',
    'es': 'Usar impulso para balancear la barra — reduce el peso y enfócate en la contracción de la espalda.',
    'id': 'Menggunakan momentum untuk mengayun bar — kurangi beban dan fokus pada kontraksi punggung.',
  },
  'exercise.barbell_row.mistake2': {
    'en': 'Pulling to the upper chest — aim for the lower abdomen to target lats.',
    'ru': 'Тяга к верхней части груди — тяните к нижней части живота для прокачки широчайших.',
    'de': 'Zur Oberbrust ziehen — auf den Unterbauch zielen, um den Latissimus zu treffen.',
    'fr': 'Tirer vers le haut de la poitrine — visez le bas du ventre pour cibler les dorsaux.',
    'it': 'Tirare verso la parte alta del petto — punta al basso addome per coinvolgere i dorsali.',
    'pt': 'Puxar para o peito superior — mire no abdômen inferior para ativar o latíssimo.',
    'es': 'Jalar hacia el pecho superior — apunta al abdomen inferior para trabajar los dorsales.',
    'id': 'Menarik ke dada atas — bidik perut bawah untuk menarget latissimus.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_row — Тяга гантели в наклоне
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_row.step1': {
    'en': 'Place your knee and hand on a bench, hold a dumbbell with your free arm hanging straight down.',
    'ru': 'Упритесь коленом и рукой в скамью, держите гантель свободной рукой — она висит вертикально.',
    'de': 'Knie und Hand auf eine Bank stützen, Hantel mit dem freien Arm senkrecht herabhängen lassen.',
    'fr': 'Posez genou et main sur un banc, tenez un haltère de l\'autre main, bras pendant verticalement.',
    'it': 'Appoggia ginocchio e mano su una panca, tieni un manubrio con il braccio libero, lasciandolo pendere verticalmente.',
    'pt': 'Apoie o joelho e a mão em um banco, segure um haltere com o braço livre pendurado reto para baixo.',
    'es': 'Apoya la rodilla y la mano en un banco, sostén una mancuerna con el brazo libre colgando recto hacia abajo.',
    'id': 'Letakkan lutut dan tangan di bangku, pegang dumbbell dengan lengan bebas menggantung lurus ke bawah.',
  },
  'exercise.dumbbell_row.step2': {
    'en': 'Pull the dumbbell toward your hip, keeping your elbow close to your body.',
    'ru': 'Тяните гантель к бедру, держа локоть близко к телу.',
    'de': 'Hantel zur Hüfte ziehen, Ellenbogen nah am Körper halten.',
    'fr': 'Tirez l\'haltère vers la hanche en gardant le coude proche du corps.',
    'it': 'Tira il manubrio verso il fianco, tenendo il gomito vicino al corpo.',
    'pt': 'Puxe o haltere em direção ao quadril, mantendo o cotovelo próximo ao corpo.',
    'es': 'Jala la mancuerna hacia la cadera, manteniendo el codo cerca del cuerpo.',
    'id': 'Tarik dumbbell ke arah pinggul, jaga siku tetap dekat dengan tubuh.',
  },
  'exercise.dumbbell_row.step3': {
    'en': 'Lower slowly to full extension, feeling the stretch in your lat.',
    'ru': 'Медленно опустите до полного разгибания, ощущая растяжку широчайшей.',
    'de': 'Langsam bis zur vollen Streckung absenken und die Dehnung im Latissimus spüren.',
    'fr': 'Redescendez lentement jusqu\'à l\'extension complète en ressentant l\'étirement du grand dorsal.',
    'it': 'Abbassa lentamente fino alla completa estensione, sentendo lo stretching del dorsale.',
    'pt': 'Abaixe lentamente até a extensão total, sentindo o alongamento no latíssimo.',
    'es': 'Baja lentamente hasta la extensión completa, sintiendo el estiramiento en el dorsal.',
    'id': 'Turunkan perlahan hingga ekstensi penuh, rasakan regangan di latissimus.',
  },
  'exercise.dumbbell_row.mistake1': {
    'en': 'Rotating the torso to swing the weight — keep your hips square and use only your arm and back.',
    'ru': 'Разворот корпуса для инерции — держите таз ровно и работайте только рукой и спиной.',
    'de': 'Rumpf drehen um Schwung zu holen — Hüfte gerade halten und nur Arm und Rücken einsetzen.',
    'fr': 'Faire pivoter le torse pour balancer le poids — gardez les hanches carrées et utilisez uniquement le bras et le dos.',
    'it': 'Ruotare il busto per prendere slancio — tieni i fianchi quadrati e usa solo braccio e schiena.',
    'pt': 'Girar o tronco para balançar o peso — mantenha os quadris quadrados e use apenas o braço e as costas.',
    'es': 'Rotar el torso para balancear el peso — mantén las caderas cuadradas y usa solo el brazo y la espalda.',
    'id': 'Memutar batang tubuh untuk mengayun beban — jaga pinggul tetap lurus dan gunakan hanya lengan dan punggung.',
  },

  // ---------------------------------------------------------------------------
  // pull_up — Подтягивания
  // ---------------------------------------------------------------------------
  'exercise.pull_up.step1': {
    'en': 'Hang from the bar with hands slightly wider than shoulder-width, palms facing away (pronated grip).',
    'ru': 'Возьмитесь за перекладину чуть шире плеч прямым хватом (пронация).',
    'de': 'An der Stange hängen, Hände leicht schulterbreiter, Handflächen von dir weg (Pronationsgriff).',
    'fr': 'Suspendez-vous à la barre, mains légèrement plus larges que les épaules, paumes vers l\'extérieur (prise pronée).',
    'it': 'Appendi alla sbarra con le mani leggermente più larghe delle spalle, palmi rivolti all\'esterno (presa pronata).',
    'pt': 'Pendure-se na barra com as mãos ligeiramente mais largas que os ombros, palmas voltadas para longe (pegada pronada).',
    'es': 'Cuélgate de la barra con las manos ligeramente más anchas que los hombros, palmas hacia afuera (agarre pronado).',
    'id': 'Gantung di bar dengan tangan sedikit lebih lebar dari bahu, telapak menghadap jauh (pegangan pronasi).',
  },
  'exercise.pull_up.step2': {
    'en': 'Engage your lats by pulling your shoulder blades down and back, then pull yourself up until your chin clears the bar.',
    'ru': 'Активируйте широчайшие: потяните лопатки вниз и назад, затем подтягивайтесь до касания подбородком перекладины.',
    'de': 'Latissimus aktivieren: Schulterblätter nach unten und hinten ziehen, dann hochziehen bis das Kinn über die Stange kommt.',
    'fr': 'Activez les dorsaux en tirant les omoplates vers le bas et l\'arrière, puis montez jusqu\'à ce que le menton dépasse la barre.',
    'it': 'Attiva i dorsali tirando le scapole verso il basso e indietro, poi tiranti su finché il mento supera la sbarra.',
    'pt': 'Ative os dorsais puxando as escápulas para baixo e para trás, depois se puxe até o queixo ultrapassar a barra.',
    'es': 'Activa los dorsales jalando las escápulas hacia abajo y atrás, luego jálate hacia arriba hasta que el mentón supere la barra.',
    'id': 'Aktifkan latissimus dengan menarik skapula ke bawah dan belakang, lalu tarik diri ke atas hingga dagu melewati bar.',
  },
  'exercise.pull_up.step3': {
    'en': 'Lower yourself slowly to a full hang — resist the urge to drop quickly.',
    'ru': 'Медленно опускайтесь в вис — не бросайте себя вниз.',
    'de': 'Sich langsam bis zum vollständigen Hängen absenken — dem Drang widerstehen, schnell fallen zu lassen.',
    'fr': 'Redescendez lentement en suspension complète — résistez à l\'envie de vous lâcher rapidement.',
    'it': 'Abbassati lentamente fino alla posizione di appensione — resisti all\'impulso di scendere velocemente.',
    'pt': 'Desça lentamente até o hang completo — resista à tentação de soltar rapidamente.',
    'es': 'Bájate lentamente hasta un cuelgue completo — resiste el impulso de soltarte rápidamente.',
    'id': 'Turunkan diri perlahan ke posisi gantung penuh — tahan dorongan untuk turun cepat.',
  },
  'exercise.pull_up.mistake1': {
    'en': 'Kipping or swinging for momentum — use strict form to build real strength.',
    'ru': 'Инерционные рывки ногами — работайте строго, без рывков.',
    'de': 'Schwingen oder Kipping für Schwung — strikte Form benutzen, um echte Kraft aufzubauen.',
    'fr': 'Balancement ou kipping pour l\'élan — utilisez une forme stricte pour développer une vraie force.',
    'it': 'Oscillare o usare il kipping per slancio — usa una forma rigorosa per costruire vera forza.',
    'pt': 'Kipping ou balanço para ganhar embalo — use forma estrita para desenvolver força de verdade.',
    'es': 'Kipping o balanceo para impulso — usa una forma estricta para construir fuerza real.',
    'id': 'Kipping atau berayun untuk momentum — gunakan bentuk ketat untuk membangun kekuatan nyata.',
  },
  'exercise.pull_up.mistake2': {
    'en': 'Partial range of motion — start from a dead hang and go all the way up each rep.',
    'ru': 'Неполная амплитуда — начинайте из полного виса и поднимайтесь до касания каждый раз.',
    'de': 'Unvollständige Bewegungsamplitude — aus dem toten Hang starten und jede Wiederholung bis oben durchführen.',
    'fr': 'Amplitude partielle — partez d\'une suspension morte et montez jusqu\'en haut à chaque répétition.',
    'it': 'Ampiezza parziale — inizia da un appensione completa e sali fino in cima ad ogni ripetizione.',
    'pt': 'Amplitude parcial — comece de um dead hang completo e suba até o topo em cada repetição.',
    'es': 'Amplitud parcial — comienza desde un cuelgue muerto y sube hasta arriba en cada repetición.',
    'id': 'Rentang gerak sebagian — mulai dari dead hang penuh dan naik sampai atas di setiap repetisi.',
  },

  // ---------------------------------------------------------------------------
  // plank — Планка
  // ---------------------------------------------------------------------------
  'exercise.plank.step1': {
    'en': 'Place forearms on the floor with elbows under your shoulders; extend your legs behind you.',
    'ru': 'Упритесь предплечьями в пол, локти под плечами; вытяните ноги назад.',
    'de': 'Unterarme auf dem Boden, Ellenbogen unter den Schultern; Beine nach hinten ausstrecken.',
    'fr': 'Posez les avant-bras au sol, coudes sous les épaules ; étendez les jambes derrière vous.',
    'it': 'Appoggia gli avambracci a terra con i gomiti sotto le spalle; estendi le gambe dietro di te.',
    'pt': 'Apoie os antebraços no chão com os cotovelos sob os ombros; estenda as pernas atrás.',
    'es': 'Apoya los antebrazos en el suelo con los codos bajo los hombros; extiende las piernas hacia atrás.',
    'id': 'Letakkan lengan bawah di lantai dengan siku di bawah bahu; rentangkan kaki ke belakang.',
  },
  'exercise.plank.step2': {
    'en': 'Lift your hips so your body forms a straight line from head to heels — squeeze your glutes and core.',
    'ru': 'Поднимите таз так, чтобы тело образовало прямую линию — напрягите ягодицы и кор.',
    'de': 'Hüfte anheben bis der Körper eine Linie von Kopf bis Ferse bildet — Gesäß und Core anspannen.',
    'fr': 'Soulevez les hanches jusqu\'à former une ligne droite de la tête aux talons — contractez fessiers et gainage.',
    'it': 'Solleva i fianchi in modo che il corpo formi una linea retta dalla testa ai talloni — contrai glutei e core.',
    'pt': 'Levante os quadris para o corpo formar uma linha reta da cabeça aos calcanhares — contraia glúteos e core.',
    'es': 'Levanta las caderas para que el cuerpo forme una línea recta de la cabeza a los talones — aprieta glúteos y core.',
    'id': 'Angkat pinggul agar tubuh membentuk garis lurus dari kepala ke tumit — kencangkan glute dan core.',
  },
  'exercise.plank.step3': {
    'en': 'Hold the position, breathing steadily, without letting your hips sag or rise.',
    'ru': 'Удерживайте позицию, ровно дышите, не давая тазу провисать или подниматься.',
    'de': 'Position halten, gleichmäßig atmen, ohne dass die Hüfte absinkt oder hochgeht.',
    'fr': 'Maintenez la position en respirant régulièrement, sans laisser les hanches s\'affaisser ou monter.',
    'it': 'Mantieni la posizione respirando in modo regolare, senza lasciare che i fianchi cedano o si alzino.',
    'pt': 'Segure a posição respirando de forma constante, sem deixar os quadris afundarem ou subirem.',
    'es': 'Mantén la posición respirando de manera constante, sin dejar que las caderas se hundan o suban.',
    'id': 'Tahan posisi, bernapas dengan stabil, tanpa membiarkan pinggul melorot atau terangkat.',
  },
  'exercise.plank.mistake1': {
    'en': 'Hips too high (piking) — lower them until your spine is neutral.',
    'ru': 'Таз поднят слишком высоко — опустите до нейтрального положения позвоночника.',
    'de': 'Hüfte zu hoch (Pike) — absenken bis die Wirbelsäule neutral ist.',
    'fr': 'Hanches trop hautes (piqué) — abaissez-les jusqu\'à une colonne neutre.',
    'it': 'Fianchi troppo alti (pica) — abbassali finché la colonna vertebrale è neutra.',
    'pt': 'Quadris muito altos (piking) — abaixe-os até a coluna ficar neutra.',
    'es': 'Caderas demasiado altas (piking) — bájalas hasta que la columna esté neutra.',
    'id': 'Pinggul terlalu tinggi (piking) — turunkan hingga tulang belakang netral.',
  },
  'exercise.plank.mistake2': {
    'en': 'Holding your breath — breathe steadily throughout the hold.',
    'ru': 'Задержка дыхания — дышите ровно на протяжении всего удержания.',
    'de': 'Luft anhalten — gleichmäßig während der gesamten Haltezeit atmen.',
    'fr': 'Retenir la respiration — respirez régulièrement pendant tout le maintien.',
    'it': 'Trattenere il respiro — respira in modo regolare per tutta la durata.',
    'pt': 'Prender a respiração — respire de forma constante durante todo o tempo de sustentação.',
    'es': 'Aguantar la respiración — respira de manera constante durante todo el tiempo de sostén.',
    'id': 'Menahan napas — bernapas dengan stabil sepanjang waktu tahan.',
  },

  // ---------------------------------------------------------------------------
  // russian_twist — Русский твист
  // ---------------------------------------------------------------------------
  'exercise.russian_twist.step1': {
    'en': 'Sit on the floor with knees bent and feet raised slightly; lean back ~45° to engage your core.',
    'ru': 'Сядьте на пол, согните колени, приподнимите стопы; отклонитесь назад ~45° для нагрузки кора.',
    'de': 'Auf dem Boden sitzen, Knie beugen, Füße leicht anheben; ~45° nach hinten lehnen um den Core zu aktivieren.',
    'fr': 'Asseyez-vous au sol, genoux fléchis, pieds légèrement levés ; penchez-vous ~45° en arrière pour engager le gainage.',
    'it': 'Siediti a terra con le ginocchia piegate e i piedi leggermente sollevati; inclinati indietro ~45° per attivare il core.',
    'pt': 'Sente no chão com os joelhos dobrados e os pés ligeiramente elevados; incline para trás ~45° para ativar o core.',
    'es': 'Siéntate en el suelo con las rodillas dobladas y los pies ligeramente elevados; inclínate hacia atrás ~45° para activar el core.',
    'id': 'Duduk di lantai dengan lutut ditekuk dan kaki sedikit diangkat; condong ke belakang ~45° untuk mengaktifkan core.',
  },
  'exercise.russian_twist.step2': {
    'en': 'Clasp your hands together and rotate your torso from side to side, touching the floor beside each hip.',
    'ru': 'Сложите руки вместе и поворачивайте корпус из стороны в сторону, касаясь пола у каждого бедра.',
    'de': 'Hände zusammenfalten und den Rumpf von Seite zu Seite drehen, dabei den Boden neben jeder Hüfte berühren.',
    'fr': 'Entrelacez les mains et faites pivoter le torse de droite à gauche en touchant le sol à côté de chaque hanche.',
    'it': 'Intreccia le mani e ruota il busto da un lato all\'altro, toccando il pavimento accanto a ogni fianco.',
    'pt': 'Entrelaçe as mãos e gire o tronco de lado a lado, tocando o chão ao lado de cada quadril.',
    'es': 'Entrelaza las manos y rota el torso de lado a lado, tocando el suelo junto a cada cadera.',
    'id': 'Satukan tangan dan putar batang tubuh dari sisi ke sisi, menyentuh lantai di samping setiap pinggul.',
  },
  'exercise.russian_twist.step3': {
    'en': 'Keep your back straight and move in a controlled arc — don\'t rush.',
    'ru': 'Держите спину прямой и двигайтесь по контролируемой дуге — не торопитесь.',
    'de': 'Rücken gerade halten und in einem kontrollierten Bogen bewegen — nicht hetzen.',
    'fr': 'Gardez le dos droit et bougez en arc contrôlé — ne précipitez pas.',
    'it': 'Tieni la schiena dritta e muoviti in un arco controllato — non affrettarti.',
    'pt': 'Mantenha as costas retas e mova-se em um arco controlado — não se apresse.',
    'es': 'Mantén la espalda recta y muévete en un arco controlado — no te apures.',
    'id': 'Jaga punggung tetap lurus dan bergerak dalam busur terkontrol — jangan terburu-buru.',
  },
  'exercise.russian_twist.mistake1': {
    'en': 'Rounding the lower back — sit taller and reduce the lean-back angle.',
    'ru': 'Скругление поясницы — сидите прямее и уменьшите угол отклонения назад.',
    'de': 'Rundrücken im Lendenwirbelbereich — aufrechter sitzen und den Neigungswinkel verringern.',
    'fr': 'Dos lombaire arrondi — asseyez-vous plus droit et réduisez l\'angle de recul.',
    'it': 'Schiena lombare arrotondata — siediti più dritto e riduci l\'angolo di inclinazione indietro.',
    'pt': 'Curvatura da lombar — sente-se mais ereto e reduza o ângulo de inclinação para trás.',
    'es': 'Redondear la zona lumbar — siéntate más erguido y reduce el ángulo de inclinación hacia atrás.',
    'id': 'Punggung bawah membulat — duduk lebih tegak dan kurangi sudut condong ke belakang.',
  },

  // ---------------------------------------------------------------------------
  // jumping_jack — Прыжки «звёздочка»
  // ---------------------------------------------------------------------------
  'exercise.jumping_jack.step1': {
    'en': 'Stand upright with feet together and arms at your sides.',
    'ru': 'Встаньте прямо, ноги вместе, руки вдоль тела.',
    'de': 'Aufrecht stehen, Füße zusammen, Arme an den Seiten.',
    'fr': 'Tenez-vous droit, pieds joints, bras le long du corps.',
    'it': 'Stai in piedi eretto, piedi uniti, braccia lungo i fianchi.',
    'pt': 'Fique em pé ereto com os pés juntos e os braços ao longo do corpo.',
    'es': 'Párate erguido con los pies juntos y los brazos a los lados.',
    'id': 'Berdiri tegak dengan kaki rapat dan lengan di samping tubuh.',
  },
  'exercise.jumping_jack.step2': {
    'en': 'Jump and simultaneously spread your feet to shoulder width while raising your arms overhead; jump back to start.',
    'ru': 'Прыгните, одновременно разводя ноги на ширину плеч и поднимая руки над головой; прыгните обратно.',
    'de': 'Springen und gleichzeitig Füße auf Schulterbreite spreizen und Arme über den Kopf heben; zurückspringen.',
    'fr': 'Sautez en écartant simultanément les pieds à la largeur des épaules et en levant les bras au-dessus de la tête ; ressautez pour revenir.',
    'it': 'Salta aprendo contemporaneamente i piedi alla larghezza delle spalle e sollevando le braccia sopra la testa; risalta per tornare.',
    'pt': 'Salte e simultaneamente abra os pés na largura dos ombros enquanto eleva os braços acima da cabeça; salte de volta ao início.',
    'es': 'Salta y simultáneamente abre los pies al ancho de los hombros mientras elevas los brazos sobre la cabeza; salta de vuelta al inicio.',
    'id': 'Lompat dan secara bersamaan buka kaki selebar bahu sambil angkat lengan ke atas kepala; lompat kembali ke posisi awal.',
  },

  // ---------------------------------------------------------------------------
  // burpee — Бёрпи
  // ---------------------------------------------------------------------------
  'exercise.burpee.step1': {
    'en': 'Start standing, then squat down and place your hands on the floor.',
    'ru': 'Из стойки присядьте и поставьте ладони на пол.',
    'de': 'Aus dem Stand in die Hocke gehen und Hände auf den Boden stellen.',
    'fr': 'Partez debout, puis accroupissez-vous et posez les mains au sol.',
    'it': 'Parti in piedi, poi scendi in squat e appoggia le mani a terra.',
    'pt': 'Comece em pé, depois agache e coloque as mãos no chão.',
    'es': 'Comienza de pie, luego agáchate y coloca las manos en el suelo.',
    'id': 'Mulai berdiri, lalu jongkok dan letakkan tangan di lantai.',
  },
  'exercise.burpee.step2': {
    'en': 'Jump your feet back into a high-plank position and perform one push-up.',
    'ru': 'Прыжком отбросьте ноги назад в упор лёжа и сделайте одно отжимание.',
    'de': 'Füße nach hinten springen in den hohen Plank und eine Liegestütze machen.',
    'fr': 'Projetez les pieds en arrière en position de planche haute et effectuez une pompe.',
    'it': 'Salta i piedi indietro in posizione di plank alto ed esegui un piegamento.',
    'pt': 'Salte os pés para trás até a posição de prancha alta e execute uma flexão.',
    'es': 'Salta los pies hacia atrás a la posición de plancha alta y realiza una flexión.',
    'id': 'Lompat kaki ke belakang ke posisi plank tinggi dan lakukan satu push-up.',
  },
  'exercise.burpee.step3': {
    'en': 'Jump your feet back to your hands and explode upward, reaching arms overhead.',
    'ru': 'Прыжком подтяните ноги к рукам и мощно выпрыгните вверх, вытянув руки над головой.',
    'de': 'Füße zurück zu den Händen springen und explosiv hochspringen, Arme über den Kopf strecken.',
    'fr': 'Ramenez les pieds vers les mains et explosez vers le haut en tendant les bras au-dessus de la tête.',
    'it': 'Salta i piedi verso le mani ed esplodi verso l\'alto, distendendo le braccia sopra la testa.',
    'pt': 'Salte os pés de volta para as mãos e exploda para cima, estendendo os braços acima da cabeça.',
    'es': 'Salta los pies de vuelta a las manos y explota hacia arriba, extendiendo los brazos sobre la cabeza.',
    'id': 'Lompat kaki kembali ke tangan dan meledak ke atas, rentangkan lengan di atas kepala.',
  },
  'exercise.burpee.step4': {
    'en': 'Land softly and immediately begin the next rep.',
    'ru': 'Приземлитесь мягко и сразу начинайте следующее повторение.',
    'de': 'Weich landen und sofort die nächste Wiederholung beginnen.',
    'fr': 'Atterrissez en douceur et commencez immédiatement la répétition suivante.',
    'it': 'Atterra in modo morbido e inizia immediatamente la ripetizione successiva.',
    'pt': 'Aterrissse suavemente e comece imediatamente a próxima repetição.',
    'es': 'Aterriza suavemente y comienza inmediatamente la siguiente repetición.',
    'id': 'Mendarat dengan lembut dan segera mulai repetisi berikutnya.',
  },
  'exercise.burpee.mistake1': {
    'en': 'Skipping the push-up — do a full push-up each rep for the full-body benefit.',
    'ru': 'Пропуск отжимания — выполняйте полное отжимание каждый раз для полноценной нагрузки.',
    'de': 'Liegestütze überspringen — bei jeder Wiederholung eine vollständige Liegestütze für den Ganzkörpernutzen machen.',
    'fr': 'Sauter la pompe — effectuez une pompe complète à chaque répétition pour un effet corps entier.',
    'it': 'Saltare il piegamento — esegui un piegamento completo ad ogni ripetizione per il beneficio su tutto il corpo.',
    'pt': 'Pular a flexão — execute uma flexão completa em cada repetição para o benefício de corpo inteiro.',
    'es': 'Saltarse la flexión — realiza una flexión completa en cada repetición para el beneficio de cuerpo completo.',
    'id': 'Melewati push-up — lakukan push-up penuh setiap repetisi untuk manfaat seluruh tubuh.',
  },

  // ---------------------------------------------------------------------------
  // front_squat — Фронтальный присед
  // ---------------------------------------------------------------------------
  'exercise.front_squat.step1': {
    'en': 'Rest the bar across your front deltoids and clavicles; hold it with a clean grip (four fingers under the bar) or crossed-arm grip, elbows high.',
    'ru': 'Положите гриф на передние дельты и ключицы; держите хватом снизу (четыре пальца под грифом) или скрещёнными руками, локти высоко.',
    'de': 'Die Stange auf die vorderen Deltamuskeln und Schlüsselbeine legen; mit dem Clean-Griff (vier Finger unter der Stange) oder Kreuzgriff halten, Ellenbogen hoch.',
    'fr': 'Posez la barre sur les deltoïdes avant et les clavicules ; tenez-la avec une prise propre (quatre doigts sous la barre) ou en bras croisés, coudes hauts.',
    'it': 'Appoggia il bilanciere sui deltoidi anteriori e le clavicole; tienilo con la presa pulita (quattro dita sotto il bilanciere) o a braccia incrociate, gomiti alti.',
  },
  'exercise.front_squat.step2': {
    'en': 'Stand with feet shoulder-width apart, toes slightly out; keep your elbows raised throughout — they drive the upright torso.',
    'ru': 'Ноги на ширине плеч, носки немного в стороны; локти держите высоко — они удерживают корпус вертикально.',
    'de': 'Füße schulterbreit, Zehen leicht auswärts; Ellenbogen während der gesamten Bewegung hochhalten — sie erzwingen den aufrechten Oberkörper.',
    'fr': 'Pieds écartés à la largeur des épaules, orteils légèrement ouverts ; gardez les coudes hauts tout au long — ils maintiennent le torse droit.',
    'it': 'Piedi alla larghezza delle spalle, punte leggermente verso l\'esterno; mantieni i gomiti alzati per tutto il movimento — tengono il busto eretto.',
  },
  'exercise.front_squat.step3': {
    'en': 'Brace your core, push your knees out and descend as deep as mobility allows — ideally below parallel.',
    'ru': 'Напрягите кор, разведите колени и опускайтесь как можно глубже — идеально ниже параллели.',
    'de': 'Core anspannen, Knie nach außen drücken und so tief absinken, wie die Mobilität erlaubt — idealerweise unter die Parallele.',
    'fr': 'Gainéz le tronc, poussez les genoux vers l\'extérieur et descendez aussi bas que la mobilité le permet — idéalement en dessous de la parallèle.',
    'it': 'Contrai il core, spingi le ginocchia verso l\'esterno e scendi quanto la mobilità consente — idealmente sotto il parallelo.',
  },
  'exercise.front_squat.step4': {
    'en': 'Drive through your whole foot to stand up; exhale as you lock out.',
    'ru': 'Давите всей стопой при подъёме; выдыхайте в верхней точке.',
    'de': 'Durch den ganzen Fuß hochdrücken; beim Durchstrecken ausatmen.',
    'fr': 'Poussez à travers tout le pied pour vous lever ; expirez au verrouillage.',
    'it': 'Spingi attraverso tutto il piede per alzarti; espira al blocco.',
  },
  'exercise.front_squat.mistake1': {
    'en': 'Elbows dropping — the bar will roll forward and strain your wrists; keep elbows parallel to the floor.',
    'ru': 'Локти опускаются — гриф съезжает вперёд и нагружает запястья; держите локти параллельно полу.',
    'de': 'Ellenbogen fallen ab — die Stange rollt nach vorne und belastet die Handgelenke; Ellenbogen parallel zum Boden halten.',
    'fr': 'Coudes qui s\'abaissent — la barre roule vers l\'avant et sollicite les poignets ; gardez les coudes parallèles au sol.',
    'it': 'Gomiti che scendono — il bilanciere scivola in avanti e affatica i polsi; mantieni i gomiti paralleli al pavimento.',
  },
  'exercise.front_squat.mistake2': {
    'en': 'Excessive forward lean — usually means poor thoracic mobility; work on upper-back flexibility.',
    'ru': 'Сильный наклон вперёд — признак недостаточной подвижности грудного отдела; развивайте гибкость верхней спины.',
    'de': 'Zu starke Vorwärtsneigung — meist schlechte Brustwirbelsäulenmobilität; Oberkörperbeweglichkeit verbessern.',
    'fr': 'Inclinaison excessive en avant — signe d\'une mauvaise mobilité thoracique ; travaillez la flexibilité du haut du dos.',
    'it': 'Eccessiva inclinazione in avanti — di solito indica scarsa mobilità toracica; lavora sulla flessibilità della parte alta della schiena.',
  },

  // ---------------------------------------------------------------------------
  // goblet_squat — Гоблет-присед
  // ---------------------------------------------------------------------------
  'exercise.goblet_squat.step1': {
    'en': 'Hold a kettlebell (or dumbbell) vertically at chest height with both hands cupped under the bell; stand with feet slightly wider than hip-width, toes out.',
    'ru': 'Держите гирю (или гантель) вертикально у груди обеими руками снизу; ноги чуть шире бёдер, носки в стороны.',
    'de': 'Eine Kettlebell (oder Hantel) senkrecht auf Brusthöhe mit beiden Händen von unten halten; Füße etwas breiter als hüftbreit, Zehen auswärts.',
    'fr': 'Tenez une kettlebell (ou haltère) verticalement à hauteur de poitrine avec les deux mains en coupe sous le poids ; pieds légèrement plus larges que les hanches, orteils tournés vers l\'extérieur.',
    'it': 'Tieni un kettlebell (o manubrio) verticalmente all\'altezza del petto con entrambe le mani a coppa sotto; piedi leggermente più larghi dei fianchi, punte verso l\'esterno.',
  },
  'exercise.goblet_squat.step2': {
    'en': 'Brace your core, push your knees outward and sit down between your heels — use your elbows to gently push the knees wider at the bottom.',
    'ru': 'Напрягите кор, разведите колени и опускайтесь между пятками — в нижней точке локтями слегка раздвигайте колени.',
    'de': 'Core anspannen, Knie nach außen drücken und zwischen die Fersen setzen — unten mit den Ellenbogen die Knie sanft weiter auseinander drücken.',
    'fr': 'Gainéz le tronc, poussez les genoux vers l\'extérieur et descendez entre vos talons — en bas, utilisez les coudes pour écarter doucement les genoux.',
    'it': 'Contrai il core, spingi le ginocchia verso l\'esterno e siediti tra i talloni — in basso usa i gomiti per spingere delicatamente le ginocchia più in fuori.',
  },
  'exercise.goblet_squat.step3': {
    'en': 'Keep your chest tall and drive through your heels to stand; squeeze your glutes at the top.',
    'ru': 'Держите грудь высоко и давите пятками в пол при подъёме; сожмите ягодицы наверху.',
    'de': 'Brust aufrecht halten und durch die Fersen hochdrücken; Gesäß oben anspannen.',
    'fr': 'Gardez la poitrine haute et poussez à travers les talons pour vous lever ; serrez les fessiers en haut.',
    'it': 'Mantieni il petto alto e spingi attraverso i talloni per alzarti; stringi i glutei in cima.',
  },
  'exercise.goblet_squat.mistake1': {
    'en': 'Heels rising — shift your weight back and improve ankle mobility.',
    'ru': 'Пятки отрываются — переместите вес назад и улучшайте подвижность голеностопа.',
    'de': 'Fersen heben sich — Gewicht nach hinten verlagern und Sprunggelenk-Mobilität verbessern.',
    'fr': 'Talons qui se soulèvent — transférez le poids vers l\'arrière et améliorez la mobilité des chevilles.',
    'it': 'I talloni si sollevano — sposta il peso indietro e migliora la mobilità della caviglia.',
  },

  // ---------------------------------------------------------------------------
  // walking_lunge — Выпады в ходьбе
  // ---------------------------------------------------------------------------
  'exercise.walking_lunge.step1': {
    'en': 'Stand tall holding a dumbbell in each hand (or hands free for beginners); step one foot forward about two feet.',
    'ru': 'Встаньте прямо с гантелями в руках (или без отягощения для новичков); сделайте шаг вперёд примерно на 60 см.',
    'de': 'Aufrecht stehen mit je einer Hantel in jeder Hand (oder ohne Gewicht für Anfänger); einen Fuß etwa 60 cm nach vorne setzen.',
    'fr': 'Tenez-vous droit en tenant un haltère dans chaque main (ou mains libres pour les débutants) ; faites un pas en avant d\'environ 60 cm.',
    'it': 'Stai in piedi con un manubrio in ogni mano (o a mani libere per i principianti); fai un passo in avanti di circa 60 cm.',
  },
  'exercise.walking_lunge.step2': {
    'en': 'Lower your rear knee toward the floor until both knees are at roughly 90°; keep your front knee over your ankle, not past your toes.',
    'ru': 'Опустите заднее колено к полу до угла примерно 90° в обоих суставах; переднее колено над лодыжкой, не выходит за носок.',
    'de': 'Hinteres Knie Richtung Boden senken, bis beide Knie ca. 90° haben; vorderes Knie über dem Knöchel, nicht über die Zehen hinaus.',
    'fr': 'Abaissez le genou arrière vers le sol jusqu\'à ce que les deux genoux soient à environ 90° ; genou avant au-dessus de la cheville, pas au-delà des orteils.',
    'it': 'Abbassa il ginocchio posteriore verso il pavimento finché entrambe le ginocchia sono a circa 90°; il ginocchio anteriore sopra la caviglia, non oltre le punte.',
  },
  'exercise.walking_lunge.step3': {
    'en': 'Drive through the front heel to rise, bringing the rear foot forward into the next step.',
    'ru': 'Давите передней пяткой в пол при подъёме, перенося заднюю ногу вперёд в следующий шаг.',
    'de': 'Durch die Vorderferse hochdrücken und den hinteren Fuß in den nächsten Schritt nach vorne bringen.',
    'fr': 'Poussez à travers le talon avant pour vous lever, en ramenant le pied arrière vers l\'avant pour le prochain pas.',
    'it': 'Spingi attraverso il tallone anteriore per alzarti, portando il piede posteriore in avanti per il passo successivo.',
  },
  'exercise.walking_lunge.mistake1': {
    'en': 'Torso leaning too far forward — keep your chest up and shoulders over your hips.',
    'ru': 'Корпус слишком наклоняется вперёд — держите грудь высоко, плечи над бёдрами.',
    'de': 'Oberkörper lehnt zu weit nach vorne — Brust oben halten, Schultern über den Hüften.',
    'fr': 'Torse trop incliné en avant — gardez la poitrine haute et les épaules au-dessus des hanches.',
    'it': 'Busto inclinato troppo in avanti — tieni il petto alto e le spalle sopra i fianchi.',
  },

  // ---------------------------------------------------------------------------
  // bulgarian_split_squat — Болгарский сплит-присед
  // ---------------------------------------------------------------------------
  'exercise.bulgarian_split_squat.step1': {
    'en': 'Stand about two feet in front of a bench; place the top of one foot on the bench behind you.',
    'ru': 'Встаньте примерно в 60 см перед скамьёй; положите тыльную поверхность стопы задней ноги на скамью.',
    'de': 'Ca. 60 cm vor einer Bank stehen; den Spann des hinteren Fußes auf die Bank legen.',
    'fr': 'Tenez-vous à environ 60 cm devant un banc ; posez le dessus d\'un pied sur le banc derrière vous.',
    'it': 'Stai a circa 60 cm davanti a una panca; appoggia il dorso del piede posteriore sulla panca.',
  },
  'exercise.bulgarian_split_squat.step2': {
    'en': 'Hold a dumbbell in each hand or keep hands at your sides; keep your chest up and core braced throughout.',
    'ru': 'Держите гантели в руках или опустите руки; грудь высоко, кор в напряжении на протяжении всего упражнения.',
    'de': 'Hanteln halten oder Hände an den Seiten lassen; Brust oben und Core während der gesamten Übung angespannt.',
    'fr': 'Tenez un haltère dans chaque main ou gardez les mains à vos côtés ; poitrine haute et gainage actif tout au long.',
    'it': 'Tieni un manubrio in ogni mano o lascia le mani ai lati; petto alto e core contratto per tutto l\'esercizio.',
  },
  'exercise.bulgarian_split_squat.step3': {
    'en': 'Lower your rear knee toward the floor by bending the front knee; front shin stays roughly vertical.',
    'ru': 'Опустите заднее колено к полу, сгибая переднее; голень передней ноги остаётся примерно вертикальной.',
    'de': 'Hinteres Knie Richtung Boden absenken, indem das vordere Knie gebeugt wird; Schienbein vorne bleibt annähernd vertikal.',
    'fr': 'Abaissez le genou arrière vers le sol en fléchissant le genou avant ; le tibia avant reste environ vertical.',
    'it': 'Abbassa il ginocchio posteriore verso il pavimento piegando il ginocchio anteriore; lo stinco anteriore rimane circa verticale.',
  },
  'exercise.bulgarian_split_squat.step4': {
    'en': 'Drive through your front heel to return to start; complete all reps on one side before switching.',
    'ru': 'Давите передней пяткой при подъёме; выполните все повторения на одну ногу, затем меняйте.',
    'de': 'Durch die Vorderferse zurückdrücken; alle Wiederholungen auf einer Seite vollenden, dann wechseln.',
    'fr': 'Poussez à travers le talon avant pour revenir au départ ; terminez toutes les répétitions d\'un côté avant de changer.',
    'it': 'Spingi attraverso il tallone anteriore per tornare all\'inizio; completa tutte le ripetizioni su un lato prima di cambiare.',
  },
  'exercise.bulgarian_split_squat.mistake1': {
    'en': 'Front knee caving inward — actively push it out in line with your toes.',
    'ru': 'Переднее колено заваливается внутрь — активно толкайте его наружу по линии носка.',
    'de': 'Vorderes Knie fällt nach innen — aktiv in Richtung Zehen nach außen drücken.',
    'fr': 'Genou avant qui rentre vers l\'intérieur — poussez-le activement vers l\'extérieur dans l\'axe des orteils.',
    'it': 'Il ginocchio anteriore cede verso l\'interno — spingi attivamente verso l\'esterno in linea con le punte.',
  },
  'exercise.bulgarian_split_squat.mistake2': {
    'en': 'Standing too close to the bench — creates excessive knee travel and hip flexor strain; step further forward.',
    'ru': 'Слишком близко к скамье — колено уходит далеко вперёд, перегружая сгибатели бедра; отступите дальше.',
    'de': 'Zu nah an der Bank stehen — verursacht übermäßigen Kniebewegung und Hüftbeuger-Belastung; weiter vortreten.',
    'fr': 'Trop près du banc — provoque un déplacement excessif du genou et une tension des fléchisseurs de hanche ; faites un pas plus en avant.',
    'it': 'Troppo vicino alla panca — causa eccessivo spostamento del ginocchio e tensione ai flessori dell\'anca; fai un passo più avanti.',
  },

  // ---------------------------------------------------------------------------
  // leg_press — Жим ногами
  // ---------------------------------------------------------------------------
  'exercise.leg_press.step1': {
    'en': 'Sit in the machine with your back flat against the pad; place feet shoulder-width apart in the middle of the platform.',
    'ru': 'Сядьте в тренажёр, прижав спину к подушке; поставьте стопы на ширине плеч в середине платформы.',
    'de': 'Im Gerät sitzen, Rücken flach an der Polsterung; Füße schulterbreit in der Mitte der Plattform.',
    'fr': 'Asseyez-vous dans la machine, dos à plat contre le rembourrage ; placez les pieds à la largeur des épaules au centre de la plateforme.',
    'it': 'Siediti nella macchina con la schiena piatta contro il cuscinetto; posiziona i piedi alla larghezza delle spalle al centro della piattaforma.',
  },
  'exercise.leg_press.step2': {
    'en': 'Release the safety handles, lower the platform by bending your knees to about 90° — lower back stays flat.',
    'ru': 'Снимите с упоров, опустите платформу, сгибая колени до ~90°; поясница прижата к спинке.',
    'de': 'Sicherheitsgriffe lösen, Plattform durch Beugen der Knie auf ca. 90° absenken — Lendenwirbelsäule bleibt flach.',
    'fr': 'Relâchez les poignées de sécurité, abaissez la plateforme en fléchissant les genoux à environ 90° — le bas du dos reste à plat.',
    'it': 'Rilascia le maniglie di sicurezza, abbassa la piattaforma piegando le ginocchia a circa 90° — la zona lombare rimane piatta.',
  },
  'exercise.leg_press.step3': {
    'en': 'Press the platform back up through your heels without fully locking out your knees at the top.',
    'ru': 'Давите платформу пятками до упора, не разгибая колени полностью в верхней точке.',
    'de': 'Plattform durch die Fersen hochdrücken, ohne die Knie oben vollständig durchzustrecken.',
    'fr': 'Repoussez la plateforme à travers les talons sans verrouiller complètement les genoux en haut.',
    'it': 'Premi la piattaforma verso l\'alto attraverso i talloni senza bloccare completamente le ginocchia in cima.',
  },
  'exercise.leg_press.mistake1': {
    'en': 'Lower back rounding off the pad — reduce the depth or the load until you can keep contact.',
    'ru': 'Поясница отрывается от спинки — уменьшите глубину или вес, пока не сможете удержать поясницу прижатой.',
    'de': 'Lendenwirbelsäule hebt vom Polster ab — Tiefe oder Gewicht reduzieren, bis der Kontakt gehalten werden kann.',
    'fr': 'Bas du dos qui se décolle du rembourrage — réduisez la profondeur ou la charge jusqu\'à pouvoir maintenir le contact.',
    'it': 'La zona lombare si stacca dal cuscinetto — riduci la profondità o il carico finché riesci a mantenere il contatto.',
  },
  'exercise.leg_press.mistake2': {
    'en': 'Feet too low on the platform — shifts stress to the knees; move them to mid-plate or higher.',
    'ru': 'Стопы слишком низко на платформе — нагрузка переходит на колени; ставьте выше к середине или верху.',
    'de': 'Füße zu weit unten auf der Plattform — verlagert Stress auf die Knie; Füße zur Mitte oder höher stellen.',
    'fr': 'Pieds trop bas sur la plateforme — transfère le stress aux genoux ; placez-les au milieu ou plus haut.',
    'it': 'Piedi troppo bassi sulla piattaforma — sposta lo stress sulle ginocchia; spostali a metà piattaforma o più in alto.',
  },

  // ---------------------------------------------------------------------------
  // romanian_deadlift — Румынская становая тяга
  // ---------------------------------------------------------------------------
  'exercise.romanian_deadlift.step1': {
    'en': 'Stand with feet hip-width apart holding the bar (or dumbbells) against your thighs, overhand grip.',
    'ru': 'Ноги на ширине бёдер, гриф (или гантели) у бёдер прямым хватом.',
    'de': 'Füße hüftbreit, Stange (oder Hanteln) mit Obergriff gegen die Oberschenkel halten.',
    'fr': 'Pieds écartés à la largeur des hanches, barre (ou haltères) contre les cuisses en prise pronée.',
    'it': 'Piedi alla larghezza dei fianchi, bilanciere (o manubri) contro le cosce con presa prona.',
  },
  'exercise.romanian_deadlift.step2': {
    'en': 'Push your hips backward and hinge forward, keeping the bar close to your legs — stop when you feel a strong hamstring stretch (usually shins vertical).',
    'ru': 'Отведите бёдра назад и наклонитесь вперёд, держа гриф близко к ногам — остановитесь при ощутимом растяжении бицепса бедра (голени вертикальны).',
    'de': 'Hüfte nach hinten schieben und vorwärts beugen, Stange nah an den Beinen halten — aufhören, wenn ein starkes Dehngefühl in den Oberschenkelrückseiten entsteht (Schienbeine vertikal).',
    'fr': 'Poussez les hanches vers l\'arrière et charnière en avant, barre proche des jambes — arrêtez quand vous sentez un fort étirement des ischio-jambiers (tibias verticaux).',
    'it': 'Spingi i fianchi indietro e inclina in avanti, tenendo il bilanciere vicino alle gambe — fermati quando senti un forte stretching dei bicipiti femorali (stinchi verticali).',
  },
  'exercise.romanian_deadlift.step3': {
    'en': 'Maintain a neutral spine and flat back throughout — no rounding.',
    'ru': 'Держите нейтральный позвоночник и прямую спину на протяжении всего движения.',
    'de': 'Neutrale Wirbelsäule und geraden Rücken während der gesamten Bewegung halten — kein Rundrücken.',
    'fr': 'Maintenez une colonne vertébrale neutre et un dos plat tout au long — pas d\'arrondi.',
    'it': 'Mantieni la colonna vertebrale neutra e la schiena piatta per tutto il movimento — niente arrotondamento.',
  },
  'exercise.romanian_deadlift.step4': {
    'en': 'Drive hips forward to return to standing; squeeze your glutes at the top.',
    'ru': 'Толкните бёдра вперёд, возвращаясь в стойку; сожмите ягодицы наверху.',
    'de': 'Hüfte nach vorne treiben, um aufzustehen; Gesäß oben anspannen.',
    'fr': 'Projetez les hanches vers l\'avant pour revenir debout ; serrez les fessiers en haut.',
    'it': 'Spingi i fianchi in avanti per tornare in piedi; stringi i glutei in cima.',
  },
  'exercise.romanian_deadlift.mistake1': {
    'en': 'Rounding the lower back — reduce the range of motion until your back stays flat.',
    'ru': 'Скругление поясницы — уменьшите амплитуду до сохранения прямой спины.',
    'de': 'Rundrücken im Lendenwirbelbereich — Bewegungsamplitude reduzieren, bis der Rücken gerade bleibt.',
    'fr': 'Dos lombaire arrondi — réduisez l\'amplitude jusqu\'à ce que le dos reste plat.',
    'it': 'Schiena lombare arrotondata — riduci il range of motion finché la schiena rimane piatta.',
  },
  'exercise.romanian_deadlift.mistake2': {
    'en': 'Bar drifting away from the legs — keep it dragging along your thighs and shins.',
    'ru': 'Гриф уходит от ног — ведите его вдоль бёдер и голеней на протяжении всего движения.',
    'de': 'Stange driftet von den Beinen weg — sie muss die Oberschenkel und Schienbeine entlangschaben.',
    'fr': 'La barre s\'éloigne des jambes — gardez-la en glissant le long des cuisses et des tibias.',
    'it': 'Il bilanciere si allontana dalle gambe — tienilo a strisciare lungo le cosce e gli stinchi.',
  },

  // ---------------------------------------------------------------------------
  // leg_curl — Сгибание ног в тренажёре
  // ---------------------------------------------------------------------------
  'exercise.leg_curl.step1': {
    'en': 'Lie face-down on the machine; position the pad just above your heels and hold the handles.',
    'ru': 'Лягте лицом вниз на тренажёр; подложите валик чуть выше пяток, держитесь за ручки.',
    'de': 'Bäuchlings auf das Gerät legen; Polster knapp über den Fersen positionieren und Griffe festhalten.',
    'fr': 'Allongez-vous face vers le bas sur la machine ; positionnez le rembourrage juste au-dessus des talons et tenez les poignées.',
    'it': 'Sdraiati a faccia in giù sulla macchina; posiziona il cuscinetto appena sopra i talloni e tieni le maniglie.',
  },
  'exercise.leg_curl.step2': {
    'en': 'Curl both legs up toward your glutes in a smooth arc, squeezing the hamstrings at the top.',
    'ru': 'Сгибайте обе ноги к ягодицам по плавной дуге, сжимая бицепс бедра в верхней точке.',
    'de': 'Beide Beine in gleichmäßigem Bogen zur Gesäßmuskulatur anziehen, Oberschenkelrückseiten oben anspannen.',
    'fr': 'Fléchissez les deux jambes vers les fessiers en arc fluide, en contractant les ischio-jambiers en haut.',
    'it': 'Piega entrambe le gambe verso i glutei in un arco fluido, contraendo i bicipiti femorali in cima.',
  },
  'exercise.leg_curl.step3': {
    'en': 'Lower the pad slowly back to the start — resist the weight on the way down.',
    'ru': 'Медленно опустите валик в исходное положение, сопротивляясь весу на пути вниз.',
    'de': 'Polster langsam in die Ausgangsposition absenken — dem Gewicht auf dem Weg nach unten widerstehen.',
    'fr': 'Rabaissez lentement le rembourrage au point de départ — résistez au poids dans la descente.',
    'it': 'Abbassa lentamente il cuscinetto alla posizione di partenza — resisti al peso durante la discesa.',
  },
  'exercise.leg_curl.mistake1': {
    'en': 'Hips rising off the pad — reduce the weight and keep your pelvis flat throughout.',
    'ru': 'Бёдра отрываются от подушки — снизьте вес и держите таз прижатым на протяжении всего движения.',
    'de': 'Hüften heben sich vom Polster ab — Gewicht reduzieren und Becken während der gesamten Bewegung flach halten.',
    'fr': 'Hanches qui se soulèvent du rembourrage — réduisez le poids et gardez le bassin à plat tout au long.',
    'it': 'I fianchi si sollevano dal cuscinetto — riduci il peso e tieni il bacino piatto per tutto il movimento.',
  },

  // ---------------------------------------------------------------------------
  // leg_extension — Разгибание ног в тренажёре
  // ---------------------------------------------------------------------------
  'exercise.leg_extension.step1': {
    'en': 'Sit in the machine with your back against the pad; hook your ankles under the lower pad, knees at 90°.',
    'ru': 'Сядьте в тренажёр, прижав спину; зацепите лодыжки под нижний валик, колени под углом 90°.',
    'de': 'Im Gerät sitzen, Rücken ans Polster; Knöchel unter das untere Polster haken, Knie 90°.',
    'fr': 'Asseyez-vous dans la machine, dos contre le rembourrage ; accrochez les chevilles sous le rembourrage inférieur, genoux à 90°.',
    'it': 'Siediti nella macchina con la schiena contro il cuscinetto; aggancia le caviglie sotto il cuscinetto inferiore, ginocchia a 90°.',
  },
  'exercise.leg_extension.step2': {
    'en': 'Extend both legs until straight, squeezing your quads at the top; hold briefly.',
    'ru': 'Разгибайте обе ноги до прямого положения, сжимая квадрицепс наверху; задержитесь на мгновение.',
    'de': 'Beide Beine bis zur Streckung ausstrecken, Quadrizeps oben anspannen; kurz halten.',
    'fr': 'Étendez les deux jambes jusqu\'à ce qu\'elles soient droites, contractez les quadriceps en haut ; maintenez brièvement.',
    'it': 'Estendi entrambe le gambe fino a raddrizzarle, contraendo i quadricipiti in cima; tieni brevemente.',
  },
  'exercise.leg_extension.step3': {
    'en': 'Lower the weight slowly — 2–3 seconds — back to 90°.',
    'ru': 'Медленно опускайте вес — 2–3 секунды — до угла 90°.',
    'de': 'Gewicht langsam — 2–3 Sekunden — zurück auf 90° absenken.',
    'fr': 'Abaissez le poids lentement — 2 à 3 secondes — pour revenir à 90°.',
    'it': 'Abbassa il peso lentamente — 2–3 secondi — fino a 90°.',
  },
  'exercise.leg_extension.mistake1': {
    'en': 'Using momentum to swing the weight up — slow down and control both phases of the rep.',
    'ru': 'Использование инерции — замедлитесь и контролируйте обе фазы движения.',
    'de': 'Schwung nutzen um das Gewicht hochzuschwingen — verlangsamen und beide Phasen der Wiederholung kontrollieren.',
    'fr': 'Utiliser l\'élan pour balancer le poids — ralentissez et contrôlez les deux phases de la répétition.',
    'it': 'Usare lo slancio per alzare il peso — rallenta e controlla entrambe le fasi della ripetizione.',
  },

  // ---------------------------------------------------------------------------
  // standing_calf_raise — Подъём на носки стоя
  // ---------------------------------------------------------------------------
  'exercise.standing_calf_raise.step1': {
    'en': 'Stand on the edge of a step or calf-raise platform with the balls of your feet on the edge and heels hanging off.',
    'ru': 'Встаньте на край ступеньки или платформы тренажёра: подушечки стоп на краю, пятки свисают.',
    'de': 'Auf die Kante einer Stufe oder Wadenpress-Plattform stellen: Fußballen auf der Kante, Fersen hängen ab.',
    'fr': 'Tenez-vous sur le bord d\'une marche ou d\'une plateforme avec les avant-pieds sur le bord et les talons dans le vide.',
    'it': 'Stai sul bordo di un gradino o di una piattaforma con gli avampiedi sul bordo e i talloni che pendono.',
  },
  'exercise.standing_calf_raise.step2': {
    'en': 'Lower your heels as far as comfortable to feel a full stretch in your calves.',
    'ru': 'Опустите пятки как можно ниже, ощущая полное растяжение икроножных мышц.',
    'de': 'Fersen so weit wie möglich absenken, um die Waden vollständig zu dehnen.',
    'fr': 'Abaissez les talons aussi bas que confortable pour ressentir un étirement complet des mollets.',
    'it': 'Abbassa i talloni il più possibile per sentire uno stretching completo nei polpacci.',
  },
  'exercise.standing_calf_raise.step3': {
    'en': 'Rise up onto your toes as high as possible, squeezing your calves at the top; lower slowly.',
    'ru': 'Поднимитесь на носки максимально высоко, сжимая икры наверху; опускайтесь медленно.',
    'de': 'So hoch wie möglich auf die Zehenspitzen steigen, Waden oben anspannen; langsam absenken.',
    'fr': 'Montez sur les pointes aussi haut que possible en contractant les mollets en haut ; redescendez lentement.',
    'it': 'Alzati sulle punte il più in alto possibile, contraendo i polpacci in cima; abbassa lentamente.',
  },
  'exercise.standing_calf_raise.mistake1': {
    'en': 'Bouncing at the bottom — pause at full stretch to load the tissue properly.',
    'ru': 'Отскок внизу — сделайте паузу в полном растяжении для правильной нагрузки на мышцу.',
    'de': 'Abprallen unten — in der vollständigen Dehnung pausieren, um das Gewebe richtig zu belasten.',
    'fr': 'Rebondir en bas — faites une pause en étirement complet pour charger correctement le tissu.',
    'it': 'Rimbalzare in basso — fai una pausa a stretching completo per caricare correttamente il tessuto.',
  },

  // ---------------------------------------------------------------------------
  // hip_thrust — Ягодичный мост со штангой
  // ---------------------------------------------------------------------------
  'exercise.hip_thrust.step1': {
    'en': 'Sit with your upper back against a bench; roll a padded barbell over your hips; plant feet flat, hip-width apart.',
    'ru': 'Прислонитесь верхней частью спины к скамье; накатите мягко зафиксированную штангу на бёдра; стопы на полу на ширине бёдер.',
  },
  'exercise.hip_thrust.step2': {
    'en': 'Brace your core, tuck your chin slightly and drive through your heels to thrust your hips upward.',
    'ru': 'Напрягите кор, слегка опустите подбородок и давите пятками, поднимая таз вверх.',
  },
  'exercise.hip_thrust.step3': {
    'en': 'At the top, your torso from shoulders to knees should be parallel to the floor; squeeze your glutes hard for 1 second.',
    'ru': 'В верхней точке корпус от плеч до колен параллелен полу; сильно сожмите ягодицы на 1 секунду.',
  },
  'exercise.hip_thrust.step4': {
    'en': 'Lower your hips under control until they almost touch the floor, then drive back up.',
    'ru': 'Медленно опустите таз почти до пола и снова поднимайте.',
  },
  'exercise.hip_thrust.mistake1': {
    'en': 'Hyperextending the lower back at the top — stop when hips are level, ribs down.',
    'ru': 'Переразгибание поясницы наверху — останавливайтесь, когда таз ровный, рёбра опущены.',
  },
  'exercise.hip_thrust.mistake2': {
    'en': 'Feet too far or too close — shins should be vertical when hips are fully extended.',
    'ru': 'Стопы слишком далеко или близко — голени должны быть вертикальны в верхней точке.',
  },

  // ---------------------------------------------------------------------------
  // chin_up — Подтягивания обратным хватом
  // ---------------------------------------------------------------------------
  'exercise.chin_up.step1': {
    'en': 'Hang from the bar with a supinated (underhand) grip, hands shoulder-width apart.',
    'ru': 'Возьмитесь за перекладину обратным хватом (ладони к себе) на ширине плеч.',
  },
  'exercise.chin_up.step2': {
    'en': 'Initiate by depressing your shoulder blades, then pull your chest toward the bar until your chin clears it.',
    'ru': 'Начните с опускания лопаток, затем тяните грудь к перекладине, пока подбородок не окажется выше неё.',
  },
  'exercise.chin_up.step3': {
    'en': 'Lower yourself slowly to a full dead hang, feeling the biceps and lats working eccentrically.',
    'ru': 'Медленно опуститесь в полный вис, ощущая эксцентричную работу бицепсов и широчайших.',
  },
  'exercise.chin_up.mistake1': {
    'en': 'Elbow flaring outward — keep them tucked close to your torso throughout.',
    'ru': 'Локти уходят в стороны — держите их близко к корпусу на протяжении всего движения.',
  },
  'exercise.chin_up.mistake2': {
    'en': 'Short range of motion — start from a full hang and get the chin fully over the bar each rep.',
    'ru': 'Неполная амплитуда — начинайте из полного виса и поднимайтесь выше перекладины каждый раз.',
  },

  // ---------------------------------------------------------------------------
  // lat_pulldown — Тяга верхнего блока
  // ---------------------------------------------------------------------------
  'exercise.lat_pulldown.step1': {
    'en': 'Sit at the machine with thighs secured under the pads; grip the bar wider than shoulder-width, palms facing forward.',
    'ru': 'Сядьте в тренажёр, зафиксировав бёдра под валиками; возьмите гриф шире плеч прямым хватом.',
  },
  'exercise.lat_pulldown.step2': {
    'en': 'Lean back slightly (~15°), depress your shoulder blades, then pull the bar to your upper chest.',
    'ru': 'Слегка наклонитесь назад (~15°), опустите лопатки, затем тяните гриф к верхней части груди.',
  },
  'exercise.lat_pulldown.step3': {
    'en': 'Hold briefly at the bottom, squeezing your lats; let the bar rise slowly back to full arm extension.',
    'ru': 'Задержитесь в нижней точке, сжимая широчайшие; медленно верните гриф в исходное положение.',
  },
  'exercise.lat_pulldown.step4': {
    'en': 'Control the eccentric — resist the weight as your arms straighten fully.',
    'ru': 'Контролируйте эксцентрическую фазу — сопротивляйтесь весу при выпрямлении рук.',
  },
  'exercise.lat_pulldown.mistake1': {
    'en': 'Pulling behind the neck — puts stress on the cervical spine; always pull to the front.',
    'ru': 'Тяга за голову — нагружает шейный отдел; всегда тяните к груди.',
  },
  'exercise.lat_pulldown.mistake2': {
    'en': 'Using body momentum to swing the weight — reduce the load and focus on lats.',
    'ru': 'Раскачка корпуса для инерции — снизьте вес и сосредоточьтесь на широчайших.',
  },

  // ---------------------------------------------------------------------------
  // seated_cable_row — Тяга нижнего блока сидя
  // ---------------------------------------------------------------------------
  'exercise.seated_cable_row.step1': {
    'en': 'Sit upright on the bench with feet on the footrests and a slight knee bend; grip the handle with both hands.',
    'ru': 'Сядьте прямо, стопы на упорах, ноги слегка согнуты в коленях; возьмите рукоять обеими руками.',
  },
  'exercise.seated_cable_row.step2': {
    'en': 'Keep your back upright, retract your shoulder blades and pull the handle to your lower abdomen, driving elbows back.',
    'ru': 'Держите спину прямой, сведите лопатки и тяните рукоять к нижней части живота, отводя локти назад.',
  },
  'exercise.seated_cable_row.step3': {
    'en': 'Return the handle to the start with control, allowing a full stretch in your lats without rounding your back.',
    'ru': 'Верните рукоять с контролем, позволяя полному растяжению широчайших, не скругляя спину.',
  },
  'exercise.seated_cable_row.mistake1': {
    'en': 'Rocking the torso back and forth — keep your upper body still; the power comes from your back.',
    'ru': 'Раскачка корпуса вперёд-назад — держите верхнюю часть тела неподвижной; сила идёт от спины.',
  },
  'exercise.seated_cable_row.mistake2': {
    'en': 'Pulling to the chest (upper row) — aim for the lower abdomen to target the lats and mid-back.',
    'ru': 'Тяга к груди — тяните к нижней части живота для прокачки широчайших и средней части спины.',
  },

  // ---------------------------------------------------------------------------
  // face_pull — Тяга к лицу
  // ---------------------------------------------------------------------------
  'exercise.face_pull.step1': {
    'en': 'Set the cable at upper-chest or eye height with a rope attachment; grip the ends with palms facing in.',
    'ru': 'Установите трос на уровне верхней части груди или глаз; возьмитесь за концы каната ладонями внутрь.',
  },
  'exercise.face_pull.step2': {
    'en': 'Step back to create tension; pull the rope toward your face, flaring your elbows out to the sides and externally rotating your shoulders.',
    'ru': 'Отступите назад, создав натяжение; тяните канат к лицу, разводя локти в стороны и разворачивая плечи наружу.',
  },
  'exercise.face_pull.step3': {
    'en': 'Hold the end position for 1 second, then extend arms back out with control.',
    'ru': 'Задержитесь в конечном положении на 1 секунду, затем с контролем верните руки.',
  },
  'exercise.face_pull.mistake1': {
    'en': 'Elbows staying low (pulling down) — raise them to shoulder height to target the rear delts and rotator cuff.',
    'ru': 'Локти остаются низко (тяга вниз) — поднимите их до уровня плеч для нагрузки задних дельт и вращательной манжеты.',
  },

  // ---------------------------------------------------------------------------
  // t_bar_row — Тяга Т-образного грифа
  // ---------------------------------------------------------------------------
  'exercise.t_bar_row.step1': {
    'en': 'Stand over the T-bar with feet hip-width apart; hinge forward 45–60°, keeping your back flat.',
    'ru': 'Встаньте над Т-образным грифом, ноги на ширине бёдер; наклонитесь на 45–60°, спина прямая.',
  },
  'exercise.t_bar_row.step2': {
    'en': 'Grip the handles and brace your core; retract your shoulder blades before pulling.',
    'ru': 'Возьмитесь за ручки и напрягите кор; сведите лопатки перед началом тяги.',
  },
  'exercise.t_bar_row.step3': {
    'en': 'Pull the weight toward your lower chest, driving elbows back and squeezing your back at the top.',
    'ru': 'Тяните вес к нижней части груди, отводя локти назад и сжимая спину в верхней точке.',
  },
  'exercise.t_bar_row.step4': {
    'en': 'Lower the weight slowly to full arm extension without rounding your back.',
    'ru': 'Медленно опускайте вес до полного выпрямления рук, не скругляя спину.',
  },
  'exercise.t_bar_row.mistake1': {
    'en': 'Loading too much weight and using body swing — reduce load and keep the torso angle steady.',
    'ru': 'Слишком большой вес и раскачка — снизьте нагрузку и удерживайте угол наклона корпуса.',
  },
  'exercise.t_bar_row.mistake2': {
    'en': 'Rounding the lower back — hold your brace throughout; drop the weight if you cannot.',
    'ru': 'Скругление поясницы — удерживайте напряжение на протяжении всего подхода; снизьте вес если не получается.',
  },

  // ---------------------------------------------------------------------------
  // incline_barbell_bench_press — Жим штанги на наклонной скамье
  // ---------------------------------------------------------------------------
  'exercise.incline_barbell_bench_press.step1': {
    'en': 'Set the bench to 30–45°; lie back with shoulder blades retracted and feet flat on the floor.',
    'ru': 'Установите скамью под углом 30–45°; лягте, сведя лопатки, стопы на полу.',
  },
  'exercise.incline_barbell_bench_press.step2': {
    'en': 'Grip the bar slightly wider than shoulders; unrack and bring it over your upper chest.',
    'ru': 'Возьмите гриф чуть шире плеч; снимите со стоек и держите над верхней частью груди.',
  },
  'exercise.incline_barbell_bench_press.step3': {
    'en': 'Lower the bar under control to the upper chest — about 1 inch of touch.',
    'ru': 'Опускайте гриф с контролем до касания верхней части груди.',
  },
  'exercise.incline_barbell_bench_press.step4': {
    'en': 'Press back up, exhaling as you lock out; keep the arc path close to vertical.',
    'ru': 'Выжмите гриф вверх, выдыхая при выпрямлении; траектория близка к вертикали.',
  },
  'exercise.incline_barbell_bench_press.mistake1': {
    'en': 'Bench angle too steep (>45°) — turns it into a shoulder press, reducing chest activation.',
    'ru': 'Угол скамьи слишком велик (>45°) — упражнение превращается в жим над головой, снижая нагрузку на грудь.',
  },
  'exercise.incline_barbell_bench_press.mistake2': {
    'en': 'Lowering the bar to the lower chest — keep it at the clavicle/upper pec region for incline.',
    'ru': 'Гриф опускается к нижней части груди — на наклонной скамье целевая зона — ключица и верхние грудные.',
  },

  // ---------------------------------------------------------------------------
  // incline_dumbbell_press — Жим гантелей на наклонной скамье
  // ---------------------------------------------------------------------------
  'exercise.incline_dumbbell_press.step1': {
    'en': 'Set the bench to 30–45°; sit with a dumbbell on each thigh, then kick them up to chest level as you lie back.',
    'ru': 'Наклоните скамью 30–45°; сядьте с гантелями на коленях, затем «закиньте» их к груди, откидываясь назад.',
  },
  'exercise.incline_dumbbell_press.step2': {
    'en': 'Press both dumbbells up and slightly inward until arms are extended; lower slowly to chest level, elbows ~45°.',
    'ru': 'Выжмите обе гантели вверх и слегка внутрь до выпрямления рук; медленно опустите до уровня груди, локти ~45°.',
  },
  'exercise.incline_dumbbell_press.step3': {
    'en': 'Feel the stretch at the bottom, then press again — don\'t bounce the dumbbells off your chest.',
    'ru': 'Ощутите растяжку в нижней точке и снова жмите — не отбивайте гантели от груди.',
  },
  'exercise.incline_dumbbell_press.mistake1': {
    'en': 'Dumbbells flaring out too wide — keep elbows at ~45° to protect the shoulder joint.',
    'ru': 'Гантели уходят слишком широко — держите локти под углом ~45° для защиты плечевого сустава.',
  },

  // ---------------------------------------------------------------------------
  // chest_dip — Отжимания на брусьях (грудь)
  // ---------------------------------------------------------------------------
  'exercise.chest_dip.step1': {
    'en': 'Grip the parallel bars and lock out your arms; lean your torso forward 20–30° to shift focus to the chest.',
    'ru': 'Возьмитесь за параллельные брусья на вытянутых руках; наклоните корпус на 20–30° вперёд для акцента на грудь.',
  },
  'exercise.chest_dip.step2': {
    'en': 'Lower yourself by bending your elbows until your upper arms are roughly parallel to the floor; feel the chest stretch.',
    'ru': 'Опускайтесь, сгибая локти, пока плечи не станут примерно параллельны полу; ощутите растяжку грудных.',
  },
  'exercise.chest_dip.step3': {
    'en': 'Press back up through your palms to full extension, exhaling at the top.',
    'ru': 'Выжмите себя ладонями до полного выпрямления рук, выдыхая наверху.',
  },
  'exercise.chest_dip.mistake1': {
    'en': 'Staying too upright — a vertical torso turns this into a triceps dip; lean forward for chest emphasis.',
    'ru': 'Слишком вертикальный корпус — превращает упражнение в трицепсовое; наклонитесь вперёд для акцента на грудь.',
  },
  'exercise.chest_dip.mistake2': {
    'en': 'Partial range of motion — lower until upper arms are parallel to the floor for full pec activation.',
    'ru': 'Неполная амплитуда — опускайтесь до параллели плеч с полом для полной активации грудных мышц.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_fly — Разведение гантелей лёжа
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_fly.step1': {
    'en': 'Lie on a flat bench holding a dumbbell in each hand directly above your chest, palms facing each other and elbows slightly bent.',
    'ru': 'Лягте на горизонтальную скамью с гантелями над грудью, ладони смотрят друг на друга, локти слегка согнуты.',
  },
  'exercise.dumbbell_fly.step2': {
    'en': 'With a controlled arc, lower the dumbbells out to the sides until you feel a deep stretch across your chest — maintain the slight elbow bend throughout.',
    'ru': 'По дуге с контролем разводите гантели в стороны до ощутимого растяжения грудных — сохраняйте небольшой изгиб локтей.',
  },
  'exercise.dumbbell_fly.step3': {
    'en': 'Squeeze your chest to bring the dumbbells back together over your sternum; exhale as you close.',
    'ru': 'Сведите гантели обратно над грудиной, напрягая грудные мышцы; выдыхайте при сведении.',
  },
  'exercise.dumbbell_fly.mistake1': {
    'en': 'Straightening the arms — this turns it into a press and risks elbow injury; keep a fixed bend.',
    'ru': 'Выпрямление рук — превращает упражнение в жим и нагружает локти; держите фиксированный изгиб.',
  },
  'exercise.dumbbell_fly.mistake2': {
    'en': 'Going too heavy and losing arc control — use a weight you can lower slowly over 3 seconds.',
    'ru': 'Слишком большой вес и потеря дуговой траектории — используйте вес, который можно опускать медленно за 3 секунды.',
  },

  // ---------------------------------------------------------------------------
  // cable_crossover — Кроссовер на блоках
  // ---------------------------------------------------------------------------
  'exercise.cable_crossover.step1': {
    'en': 'Set both cable pulleys to the high position and attach single handles; stand in the center, one foot slightly forward, and grab a handle in each hand.',
    'ru': 'Установите оба блока в верхнее положение, закрепите одиночные рукояти; встаньте в центре, одна нога слегка вперёд, возьмите рукоять в каждую руку.',
  },
  'exercise.cable_crossover.step2': {
    'en': 'With a slight bend in the elbows, bring your hands together in a sweeping arc downward and inward until they meet at hip level — feel the chest squeeze.',
    'ru': 'С небольшим сгибом в локтях сведите руки по дуге вниз и вперёд до уровня бёдер — ощутите сокращение грудных.',
  },
  'exercise.cable_crossover.step3': {
    'en': 'Slowly return to the start, allowing a full stretch; do not let the weight stack crash.',
    'ru': 'Медленно вернитесь в исходное положение, ощущая полное растяжение; не бросайте вес резко.',
  },
  'exercise.cable_crossover.mistake1': {
    'en': 'Pulling with your arms rather than squeezing the chest — focus on leading the movement from the pec, not the bicep.',
    'ru': 'Тяга руками вместо сокращения груди — ведите движение грудными мышцами, а не бицепсами.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_shoulder_press — Жим гантелей сидя
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_shoulder_press.step1': {
    'en': 'Sit on a bench with back support, holding a dumbbell in each hand at shoulder height, palms facing forward and elbows at roughly 90°.',
    'ru': 'Сядьте на скамью со спинкой, гантели на уровне плеч, ладони вперёд, локти примерно под 90°.',
  },
  'exercise.dumbbell_shoulder_press.step2': {
    'en': 'Press both dumbbells overhead in a slight arc until arms are fully extended, then lower under control back to start.',
    'ru': 'Выжмите обе гантели вверх по небольшой дуге до полного выпрямления рук, затем с контролем опустите.',
  },
  'exercise.dumbbell_shoulder_press.step3': {
    'en': 'Exhale as you press; maintain a tight core and avoid flaring your ribs or arching excessively.',
    'ru': 'Выдыхайте при жиме; удерживайте кор и не разворачивайте рёбра наружу и не прогибайте поясницу.',
  },
  'exercise.dumbbell_shoulder_press.mistake1': {
    'en': 'Letting dumbbells drift too far forward — keep them in a vertical line above the shoulder joints.',
    'ru': 'Гантели уходят вперёд — держите их в вертикальной плоскости над плечевыми суставами.',
  },
  'exercise.dumbbell_shoulder_press.mistake2': {
    'en': 'Excessive lower back arch — engage your core and keep your back flat against the bench.',
    'ru': 'Чрезмерный прогиб поясницы — напрягите кор и прижмите спину к спинке скамьи.',
  },

  // ---------------------------------------------------------------------------
  // lateral_raise — Махи гантелями в стороны
  // ---------------------------------------------------------------------------
  'exercise.lateral_raise.step1': {
    'en': 'Stand (or sit) holding a dumbbell in each hand at your sides, palms facing your thighs; maintain a soft bend in the elbows.',
    'ru': 'Встаньте (или сядьте) с гантелями у бёдер, ладони к бёдрам; сохраняйте небольшой изгиб в локтях.',
  },
  'exercise.lateral_raise.step2': {
    'en': 'Raise both arms out to the sides in a controlled arc until they reach shoulder height — lead with your elbows, not your wrists.',
    'ru': 'Поднимайте обе руки в стороны по дуге до уровня плеч — ведите движение локтями, а не запястьями.',
  },
  'exercise.lateral_raise.step3': {
    'en': 'Lower slowly back to the start over 2–3 seconds; resist the weight on the way down.',
    'ru': 'Медленно опустите за 2–3 секунды; сопротивляйтесь весу на пути вниз.',
  },
  'exercise.lateral_raise.mistake1': {
    'en': 'Shrugging the shoulders up — keep them depressed to avoid trap dominance.',
    'ru': 'Подъём плеч кверху — держите лопатки опущенными, чтобы нагрузка не уходила в трапецию.',
  },
  'exercise.lateral_raise.mistake2': {
    'en': 'Swinging the body for momentum — slow down and use a lighter weight.',
    'ru': 'Инерционные раскачки — замедлитесь и возьмите меньший вес.',
  },

  // ---------------------------------------------------------------------------
  // front_raise — Махи гантелями вперёд
  // ---------------------------------------------------------------------------
  'exercise.front_raise.step1': {
    'en': 'Stand holding a dumbbell in each hand against your thighs, palms facing back; keep a soft elbow bend.',
    'ru': 'Встаньте с гантелями у бёдер, ладони назад; сохраняйте небольшой изгиб в локтях.',
  },
  'exercise.front_raise.step2': {
    'en': 'Raise one or both arms straight forward to shoulder height; hold briefly at the top, then lower slowly.',
    'ru': 'Поднимайте одну или обе руки прямо вперёд до уровня плеч; задержитесь на мгновение, затем медленно опустите.',
  },
  'exercise.front_raise.mistake1': {
    'en': 'Using body swing — lean slightly forward only if necessary, but keep the movement controlled.',
    'ru': 'Инерционная раскачка корпуса — допускается лёгкий наклон вперёд, но движение должно оставаться контролируемым.',
  },

  // ---------------------------------------------------------------------------
  // rear_delt_fly — Разведение гантелей в наклоне
  // ---------------------------------------------------------------------------
  'exercise.rear_delt_fly.step1': {
    'en': 'Sit on the edge of a bench and hinge forward 45–90° with your chest toward your thighs; hold a dumbbell in each hand, arms hanging down with palms facing each other.',
    'ru': 'Сядьте на край скамьи, наклонитесь вперёд 45–90°, грудью к бёдрам; гантели свисают вниз, ладони смотрят друг на друга.',
  },
  'exercise.rear_delt_fly.step2': {
    'en': 'With a fixed elbow bend, sweep both arms out to the sides until they are parallel to the floor — squeeze your rear delts and rhomboids at the top.',
    'ru': 'С фиксированным изгибом локтей разведите руки в стороны до параллели с полом — сожмите задние дельты и ромбовидные в верхней точке.',
  },
  'exercise.rear_delt_fly.step3': {
    'en': 'Lower slowly back to the start; keep your torso still throughout.',
    'ru': 'Медленно опустите в исходное положение; корпус неподвижен на протяжении всего движения.',
  },
  'exercise.rear_delt_fly.mistake1': {
    'en': 'Raising the elbows above shoulder height — stop at parallel to avoid traps taking over.',
    'ru': 'Подъём локтей выше уровня плеч — остановитесь у параллели, чтобы не подключалась трапеция.',
  },

  // ---------------------------------------------------------------------------
  // arnold_press — Жим Арнольда
  // ---------------------------------------------------------------------------
  'exercise.arnold_press.step1': {
    'en': 'Sit on a bench with back support, holding dumbbells at chin height with palms facing you and elbows in front of your chest.',
    'ru': 'Сядьте на скамью со спинкой, гантели у подбородка, ладони к себе, локти перед грудью.',
  },
  'exercise.arnold_press.step2': {
    'en': 'As you press upward, rotate your palms outward so they face forward at the top — arms fully extended.',
    'ru': 'При жиме вверх разворачивайте ладони наружу, так что в верхней точке они смотрят вперёд — руки полностью выпрямлены.',
  },
  'exercise.arnold_press.step3': {
    'en': 'Reverse the rotation as you lower back to the starting position, returning palms to face you.',
    'ru': 'При опускании разворот обратный — в нижней точке ладони снова смотрят на вас.',
  },
  'exercise.arnold_press.mistake1': {
    'en': 'Rushing the rotation — move smoothly through the full arc to engage all three heads of the deltoid.',
    'ru': 'Спешка с разворотом — выполняйте плавно по всей дуге для нагрузки всех трёх пучков дельтовидных.',
  },

  // ---------------------------------------------------------------------------
  // barbell_curl — Подъём штанги на бицепс
  // ---------------------------------------------------------------------------
  'exercise.barbell_curl.step1': {
    'en': 'Stand with feet hip-width apart, holding a barbell with an underhand (supinated) grip, hands shoulder-width apart, arms hanging straight.',
    'ru': 'Встаньте, ноги на ширине бёдер, гриф хватом снизу на ширине плеч, руки прямые.',
  },
  'exercise.barbell_curl.step2': {
    'en': 'Keeping your elbows pinned to your sides, curl the bar up toward your collarbone by contracting your biceps.',
    'ru': 'Прижав локти к бокам, поднимайте гриф к ключицам, сокращая бицепсы.',
  },
  'exercise.barbell_curl.step3': {
    'en': 'Squeeze at the top, then lower the bar slowly over 2–3 seconds to full arm extension.',
    'ru': 'Сожмите бицепсы наверху, затем медленно опустите гриф за 2–3 секунды до полного выпрямления рук.',
  },
  'exercise.barbell_curl.mistake1': {
    'en': 'Swinging the body back — reduce the weight so the movement is strict.',
    'ru': 'Откидывание корпуса назад — снизьте вес, чтобы движение оставалось строгим.',
  },
  'exercise.barbell_curl.mistake2': {
    'en': 'Elbows drifting forward — keep them fixed at your sides to maximize bicep tension.',
    'ru': 'Локти уходят вперёд — держите их у боков для максимального напряжения бицепсов.',
  },

  // ---------------------------------------------------------------------------
  // dumbbell_curl — Подъём гантелей на бицепс
  // ---------------------------------------------------------------------------
  'exercise.dumbbell_curl.step1': {
    'en': 'Stand or sit holding a dumbbell in each hand at your sides, palms facing forward.',
    'ru': 'Встаньте или сядьте с гантелями вдоль тела, ладони смотрят вперёд.',
  },
  'exercise.dumbbell_curl.step2': {
    'en': 'Curl both (or alternating) dumbbells up toward your shoulders, keeping elbows stationary at your sides.',
    'ru': 'Поднимайте обе (или поочерёдные) гантели к плечам, локти неподвижны у боков.',
  },
  'exercise.dumbbell_curl.step3': {
    'en': 'Lower slowly with full control; fully extend the arms at the bottom of each rep.',
    'ru': 'Медленно опускайте с контролем; полностью выпрямляйте руки в нижней точке каждого повторения.',
  },
  'exercise.dumbbell_curl.mistake1': {
    'en': 'Not lowering all the way — a partial rep misses the full range and limits muscle growth.',
    'ru': 'Неполное опускание — частичное повторение сокращает амплитуду и тормозит рост мышц.',
  },

  // ---------------------------------------------------------------------------
  // hammer_curl — Молотковый подъём
  // ---------------------------------------------------------------------------
  'exercise.hammer_curl.step1': {
    'en': 'Hold a dumbbell in each hand with a neutral grip (palms facing each other) and arms at your sides.',
    'ru': 'Держите гантели нейтральным хватом (ладони смотрят друг на друга), руки вдоль тела.',
  },
  'exercise.hammer_curl.step2': {
    'en': 'Curl both (or alternating) dumbbells upward, keeping the neutral grip throughout — do not rotate the wrists; lower slowly.',
    'ru': 'Поднимайте гантели, сохраняя нейтральный хват на протяжении всего движения — не разворачивайте запястья; опускайте медленно.',
  },
  'exercise.hammer_curl.mistake1': {
    'en': 'Supinating the wrist at the top — maintain the hammer position to target the brachialis and brachioradialis.',
    'ru': 'Разворот запястья наверху — сохраняйте «молотковое» положение для нагрузки плечевой мышцы и плечелучевой.',
  },

  // ---------------------------------------------------------------------------
  // triceps_pushdown — Разгибание рук на блоке
  // ---------------------------------------------------------------------------
  'exercise.triceps_pushdown.step1': {
    'en': 'Stand at a cable machine with a bar or rope attachment set at upper-chest height; grip it with both hands, elbows bent at 90° and pinned close to your body.',
    'ru': 'Встаньте у кабельного тренажёра с рукоятью (прямой или канат) на уровне верхней части груди; обхватите обеими руками, локти согнуты под 90° и прижаты к телу.',
  },
  'exercise.triceps_pushdown.step2': {
    'en': 'Push the attachment straight down by extending your elbows until your arms are fully locked out — keep elbows still at your sides.',
    'ru': 'Разгибайте локти вниз до полного выпрямления рук — локти неподвижны у боков.',
  },
  'exercise.triceps_pushdown.step3': {
    'en': 'Allow the attachment to rise slowly back to the start, feeling the triceps stretch at the top.',
    'ru': 'Медленно верните рукоять в исходное положение, ощущая растяжение трицепсов наверху.',
  },
  'exercise.triceps_pushdown.mistake1': {
    'en': 'Elbows flaring out or lifting — keep them locked tight to isolate the triceps.',
    'ru': 'Локти разводятся или поднимаются — держите их прижатыми для изолированной нагрузки трицепса.',
  },
  'exercise.triceps_pushdown.mistake2': {
    'en': 'Leaning heavily over the bar — stay upright so the motion is pure elbow extension.',
    'ru': 'Сильный наклон вперёд над рукоятью — держитесь вертикально, чтобы работало только разгибание в локте.',
  },

  // ---------------------------------------------------------------------------
  // overhead_triceps_extension — Французский жим с гантелью
  // ---------------------------------------------------------------------------
  'exercise.overhead_triceps_extension.step1': {
    'en': 'Sit or stand holding a single dumbbell with both hands, arms extended directly overhead — grip the inner plate of the dumbbell with thumbs wrapped around.',
    'ru': 'Сядьте или встаньте с одной гантелью над головой на вытянутых руках — возьмитесь за внутренний блин обеими руками, большие пальцы обхватывают гриф.',
  },
  'exercise.overhead_triceps_extension.step2': {
    'en': 'Keeping your upper arms vertical and elbows pointing forward, lower the dumbbell behind your head by bending your elbows.',
    'ru': 'Удерживая плечи вертикально и локти направленными вперёд, опускайте гантель за голову, сгибая локти.',
  },
  'exercise.overhead_triceps_extension.step3': {
    'en': 'Extend your elbows to press the dumbbell back overhead; exhale as you lock out.',
    'ru': 'Разгибайте локти, выжимая гантель обратно вверх; выдыхайте при выпрямлении.',
  },
  'exercise.overhead_triceps_extension.mistake1': {
    'en': 'Elbows flaring wide — keep them as narrow as possible to target the long head of the triceps.',
    'ru': 'Локти широко расходятся — держите их как можно ближе для нагрузки длинной головки трицепса.',
  },

  // ---------------------------------------------------------------------------
  // close_grip_bench_press — Жим штанги узким хватом
  // ---------------------------------------------------------------------------
  'exercise.close_grip_bench_press.step1': {
    'en': 'Lie on a flat bench; grip the barbell with hands about shoulder-width (narrower than a regular bench press), shoulder blades retracted, feet flat.',
    'ru': 'Лягте на горизонтальную скамью; хват примерно на ширине плеч (уже обычного жима), лопатки сведены, стопы на полу.',
  },
  'exercise.close_grip_bench_press.step2': {
    'en': 'Lower the bar to your lower chest with elbows staying close to your torso (~45° flare) — do not flare them wide.',
    'ru': 'Опускайте гриф к нижней части груди, локти прижаты к корпусу (~45° отведение) — не уводите их широко.',
  },
  'exercise.close_grip_bench_press.step3': {
    'en': 'Press back up to full extension; exhale at the top.',
    'ru': 'Выжмите гриф до полного выпрямления рук; выдыхайте наверху.',
  },
  'exercise.close_grip_bench_press.mistake1': {
    'en': 'Gripping too narrow (hands touching) — this strains the wrists; keep hands about shoulder-width.',
    'ru': 'Слишком узкий хват (руки вплотную) — нагружает запястья; держите хват примерно на ширине плеч.',
  },
  'exercise.close_grip_bench_press.mistake2': {
    'en': 'Elbows flaring out wide — this shifts load to the chest and reduces triceps emphasis.',
    'ru': 'Локти уходят широко в стороны — нагрузка переходит на грудь, снижая акцент на трицепс.',
  },

  // ---------------------------------------------------------------------------
  // hanging_leg_raise — Подъём ног в висе
  // ---------------------------------------------------------------------------
  'exercise.hanging_leg_raise.step1': {
    'en': 'Hang from a pull-up bar with an overhand grip, arms fully extended and body still — avoid swinging.',
    'ru': 'Повисните на турнике прямым хватом, руки полностью выпрямлены, тело неподвижно — не раскачивайтесь.',
  },
  'exercise.hanging_leg_raise.step2': {
    'en': 'Engage your core and raise your legs until they are at least parallel to the floor (or higher if possible); avoid swinging hips.',
    'ru': 'Напрягите кор и поднимайте ноги до параллели с полом (или выше); не раскачивайте бёдра.',
  },
  'exercise.hanging_leg_raise.step3': {
    'en': 'Lower your legs slowly with control; do not let them drop or swing forward.',
    'ru': 'Медленно с контролем опустите ноги; не бросайте их и не раскачивайтесь вперёд.',
  },
  'exercise.hanging_leg_raise.mistake1': {
    'en': 'Using momentum and swinging — pause at the bottom of each rep to eliminate swing.',
    'ru': 'Использование инерции и раскачка — останавливайтесь в нижней точке каждого повторения.',
  },
  'exercise.hanging_leg_raise.mistake2': {
    'en': 'Bending the knees excessively — straighten legs for maximum hip flexor and ab involvement.',
    'ru': 'Чрезмерное сгибание колен — выпрямите ноги для максимальной нагрузки на сгибатели бедра и пресс.',
  },

  // ---------------------------------------------------------------------------
  // crunch — Скручивания
  // ---------------------------------------------------------------------------
  'exercise.crunch.step1': {
    'en': 'Lie on your back with knees bent, feet flat on the floor hip-width apart; place hands lightly behind your head — do not pull on your neck.',
    'ru': 'Лягте на спину, колени согнуты, стопы на полу на ширине бёдер; руки легко за головой — не тяните шею.',
  },
  'exercise.crunch.step2': {
    'en': 'Exhale and curl your shoulders off the floor by contracting your abs — stop when your lower back is still on the floor; do not sit all the way up.',
    'ru': 'Выдыхая, скручивайте плечи от пола сокращением пресса — остановитесь пока поясница на полу; не поднимайтесь в полный сед.',
  },
  'exercise.crunch.step3': {
    'en': 'Inhale and slowly lower back to the start; keep tension in your abs throughout.',
    'ru': 'Вдыхая, медленно опустите плечи в исходное положение; сохраняйте напряжение в прессе.',
  },
  'exercise.crunch.mistake1': {
    'en': 'Pulling on the neck with your hands — cross arms on your chest if this is a problem.',
    'ru': 'Тяга шеи руками — скрестите руки на груди, если это проблема.',
  },

  // ---------------------------------------------------------------------------
  // mountain_climber — Скалолаз
  // ---------------------------------------------------------------------------
  'exercise.mountain_climber.step1': {
    'en': 'Start in a high-plank position: arms straight, hands under your shoulders, body forming a straight line from head to heels.',
    'ru': 'Примите упор лёжа на прямых руках: ладони под плечами, тело — прямая линия от головы до пяток.',
  },
  'exercise.mountain_climber.step2': {
    'en': 'Drive one knee toward your chest as fast as possible, then immediately switch legs — keep hips level and core tight.',
    'ru': 'Подтяните одно колено к груди как можно быстрее, затем сразу смените ногу — таз ровный, кор в напряжении.',
  },
  'exercise.mountain_climber.step3': {
    'en': 'Continue alternating legs for the set duration, maintaining a flat back throughout.',
    'ru': 'Продолжайте чередовать ноги в течение заданного времени, сохраняя ровную спину.',
  },
  'exercise.mountain_climber.mistake1': {
    'en': 'Hips rising too high — keep them in line with your shoulders to prevent losing core tension.',
    'ru': 'Таз поднимается слишком высоко — держите его на линии плеч, чтобы не терять напряжение кора.',
  },

  // ---------------------------------------------------------------------------
  // kettlebell_swing — Махи гирей
  // ---------------------------------------------------------------------------
  'exercise.kettlebell_swing.step1': {
    'en': 'Stand with feet slightly wider than hip-width; place the kettlebell about a foot in front of you. Hinge at the hips and grip the bell with both hands, tilting it toward you.',
    'ru': 'Ноги чуть шире бёдер; гиря на полу примерно в 30 см перед вами. Наклонитесь в тазобедренном суставе, возьмитесь за гирю обеими руками, наклонив её к себе.',
  },
  'exercise.kettlebell_swing.step2': {
    'en': 'Hike the bell back between your legs (keep it above your knees), then explosively drive your hips forward to propel the bell up to chest height.',
    'ru': 'Заброситель гирю назад между ног (выше колен), затем взрывно вытолкните бёдра вперёд, выбрасывая гирю до уровня груди.',
  },
  'exercise.kettlebell_swing.step3': {
    'en': 'At the top, your body should be fully upright with glutes and core contracted — the bell floats; do not actively pull with your arms.',
    'ru': 'В верхней точке тело полностью выпрямлено, ягодицы и кор сжаты — гиря «плывёт»; не тяните её руками.',
  },
  'exercise.kettlebell_swing.step4': {
    'en': 'Allow the bell to swing back down, hinge to absorb the load, and immediately cycle into the next rep.',
    'ru': 'Позвольте гире опуститься назад, согнитесь в тазу для поглощения нагрузки и сразу начинайте следующее повторение.',
  },
  'exercise.kettlebell_swing.mistake1': {
    'en': 'Squatting the swing (knee-dominant) — this is a hip hinge; your shins should stay nearly vertical and the power comes from your glutes, not your quads.',
    'ru': 'Приседание вместо тяги (доминирование колена) — это тяга в тазобедренном суставе; голени почти вертикальны, сила идёт от ягодиц, не от квадрицепсов.',
  },
  'exercise.kettlebell_swing.mistake2': {
    'en': 'Rounding the lower back at the bottom — maintain a neutral spine throughout; reduce the load if you lose position.',
    'ru': 'Скругление поясницы внизу — держите нейтральный позвоночник; снизьте вес, если не удаётся сохранить положение.',
  },
};
