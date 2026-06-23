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
import '../../../core/settings/reminder_default_provider.dart';
import '../../../core/settings/task_presets_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/nl_datetime.dart';
import '../../../services/notifications/notification_service.dart';
import '../../plan/recurrence.dart';
import '../../plan/widgets/recurrence_providers.dart';
import '../task_colors.dart';
import '../undo_provider.dart';

const List<String> _types = ['task', 'event', 'exam', 'deadline'];
const List<String> _priorities = ['low', 'medium', 'high', 'main'];
const int _maxMainPerDay = 3;

/// Типы, показываемые чипами в форме (exam сворачиваем в deadline).
const List<String> _displayTypes = ['task', 'event', 'deadline'];

/// Приоритеты, показываемые чипами в форме (low сворачиваем в medium).
const List<String> _displayPriorities = ['main', 'high', 'medium'];

/// Нормализует тип к одному из показываемых: 'exam' → 'deadline'.
String _normalizeType(String t) => t == 'exam' ? 'deadline' : t;

/// Нормализует приоритет к одному из показываемых: 'low' → 'medium'.
String _normalizePriority(String p) => p == 'low' ? 'medium' : p;

/// Дефолтная длительность задачи (минут). Используется как стартовое значение
/// при создании новой задачи (если не распознано из текста).
const int _kDefaultDurationMinutes = 30;

/// Человекочитаемая метка напоминания: null→«Нет», 0→«в момент», 60→«1ч».
String _reminderLabel(BuildContext context, int? minutes) {
  if (minutes == null) return context.s('today.reminder_none');
  if (minutes == 0) return context.s('today.reminder_at_time');
  if (minutes >= 60 && minutes % 60 == 0) {
    return context
        .s('today.reminder_h_before')
        .replaceAll('{n}', '${minutes ~/ 60}');
  }
  return context
      .s('today.reminder_min_before')
      .replaceAll('{n}', '$minutes');
}

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
  // Цвет-метка задачи: null = нет, или ключ палитры из task_colors.dart (локальное поле)
  String? _color;

  // --- Повтор (серия) ---
  // Выбранная частота повтора. null = без повтора (None по умолчанию).
  RecurFreq? _repeatFreq;
  // Выбранные дни недели для WEEKLY (чипы Пн..Вс). Пусто при выборе weekly =>
  // используем день недели даты задачи (effectiveByDays в правиле).
  final Set<RecurWeekday> _repeatWeekdays = {};
  // Число месяца для MONTHLY. null => день месяца даты задачи (по умолчанию).
  int? _repeatMonthDay;
  // Необязательная дата окончания повтора (UNTIL). null = бессрочно.
  DateTime? _repeatUntil;

  /// Есть ли активный повтор (любая частота).
  bool get _repeatEnabled => _repeatFreq != null;

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

  // Подзадачи (чеклист) — черновик в памяти, сохраняется при _save (schemaVersion 14).
  // Для редактирования загружаются из Drift; для виртуального повтора серии —
  // это будущая копия дня (материализуется при сохранении).
  final List<_SubtaskDraft> _subtasks = [];
  final TextEditingController _subtaskController = TextEditingController();

  // Недавние уникальные названия задач (для ряда «быстрый выбор»).
  List<String> _recentTitles = [];

  // Состояние сворачиваемого блока «Ещё» (по умолчанию свёрнут).
  bool _moreExpanded = false;

  final _imagePicker = ImagePicker();

  // --- NL datetime ---
  // Кэш последнего разбора заголовка. Парсим РОВНО один раз в _onTitleChanged
  // (с одним DateTime.now()), результат переиспользуем в _save/_cleanedTitle —
  // иначе повторный parseNaturalDateTime с новым now давал нестабильность у
  // полуночи / для относительных фраз (баг 2). Текст, по которому получен кэш,
  // храним рядом для защиты, если _cleanedTitle вызовут до первого listener'а.
  NlDateTimeResult? _lastParseResult;
  String? _lastParsedText;
  // Дата/время, определённая NL-парсером из заголовка. null = не распознано.
  DateTime? _nlDetectedDateTime;
  // Флаг: пользователь вручную изменил дату/время → не перезаписываем.
  bool _userPickedDateTime = false;
  // Флаги ручного выбора для остальных NL-полей: пока поле не тронули руками,
  // парсер может его автоматически подставлять; после ручного выбора — нет.
  bool _userPickedDuration = false;
  bool _userPickedPriority = false;
  bool _userPickedRepeat = false;
  bool _userPickedReminder = false;
  // Модуль/тип авто-подставляются NL-парсером по ключевым словам названия,
  // пока пользователь не выбрал их вручную.
  bool _userPickedModuleLink = false;
  bool _userPickedType = false;

  // Напоминание перед задачей: null = нет; 0 = в момент; >0 = за N минут до
  // scheduledAt. Авто-подставляется парсером до ручного выбора (_userPickedReminder).
  int? _reminderMinutesBefore;

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
    // Нормализуем старые значения к показываемым (exam→deadline, low→medium),
    // чтобы соответствующий чип подсветился и сохранилось нормализованное.
    _type = _normalizeType(existing?.type ?? 'task');
    _priority = _normalizePriority(existing?.priority ?? 'medium');
    _scheduledAt = existing?.scheduledAt ?? _defaultScheduledAt();
    _durationMinutes = existing?.durationMinutes ?? _kDefaultDurationMinutes;
    _moduleLink = existing?.moduleLink;
    _color = existing?.color;
    _reminderMinutesBefore = existing?.reminderMinutesBefore;
    // Инициализируем состояние повтора из существующего правила (режим
    // редактирования якоря серии). Для виртуального повтора и обычной задачи
    // контрол повтора не показываем, поэтому состояние остаётся дефолтным.
    final existingRule = RecurrenceRule.parse(existing?.recurrenceRule);
    if (existingRule != null) {
      _repeatFreq = existingRule.freq;
      _repeatUntil = existingRule.until;
      _repeatWeekdays
        ..clear()
        ..addAll(existingRule.byDays);
      _repeatMonthDay = existingRule.byMonthDay;
    }
    // Поле ручного ввода больше не показывается всегда (кастомная длительность —
    // через чип «Свой»/диалог), оставляем контроллер для диалога ввода минут.
    _customMinutesController = TextEditingController();
    // Для НОВОЙ задачи предзаполняем напоминание из глобального дефолта, если
    // пользователь его ещё не трогал. Делаем в post-frame, т.к. читаем провайдер.
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _applyReminderDefault();
      });
    }
    // Загружаем число main-задач для отображения подсказки лимита.
    _loadMainCount();
    // Загружаем недавние названия задач для ряда «быстрый выбор».
    _loadRecentTitles();
    // Загружаем вложения (только в режиме редактирования — у новой задачи нет id).
    if (_isEditing) _loadAttachments();
    // Загружаем подзадачи (чеклист) для редактируемой задачи / шаблона серии.
    if (_isEditing) _loadSubtasks();
    // Слушаем изменения заголовка для NL-парсинга.
    _titleController.addListener(_onTitleChanged);
  }

  /// Запускается при каждом изменении заголовка.
  /// Применяет NL-парсер и автоподставляет распознанные поля.
  ///
  /// Политика автоподстановки: каждое поле (дата/время, длительность, приоритет,
  /// повтор) подставляется ТОЛЬКО пока пользователь не трогал его вручную
  /// (флаги _userPicked*). После ручного выбора NL это поле не перетирает —
  /// явный выбор пользователя главнее. Поля независимы: можно вручную задать
  /// время, но всё ещё ловить длительность/приоритет/повтор из текста.
  void _onTitleChanged() {
    final text = _titleController.text;
    final result = parseNaturalDateTime(text, DateTime.now());
    // Кэшируем разбор: _save/_cleanedTitle переиспользуют его без второго
    // parseNaturalDateTime(DateTime.now()) (баг 2 — двойной парсинг у полуночи).
    _lastParseResult = result;
    _lastParsedText = text;

    // --- Дата/время ---
    if (!_userPickedDateTime) {
      if (result.when != null) {
        setState(() {
          _nlDetectedDateTime = result.when;
          _scheduledAt = result.when!;
        });
      } else if (_nlDetectedDateTime != null) {
        setState(() => _nlDetectedDateTime = null);
      }
    }

    // --- Длительность ---
    if (!_userPickedDuration && result.durationMinutes != null) {
      setState(() {
        _durationMinutes = result.durationMinutes!;
      });
    }

    // --- Приоритет ---
    if (!_userPickedPriority &&
        result.priority != null &&
        _priorities.contains(result.priority)) {
      final parsedPriority = _normalizePriority(result.priority!);
      // Лимит main соблюдаем: если main уже исчерпан, не подставляем main авто.
      final wantsMain = parsedPriority == 'main';
      final mainBlocked = wantsMain &&
          _mainCount >= _maxMainPerDay &&
          !(_isEditing && widget.existing!.priority == 'main');
      if (!mainBlocked) {
        setState(() => _priority = parsedPriority);
      }
    }

    // --- Повтор (серия) ---
    // Не трогаем для виртуальных повторов / якорей серии при редактировании —
    // там правило управляется серийными действиями.
    if (!_userPickedRepeat && !_isSeriesItem && result.recurrenceRule != null) {
      final rule = RecurrenceRule.parse(result.recurrenceRule);
      if (rule != null) {
        setState(() {
          _repeatFreq = rule.freq;
          _repeatWeekdays
            ..clear()
            ..addAll(rule.byDays);
          _repeatMonthDay = rule.byMonthDay;
        });
      }
    }

    // --- Напоминание перед задачей ---
    if (!_userPickedReminder && result.reminderMinutesBefore != null) {
      setState(() => _reminderMinutesBefore = result.reminderMinutesBefore);
    }

    // --- Модуль (moduleLink) по ключевым словам названия ---
    if (!_userPickedModuleLink && result.moduleLink != null) {
      setState(() => _moduleLink = result.moduleLink);
    }

    // --- Тип задачи по ключевым словам названия ---
    if (!_userPickedType &&
        result.type != null &&
        _types.contains(result.type)) {
      setState(() => _type = _normalizeType(result.type!));
    }
  }

  /// Возвращает чистый заголовок (без распознанных NL-фраз) для сохранения.
  /// Чистим, если распознано ХОТЬ ЧТО-ТО: время, длительность, приоритет или
  /// повтор — иначе оставляем исходный текст без изменений.
  String get _cleanedTitle {
    final text = _titleController.text;
    // Переиспользуем кэш из _onTitleChanged (один парсинг с одним now). Если
    // текст изменился без срабатывания listener'а (теоретически) — парсим заново.
    final result = (_lastParseResult != null && _lastParsedText == text)
        ? _lastParseResult!
        : parseNaturalDateTime(text, DateTime.now());
    final recognizedSomething = result.when != null ||
        result.durationMinutes != null ||
        result.priority != null ||
        result.recurrenceRule != null;
    if (recognizedSomething) return result.cleanedTitle.trim();
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

  /// Загружает подзадачи (чеклист) текущей задачи.
  /// Для виртуального повтора серии берём шаблон с якоря — пользователь видит
  /// общий чеклист серии (правка одного дня его материализует и переопределит).
  Future<void> _loadSubtasks() async {
    final existing = widget.existing;
    if (existing == null) return;
    final dao = ref.read(subtasksDaoProvider);
    final sourceId =
        _isVirtualOccurrence ? anchorIdFromVirtual(existing.id) : existing.id;
    final list = await dao.getSubtasks(sourceId);
    if (!mounted) return;
    setState(() {
      _subtasks
        ..clear()
        ..addAll(list.map((s) =>
            _SubtaskDraft(id: s.id, title: s.title, done: s.done)));
    });
  }

  /// Добавить подзадачу из поля ввода в черновик (сохранится при _save).
  void _addSubtask() {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) return;
    setState(() {
      _subtasks.add(_SubtaskDraft(id: uuidV4(), title: title, done: false));
      _subtaskController.clear();
    });
  }

  Future<void> _loadMainCount() async {
    final dao = ref.read(itemsDaoProvider);
    final count = await dao.countMainItems(widget.day);
    if (mounted) setState(() => _mainCount = count);
  }

  /// Загружает последние уникальные названия задач для ряда «быстрый выбор».
  Future<void> _loadRecentTitles() async {
    final dao = ref.read(itemsDaoProvider);
    final titles = await dao.recentDistinctTitles(limit: 8);
    if (mounted) setState(() => _recentTitles = titles);
  }

  /// Предзаполняет напоминание для НОВОЙ задачи из глобального дефолта, пока
  /// пользователь не выбрал напоминание вручную и NL-парсер его не задал.
  /// mode='all' → ставим default minutes; mode='main' и приоритет main → ставим;
  /// иначе оставляем «Нет» (null).
  void _applyReminderDefault() {
    if (_isEditing) return;
    if (_userPickedReminder) return;
    // NL-парсер уже мог задать напоминание из текста — не перетираем.
    if (_reminderMinutesBefore != null) return;
    final def = ref.read(reminderDefaultProvider);
    final shouldSet =
        def.mode == 'all' || (def.mode == 'main' && _priority == 'main');
    if (shouldSet && mounted) {
      setState(() => _reminderMinutesBefore = def.minutes);
    }
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
    _subtaskController.dispose();
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
    // Ручной выбор приоритета → NL больше не перетирает это поле.
    setState(() {
      _priority = priority;
      _userPickedPriority = true;
    });
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

  /// Выбор «Заканчивается в» — пользователь указывает время конца задачи,
  /// duration = разница в минутах с _scheduledAt. Вызывается из диалога «Свой».
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
      // Ручной выбор длительности → NL больше не перетирает.
      _userPickedDuration = true;
    });
  }

  /// Диалог кастомной длительности: ввод минут ИЛИ выбор времени окончания.
  Future<void> _showCustomDurationDialog() async {
    _customMinutesController.text = '$_durationMinutes';
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('today.custom_duration_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _customMinutesController,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: InputDecoration(
                labelText: ctx.s('today.custom_duration_minutes'),
                suffixText: ctx.s('today.duration_min_hint'),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (v) {
                final parsed = int.tryParse(v.trim());
                Navigator.of(ctx).pop(
                    parsed != null && parsed > 0 ? parsed : null);
              },
            ),
            const SizedBox(height: 12),
            // Альтернатива: выбрать время окончания «Заканчивается в…».
            OutlinedButton.icon(
              icon: const Icon(Icons.schedule_outlined, size: 18),
              label: Text(ctx.s('today.custom_duration_end')),
              onPressed: () {
                // Закрываем диалог без значения, затем открываем time picker.
                Navigator.of(ctx).pop(-1);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(_customMinutesController.text.trim());
              Navigator.of(ctx).pop(
                  parsed != null && parsed > 0 ? parsed : null);
            },
            child: Text(ctx.s('btn.add')),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (minutes == -1) {
      // Пользователь выбрал «Заканчивается в…» → time picker.
      await _pickEndTime();
      return;
    }
    if (minutes != null && minutes > 0) {
      setState(() {
        _durationMinutes = minutes;
        _userPickedDuration = true;
      });
    }
  }

  /// Диалог кастомного напоминания: ввод «за N минут до» (0 = в момент).
  Future<void> _showCustomReminderDialog() async {
    final controller = TextEditingController(
      text: _reminderMinutesBefore?.toString() ?? '',
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.s('today.reminder_label')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: ctx.s('today.reminder_min_before').replaceAll('{n}', 'N'),
            suffixText: ctx.s('today.duration_min_hint'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            final parsed = int.tryParse(v.trim());
            Navigator.of(ctx).pop(parsed != null && parsed >= 0 ? parsed : null);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(
                  parsed != null && parsed >= 0 ? parsed : null);
            },
            child: Text(ctx.s('btn.add')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (minutes != null && minutes >= 0) {
      setState(() {
        _reminderMinutesBefore = minutes;
        _userPickedReminder = true;
      });
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

  void _viewAttachment(ItemAttachmentsTableData a) {
    if (a.type == 'photo') {
      // Полноэкранный просмотр фото с зумом (InteractiveViewer).
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
                  child: Image.file(File(a.localPath), fit: BoxFit.contain),
                ),
              ),
            ),
            Positioned(
              top: 8 + MediaQuery.of(ctx).padding.top,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
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

    // Запоминаем названия занятий/событий для быстрого повторного ввода (C4).
    // (exam теперь нормализуется в deadline ещё на входе формы.)
    if (_type == 'event') {
      await ref.read(recentSubjectsProvider).add(title);
    }

    // Строка правила повтора для серии. None → null; иначе собираем правило по
    // выбранной частоте (+UNTIL если задана дата окончания). Для weekly/monthly
    // пустой выбор дней/числа => используем день недели/число даты задачи.
    final newRuleString = _buildRuleString();

    // id сохранённой задачи — для планирования напоминания после записи в Drift.
    String? savedItemId;

    if (_isVirtualOccurrence) {
      // Редактирование одного дня серии: материализуем его в реальную строку
      // с применёнными правками (анкер получает EXDATE на эту дату).
      // materializeOccurrence уже скопировал подзадачи-шаблон с якоря; затем
      // переопределяем их черновиком этого дня (replaceForItem).
      final concreteId = await dao.materializeOccurrence(
        anchorIdFromVirtual(widget.existing!.id),
        dateFromVirtual(widget.existing!.id) ?? widget.existing!.scheduledAt,
        title: title,
        type: _type,
        priority: _priority,
        scheduledAt: _scheduledAt,
        durationMinutes: _durationMinutes,
        isProtected: isProtected,
        color: _color,
      );
      if (concreteId != null) {
        await _persistSubtasks(concreteId);
        // materializeOccurrence не принимает reminder — проставляем отдельно.
        await dao.updateItem(
          concreteId,
          ItemsTableCompanion(
            reminderMinutesBefore: Value(_reminderMinutesBefore),
            updatedAt: Value(now),
          ),
        );
        savedItemId = concreteId;
      }
    } else if (_isEditing) {
      // Обычное редактирование / редактирование якоря серии. Для якоря
      // сохраняем (возможно обновлённую через UNTIL) строку правила; для
      // обычной задачи recurrenceRule остаётся прежним (null), но если
      // пользователь включил повтор — превращаем её в серию.
      final ruleValue = _isSeriesAnchor
          ? Value(newRuleString) // якорь: новое правило (None уберёт серию)
          : (_repeatEnabled
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
          reminderMinutesBefore: Value(_reminderMinutesBefore),
          moduleLink: Value(_moduleLink), // локальное поле — не попадает в синк
          color: Value(_color), // локальное поле — не попадает в синк
          updatedAt: Value(now),
        ),
      );
      await _persistSubtasks(widget.existing!.id);
      // Напоминание планируем только для НЕ-серийных задач (у якоря серии нет
      // одного конкретного scheduledAt; повторы материализуются отдельно).
      if (!_isSeriesAnchor) savedItemId = widget.existing!.id;
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
          reminderMinutesBefore: Value(_reminderMinutesBefore),
          moduleLink: Value(_moduleLink), // локальное поле — не попадает в синк
          color: Value(_color), // локальное поле — не попадает в синк
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _persistSubtasks(newId);
      // Записываем «добавлено» для одноуровневой отмены (кнопка ↩ на Today).
      ref.read(lastUndoableActionProvider.notifier).recordAdd(newId);
      // Напоминание планируем только для не-серийной задачи (newRuleString==null).
      if (newRuleString == null) savedItemId = newId;
    }

    // Планируем/отменяем локальное напоминание для сохранённой задачи.
    if (savedItemId != null) {
      await _applyReminder(savedItemId, title);
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Планирует или отменяет локальное напоминание для задачи [itemId].
  /// fireAt = scheduledAt − reminderMinutesBefore. Планируем, только если
  /// напоминание задано (не null) и fireAt в будущем; иначе снимаем прежнее
  /// (на случай, если пользователь убрал/сдвинул напоминание при редактировании).
  Future<void> _applyReminder(String itemId, String title) async {
    final service = ref.read(notificationServiceProvider);
    final minutes = _reminderMinutesBefore;
    if (minutes == null) {
      // Напоминание снято — разрешение не нужно, просто отменяем прежнее.
      await service.cancelTaskReminder(itemId);
      return;
    }
    // Напоминание ЗАДАНО: гарантируем разрешение (на Android 13+ его могли
    // не выдать через глобальный тумблер — иначе уведомление тихо не придёт).
    // Идемпотентно: системный диалог показывается один раз.
    final granted = await service.ensurePermission();
    final fireAt = _scheduledAt.subtract(Duration(minutes: minutes));
    // scheduleTaskReminder сам отменит прежнее и пропустит планирование,
    // если fireAt уже в прошлом. Планируем в любом случае (отказ не блокирует).
    await service.scheduleTaskReminder(itemId, title, fireAt);
    // Если пользователь отказал — ненавязчивая подсказка. Метод async, поэтому
    // после await проверяем mounted перед обращением к context.
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('today.reminder_permission_hint'))),
      );
    }
  }

  /// Сохраняет черновик подзадач в Drift, привязывая их к задаче [itemId].
  /// Заменяет весь набор (replaceForItem) — last-write-wins на уровне задачи.
  Future<void> _persistSubtasks(String itemId) async {
    final dao = ref.read(subtasksDaoProvider);
    final companions = <SubtasksTableCompanion>[];
    for (var i = 0; i < _subtasks.length; i++) {
      final s = _subtasks[i];
      companions.add(SubtasksTableCompanion(
        id: Value(s.id),
        itemId: Value(itemId),
        title: Value(s.title),
        done: Value(s.done),
        sortOrder: Value(i),
      ));
    }
    await dao.replaceForItem(itemId, companions);
  }

  /// Собирает строку правила повтора из выбранных контролов. null = без повтора.
  /// • daily   → FREQ=DAILY
  /// • weekly  → FREQ=WEEKLY;BYDAY=… (пустой выбор => день недели даты задачи)
  /// • monthly → FREQ=MONTHLY;BYMONTHDAY=N (null => день месяца даты задачи)
  /// UNTIL добавляется, если выбрана дата окончания.
  String? _buildRuleString() {
    final freq = _repeatFreq;
    if (freq == null) return null;
    final RecurrenceRule rule;
    switch (freq) {
      case RecurFreq.daily:
        rule = dailyRule(until: _repeatUntil);
      case RecurFreq.weekly:
        // Пустой выбор => effectiveByDays возьмёт день недели даты задачи; но
        // чтобы правило было самодостаточным, материализуем выбранный день.
        final days = _repeatWeekdays.isNotEmpty
            ? _repeatWeekdays
            : {RecurWeekday.fromDartWeekday(_scheduledAt.weekday)};
        rule = weeklyRule(days, until: _repeatUntil);
      case RecurFreq.monthly:
        rule = monthlyRule(
          monthDay: _repeatMonthDay ?? _scheduledAt.day,
          until: _repeatUntil,
        );
    }
    return rule.toRuleString();
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
    final subtasksDao = ref.read(subtasksDaoProvider);
    // Полный снимок ДО удаления: подзадачи (deleteItem удаляет их каскадно —
    // без снимка Undo вернул бы задачу без чеклиста, баг 4).
    final subtasksSnapshot = await subtasksDao.getSubtasks(existing.id);
    await dao.deleteItem(existing.id);
    // Снимаем запланированное напоминание удаляемой задачи (если было).
    await ref.read(notificationServiceProvider).cancelTaskReminder(existing.id);
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
      onUndo: () async {
        final now = DateTime.now();
        final newId = uuidV4();
        // Полный companion (включая reminderMinutesBefore/moduleLink/color,
        // которые раньше терялись, баг 4). Восстанавливаем под НОВЫЙ id.
        await dao.insertItem(
          ItemsTableCompanion(
            id: Value(newId),
            userId: Value(existing.userId),
            title: Value(existing.title),
            type: Value(existing.type),
            priority: Value(existing.priority),
            status: Value(existing.status),
            scheduledAt: Value(existing.scheduledAt),
            durationMinutes: Value(existing.durationMinutes),
            isProtected: Value(existing.isProtected),
            recurrenceRule: Value(existing.recurrenceRule),
            reminderMinutesBefore: Value(existing.reminderMinutesBefore),
            moduleLink: Value(existing.moduleLink),
            color: Value(existing.color),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
        // Восстанавливаем подзадачи под новый itemId (новые uuid).
        await subtasksDao.replaceForItem(
          newId,
          subtasksSnapshot
              .map((s) => SubtasksTableCompanion(
                    id: Value(uuidV4()),
                    itemId: Value(newId),
                    title: Value(s.title),
                    done: Value(s.done),
                    sortOrder: Value(s.sortOrder),
                  ))
              .toList(),
        );
      },
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // Настраиваемые пресеты длительности/напоминания (Профиль → Задачи по умолч.).
    final durationPresets = ref.watch(durationPresetsProvider);
    final reminderPresets = ref.watch(reminderPresetsProvider);

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

            // 1. Заголовок + mic + NL-подсказка
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
            const SizedBox(height: 12),

            // 2. Быстрый выбор — шаблоны (l10n) + недавние задачи, один ряд.
            _QuickPickRow(
              recentTitles: _recentTitles,
              onSelectTemplate: (title, type, moduleLink) => setState(() {
                _titleController.text = title;
                _type = _normalizeType(type);
                // Шаблон явно задаёт тип → NL не перетирает его.
                _userPickedType = true;
                if (moduleLink != null) {
                  _moduleLink = moduleLink;
                  _userPickedModuleLink = true;
                }
              }),
              onSelectRecent: (title) =>
                  setState(() => _titleController.text = title),
            ),
            const SizedBox(height: 16),

            // 3. Тип — 3 чипа (Задача / Событие / Дедлайн). exam→deadline.
            Text(context.s('today.type_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in _displayTypes) ...[
                    ChoiceChip(
                      label: Text(context.s('today.type_chip_$t')),
                      selected: _type == t,
                      onSelected: (_) => setState(() {
                        _type = t;
                        // Ручной выбор → NL больше не перетирает тип.
                        _userPickedType = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Приоритет — 3 чипа (Главное / Важная / Обычная) + «?»-подсказка.
            Row(
              children: [
                Text(context.s('today.priority_label'),
                    style: textTheme.labelMedium),
                const SizedBox(width: 6),
                Tooltip(
                  message: context.s('today.priority_help'),
                  triggerMode: TooltipTriggerMode.tap,
                  showDuration: const Duration(seconds: 8),
                  child: Icon(
                    Icons.help_outline,
                    size: 16,
                    color: Theme.of(context)
                            .extension<FocusThemeExtension>()
                            ?.textMuted ??
                        colorScheme.onSurface.withAlpha(160),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final pr in _displayPriorities) ...[
                    ChoiceChip(
                      label: Text(context.s('today.priority_chip_$pr')),
                      selected: _priority == pr,
                      onSelected: (_) => _onPriorityTap(pr),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
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

            // 5. Дата (date picker).
            OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(DateFormat.yMMMEd().format(_scheduledAt)),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: _pickDate,
            ),
            const SizedBox(height: 16),

            // 6. Начало — время старта (перенесено выше длительности).
            Text(context.s('today.start_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.access_time, size: 18),
              label: Text(DateFormat.Hm().format(_scheduledAt)),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                minimumSize: const Size(double.infinity, 44),
              ),
              onPressed: _pickTime,
            ),
            const SizedBox(height: 16),

            // 7. Длительность — пресеты из durationPresetsProvider + «Свой».
            // Один горизонтально прокручиваемый ряд (не переносится).
            Text(context.s('today.duration_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final d in durationPresets) ...[
                    ChoiceChip(
                      label: Text(_durationLabel(d)),
                      selected: _durationMinutes == d,
                      onSelected: (_) => setState(() {
                        _durationMinutes = d;
                        // Ручной выбор → NL не перетирает длительность.
                        _userPickedDuration = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Чип «Свой» — диалог ввода минут / выбора времени окончания.
                  // Подсвечен, если текущее значение не входит в пресеты.
                  ChoiceChip(
                    label: Text(
                      durationPresets.contains(_durationMinutes)
                          ? context.s('today.custom_chip')
                          : '${context.s('today.custom_chip')} · '
                              '${_durationLabel(_durationMinutes)}',
                    ),
                    avatar: const Icon(Icons.tune, size: 16),
                    selected: !durationPresets.contains(_durationMinutes),
                    onSelected: (_) => _showCustomDurationDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 8. Повтор (серия). Для виртуального повтора серии контрол правила не
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
                    selected: _repeatFreq == null,
                    onSelected: (_) => setState(() {
                      _repeatFreq = null;
                      _userPickedRepeat = true;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(context.s('addtask.repeat_daily')),
                    selected: _repeatFreq == RecurFreq.daily,
                    onSelected: (_) => setState(() {
                      _repeatFreq = RecurFreq.daily;
                      _userPickedRepeat = true;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(context.s('addtask.repeat_weekly')),
                    selected: _repeatFreq == RecurFreq.weekly,
                    onSelected: (_) => setState(() {
                      _repeatFreq = RecurFreq.weekly;
                      _userPickedRepeat = true;
                    }),
                  ),
                  ChoiceChip(
                    label: Text(context.s('addtask.repeat_monthly')),
                    selected: _repeatFreq == RecurFreq.monthly,
                    onSelected: (_) => setState(() {
                      _repeatFreq = RecurFreq.monthly;
                      _userPickedRepeat = true;
                    }),
                  ),
                ],
              ),
              // WEEKLY: выбор дней недели чипами Пн..Вс.
              if (_repeatFreq == RecurFreq.weekly) ...[
                const SizedBox(height: 8),
                _WeekdayPicker(
                  selected: _repeatWeekdays,
                  onToggle: (wd) => setState(() {
                    if (_repeatWeekdays.contains(wd)) {
                      _repeatWeekdays.remove(wd);
                    } else {
                      _repeatWeekdays.add(wd);
                    }
                    _userPickedRepeat = true;
                  }),
                ),
              ],
              // MONTHLY: выбор числа месяца (1..31). По умолчанию — день даты.
              if (_repeatFreq == RecurFreq.monthly) ...[
                const SizedBox(height: 8),
                _MonthDayPicker(
                  value: _repeatMonthDay ?? _scheduledAt.day,
                  label: context.s('addtask.repeat_monthday'),
                  onChanged: (d) => setState(() {
                    _repeatMonthDay = d;
                    _userPickedRepeat = true;
                  }),
                ),
              ],
              // Дата окончания повтора (UNTIL) — показывается при включённом повторе.
              if (_repeatEnabled) ...[
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

            // 9. Напоминание — «Нет» + пресеты из reminderPresetsProvider + «Свой».
            // Один горизонтально прокручиваемый ряд (не переносится).
            Text(context.s('today.reminder_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(context.s('today.reminder_none')),
                    selected: _reminderMinutesBefore == null,
                    onSelected: (_) => setState(() {
                      _reminderMinutesBefore = null;
                      _userPickedReminder = true;
                    }),
                  ),
                  const SizedBox(width: 8),
                  for (final m in reminderPresets) ...[
                    ChoiceChip(
                      label: Text(_reminderLabel(context, m)),
                      selected: _reminderMinutesBefore == m,
                      onSelected: (_) => setState(() {
                        _reminderMinutesBefore = m;
                        _userPickedReminder = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Чип «Свой» — диалог ввода минут «за N минут до».
                  ChoiceChip(
                    label: Text(
                      (_reminderMinutesBefore != null &&
                              !reminderPresets.contains(_reminderMinutesBefore))
                          ? '${context.s('today.custom_chip')} · '
                              '${_reminderLabel(context, _reminderMinutesBefore)}'
                          : context.s('today.custom_chip'),
                    ),
                    avatar: const Icon(Icons.tune, size: 16),
                    selected: _reminderMinutesBefore != null &&
                        !reminderPresets.contains(_reminderMinutesBefore),
                    onSelected: (_) => _showCustomReminderDialog(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Подзадачи (чеклист). Для виртуального повтора серии — общий шаблон;
            // правка дня материализует его в отдельную копию (см. _save).
            Text(context.s('today.subtasks_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            _SubtasksEditor(
              subtasks: _subtasks,
              controller: _subtaskController,
              hintText: context.s('today.subtask_hint'),
              onAdd: _addSubtask,
              onToggle: (i, v) => setState(() => _subtasks[i].done = v),
              onRemove: (i) => setState(() => _subtasks.removeAt(i)),
              // onReorderItem: newIndex уже скорректирован под удалённый элемент.
              onReorder: (oldIndex, newIndex) => setState(() {
                final moved = _subtasks.removeAt(oldIndex);
                _subtasks.insert(newIndex, moved);
              }),
            ),
            const SizedBox(height: 16),

            // 10. «▸ Ещё» — сворачиваемый блок (по умолчанию свёрнут):
            // Модуль, Цвет, Вложения.
            InkWell(
              onTap: () => setState(() => _moreExpanded = !_moreExpanded),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _moreExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(context.s('today.more_section'),
                        style: textTheme.labelMedium),
                  ],
                ),
              ),
            ),
            if (_moreExpanded) ...[
              const SizedBox(height: 12),

              // Привязка к модулю — необязательный выбор.
              _ModuleLinkPicker(
                value: _moduleLink,
                onChanged: (v) => setState(() {
                  _moduleLink = v;
                  // Ручной выбор → NL больше не перетирает модуль.
                  _userPickedModuleLink = true;
                }),
              ),
              const SizedBox(height: 16),

              // Цвет-метка задачи — палитра пресетов + «нет цвета».
              Text(context.s('today.color_label'), style: textTheme.labelMedium),
              const SizedBox(height: 8),
              _ColorPicker(
                value: _color,
                onChanged: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 16),

              // Вложения (фото / видео): подпись + 3 способа добавления
              // (камера / галерея / видео) + сетка миниатюр-превью.
              Text(context.s('today.attachments_label'),
                  style: textTheme.labelMedium),
              const SizedBox(height: 8),
              // Кнопки добавления — три явных способа, иконка + подпись.
              Row(
                children: [
                  Expanded(
                    child: _AttachAddButton(
                      icon: Icons.photo_camera_outlined,
                      label: context.s('today.attach_camera'),
                      onTap: () => _pickAttachment(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AttachAddButton(
                      icon: Icons.photo_library_outlined,
                      label: context.s('today.attach_gallery'),
                      onTap: () => _pickAttachment(ImageSource.gallery),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AttachAddButton(
                      icon: Icons.videocam_outlined,
                      label: context.s('today.attach_video'),
                      onTap: () =>
                          _pickAttachment(ImageSource.gallery, isVideo: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_attachments.isEmpty)
                Text(
                  context.s('today.attachments_empty'),
                  style: textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                            .extension<FocusThemeExtension>()
                            ?.textMuted ??
                        colorScheme.onSurface.withAlpha(160),
                  ),
                )
              else
                // Сетка квадратных миниатюр (~72dp), переносится на строки.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final a in _attachments)
                      _AttachmentThumb(
                        attachment: a,
                        onTap: () => _viewAttachment(a),
                        onDelete: () => _deleteAttachment(a),
                      ),
                  ],
                ),
            ], // конец сворачиваемого блока «Ещё»
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

// ---------------------------------------------------------------------------
// Кнопка одного способа добавления вложения (камера / галерея / видео):
// иконка над короткой подписью, нейтральная рамка как у остальной формы.
// ---------------------------------------------------------------------------

class _AttachAddButton extends StatelessWidget {
  const _AttachAddButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final muted = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12),
        foregroundColor: colorScheme.onSurface,
        side: BorderSide(color: ext?.border ?? colorScheme.outline),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: muted),
          const SizedBox(height: 4),
          Text(label, style: textTheme.labelSmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Квадратная миниатюра одного вложения: фото через Image.file, видео — кадр-
// заглушка с иконкой ▶. Тап — просмотр на весь экран; крестик в углу — удаление.
// ---------------------------------------------------------------------------

class _AttachmentThumb extends StatelessWidget {
  const _AttachmentThumb({
    required this.attachment,
    required this.onTap,
    required this.onDelete,
  });

  final ItemAttachmentsTableData attachment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final isVideo = attachment.type != 'photo';

    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          // Превью (фото или кадр-заглушка видео).
          Positioned.fill(
            child: GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isVideo
                    ? Container(
                        color: ext?.surfaceElevated ?? colorScheme.surface,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.play_circle_outline,
                          size: 30,
                          color: colorScheme.onSurface,
                        ),
                      )
                    : Image.file(
                        File(attachment.localPath),
                        fit: BoxFit.cover,
                        // Если файл недоступен — нейтральная заглушка, не падаем.
                        errorBuilder: (ctx, _, _) => Container(
                          color: ext?.surfaceElevated ?? colorScheme.surface,
                          alignment: Alignment.center,
                          child: Icon(Icons.broken_image_outlined,
                              size: 24, color: colorScheme.onSurface),
                        ),
                      ),
              ),
            ),
          ),
          // Кнопка удаления — крестик в правом верхнем углу.
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
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
// Выбор цвета-метки задачи — Wrap из кружков-сватчей + опция «нет цвета».
// Значение — ключ палитры (task_colors.dart) или null. Выбранный сватч
// получает кольцо-обводку; «нет цвета» — перечёркнутый кружок.
// ---------------------------------------------------------------------------

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.value,
    required this.onChanged,
  });

  /// Текущий ключ цвета или null (нет цвета).
  final String? value;

  /// null = снять цвет; иначе ключ выбранного пресета.
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final ringColor = scheme.onSurface;
    final mutedColor = ext?.textMuted ?? scheme.onSurface.withAlpha(160);
    final borderColor = ext?.border ?? scheme.outline;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // «Нет цвета» — перечёркнутый кружок, очищает выбор.
        _ColorSwatch(
          selected: value == null,
          ringColor: ringColor,
          tooltip: context.s('today.color_none'),
          onTap: () => onChanged(null),
          fill: Colors.transparent,
          borderColor: borderColor,
          child: Icon(
            Icons.format_color_reset_outlined,
            size: 18,
            color: mutedColor,
          ),
        ),
        for (final option in kTaskColors)
          _ColorSwatch(
            selected: value == option.key,
            ringColor: ringColor,
            tooltip: option.key,
            onTap: () => onChanged(option.key),
            fill: option.color,
            borderColor: option.color,
            child: value == option.key
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
      ],
    );
  }
}

/// Один кружок-сватч палитры. Выбранный получает обводку-кольцо.
class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.selected,
    required this.ringColor,
    required this.tooltip,
    required this.onTap,
    required this.fill,
    required this.borderColor,
    this.child,
  });

  final bool selected;
  final Color ringColor;
  final String tooltip;
  final VoidCallback onTap;
  final Color fill;
  final Color borderColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? ringColor : borderColor,
              width: selected ? 2.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Подзадачи (чеклист) — черновик и редактор.
// ---------------------------------------------------------------------------

/// Черновик одной подзадачи в форме (до сохранения в Drift).
/// id фиксируется при создании, чтобы переживать reorder/replaceForItem.
class _SubtaskDraft {
  _SubtaskDraft({required this.id, required this.title, required this.done});

  final String id;
  final String title;
  bool done;
}

/// Редактор чеклиста подзадач: поле ввода + «+», список с чекбоксом,
/// удалением и drag-переупорядочиванием (ReorderableListView, как в проекте).
class _SubtasksEditor extends StatelessWidget {
  const _SubtasksEditor({
    required this.subtasks,
    required this.controller,
    required this.hintText,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
    required this.onReorder,
  });

  final List<_SubtaskDraft> subtasks;
  final TextEditingController controller;
  final String hintText;
  final VoidCallback onAdd;
  final void Function(int index, bool value) onToggle;
  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final muted = ext?.textMuted ?? colorScheme.onSurface.withAlpha(160);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (subtasks.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: subtasks.length,
            onReorderItem: onReorder,
            itemBuilder: (ctx, i) {
              final s = subtasks[i];
              return Padding(
                key: ValueKey(s.id),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Checkbox(
                        value: s.done,
                        onChanged: (v) => onToggle(i, v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.title,
                        style: textTheme.bodyMedium?.copyWith(
                          decoration: s.done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: s.done ? muted : colorScheme.onSurface,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: muted,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onRemove(i),
                    ),
                    ReorderableDragStartListener(
                      index: i,
                      child: Icon(Icons.drag_handle, size: 20, color: muted),
                    ),
                  ],
                ),
              );
            },
          ),
        // Поле добавления новой подзадачи + кнопка «+».
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hintText,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onSubmitted: (_) => onAdd(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: context.s('btn.add'),
              onPressed: onAdd,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Выбор дней недели для WEEKLY-повтора — чипы Пн..Вс (мультивыбор).
// Использует существующие локализованные ярлыки plan.weekday_*.
// ---------------------------------------------------------------------------

class _WeekdayPicker extends StatelessWidget {
  const _WeekdayPicker({
    required this.selected,
    required this.onToggle,
  });

  final Set<RecurWeekday> selected;
  final ValueChanged<RecurWeekday> onToggle;

  static const _labelKeys = {
    RecurWeekday.mo: 'plan.weekday_mon',
    RecurWeekday.tu: 'plan.weekday_tue',
    RecurWeekday.we: 'plan.weekday_wed',
    RecurWeekday.th: 'plan.weekday_thu',
    RecurWeekday.fr: 'plan.weekday_fri',
    RecurWeekday.sa: 'plan.weekday_sat',
    RecurWeekday.su: 'plan.weekday_sun',
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: RecurWeekday.values.map((wd) {
        return FilterChip(
          label: Text(context.s(_labelKeys[wd]!)),
          selected: selected.contains(wd),
          onSelected: (_) => onToggle(wd),
        );
      }).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Выбор числа месяца для MONTHLY-повтора (1..31) — компактный DropdownButton.
// ---------------------------------------------------------------------------

class _MonthDayPicker extends StatelessWidget {
  const _MonthDayPicker({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final int value;
  final String label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(label, style: textTheme.bodyMedium),
        const SizedBox(width: 12),
        DropdownButton<int>(
          value: value,
          items: [
            for (var d = 1; d <= 31; d++)
              DropdownMenuItem(value: d, child: Text('$d')),
          ],
          onChanged: (d) {
            if (d != null) onChanged(d);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Быстрый выбор — один горизонтальный ряд: переведённые шаблоны (l10n) +
// недавние названия задач пользователя. Тап заполняет название (+ тип/модуль
// для шаблона). Шаблоны переосмыслены (учёба/задание/тренировка/лекция/встреча/
// чтение). Недавние подмешиваются после шаблонов, дубли по названию убираются.
// ---------------------------------------------------------------------------

/// Описание шаблона быстрого выбора. [labelKey] — ключ l10n ярлыка;
/// [type] — задаваемый тип; [moduleLink] — необязательная привязка к модулю.
class _QuickTemplate {
  const _QuickTemplate({
    required this.emoji,
    required this.labelKey,
    required this.type,
    this.moduleLink,
  });

  final String emoji;
  final String labelKey;
  final String type;
  final String? moduleLink;
}

const List<_QuickTemplate> _kQuickTemplates = [
  _QuickTemplate(emoji: '📚', labelKey: 'today.template_study', type: 'task'),
  _QuickTemplate(
      emoji: '📝', labelKey: 'today.template_assignment', type: 'deadline'),
  _QuickTemplate(
      emoji: '🏋️',
      labelKey: 'today.template_workout',
      type: 'task',
      moduleLink: 'workout'),
  _QuickTemplate(
      emoji: '🎓', labelKey: 'today.template_lecture', type: 'event'),
  _QuickTemplate(
      emoji: '👥', labelKey: 'today.template_meeting', type: 'event'),
  _QuickTemplate(emoji: '📖', labelKey: 'today.template_reading', type: 'task'),
];

class _QuickPickRow extends StatelessWidget {
  const _QuickPickRow({
    required this.recentTitles,
    required this.onSelectTemplate,
    required this.onSelectRecent,
  });

  final List<String> recentTitles;

  /// (title, type, moduleLink) — шаблон задаёт тип и (опц.) модуль.
  final void Function(String title, String type, String? moduleLink)
      onSelectTemplate;

  /// Недавняя задача — заполняет только название.
  final void Function(String title) onSelectRecent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // accentMuted для фона чипов быстрого выбора — нейтральный chip-fill.
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final chipFill = ext?.accentMuted ?? colorScheme.surface;

    // Названия шаблонов (для дедупликации недавних, регистронезависимо).
    final templateLabels = {
      for (final t in _kQuickTemplates) context.s(t.labelKey).toLowerCase(),
    };
    final recents = recentTitles
        .where((r) => !templateLabels.contains(r.toLowerCase()))
        .toList();

    Widget chip({required String text, required VoidCallback onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: chipFill,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.center,
          child: Text(text, style: textTheme.bodySmall),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _kQuickTemplates) ...[
              chip(
                text: '${t.emoji} ${context.s(t.labelKey)}',
                onTap: () =>
                    onSelectTemplate(context.s(t.labelKey), t.type, t.moduleLink),
              ),
              const SizedBox(width: 8),
            ],
            for (final r in recents) ...[
              chip(text: '🕘 $r', onTap: () => onSelectRecent(r)),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}
