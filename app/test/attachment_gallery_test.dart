// Тесты полноэкранной галереи вложений (AttachmentGalleryScreen).
//
// Контракт:
//   • галерея с N фото показывает счётчик «1/N» на первой странице;
//   • свайп меняет страницу и обновляет счётчик;
//   • нет RenderFlex overflow на ширине 320px и textScaleFactor 2.0.
//
// Используем data-URI (Image.memory) — нет зависимости от файловой системы.
// Без pumpAndSettle (может зависнуть на анимациях): явные pump(Duration).

import 'package:app/core/database/database.dart';
import 'package:app/core/theme/app_theme.dart';
import 'package:app/core/widgets/attachment_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

/// Минимальный 1×1 PNG в base64 — надёжно декодируется Image.memory.
const _kMinimalPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42'
    'mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

/// data-URI для Image.memory (без доступа к файловой системе).
const _kPhotoDataUri = 'data:image/png;base64,$_kMinimalPngBase64';

/// Строит фейковое фото-вложение задачи (data-URI, type='photo').
ItemAttachmentsTableData _fakePhoto(String id) => ItemAttachmentsTableData(
      id: id,
      itemId: 'item1',
      localPath: _kPhotoDataUri,
      type: 'photo',
      createdAt: DateTime(2024),
    );

/// Тестовая тема с FocusThemeExtension (без GoogleFonts — они заблокированы
/// в flutter_test_config.dart).
ThemeData _testTheme() => ThemeData.dark().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF9E9070),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFF3A3020),
          surfaceElevated: Color(0xFF2E2618),
          textFaint: Color(0xFF736850),
          accentMuted: Color(0xFF26290F),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFF524630),
        ),
      ],
    );

/// Строит дерево виджетов с [screen] внутри MaterialApp + MediaQuery.
/// [textScale] применяется через внешний MediaQuery (MaterialApp уважает его
/// при условии useInheritedMediaQuery или setSurfaceSize уже установлен).
Widget _buildGallery(
  Widget screen, {
  double textScale = 1.0,
}) {
  return MediaQuery(
    // Задаём textScaler; размер определяется setSurfaceSize в каждом тесте.
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: MaterialApp(
      theme: _testTheme(),
      // Фиксируем en-локаль → context.s() вернёт '{current}/{total}'
      locale: const Locale('en'),
      home: screen,
    ),
  );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  group('AttachmentGalleryScreen', () {
    // -----------------------------------------------------------------------
    // 1. Счётчик «1/3» на первой странице
    // -----------------------------------------------------------------------
    testWidgets('shows counter 1/3 on first page', (tester) async {
      final photos = [_fakePhoto('a'), _fakePhoto('b'), _fakePhoto('c')];

      await tester.pumpWidget(
        _buildGallery(
          AttachmentGalleryScreen(
            attachments: photos,
            startIndex: 0,
            onUnsupportedVideo: () {},
          ),
        ),
      );
      // Один pump: обрабатывает первый кадр и пост-фрейм колбеки.
      await tester.pump();

      // Счётчик «1/3» должен быть виден в AppBar
      expect(find.text('1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // 2. Свайп меняет страницу и счётчик
    // -----------------------------------------------------------------------
    testWidgets('fling left updates counter to 2/3', (tester) async {
      final photos = [_fakePhoto('a'), _fakePhoto('b'), _fakePhoto('c')];

      await tester.pumpWidget(
        _buildGallery(
          AttachmentGalleryScreen(
            attachments: photos,
            startIndex: 0,
            onUnsupportedVideo: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1/3'), findsOneWidget);

      // Fling влево: PageView получает скорость и переключается на следующую страницу.
      await tester.fling(
        find.byType(PageView),
        const Offset(-300, 0),
        1200,
      );
      // Несколько явных pump-шагов вместо pumpAndSettle:
      // анимация snap-a PageView обычно завершается за ~200-300 мс.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('2/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // 3. Нет overflow на 320px и крупном тексте (textScaleFactor 2.0)
    // -----------------------------------------------------------------------
    testWidgets('no overflow at 320px width with textScale 2.0',
        (tester) async {
      // Устанавливаем размер поверхности 320×760; сбрасываем после теста.
      await tester.binding.setSurfaceSize(const Size(320, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final photos = [_fakePhoto('x'), _fakePhoto('y'), _fakePhoto('z')];

      await tester.pumpWidget(
        _buildGallery(
          AttachmentGalleryScreen(
            attachments: photos,
            startIndex: 0,
            onUnsupportedVideo: () {},
          ),
          textScale: 2.0,
        ),
      );
      await tester.pump();

      // Успешный pump без исключений = нет overflow
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // 4. startIndex открывает нужную страницу
    // -----------------------------------------------------------------------
    testWidgets('startIndex=2 shows counter 3/3', (tester) async {
      final photos = [_fakePhoto('a'), _fakePhoto('b'), _fakePhoto('c')];

      await tester.pumpWidget(
        _buildGallery(
          AttachmentGalleryScreen(
            attachments: photos,
            startIndex: 2,
            onUnsupportedVideo: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('3/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    // -----------------------------------------------------------------------
    // 5. Одно вложение: счётчик «1/1», PageView с одной страницей
    // -----------------------------------------------------------------------
    testWidgets('single attachment shows 1/1', (tester) async {
      final photos = [_fakePhoto('solo')];

      await tester.pumpWidget(
        _buildGallery(
          AttachmentGalleryScreen(
            attachments: photos,
            startIndex: 0,
            onUnsupportedVideo: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('1/1'), findsOneWidget);
      // PageView присутствует (галерея работает даже с одним элементом)
      expect(find.byType(PageView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
