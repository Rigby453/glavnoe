// streak_share_card.dart — G1: поделиться стриком
//
// Экспортирует три публичных члена:
//   • StreakShareCard — визуальная карточка (RepaintBoundary с ключом)
//   • StreakShareModal — нижний шит: предпросмотр + кнопка «Поделиться»
//   • captureCardAsPng(GlobalKey) — рендеринг в PNG-байты
//
// Шеринг: пробуем Share.shareXFiles(PNG), при ошибке (web / API недоступен)
// откатываемся на копирование текста в Clipboard + снэкбар.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/branding.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// StreakShareCard — визуальная карточка
// ---------------------------------------------------------------------------

/// Красивая карточка стрика для скриншота и предпросмотра.
///
/// Обёрнута в [RepaintBoundary] с [repaintKey] — этот ключ передаётся
/// в [captureCardAsPng] для захвата PNG. Карточка квадратная (1:1),
/// стиль Kaname: фон [ColorScheme.surface], акцент [ColorScheme.primary],
/// скругление 20dp.
class StreakShareCard extends StatelessWidget {
  const StreakShareCard({
    super.key,
    required this.streakCount,
    required this.repaintKey,
  });

  /// Текущий стрик (дни подряд).
  final int streakCount;

  /// Ключ [RepaintBoundary]; передаётся в [captureCardAsPng].
  final GlobalKey repaintKey;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final shareText = context
        .s('streak.share_text')
        .replaceAll('{count}', '$streakCount');

    return RepaintBoundary(
      key: repaintKey,
      // AspectRatio 1:1 → квадратная карточка без фиксированных пикселей
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ext.border, width: 0.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Иконка огня — Phosphor fill, ember-цвет (streak-ячейки §1)
              Icon(
                PhosphorIcons.fire(PhosphorIconsStyle.fill),
                size: 48,
                color: ext.ember,
              ),
              const SizedBox(height: 6),

              // Число дней — displayLarge, accent.
              // SizedBox даёт FittedBox фиксированную высоту (не растёт при
              // крупном тексте), scaleDown убирает overflow при textScale 2.0.
              SizedBox(
                height: 68,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: Text(
                    '$streakCount',
                    style: textTheme.displayLarge?.copyWith(
                      color: colorScheme.primary,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Подпись — максимум 2 строки, ellipsis защищает от overflow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  shareText,
                  style: textTheme.bodyMedium?.copyWith(
                    color: ext.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),

              // Бренд-ватермарк внизу карточки
              Text(
                kAppWordmark,
                style: textTheme.labelSmall?.copyWith(color: ext.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Захват в PNG
// ---------------------------------------------------------------------------

/// Рендерит [RepaintBoundary] по ключу [key] в PNG-байты.
///
/// pixelRatio = 3.0 — @3x качество для шеринга.
/// Возвращает null при любой ошибке (контекст не готов, платформа не поддерживает).
Future<Uint8List?> captureCardAsPng(GlobalKey key) async {
  try {
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  } catch (_) {
    // Тихий откат — вызывающий код перейдёт на clipboard fallback
    return null;
  }
}

// ---------------------------------------------------------------------------
// StreakShareModal — нижний шит предпросмотра
// ---------------------------------------------------------------------------

/// Нижний шит: предпросмотр [StreakShareCard] + кнопка «Поделиться».
///
/// Открывается из профиля через showModalBottomSheet.
/// Логика шеринга:
///   1. Захватить PNG через [captureCardAsPng].
///   2. Поделиться через Share.shareXFiles (share_plus).
///   3. При ошибке (web API недоступен / платформа не поддерживает PNG) →
///      скопировать текст в [Clipboard] + показать снэкбар.
class StreakShareModal extends StatefulWidget {
  const StreakShareModal({super.key, required this.streakCount});

  final int streakCount;

  @override
  State<StreakShareModal> createState() => _StreakShareModalState();
}

class _StreakShareModalState extends State<StreakShareModal> {
  // Ключ RepaintBoundary живёт здесь — доступен и карточке, и кнопке
  final _cardKey = GlobalKey();
  bool _sharing = false;

  /// Основная логика шеринга с graceful fallback.
  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      final text = context
          .s('streak.share_text')
          .replaceAll('{count}', '${widget.streakCount}');

      // Попытка 1: PNG через share_plus
      final bytes = await captureCardAsPng(_cardKey);
      if (bytes != null) {
        try {
          await Share.shareXFiles(
            [
              XFile.fromData(
                bytes,
                mimeType: 'image/png',
                name: 'kaname_streak.png',
              ),
            ],
            text: text,
          );
          // Успешно — выходим без fallback
          return;
        } catch (_) {
          // share_plus недоступен / Web Share API не поддерживается браузером
        }
      }

      // Попытка 2: clipboard fallback + снэкбар
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('streak.copied'))),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ручка шита
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: ext.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Заголовок шита
            Text(
              context.s('streak.share_title'),
              style: textTheme.titleLarge,
            ),
            const SizedBox(height: 20),

            // Предпросмотр карточки (ограничиваем ширину для корректного вида)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: StreakShareCard(
                streakCount: widget.streakCount,
                repaintKey: _cardKey,
              ),
            ),
            const SizedBox(height: 24),

            // Кнопка «Поделиться» (показывает спиннер во время шеринга)
            FilledButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colorScheme.onPrimary,
                      ),
                    )
                  : Icon(PhosphorIcons.shareNetwork(), size: 18),
              label: Text(context.s('streak.share_btn')),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
