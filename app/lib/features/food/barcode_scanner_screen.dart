// Полноэкранный сканер штрихкода (Food, Ф1, SPEC C5 «ввод: штрихкод»).
// Возвращает считанный код через Navigator.pop(code) — дальше food_screen
// сам ходит в /api/v1/food/barcode и открывает диалог порции.
//
// Дизайн: чёрный фон — намеренный (камера, темнота улучшает сканирование),
// НЕ тема приложения. Белые наложения — контраст поверх видеопотока.
// Kaname redesign: Phosphor icons (flashlight), рамка-прицел без изменений.

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // mobile_scanner 6+: внешний контроллер — без start() камера падала.
  final _controller = MobileScannerController(
    formats: [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA],
  );

  // Камера может детектить один и тот же код много раз — закрываемся один раз.
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((v) => RegExp(r'^\d{6,14}$').hasMatch(v))
        .firstOrNull;
    if (code == null) return;
    _handled = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    // Экран сканера — намеренно чёрный (камера): НЕ тема-поверхность.
    // Белые наложения — контраст поверх видеопотока.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(context.s('food.scan_barcode_title')),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          // Фонарик — Phosphor; следит за состоянием контроллера.
          // Включённый: fill + amber (ситуативный, не акцент темы).
          // Выключенный: regular + white.
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return IconButton(
                tooltip: torchOn
                    ? context.s('food.torch_off')
                    : context.s('food.torch_on'),
                icon: Icon(
                  torchOn
                      ? PhosphorIcons.flashlight(PhosphorIconsStyle.fill)
                      : PhosphorIcons.flashlight(),
                  // Включённый — amber для ситуативной индикации
                  color: torchOn ? Colors.amber : Colors.white,
                ),
                onPressed: state.isRunning
                    ? () => _controller.toggleTorch()
                    : null,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Рамка-прицел по центру: белая hairline-подобная 1.5dp, R16
          Center(
            child: Container(
              width: 260,
              height: 160,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withAlpha(180),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Инструкция внизу — bodyMedium белый (поверх камеры)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.s('food.scan_instruction'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withAlpha(180),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
