// Виджет временной шкалы дня — §4.1 «Kaname» redesign.
//
// Структура каждой строки (Row):
//   [ 44dp time col, right-aligned ]   ·   [ 28dp spine: 2dp line + node ]   ·   [ Expanded card ]
//
// Узлы по виду (TimelineNodeKind):
//   mainPending → filled accent d14 + accentTint ring d22
//   done        → filled textFaint d13
//   task/event  → hollow d13 (1.5dp border textMuted)
//
// Карточка: surface1 (или accentTint для mainPending) + 0.5dp hairline (ext.border) + R14 + pad 11×13.
// Временна́я метка: labelMedium + ext.textMuted + tabular figures. Внутри карточки времени нет.
// Черта «сейчас»: тонкая accent-линия через хребет + «now» в колонке времени.
//
// Только визуал — свайпы/удаление/перетаскивание — ответственность экранов-потребителей.

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../categories/category_dot.dart';
import '../../l10n/app_strings.dart';
import '../../theme/app_theme.dart';
import 'timeline_entry.dart';

// ---------------------------------------------------------------------------
// Размерные константы (§4.1 design-tokens.json v4 + REDESIGN-KANAME.md §4.1)
// ---------------------------------------------------------------------------

/// Ширина колонки времени.
const _kTimeWidth = 44.0;

/// Ширина колонки хребта (spine).
const _kSpineWidth = 28.0;

/// Горизонтальный зазор между колонками.
const _kColGap = 8.0;

/// Нижний зазор между строками (внутри IntrinsicHeight → линия хребта не рвётся).
const _kRowGap = 6.0;

/// Y-координата центра узла от верхнего края строки.
/// Подобрана так, чтобы совпадать с серединой текста временно́й метки.
const _kNodeY = 12.0;

/// Диаметр узла «mainPending» (accent-заливка).
const _kNodeDMain = 14.0;

/// Радиус кольца вокруг узла «mainPending» (accentTint-заливка).
const _kRingRMain = 11.0;

/// Диаметр малого узла (done / task / event).
const _kNodeDSmall = 13.0;

/// Толщина границы полого узла (task / event).
const _kNodeBorder = 1.5;

/// Горизонтальные внутренние отступы карточки.
const _kCardPadH = 13.0;

/// Вертикальные внутренние отступы карточки.
const _kCardPadV = 11.0;

/// Радиус скругления карточки (§radius.card).
const _kCardRadius = 14.0;

/// Высота строки «черта сейчас».
const _kNowLineH = 20.0;

// ---------------------------------------------------------------------------
// TimelineList
// ---------------------------------------------------------------------------

/// Виджет временной шкалы — §4.1 «Kaname».
///
/// **Публичный API:**
///
/// ```dart
/// TimelineList({
///   required List<TimelineEntry> entries,
///   bool showNowLine = false,
///   TimeOfDay? nowTime,
///   EdgeInsets padding = EdgeInsets.zero,
/// })
/// ```
///
/// * [entries]     — упорядоченный список записей.
/// * [showNowLine] — рисовать ли «черту настоящего».
/// * [nowTime]     — текущее время; черта вставляется перед первой записью,
///                   чьё [TimelineEntry.time] > [nowTime]. null → черта не рисуется
///                   даже при [showNowLine] == true.
/// * [padding]     — внешний отступ всего виджета (по умолчанию EdgeInsets.zero).
///
/// **Примечание по производительности:** каждая строка завёрнута в `IntrinsicHeight`
/// для корректного растягивания линии хребта через строки переменной высоты.
/// При больших списках (>50 записей) оборачивайте в `ListView` с явными высотами строк
/// или используйте `SliverList` + `RenderBox` кэширование.
///
/// Свайпы (Dismissible), перетаскивание и Undo-snackbar — ответственность экранов.
class TimelineList extends StatelessWidget {
  const TimelineList({
    super.key,
    required this.entries,
    this.showNowLine = false,
    this.nowTime,
    this.padding = EdgeInsets.zero,
  });

  final List<TimelineEntry> entries;
  final bool showNowLine;
  final TimeOfDay? nowTime;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>()!;
    final scheme = theme.colorScheme;

    // Вычисляем «now» один раз — используем только если showNowLine И nowTime задан.
    final TimeOfDay? now = (showNowLine && nowTime != null) ? nowTime : null;
    final int nowMin = now != null ? now.hour * 60 + now.minute : -1;

    final rows = <Widget>[];
    bool nowInserted = false;

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];

      // Вставить «черту сейчас» перед первой записью с time > now.
      if (!nowInserted && now != null && entry.time != null) {
        final entryMin = entry.time!.hour * 60 + entry.time!.minute;
        if (entryMin > nowMin) {
          rows.add(_buildNowLine(context, scheme, ext, theme));
          nowInserted = true;
        }
      }

      rows.add(_buildEntryRow(context, entry, ext, scheme, theme));
    }

    // Черта в конце, если все записи раньше текущего времени.
    if (!nowInserted && now != null) {
      rows.add(_buildNowLine(context, scheme, ext, theme));
    }

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Строка записи
  // -------------------------------------------------------------------------

  Widget _buildEntryRow(
    BuildContext context,
    TimelineEntry entry,
    FocusThemeExtension ext,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Колонка времени (44dp, right-aligned) ─────────────────────────
          SizedBox(
            width: _kTimeWidth,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                // Небольшой top-отступ для выравнивания с центром узла.
                padding: const EdgeInsets.only(top: 4.0),
                child: entry.time != null
                    ? Text(
                        _formatTime(entry.time!, context),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: ext.textMuted,
                          // Tabular figures для стабильной ширины цифр.
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

          const SizedBox(width: _kColGap),

          // ── Хребет (28dp): вертикальная линия + узел ──────────────────────
          // CustomPaint растягивается до полной высоты строки (IntrinsicHeight +
          // CrossAxisAlignment.stretch) → линия непрерывна между строками.
          SizedBox(
            width: _kSpineWidth,
            child: CustomPaint(
              painter: _SpinePainter(
                kind: entry.kind,
                lineColor: ext.border,
                accentColor: scheme.primary,
                accentTintColor: ext.accentTint,
                textFaintColor: ext.textFaint,
                textMutedColor: ext.textMuted,
              ),
            ),
          ),

          const SizedBox(width: _kColGap),

          // ── Карточка (Expanded) ────────────────────────────────────────────
          // Padding.bottom = _kRowGap создаёт зазор между строками визуально,
          // при этом хребет продолжается сквозь зазор (IntrinsicHeight включает его).
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: _kRowGap),
              child: _buildCard(context, entry, ext, scheme, theme),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Карточка
  // -------------------------------------------------------------------------

  Widget _buildCard(
    BuildContext context,
    TimelineEntry entry,
    FocusThemeExtension ext,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    // mainPending → accentTint-фон; остальные → surface1 (colorScheme.surface).
    final bgColor = entry.kind == TimelineNodeKind.mainPending
        ? ext.accentTint
        : scheme.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(_kCardRadius),
        // Hairline 0.5dp (design-tokens §border.hairline).
        border: Border.all(color: ext.border, width: 0.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: InkWell(
          onTap: entry.onTap,
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: _kCardPadH,
              vertical: _kCardPadV,
            ),
            child: _buildCardContent(context, entry, ext, scheme, theme),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    TimelineEntry entry,
    FocusThemeExtension ext,
    ColorScheme scheme,
    ThemeData theme,
  ) {
    // Стиль заголовка: зачёркнутый + textMuted для выполненных.
    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      color: entry.isDone ? ext.textMuted : null,
      decoration: entry.isDone ? TextDecoration.lineThrough : null,
      decorationColor: ext.textMuted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Точка категории (10dp) + зазор — только при непустом теге.
        if (entry.categoryTag != null && entry.categoryTag!.isNotEmpty) ...[
          CategoryDot(tag: entry.categoryTag!, size: 10),
          const SizedBox(width: 8),
        ],

        // Заголовок — Expanded для предотвращения overflow при любой ширине.
        Expanded(
          child: Text(
            entry.title,
            style: titleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Иконка справа:
        //   isMain && !isDone → shield (fill, accent)
        //   иначе typeIcon != null → typeIcon (regular, textMuted)
        //   isDone без typeIcon → ничего
        if (entry.isMain && !entry.isDone) ...[
          const SizedBox(width: 6),
          Icon(
            PhosphorIcons.shield(PhosphorIconsStyle.fill),
            size: 16,
            color: scheme.primary,
          ),
        ] else if (entry.typeIcon != null) ...[
          const SizedBox(width: 6),
          Icon(
            entry.typeIcon!,
            size: 16,
            color: ext.textMuted,
          ),
        ],

        // Произвольный trailing-виджет экрана-потребителя.
        if (entry.trailing != null) ...[
          const SizedBox(width: 4),
          entry.trailing!,
        ],
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Черта «сейчас»
  // -------------------------------------------------------------------------

  Widget _buildNowLine(
    BuildContext context,
    ColorScheme scheme,
    FocusThemeExtension ext,
    ThemeData theme,
  ) {
    // ПРИМЕЧАНИЕ ДЛЯ ОРКЕСТРАТОРА: строковый ключ 'today.now' необходимо добавить
    // в app/lib/core/l10n/strings/today.dart:
    //   'today.now': { 'en': 'now', 'ru': 'сейчас', ... (все 11 языков) }
    // До добавления виджет покажет строку 'today.now' как fallback (не падает).
    return SizedBox(
      height: _kNowLineH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Метка «сейчас» в колонке времени.
          SizedBox(
            width: _kTimeWidth,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                context.s('today.now'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),

          const SizedBox(width: _kColGap),

          // Хребет «сейчас»: вертикальная border-линия + горизонтальная accent + узел.
          SizedBox(
            width: _kSpineWidth,
            // height берётся от родительского SizedBox(_kNowLineH).
            child: CustomPaint(
              painter: _NowSpinePainter(
                borderColor: ext.border,
                accentColor: scheme.primary,
              ),
            ),
          ),

          const SizedBox(width: _kColGap),

          // Горизонтальная accent-линия до конца строки.
          Expanded(
            child: Container(
              height: 1,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Вспомогательные методы
  // -------------------------------------------------------------------------

  /// Форматирует [TimeOfDay] с учётом locale и системного 12/24ч-формата.
  static String _formatTime(TimeOfDay time, BuildContext context) {
    return MaterialLocalizations.of(context).formatTimeOfDay(
      time,
      alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
    );
  }
}

// ---------------------------------------------------------------------------
// _SpinePainter — хребет обычной строки
// ---------------------------------------------------------------------------

/// Рисует 2dp вертикальную border-линию (на полную высоту, для непрерывности)
/// и узел [TimelineNodeKind] на позиции Y = [_kNodeY].
class _SpinePainter extends CustomPainter {
  const _SpinePainter({
    required this.kind,
    required this.lineColor,
    required this.accentColor,
    required this.accentTintColor,
    required this.textFaintColor,
    required this.textMutedColor,
  });

  final TimelineNodeKind kind;
  final Color lineColor;
  final Color accentColor;
  final Color accentTintColor;
  final Color textFaintColor;
  final Color textMutedColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;

    // Вертикальная линия — полная высота строки (соединяется с соседними строками).
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.butt,
    );

    // Узел.
    _paintNode(canvas, cx, _kNodeY);
  }

  void _paintNode(Canvas canvas, double cx, double cy) {
    switch (kind) {
      case TimelineNodeKind.mainPending:
        // Кольцо accentTint (d=22, r=11).
        canvas.drawCircle(
          Offset(cx, cy),
          _kRingRMain,
          Paint()..color = accentTintColor,
        );
        // Акцентный заполненный круг (d=14, r=7).
        canvas.drawCircle(
          Offset(cx, cy),
          _kNodeDMain / 2,
          Paint()..color = accentColor,
        );

      case TimelineNodeKind.done:
        // Заполненный круг textFaint (d=13, r=6.5).
        canvas.drawCircle(
          Offset(cx, cy),
          _kNodeDSmall / 2,
          Paint()..color = textFaintColor,
        );

      case TimelineNodeKind.task:
      case TimelineNodeKind.event:
        // Полый круг 1.5dp textMuted (d=13, r=6.5).
        canvas.drawCircle(
          Offset(cx, cy),
          _kNodeDSmall / 2,
          Paint()
            ..color = textMutedColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = _kNodeBorder,
        );
    }
  }

  @override
  bool shouldRepaint(_SpinePainter old) =>
      kind != old.kind ||
      lineColor != old.lineColor ||
      accentColor != old.accentColor ||
      accentTintColor != old.accentTintColor ||
      textFaintColor != old.textFaintColor ||
      textMutedColor != old.textMutedColor;
}

// ---------------------------------------------------------------------------
// _NowSpinePainter — хребет черты «сейчас»
// ---------------------------------------------------------------------------

/// Рисует хребет строки «сейчас»:
///   • вертикальная border-линия (для непрерывности с соседними строками);
///   • горизонтальная accent-линия через центр;
///   • малый заполненный accent-кружок в точке пересечения.
class _NowSpinePainter extends CustomPainter {
  const _NowSpinePainter({
    required this.borderColor,
    required this.accentColor,
  });

  final Color borderColor;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Вертикальная border-линия.
    canvas.drawLine(
      Offset(cx, 0),
      Offset(cx, size.height),
      Paint()
        ..color = borderColor
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.butt,
    );

    // Горизонтальная accent-линия.
    canvas.drawLine(
      Offset(0, cy),
      Offset(size.width, cy),
      Paint()
        ..color = accentColor
        ..strokeWidth = 1.0,
    );

    // Малый accent-кружок (r=4).
    canvas.drawCircle(
      Offset(cx, cy),
      4.0,
      Paint()..color = accentColor,
    );
  }

  @override
  bool shouldRepaint(_NowSpinePainter old) =>
      borderColor != old.borderColor || accentColor != old.accentColor;
}
