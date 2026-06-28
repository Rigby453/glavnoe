// Общие примитивы отображения вложений задач (фото/видео).
//
// Источник истины для рендера вложений: используется и в add_task_sheet
// (создание/редактирование задачи, с удалением), и в task_detail_card
// (карточка-деталь в сетке Плана, read-only). НЕ дублируйте ветку
// data-URI(web)/File(Android) в новых местах — переиспользуйте отсюда.
//
//   • web  → вложение хранится как base64 data-URI прямо в localPath
//            (нет файла на диске) → Image.memory / видео не поддерживается.
//   • Android → localPath это реальный путь к файлу → Image.file / File-плеер.
//
// Иконки: Phosphor imageBroken / playCircle / play / pause / x

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';

import '../database/database.dart';
import '../theme/app_theme.dart';

/// true, если [localPath] — это base64 data-URI (web), а не путь к файлу на диске.
bool isAttachmentDataUri(String localPath) => localPath.startsWith('data:');

/// Декодирует base64-байты из data-URI вложения (web).
/// Ожидает формат `data:<mime>;base64,<payload>`.
Uint8List bytesFromAttachmentDataUri(String dataUri) =>
    base64Decode(dataUri.substring(dataUri.indexOf(',') + 1));

/// Строит виджет-изображение вложения по его localPath, выбирая источник:
///   • data-URI (web) → Image.memory из декодированных base64-байтов;
///   • обычный путь (Android) → Image.file.
/// errorBuilder общий для обоих случаев.
Widget attachmentImage(
  String localPath, {
  required BoxFit fit,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  if (isAttachmentDataUri(localPath)) {
    return Image.memory(
      bytesFromAttachmentDataUri(localPath),
      fit: fit,
      errorBuilder: errorBuilder,
    );
  }
  return Image.file(File(localPath), fit: fit, errorBuilder: errorBuilder);
}

/// Открывает вложение [a] на весь экран: фото — InteractiveViewer (зум),
/// видео — File-плеер (web-видео не поддерживается, показываем snack).
///
/// [onUnsupportedVideo] вызывается, если видео нельзя проиграть (web data-URI).
void viewAttachmentFullscreen(
  BuildContext context,
  ItemAttachmentsTableData a, {
  required VoidCallback onUnsupportedVideo,
}) {
  if (a.type == 'photo') {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: Center(
                child: attachmentImage(
                  a.localPath,
                  fit: BoxFit.contain,
                  errorBuilder: (ctx, _, _) => PhosphorIcon(
                    PhosphorIcons.imageBroken(PhosphorIconsStyle.regular),
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8 + MediaQuery.of(ctx).padding.top,
            right: 8,
            child: IconButton(
              icon: PhosphorIcon(
                PhosphorIcons.x(PhosphorIconsStyle.regular),
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  } else {
    // Видео хранится только как файл на диске (Android).
    if (isAttachmentDataUri(a.localPath)) {
      onUnsupportedVideo();
      return;
    }
    final ctrl = VideoPlayerController.file(File(a.localPath));
    showDialog<void>(
      context: context,
      builder: (ctx) => AttachmentVideoDialog(controller: ctrl),
    );
  }
}

/// Превью одного вложения: квадрат с фото (или иконкой видео).
/// Тап → [onTap]. Если задан [onDelete] — крестик удаления в углу.
class AttachmentThumb extends StatelessWidget {
  const AttachmentThumb({
    super.key,
    required this.attachment,
    required this.onTap,
    this.onDelete,
    this.size = 72,
  });

  final ItemAttachmentsTableData attachment;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final isVideo = attachment.type != 'photo';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Превью (фото или кадр-заглушка видео)
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isVideo
                    ? Container(
                        color: ext?.surfaceElevated ?? colorScheme.surface,
                        alignment: Alignment.center,
                        child: PhosphorIcon(
                          PhosphorIcons.playCircle(PhosphorIconsStyle.regular),
                          size: 30,
                          color: colorScheme.onSurface,
                        ),
                      )
                    : attachmentImage(
                        attachment.localPath,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, _, _) => Container(
                          color: ext?.surfaceElevated ?? colorScheme.surface,
                          alignment: Alignment.center,
                          child: PhosphorIcon(
                            PhosphorIcons.imageBroken(PhosphorIconsStyle.regular),
                            size: 24,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
              ),
            ),
          ),
          // Кнопка удаления — крестик в правом верхнем углу (только если задан)
          if (onDelete != null)
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: PhosphorIcon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Диалог проигрывания видео-вложения (Android File-плеер).
class AttachmentVideoDialog extends StatefulWidget {
  const AttachmentVideoDialog({super.key, required this.controller});
  final VideoPlayerController controller;

  @override
  State<AttachmentVideoDialog> createState() => _AttachmentVideoDialogState();
}

class _AttachmentVideoDialogState extends State<AttachmentVideoDialog> {
  @override
  void initState() {
    super.initState();
    widget.controller.initialize().then((_) {
      if (mounted) setState(() {});
      widget.controller.play();
    });
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.controller.value.isInitialized)
            AspectRatio(
              aspectRatio: widget.controller.value.aspectRatio,
              child: VideoPlayer(widget.controller),
            )
          else
            const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: PhosphorIcon(
                  widget.controller.value.isPlaying
                      ? PhosphorIcons.pause(PhosphorIconsStyle.regular)
                      : PhosphorIcons.play(PhosphorIconsStyle.regular),
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  setState(() {
                    widget.controller.value.isPlaying
                        ? widget.controller.pause()
                        : widget.controller.play();
                  });
                },
              ),
              IconButton(
                icon: PhosphorIcon(
                  PhosphorIcons.x(PhosphorIconsStyle.regular),
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
