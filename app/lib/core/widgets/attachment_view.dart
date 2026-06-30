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
// Точки входа:
//   viewAttachmentGallery  — полноэкранная галерея со свайпом и счётчиком.
//   viewAttachmentFullscreen — обёртка: открывает галерею из одного элемента
//                              (обратная совместимость с прежними вызовами).
//   AttachmentThumb        — 72dp превью с крестиком удаления.
//   AttachmentGalleryScreen — публичный виджет; используется в тестах напрямую.
//
// Иконки: Phosphor imageBroken / playCircle / play / pause / x / videoCameraSlash

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:video_player/video_player.dart';

import '../animations/constants.dart';
import '../database/database.dart';
import '../l10n/app_strings.dart';
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

// ---------------------------------------------------------------------------
// Полноэкранная галерея вложений со свайпом PageView и счётчиком
// ---------------------------------------------------------------------------

/// Открывает полноэкранную галерею вложений задачи с листанием.
///
/// [attachments] — все вложения задачи; [startIndex] — индекс нажатого.
/// В AppBar показывается счётчик «{i+1}/{n}» (l10n key `attachments.counter`).
/// Для одиночного вложения можно вызвать с `attachments: [a], startIndex: 0`.
///
/// Используем rootNavigator: true — как showDialog, чтобы галерея открылась
/// поверх нижних листов (add_task_sheet, task_detail_card).
void viewAttachmentGallery(
  BuildContext context,
  List<ItemAttachmentsTableData> attachments,
  int startIndex, {
  required VoidCallback onUnsupportedVideo,
}) {
  if (attachments.isEmpty) return;
  Navigator.of(context, rootNavigator: true).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => AttachmentGalleryScreen(
        attachments: attachments,
        startIndex: startIndex,
        onUnsupportedVideo: onUnsupportedVideo,
      ),
    ),
  );
}

/// Открывает вложение [a] на весь экран: обёртка над viewAttachmentGallery
/// для обратной совместимости (один элемент, startIndex = 0).
///
/// [onUnsupportedVideo] вызывается, если видео нельзя проиграть (web data-URI).
void viewAttachmentFullscreen(
  BuildContext context,
  ItemAttachmentsTableData a, {
  required VoidCallback onUnsupportedVideo,
}) {
  viewAttachmentGallery(
    context,
    [a],
    0,
    onUnsupportedVideo: onUnsupportedVideo,
  );
}

/// Полноэкранная галерея вложений задачи с PageView-листанием.
///
/// Счётчик «{i+1}/{n}» в AppBar (l10n `attachments.counter`).
/// Dots-индикатор снизу когда вложений > 1.
/// Фото — InteractiveViewer (зум/pan); видео — File-плеер на Android.
///
/// Публичный класс: импортируется и pump'ается напрямую в тестах.
class AttachmentGalleryScreen extends StatefulWidget {
  const AttachmentGalleryScreen({
    super.key,
    required this.attachments,
    required this.startIndex,
    required this.onUnsupportedVideo,
  });

  /// Все вложения задачи для листания.
  final List<ItemAttachmentsTableData> attachments;

  /// Индекс, с которого открываем галерею (0-based).
  final int startIndex;

  /// Вызывается, когда видео-вложение не может быть проиграно (data-URI на web).
  final VoidCallback onUnsupportedVideo;

  @override
  State<AttachmentGalleryScreen> createState() =>
      _AttachmentGalleryScreenState();
}

class _AttachmentGalleryScreenState extends State<AttachmentGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final total = widget.attachments.length;
    _currentIndex =
        total > 0 ? widget.startIndex.clamp(0, total - 1) : 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.attachments.length;

    // Счётчик «1/3» из l10n с подстановкой плейсхолдеров
    final counterText = context
        .s('attachments.counter')
        .replaceAll('{current}', '${_currentIndex + 1}')
        .replaceAll('{total}', '$total');

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withAlpha(180),
        elevation: 0,
        // Кнопка закрытия — Phosphor X
        leading: IconButton(
          icon: PhosphorIcon(
            PhosphorIcons.x(PhosphorIconsStyle.regular),
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          counterText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
      ),
      body: total == 0
          ? const SizedBox.shrink()
          : Stack(
              children: [
                // Листание между вложениями
                PageView.builder(
                  controller: _pageController,
                  itemCount: total,
                  onPageChanged: (i) => setState(() => _currentIndex = i),
                  itemBuilder: (ctx, i) => _GalleryPage(
                    attachment: widget.attachments[i],
                    onUnsupportedVideo: widget.onUnsupportedVideo,
                  ),
                ),
                // Dots-индикатор снизу (только при > 1 вложении)
                if (total > 1)
                  Positioned(
                    bottom: 24 + MediaQuery.of(context).padding.bottom,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < total; i++)
                          AnimatedContainer(
                            duration: effectiveDuration(context, kDurationFast),
                            margin:
                                const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _currentIndex ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _currentIndex
                                  ? Colors.white
                                  : Colors.white.withAlpha(102),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Одна страница галереи: фото — InteractiveViewer, видео — [_VideoPageItem].
class _GalleryPage extends StatelessWidget {
  const _GalleryPage({
    required this.attachment,
    required this.onUnsupportedVideo,
  });

  final ItemAttachmentsTableData attachment;
  final VoidCallback onUnsupportedVideo;

  @override
  Widget build(BuildContext context) {
    if (attachment.type == 'photo') {
      return InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: attachmentImage(
            attachment.localPath,
            fit: BoxFit.contain,
            errorBuilder: (ctx, _, _) => PhosphorIcon(
              PhosphorIcons.imageBroken(PhosphorIconsStyle.regular),
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    // Видео: на вебе data-URI не поддерживается — показываем иконку и снэк.
    if (isAttachmentDataUri(attachment.localPath)) {
      // Вызываем callback в post-frame (безопасно вне build)
      WidgetsBinding.instance
          .addPostFrameCallback((_) => onUnsupportedVideo());
      return Center(
        child: PhosphorIcon(
          PhosphorIcons.videoCameraSlash(PhosphorIconsStyle.regular),
          size: 48,
          color: Colors.white,
        ),
      );
    }

    // Android: файловый плеер
    return _VideoPageItem(localPath: attachment.localPath);
  }
}

/// Страница видео в галерее: File-плеер (только Android).
class _VideoPageItem extends StatefulWidget {
  const _VideoPageItem({required this.localPath});
  final String localPath;

  @override
  State<_VideoPageItem> createState() => _VideoPageItemState();
}

class _VideoPageItemState extends State<_VideoPageItem> {
  late final VideoPlayerController _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.localPath));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _ctrl.play();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _ctrl.value.aspectRatio,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            VideoPlayer(_ctrl),
            // Контролы: play/pause
            ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: _ctrl,
              builder: (ctx, val, _) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: PhosphorIcon(
                      val.isPlaying
                          ? PhosphorIcons.pause(PhosphorIconsStyle.regular)
                          : PhosphorIcons.play(PhosphorIconsStyle.regular),
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () =>
                        val.isPlaying ? _ctrl.pause() : _ctrl.play(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Превью одного вложения (AttachmentThumb)
// ---------------------------------------------------------------------------

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
                            PhosphorIcons.imageBroken(
                                PhosphorIconsStyle.regular),
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

// ---------------------------------------------------------------------------
// Диалог проигрывания видео (сохранён для обратной совместимости / кейсов
// вне галереи, где нужен именно Dialog, а не Scaffold-страница).
// ---------------------------------------------------------------------------

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
