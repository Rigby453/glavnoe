// Поле ввода с кнопкой диктовки.
// Принимает TextEditingController снаружи; при диктовке заменяет текст поля.
// На веб-платформе и при недоступности STT — mic-иконка скрыта (поле остаётся).
// Паттерн голосового ввода скопирован из food_screen.dart (_voiceSearch).
//
// Иконки: Phosphor microphone (fill = активно, regular = неактивно).

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../l10n/app_strings.dart';
import '../l10n/locale_provider.dart';
import '../theme/app_theme.dart';

/// Текстовое поле с кнопкой микрофона.
///
/// [controller] — внешний контроллер; контент пишется/читается снаружи.
/// [labelText] — подпись поля.
/// [hintText] — плейсхолдер.
/// [maxLines] — максимальное количество строк (по умолчанию 3).
/// [onChanged] — опциональный колбэк при каждом изменении текста.
class VoiceTextField extends ConsumerStatefulWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText,
    this.maxLines = 3,
    this.onChanged,
  });

  final TextEditingController controller;
  final String labelText;
  final String? hintText;
  final int maxLines;
  final void Function(String)? onChanged;

  @override
  ConsumerState<VoiceTextField> createState() => _VoiceTextFieldState();
}

class _VoiceTextFieldState extends ConsumerState<VoiceTextField> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  // На вебе STT не поддерживается
  static final bool _canShowMic = !kIsWeb;

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListen() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );

    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('food.speech_unavailable'))),
      );
      return;
    }

    final appLocale = ref.read(localeNotifierProvider);
    final localeId = switch (appLocale.languageCode) {
      'ru' => 'ru-RU',
      'de' => 'de-DE',
      _ => 'en-US',
    };

    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
      onResult: (result) {
        if (!mounted) return;
        widget.controller.text = result.recognizedWords;
        widget.onChanged?.call(result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;

    Widget? suffixIcon;
    if (_canShowMic) {
      // Активный микрофон: fill + ember (запись идёт — urgent/active).
      // Неактивный: regular + textMuted (нейтральный, второстепенный).
      final isListening = _listening;
      suffixIcon = IconButton(
        tooltip: isListening
            ? context.s('food.voice_stop')
            : context.s('food.voice_input'),
        icon: PhosphorIcon(
          isListening
              ? PhosphorIcons.microphone(PhosphorIconsStyle.fill)
              : PhosphorIcons.microphone(PhosphorIconsStyle.regular),
          size: 20,
          color: isListening
              ? (ext?.ember ?? colorScheme.error)
              : (ext?.textMuted ?? colorScheme.onSurface.withAlpha(140)),
        ),
        onPressed: _toggleListen,
      );
    }

    return TextField(
      controller: widget.controller,
      maxLines: widget.maxLines,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.newline,
      decoration: InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        alignLabelWithHint: true,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
