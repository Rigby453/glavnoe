// Plural-формы для строк со счётчиками.
// Используют Intl.plural, который понимает правила склонения для каждого языка.
// Локаль берётся из Localizations.localeOf(context) — тот же источник, что context.s().
//
// Правила для RU (3 формы):
//   one   — 1, 21, 31 … (одна минута, одно упражнение)
//   few   — 2–4, 22–24 … (две минуты, два упражнения)
//   many  — 5–20, 25–30 … (пять минут, пять упражнений)
// Для DE и EN — one / other (стандартные 2 формы).
// Для FR — 0 и 1 используют singular (one), остальные plural (other).
// Для JA/KO/ID/HI — нет различия ед./мн., используем одну форму (other).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// МИНУТЫ
// ---------------------------------------------------------------------------

/// «N minute(s)» с правильным склонением для всех поддерживаемых языков.
///
/// EN: 1 minute / 2 minutes
/// RU: 1 минута / 2 минуты / 5 минут
/// DE: 1 Minute / 2 Minuten
/// FR: 1 minute / 2 minutes
/// IT: 1 minuto / 2 minuti
/// PT: 1 minuto / 2 minutos
/// ES: 1 minuto / 2 minutos
/// ID: N menit
/// HI: N मिनट
/// JA: N 分
/// KO: N 분
String plMinutes(BuildContext context, int n) {
  final locale = Localizations.localeOf(context).languageCode;
  return Intl.plural(
    n,
    locale: locale,
    one: _minuteOne(locale, n),
    few: _minuteFew(locale, n),
    many: _minuteMany(locale, n),
    other: _minuteOther(locale, n),
  );
}

String _minuteOne(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n минута';
    case 'de':
      return '$n Minute';
    case 'fr':
      return '$n minute';
    case 'it':
      return '$n minuto';
    case 'pt':
      return '$n minuto';
    case 'es':
      return '$n minuto';
    default:
      return '$n minute';
  }
}

String _minuteFew(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n минуты';
    case 'de':
      return '$n Minuten';
    case 'fr':
      return '$n minutes';
    case 'it':
      return '$n minuti';
    case 'pt':
      return '$n minutos';
    case 'es':
      return '$n minutos';
    default:
      return '$n minutes';
  }
}

String _minuteMany(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n минут';
    case 'de':
      return '$n Minuten';
    case 'fr':
      return '$n minutes';
    case 'it':
      return '$n minuti';
    case 'pt':
      return '$n minutos';
    case 'es':
      return '$n minutos';
    default:
      return '$n minutes';
  }
}

String _minuteOther(String lang, int n) {
  // «other» для EN/DE/FR/IT/PT/ES (n != 1) и единственная форма для JA/KO/ID/HI
  switch (lang) {
    case 'ru':
      return '$n минут';
    case 'de':
      return '$n Minuten';
    case 'fr':
      return '$n minutes';
    case 'it':
      return '$n minuti';
    case 'pt':
      return '$n minutos';
    case 'es':
      return '$n minutos';
    case 'id':
      return '$n menit';
    case 'hi':
      return '$n मिनट';
    case 'ja':
      return '$n 分';
    case 'ko':
      return '$n 분';
    default:
      return '$n minutes';
  }
}

// ---------------------------------------------------------------------------
// УПРАЖНЕНИЯ
// ---------------------------------------------------------------------------

/// «N exercise(s)» с правильным склонением для всех поддерживаемых языков.
///
/// EN: 1 exercise / 2 exercises
/// RU: 1 упражнение / 2 упражнения / 5 упражнений
/// DE: 1 Übung / 2 Übungen
/// FR: 1 exercice / 2 exercices
/// IT: 1 esercizio / 2 esercizi
/// PT: 1 exercício / 2 exercícios
/// ES: 1 ejercicio / 2 ejercicios
/// ID: N latihan
/// HI: N व्यायाम / N अभ्यास (используем व्यायाम как универсальное)
/// JA: N エクササイズ
/// KO: N 운동
String plExercises(BuildContext context, int n) {
  final locale = Localizations.localeOf(context).languageCode;
  return Intl.plural(
    n,
    locale: locale,
    one: _exerciseOne(locale, n),
    few: _exerciseFew(locale, n),
    many: _exerciseMany(locale, n),
    other: _exerciseOther(locale, n),
  );
}

String _exerciseOne(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n упражнение';
    case 'de':
      return '$n Übung';
    case 'fr':
      return '$n exercice';
    case 'it':
      return '$n esercizio';
    case 'pt':
      return '$n exercício';
    case 'es':
      return '$n ejercicio';
    default:
      return '$n exercise';
  }
}

String _exerciseFew(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n упражнения';
    case 'de':
      return '$n Übungen';
    case 'fr':
      return '$n exercices';
    case 'it':
      return '$n esercizi';
    case 'pt':
      return '$n exercícios';
    case 'es':
      return '$n ejercicios';
    default:
      return '$n exercises';
  }
}

String _exerciseMany(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n упражнений';
    case 'de':
      return '$n Übungen';
    case 'fr':
      return '$n exercices';
    case 'it':
      return '$n esercizi';
    case 'pt':
      return '$n exercícios';
    case 'es':
      return '$n ejercicios';
    default:
      return '$n exercises';
  }
}

String _exerciseOther(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n упражнений';
    case 'de':
      return '$n Übungen';
    case 'fr':
      return '$n exercices';
    case 'it':
      return '$n esercizi';
    case 'pt':
      return '$n exercícios';
    case 'es':
      return '$n ejercicios';
    case 'id':
      return '$n latihan';
    case 'hi':
      return '$n व्यायाम';
    case 'ja':
      return '$n エクササイズ';
    case 'ko':
      return '$n 운동';
    default:
      return '$n exercises';
  }
}

// ---------------------------------------------------------------------------
// ИНГРЕДИЕНТЫ
// ---------------------------------------------------------------------------

/// «N ingredient(s)» с правильным склонением для всех поддерживаемых языков.
///
/// EN: 1 ingredient / 2 ingredients
/// RU: 1 ингредиент / 2 ингредиента / 5 ингредиентов
/// DE: 1 Zutat / 2 Zutaten
/// FR: 1 ingrédient / 2 ingrédients
/// IT: 1 ingrediente / 2 ingredienti
/// PT: 1 ingrediente / 2 ingredientes
/// ES: 1 ingrediente / 2 ingredientes
/// ID: N bahan
/// HI: N सामग्री
/// JA: N 材料
/// KO: N 재료
String plIngredients(BuildContext context, int n) {
  final locale = Localizations.localeOf(context).languageCode;
  return Intl.plural(
    n,
    locale: locale,
    one: _ingredientOne(locale, n),
    few: _ingredientFew(locale, n),
    many: _ingredientMany(locale, n),
    other: _ingredientOther(locale, n),
  );
}

String _ingredientOne(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n ингредиент';
    case 'de':
      return '$n Zutat';
    case 'fr':
      return '$n ingrédient';
    case 'it':
      return '$n ingrediente';
    case 'pt':
      return '$n ingrediente';
    case 'es':
      return '$n ingrediente';
    default:
      return '$n ingredient';
  }
}

String _ingredientFew(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n ингредиента';
    case 'de':
      return '$n Zutaten';
    case 'fr':
      return '$n ingrédients';
    case 'it':
      return '$n ingredienti';
    case 'pt':
      return '$n ingredientes';
    case 'es':
      return '$n ingredientes';
    default:
      return '$n ingredients';
  }
}

String _ingredientMany(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n ингредиентов';
    case 'de':
      return '$n Zutaten';
    case 'fr':
      return '$n ingrédients';
    case 'it':
      return '$n ingredienti';
    case 'pt':
      return '$n ingredientes';
    case 'es':
      return '$n ingredientes';
    default:
      return '$n ingredients';
  }
}

String _ingredientOther(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n ингредиентов';
    case 'de':
      return '$n Zutaten';
    case 'fr':
      return '$n ingrédients';
    case 'it':
      return '$n ingredienti';
    case 'pt':
      return '$n ingredientes';
    case 'es':
      return '$n ingredientes';
    case 'id':
      return '$n bahan';
    case 'hi':
      return '$n सामग्री';
    case 'ja':
      return '$n 材料';
    case 'ko':
      return '$n 재료';
    default:
      return '$n ingredients';
  }
}

// ---------------------------------------------------------------------------
// ШАГИ
// ---------------------------------------------------------------------------

/// «N step(s)» с правильным склонением для всех поддерживаемых языков.
///
/// EN: 1 step / 2 steps
/// RU: 1 шаг / 2 шага / 5 шагов
/// DE: 1 Schritt / 2 Schritte
/// FR: 1 étape / 2 étapes
/// IT: 1 passo / 2 passi
/// PT: 1 passo / 2 passos
/// ES: 1 paso / 2 pasos
/// ID: N langkah
/// HI: N चरण
/// JA: N ステップ
/// KO: N 단계
String plSteps(BuildContext context, int n) {
  final locale = Localizations.localeOf(context).languageCode;
  return Intl.plural(
    n,
    locale: locale,
    one: _stepOne(locale, n),
    few: _stepFew(locale, n),
    many: _stepMany(locale, n),
    other: _stepOther(locale, n),
  );
}

String _stepOne(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n шаг';
    case 'de':
      return '$n Schritt';
    case 'fr':
      return '$n étape';
    case 'it':
      return '$n passo';
    case 'pt':
      return '$n passo';
    case 'es':
      return '$n paso';
    default:
      return '$n step';
  }
}

String _stepFew(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n шага';
    case 'de':
      return '$n Schritte';
    case 'fr':
      return '$n étapes';
    case 'it':
      return '$n passi';
    case 'pt':
      return '$n passos';
    case 'es':
      return '$n pasos';
    default:
      return '$n steps';
  }
}

String _stepMany(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n шагов';
    case 'de':
      return '$n Schritte';
    case 'fr':
      return '$n étapes';
    case 'it':
      return '$n passi';
    case 'pt':
      return '$n passos';
    case 'es':
      return '$n pasos';
    default:
      return '$n steps';
  }
}

String _stepOther(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n шагов';
    case 'de':
      return '$n Schritte';
    case 'fr':
      return '$n étapes';
    case 'it':
      return '$n passi';
    case 'pt':
      return '$n passos';
    case 'es':
      return '$n pasos';
    case 'id':
      return '$n langkah';
    case 'hi':
      return '$n चरण';
    case 'ja':
      return '$n ステップ';
    case 'ko':
      return '$n 단계';
    default:
      return '$n steps';
  }
}

// ---------------------------------------------------------------------------
// СЕКУНДЫ
// ---------------------------------------------------------------------------

/// «N second(s)» с правильным склонением для всех поддерживаемых языков.
///
/// EN: 1 second / 2 seconds / 30 seconds
/// RU: 1 секунда / 2 секунды / 30 секунд
/// DE: 1 Sekunde / 2 Sekunden / 30 Sekunden
/// FR: 1 seconde / 2 secondes
/// IT: 1 secondo / 2 secondi
/// PT: 1 segundo / 2 segundos
/// ES: 1 segundo / 2 segundos
/// ID: N detik
/// HI: N सेकंड
/// JA: N 秒
/// KO: N 초
String plSeconds(BuildContext context, int n) {
  final locale = Localizations.localeOf(context).languageCode;
  return Intl.plural(
    n,
    locale: locale,
    one: _secondOne(locale, n),
    few: _secondFew(locale, n),
    many: _secondMany(locale, n),
    other: _secondOther(locale, n),
  );
}

String _secondOne(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n секунда';
    case 'de':
      return '$n Sekunde';
    case 'fr':
      return '$n seconde';
    case 'it':
      return '$n secondo';
    case 'pt':
      return '$n segundo';
    case 'es':
      return '$n segundo';
    default:
      return '$n second';
  }
}

String _secondFew(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n секунды';
    case 'de':
      return '$n Sekunden';
    case 'fr':
      return '$n secondes';
    case 'it':
      return '$n secondi';
    case 'pt':
      return '$n segundos';
    case 'es':
      return '$n segundos';
    default:
      return '$n seconds';
  }
}

String _secondMany(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n секунд';
    case 'de':
      return '$n Sekunden';
    case 'fr':
      return '$n secondes';
    case 'it':
      return '$n secondi';
    case 'pt':
      return '$n segundos';
    case 'es':
      return '$n segundos';
    default:
      return '$n seconds';
  }
}

String _secondOther(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '$n секунд';
    case 'de':
      return '$n Sekunden';
    case 'fr':
      return '$n secondes';
    case 'it':
      return '$n secondi';
    case 'pt':
      return '$n segundos';
    case 'es':
      return '$n segundos';
    case 'id':
      return '$n detik';
    case 'hi':
      return '$n सेकंड';
    case 'ja':
      return '$n 秒';
    case 'ko':
      return '$n 초';
    default:
      return '$n seconds';
  }
}

// ---------------------------------------------------------------------------
// ПОВТОРЫ (для шагов зарядки/растяжки по повторам)
// ---------------------------------------------------------------------------

/// «× N reps» с правильным склонением.
///
/// EN: × 1 rep / × 12 reps
/// RU: × 1 повтор / × 2 повтора / × 12 повторов
/// Остальные языки пока фолбэкают на en (контент warmup не переведён).
String plReps(BuildContext context, int n) {
  final locale = Localizations.localeOf(context).languageCode;
  return Intl.plural(
    n,
    locale: locale,
    one: _repOne(locale, n),
    few: _repFew(locale, n),
    many: _repMany(locale, n),
    other: _repOther(locale, n),
  );
}

String _repOne(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '× $n повтор';
    default:
      return '× $n rep';
  }
}

String _repFew(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '× $n повтора';
    default:
      return '× $n reps';
  }
}

String _repMany(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '× $n повторов';
    default:
      return '× $n reps';
  }
}

String _repOther(String lang, int n) {
  switch (lang) {
    case 'ru':
      return '× $n повторов';
    default:
      return '× $n reps';
  }
}

// ---------------------------------------------------------------------------
// СОСТАВНЫЕ ФУНКЦИИ
// ---------------------------------------------------------------------------

/// Строка длительности для упражнения осанки (секунды или минуты).
/// Используется в _ExerciseTile (posture_screen.dart) — context.s() не нужен.
String plPostureDuration(BuildContext context, int seconds) {
  if (seconds < 60) return plSeconds(context, seconds);
  return plMinutes(context, seconds ~/ 60);
}

/// Строка «N мин / studying for N min» для co-study диалога.
///
/// EN: {name} has been studying for N minutes. Join their session?
/// RU: {name} учится уже N минут. Присоединиться к сессии?
/// DE: {name} lernt seit N Minuten. Sitzung beitreten?
/// FR: {name} étudie depuis N minutes. Rejoindre la session?
/// IT: {name} studia da N minuti. Partecipare alla sessione?
/// PT: {name} está estudando há N minutos. Entrar na sessão?
/// ES: {name} lleva N minutos estudiando. ¿Unirse a la sesión?
/// ID: {name} sudah belajar selama N menit. Bergabung ke sesinya?
/// HI: {name} N मिनट से पढ़ रहे हैं। उनके सेशन में शामिल हों?
/// JA: {name}はN分間勉強しています。セッションに参加しますか?
/// KO: {name}이(가) N분째 공부 중입니다. 세션에 참가할까요?
String plCoStudyJoin(BuildContext context, String name, int minutes) {
  final locale = Localizations.localeOf(context).languageCode;
  final minsStr = plMinutes(context, minutes);
  switch (locale) {
    case 'ru':
      return '$name учится уже $minsStr.\nПрисоединиться к сессии?';
    case 'de':
      return '$name lernt seit $minsStr.\nSitzung beitreten?';
    case 'fr':
      return '$name étudie depuis $minsStr.\nRejoindre la session?';
    case 'it':
      return '$name studia da $minsStr.\nPartecipare alla sessione?';
    case 'pt':
      return '$name está estudando há $minsStr.\nEntrar na sessão?';
    case 'es':
      return '$name lleva $minsStr estudiando.\n¿Unirse a la sesión?';
    case 'id':
      return '$name sudah belajar selama $minsStr.\nBergabung ke sesinya?';
    case 'hi':
      return '$name $minsStr से पढ़ रहे हैं।\nउनके सेशन में शामिल हों?';
    case 'ja':
      return '$nameは$minsStr間勉強しています。\nセッションに参加しますか?';
    case 'ko':
      return '$name이(가) $minsStr째 공부 중입니다.\n세션에 참가할까요?';
    default:
      return '$name has been studying for $minsStr.\nJoin their session?';
  }
}
