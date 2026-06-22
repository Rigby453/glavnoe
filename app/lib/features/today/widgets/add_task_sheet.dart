// FL-TODAY-05: Нижний лист добавления/редактирования задачи.
// - Поле заголовка (autofocus) с голосовым вводом (mic) и NL-парсером дат.
// - Чипы типа и приоритета, выбор даты и времени.
// - Лимит: максимум 3 main-задачи в день (enforced при выборе приоритета main).
// - Сохранение пишет в Drift через ItemsDao (офлайн-первый подход).
// - Секция вложений: фото/видео, хранятся локально (schemaVersion 11).
//
// Локальное состояние формы (контроллер, выбранные чипы) — эфемерное,
// поэтому здесь используется StatefulWidget; бизнес-состояние идёт через Riverpod.

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

import '../../../core/animations/app_sheet.dart';
import '../../../core/animations/app_toast.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/settings/recent_subjects.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/nl_datetime.dart';
import '../../plan/recurrence.dart';
import '../../plan/widgets/recurrence_providers.dart';
import '../undo_provider.dart';

const List<String> _types = ['task', 'event', 'exam', 'deadline'];
const List<String> _priorities = ['low', 'medium', 'high', 'main'];
const List<int> _durations = [15, 30, 45, 60, 90, 120];
const int _maxMainPerDay = 3;

/// Человекочитаемая длительность: 45 → "45m", 90 → "1h 30m".
String _durationLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// Открывает модальный лист добавления (existing == null) или
/// редактирования (existing != null) задачи на день [day].
Future<void> showAddTaskSheet(
  BuildContext context, {
  required DateTime day,
  ItemsTableData? existing,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  // Баг 1: серые треугольники по бокам скруглений появляются из-за того, что
  // Material 3 добавляет surfaceTint (elevation tint) поверх фона шита, а сам
  // шит не обрезает внутренние виджеты по своей форме.
  // Фикс:
  //   • backgroundColor = colorScheme.surface — явный фон без оттенка elevation.
  //   • shape + clipBehavior = Clip.antiAlias — все дочерние виджеты обрезаются
  //     по скруглённым углам, просвет за углом исчезает.
  //   • Внутри builder оборачиваем в Material(surfaceTintColor: transparent),
  //     чтобы подавить M3-tint независимо от темы.
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    backgroundColor: colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    clipBehavior: Clip.antiAlias,
    builder: (_) => Material(
      // Подавляем M3 elevation tint — иначе цвет шита будет светлее surface.
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        // Поднимаем лист над клавиатурой
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddTaskSheet(day: day, existing: existing),
      ),
    ),
  );
}

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({
    required this.day,
    this.existing,
    super.key,
  });

  /// День, в контексте которого создаётся задача (для лимита main и дефолта даты)
  final DateTime day;

  /// Если задан — режим редактирования
  final ItemsTableData? existing;

  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  late final TextEditingController _titleController;
  // Баг 2: контроллер для ручного ввода минут; синхронизируется с _durationMinutes.
  late final TextEditingController _customMinutesController;
  late String _type;
  late String _priority;
  late DateTime _scheduledAt;
  late int _durationMinutes;
  // Ссылка на модуль: null = нет, или одно из значений moduleLink (локальное поле)
  String? _moduleLink;

  // --- Повтор (серия) ---
  // Включён ли ежедневный повтор для НОВОЙ задачи (None по умолчанию).
  bool _repeatDaily = false;
  // Необязательная дата окончания повтора (UNTIL). null = бессрочно.
  DateTime? _repeatUntil;

  bool get _isEditing => widget.existing != null;

  /// Редактируем виртуальный повтор серии (синтетический id с '@')?
  bool get _isVirtualOccurrence =>
      _isEditing && isVirtualOccurrenceId(widget.existing!.id);

  /// Редактируем якорь серии напрямую (recurrenceRule != null, не виртуал)?
  bool get _isSeriesAnchor =>
      _isEditing &&
      !_isVirtualOccurrence &&
      RecurrenceRule.parse(widget.existing!.recurrenceRule) != null;

  /// Это серийный элемент (якорь или виртуальный повтор) — для серийных действий.
  bool get _isSeriesItem => _isVirtualOccurrence || _isSeriesAnchor;

  /// id якоря серии для серийных действий (stop/delete). Для виртуала —
  /// извлекаем из синтетического id; для якоря — это сам id.
  String? get _seriesAnchorId {
    if (!_isEditing) return null;
    if (_isVirtualOccurrence) return anchorIdFromVirtual(widget.existing!.id);
    if (_isSeriesAnchor) return widget.existing!.id;
    return null;
  }

  // Кэшированное число main-задач на текущий день — загружается при initState.
  int _mainCount = 0;

  // Вложения (фото/видео) — загружаются из Drift при открытии в режиме редактирования.
  List<ItemAttachmentsTableData> _attachments = [];

  final _imagePicker = ImagePicker();

  // --- NL datetime ---
  // Дата/время, определённая NL-парсером из заголовка. null = не распознано.
  DateTime? _nlDetectedDateTime;
  // Флаг: пользователь вручную изменил дату/время → не перезаписываем.
  bool _userPickedDateTime = false;

  // --- Voice input ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;
  // Микрофон показываем только на не-вебе.
  static final bool _canShowMic = !kIsWeb;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _type = existing?.type ?? 'task';
    _priority = existing?.priority ?? 'medium';
    _scheduledAt = existing?.scheduledAt ?? _defaultScheduledAt();
    _durationMinutes = existing?.durationMinutes ?? 30;
    _moduleLink = existing?.moduleLink;
    // Инициализируем состояние повтора из существующего правила (режим
    // редактирования якоря серии). Для виртуального повтора и обычной задачи
    // контрол повтора не показываем, поэтому состояние остаётся дефолтным.
    final existingRule = RecurrenceRule.parse(existing?.recurrenceRule);
    if (existingRule != null) {
      _repeatDaily = true;
      _repeatUntil = existingRule.until;
    }
    // Инициализируем поле ручного ввода текущим значением, если оно не входит
    // в стандартный список пресетов — тогда пользователь сразу видит своё число.
    final isCustom = !_durations.contains(_durationMinutes);
    _customMinutesController = TextEditingController(
      text: isCustom ? '$_durationMinutes' : '',
    );
    // Загружаем число main-задач для отображения подсказки лимита.
    _loadMainCount();
    // Загружаем вложения (только в режиме редактирования — у новой задачи нет id).
    if (_isEditing) _loadAttachments();
    // Слушаем изменения заголовка для NL-парсинга.
    _titleController.addListener(_onTitleChanged);
  }

  /// Запускается при каждом изменении заголовка.
  /// Применяет NL-парсер; если есть распознанная дата и пользователь
  /// не переопределил её вручную — подставляем автоматически.
  void _onTitleChanged() {
    if (_userPickedDateTime) return;
    final text = _titleController.text;
    final result = parseNaturalDateTime(text, DateTime.now());
    if (result.when != null) {
      setState(() {
        _nlDetectedDateTime = result.when;
        _scheduledAt = result.when!;
      });
    } else {
      // Нет совпадений — убираем маркер NL-определённой даты.
      if (_nlDetectedDateTime != null) {
        setState(() => _nlDetectedDateTime = null);
      }
    }
  }

  /// Возвращает чистый заголовок (без временной фразы) для сохранения.
  String get _cleanedTitle {
    final text = _titleController.text;
    final result = parseNaturalDateTime(text, DateTime.now());
    // Если NL распознал фразу — сохраняем очищенный вариант.
    if (result.when != null) return result.cleanedTitle.trim();
    return text.trim();
  }

  // --- Голосовой ввод ---

  /// Переключение диктовки: старт/стоп.
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
        _titleController.text = result.recognizedWords;
        // NL-парсинг запустится через listener (addListener выше).
        if (result.finalResult) {
          setState(() => _listening = false);
        }
      },
    );
  }

  Future<void> _loadAttachments() async {
    if (widget.existing == null) return;
    final dao = ref.read(itemAttachmentsDaoProvider);
    final list =
        await dao.watchAttachments(widget.existing!.id).first;
    if (mounted) setState(() => _attachments = list);
  }

  Future<void> _loadMainCount() async {
    final dao = ref.read(itemsDaoProvider);
    final count = await dao.countMainItems(widget.day);
    if (mounted) setState(() => _mainCount = count);
  }

  /// Умный дефолт времени при создании задачи (UX-LAYOUT §7, §9.5, ADR-033):
  ///
  /// • Будущая дата → 09:00 на эту дату (текущий час ничего не значит для другого дня).
  /// • Сегодня → ближайший будущий получасовой слот (:00 или :30) от текущего момента.
  ///   Пример: сейчас 14:07 → дефолт 14:30; сейчас 14:33 → дефолт 15:00.
  ///   Добавляем 1 минуту буфера чтобы не предлагать «сейчас» — слот должен быть в будущем.
  /// • Сегодня, но ближайший слот ≥ 23:30 → 09:00 завтра, чтобы дефолт был полезным.
  DateTime _defaultScheduledAt() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final widgetDay =
        DateTime(widget.day.year, widget.day.month, widget.day.day);

    // Будущая дата — 09:00 утра того дня.
    if (widgetDay.isAfter(today)) {
      return DateTime(widget.day.year, widget.day.month, widget.day.day, 9, 0);
    }

    // Сегодня (или прошлое — edge-case, обрабатываем как сегодня):
    // ближайший будущий получасовой слот (+1 мин буфер против «сейчас»).
    final base = now.add(const Duration(minutes: 1));
    // Округляем минуты вверх до ближайшего кратного 30.
    final rawMinutes = base.hour * 60 + base.minute;
    final slotMinutes = ((rawMinutes + 29) ~/ 30) * 30;
    final slotHour = slotMinutes ~/ 60;
    final slotMin = slotMinutes % 60;

    if (slotHour <= 23) {
      return DateTime(
          widget.day.year, widget.day.month, widget.day.day, slotHour, slotMin);
    } else {
      // Уже после 23:30 — откатываемся на утро следующего дня.
      final tomorrow = widgetDay.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 9, 0);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _titleController.dispose();
    _customMinutesController.dispose();
    if (_listening) _speech.stop();
    super.dispose();
  }

  Future<void> _onPriorityTap(String priority) async {
    // Лимит main: при выборе main проверяем, что их меньше 3 (кроме уже-main при редактировании)
    if (priority == 'main' && _priority != 'main') {
      final dao = ref.read(itemsDaoProvider);
      final mainCount = await dao.countMainItems(widget.day);
      // Обновляем кэш для отображения подсказки лимита.
      if (mounted) setState(() => _mainCount = mainCount);
      final alreadyCountsSelf = _isEditing && widget.existing!.priority == 'main';
      final effective = alreadyCountsSelf ? mainCount - 1 : mainCount;
      if (effective >= _maxMainPerDay) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('today.max_main_snackbar'))),
          );
        }
        return;
      }
    }
    setState(() => _priority = priority);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = DateTime(picked.year, picked.month, picked.day,
            _scheduledAt.hour, _scheduledAt.minute);
        // Пользователь выбрал вручную → не перезаписываем от NL-парсера.
        _userPickedDateTime = true;
        _nlDetectedDateTime = null;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (picked != null) {
      setState(() {
        _scheduledAt = DateTime(_scheduledAt.year, _scheduledAt.month,
            _scheduledAt.day, picked.hour, picked.minute);
        // Пользователь выбрал вручную → не перезаписываем от NL-парсера.
        _userPickedDateTime = true;
        _nlDetectedDateTime = null;
      });
    }
  }

  // Баг 2: выбор «End time» — пользователь указывает время конца задачи,
  // duration = разница в минутах с _scheduledAt.
  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _scheduledAt.add(Duration(minutes: _durationMinutes)),
      ),
    );
    if (picked == null) return;

    final endDt = DateTime(_scheduledAt.year, _scheduledAt.month,
        _scheduledAt.day, picked.hour, picked.minute);
    final diffMinutes = endDt.difference(_scheduledAt).inMinutes;

    if (diffMinutes <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.s('today.end_time_error')),
          ),
        );
      }
      return;
    }

    setState(() {
      _durationMinutes = diffMinutes;
      // Сбрасываем поле ручного ввода — показываем вычисленное значение.
      _customMinutesController.text = '$diffMinutes';
    });
  }

  // Баг 2: обработка ручного ввода минут из TextField.
  void _onCustomMinutesChanged(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed != null && parsed > 0) {
      setState(() => _durationMinutes = parsed);
    }
  }

  Future<void> _pickAttachment(ImageSource source, {bool isVideo = false}) async {
    XFile? file;
    if (isVideo) {
      file = await _imagePicker.pickVideo(source: source);
    } else {
      file = await _imagePicker.pickImage(source: source, imageQuality: 85);
    }
    if (file == null || !mounted) return;

    // Копируем в директорию приложения для надёжного хранения
    final dir = await getApplicationDocumentsDirectory();
    final ext = p.extension(file.path).isEmpty
        ? (isVideo ? '.mp4' : '.jpg')
        : p.extension(file.path);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
    final dest = File(p.join(dir.path, 'attachments', fileName));
    await dest.parent.create(recursive: true);
    await File(file.path).copy(dest.path);

    final dao = ref.read(itemAttachmentsDaoProvider);
    // Для новых задач временно используем пустой itemId — обновим после сохранения.
    // Для редактирования — сразу привязываем к существующему id.
    final itemId = widget.existing?.id ?? '__pending__';
    await dao.addAttachment(ItemAttachmentsTableCompanion(
      id: Value(uuidV4()),
      itemId: Value(itemId),
      localPath: Value(dest.path),
      type: Value(isVideo ? 'video' : 'photo'),
    ));
    if (mounted) _loadAttachments();
  }

  void _showPickerMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.s('today.photo_camera')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.s('today.photo_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined),
              title: Text(context.s('today.video_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAttachment(ImageSource.gallery, isVideo: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _viewAttachment(ItemAttachmentsTableData a) {
    if (a.type == 'photo') {
      showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Image.file(File(a.localPath), fit: BoxFit.contain),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final ctrl = VideoPlayerController.file(File(a.localPath));
      showDialog<void>(
        context: context,
        builder: (ctx) => _VideoDialog(controller: ctrl),
      );
    }
  }

  Future<void> _deleteAttachment(ItemAttachmentsTableData a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.s('today.remove_attachment_title')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.s('btn.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(context.s('today.remove_attachment_btn'))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(itemAttachmentsDaoProvider).deleteAttachment(a.id);
    if (mounted) _loadAttachments();
  }

  Future<void> _save() async {
    // Используем очищенный заголовок (NL-фраза удалена).
    final title = _cleanedTitle;
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('today.title_required'))),
      );
      return;
    }

    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    // main-задачи всегда защищены от автопереноса
    final isProtected = _priority == 'main';

    // Запоминаем названия занятий/экзаменов для быстрого повторного ввода (C4).
    if (_type == 'event' || _type == 'exam') {
      await ref.read(recentSubjectsProvider).add(title);
    }

    // Строка правила повтора для НОВОЙ задачи: None → null, Every day → FREQ=DAILY
    // (+UNTIL если выбрана дата окончания).
    String? newRuleString;
    if (_repeatDaily) {
      var rule = RecurrenceRule(freq: RecurFreq.daily);
      if (_repeatUntil != null) rule = rule.copyWith(until: _repeatUntil);
      newRuleString = rule.toRuleString();
    }

    if (_isVirtualOccurrence) {
      // Редактирование одного дня серии: материализуем его в реальную строку
      // с применёнными правками (анкер получает EXDATE на эту дату).
      await dao.materializeOccurrence(
        anchorIdFromVirtual(widget.existing!.id),
        dateFromVirtual(widget.existing!.id) ?? widget.existing!.scheduledAt,
        title: title,
        type: _type,
        priority: _priority,
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        isProtected: isProtected,
      );
    } else if (_isEditing) {
      // Обычное редактирование / редактирование якоря серии. Для якоря
      // сохраняем (возможно обновлённую через UNTIL) строку правила; для
      // обычной задачи recurrenceRule остаётся прежним (null), но если
      // пользователь включил повтор — превращаем её в серию.
      final ruleValue = _isSeriesAnchor
          ? Value(newRuleString) // якорь: новое правило (None уберёт серию)
          : (_repeatDaily
              ? Value(newRuleString) // обычную задачу делаем серией
              : const Value<String?>.absent()); // не трогаем
      await dao.updateItem(
        widget.existing!.id,
        ItemsTableCompanion(
          title: Value(title),
          type: Value(_type),
          priority: Value(_priority),
          scheduledAt: Value(_scheduledAt),
          durationMinutes: Value(_durationMinutes),
          isProtected: Value(isProtected),
          recurrenceRule: ruleValue,
          moduleLink: Value(_moduleLink), // локальное поле — не попадает в синк
          updatedAt: Value(now),
        ),
      );
    } else {
      final newId = uuidV4();
      await dao.insertItem(
        ItemsTableCompanion(
          id: Value(newId),
          userId: const Value('local'), // заменится на реальный userId на шаге 8 (sync)
          title: Value(title),
          type: Value(_type),
          priority: Value(_priority),
          status: const Value('pending'),
          scheduledAt: Value(_scheduledAt),
          durationMinutes: Value(_durationMinutes),
          isProtected: Value(isProtected),
          recurrenceRule: Value(newRuleString),
          moduleLink: Value(_moduleLink), // локальное поле — не попадает в синк
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      // Записываем «добавлено» для одноуровневой отмены (кнопка ↩ на Today).
      ref.read(lastUndoableActionProvider.notifier).recordAdd(newId);
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Выбор даты окончания повтора (UNTIL). Чистит при отмене не выполняется —
  /// сброс делается отдельной кнопкой «×» рядом с датой.
  Future<void> _pickRepeatUntil() async {
    final base = _repeatUntil ?? _scheduledAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() =>
          _repeatUntil = DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// «Stop repeating»: ставит UNTIL = вчера на якорь серии (сегодня и будущее
  /// перестают повторяться; история и материализованное прошлое остаются).
  Future<void> _stopRepeating() async {
    final anchorId = _seriesAnchorId;
    if (anchorId == null) return;
    await ref.read(itemsDaoProvider).stopSeries(anchorId, DateTime.now());
    if (mounted) Navigator.of(context).pop();
  }

  /// «Delete series»: удаляет якорь серии целиком (повторы исчезнут; уже
  /// материализованные конкретные дни остаются).
  Future<void> _deleteSeries() async {
    final anchorId = _seriesAnchorId;
    if (anchorId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.s('recur.delete_series')),
        content: Text('"${widget.existing!.title}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.s('btn.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.s('btn.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(itemsDaoProvider).deleteItem(anchorId);
    if (mounted) Navigator.of(context).pop();
  }

  /// Удаление задачи (режим редактирования) с подтверждением.
  Future<void> _confirmDelete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.s('today.delete_task_title')),
        content: Text('"${existing.title}"'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.s('btn.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.s('btn.delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final dao = ref.read(itemsDaoProvider);
    await dao.deleteItem(existing.id);
    // Записываем «удалено» (полный снимок) для одноуровневой отмены кнопкой ↩.
    ref.read(lastUndoableActionProvider.notifier).recordDelete(existing);
    if (!mounted) return;
    // §3.3: тост «Task removed» с Undo. Показываем до pop — OverlayEntry живёт
    // в корневом Overlay навигатора и переживает закрытие шита.
    // Undo вставляет КОПИЮ с новым id: старый id затумбстоунен для синка
    // (ADR-021), повторная вставка того же id вернула бы конфликт удаления.
    showAppToast(
      context,
      variant: AppToastVariant.removed,
      message: context.s('today.task_removed'),
      onUndo: () {
        final now = DateTime.now();
        dao.insertItem(
          ItemsTableCompanion(
            id: Value(uuidV4()),
            userId: Value(existing.userId),
            title: Value(existing.title),
            type: Value(existing.type),
            priority: Value(existing.priority),
            status: Value(existing.status),
            scheduledAt: Value(existing.scheduledAt),
            durationMinutes: Value(existing.durationMinutes),
            isProtected: Value(existing.isProtected),
            recurrenceRule: Value(existing.recurrenceRule),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      // Скролл вместо Padding: с открытой клавиатурой контент не помещается
      // и Column переполнялся («BOTTOM OVERFLOWED BY 112 PIXELS», ревью MVP).
      child: SingleChildScrollView(
        // lg=24 горизонтальный отступ шита (02-type-space.md §4.1)
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? context.s('today.edit_task') : context.s('today.new_task'),
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Быстрые шаблоны — горизонтальный скролл, заполняют форму одним тапом.
            _TemplatesRow(
              onSelect: (title, type) => setState(() {
                _titleController.text = title;
                if (_types.contains(type)) _type = type;
              }),
            ),
            const SizedBox(height: 8),

            // Заголовок + mic + NL-подсказка
            _TitleField(
              controller: _titleController,
              hintText: context.s('today.task_hint'),
              onSubmitted: _save,
              listening: _listening,
              canShowMic: _canShowMic,
              onMicTap: _canShowMic ? _toggleListen : null,
              ext: Theme.of(context).extension<FocusThemeExtension>(),
              colorScheme: colorScheme,
            ),
            // NL hint chip — показывается когда парсер определил дату.
            if (_nlDetectedDateTime != null) ...[
              const SizedBox(height: 8),
              _NlHintChip(
                detectedAt: _nlDetectedDateTime!,
                now: DateTime.now(),
                onTap: _pickTime,
                onDismiss: () => setState(() {
                  _nlDetectedDateTime = null;
                  _userPickedDateTime = true;
                }),
              ),
            ],
            const SizedBox(height: 16),

            // Тип
            Text(context.s('today.type_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types
                  .map((t) => ChoiceChip(
                        label: Text(context.s('today.type_$t')),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Недавние предметы — быстрый ввод для занятий/экзаменов (C4)
            if (_type == 'event' || _type == 'exam')
              Builder(
                builder: (context) {
                  final recents = ref.read(recentSubjectsProvider).all;
                  if (recents.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.s('today.recent_subjects'), style: textTheme.labelMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: recents
                            .map((s) => ActionChip(
                                  label: Text(s),
                                  onPressed: () => setState(
                                      () => _titleController.text = s),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

            // Приоритет
            Text(context.s('today.priority_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _priorities
                  .map((p) => ChoiceChip(
                        // Баг 3: Tooltip на чипе main объясняет назначение щита
                        // (видно при долгом нажатии / hover).
                        label: p == 'main'
                            ? Tooltip(
                                message: context.s('today.priority_tooltip'),
                                child: Text(context.s('today.priority_main')),
                              )
                            : Text(context.s('today.priority_$p')),
                        selected: _priority == p,
                        onSelected: (_) => _onPriorityTap(p),
                      ))
                  .toList(),
            ),
            // Баг 3: подсказка под строкой приоритетов — показывается только
            // когда выбран main, чтобы не захламлять UI по умолчанию.
            if (_priority == 'main') ...[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  // success-цвет для подсказки «защищено» — позитивное состояние
                  final ext = Theme.of(context).extension<FocusThemeExtension>();
                  final hintColor = ext?.success ?? colorScheme.primary;
                  return Row(
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: hintColor),
                      const SizedBox(width: 4),
                      Text(
                        context.s('today.protected_hint'),
                        style: textTheme.bodySmall?.copyWith(color: hintColor),
                      ),
                    ],
                  );
                },
              ),
            ],
            // Подпись лимита: показывается когда уже занято 3 слота main.
            if (_mainCount >= _maxMainPerDay && _priority != 'main')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Builder(
                  builder: (context) {
                    // ember для предупреждения о лимите — ограничивающее состояние
                    final ext = Theme.of(context).extension<FocusThemeExtension>();
                    return Text(
                      context.s('today.main_limit'),
                      style: textTheme.bodySmall?.copyWith(
                        color: ext?.ember ?? colorScheme.secondary,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),

            // Длительность — пресеты + ручной ввод минут + End time (Баг 2)
            Text(context.s('today.duration_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            // Строка 1: пресеты чипами
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _durations
                  .map((d) => ChoiceChip(
                        label: Text(_durationLabel(d)),
                        // Пресет считается выбранным только если поле ручного ввода пустое
                        // (т.е. пользователь не вводил своё число).
                        selected: _durationMinutes == d &&
                            _customMinutesController.text.trim().isEmpty,
                        onSelected: (_) => setState(() {
                          _durationMinutes = d;
                          // Сбрасываем кастомный ввод при выборе пресета.
                          _customMinutesController.clear();
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Строка 2: ручной ввод минут + кнопка End time
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Поле ввода произвольного числа минут
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _customMinutesController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      // Не более 4 цифр (максимум 9999 минут)
                      LengthLimitingTextInputFormatter(4),
                    ],
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: context.s('today.duration_min_hint'),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: _onCustomMinutesChanged,
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка выбора конечного времени (Баг 2)
                OutlinedButton.icon(
                  icon: const Icon(Icons.schedule_outlined, size: 16),
                  label: Text(context.s('today.end_time')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    textStyle: textTheme.labelMedium,
                  ),
                  onPressed: _pickEndTime,
                ),
                // Текущее значение рядом для наглядности
                if (_durationMinutes > 0) ...[
                  const SizedBox(width: 8),
                  Builder(
                    builder: (ctx) {
                      // textFaint для вспомогательного отображения значения (01-color.md)
                      final ext = Theme.of(ctx).extension<FocusThemeExtension>();
                      return Text(
                        _durationLabel(_durationMinutes),
                        style: textTheme.bodySmall?.copyWith(
                          color: ext?.textFaint ?? colorScheme.onSurface.withAlpha(160),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Дата + время
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(DateFormat.yMMMd().format(_scheduledAt)),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(DateFormat.Hm().format(_scheduledAt)),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Повтор (серия). Для виртуального повтора серии контрол правила не
            // показываем — правки одного дня материализуются, а правило меняется
            // через серийные действия ниже.
            if (!_isVirtualOccurrence) ...[
              Text(context.s('addtask.repeat'), style: textTheme.labelMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(context.s('addtask.repeat_none')),
                    selected: !_repeatDaily,
                    onSelected: (_) => setState(() => _repeatDaily = false),
                  ),
                  ChoiceChip(
                    label: Text(context.s('addtask.repeat_daily')),
                    selected: _repeatDaily,
                    onSelected: (_) => setState(() => _repeatDaily = true),
                  ),
                ],
              ),
              // Дата окончания повтора (UNTIL) — показывается при включённом повторе.
              if (_repeatDaily) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_busy_outlined, size: 18),
                        label: Text(
                          _repeatUntil == null
                              ? context.s('addtask.repeat_until')
                              : '${context.s('addtask.repeat_until')}: '
                                  '${DateFormat.yMMMd().format(_repeatUntil!)}',
                        ),
                        onPressed: _pickRepeatUntil,
                      ),
                    ),
                    if (_repeatUntil != null)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: context.s('btn.cancel'),
                        onPressed: () => setState(() => _repeatUntil = null),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Серийные действия: для якоря серии или виртуального повтора.
            if (_isSeriesItem) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.event_repeat_outlined, size: 18),
                      label: Text(context.s('recur.stop')),
                      onPressed: _stopRepeating,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                      label: Text(context.s('recur.delete_series')),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _deleteSeries,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Привязка к модулю — необязательный выбор (только для task/event)
            _ModuleLinkPicker(
              value: _moduleLink,
              onChanged: (v) => setState(() => _moduleLink = v),
            ),
            const SizedBox(height: 16),

            // Вложения (фото / видео)
            Row(
              children: [
                Text(context.s('today.attachments_label'), style: textTheme.labelMedium),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                  label: Text(context.s('btn.add')),
                  onPressed: _showPickerMenu,
                ),
              ],
            ),
            if (_attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _attachments.length,
                  separatorBuilder: (context2, index2) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) {
                    final a = _attachments[i];
                    return GestureDetector(
                      onTap: () => _viewAttachment(a),
                      onLongPress: () => _deleteAttachment(a),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 80,
                          height: 88,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              a.type == 'photo'
                                  ? Image.file(File(a.localPath),
                                      fit: BoxFit.cover)
                                  : Builder(
                                      builder: (ctx) {
                                        // surfaceElevated для модального контента (01-color.md)
                                        final ext = Theme.of(ctx).extension<FocusThemeExtension>();
                                        return Container(
                                          color: ext?.surfaceElevated ?? colorScheme.surface,
                                          child: Icon(Icons.play_circle_outline,
                                              size: 36,
                                              color: colorScheme.onSurface),
                                        );
                                      },
                                    ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _deleteAttachment(a),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 16, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Сохранить
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? context.s('today.save_changes') : context.s('today.add_task_btn')),
              ),
            ),
            // Кнопка обычного удаления — НЕ для серийных элементов (у них свои
            // действия Stop/Delete series выше; обычный delete с виртуальным id
            // был бы no-op, а у якоря — это «Delete series»).
            if (_isEditing && !_isSeriesItem) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(context.s('today.delete_task_btn')),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _confirmDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Поле заголовка с голосовым вводом (mic).
// Однострочное, с autofocus и кнопкой диктовки (скрыта на вебе).
// ---------------------------------------------------------------------------

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.hintText,
    required this.onSubmitted,
    required this.listening,
    required this.canShowMic,
    required this.onMicTap,
    required this.ext,
    required this.colorScheme,
  });

  final TextEditingController controller;
  final String hintText;
  final VoidCallback onSubmitted;
  final bool listening;
  final bool canShowMic;
  final VoidCallback? onMicTap;
  final FocusThemeExtension? ext;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hintText,
        suffixIcon: canShowMic
            ? IconButton(
                tooltip: listening
                    ? context.s('food.voice_stop')
                    : context.s('food.voice_input'),
                icon: Icon(
                  listening ? Icons.mic : Icons.mic_none,
                  // Активный mic → ember; неактивный → textMuted.
                  color: listening
                      ? (ext?.ember ?? colorScheme.error)
                      : (ext?.textMuted ?? colorScheme.onSurface.withAlpha(140)),
                ),
                onPressed: onMicTap,
              )
            : null,
      ),
      onSubmitted: (_) => onSubmitted(),
    );
  }
}

// ---------------------------------------------------------------------------
// NL-подсказка: чип с распознанной датой/временем.
// Тап → переход к ручному выбору времени.
// Dismiss-кнопка (×) → убирает подсказку и блокирует автоопределение.
// ---------------------------------------------------------------------------

class _NlHintChip extends StatelessWidget {
  const _NlHintChip({
    required this.detectedAt,
    required this.now,
    required this.onTap,
    required this.onDismiss,
  });

  final DateTime detectedAt;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final colorScheme = Theme.of(context).colorScheme;

    // Формируем текст подсказки: "Tomorrow 17:00 — tap to change" и т.п.
    final timeStr = DateFormat.Hm().format(detectedAt);
    final today = DateTime(now.year, now.month, now.day);
    final detectedDay = DateTime(detectedAt.year, detectedAt.month, detectedAt.day);
    final diff = detectedDay.difference(today).inDays;

    final String hintText;
    if (diff == 0) {
      hintText = context.s('today.nl_hint_today').replaceAll('{time}', timeStr);
    } else if (diff == 1) {
      hintText = context.s('today.nl_hint_tomorrow').replaceAll('{time}', timeStr);
    } else {
      final dateStr = DateFormat.MMMd().format(detectedAt);
      hintText = context.s('today.nl_hint_date')
          .replaceAll('{date}', dateStr)
          .replaceAll('{time}', timeStr);
    }

    // Цвет фона: accentMuted если есть, иначе surface.
    final chipColor = ext?.accentMuted ?? colorScheme.surface;
    // accent живёт в colorScheme.primary (так сконфигурировано AppTheme).
    final accentColor = colorScheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: accentColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule,
              size: 14,
              color: accentColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                hintText,
                style: textTheme.bodySmall?.copyWith(
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close,
                size: 14,
                color: ext?.textMuted ?? colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Видеоплеер в диалоге.
// ---------------------------------------------------------------------------

class _VideoDialog extends StatefulWidget {
  const _VideoDialog({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_VideoDialog> createState() => _VideoDialogState();
}

class _VideoDialogState extends State<_VideoDialog> {
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
            const SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  widget.controller.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
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
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Выбор привязки к модулю — компактный DropdownButton (необязательный).
// Значения: null, 'workout', 'meal:breakfast', 'meal:lunch', 'meal:dinner', 'sleep'.
// ---------------------------------------------------------------------------

class _ModuleLinkPicker extends StatelessWidget {
  const _ModuleLinkPicker({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final textMuted = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);

    // Пары: значение → локализованный ярлык
    final options = <(String?, String)>[
      (null, context.s('today.module_link_none')),
      ('workout', context.s('today.module_link_workout')),
      ('meal:breakfast', context.s('today.module_link_breakfast')),
      ('meal:lunch', context.s('today.module_link_lunch')),
      ('meal:dinner', context.s('today.module_link_dinner')),
      ('sleep', context.s('today.module_link_sleep')),
    ];

    return Row(
      children: [
        Text(context.s('today.module_link_label'), style: textTheme.labelMedium),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String?>(
              value: value,
              isDense: true,
              isExpanded: true,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
              dropdownColor: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              hint: Text(
                context.s('today.module_link_none'),
                style: textTheme.bodyMedium?.copyWith(color: textMuted),
              ),
              items: options.map((opt) {
                final (val, label) = opt;
                return DropdownMenuItem<String?>(
                  value: val,
                  child: Text(label),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick templates — горизонтальный скролл, заполняют поля одним тапом.
// ---------------------------------------------------------------------------

class _TemplatesRow extends StatelessWidget {
  const _TemplatesRow({required this.onSelect});

  final void Function(String title, String type) onSelect;

  static const _templates = [
    (emoji: '📚', title: 'Study session', type: 'task'),
    (emoji: '📝', title: 'Assignment due', type: 'deadline'),
    (emoji: '🏋️', title: 'Workout', type: 'task'),
    (emoji: '📖', title: 'Read chapter', type: 'task'),
    (emoji: '💻', title: 'Coding practice', type: 'task'),
    (emoji: '🧘', title: 'Meditation', type: 'task'),
    (emoji: '📞', title: 'Call parents', type: 'task'),
    (emoji: '🛒', title: 'Groceries', type: 'task'),
    (emoji: '🎓', title: 'Lecture', type: 'event'),
    (emoji: '👥', title: 'Group meeting', type: 'event'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // accentMuted для фона шаблонов — нейтральный chip-fill (01-color.md §accentMuted)
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final chipFill = ext?.accentMuted ?? colorScheme.surface;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _templates.length,
        separatorBuilder: (context2, index2) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final t = _templates[i];
          return GestureDetector(
            onTap: () => onSelect(t.title, t.type),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                // accentMuted: selection highlight / chip fill (01-color.md)
                color: chipFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${t.emoji} ${t.title}',
                style: textTheme.bodySmall,
              ),
            ),
          );
        },
      ),
    );
  }
}
