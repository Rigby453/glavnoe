// Безопасный диалог ввода целого числа (минуты длительности/напоминания/пресета).
//
// Зачем StatefulWidget: TextEditingController создаётся в [initState] и
// уничтожается в [State.dispose]. Flutter вызовет dispose ТОЛЬКО когда маршрут
// диалога полностью удалён из дерева — то есть ПОСЛЕ анимации закрытия.
// Это устраняет краш «A TextEditingController was used after being disposed»,
// который возникал при раннем `controller.dispose()` сразу после `await
// showDialog(...)` (на следующем кадре закрывающийся TextField обращался к уже
// уничтоженному контроллеру).
//
// Диалог возвращает введённое значение через `Navigator.pop(value)`:
//   • `null`  — отмена / невалидный ввод;
//   • int     — корректное число (>= [minValue]).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';

class NumberInputDialog extends StatefulWidget {
  const NumberInputDialog({
    super.key,
    required this.title,
    required this.labelText,
    this.initialValue,
    this.suffixText,
    this.confirmLabel,
    this.minValue = 0,
    this.maxValue,
    this.maxValueHint,
    this.maxDigits = 4,
    this.backgroundColor,
    this.bordered = true,
  });

  /// Заголовок диалога.
  final String title;

  /// Подпись поля ввода.
  final String labelText;

  /// Начальное значение поля (например, текущее число минут). null — пусто.
  final int? initialValue;

  /// Подпись-суффикс в поле (например, «мин»).
  final String? suffixText;

  /// Текст кнопки подтверждения. null → используется `btn.add`.
  final String? confirmLabel;

  /// Минимально допустимое значение. Ввод меньше → возвращается null.
  final int minValue;

  /// Максимально допустимое значение (в единицах поля). null — без верхней
  /// границы. Ввод больше → возвращается null (как и при нарушении minValue),
  /// поэтому значение НЕ обрезается молча — пользователь видит [maxValueHint].
  final int? maxValue;

  /// Готовая локализованная подсказка о максимуме (helperText под полем),
  /// например «Max 60 min». Строится вызывающей стороной из l10n-ключа, чтобы
  /// диалог оставался независимым от единиц (секунды/минуты/штуки). null — нет.
  final String? maxValueHint;

  /// Ограничение длины ввода в цифрах.
  final int maxDigits;

  /// Цвет фона диалога (опционально).
  final Color? backgroundColor;

  /// Рисовать ли рамку у поля (OutlineInputBorder).
  final bool bordered;

  @override
  State<NumberInputDialog> createState() => _NumberInputDialogState();
}

class _NumberInputDialogState extends State<NumberInputDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Парсит и валидирует текущий ввод, затем закрывает диалог.
  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    final withinBounds = parsed != null &&
        parsed >= widget.minValue &&
        (widget.maxValue == null || parsed <= widget.maxValue!);
    Navigator.of(context).pop(withinBounds ? parsed : null);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.backgroundColor,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(widget.maxDigits),
        ],
        decoration: InputDecoration(
          labelText: widget.labelText,
          suffixText: widget.suffixText,
          helperText: widget.maxValueHint,
          border: widget.bordered ? const OutlineInputBorder() : null,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel ?? context.s('btn.add')),
        ),
      ],
    );
  }
}
