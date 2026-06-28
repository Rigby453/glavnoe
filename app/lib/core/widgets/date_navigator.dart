// Единый виджет навигации по датам (chevron ‹ дата ›).
// Используется на: sleep_report, water_report, diary_history.
//
// Правила:
// - Дата форматируется locale-aware через intl (DateFormat.yMMMMd,
//   Intl.defaultLocale установлен в main через applyIntlLocale).
// - showDatePicker не форсирует локаль — берёт её из MaterialApp
//   (GlobalMaterialLocalizations.delegate).
// - Кнопка «›» отключена, если date == сегодня (нельзя смотреть в будущее).
// - Нет своих анимаций — уважает reduce-motion (MediaQuery.disableAnimations).
//
// Иконки: Phosphor caretLeft / caretRight (20dp), calendarBlank (16dp).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/app_theme.dart';

class DateNavigator extends StatelessWidget {
  const DateNavigator({
    super.key,
    required this.date,
    required this.onChanged,
    this.firstDate,
  });

  /// Текущая выбранная дата.
  final DateTime date;

  /// Вызывается при выборе новой даты (через стрелки или DatePicker).
  final ValueChanged<DateTime> onChanged;

  /// Нижняя граница DatePicker. По умолчанию DateTime(2020).
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);
    final isToday = selectedDate == todayDate;

    return Row(
      children: [
        // Предыдущий день — Phosphor caretLeft (20dp)
        IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.caretLeft(PhosphorIconsStyle.regular),
            size: 20,
          ),
          onPressed: () => onChanged(date.subtract(const Duration(days: 1))),
        ),

        // Тапаемая подпись даты → открывает DatePicker
        Expanded(
          child: GestureDetector(
            onTap: () => _showPicker(context),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    DateFormat.yMMMMd().format(date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Phosphor calendarBlank (16dp, caption size)
                PhosphorIcon(
                  PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular),
                  size: 16,
                  color: ext.textMuted,
                ),
              ],
            ),
          ),
        ),

        // Следующий день — отключён, если уже сегодня — Phosphor caretRight (20dp)
        IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.caretRight(PhosphorIconsStyle.regular),
            size: 20,
          ),
          onPressed: isToday
              ? null
              : () => onChanged(date.add(const Duration(days: 1))),
        ),
      ],
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: now,
    );
    if (picked != null) {
      onChanged(picked);
    }
  }
}
