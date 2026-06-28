// Модель данных одной строки временной шкалы (timeline §4.1 «Kaname»).
//
// Используется виджетом TimelineList. Чисто данные — никакого UI.
// Изменение формата вывода (render) — правь timeline_list.dart.

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Вид узла
// ---------------------------------------------------------------------------

/// Вид узла временной шкалы (§4.1 REDESIGN-KANAME.md).
///
/// Определяет форму и цвет кружка на линии хребта:
///   [mainPending] — заполненный акцентный кружок d14 + кольцо accentTint;
///   [done]        — заполненный кружок textFaint d13;
///   [task]        — полый кружок d13, граница 1.5dp textMuted;
///   [event]       — полый кружок d13, граница 1.5dp textMuted (как task, иное значение).
enum TimelineNodeKind {
  /// Главная задача (priority=main), ещё не выполнена.
  mainPending,

  /// Запись выполнена (задача или событие).
  done,

  /// Обычная задача (без приоритета main).
  task,

  /// Событие (встреча, напоминание, дедлайн).
  event,
}

// ---------------------------------------------------------------------------
// TimelineEntry
// ---------------------------------------------------------------------------

/// Данные одной строки временной шкалы.
///
/// **Публичный API** (используется экранами Today и Plan):
///
/// ```dart
/// TimelineEntry({
///   required String id,
///   TimeOfDay? time,
///   required String title,
///   required TimelineNodeKind kind,
///   bool isMain = false,
///   bool isDone = false,
///   IconData? typeIcon,
///   String? categoryTag,
///   VoidCallback? onTap,
///   Widget? trailing,
/// })
/// ```
///
/// * [id]          — уникальный идентификатор (например, task.id из Drift).
/// * [time]        — время начала; null → строка без временной метки.
/// * [title]       — заголовок задачи / события (1–2 строки, ellipsis при overflow).
/// * [kind]        — форма узла на хребте.
/// * [isMain]      — показывает иконку shield + accentTint-фон карточки.
/// * [isDone]      — зачёркнутый текст, приглушённый цвет текста.
/// * [typeIcon]    — иконка типа справа (PhosphorIcons.calendar() и т.д.); игнорируется
///                   если [isMain] && ![isDone].
/// * [categoryTag] — тег категории без «#»; null/empty → CategoryDot не рендерится.
/// * [onTap]       — обработчик нажатия на карточку.
/// * [trailing]    — произвольный виджет справа (кнопка-галочка, badge и т.п.).
///
/// Конструктор объявлен как `const` — экземпляр можно создать как compile-time
/// константу, если все аргументы тоже константны (типично: typeIcon и trailing = null,
/// onTap = null). В рантайм-случаях просто не указывайте `const`.
class TimelineEntry {
  const TimelineEntry({
    required this.id,
    this.time,
    required this.title,
    required this.kind,
    this.isMain = false,
    this.isDone = false,
    this.typeIcon,
    this.categoryTag,
    this.onTap,
    this.trailing,
  });

  /// Уникальный идентификатор записи (task id / event id / habit id и т.д.).
  final String id;

  /// Время начала. null → строка отображается без временной метки слева.
  final TimeOfDay? time;

  /// Заголовок (содержимое карточки, до 2 строк с ellipsis).
  final String title;

  /// Вид узла — управляет формой и заливкой кружка на линии хребта.
  final TimelineNodeKind kind;

  /// true → кружок main (accentTint-кольцо + filled accent), карточка на accentTint,
  ///         иконка shield показывается если [isDone] == false.
  final bool isMain;

  /// true → текст зачёркнут и окрашен в ext.textMuted.
  final bool isDone;

  /// Иконка типа справа в карточке. Показывается если [isMain] == false
  /// (или [isDone] == true). Используйте PhosphorIcons.xxx(PhosphorIconsStyle.regular).
  final IconData? typeIcon;

  /// Тег категории (первый тег без «#»). Передаётся в CategoryDot(size:10).
  /// null или '' → CategoryDot не рендерится (SizedBox.shrink).
  final String? categoryTag;

  /// Вызывается при нажатии на карточку. null → карточка не реагирует на тапы.
  final VoidCallback? onTap;

  /// Произвольный виджет-трейлинг (например [Checkbox], бейдж, кнопка-снуз).
  /// Отображается крайним справа, после иконки типа.
  final Widget? trailing;
}
