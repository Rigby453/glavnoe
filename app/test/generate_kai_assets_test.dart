// Генератор PNG-ассетов маскота Kai для нативного виджета.
//
// Запуск: flutter test test/generate_kai_assets_test.dart
//
// Что делает:
//   1. Рендерит KaiMascot через renderKaiPng (CustomPainter → PictureRecorder → PNG)
//      для эмоций: neutral, success, anxious, away (и их harsh-вариантов).
//   2. Пишет PNG во все плотности Android:
//      app/android/app/src/main/res/drawable-<density>/kai_<emotion>[_harsh].png
//   3. Кладёт копию xxxhdpi в app/assets/kai_widget/ (для iOS/будущего).
//
// Цвет глаз — белый (Colors.white). Accent темы накладывается в нативном виджете
// через RemoteViews setImageTintList / ColorFilter (tinting белых глаз).
// Тело — нейтральный тёмный полупрозрачный цвет (255,255,255,0.11 ≈ rgba для тёмных тем).
// Фон — прозрачный.
//
// Плотности (логический размер 96 dp):
//   mdpi    1.0x → 96 × 96 px
//   hdpi    1.5x → 144 × 144 px
//   xhdpi   2.0x → 192 × 192 px
//   xxhdpi  3.0x → 288 × 288 px
//   xxxhdpi 4.0x → 384 × 384 px

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/features/mascot/kai_mascot.dart';

void main() {
  // Инициализируем Flutter-биндинг (нужен для PictureRecorder.toImage)
  TestWidgetsFlutterBinding.ensureInitialized();

  // Базовый логический размер маскота в dp
  const double baseSize = 96.0;

  // Плотности Android
  const densities = <String, double>{
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
  };

  // Эмоции для виджета (WIDGET.md §4 + §6)
  // thinking/harsh-emotion пропускаем: harsh передаётся как isHarsh=true
  const emotions = <KaiEmotion>[
    KaiEmotion.neutral,
    KaiEmotion.success,
    KaiEmotion.anxious,
    KaiEmotion.away,
  ];

  // Цвета: тело — полупрозрачное белое (светлое на тёмном фоне; native colorFilter даст нужный тон)
  // Глаза — белые (tinting в нативе через setImageTintList)
  // Фон — прозрачный (PNG с alpha)
  const eyeColor = Colors.white;
  // Тело: тёмно-нейтральное полупрозрачное (соответствует Focus surface #241D11 с alpha ~11%)
  const bodyColor = Color(0x1CFFFFFF); // rgba(255,255,255,0.11)
  const borderColor = Color(0x12FFFFFF); // rgba(255,255,255,0.07)

  // Корень проекта: test/ находится рядом с pubspec.yaml
  // При запуске flutter test CWD = app/
  final projectRoot = Directory.current.path;

  String androidDrawablePath(String density, String filename) =>
      '$projectRoot/android/app/src/main/res/drawable-$density/$filename';

  String iosAssetsPath(String filename) =>
      '$projectRoot/assets/kai_widget/$filename';

  test('Генерация PNG-ассетов Kai', () async {
    final generatedFiles = <String>[];

    for (final emotion in emotions) {
      for (final isHarsh in [false, true]) {
        final suffix = isHarsh ? '_harsh' : '';
        final filename = 'kai_${emotion.name}$suffix.png';

        for (final entry in densities.entries) {
          final density = entry.key;
          final ratio = entry.value;

          final pngBytes = await renderKaiPng(
            emotion: emotion,
            isHarsh: isHarsh,
            eyeColor: eyeColor,
            bodyColor: bodyColor,
            borderColor: borderColor,
            size: baseSize,
            pixelRatio: ratio,
          );

          // Пишем в Android drawable
          final androidPath = androidDrawablePath(density, filename);
          final androidFile = File(androidPath);
          await androidFile.parent.create(recursive: true);
          await androidFile.writeAsBytes(pngBytes);

          final pxSize = (baseSize * ratio).round();
          print('  WRITTEN [$pxSize×$pxSize px, ${pngBytes.length} bytes] → $androidPath');
          generatedFiles.add(androidPath);

          // Копия xxxhdpi → assets/kai_widget/
          if (density == 'xxxhdpi') {
            final iosPath = iosAssetsPath(filename);
            final iosFile = File(iosPath);
            await iosFile.parent.create(recursive: true);
            await iosFile.writeAsBytes(pngBytes);
            print('  WRITTEN (ios copy) → $iosPath');
            generatedFiles.add(iosPath);
          }
        }
      }
    }

    print('\n=== Сгенерировано файлов: ${generatedFiles.length} ===');
    for (final f in generatedFiles) {
      final size = await File(f).length();
      print('  $f  ($size bytes)');
    }

    // Проверяем, что все файлы созданы и не пустые
    for (final path in generatedFiles) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: 'Файл не создан: $path');
      expect(file.lengthSync(), greaterThan(100), reason: 'Файл пустой/слишком мал: $path');
    }
  });
}
