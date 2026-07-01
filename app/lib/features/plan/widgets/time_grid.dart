// FL-PLAN-GRID: Сетка времени в стиле Google Calendar для Day/Week.
// Вертикальная ось часов (0–24), блоки-события позиционируются по scheduledAt
// и durationMinutes. Поддержка drag (перенос времени), resize (длительность),
// тап → редактирование. Чистая математика вынесена в top-level функции —
// они покрыты юнит-тестами (test/time_grid_test.dart). Жесты на устройстве
// нужно проверять вручную.
//
// Конвенция времени: scheduledAt трактуется как локальное «настенное» время
// (так его показывает DayTimeline через DateFormat.Hm без .toLocal). Поэтому
// позиция считается по .hour/.minute, а при сохранении новое время строится
// через локальный DateTime(...), как в add_task_sheet.

import 'dart:async';

import 'package:drift/drift.dart' show Value;
// gestures.dart нужен явно: VerticalDragGestureRecognizer, PointerDownEvent и
// GestureDisposition НЕ ре-экспортируются material.dart (там только узкий show-
// список из gesture_detector.dart). Без этого импорта _EagerVerticalDragRecognizer
// не скомпилируется.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/animations/constants.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/day_window.dart';
import '../../../core/utils/weekday_label.dart';
import '../../../core/widgets/kai_loader.dart';
import '../../today/task_colors.dart';
import '../../today/widgets/add_task_sheet.dart' show showAddTaskSheet;
import '../task_shape.dart';
import 'day_timeline.dart' show dayItemsProvider;
import 'plan_providers.dart';
import 'recurrence_providers.dart';
import 'task_detail_card.dart';
import 'week_strip.dart' show selectedDayProvider;

// Порог удержания для подхвата блока на перенос (long-press, ТАЧ-путь).
// Дефолт Flutter kLongPressTimeout ≈ 500 мс — слишком долго держать; по
// решению владельца продукта опущено до 120 мс — почти мгновенный подхват
// пальцем, но ещё отличает «придержал → тяну» от быстрого свайпа-скролла
// сетки. МЫШЬ/ТРЕКПАД/СТИЛУС не используют эту задержку вовсе — у них
// немедленный PanGestureRecognizer (см. _EventBlock/_CreateLayer). Общая
// константа для _CreateLayer (создание) и _EventBlock (перенос) — тач-подхват
// консистентен на обоих путях.
const _kBlockPickupDelay = Duration(milliseconds: 120);

// ===========================================================================
// Чистая математика (тестируемые top-level функции)
// ===========================================================================

/// Высота одного часа в логических пикселях (по умолчанию).
const double kHourHeight = 56.0;

/// Высота маркера задачи-«момента» (TaskShape.moment) — фиксирована, НЕ
/// масштабируется c hourHeight, т.к. у момента нет протяжённости во времени
/// (см. task_shape.dart). Используется _MomentMarker.
const double kMomentMarkerHeight = 22.0;

/// Шаг привязки при drag/resize — 15 минут.
const int kSnapMinutes = 15;

/// Минимальная длительность события в минутах.
const int kMinDurationMinutes = 15;

/// Минут от полуночи для [time] (учитывает только часы/минуты).
int minutesFromMidnight(DateTime time) => time.hour * 60 + time.minute;

/// Вертикальное смещение (top) блока для времени [minutesOfDay] минут от
/// полуночи при высоте часа [hourHeight].
double minutesToOffset(int minutesOfDay, double hourHeight) =>
    minutesOfDay * hourHeight / 60.0;

/// Высота блока для длительности [durationMinutes] при высоте часа [hourHeight].
/// Не меньше [minHeight] ради читаемости коротких событий.
double durationToHeight(
  int durationMinutes,
  double hourHeight, {
  double minHeight = 24.0,
}) {
  final raw = durationMinutes * hourHeight / 60.0;
  return raw < minHeight ? minHeight : raw;
}

/// Перевод вертикального смещения [offset] обратно в минуты от полуночи,
/// привязанные к шагу [snapMinutes]. Результат зажат в [0, 24*60].
int offsetToSnappedMinutes(
  double offset,
  double hourHeight, {
  int snapMinutes = kSnapMinutes,
}) {
  final rawMinutes = offset / hourHeight * 60.0;
  final snapped = (rawMinutes / snapMinutes).round() * snapMinutes;
  if (snapped < 0) return 0;
  const maxMinutes = 24 * 60;
  if (snapped > maxMinutes) return maxMinutes;
  return snapped;
}

/// Привязывает произвольное число минут к шагу [snapMinutes] и не даёт
/// результату упасть ниже [minDuration]. Используется при resize.
int snapDuration(
  int minutes, {
  int snapMinutes = kSnapMinutes,
  int minDuration = kMinDurationMinutes,
}) {
  final snapped = (minutes / snapMinutes).round() * snapMinutes;
  return snapped < minDuration ? minDuration : snapped;
}

/// Двузначное число с ведущим нулём (для форматирования времени).
String _two(int n) => n.toString().padLeft(2, '0');

/// «HH:MM» из минут от полуночи (зажато в пределах суток для отображения).
String formatMinutesOfDay(int minutesOfDay) {
  final clamped = minutesOfDay < 0
      ? 0
      : (minutesOfDay > 24 * 60 ? 24 * 60 : minutesOfDay);
  final h = (clamped ~/ 60) % 24;
  final m = clamped % 60;
  return '${_two(h)}:${_two(m)}';
}

/// Диапазон времени блока: «14:30–15:15» из старта [start] и длительности
/// [durationMinutes]. Конец считается по минутам от старта (без перехода суток
/// в отображении — конец зажимается формулой выше). Чистая функция.
String formatBlockTimeRange(DateTime start, int durationMinutes) {
  final startMin = minutesFromMidnight(start);
  final endMin = startMin + durationMinutes;
  return '${formatMinutesOfDay(startMin)}–${formatMinutesOfDay(endMin)}';
}

/// Диапазон времени задачи С УЧЁТОМ её «формы» (task_shape.dart) — единая
/// точка входа, которую используют и сетка (_BlockContent), и карточка-деталь
/// (task_detail_card), вместо того чтобы заново городить ветвление по
/// durationMinutes на каждом месте:
///   • [TaskShape.block]  — как [formatBlockTimeRange] («14:30–15:15»);
///   • [TaskShape.moment] — одна точка («14:00»), диапазона нет — длительности
///     нет вовсе;
///   • [TaskShape.open]   — начало с открытым концом («15:00–», без конкретного
///     времени завершения — намеренно без второй половины диапазона).
String formatItemTimeRange(DateTime start, int durationMinutes) {
  switch (taskShapeOf(durationMinutes)) {
    case TaskShape.moment:
      return formatMinutesOfDay(minutesFromMidnight(start));
    case TaskShape.open:
      return '${formatMinutesOfDay(minutesFromMidnight(start))}–';
    case TaskShape.block:
      return formatBlockTimeRange(start, durationMinutes);
  }
}

/// Сколько информации помещается в блок данной высоты [height] — чистая
/// функция, чтобы поведение «масштабируй контент под высоту» было тестируемым.
/// Очень низкий блок — только заголовок; средний — заголовок + время; высокий —
/// заголовок (до 2 строк) + время + строка типа/повтора.
enum BlockContentLevel { titleOnly, titleAndTime, titleTimeAndMeta }

/// Пороги подобраны под крупный заголовок (bodyMedium ~14–16px) + время
/// (labelMedium ~12px) и вертикальные паддинги блока (3+3). Приоритет —
/// НАЗВАНИЮ (как у Google/Apple Calendar): на низком блоке показываем только
/// заголовок (время и так видно на часовой оси слева), время добавляется лишь
/// когда под заголовком гарантированно есть место для ещё одной строки, мета —
/// только на высоком блоке.
///
/// Порог titleAndTime (48) с запасом выше суммы «заголовок (~17px) + время
/// (~15px) + паддинги (6px)» ≈ 38px — чтобы на ПЕРЕХОДНЫХ высотах живого ресайза
/// между titleOnly и titleAndTime строка времени не появлялась раньше, чем под
/// неё реально хватит места (иначе на отдельных кадрах был overflow на 8..0px).
BlockContentLevel blockContentLevel(double height) {
  if (height >= 80) return BlockContentLevel.titleTimeAndMeta;
  if (height >= 48) return BlockContentLevel.titleAndTime;
  return BlockContentLevel.titleOnly;
}

/// Что показывать в блоке узких видов (3 дня / неделя), где колонки тонкие.
/// Решение принимается по ФАКТИЧЕСКОЙ геометрии блока (ширина × высота), а не
/// только по высоте: на узкой колонке диапазон времени «14:30–15:15» не влезает
/// и читается как каша, а на совсем маленьком блоке даже заголовок превращается
/// в обрезок — лучше показать просто цветной блок (название доступно по тапу).
enum CompactBlockContent {
  /// Блок слишком мал для читаемого текста — только цвет (тап открывает карточку).
  colorOnly,

  /// Помещается только короткий заголовок по центру (без времени).
  titleOnly,

  /// Помещается заголовок + время (колонка достаточно широкая/высокая).
  titleAndTime,
}

/// Минимальная ширина блока, при которой имеет смысл рисовать текст вообще.
const double kCompactMinTextWidth = 36.0;

/// Минимальная высота блока для читаемого заголовка. Снижена с 22 до 10 px
/// (правка владельца продукта): раньше короткие задачи (10–25 мин, реальный
/// пол высоты блока — 24px из-за minHeight в durationToHeight) оставались
/// совсем пустыми — после вычитания вертикальных паддингов блока (3+3=6px)
/// их эффективная высота текста (~18px) была НИЖЕ старого порога 22 и заголовок
/// не показывался вовсе. FittedBox(scaleDown) в _buildDayContent/
/// _buildCompactContent — жёсткий гард от overflow на ЛЮБОЙ высоте, поэтому
/// порог можно безопасно снижать: перегрузки Column не будет, риск только в
/// нечитаемо мелком тексте на совсем крошечных высотах (тут запас 10px всё ещё
/// разборчив после scaleDown).
const double kCompactMinTextHeight = 10.0;

/// Минимальная ширина для отображения диапазона времени (он длиннее заголовка).
const double kCompactMinTimeWidth = 64.0;

/// Минимальная высота, при которой под заголовком ещё есть место для строки
/// времени в узком виде.
const double kCompactMinTimeHeight = 40.0;

/// Решает, что рисовать в блоке узкого вида (3 дня / неделя) по его фактическим
/// ширине [width] и высоте [height]. Чистая функция — покрыта юнит-тестами.
CompactBlockContent compactBlockContent(double width, double height) {
  if (width < kCompactMinTextWidth || height < kCompactMinTextHeight) {
    return CompactBlockContent.colorOnly;
  }
  if (width >= kCompactMinTimeWidth && height >= kCompactMinTimeHeight) {
    return CompactBlockContent.titleAndTime;
  }
  return CompactBlockContent.titleOnly;
}

/// Резерв «тела» блока (тап → карточка-деталь, долгое нажатие → перенос),
/// который остаётся ВСЕГДА, даже на самом коротком блоке — иначе нижняя ручка
/// ресайза съедала бы блок целиком, и тело стало бы недостижимо для tap/move.
/// Служит НИЖНЕЙ границей резерва (см. bottomHandleHeight) — на маленьких
/// блоках реальный резерв обычно БОЛЬШЕ этого значения (половина блока).
const double kHandleBodyReserve = 8.0;

/// Высота зоны хвата нижней ручки ресайза для блока высотой [blockHeight].
///
/// BUG-FIX (маленький блок нельзя было сразу перетащить, только ресайзить):
/// раньше резерв тела был ФИКСИРОВАННЫМ [minBodyReserve] (8px) независимо от
/// высоты блока — на реальном блоке-минимуме (24px, минимум durationToHeight)
/// это давало ручке 16px (67% площади блока), а телу — тонкую полоску 8px
/// (33%) наверху. Палец не может надёжно попасть в 8-пиксельную полосу —
/// пользователь «всегда сначала ресайзил», хотя хотел подвинуть короткую
/// задачу. Теперь ниже порога [handleHitHeight] + [minBodyReserve] (по
/// умолчанию 30px — граница, где ручка ещё помещается полностью) резерв тела
/// растёт линейно и на блоке-минимуме достигает ПОЛОВИНЫ высоты — тело
/// остаётся БОЛЬШИНСТВОМ (или равной долей) площади блока при любом размере,
/// а не тонкой полоской. На вырожденно крошечных блоках (резерв половины
/// блока всё ещё меньше [minBodyReserve]) ручка обнуляется совсем — ниже
/// [_BlockContent] такой блок рисуется БЕЗ ручки ресайза вовсе (см.
/// `showResizeHandle && handleHeight > 0`), то есть весь блок становится
/// зоной переноса/тапа, а ресайз доступен только когда блок подрастёт.
///
/// На обычных блоках (>= [handleHitHeight] + [minBodyReserve], т.е. по
/// умолчанию 30px) высота ручки полная ([handleHitHeight], 22px) — поведение
/// НЕ регрессирует, только маленькие блоки становятся надёжно перетаскиваемы.
/// Чистая функция — покрыта юнит-тестами.
double bottomHandleHeight(
  double blockHeight, {
  double handleHitHeight = 22.0,
  double minBodyReserve = kHandleBodyReserve,
}) {
  if (blockHeight <= 0) return 0;
  final threshold = handleHitHeight + minBodyReserve;
  if (blockHeight >= threshold) return handleHitHeight;
  // Маленький блок: резерв тела — не меньше половины блока (тело остаётся
  // БОЛЬШИНСТВОМ площади), но и не меньше minBodyReserve (совместимость с
  // кастомными/очень маленькими резервами).
  final halfBody = blockHeight / 2;
  final reserve = halfBody > minBodyReserve ? halfBody : minBodyReserve;
  final available = blockHeight - reserve;
  // Вырожденный случай (даже половина блока меньше резерва тела) — ручки НЕТ
  // совсем: весь блок остаётся зоной переноса/тапа (см. showResizeHandle &&
  // handleHeight > 0 в _BlockContent). Лучше блок без резайза, чем блок,
  // который нельзя ни подвинуть, ни надёжно ресайзнуть.
  return available < 0 ? 0 : available;
}

/// Раскладка перекрывающихся событий по равным колонкам-«дорожкам».
/// Возвращает для каждого индекса входного списка пару (lane, laneCount):
/// номер дорожки и общее число дорожек в его группе пересечений.
/// Группа — связное множество событий, пересекающихся по времени; внутри
/// группы события распределяются жадно по первой свободной дорожке.
/// [items] должны идти в порядке возрастания начала (как из DAO).
List<({int lane, int laneCount})> computeOverlapLanes(
  List<({int startMin, int endMin})> items,
) {
  final result = List<({int lane, int laneCount})>.filled(
    items.length,
    (lane: 0, laneCount: 1),
  );
  if (items.isEmpty) return result;

  // Индексы по возрастанию начала (стабильно к исходному порядку).
  final order = List<int>.generate(items.length, (i) => i)
    ..sort((a, b) {
      final c = items[a].startMin.compareTo(items[b].startMin);
      return c != 0 ? c : a.compareTo(b);
    });

  var groupStart = 0; // позиция в order, где началась текущая группа
  var groupMaxEnd = -1;
  final laneEnds = <int>[]; // конец события в каждой активной дорожке

  void finalizeGroup(int endExclusive) {
    final count = laneEnds.isEmpty ? 1 : laneEnds.length;
    for (var k = groupStart; k < endExclusive; k++) {
      final idx = order[k];
      result[idx] = (lane: result[idx].lane, laneCount: count);
    }
  }

  for (var k = 0; k < order.length; k++) {
    final idx = order[k];
    final it = items[idx];
    // Новая группа, если событие начинается после конца всей предыдущей группы.
    if (it.startMin >= groupMaxEnd) {
      if (k > 0) finalizeGroup(k);
      groupStart = k;
      groupMaxEnd = it.endMin;
      laneEnds
        ..clear()
        ..add(it.endMin);
      result[idx] = (lane: 0, laneCount: 1);
      continue;
    }
    // Ищем первую дорожку, освободившуюся к началу события.
    var placed = -1;
    for (var lane = 0; lane < laneEnds.length; lane++) {
      if (laneEnds[lane] <= it.startMin) {
        placed = lane;
        laneEnds[lane] = it.endMin;
        break;
      }
    }
    if (placed == -1) {
      placed = laneEnds.length;
      laneEnds.add(it.endMin);
    }
    result[idx] = (lane: placed, laneCount: laneEnds.length);
    if (it.endMin > groupMaxEnd) groupMaxEnd = it.endMin;
  }
  finalizeGroup(order.length);
  return result;
}

// ===========================================================================
// Общие константы раскладки
// ===========================================================================

const double _kGutterWidth = 44.0; // ширина левой колонки с метками часов
const double _kHeaderHeight = 44.0; // высота шапки с днями недели (week)
const int _kHoursInDay = 24;
const int _kDefaultScrollHour = 7; // прокрутка по умолчанию ~7:00

/// Цвет-«полоса» задачи для индикаторов (например, точки/полоски месяца):
/// пользовательский цвет-метка имеет приоритет, иначе ember для exam/deadline,
/// accent для main, иначе нейтральный border. Чистая функция — переиспользуется
/// месячным видом, чтобы правило цвета было единым с сеткой времени.
Color taskStripeColor(
  ItemsTableData item,
  FocusThemeExtension? ext,
  ColorScheme scheme,
) {
  final userColor = taskColorFromKey(item.color);
  if (userColor != null) return userColor;
  if (item.type == 'exam' || item.type == 'deadline') {
    return ext?.ember ?? scheme.secondary;
  }
  if (item.priority == 'main') return scheme.primary;
  return ext?.border ?? scheme.outline;
}

/// Автоконтрастный текст для заливки [bg]: тёмный near-black на светлом фоне,
/// почти-белый на тёмном. Считается по ВОСПРИНИМАЕМОЙ яркости заливки
/// (computeLuminance), а не хардкодом цвета темы — поэтому блок читаем при любой
/// (в т.ч. кастомной) теме и любом цвете-метке задачи. Порог 0.5 — стандартная
/// граница «светлый/тёмный фон» для контраста текста.
Color _onColorFor(Color bg) {
  return bg.computeLuminance() > 0.5
      ? const Color(0xFF1A1A1A)
      : const Color(0xFFFFFFFF);
}

/// Граница блока — тот же цвет, что и фон, но СДВИНУТЫЙ к контрасту текста
/// (чуть темнее на светлом фоне, чуть светлее на тёмном). Даёт явный кант, чтобы
/// блок не сливался с соседними/с колонкой, не нарушая однородность рамки
/// (неоднородный Border + borderRadius = краш на paint).
Color _borderFor(Color bg) {
  // 18% к контрастному полюсу: видимая, но не кричащая граница.
  return Color.lerp(bg, _onColorFor(bg), 0.18) ?? bg;
}

/// Цвет блока события по типу/приоритету (accent discipline: ember только
/// для urgent, accent только для main, остальное — нейтрали).
///
/// Стиль «Google Calendar»: блок — ПЛОТНАЯ заливка цветом задачи (не
/// полупрозрачная «вода»), текст — автоконтраст по яркости заливки, граница —
/// тот же цвет, сдвинутый к контрасту (видимый кант). Так блок читается на любой
/// теме и не сливается с фоном колонки. [accentStripe] — насыщенный исходный
/// цвет для левой полоски-акцента (ярче плотной заливки, особенно для нейтралей).
({Color bg, Color fg, Color border, Color accentStripe}) _blockColors(
  ItemsTableData item,
  FocusThemeExtension? ext,
  ColorScheme scheme,
) {
  final ember = ext?.ember ?? scheme.secondary;
  final accent = scheme.primary;
  // Фон колонки — куда «отступает» заливка выполненной задачи (B4): lerp к нему
  // гасит насыщенность, не делая блок прозрачным (что плодило бы слои покраски).
  final surface = scheme.surface;
  // Выполненная задача визуально приглушена: заливка тянется к surface, граница
  // и левый акцент — тоже, текст становится muted. Strikethrough рисуется отдельно
  // (в _BlockContent). Доля приглушения подобрана так, чтобы блок «отступал», но
  // оставался читаем (автоконтраст текста считается уже по приглушённой заливке).
  const doneBgLerp = 0.55; // насколько заливка тянется к surface
  const doneFgAlpha = 0.6; // текст выполненной задачи слегка тусклее
  final isDone = item.status == 'done';

  // Плотный блок из насыщенного цвета [base]: заливка = сам цвет (полностью
  // непрозрачный, поверх фона колонки), текст и граница — производные от него.
  // Для выполненной задачи заливка приглушается (lerp к surface), а текст —
  // приглушённый автоконтраст по уже приглушённой заливке.
  ({Color bg, Color fg, Color border, Color accentStripe}) dense(Color base) {
    final bg = isDone
        ? (Color.lerp(base, surface, doneBgLerp) ?? base)
        : base;
    final fg = isDone
        ? _onColorFor(bg).withValues(alpha: doneFgAlpha)
        : _onColorFor(bg);
    final stripe = isDone
        ? (Color.lerp(base, surface, doneBgLerp * 0.6) ?? base)
        : base;
    return (
      bg: bg,
      fg: fg,
      border: _borderFor(bg),
      accentStripe: stripe,
    );
  }

  // Пользовательский цвет-метка имеет приоритет над типом/приоритетом.
  final userColor = taskColorFromKey(item.color);
  if (userColor != null) return dense(userColor);

  if (item.type == 'exam' || item.type == 'deadline') return dense(ember);
  if (item.priority == 'main') return dense(accent);

  // Нейтральная задача (без цвета/типа/main): плотная заливка приглушённым
  // цветом-меткой («gray» из палитры) — всё ещё чёткая плашка, но не претендует
  // на акцент темы. Левая полоска — нейтральный border темы для тонкого намёка.
  final neutral = ext?.textMuted ?? scheme.outline;
  final neutralBg = isDone
      ? (Color.lerp(neutral, surface, doneBgLerp) ?? neutral)
      : neutral;
  final neutralStripe = ext?.border ?? scheme.outline;
  return (
    bg: neutralBg,
    fg: isDone
        ? _onColorFor(neutralBg).withValues(alpha: doneFgAlpha)
        : _onColorFor(neutralBg),
    border: _borderFor(neutralBg),
    accentStripe: isDone
        ? (Color.lerp(neutralStripe, surface, doneBgLerp * 0.6) ?? neutralStripe)
        : neutralStripe,
  );
}

// ===========================================================================
// Day grid
// ===========================================================================

/// Дневная сетка времени: одна колонка, питается dayItemsProvider(selectedDay).
class DayTimeGrid extends ConsumerWidget {
  const DayTimeGrid({super.key, this.hourHeight = kHourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final itemsAsync = ref.watch(dayItemsProvider(selectedDay));

    final now = DateTime.now();
    final todayNorm = DateTime(now.year, now.month, now.day);
    final selectedNorm =
        DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final isToday = selectedNorm == todayNorm;

    if (itemsAsync.isLoading && itemsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }
    final items = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    // Фильтр по тексту/#тегу/типу (planSearchMatches) + фильтр-панель
    // приоритет/статус/тип (planFilterMatches) — та же AND-семантика, что
    // в day_timeline.dart/week_agenda.dart/month_view.dart. Раньше сетка
    // (блочный вид) применяла только текстовый фильтр — панель приоритет/
    // статус/тип на неё не действовала (баг).
    final query = ref.watch(planSearchQueryProvider);
    final filters = ref.watch(planFiltersProvider);
    final filtered = (query.trim().isEmpty && filters.isEmpty)
        ? items
        : items.where((i) {
            final searchOk =
                query.trim().isEmpty || planSearchMatches(i, query);
            return searchOk && planFilterMatches(i, filters);
          }).toList();

    return _TimeGridScaffold(
      hourHeight: hourHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final colWidth = constraints.maxWidth - _kGutterWidth;
          return Stack(
            children: [
              // Статичный слой линий часов изолирован от перерисовки: drag
              // соседнего блока не должен перерисовывать сетку.
              RepaintBoundary(
                child: _HourLinesAndGutter(hourHeight: hourHeight),
              ),
              Positioned(
                left: _kGutterWidth,
                top: 0,
                width: colWidth < 0 ? 0 : colWidth,
                height: hourHeight * _kHoursInDay,
                child: _DayColumn(
                  day: selectedDay,
                  items: filtered,
                  hourHeight: hourHeight,
                ),
              ),
              // Линия текущего времени — только если выбран сегодняшний день.
              // Поверх блоков, но не интерактивна (IgnorePointer внутри),
              // поэтому tap/drag блоков не перехватывает.
              if (isToday)
                Positioned(
                  left: _kGutterWidth,
                  top: 0,
                  width: colWidth < 0 ? 0 : colWidth,
                  height: hourHeight * _kHoursInDay,
                  child: _NowIndicator(hourHeight: hourHeight),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// Week grid
// ===========================================================================

/// Недельная сетка: 7 колонок-дней от понедельника недели выбранного дня.
class WeekTimeGrid extends ConsumerWidget {
  const WeekTimeGrid({super.key, this.hourHeight = kHourHeight});

  final double hourHeight;

  DateTime _weekStart(DateTime date) {
    final daysFromMonday = date.weekday - 1;
    return DateTime(date.year, date.month, date.day - daysFromMonday);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final weekStart = _weekStart(selectedDay);
    return _NDayTimeGrid(startDay: weekStart, dayCount: 7, hourHeight: hourHeight);
  }
}

/// Трёхдневная сетка: 3 колонки-дня, начиная с ВЫБРАННОГО дня (selectedDay,
/// +1, +2). Та же инфраструктура, что у недельной (общая ось часов, шапка дней,
/// блоки), но колонки шире — три дня удобнее читать на телефоне.
class ThreeDayTimeGrid extends ConsumerWidget {
  const ThreeDayTimeGrid({super.key, this.hourHeight = kHourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    return _NDayTimeGrid(
      startDay: selectedDay,
      dayCount: 3,
      hourHeight: hourHeight,
    );
  }
}

/// Обобщённая N-дневная сетка времени: [dayCount] колонок-дней от [startDay]
/// с общей вертикальной осью часов. WeekTimeGrid = 7 от начала недели,
/// ThreeDayTimeGrid = 3 от выбранного дня. Данные берёт реактивно из
/// rangeItemsProvider на полуоткрытый интервал [startDay, startDay+dayCount).
class _NDayTimeGrid extends ConsumerWidget {
  const _NDayTimeGrid({
    required this.startDay,
    required this.dayCount,
    required this.hourHeight,
  });

  final DateTime startDay;
  final int dayCount;
  final double hourHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = List.generate(
      dayCount,
      (i) => DateTime(startDay.year, startDay.month, startDay.day + i),
    );

    // Реактивный диапазон через rangeItemsProvider. Границы — локальная
    // полночь, согласованы с watchItemsInRange/watchTodayItems.
    final from = localDayStart(startDay);
    final to = from.add(Duration(days: dayCount));
    final itemsAsync = ref.watch(rangeItemsProvider((from, to)));

    if (itemsAsync.isLoading && itemsAsync.valueOrNull == null) {
      return const Center(child: KaiLoader());
    }
    final allItems = itemsAsync.valueOrNull ?? const <ItemsTableData>[];
    // Фильтр по тексту/#тегу/типу (planSearchMatches) + фильтр-панель
    // приоритет/статус/тип (planFilterMatches) — та же AND-семантика, что
    // в day_timeline.dart/week_agenda.dart/month_view.dart (баг: раньше эта
    // N-дневная сетка — Week/3-day — применяла только текстовый фильтр).
    final query = ref.watch(planSearchQueryProvider);
    final filters = ref.watch(planFiltersProvider);
    final items = (query.trim().isEmpty && filters.isEmpty)
        ? allItems
        : allItems.where((i) {
            final searchOk =
                query.trim().isEmpty || planSearchMatches(i, query);
            return searchOk && planFilterMatches(i, filters);
          }).toList();

    // Группируем по календарному дню (по локальной дате scheduledAt).
    Map<DateTime, List<ItemsTableData>> byDay = {
      for (final d in days) d: <ItemsTableData>[],
    };
    for (final it in items) {
      final dt = it.scheduledAt;
      final key = DateTime(dt.year, dt.month, dt.day);
      byDay[key]?.add(it);
    }

    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth =
            (constraints.maxWidth - _kGutterWidth) / dayCount;
        // Пытаемся уместить колонки; если совсем узко — горизонтальный скролл.
        const minColWidth = 40.0;
        final fits = colWidth >= minColWidth;
        final effectiveColWidth = fits ? colWidth : minColWidth;
        final totalWidth = _kGutterWidth + effectiveColWidth * dayCount;

        final grid = SizedBox(
          width: totalWidth,
          child: Column(
            children: [
              // Шапка с днями
              SizedBox(
                height: _kHeaderHeight,
                child: Row(
                  children: [
                    const SizedBox(width: _kGutterWidth),
                    for (final d in days)
                      SizedBox(
                        width: effectiveColWidth,
                        child: _WeekDayHeader(
                          day: d,
                          isToday: d == todayNorm,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: _TimeGridScaffold(
                  hourHeight: hourHeight,
                  child: Stack(
                    children: [
                      // Статичный слой линий часов изолирован от перерисовки:
                      // drag соседнего блока не должен перерисовывать сетку.
                      RepaintBoundary(
                        child: _HourLinesAndGutter(hourHeight: hourHeight),
                      ),
                      for (var i = 0; i < days.length; i++)
                        Positioned(
                          left: _kGutterWidth + effectiveColWidth * i,
                          top: 0,
                          width: effectiveColWidth,
                          height: hourHeight * _kHoursInDay,
                          child: _DayColumn(
                            day: days[i],
                            items: byDay[days[i]] ?? const [],
                            hourHeight: hourHeight,
                            compact: true,
                          ),
                        ),
                      // Линия текущего времени — в колонке сегодняшнего дня (если
                      // он попал в диапазон). Поверх блоков, не интерактивна.
                      for (var i = 0; i < days.length; i++)
                        if (days[i] == todayNorm)
                          Positioned(
                            left: _kGutterWidth + effectiveColWidth * i,
                            top: 0,
                            width: effectiveColWidth,
                            height: hourHeight * _kHoursInDay,
                            child: _NowIndicator(hourHeight: hourHeight),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        if (fits) return grid;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: totalWidth, child: grid),
        );
      },
    );
  }
}

/// Шапка одной колонки недели: день недели + число, today подсвечен.
class _WeekDayHeader extends StatelessWidget {
  const _WeekDayHeader({required this.day, required this.isToday});

  final DateTime day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? scheme.onSurface;
    final textTheme = Theme.of(context).textTheme;
    final color = isToday ? scheme.primary : scheme.onSurface;

    // FittedBox масштабирует содержимое вниз, чтобы шапка фиксированной высоты
    // (_kHeaderHeight) не переполнялась при крупном системном тексте (scale 1.5).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            // Безопасная короткая подпись дня недели: на локалях с 1–2-символьной
            // аббревиатурой (ru «пн», ja «月») substring(0,3) бросал RangeError,
            // и заголовок КАЖДОЙ колонки падал в красный ErrorWidget.
            shortWeekdayLabel(day),
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: textTheme.labelSmall?.copyWith(
              color: isToday ? scheme.primary : textMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            day.day.toString(),
            maxLines: 1,
            style: textTheme.bodyMedium?.copyWith(
              color: color,
              // w500 вместо w700 (design tokens: max w600 rare)
              fontWeight: isToday ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Общая обвязка: вертикальный скролл с авто-прокруткой на ~7:00
// ===========================================================================

class _TimeGridScaffold extends StatefulWidget {
  const _TimeGridScaffold({required this.hourHeight, required this.child});

  final double hourHeight;
  final Widget child;

  @override
  State<_TimeGridScaffold> createState() => _TimeGridScaffoldState();
}

class _TimeGridScaffoldState extends State<_TimeGridScaffold> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.hourHeight * _kDefaultScrollHour,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _controller,
      child: SizedBox(
        height: widget.hourHeight * _kHoursInDay,
        child: widget.child,
      ),
    );
  }
}

/// Левый «жёлоб» с метками часов и горизонтальные линии часов на всю ширину.
class _HourLinesAndGutter extends StatelessWidget {
  const _HourLinesAndGutter({required this.hourHeight});

  final double hourHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final border = ext?.border ?? scheme.outline;
    final textFaint = ext?.textFaint ?? scheme.onSurface;
    final textTheme = Theme.of(context).textTheme;

    return Stack(
      children: [
        for (var h = 0; h <= _kHoursInDay; h++)
          Positioned(
            top: h * hourHeight,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _kGutterWidth,
                  child: h < _kHoursInDay
                      ? Padding(
                          padding: const EdgeInsets.only(right: 6, top: 0),
                          child: Text(
                            '${h.toString().padLeft(2, '0')}:00',
                            textAlign: TextAlign.right,
                            style: textTheme.labelSmall?.copyWith(
                              color: textFaint,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Expanded(
                  child: Container(height: 0.5, color: border),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// Линия текущего времени («now» indicator)
// ===========================================================================

/// Тонкая горизонтальная линия на уровне текущего времени + кружок-«пуговица»
/// слева (как Google/Apple Calendar). Показывается ТОЛЬКО в колонке сегодняшнего
/// дня — вызывающий код вставляет её лишь для today.
///
/// Перф: собственный [Timer.periodic] на МИНУТУ (не секунду — позиция меняется
/// раз в минуту, секундный тайм ер зря будил бы дерево), setState только сдвигает
/// top. Обёрнут в свой [RepaintBoundary], не интерактивен ([IgnorePointer]),
/// поэтому не перерисовывает блоки/сетку и не перехватывает tap/drag.
class _NowIndicator extends StatefulWidget {
  const _NowIndicator({required this.hourHeight});

  final double hourHeight;

  @override
  State<_NowIndicator> createState() => _NowIndicatorState();
}

class _NowIndicatorState extends State<_NowIndicator> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Минутный таймер: позиция линии меняется раз в минуту. Отменяется в dispose.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // Цвет — приглушённый акцент, НЕ ember-urgent (линия времени — нейтральный
    // ориентир, не тревога). На Contrast-теме disableAnimations не влияет на
    // цвет; контраст обеспечиваем через border темы, чтобы линия была видна на
    // ярком фоне (там accent сливался бы). Иначе — primary темы.
    final reduce = reduceMotionOf(context);
    final lineColor = reduce
        ? (ext?.border ?? scheme.outline)
        : scheme.primary;

    final nowMin = minutesFromMidnight(DateTime.now());
    final top = minutesToOffset(nowMin, widget.hourHeight);

    // Не интерактивен: не должен перехватывать tap/drag блоков под/над ним.
    return IgnorePointer(
      child: RepaintBoundary(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              // Линия идёт на всю ширину колонки; кружок «свисает» влево за её
              // левый край (в зону жёлоба), как у Google/Apple Calendar.
              top: top - 0.5,
              left: 0,
              right: 0,
              child: Row(
                children: [
                  // Кружок-«пуговица» слева, центрирован по линии.
                  Transform.translate(
                    offset: const Offset(-3, 0),
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(child: Container(height: 1.5, color: lineColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Колонка одного дня с блоками-событиями (drag/resize/tap)
// ===========================================================================

class _DayColumn extends ConsumerWidget {
  const _DayColumn({
    required this.day,
    required this.items,
    required this.hourHeight,
    this.compact = false,
  });

  final DateTime day;
  final List<ItemsTableData> items;
  final double hourHeight;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Форма задачи (task_shape.dart) решает, как она входит в раскладку:
    //   • block — как раньше, конец = начало + длительность;
    //   • open  — «эффективный» конец для раскладки/рендера — до следующего
    //     события дня (любой формы) или до конца суток, а НЕ item.durationMinutes
    //     (там сентинел -1 — durationToHeight/спаны никогда не должны получать
    //     его напрямую, иначе высота/интервал будут отрицательными);
    //   • moment — исключается из блоков-с-лейнами совсем: рисуется отдельным
    //     маркером НАД блоками (_MomentMarker), без лейна и без резервирования
    //     места на сетке.
    final allStarts =
        items.map((i) => minutesFromMidnight(i.scheduledAt)).toList();

    final blockLike = <ItemsTableData>[];
    final moments = <ItemsTableData>[];
    for (final i in items) {
      if (taskShapeOf(i.durationMinutes) == TaskShape.moment) {
        moments.add(i);
      } else {
        blockLike.add(i);
      }
    }

    final spans = blockLike.map((i) {
      final startMin = minutesFromMidnight(i.scheduledAt);
      final endMin = taskShapeOf(i.durationMinutes) == TaskShape.open
          ? startMin +
              openEndedDurationMinutes(
                startMin,
                nextStartMin: nextStartAfter(startMin, allStarts),
              )
          : startMin + i.durationMinutes;
      return (startMin: startMin, endMin: endMin);
    }).toList();
    final lanes = computeOverlapLanes(spans);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Stack(
          children: [
            // ПОД блоками — слой рисования новой задачи (drag-to-create). Долгое
            // нажатие (_kBlockPickupDelay) на ПУСТОМ месте колонки → ghost-блок,
            // тяга рисует интервал, отпускание открывает лист добавления.
            // Блоки лежат ВЫШЕ в Stack, поэтому их long-press/tap/resize
            // перехватывают касания над собой первыми, а этот слой ловит только
            // пустые области. Подробности арены — в _CreateLayer.
            Positioned.fill(
              child: _CreateLayer(
                day: day,
                hourHeight: hourHeight,
              ),
            ),
            for (var i = 0; i < blockLike.length; i++)
              // Positioned должен быть прямым потомком Stack, поэтому _EventBlock
              // кладётся в Stack напрямую. RepaintBoundary для изоляции
              // перерисовки блока во время drag/resize находится внутри
              // _EventBlock (оборачивает child у Positioned).
              _EventBlock(
                key: ValueKey(blockLike[i].id),
                item: blockLike[i],
                day: day,
                hourHeight: hourHeight,
                columnWidth: width,
                lane: lanes[i].lane,
                laneCount: lanes[i].laneCount,
                compact: compact,
                effectiveDurationMinutes: spans[i].endMin - spans[i].startMin,
              ),
            // Маркеры-«моменты» — НАД блоками, на полную ширину колонки, без
            // лейнов (момент не занимает места на сетке — только точка).
            for (final m in moments)
              _MomentMarker(
                key: ValueKey(m.id),
                item: m,
                day: day,
                top: (minutesToOffset(
                          minutesFromMidnight(m.scheduledAt),
                          hourHeight,
                        ) -
                        kMomentMarkerHeight / 2)
                    .clamp(0.0, double.infinity),
                compact: compact,
              ),
          ],
        );
      },
    );
  }
}

/// Минимальная «нарисованная» длительность, ниже которой жест считается тапом
/// (палец почти не сдвинулся) и задача НЕ создаётся drag-путём. 20 мин > одного
/// снап-шага (15), поэтому случайный микро-потяг не плодит пустые задачи. Сам
/// КОРОТКИЙ ТАП по пустому месту создаёт задачу дефолтной длительности отдельным
/// путём (см. _onTapCreate / _kTapCreateDefaultMinutes).
const int kMinCreateDurationMinutes = 20;

/// Дефолтная длительность задачи, создаваемой КОРОТКИМ ТАПОМ по пустой области
/// (как Google Calendar: тап по пустому слоту → событие на час, которое потом
/// двигают/ресайзят существующими жестами). Вынесена в константу — легко менять.
const int _kTapCreateDefaultMinutes = 60;

/// Эфемерное состояние жеста рисования новой задачи. Хранится в ValueNotifier,
/// чтобы кадр рисования перерисовывал только ghost+подсказку (свой
/// RepaintBoundary), а не всю колонку/сетку — как у блоков.
class _CreateGesture {
  const _CreateGesture(this.topPx, this.heightPx);
  const _CreateGesture.none()
      : topPx = 0,
        heightPx = -1;

  final double topPx;
  final double heightPx;

  /// Активен, пока высота >= 0 (none() ставит -1).
  bool get active => heightPx >= 0;
}

/// Слой рисования новой задачи по пустой области колонки дня (drag-to-create,
/// как Google/Apple/Fantastical/Notion).
///
/// АРЕНА ЖЕСТОВ (почему скролл не воруется). Слой держит ДВА распознавателя,
/// разнесённых по ТИПУ указателя (supportedDevices), чтобы не конкурировать
/// между собой:
///   • ТАЧ (палец): [LongPressGestureRecognizer] с порогом [_kBlockPickupDelay]
///     (~250 мс), как у переноса блоков. LongPress заявляет победу в арене лишь
///     после удержания почти неподвижного пальца; быстрый вертикальный свайп
///     сдвигает палец раньше срабатывания — арену выигрывает родительский
///     SingleChildScrollView (скролл сетки работает). «Придержал → рисуешь»,
///     «свайпнул → листаешь».
///   • МЫШЬ/ТРЕКПАД/СТИЛУС: [PanGestureRecognizer] — рисование СРАЗУ по
///     нажатию-и-протягиванию, БЕЗ удержания (как Google Calendar на вебе).
///     Точный указатель не конфликтует со скроллом так, как палец, поэтому
///     удержание ему не нужно. Оба drag-пути переиспользуют одну ghost-логику
///     (_beginDrawAt / _updateDrawTo / _endDraw).
///   • ЛЮБОЙ указатель — КОРОТКИЙ ТАП: [TapGestureRecognizer] → задача
///     ДЕФОЛТНОЙ длительности (_kTapCreateDefaultMinutes) на снэпнутое время
///     тапа (_onTapCreate). Tap выигрывает арену лишь когда не было drag — при
///     протягивании побеждает pan/long-press-move, поэтому «тап = дефолт»,
///     «протянул = диапазон» не конфликтуют.
///
/// Слой лежит ПОД блоками (раньше в Stack), behavior = opaque, поэтому ловит
/// касания только на ПУСТЫХ участках: над блоком его tap/long-press-move/resize
/// перехватывают сами блоки. Ghost рисуется через [ValueNotifier]+собственный
/// [RepaintBoundary], без setState всей колонки.
class _CreateLayer extends StatefulWidget {
  const _CreateLayer({
    required this.day,
    required this.hourHeight,
  });

  final DateTime day;
  final double hourHeight;

  @override
  State<_CreateLayer> createState() => _CreateLayerState();
}

class _CreateLayerState extends State<_CreateLayer> {
  // Эфемерное состояние ghost. ValueNotifier (не setState) — кадр рисования
  // перерисовывает только ghost+подсказку в своём RepaintBoundary.
  final ValueNotifier<_CreateGesture> _ghost =
      ValueNotifier(const _CreateGesture.none());

  // Сырой top старта и текущий низ (в пикселях от начала колонки). Старт
  // фиксируется в onLongPressStart по localPosition, низ ведётся в move.
  double _startTop = 0;
  double _currentBottom = 0;

  // Снап-хаптика: последний слот (минуты), на котором уже был тик. Сбрасывается
  // на старте; тик при смене 15-мин слота конца — переиспользуем приём блоков.
  int? _lastSnapSlot;

  void _tickOnSnapChange(int slot) {
    if (_lastSnapSlot != slot) {
      _lastSnapSlot = slot;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _ghost.dispose();
    super.dispose();
  }

  /// Снэпнутый старт (минуты от полуночи) текущего рисования.
  int get _snappedStartMin =>
      offsetToSnappedMinutes(_startTop, widget.hourHeight);

  /// Снэпнутая длительность (минуты) текущего рисования: разница снэпнутых
  /// концов, минимум одного снап-шага (рисование всегда «вниз» — берём модуль).
  int _snappedDurationMin() {
    final endMin = offsetToSnappedMinutes(_currentBottom, widget.hourHeight);
    final dur = (endMin - _snappedStartMin).abs();
    return dur < kSnapMinutes ? kSnapMinutes : dur;
  }

  // Старт рисования по локальной точке нажатия. Общий код для двух путей:
  // long-press (тач, _onLongPressStart) и немедленный pan (мышь/трекпад/стилус,
  // _onPanStart). [haptic] выключаем для мыши — на десктопе тактильной отдачи нет.
  void _beginDrawAt(Offset localPosition, {bool haptic = true}) {
    if (haptic) HapticFeedback.mediumImpact();
    _startTop = localPosition.dy;
    _currentBottom = localPosition.dy;
    _lastSnapSlot = offsetToSnappedMinutes(_startTop, widget.hourHeight);
    final snappedTop =
        minutesToOffset(_snappedStartMin, widget.hourHeight);
    _ghost.value = _CreateGesture(snappedTop, 0);
  }

  // Обновление по СУММАРНОМУ смещению от точки старта (offsetFromOrigin у
  // long-press, накопленная дельта у pan). Общий код для двух путей.
  void _updateDrawTo(double totalDy) {
    _currentBottom = _startTop + totalDy;
    final endSlot = offsetToSnappedMinutes(_currentBottom, widget.hourHeight);
    _tickOnSnapChange(endSlot);
    // Рисуем от снэпнутого старта до снэпнутого конца (всегда вниз: высота по
    // модулю, top = меньшая из границ).
    final startSnapMin = _snappedStartMin;
    final endSnapMin = endSlot;
    final topMin = startSnapMin < endSnapMin ? startSnapMin : endSnapMin;
    final durMin = (endSnapMin - startSnapMin).abs();
    final topPx = minutesToOffset(topMin, widget.hourHeight);
    final heightPx = durationToHeight(
      durMin < kSnapMinutes ? kSnapMinutes : durMin,
      widget.hourHeight,
      minHeight: 0,
    );
    _ghost.value = _CreateGesture(topPx, heightPx);
  }

  // Завершение рисования: общий код для обоих путей. Слишком короткий диапазон
  // (микро-движение мышью или почти-тап) — НЕ создаём.
  void _endDraw() {
    final wasActive = _ghost.value.active;
    _ghost.value = const _CreateGesture.none();
    if (!wasActive) return;
    final durMin = _snappedDurationMin();
    // Слишком короткий диапазон (по сути тап) — НЕ создаём.
    if (durMin < kMinCreateDurationMinutes) return;
    HapticFeedback.selectionClick();
    final startMin = _snappedStartMin;
    final startAt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      startMin ~/ 60,
      startMin % 60,
    );
    // Открываем лист добавления с предзаполнением начала и длительности.
    showAddTaskSheet(
      context,
      day: widget.day,
      initialAt: startAt,
      initialDurationMinutes: durMin,
    );
  }

  void _onCancel() {
    _ghost.value = const _CreateGesture.none();
  }

  /// КОРОТКИЙ ТАП по пустой области (без протягивания/удержания-с-движением):
  /// создаёт задачу ДЕФОЛТНОЙ длительности (_kTapCreateDefaultMinutes) на
  /// снэпнутое к 15 мин время тапа и открывает лист добавления. После сохранения
  /// это обычный блок, который двигают/ресайзят существующими жестами. Тап по
  /// БЛОКУ сюда не доходит — блоки лежат выше в Stack и перехватывают свой tap.
  void _onTapCreate(TapUpDetails d) {
    final startMin = offsetToSnappedMinutes(d.localPosition.dy, widget.hourHeight);
    final startAt = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      startMin ~/ 60,
      startMin % 60,
    );
    HapticFeedback.selectionClick();
    showAddTaskSheet(
      context,
      day: widget.day,
      initialAt: startAt,
      initialDurationMinutes: _kTapCreateDefaultMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        // КОРОТКИЙ ТАП (любой указатель) по пустому месту → задача дефолтной
        // длительности (как Google Calendar). Tap выигрывает арену только когда
        // НЕ было протягивания/удержания-с-движением: при drag-create арену
        // забирает pan (мышь) или long-press-move (тач), и tap проигрывает —
        // поэтому «тап = дефолт», «протянул = диапазон» не конфликтуют.
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (r) {
            r.onTapUp = _onTapCreate;
          },
        ),
        // ТАЧ-путь: удержание (_kBlockPickupDelay) → рисование. Ограничен пальцем
        // (supportedDevices = touch), чтобы на тач-устройстве короткий свайп
        // уходил скроллу сетки, а удержание брало рисование. Мышь сюда не идёт —
        // у неё отдельный немедленный pan ниже.
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: _kBlockPickupDelay,
            supportedDevices: const {PointerDeviceKind.touch},
          ),
          (r) {
            // Блочные тела колбэков (не arrow): сеттеры распознавателя
            // возвращают void, а arrow `=> _endDraw()` «использовал» бы void-
            // результат (use_of_void_result) — как у resize-распознавателей ниже.
            r
              ..onLongPressStart = (d) {
                _beginDrawAt(d.localPosition);
              }
              ..onLongPressMoveUpdate = (d) {
                _updateDrawTo(d.offsetFromOrigin.dy);
              }
              ..onLongPressEnd = (_) {
                _endDraw();
              }
              ..onLongPressCancel = _onCancel;
          },
        ),
        // МЫШЬ/ТРЕКПАД/СТИЛУС-путь (как Google Calendar на вебе): рисование
        // начинается СРАЗУ по нажатию-и-протягиванию, БЕЗ удержания. Точный
        // указатель не конфликтует с вертикальным скроллом так, как палец,
        // поэтому удержание ему не нужно. supportedDevices исключает touch —
        // палец идёт по long-press выше. Переиспользует ту же ghost-логику.
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(
            supportedDevices: const {
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          (r) {
            r
              ..onStart = (d) {
                _beginDrawAt(d.localPosition, haptic: false);
              }
              ..onUpdate = (d) {
                // localPosition.dy − старт = суммарное смещение от точки нажатия
                // (та же семантика, что offsetFromOrigin у long-press пути).
                _updateDrawTo(d.localPosition.dy - _startTop);
              }
              ..onEnd = (_) {
                _endDraw();
              }
              ..onCancel = _onCancel;
          },
        ),
      },
      // Ghost изолирован в свой RepaintBoundary: кадр рисования не перерисовывает
      // колонку/сетку. Когда жест неактивен — пустой Stack (нулевая стоимость).
      child: RepaintBoundary(
        child: ValueListenableBuilder<_CreateGesture>(
          valueListenable: _ghost,
          builder: (context, g, _) {
            if (!g.active) return const SizedBox.expand();
            final startMin = _snappedStartMin;
            final durMin = _snappedDurationMin();
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  top: g.topPx,
                  left: 0,
                  right: 0,
                  height: g.heightPx < 2 ? 2 : g.heightPx,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      // Полупрозрачный акцент темы — «ghost» будущей задачи.
                      color: scheme.primary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
                // Плавающая подсказка времени — как у блоков (_GestureLabel).
                Positioned(
                  top: g.topPx + 2,
                  left: 4,
                  child: _GestureLabel(
                    text: '${formatMinutesOfDay(startMin)}  ·  '
                        '${_durationShort(durMin)}',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Активный жест блока: перенос (drag), изменение длительности через нижнюю
/// ручку (resize, меняет конец блока) или «приземление» после коммита
/// (settling). Верхней ручки (resize начала) больше нет — по решению владельца
/// продукта оставлена ТОЛЬКО нижняя ручка ресайза (см. bottomHandleHeight).
enum _GestureKind { none, drag, resize, settling }

/// Эфемерное состояние жеста блока. Хранится в ValueNotifier, чтобы во время
/// жеста перерисовывался только Positioned + плавающая подсказка, а не весь
/// контент блока (заголовок/время/мета) и тем более не вся колонка/сетка.
class _BlockGesture {
  const _BlockGesture(this.kind, this.topPx, this.heightPx);
  const _BlockGesture.none()
      : kind = _GestureKind.none,
        topPx = 0,
        heightPx = 0;

  final _GestureKind kind;
  final double topPx;
  final double heightPx;

  bool get active => kind != _GestureKind.none;
}

/// Один блок-событие. Long-press начинает перенос (не мешает скроллу списка);
/// нижняя ручка с увеличенной зоной хвата меняет длительность; короткий тап
/// открывает карточку-деталь. Во время жеста — лифт (тень/масштаб), тактильная
/// отдача и плавающая подсказка времени.
class _EventBlock extends ConsumerStatefulWidget {
  const _EventBlock({
    super.key,
    required this.item,
    required this.day,
    required this.hourHeight,
    required this.columnWidth,
    required this.lane,
    required this.laneCount,
    required this.compact,
    required this.effectiveDurationMinutes,
  });

  final ItemsTableData item;
  final DateTime day;
  final double hourHeight;
  final double columnWidth;
  final int lane;
  final int laneCount;
  final bool compact;

  /// Длительность (минут, всегда > 0) для расчёта ВЫСОТЫ блока — НЕ то же
  /// самое, что item.durationMinutes для формы [TaskShape.open] (там в БД
  /// лежит сентинел -1). Для [TaskShape.block] совпадает с
  /// item.durationMinutes; для open — посчитана в _DayColumn через
  /// [openEndedDurationMinutes] (до следующего события/конца дня). Передаётся
  /// готовым значением, чтобы durationToHeight никогда не получал -1/0 напрямую.
  final int effectiveDurationMinutes;

  @override
  ConsumerState<_EventBlock> createState() => _EventBlockState();
}

class _EventBlockState extends ConsumerState<_EventBlock> {
  // Эфемерное состояние жеста. ValueNotifier (а не setState) — чтобы кадры
  // drag/resize перерисовывали только геометрию и подсказку, не весь контент.
  final ValueNotifier<_BlockGesture> _gesture =
      ValueNotifier(const _BlockGesture.none());

  // B2 — снап-хаптика: последний снэпнутый слот (в минутах), на котором уже был
  // дан тактильный тик. Сбрасывается в null на старте каждого жеста; при СМЕНЕ
  // слота во время drag/resize даём лёгкий selectionClick и обновляем поле.
  // Так тик звучит ровно на каждом 15-мин шаге, а не на каждом кадре (дребезг).
  int? _lastSnapSlot;

  /// Если текущий снэпнутый слот [slot] отличается от прошлого — даёт лёгкий
  /// тактильный тик и запоминает новый. Вызывается из update-обработчиков жеста.
  void _tickOnSnapChange(int slot) {
    if (_lastSnapSlot != slot) {
      _lastSnapSlot = slot;
      HapticFeedback.selectionClick();
    }
  }

  // B3 — анимация «приземления»: на коммите блок не перескакивает с сырого drag-
  // top на снэпнутый мгновенно, а короткое время держит снэпнутую геометрию в
  // «settling»-состоянии, и AnimatedPositioned плавно довозит его (а лифт-тень
  // мягко гаснет). Таймер чистит settling после kDurationSnap — НО только если
  // нет неподтверждённого коммита (см. _pendingScheduledAt/_pendingDurationMinutes
  // и _maybeClearSettling ниже). Отменяется в dispose, чтобы не было pending Timer.
  Timer? _settleTimer;

  // BUG-FIX (блик на старой позиции при drop, телефон): раньше _settleTimer
  // срабатывал через фиксированные kDurationSnap (120мс), что могло произойти
  // РАНЬШЕ, чем async-запись updateItem/materializeOccurrence долетала до БД,
  // стрим Drift эмитил новое значение и оно доходило до widget.item — тогда
  // _gesture сбрасывался в none, build() считал геометрию по СТАРОМУ
  // widget.item.scheduledAt (провайдер ещё не прислал новый item), и на один
  // кадр блок отрисовывался в СТАРОЙ позиции, прежде чем didUpdateWidget
  // подхватывал новые данные (на вебе БД-запись быстрее 120мс, поэтому там
  // бага не было видно).
  //
  // Фикс: коммит помечает, какое значение scheduledAt/durationMinutes он ждёт
  // от провайдера. Settle-таймер (чисто визуальная анимация лифта/тени) больше
  // НЕ единственный триггер очистки ephemeral-позиции — она снимается ТОЛЬКО
  // когда didUpdateWidget увидит совпадающий widget.item (т.е. репаинт уже
  // несёт новое значение) либо когда коммит явно провалился (см. catch в
  // _commitMove/_commitResize — там ephemeral-позиция сбрасывается сразу, т.к.
  // реальные данные не менялись и мигать нечему).
  DateTime? _pendingScheduledAt;
  int? _pendingDurationMinutes;

  /// Переводит блок в кратковременное «settling»: держит снэпнутую геометрию
  /// [topPx]/[heightPx], чтобы AnimatedPositioned доехал от сырого top к снэпу и
  /// лифт-тень погасла плавно. Через [settleFor] ПЫТАЕТСЯ сброситься в none —
  /// но см. [_maybeClearSettling]: если коммит ещё не подтверждён провайдером,
  /// settling-геометрия (уже приземлённая/снэпнутая — НЕ старая) удерживается
  /// дольше settleFor. При reduce-motion (effectiveDuration == 0) фаза
  /// мгновенна — сразу none (в этот момент коммит ещё не начат: _settle
  /// вызывается ДО выставления _pendingScheduledAt/_pendingDurationMinutes).
  void _settle(double topPx, double heightPx) {
    _settleTimer?.cancel();
    final settleFor = effectiveDuration(context, kDurationSnap);
    if (settleFor == Duration.zero) {
      _gesture.value = const _BlockGesture.none();
      return;
    }
    _gesture.value = _BlockGesture(_GestureKind.settling, topPx, heightPx);
    _settleTimer = Timer(settleFor, () {
      if (!mounted) return;
      _maybeClearSettling();
    });
  }

  /// Снимает settling-состояние (эфемерная позиция → none, build() дальше
  /// использует baseTop/baseHeight из widget.item) — ТОЛЬКО если нет
  /// неподтверждённого коммита. Если есть — оставляем блок в приземлённой
  /// (уже снэпнутой, НЕ старой) позиции: [didUpdateWidget] вызовет эту же
  /// функцию досрочно, как только провайдер пришлёт совпадающий item.
  void _maybeClearSettling() {
    if (_pendingScheduledAt == null &&
        _pendingDurationMinutes == null &&
        _gesture.value.kind == _GestureKind.settling) {
      _gesture.value = const _BlockGesture.none();
    }
  }

  @override
  void didUpdateWidget(covariant _EventBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Провайдер прислал новый item — если он совпадает с тем, что ждал коммит,
    // снимаем ожидание. Саму очистку settling откладываем на пост-фрейм:
    // нельзя дёргать ValueNotifier (а через него — setState у
    // ValueListenableBuilder) синхронно внутри didUpdateWidget — он вызывается
    // в том же buildScope, что и текущая перестройка дерева.
    var confirmed = false;
    if (_pendingScheduledAt != null &&
        widget.item.scheduledAt == _pendingScheduledAt) {
      _pendingScheduledAt = null;
      confirmed = true;
    }
    if (_pendingDurationMinutes != null &&
        widget.item.durationMinutes == _pendingDurationMinutes) {
      _pendingDurationMinutes = null;
      confirmed = true;
    }
    if (!confirmed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeClearSettling();
    });
  }

  // Зона хвата нижней ручки крупнее видимой полоски — Закон Фиттса.
  static const double _handleHitHeight = 22.0;
  static const double _laneGap = 2.0;

  // Минимальная высота блока во время resize в пикселях (= минимум 15 минут
  // визуально, но не меньше, чтобы хват не схлопнулся).
  static const double _minResizePx = 18.0;

  @override
  void dispose() {
    _settleTimer?.cancel();
    _gesture.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colors = _blockColors(widget.item, ext, scheme);

    final startMin = minutesFromMidnight(widget.item.scheduledAt);
    final baseTop = minutesToOffset(startMin, widget.hourHeight);
    // effectiveDurationMinutes — НЕ item.durationMinutes напрямую: для
    // TaskShape.open там сентинел -1 (см. task_shape.dart), а
    // effectiveDurationMinutes уже посчитан в _DayColumn (до следующего
    // события/конца дня) и всегда > 0.
    final baseHeight =
        durationToHeight(widget.effectiveDurationMinutes, widget.hourHeight);
    final shape = taskShapeOf(widget.item.durationMinutes);

    // Геометрия дорожек: равные колонки внутри ширины.
    final laneWidth =
        (widget.columnWidth - _laneGap * (widget.laneCount - 1)) /
            widget.laneCount;
    final left = (laneWidth + _laneGap) * widget.lane;
    final width = laneWidth < 0 ? 0.0 : laneWidth;

    // Контент строится один раз и передаётся как child в ValueListenableBuilder,
    // поэтому при каждом кадре жеста он НЕ перестраивается (только обёртка).
    final content = _BlockContent(
      item: widget.item,
      colors: colors,
      compact: widget.compact,
      baseHeight: baseHeight,
      // Ручка ресайза (меняет длительность) имеет смысл только для обычного
      // блока — у «момента» длительности нет (сюда он и не попадает — см.
      // _DayColumn), у «открытого» конец сознательно не задан. По решению
      // владельца продукта ресайз для open временно НЕ поддержан (можно было
      // бы «перетянуть низ → стал обычным блоком», но это отдельная задача);
      // просто скрываем ручку, перенос (drag) времени начала работает как обычно.
      showResizeHandle: shape == TaskShape.block,
      openEnded: shape == TaskShape.open,
      onResizeStart: () {
        HapticFeedback.selectionClick();
        // Старт жеста: снэп-слот «уже на текущей длительности», чтобы первый тик
        // прозвучал только при реальной смене слота.
        _lastSnapSlot = snapDuration(widget.item.durationMinutes);
        _gesture.value =
            _BlockGesture(_GestureKind.resize, baseTop, baseHeight);
      },
      onResizeUpdate: (dy) {
        final g = _gesture.value;
        final cur = g.active ? g.heightPx : baseHeight;
        final next = cur + dy;
        final clamped = next < _minResizePx ? _minResizePx : next;
        // B2: тик при смене снэпнутой длительности (слот = снэпнутые минуты).
        final rawMinutes = (clamped / widget.hourHeight * 60).round();
        _tickOnSnapChange(snapDuration(rawMinutes));
        _gesture.value = _BlockGesture(
          _GestureKind.resize,
          baseTop,
          clamped,
        );
      },
      onResizeEnd: _commitResize,
      handleHitHeight: _handleHitHeight,
    );

    // Внутренняя обёртка лифта (масштаб + тень + подсказка). Вынесена из
    // верхнего ValueListenableBuilder, чтобы GestureDetector и его замыкания
    // (onLongPress*) НЕ пересоздавались на каждом кадре жеста — за кадр
    // перестраивается только геометрия Positioned и лёгкий внутренний слой.
    // AnimatedScale остаётся внутри: цель scale (1.03/1.0) меняется лишь на
    // старте/конце жеста, поэтому анимация лифта не «тикает» во время переноса.
    final lift = ValueListenableBuilder<_BlockGesture>(
      valueListenable: _gesture,
      child: content,
      builder: (context, g, child) {
        final top = g.active ? g.topPx : baseTop;
        final height = g.active ? g.heightPx : baseHeight;
        final dragging = g.kind == _GestureKind.drag;
        final resizing = g.kind == _GestureKind.resize;

        // Плавающая подсказка: при drag — новое время начала; при resize
        // (нижняя ручка, единственная) — конец + длительность. Привязка к
        // 15 мин показывается уже снэпнутой.
        Widget? floatingLabel;
        if (dragging) {
          final snapMin = offsetToSnappedMinutes(top, widget.hourHeight);
          floatingLabel = _GestureLabel(text: formatMinutesOfDay(snapMin));
        } else if (resizing) {
          final rawMinutes = (height / widget.hourHeight * 60).round();
          final dur = snapDuration(rawMinutes);
          floatingLabel = _GestureLabel(
            text: '${formatMinutesOfDay(startMin + dur)}  ·  '
                '${_durationShort(dur)}',
          );
        }

        // Лифт во время жеста: лёгкий масштаб + тень (ANIMATIONS.md §1.1/§1.2 —
        // приподнятый элемент = «взят»). На фазе «приземления» (settling, B3)
        // масштаб уже опускается к 1.0, а тень мягко гаснет (AnimatedOpacity),
        // а не обрывается резко.
        final settling = g.kind == _GestureKind.settling;
        final lifted = g.active && !settling;
        // Тень присутствует пока активен жест ИЛИ идёт приземление; её
        // прозрачность анимируется в 0 на settling — мягкое гашение лифт-тени.
        final showShadow = g.active;

        return AnimatedScale(
          scale: lifted ? 1.03 : 1.0,
          duration: effectiveDuration(context, kDurationSnap),
          curve: kCurveSnap,
          // ВАЖНО (баг-фикс ресайза на первый жест мышью): у КАЖДОГО элемента
          // этого Stack — СТАБИЛЬНЫЙ Key. Без ключей Flutter сопоставляет
          // unkeyed children списка ПО ИНДЕКСУ; когда showShadow переключается
          // false→true РОВНО в момент onResizeStart (тень появляется как НОВЫЙ
          // элемент №0), индекс `Positioned.fill(child: child!)` («child!» —
          // это `content`/_BlockContent, а внутри него живёт RawGestureDetector
          // нижней ручки с _EagerVerticalDragRecognizer) СМЕЩАЕТСЯ. Flutter
          // трактует это как «тип виджета в этой позиции сменился» и УНИЧТОЖАЕТ
          // старый Element вместе с его State — а значит и recognizer,
          // который в этот момент уже держит указатель в середине жеста
          // (onStart уже вызван, но onEnd/onCancel для СТАРОГО recognizer'а
          // никогда не придёт — указатель никто не трекает). На тач-пути жест
          // (down→move→up) успевает завершиться до следующего pump() и
          // разрушительный rebuild не успевает случиться раньше _commitResize;
          // на мышином пути (эксплицитный pump() между move и up, как в UI:
          // кадры рисуются во время live-драга) — успевает, ресайз ломается
          // на первом же кадре. Явные Key делают сопоставление по ключу, а не
          // по индексу — Element (и recognizer внутри) переживает переключение
          // тени/подсказки без пересоздания.
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Тень-лифт поверх обычной заливки во время жеста и приземления;
              // на settling её opacity → 0 (плавное гашение, B3).
              if (showShadow)
                Positioned.fill(
                  key: const ValueKey('block-shadow'),
                  child: AnimatedOpacity(
                    opacity: settling ? 0.0 : 1.0,
                    duration: effectiveDuration(context, kDurationSnap),
                    curve: kCurveSnap,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned.fill(key: const ValueKey('block-content'), child: child!),
              // Плавающая подсказка не нужна на фазе приземления — жест отпущен.
              if (floatingLabel != null && !settling)
                Positioned(
                  key: const ValueKey('block-label'),
                  top: 2,
                  right: 2,
                  child: floatingLabel,
                ),
            ],
          ),
        );
      },
    );

    // Стабильная часть: распознаватели жеста строятся один раз за data-build и
    // не зависят от кадров жеста.
    //
    // Арена жестов тела блока — то же деление по типу указателя, что у
    // _CreateLayer (drag-to-create на пустом месте):
    //   • ТАЧ (палец): [LongPressGestureRecognizer] с коротким удержанием
    //     (_kBlockPickupDelay = 120 мс, supportedDevices = touch). Быстрый
    //     вертикальный свайп по блоку без паузы не успевает выиграть арену —
    //     её забирает родительский SingleChildScrollView (скролл сетки
    //     работает); почти-мгновенное удержание поднимает блок (лифт+хаптика)
    //     и в том же касании тянет его на новое время.
    //   • МЫШЬ/ТРЕКПАД/СТИЛУС: [PanGestureRecognizer] — подхват СРАЗУ по
    //     нажатию-и-протягиванию, без удержания. Claim идёт по порогу
    //     смещения (slop) самого распознавателя движения, поэтому клик БЕЗ
    //     движения не крадёт арену у [TapGestureRecognizer] — короткий тап
    //     мышью по-прежнему открывает карточку-деталь.
    //   • Оба drag-пути переиспользуют общие beginBlockDrag/applyBlockDragDelta/
    //     cancelBlockDrag ниже — коммит (snap/сохранение) общий, _commitMove.
    // Нижняя ручка (resize, единственная) — отдельный _EagerVerticalDragRecognizer
    // в _BlockContent, он выигрывает на своей зоне (и для тача, и для мыши),
    // поэтому tap/drag/resize/скролл не конфликтуют.
    var lastMoveDy = 0.0;

    // Общий старт переноса: хаптика-лифт (выключаема для мыши — на десктопе
    // тактильной отдачи нет) + пометка active. mediumImpact — ощутимый «взял»,
    // как принято в проекте для лифта жеста.
    void beginBlockDrag({bool haptic = true}) {
      if (haptic) HapticFeedback.mediumImpact();
      lastMoveDy = 0.0;
      // B2: снэп-слот = текущее снэпнутое начало (тик только при смене).
      _lastSnapSlot = offsetToSnappedMinutes(baseTop, widget.hourHeight);
      _gesture.value = _BlockGesture(_GestureKind.drag, baseTop, baseHeight);
    }

    // Общее обновление переноса по ПОКАДРОВОЙ дельте [deltaDy] (не суммарному
    // смещению) — вызывающие стороны сами приводят свой формат к дельте кадра.
    void applyBlockDragDelta(double deltaDy) {
      final cur = _gesture.value;
      final base = cur.kind == _GestureKind.drag ? cur.topPx : baseTop;
      final nextTop = base + deltaDy;
      // B2: тик при смене снэпнутого слота начала (шаг 15 мин).
      _tickOnSnapChange(offsetToSnappedMinutes(nextTop, widget.hourHeight));
      _gesture.value = _BlockGesture(
        _GestureKind.drag,
        nextTop,
        cur.active ? cur.heightPx : baseHeight,
      );
    }

    // Откатывает эфемерный лифт, если жест отменён ареной/уходом.
    void cancelBlockDrag() {
      if (_gesture.value.kind == _GestureKind.drag) {
        _gesture.value = const _BlockGesture.none();
      }
    }

    final interactive = RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: <Type, GestureRecognizerFactory>{
        TapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
          () => TapGestureRecognizer(),
          (r) {
            r.onTap = () => showTaskDetailSheet(
                  context,
                  item: widget.item,
                  day: widget.day,
                );
          },
        ),
        // ТАЧ-путь: короткое удержание (_kBlockPickupDelay) → перенос.
        // Ограничен пальцем (supportedDevices = touch) — мышь идёт по
        // отдельному немедленному PanGestureRecognizer ниже.
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
            duration: _kBlockPickupDelay,
            supportedDevices: const {PointerDeviceKind.touch},
          ),
          (r) {
            // Блочные тела (не arrow): сеттеры распознавателя возвращают void,
            // arrow `=> _commitMove()` дал бы use_of_void_result.
            r
              ..onLongPressStart = (_) {
                beginBlockDrag();
              }
              ..onLongPressMoveUpdate = (d) {
                // offsetFromOrigin — суммарное смещение от подхвата; приводим
                // к дельте кадра (текущее − прошлое) для общей функции.
                final dy = d.offsetFromOrigin.dy;
                applyBlockDragDelta(dy - lastMoveDy);
                lastMoveDy = dy;
              }
              ..onLongPressEnd = (_) {
                _commitMove();
              }
              ..onLongPressCancel = cancelBlockDrag;
          },
        ),
        // МЫШЬ/ТРЕКПАД/СТИЛУС-путь: перенос начинается СРАЗУ по нажатию-и-
        // протягиванию, без удержания (как _CreateLayer). Claim идёт по слопу
        // самого PanGestureRecognizer, поэтому клик без движения не отбирает
        // арену у TapGestureRecognizer выше — карточка-деталь по клику работает.
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          () => PanGestureRecognizer(
            supportedDevices: const {
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          (r) {
            r
              ..onStart = (_) {
                beginBlockDrag(haptic: false);
              }
              ..onUpdate = (d) {
                // d.delta.dy — уже покадровая дельта, дополнительный учёт
                // lastMoveDy не нужен (в отличие от long-press-пути выше).
                applyBlockDragDelta(d.delta.dy);
              }
              ..onEnd = (_) {
                _commitMove();
              }
              ..onCancel = cancelBlockDrag;
          },
        ),
      },
      child: lift,
    );

    // Только геометрия Positioned (top/height) перестраивается на каждом кадре
    // жеста; интерактивная обёртка и содержимое переиспользуются как child.
    //
    // B3: AnimatedPositioned с НУЛЕВОЙ длительностью на живом drag/resize (блок
    // мгновенно следует за пальцем — перф-инвариант) и kDurationSnap ТОЛЬКО на
    // фазе «приземления» (settling): тогда блок плавно доезжает от сырого drag-
    // top к снэпнутому. При reduce-motion settling вообще не возникает (см.
    // _settle), поэтому здесь длительность всегда ноль — мгновенно.
    return ValueListenableBuilder<_BlockGesture>(
      valueListenable: _gesture,
      child: interactive,
      builder: (context, g, child) {
        final top = g.active ? g.topPx : baseTop;
        final height = g.active ? g.heightPx : baseHeight;
        final settling = g.kind == _GestureKind.settling;
        final duration =
            settling ? effectiveDuration(context, kDurationSnap) : Duration.zero;

        return AnimatedPositioned(
          duration: duration,
          curve: kCurveSnap,
          top: top,
          left: left,
          width: width,
          height: height,
          // RepaintBoundary изолирует перерисовку блока: во время drag/resize
          // перерисовывается только этот слой, а не вся колонка/сетка.
          child: RepaintBoundary(child: child!),
        );
      },
    );
  }

  /// Сохраняет новое время после переноса: snap к 15 минутам, обновляет
  /// scheduledAt (и дату — в week колонка фиксирует день widget.day).
  Future<void> _commitMove() async {
    final g = _gesture.value;
    if (g.kind != _GestureKind.drag) {
      _gesture.value = const _BlockGesture.none();
      return;
    }
    HapticFeedback.selectionClick();
    final snappedMin = offsetToSnappedMinutes(g.topPx, widget.hourHeight);
    // B3: «приземление» — довозим блок от сырого drag-top к снэпнутому top
    // (высота не менялась при переносе), вместо мгновенного перескока. Это
    // ЛАНДЕД (снэпнутая, целевая) позиция — не старая, поэтому держать её
    // дольше settleFor (пока идёт async-коммит ниже) безопасно, см. BUG-FIX
    // у _settle/_maybeClearSettling.
    _settle(minutesToOffset(snappedMin, widget.hourHeight), g.heightPx);
    final newStart = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      snappedMin ~/ 60,
      snappedMin % 60,
    );
    if (newStart == widget.item.scheduledAt) return;
    final dao = ref.read(itemsDaoProvider);
    // BUG-FIX: помечаем, какое scheduledAt ждём от провайдера — settle-таймер
    // не снимет settling раньше, чем didUpdateWidget увидит именно это значение
    // (или пока коммит явно не провалится — см. catch ниже).
    _pendingScheduledAt = newStart;
    try {
      // Виртуальный повтор серии: материализуем этот день с новым временем
      // (анкер получает EXDATE на дату), иначе updateItem по синтетическому id
      // был бы no-op и перенос потерялся бы.
      //
      // TODO(B4): drag-перенос виртуального повтора сейчас всегда применяет
      // «onlyThis» (materializeOccurrence). Добавить showRecurrenceScopeDialog
      // здесь после того, как drag-конвейер станет async-safe (сейчас _commitDrag
      // вызывается из _DragGestureHandler без await и без BuildContext для диалога).
      // Корректный путь выбора области уже реализован в add_task_sheet._save().
      if (isVirtualOccurrenceId(widget.item.id)) {
        await dao.materializeOccurrence(
          anchorIdFromVirtual(widget.item.id),
          dateFromVirtual(widget.item.id) ?? widget.day,
          status: widget.item.status,
          scheduledAt: newStart,
        );
      } else {
        await dao.updateItem(
          widget.item.id,
          ItemsTableCompanion(
            scheduledAt: Value(newStart),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (_) {
      // Запись не удалась — откатываемся: реальный item НЕ менялся, поэтому
      // снятие settling сейчас безопасно (базовая геометрия и так верна,
      // мигать нечему).
      _pendingScheduledAt = null;
      if (mounted) _maybeClearSettling();
      return;
    }
    // Подстраховка: обычно didUpdateWidget подтвердит коммит почти сразу же
    // (стрим Drift эмитит новое значение вскоре после успешной записи). Если
    // почему-то этого не произойдёт (напр. фильтр Plan скрыл задачу сразу
    // после переноса, и widget.item больше не обновляется) — не держим
    // ephemeral-позицию бесконечно.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_pendingScheduledAt == newStart) {
        _pendingScheduledAt = null;
        _maybeClearSettling();
      }
    });
  }

  /// Сохраняет новую длительность после resize: snap к 15, минимум 15.
  Future<void> _commitResize() async {
    final g = _gesture.value;
    if (g.kind != _GestureKind.resize) {
      _gesture.value = const _BlockGesture.none();
      return;
    }
    HapticFeedback.selectionClick();
    final rawMinutes = (g.heightPx / widget.hourHeight * 60).round();
    final newDuration = snapDuration(rawMinutes);
    // B3: «приземление» — довозим нижнюю границу к снэпнутой высоте (top
    // фиксирован при ресайзе низом). Ландед (целевая), а не старая высота —
    // держать её дольше settleFor во время async-коммита ниже безопасно.
    _settle(g.topPx, durationToHeight(newDuration, widget.hourHeight));
    if (newDuration == widget.item.durationMinutes) return;
    final dao = ref.read(itemsDaoProvider);
    // BUG-FIX: помечаем, какую durationMinutes ждём от провайдера — см. тот же
    // механизм, что и в _commitMove (_pendingDurationMinutes/_maybeClearSettling).
    _pendingDurationMinutes = newDuration;
    try {
      // Виртуальный повтор серии: материализуем этот день с новой длительностью.
      if (isVirtualOccurrenceId(widget.item.id)) {
        await dao.materializeOccurrence(
          anchorIdFromVirtual(widget.item.id),
          dateFromVirtual(widget.item.id) ?? widget.day,
          status: widget.item.status,
          durationMinutes: newDuration,
        );
      } else {
        await dao.updateItem(
          widget.item.id,
          ItemsTableCompanion(
            durationMinutes: Value(newDuration),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }
    } catch (_) {
      _pendingDurationMinutes = null;
      if (mounted) _maybeClearSettling();
      return;
    }
    // Подстраховка — см. аналогичный комментарий в _commitMove.
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_pendingDurationMinutes == newDuration) {
        _pendingDurationMinutes = null;
        _maybeClearSettling();
      }
    });
  }
}

/// Карта распознавателей для зоны хвата нижней ручки ресайза.
/// Один [_EagerVerticalDragRecognizer] — он принимает жест в арене НЕМЕДЛЕННО
/// (resolve(accepted) в addAllowedPointer), стабильно выигрывая над long-press
/// родительского блока уже на ПЕРВЫЙ потяг. Распознаватель device-agnostic, т.е.
/// одинаково ловит ТАЧ (палец) и МЫШЬ/трекпад: на вебе/десктопе ресайз за ручку
/// начинается СРАЗУ по нажатию-протягиванию мышью, без необходимости «выбрать»
/// блок заранее; тач-eager-поведение при этом не регрессирует.
///
/// Блочные тела колбэков (не arrow): сеттеры drag-распознавателя возвращают void,
/// и arrow `=> onEnd()` «использовал» бы void-результат (use_of_void_result).
Map<Type, GestureRecognizerFactory> _resizeHandleGestures({
  required VoidCallback onStart,
  required ValueChanged<double> onUpdate,
  required VoidCallback onEnd,
}) {
  return <Type, GestureRecognizerFactory>{
    _EagerVerticalDragRecognizer:
        GestureRecognizerFactoryWithHandlers<_EagerVerticalDragRecognizer>(
      () => _EagerVerticalDragRecognizer(),
      (recognizer) {
        recognizer
          ..onStart = (_) {
            onStart();
          }
          ..onUpdate = (d) {
            onUpdate(d.delta.dy);
          }
          ..onEnd = (_) {
            onEnd();
          }
          ..onCancel = () {
            onEnd();
          };
      },
    ),
  };
}

/// Короткая длительность: 45 → "45m", 90 → "1h30m". Для подсказки resize.
String _durationShort(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h${m}m';
}

/// Статичный контент блока (заливка, рамка, заголовок/время/мета + ручка
/// resize). Строится один раз на изменение данных — не перестраивается на
/// каждом кадре жеста (передаётся как child в ValueListenableBuilder).
class _BlockContent extends StatelessWidget {
  const _BlockContent({
    required this.item,
    required this.colors,
    required this.compact,
    required this.baseHeight,
    required this.showResizeHandle,
    required this.openEnded,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.handleHitHeight,
  });

  final ItemsTableData item;
  final ({Color bg, Color fg, Color border, Color accentStripe}) colors;
  final bool compact;
  final double baseHeight;
  // Нижняя ручка ресайза (меняет длительность) — единственная ручка блока
  // (верхняя убрана по решению владельца продукта). Показывается ТОЛЬКО для
  // TaskShape.block — у момента нет длительности (и он вообще не рендерится
  // этим виджетом), у открытого конец сознательно не задан (см. task_shape.dart).
  final bool showResizeHandle;
  // TaskShape.open: рисуем открытый низ (стрелка вниз) вместо ручки ресайза.
  final bool openEnded;
  final VoidCallback onResizeStart;
  final ValueChanged<double> onResizeUpdate;
  final VoidCallback onResizeEnd;
  final double handleHitHeight;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    // Ручка показывается ВСЕГДА на обычном блоке (как в Google Calendar) —
    // даже на самом коротком. Её высота адаптивно уменьшается на маленьких
    // блоках, но никогда не съедает тело целиком (см. bottomHandleHeight).
    final handleHeight = bottomHandleHeight(
      baseHeight,
      handleHitHeight: handleHitHeight,
    );
    final timeRange = formatItemTimeRange(item.scheduledAt, item.durationMinutes);
    final isDone = item.status == 'done';

    return Container(
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(8),
        // Рамка ОДНОРОДНА по цвету (иначе borderRadius бросает ассерт «A
        // borderRadius can only be given on borders with uniform colors»).
        // Полная непрозрачность + цвет, сдвинутый к контрасту (_borderFor) —
        // явный кант, чтобы плотный блок не сливался с соседями и колонкой.
        // Толстый левый акцент рисуется отдельной полоской ниже.
        border: Border.all(color: colors.border),
      ),
      child: Stack(
        children: [
          // Левый акцент-полоска: насыщенный исходный цвет задачи (ярче плотной
          // заливки), читается как явный цветной акцент. Для colorOnly-блоков
          // (без текста) это второй слой плотности.
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.accentStripe,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(8),
                ),
              ),
            ),
          ),
          // Контент строится по фактической геометрии блока. В дневном виде
          // (compact=false) заголовок+время центрируются по обеим осям. В узких
          // видах (3 дня / неделя, compact=true) решение «что вообще влезет»
          // принимает compactBlockContent по реальной ширине/высоте — чтобы
          // не было обрезанной каши и наезжающего текста.
          Positioned.fill(
            // Слева оставляем место под акцент-полоску (3px) + воздух.
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 3, 4, 3),
              child: LayoutBuilder(
                builder: (context, c) {
                  // Жёсткая нижняя граница для ОБОИХ путей: если фактической
                  // высоты не хватает даже на одну строку текста (короткий блок
                  // 12–20px у задачи на 10–15 мин, в т.ч. в день-виде с lane-
                  // раскладкой), рисуем только цвет — иначе Column переполняется
                  // на пиксель. compactBlockContent.colorOnly уже инкапсулирует
                  // этот порог по высоте, поэтому переиспользуем его и для дня.
                  if (compactBlockContent(c.maxWidth, c.maxHeight) ==
                      CompactBlockContent.colorOnly) {
                    return const SizedBox.shrink();
                  }
                  return compact
                      ? _buildCompactContent(
                          context,
                          textTheme,
                          c.maxWidth,
                          c.maxHeight,
                          timeRange,
                          isDone,
                        )
                      // Уровень дневного контента считаем по ФАКТИЧЕСКОЙ высоте
                      // блока (c.maxHeight), а не по замороженному baseHeight: во
                      // время живого ресайза Positioned ужимает блок кадр за
                      // кадром, и контент должен деградировать (титул+время →
                      // только титул) по реальной высоте, иначе на переходных
                      // высотах строка времени не влезает и Column переполняется.
                      : _buildDayContent(
                          context,
                          textTheme,
                          blockContentLevel(c.maxHeight),
                          c.maxWidth,
                          timeRange,
                          isDone,
                        );
                },
              ),
            ),
          ),
          // Нижняя ручка изменения длительности: видимая полоска + крупная
          // невидимая зона хвата (Закон Фиттса). Единственная ручка ресайза —
          // верхняя убрана по решению владельца продукта.
          //
          // Арена жестов: родительский блок слушает onLongPress*/Pan (перенос).
          // Если ручку повесить на обычный GestureDetector с onVerticalDrag, то
          // на ПЕРВОМ касании арена сначала отдаёт жест родителю (вертикальный
          // drag «проигрывает» по умолчанию), и ресайз срабатывал лишь со
          // второго хвата. Поэтому здесь RawGestureDetector с
          // _EagerVerticalDragRecognizer — он принимает жест в арене немедленно
          // (resolve(accepted) на старте), стабильно выигрывая над родительским
          // long-press/Pan уже на первый потяг — ТАЧ и МЫШЬ одинаково. Вне зоны
          // ручки перенос блока работает как прежде.
          //
          // Открытый конец (TaskShape.open, task_shape.dart): вместо ручки
          // ресайза — пунктирная линия у нижнего края («конец не задан», как
          // просил владелец продукта). Чисто декоративный слой (без гест-
          // детектора) — не мешает тапу/переносу блока сверху него.
          if (openEnded)
            Positioned(
              left: 4,
              right: 4,
              bottom: 0,
              height: 6,
              child: _OpenEndedEdge(color: colors.fg.withValues(alpha: 0.55)),
            ),
          // Ручка показывается ВСЕГДА на обычном блоке (handleHeight > 0 почти
          // всегда — см. bottomHandleHeight), в т.ч. на самом коротком блоке:
          // там её высота адаптивно меньше полной [handleHitHeight], но резерв
          // тела (kHandleBodyReserve) не даёт ей съесть блок целиком — тап/
          // перенос остаются доступны даже на короткой задаче. У «открытого»
          // (openEnded) и «момента» (сюда не попадает совсем) ручки нет.
          if (showResizeHandle && handleHeight > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: handleHeight,
              // MouseRegion-курсор ресайза (resizeUpDown): на вебе/десктопе при
              // наведении мышью на зону хвата курсор сообщает «край тянется»,
              // как у Google Calendar. На тач-устройствах курсора нет —
              // поведение не меняется.
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: RawGestureDetector(
                  behavior: HitTestBehavior.opaque,
                  gestures: _resizeHandleGestures(
                    onStart: onResizeStart,
                    onUpdate: onResizeUpdate,
                    onEnd: onResizeEnd,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 28,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        // На плотной заливке ручка из цвета текста (автоконтраст)
                        // читается лучше, чем граница (близкая к фону).
                        color: colors.fg.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Дневной вид (широкий блок): заголовок + время по центру блока — и по
  /// вертикали, и по горизонтали. Текст по-прежнему обрезается ellipsis и не
  /// вызывает overflow на коротких блоках (Column min + maxLines).
  Widget _buildDayContent(
    BuildContext context,
    TextTheme textTheme,
    BlockContentLevel level,
    double maxWidth,
    String timeRange,
    bool isDone,
  ) {
    // ЖЁСТКИЙ гард от overflow на ЛЮБОЙ высоте (в т.ч. на переходных кадрах
    // живого ресайза): ClipRect отсекает покраску за границами, а FittedBox
    // (scaleDown) гарантирует, что Column НИКОГДА не превысит фактическую высоту
    // блока — на тесном кадре контент ужимается, а не переполняет RenderFlex.
    // SizedBox(width) внутри FittedBox даёт тексту КОНЕЧНУЮ ширину, чтобы работал
    // ellipsis по горизонтали (FittedBox иначе отдаёт неограниченную ширину и
    // длинное название не обрезалось бы, а масштабировалось в нечитаемо мелкое).
    // Приоритет — НАЗВАНИЮ: titleOnly показывает только заголовок (время видно
    // на часовой оси слева), время добавляется лишь когда блок достаточно высок.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: maxWidth.isFinite && maxWidth > 0 ? maxWidth : null,
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              item.title,
              textAlign: TextAlign.center,
              // До 2 строк когда блок высокий; иначе 1 строка.
              maxLines: level == BlockContentLevel.titleTimeAndMeta ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              // Заголовок — читаемый размер из темы (bodyMedium ~14px вместо
              // мелкого labelSmall ~11px, особенно заметного в вебе).
              style: textTheme.bodyMedium?.copyWith(
                color: colors.fg,
                // w600 на цветном блоке — баланс между читаемостью и design tokens
                fontWeight: FontWeight.w600,
                height: 1.1,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
            if (level != BlockContentLevel.titleOnly)
              Text(
                timeRange,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.clip,
                // Время — labelMedium (~12px) вместо labelSmall: крупнее и
                // читаемо, но мельче заголовка, чтобы держать иерархию.
                style: textTheme.labelMedium?.copyWith(
                  color: colors.fg.withValues(alpha: 0.85),
                ),
              ),
            if (level == BlockContentLevel.titleTimeAndMeta &&
                isVirtualOccurrenceId(item.id))
              Text(
                context.s('recur.repeats_daily'),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: colors.fg.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
          ),
        ),
      ),
    );
  }

  /// Узкий вид (3 дня / неделя): по фактической геометрии решаем, что влезает.
  /// colorOnly — только цвет блока (название по тапу), titleOnly — короткое
  /// имя по центру с ellipsis, titleAndTime — имя + время. Так в тонких
  /// колонках не остаётся обрезанной каши и наезжающего текста.
  Widget _buildCompactContent(
    BuildContext context,
    TextTheme textTheme,
    double width,
    double height,
    String timeRange,
    bool isDone,
  ) {
    final what = compactBlockContent(width, height);
    if (what == CompactBlockContent.colorOnly) {
      // Только цвет — никакого текста, название доступно по тапу (карточка).
      return const SizedBox.shrink();
    }
    // ЖЁСТКИЙ гард от overflow на ЛЮБОЙ высоте (тот же, что в дне): ClipRect +
    // FittedBox(scaleDown) — контент НИКОГДА не превысит фактическую высоту блока
    // даже на переходных кадрах ресайза. SizedBox(width) сохраняет ellipsis по
    // горизонтали. Приоритет — НАЗВАНИЮ (titleOnly раньше titleAndTime).
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: width.isFinite && width > 0 ? width : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelMedium?.copyWith(
                  color: colors.fg,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              if (what == CompactBlockContent.titleAndTime)
                Text(
                  timeRange,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: textTheme.labelSmall?.copyWith(
                    color: colors.fg.withValues(alpha: 0.85),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// TaskShape.open — индикатор открытого низа (task_shape.dart)
// ===========================================================================

/// Пунктирная линия у нижнего края блока [TaskShape.open] — визуальная
/// подсказка «конец не задан» вместо ручки ресайза. Чисто декоративный слой:
/// без гест-детектора внутри, поэтому не крадёт хиты у тап/переноса блока,
/// которые обрабатываются выше по дереву (_EventBlockState).
class _OpenEndedEdge extends StatelessWidget {
  const _OpenEndedEdge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 6,
      child: CustomPaint(painter: _DashedLinePainter(color: color)),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  static const double _dashWidth = 5.0;
  static const double _dashGap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    var x = 0.0;
    while (x < size.width) {
      final end = (x + _dashWidth) > size.width ? size.width : x + _dashWidth;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter oldDelegate) =>
      oldDelegate.color != color;
}

// ===========================================================================
// TaskShape.moment — маркер без длительности (task_shape.dart)
// ===========================================================================

/// Маркер задачи-«момента» (durationMinutes == 0, [TaskShape.moment]): точка +
/// время + заголовок в один ряд, БЕЗ длительности и БЕЗ ручек ресайза — просто
/// метка на сетке (не занимает лейн/место у соседних блоков, см. _DayColumn).
/// Тап открывает ту же карточку-деталь, что и у обычного блока. Высота
/// фиксирована ([kMomentMarkerHeight]) и НЕ масштабируется под hourHeight —
/// у момента нет протяжённости во времени, поэтому её незачем привязывать
/// к масштабу сетки. Перенос (drag) для момента пока не поддержан — время
/// правится через карточку-деталь → Edit (то же ограничение, что у ручки
/// ресайза открытого блока, см. showResizeHandle в _EventBlockState).
class _MomentMarker extends StatelessWidget {
  const _MomentMarker({
    super.key,
    required this.item,
    required this.day,
    required this.top,
    required this.compact,
  });

  final ItemsTableData item;
  final DateTime day;
  final double top;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textTheme = Theme.of(context).textTheme;
    final colors = _blockColors(item, ext, scheme);
    final isDone = item.status == 'done';

    return Positioned(
      top: top,
      left: 0,
      right: 0,
      height: kMomentMarkerHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Material(
          color: colors.bg,
          borderRadius: BorderRadius.circular(999),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => showTaskDetailSheet(context, item: item, day: day),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: colors.fg,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Время скрываем в узких видах (3 дня/неделя) — там место
                  // экономится тем же принципом, что и у обычных блоков
                  // (compactBlockContent): приоритет — заголовку. Flexible (а
                  // НЕ голый Text) — иначе при крупном системном тексте (a11y
                  // 2.0×) время требует своей полной интринсик-ширины и рвёт
                  // Row по горизонтали (RenderFlex overflow), даже когда
                  // заголовок рядом честно сжат через Expanded+ellipsis:
                  // не-flex дети Row всегда берут натуральный размер вне
                  // зависимости от того, что рядом есть гибкий сосед.
                  if (!compact) ...[
                    Flexible(
                      child: Text(
                        formatMinutesOfDay(minutesFromMidnight(item.scheduledAt)),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: textTheme.labelSmall?.copyWith(
                          color: colors.fg,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    flex: 3,
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: colors.fg,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Вертикальный drag-распознаватель, который выигрывает арену немедленно.
///
/// Стандартный [VerticalDragGestureRecognizer] ждёт, пока палец сдвинется на
/// kTouchSlop, и только потом претендует на победу — за это время долгое
/// нажатие родительского блока успевает заявить о себе, и на ПЕРВОМ касании
/// нижней ручки арену выигрывал long-press (ресайз срабатывал лишь со второго
/// хвата). Здесь мы вызываем [resolve(GestureDisposition.accepted)] прямо в
/// [addAllowedPointer], то есть на нажатии в зоне ручки — так ресайз надёжно
/// побеждает long-press родителя уже на первый потяг.
class _EagerVerticalDragRecognizer extends VerticalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    // Немедленно заявляем победу в арене за этот указатель: касание пришлось на
    // зону ручки (translucent/opaque hit), значит пользователь целится в ресайз.
    resolve(GestureDisposition.accepted);
  }

  @override
  String get debugDescription => 'eager vertical drag';
}

/// Плавающая подсказка времени/длительности во время жеста.
class _GestureLabel extends StatelessWidget {
  const _GestureLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
