// Безопасные короткие подписи дня недели для календарных сеток.
//
// `DateFormat.E()` следует Intl.defaultLocale и в РАЗНЫХ локалях возвращает
// аббревиатуру РАЗНОЙ длины: en «Mon» (3), it «lun» (3), но ru «пн»/«вт» (2),
// ja «月»/«日» (1), ko «월»/«일» (1). Наивный `.substring(0, 3)` на таких
// строках бросает RangeError (index out of range) — а под фейковым/боевым
// деревом он всплывал как красный ErrorWidget на КАЖДОЙ колонке-заголовке
// (3 в виде «3 дня», 7 в «неделе»), отсюда повтор «мусора» по числу колонок.
//
// Хелпер обрезает по ГРАФЕМАМ (а не code unit'ам), чтобы не разрывать составные
// символы (напр. деванагари в hi), и никогда не выходит за длину строки.

import 'package:flutter/widgets.dart'; // даёт расширение String.characters
import 'package:intl/intl.dart';

/// Короткая локализованная подпись дня недели для [day] — не длиннее 3 графем.
/// Использует Intl.defaultLocale (как остальной интерфейс). Безопасна для любой
/// локали: не бросает RangeError на 1–2-символьных аббревиатурах (ru/ja/ko).
String shortWeekdayLabel(DateTime day) {
  final label = DateFormat.E().format(day);
  final chars = label.characters;
  return chars.length <= 3 ? label : chars.take(3).toString();
}
