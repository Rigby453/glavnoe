// FL-TODAY-05: Нижний лист добавления/редактирования задачи.
// - Поле заголовка (autofocus) с голосовым вводом (mic) и NL-парсером дат.
// - Чипы типа и приоритета, выбор даты и времени.
// - Лимит: максимум 3 main-задачи в день (enforced при выборе приоритета main).
// - Сохранение пишет в Drift через ItemsDao (офлайн-первый подход).
// - Секция вложений: фото/видео, хранятся локально (schemaVersion 11).
//
// Локальное состояние формы (контроллер, выбранные чипы) — эфемерное,
// поэтому здесь используется StatefulWidget; бизнес-состояние идёт через Riverpod.

import 'dart:convert';
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
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../core/animations/app_sheet.dart';
import '../../../core/categories/categories_enabled_provider.dart';
import '../../../core/categories/category_dot.dart';
import '../../../core/animations/app_toast.dart';
import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/settings/recent_subjects.dart';
import '../../../core/settings/reminder_default_provider.dart';
import '../../../core/settings/task_presets_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/attachment_view.dart';
import '../../../core/widgets/number_input_dialog.dart';
import '../../../core/utils/id.dart';
import '../../../core/utils/module_inference.dart';
import '../../../core/utils/nl_datetime.dart';
import '../../../core/utils/tag_parser.dart';
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
///
/// [initialAt] / [initialDurationMinutes] — необязательное предзаполнение
/// времени начала и длительности (drag-to-create в сетке времени: пользователь
/// «нарисовал» интервал по пустой области). Применяются только при создании
/// (existing == null) и игнорируются в режиме редактирования. Обычный вызов с
/// одним [day] работает как прежде.
Future<void> showAddTaskSheet(
  BuildContext context, {
  required DateTime day,
  ItemsTableData? existing,
  DateTime? initialAt,
  int? initialDurationMinutes,
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
        child: AddTaskSheet(
          day: day,
          existing: existing,
          initialAt: initialAt,
          initialDurationMinutes: initialDurationMinutes,
        ),
      ),
    ),
  );
}

class AddTaskSheet extends ConsumerStatefulWidget {
  const AddTaskSheet({
    required this.day,
    this.existing,
    this.initialAt,
    this.initialDurationMinutes,
    super.key,
  });

  /// День, в контексте которого создаётся задача (для лимита main и дефолта даты)
  final DateTime day;

  /// Если задан — режим редактирования
  final ItemsTableData? existing;

  /// Предзаполненное время начала для НОВОЙ задачи (drag-to-create в сетке).
  /// В режиме редактирования игнорируется (приоритет у existing.scheduledAt).
  final DateTime? initialAt;

  /// Предзаполненная длительность (минут) для НОВОЙ задачи (drag-to-create).
  /// В режиме редактирования игнорируется.
  final int? initialDurationMinutes;

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
  // Цвет-метка задачи: null = нет, или ключ палитры из task_colors.dart (локальное поле)
  String? _color;
  // Место/локация задачи (свободный текст, как в Google Calendar). Локальное
  // поле — НЕ синхронизируется. Контроллер хранит текст; пустой => null в Drift.
  late final TextEditingController _locationController;

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

  // Теги задачи (без «#»), извлечённые из заголовка или добавленные вручную.
  // При загрузке извлекаются из сохранённого заголовка; при сохранении
  // возвращаются в строку через buildStoredTitle.
  final List<String> _tags = [];

  // Недавние уникальные названия задач (для ряда «быстрый выбор»).
  List<String> _recentTitles = [];

  // Все уникальные теги из истории задач (для ряда подсказок тегов, B7).
  List<String> _allUsedTags = [];

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
  // Тип авто-подставляется NL-парсером по ключевым словам названия,
  // пока пользователь не выбрал его вручную.
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
    // Извлекаем теги из сохранённого заголовка: в Drift хранится «заголовок #tag1 #tag2».
    // Показываем в поле только cleanTitle; теги отображаются как чипы.
    final rawTitle = existing?.title ?? '';
    final tagResult = parseTaskTags(rawTitle);
    _tags
      ..clear()
      ..addAll(tagResult.tags);
    _titleController = TextEditingController(text: tagResult.cleanTitle);
    // Нормализуем старые значения к показываемым (exam→deadline, low→medium),
    // чтобы соответствующий чип подсветился и сохранилось нормализованное.
    _type = _normalizeType(existing?.type ?? 'task');
    _priority = _normalizePriority(existing?.priority ?? 'medium');
    // Приоритет времени/длительности: существующая задача (редактирование) →
    // предзаполнение из drag-to-create (initialAt/initialDurationMinutes) →
    // умный дефолт. initial* применяются только при создании (existing == null).
    _scheduledAt =
        existing?.scheduledAt ?? widget.initialAt ?? _defaultScheduledAt();
    _durationMinutes = existing?.durationMinutes ??
        widget.initialDurationMinutes ??
        _kDefaultDurationMinutes;
    // Пользователь явно задал время рисованием на сетке — NL-парсер заголовка
    // не должен его перетирать (как после ручного выбора времени).
    if (existing == null && widget.initialAt != null) {
      _userPickedDateTime = true;
    }
    if (existing == null && widget.initialDurationMinutes != null) {
      _userPickedDuration = true;
    }
    _color = existing?.color;
    _locationController = TextEditingController(text: existing?.location ?? '');
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
    // Загружаем все использованные теги для подсказок (B7).
    _loadUsedTags();
    // Вложения. Для новой задачи сначала чистим возможные «осиротевшие»
    // '__pending__'-строки от предыдущей прерванной сессии (иначе они
    // протекли бы в новую задачу), затем — на Android подбираем потерянный
    // результат камеры (Activity мог пересоздаться) и загружаем сетку.
    if (_isEditing) {
      _loadAttachments();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initPendingAttachments();
      });
    }
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

    // --- Тип задачи по ключевым словам названия ---
    if (!_userPickedType &&
        result.type != null &&
        _types.contains(result.type)) {
      setState(() => _type = _normalizeType(result.type!));
    }

    // --- Теги: авто-извлечение #tag-токенов из поля заголовка ---
    // Когда пользователь печатает «#cs101» в заголовке, тег извлекается
    // в чипы-список, а из поля ввода убирается токен (чистая строка остаётся).
    // Это происходит ТОЛЬКО если в тексте есть хотя бы один тег.
    final tagResult = parseTaskTags(text);
    if (tagResult.tags.isNotEmpty) {
      // Добавляем новые теги (которых ещё нет в _tags), сохраняя порядок.
      bool newTagsAdded = false;
      for (final t in tagResult.tags) {
        if (!_tags.contains(t)) {
          _tags.add(t);
          newTagsAdded = true;
        }
      }
      if (newTagsAdded || tagResult.cleanTitle != text) {
        // Обновляем поле ввода: убираем тег-токены, оставляем чистый заголовок.
        // Сохраняем курсор в конце чистой строки.
        final clean = tagResult.cleanTitle;
        if (_titleController.text != clean) {
          _titleController.value = TextEditingValue(
            text: clean,
            selection: TextSelection.collapsed(offset: clean.length),
          );
          // listener сработает снова, но tagResult.tags уже пусты → цикл не бесконечный.
        }
        setState(() {}); // обновляем чипы
      }
    }
  }

  /// Возвращает чистый заголовок (без распознанных NL-фраз) для сохранения.
  /// Чистим, если распознан ЛЮБОЙ параметр, который вырезается из названия:
  /// время, длительность, приоритет, повтор ИЛИ напоминание. Эти параметры
  /// одновременно автоподставляются в _onTitleChanged, поэтому их фрагмент
  /// должен уйти и из заголовка (например «звонок напомни за 10 мин» → «звонок»).
  /// moduleLink/type намеренно НЕ учитываем — их ключевые слова остаются в
  /// названии (смысловое ядро), парсер их не вырезает.
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
        result.recurrenceRule != null ||
        result.reminderMinutesBefore != null;
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

  /// Временный itemId для вложений новой (ещё не сохранённой) задачи.
  /// При сохранении перепривязываются к реальному id (reassignItemId в _save).
  static const String _pendingAttachmentItemId = '__pending__';

  /// id, под которым лежат вложения текущей формы: реальный id для
  /// редактирования, '__pending__' для новой задачи.
  String get _attachmentItemId => widget.existing?.id ?? _pendingAttachmentItemId;

  Future<void> _loadAttachments() async {
    // Работает и для новой задачи: читаем по _attachmentItemId (для новой —
    // '__pending__'), иначе сетка миниатюр у новой задачи никогда не обновлялась
    // после добавления (баг «через раз»). Future-запрос вместо стрима — нам нужен
    // снимок текущего набора.
    final dao = ref.read(itemAttachmentsDaoProvider);
    final list = await dao.getAttachments(_attachmentItemId);
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

  /// Загружает все использованные теги из истории задач (для подсказок, B7).
  Future<void> _loadUsedTags() async {
    final dao = ref.read(itemsDaoProvider);
    final tags = await dao.allUsedTags();
    if (mounted) setState(() => _allUsedTags = tags);
  }

  /// Вычисляет частичный #-префикс, который пользователь сейчас набирает.
  /// Если заголовок заканчивается на «#слово» (без пробела после — незавершённый
  /// тег), возвращает «слово» в lowercase как префикс для фильтрации подсказок.
  /// Иначе — null (подсказки не фильтруются, показываются все).
  String? get _typingTagPrefix {
    final text = _titleController.text;
    // Ищем #word в конце строки (без trailing-пробела — незавершённый тег).
    final match = RegExp(r'(?:^|[\s(])#([\wЀ-ӿ]+)$').firstMatch(text);
    if (match == null) return null;
    return match.group(1)!.toLowerCase();
  }

  /// Список подсказок-тегов для отображения: все использованные теги, исключая
  /// уже выбранные (_tags), отфильтрованные по частичному префиксу (если есть).
  /// Ограничиваем 20 штуками для читаемости ряда.
  List<String> get _tagSuggestions {
    if (_allUsedTags.isEmpty) return const [];
    final selectedLower = _tags.map((t) => t.toLowerCase()).toSet();
    final prefix = _typingTagPrefix;
    return _allUsedTags
        .where((tag) => !selectedLower.contains(tag))
        .where((tag) => prefix == null || tag.startsWith(prefix))
        .take(20)
        .toList();
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
    _locationController.dispose();
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
          // Быстрые повторные тапы по «main» при исчерпанном лимите копили
          // снекбары в очереди (потом они долго показывались по очереди).
          // Чистим очередь и показываем только один актуальный, короткий.
          ScaffoldMessenger.of(context)
            ..clearSnackBars()
            ..showSnackBar(
              SnackBar(
                content: Text(context.s('today.max_main_snackbar')),
                duration: const Duration(seconds: 2),
              ),
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
    // Контроллером владеет State диалога (NumberInputDialog) — он уничтожается
    // ПОСЛЕ анимации закрытия, поэтому краш «used after disposed» исключён.
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => NumberInputDialog(
        title: ctx.s('today.reminder_label'),
        labelText:
            ctx.s('today.reminder_min_before').replaceAll('{n}', 'N'),
        suffixText: ctx.s('today.duration_min_hint'),
        initialValue: _reminderMinutesBefore,
        // 0 = «в момент» допустимо, поэтому минимум 0.
        minValue: 0,
      ),
    );
    if (!mounted) return;
    if (minutes != null && minutes >= 0) {
      setState(() {
        _reminderMinutesBefore = minutes;
        _userPickedReminder = true;
      });
    }
  }

  /// Инициализация вложений новой задачи (post-frame):
  /// 1) Чистим осиротевшие '__pending__' от прошлой прерванной сессии формы.
  /// 2) На Android подбираем «потерянный» результат камеры/галереи
  ///    (Activity мог быть пересоздан и pick* вернул бы null — баг «через раз»).
  /// 3) Загружаем сетку.
  Future<void> _initPendingAttachments() async {
    final dao = ref.read(itemAttachmentsDaoProvider);
    // Осиротевшие pending-вложения предыдущей сессии (форма закрыта без сохранения
    // не успев перепривязать) удаляем вместе с файлами, чтобы они не «прилипли»
    // к новой задаче.
    await dao.deleteAllForItem(_pendingAttachmentItemId);
    await _retrieveLostAttachment();
    if (mounted) _loadAttachments();
  }

  /// Android: подбор потерянного результата image_picker после пересоздания
  /// Activity (стандартное решение image_picker). На прочих платформах — no-op.
  Future<void> _retrieveLostAttachment() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return;
      final isVideo = response.type == RetrieveType.video;
      // files заполняется только для мульти-выбора; для одиночного фото/видео
      // результат лежит в file. Берём непустой набор из доступного.
      final files = (response.files != null && response.files!.isNotEmpty)
          ? response.files!
          : (response.file != null ? [response.file!] : const <XFile>[]);
      for (final f in files) {
        await _storeAttachment(f, isVideo: isVideo);
      }
    } catch (_) {
      // Молча игнорируем — потерянных данных просто нет/не получить.
    }
  }

  Future<void> _pickAttachment(ImageSource source, {bool isVideo = false}) async {
    // Видео на вебе не поддерживаем: хранение через data-URI раздуло бы базу
    // (большие байты в base64), а плеер на вебе требует blob-URL. Фото на вебе
    // работает полностью (см. _storeAttachment). На Android — всё как было.
    if (kIsWeb && isVideo) {
      _showAttachmentSnack(context.s('today.attachment_web_video_unsupported'));
      return;
    }

    // Локализуем сообщения ДО async-разрывов, чтобы не трогать context после
    // await (use_build_context_synchronously).
    final failedMsg = context.s('today.attachment_failed');
    final cancelledMsg = context.s('today.attachment_cancelled');

    XFile? file;
    try {
      if (isVideo) {
        file = await _imagePicker.pickVideo(source: source);
      } else {
        file = await _imagePicker.pickImage(source: source, imageQuality: 85);
      }
    } catch (e) {
      // Picker бросил (нет разрешения, занят и т.п.) — раньше это было «тихо».
      debugPrint('Attachment pick failed: $e');
      _showAttachmentSnack(failedMsg);
      return;
    }

    // null = пользователь отменил выбор ИЛИ Android потерял результат
    // (Activity пересоздана). Сообщаем «отменено», но не как ошибку.
    if (file == null) {
      _showAttachmentSnack(cancelledMsg);
      return;
    }

    try {
      await _storeAttachment(file, isVideo: isVideo);
    } catch (e) {
      debugPrint('Attachment store failed: $e');
      _showAttachmentSnack(failedMsg);
      return;
    }
    if (mounted) _loadAttachments();
  }

  /// Сохраняет выбранное вложение и пишет строку под текущим _attachmentItemId
  /// (реальный id или '__pending__'). Колонка localPath переиспользуется:
  ///   • Android: копируем файл в каталог приложения, localPath = реальный путь.
  ///   • Web: File/path_provider недоступны, поэтому читаем байты (работает в
  ///     вебе) и кодируем как data-URI base64 в localPath. Превью затем рисуется
  ///     через Image.memory из этой строки (см. _attachmentImageProvider).
  Future<void> _storeAttachment(XFile file, {required bool isVideo}) async {
    final String localPath;
    if (kIsWeb) {
      // dart:io File недоступен — берём байты напрямую из XFile и кодируем
      // в data-URI. На вебе сюда попадают только фото (видео отсечено выше).
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? (isVideo ? 'video/mp4' : 'image/jpeg');
      localPath = 'data:$mime;base64,${base64Encode(bytes)}';
    } else {
      // Копируем в директорию приложения для надёжного хранения.
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(file.path).isEmpty
          ? (isVideo ? '.mp4' : '.jpg')
          : p.extension(file.path);
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$ext';
      final dest = File(p.join(dir.path, 'attachments', fileName));
      await dest.parent.create(recursive: true);
      await File(file.path).copy(dest.path);
      localPath = dest.path;
    }

    final dao = ref.read(itemAttachmentsDaoProvider);
    // Новая задача → '__pending__' (перепривяжем в _save); редактирование →
    // реальный id.
    await dao.addAttachment(ItemAttachmentsTableCompanion(
      id: Value(uuidV4()),
      itemId: Value(_attachmentItemId),
      localPath: Value(localPath),
      type: Value(isVideo ? 'video' : 'photo'),
    ));
  }

  /// Короткий SnackBar по поводу вложения (если виджет ещё в дереве).
  void _showAttachmentSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _viewAttachment(ItemAttachmentsTableData a) {
    viewAttachmentFullscreen(
      context,
      a,
      onUnsupportedVideo: () => _showAttachmentSnack(
        context.s('today.attachment_web_video_unsupported'),
      ),
    );
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
    // Строим заголовок для сохранения: чистый заголовок (без NL-фраз) + #теги в конце.
    // В Drift хранится «чистый заголовок #tag1 #tag2» — обратная совместимость и
    // полнотекстовый поиск; колонка tags хранит их же как comma-joined (schemaVersion 18).
    final storedTitle = buildStoredTitle(_cleanedTitle, _tags);
    // Если нет ни текста, ни тегов — сохраняем плейсхолдер вместо отказа:
    // текст из контекста (локализованный) пишется напрямую в БД, чтобы списки,
    // синк и виджет видели осмысленное имя. Если есть хотя бы теги —
    // buildStoredTitle уже вернул непустую строку (#tag1 …).
    final title = storedTitle.trim().isEmpty
        ? context.s('today.untitled_default')
        : storedTitle;

    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    // main-задачи всегда защищены от автопереноса
    final isProtected = _priority == 'main';
    // Место/локация: пустая строка → null (локальное поле, не синкается).
    final locationText = _locationController.text.trim();
    final location = locationText.isEmpty ? null : locationText;
    // Теги: comma-joined строка для поиска (локальное поле, не синкается).
    // null если нет тегов, иначе «shopping,urgent» (нижний регистр для поиска).
    final tagsValue = _tags.isEmpty
        ? null
        : _tags.map((t) => t.toLowerCase()).join(',');

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
        // materializeOccurrence не принимает reminder/location/tags/moduleLink — проставляем
        // отдельно (все — локальные поля, не синкаются).
        await dao.updateItem(
          concreteId,
          ItemsTableCompanion(
            reminderMinutesBefore: Value(_reminderMinutesBefore),
            location: Value(location),
            tags: Value(tagsValue), // локальное поле — не попадает в синк
            moduleLink: Value(inferModuleLink(_cleanedTitle, type: _type)), // автоматически — не попадает в синк
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
          moduleLink: Value(inferModuleLink(_cleanedTitle, type: _type)), // автоматически — не попадает в синк
          color: Value(_color), // локальное поле — не попадает в синк
          location: Value(location), // локальное поле — не попадает в синк
          tags: Value(tagsValue), // локальное поле — не попадает в синк
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
          moduleLink: Value(inferModuleLink(_cleanedTitle, type: _type)), // автоматически — не попадает в синк
          color: Value(_color), // локальное поле — не попадает в синк
          location: Value(location), // локальное поле — не попадает в синк
          tags: Value(tagsValue), // локальное поле — не попадает в синк
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _persistSubtasks(newId);
      // Перепривязываем вложения, добавленные до сохранения (лежали под
      // '__pending__'), к реальному id новой задачи — иначе они «пропадали»
      // (оставались осиротевшими и не показывались на карточке задачи).
      await ref
          .read(itemAttachmentsDaoProvider)
          .reassignItemId(_pendingAttachmentItemId, newId);
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
            location: Value(existing.location),
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
            // Заголовок + видимый крестик закрытия (не только кнопка «назад»).
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing
                        ? context.s('today.edit_task')
                        : context.s('today.new_task'),
                    style: textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: PhosphorIcon(
                    PhosphorIcons.x(PhosphorIconsStyle.regular),
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 8),

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
            // Теги-чипы: показываются когда есть хотя бы один тег.
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              _TagChipsRow(
                tags: _tags,
                onRemove: (tag) => setState(() => _tags.remove(tag)),
              ),
            ],
            // Подсказки-теги (B7): ряд часто-используемых тегов, не выбранных
            // ещё, с фильтрацией по частичному #-префиксу из заголовка.
            Builder(builder: (context) {
              final suggestions = _tagSuggestions;
              if (suggestions.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _TagSuggestionsRow(
                  suggestions: suggestions,
                  onTap: (tag) => setState(() {
                    if (!_tags.contains(tag)) _tags.add(tag);
                  }),
                  semanticLabel: context.s('today.suggested_tags'),
                ),
              );
            }),
            const SizedBox(height: 12),

            // 2. Быстрый выбор — шаблоны (l10n) + недавние задачи, один ряд.
            _QuickPickRow(
              recentTitles: _recentTitles,
              onSelectTemplate: (title, type, moduleLink) => setState(() {
                _titleController.text = title;
                _type = _normalizeType(type);
                // Шаблон явно задаёт тип → NL не перетирает его.
                // moduleLink теперь определяется автоматически из заголовка при сохранении.
                _userPickedType = true;
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
                  // success-цвет для подсказки «фокус» — позитивное состояние
                  final ext = Theme.of(context).extension<FocusThemeExtension>();
                  final hintColor = ext?.success ?? colorScheme.primary;
                  return Row(
                    children: [
                      PhosphorIcon(
                        PhosphorIcons.shield(PhosphorIconsStyle.fill),
                        size: 14,
                        color: hintColor,
                      ),
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
            const SizedBox(height: 12),

            // 4b. «Main»-тогл с иконкой щита (§4.4 REDESIGN-KANAME.md).
            // Показывается как отдельная заметная строка, а не просто чип.
            _MainToggle(
              isMain: _priority == 'main',
              canSelect: _mainCount < _maxMainPerDay || _priority == 'main',
              onChanged: (val) => _onPriorityTap(val ? 'main' : 'medium'),
            ),

            // 4c. Категория-точка (первый тег) — только когда категории включены.
            if (_tags.isNotEmpty)
              Consumer(
                builder: (context, ref, _) {
                  final catEnabled = ref.watch(categoriesEnabledProvider);
                  if (!catEnabled) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        CategoryDot(tag: _tags.first, size: 10),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${context.s('today.category_dot_label')}: ${_tags.first}',
                            style: textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .extension<FocusThemeExtension>()
                                  ?.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

            // 6. Начало — шагово-инкрементный степпер (§4.3 REDESIGN-KANAME.md).
            // Шаг ±15 мин; тап по значению времени открывает clock-диалог для точной правки.
            Text(context.s('today.start_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            _TimeStepper(
              value: _scheduledAt,
              onChanged: (dt) => setState(() {
                _scheduledAt = dt;
                _userPickedDateTime = true;
                _nlDetectedDateTime = null;
              }),
              onTapValue: _pickTime,
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
              // Один горизонтально прокручиваемый ряд чипов частоты (не
              // переносится) — тот же паттерн, что у длительности/напоминания.
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(context.s('addtask.repeat_none')),
                      selected: _repeatFreq == null,
                      onSelected: (_) => setState(() {
                        _repeatFreq = null;
                        _userPickedRepeat = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(context.s('addtask.repeat_daily')),
                      selected: _repeatFreq == RecurFreq.daily,
                      onSelected: (_) => setState(() {
                        _repeatFreq = RecurFreq.daily;
                        _userPickedRepeat = true;
                      }),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(context.s('addtask.repeat_weekly')),
                      selected: _repeatFreq == RecurFreq.weekly,
                      onSelected: (_) => setState(() {
                        _repeatFreq = RecurFreq.weekly;
                        _userPickedRepeat = true;
                      }),
                    ),
                    const SizedBox(width: 8),
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

            // Место/локация (как в Google Calendar) — свободный текст.
            // Локальное поле, НЕ участвует в синке и NL-парсере названия.
            Text(context.s('today.location_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.s('today.location_hint'),
                prefixIcon: const Icon(Icons.place_outlined),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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

            // 10. Цвет-метка задачи — палитра пресетов + «нет цвета».
            Text(context.s('today.color_label'), style: textTheme.labelMedium),
            const SizedBox(height: 8),
            _ColorPicker(
              value: _color,
              onChanged: (v) => setState(() => _color = v),
            ),
            const SizedBox(height: 16),

            // 11. Вложения (фото / видео): подпись + 3 способа добавления
            // (камера / галерея / видео) + сетка миниатюр-превью.
            Text(context.s('today.attachments_label'),
                style: textTheme.labelMedium),
            const SizedBox(height: 8),
            // Кнопки добавления — три явных способа, иконка + подпись.
            Row(
              children: [
                // Камера: только на мобильных. На вебе image_picker не умеет
                // камеру и открывает файловый проводник — кнопка вводит в
                // заблуждение, поэтому скрываем её (остаются «Галерея»/«Видео»).
                if (!kIsWeb) ...[
                  Expanded(
                    child: _AttachAddButton(
                      icon: Icons.photo_camera_outlined,
                      label: context.s('today.attach_camera'),
                      onTap: () => _pickAttachment(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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
                    AttachmentThumb(
                      attachment: a,
                      onTap: () => _viewAttachment(a),
                      onDelete: () => _deleteAttachment(a),
                    ),
                ],
              ),
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
// Ряд чипов тегов под полем заголовка.
// Каждый тег — InputChip с крестиком удаления.
// ---------------------------------------------------------------------------

class _TagChipsRow extends StatelessWidget {
  const _TagChipsRow({required this.tags, required this.onRemove});

  final List<String> tags;
  final void Function(String tag) onRemove;

  @override
  Widget build(BuildContext context) {
    final removeTooltip = context.s('today.tag_remove_tooltip');
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tag in tags)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: InputChip(
                label: Text('#$tag'),
                onDeleted: () => onRemove(tag),
                deleteButtonTooltipMessage: removeTooltip,
                // Компактный размер — MaterialTapTargetSize.shrinkWrap
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Ряд подсказок-тегов (автодополнение, B7).
// Показывает часто-используемые теги из истории, не выбранные ещё.
// Стиль: surface-фон + hairline-border, accent при тапе (добавляет тег).
// Overflow-safe: горизонтальный SingleChildScrollView.
// ---------------------------------------------------------------------------

class _TagSuggestionsRow extends StatelessWidget {
  const _TagSuggestionsRow({
    required this.suggestions,
    required this.onTap,
    required this.semanticLabel,
  });

  final List<String> suggestions;
  final void Function(String tag) onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // surface-фон + тонкая рамка hairline (Kaname-стиль)
    final bgColor = colorScheme.surface;
    final borderColor =
        ext?.border ?? colorScheme.outlineVariant.withAlpha(120);
    final textColor =
        ext?.textMuted ?? colorScheme.onSurface.withAlpha(180);
    final accentColor = colorScheme.primary;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: semanticLabel,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Иконка-подсказка (hash / tag): намекает на назначение ряда.
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: PhosphorIcon(
                PhosphorIcons.hash(PhosphorIconsStyle.regular),
                size: 14,
                color: textColor,
              ),
            ),
            for (final tag in suggestions) ...[
              GestureDetector(
                onTap: () => onTap(tag),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Text(
                    '#$tag',
                    style: textTheme.bodySmall?.copyWith(color: accentColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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

// ---------------------------------------------------------------------------
// _TimeStepper — шагово-инкрементный выбор времени (§4.3 REDESIGN-KANAME.md).
//
// Структура: [−] [HH:MM] [+]
//   • [−] / [+] — изменяют время на ±15 минут (шаг 15).
//   • [HH:MM] — тап открывает clock-диалог (onTapValue).
// Предотвращает overflow: 320dp + textScale 1.5.
// ---------------------------------------------------------------------------

class _TimeStepper extends StatelessWidget {
  const _TimeStepper({
    required this.value,
    required this.onChanged,
    required this.onTapValue,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  /// Вызывается при тапе на текст времени — обычно открывает showTimePicker.
  final VoidCallback onTapValue;

  static const _stepMinutes = 15;

  DateTime _step(int delta) {
    final next = value.add(Duration(minutes: _stepMinutes * delta));
    // Оставляем в границах [00:00..23:45] того же дня.
    return DateTime(
      value.year,
      value.month,
      value.day,
      next.hour,
      next.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final scheme = theme.colorScheme;
    final timeText = DateFormat.Hm().format(value);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: ext?.border ?? scheme.outline,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Кнопка «минус»
          _StepButton(
            icon: PhosphorIcons.minus(PhosphorIconsStyle.regular),
            onPressed: () => onChanged(_step(-1)),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(11),
              bottomLeft: Radius.circular(11),
            ),
          ),
          // Значение времени — тап открывает clock-диалог
          Expanded(
            child: GestureDetector(
              onTap: onTapValue,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                color: Colors.transparent,
                child: Text(
                  timeText,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          // Кнопка «плюс»
          _StepButton(
            icon: PhosphorIcons.plus(PhosphorIconsStyle.regular),
            onPressed: () => onChanged(_step(1)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(11),
              bottomRight: Radius.circular(11),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onPressed,
    required this.borderRadius,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();

    return Material(
      color: ext?.surfaceElevated ?? theme.colorScheme.surface,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: borderRadius,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: PhosphorIcon(icon, size: 20, color: ext?.textSecondary),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MainToggle — выделенный тогл «Главная задача» со щитом (§4.4 REDESIGN-KANAME.md).
//
// Показывается между строкой приоритетов и секцией даты.
// isMain: текущее состояние (priority == 'main').
// canSelect: false когда лимит 3 already reached и это не main — тогл disabled.
// ---------------------------------------------------------------------------

class _MainToggle extends StatelessWidget {
  const _MainToggle({
    required this.isMain,
    required this.canSelect,
    required this.onChanged,
  });

  final bool isMain;
  final bool canSelect;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final scheme = theme.colorScheme;

    final activeColor = scheme.primary;
    final inactiveColor = ext?.textMuted ?? scheme.onSurface.withValues(alpha: 0.5);

    return GestureDetector(
      onTap: canSelect ? () => onChanged(!isMain) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMain ? ext?.accentTint : null,
          border: Border.all(
            color: isMain
                ? activeColor.withValues(alpha: 0.4)
                : ext?.border ?? scheme.outline,
            width: isMain ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            PhosphorIcon(
              isMain
                  ? PhosphorIcons.shield(PhosphorIconsStyle.fill)
                  : PhosphorIcons.shield(PhosphorIconsStyle.regular),
              size: 18,
              color: isMain ? activeColor : inactiveColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.s('today.main_toggle_label'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMain ? ext?.accentInk ?? activeColor : null,
                  fontWeight: isMain ? FontWeight.w500 : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Switch.adaptive(
              value: isMain,
              onChanged: canSelect ? onChanged : null,
              activeColor: activeColor,
            ),
          ],
        ),
      ),
    );
  }
}
