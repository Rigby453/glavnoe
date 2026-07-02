// Импорт расписания — sheet с выбором источника (§4.3 Kaname redesign).
//
// Источники (source chips):
//   text     — вставка строк «HH:MM Заголовок»
//   photoAi  — фото-AI (Premium), результат подставляется в текстовое поле
//   ics      — .ics файл (Google / Apple / Outlook), структурированный предпросмотр
//   csv      — Todoist CSV backup, структурированный предпросмотр
//   cloneWeek — клонировать прошлую неделю (заглушка, coming soon)
//
// ICS и CSV показывают карточки вместо текстовых строк «HH:MM»:
//   ICS  → IcsEvent (время, длительность, весь-день, повтор).
//   CSV  → TodoistTask (заголовок, приоритет, дата).
// Данные больше не теряются при конвертации в одну строку.
//
// Дизайн: §4.3 — AppSheetContent (handle · title · X) + Phosphor icons.
// Overflow-safe: Expanded/ellipsis везде; 320px / textScale 1.5 / keyboard OK.

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import 'ics_parser.dart';
import 'todoist_csv_parser.dart';

// ---------------------------------------------------------------------------
// Публичный API
// ---------------------------------------------------------------------------

/// Строка расписания: "9:00 Math lecture" или "09:30 Gym"
final _lineRegex = RegExp(r'^\s*(\d{1,2}):(\d{2})\s+(.+?)\s*$');

class _ParsedLine {
  const _ParsedLine(this.hour, this.minute, this.title);
  final int hour;
  final int minute;
  final String title;
}

Future<void> showImportSheet(
  BuildContext context, {
  required DateTime day,
}) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ImportSheet(day: day),
    ),
  );
}

// ---------------------------------------------------------------------------
// Enum источника импорта
// ---------------------------------------------------------------------------

enum _ImportSource { text, photoAi, ics, csv, cloneWeek }

// ---------------------------------------------------------------------------
// ImportSheet widget
// ---------------------------------------------------------------------------

class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({required this.day, super.key});

  final DateTime day;

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  final _controller = TextEditingController();
  late DateTime _day;

  _ImportSource _source = _ImportSource.text;

  bool _recognizing = false;   // фото-AI в процессе
  bool _pickingIcs = false;    // выбор ICS файла
  bool _pickingCsv = false;    // выбор CSV файла

  // Структурированные предпросмотры (замена текстовых строк «HH:MM»)
  List<IcsEvent> _icsEvents = [];
  List<TodoistTask> _csvTasks = [];

  bool get _anyLoading => _recognizing || _pickingIcs || _pickingCsv;

  bool get _canImport {
    if (_anyLoading) return false;
    switch (_source) {
      case _ImportSource.text:
      case _ImportSource.photoAi:
        return _controller.text.trim().isNotEmpty;
      case _ImportSource.ics:
        return _icsEvents.isNotEmpty;
      case _ImportSource.csv:
        return _csvTasks.isNotEmpty;
      case _ImportSource.cloneWeek:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _day = widget.day;
    _controller.addListener(() => setState(() {})); // обновляем _canImport
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Бизнес-логика (сохранена)
  // ---------------------------------------------------------------------------

  List<_ParsedLine> _parse(String text) {
    final result = <_ParsedLine>[];
    for (final raw in text.split('\n')) {
      final m = _lineRegex.firstMatch(raw);
      if (m == null) continue;
      final hour = int.parse(m.group(1)!);
      final minute = int.parse(m.group(2)!);
      if (hour > 23 || minute > 59) continue;
      result.add(_ParsedLine(hour, minute, m.group(3)!));
    }
    return result;
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _day = picked;
        // ICS-события отфильтрованы по дню → при смене дня нужно выбрать заново
        _icsEvents = [];
      });
    }
  }

  /// Импорт из текстового поля («HH:MM Заголовок», одна строка на событие).
  Future<void> _importFromText() async {
    final parsed = _parse(_controller.text);
    if (parsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('import.err_no_lines'))),
      );
      return;
    }

    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    for (final line in parsed) {
      await dao.insertItem(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: const Value('local'),
          title: Value(line.title),
          type: const Value('task'),
          priority: const Value('medium'),
          status: const Value('pending'),
          scheduledAt: Value(
            DateTime(_day.year, _day.month, _day.day, line.hour, line.minute),
          ),
          durationMinutes: const Value(30),
          isProtected: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('import.success_tasks').replaceAll('{n}', '${parsed.length}'),
          ),
        ),
      );
    }
  }

  /// Phase 1 (Premium): распознать расписание с фото через бэкенд-AI.
  Future<void> _importFromPhoto() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.s('import.photo_premium_snack'))),
      );
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final mediaType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    setState(() => _recognizing = true);
    try {
      final items = await ref.read(apiClientProvider).scheduleImportFromPhoto(
            imageBase64: base64Encode(bytes),
            mediaType: mediaType,
            targetDate: DateFormat('yyyy-MM-dd').format(_day),
          );
      // Превращаем { title, scheduled_at } в строки «HH:MM Заголовок» для проверки
      final lines = items.map((dynamic e) {
        final map = e as Map<String, dynamic>;
        final dt =
            DateTime.tryParse(map['scheduled_at'] as String? ?? '')?.toLocal();
        final time = dt != null ? DateFormat.Hm().format(dt) : '09:00';
        return '$time ${map['title']}';
      }).join('\n');

      if (!mounted) return;
      _controller.text =
          _controller.text.trim().isEmpty ? lines : '${_controller.text}\n$lines';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .s('import.photo_recognized')
                .replaceAll('{n}', '${items.length}'),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  /// Выбор ICS-файла → парсинг → структурированный предпросмотр.
  Future<void> _pickIcsFile() async {
    setState(() => _pickingIcs = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('import.err_no_file'))),
          );
        }
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final events = IcsParser.parse(content);

      // Фильтруем по дню _day
      final dayEvents = events.where((e) {
        final dt = e.dtStart;
        if (dt == null) return false;
        return dt.year == _day.year &&
            dt.month == _day.month &&
            dt.day == _day.day;
      }).toList();

      if (!mounted) return;

      if (dayEvents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context
                  .s('import.ics_no_events')
                  .replaceAll('{date}', DateFormat.yMMMd().format(_day)),
            ),
          ),
        );
        return;
      }

      setState(() => _icsEvents = dayEvents);
    } finally {
      if (mounted) setState(() => _pickingIcs = false);
    }
  }

  /// Выбор Todoist CSV → парсинг → структурированный предпросмотр.
  Future<void> _pickCsvFile() async {
    setState(() => _pickingCsv = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('import.err_no_file'))),
          );
        }
        return;
      }

      final content = utf8.decode(bytes, allowMalformed: true);
      final tasks = TodoistCsvParser.parse(content);

      if (!mounted) return;

      if (tasks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.s('import.err_no_todoist_tasks'))),
        );
        return;
      }

      setState(() => _csvTasks = tasks);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('import.csv_found').replaceAll('{n}', '${tasks.length}'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _pickingCsv = false);
    }
  }

  /// Импорт структурированных ICS-событий напрямую в Drift (не через текстовое поле).
  /// Сохраняет длительность, recurrenceRule, isAllDay (type = 'event').
  Future<void> _importFromStructuredIcs() async {
    if (_icsEvents.isEmpty) return;
    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    int count = 0;
    for (final event in _icsEvents) {
      if (event.dtStart == null) continue;
      await dao.insertItem(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: const Value('local'),
          title: Value(event.summary),
          type: const Value('event'),
          priority: const Value('medium'),
          status: const Value('pending'),
          scheduledAt: Value(event.dtStart!),
          durationMinutes: Value(event.durationMinutes),
          isProtected: const Value(false),
          recurrenceRule: Value(event.recurrenceRule),
          location: Value(event.location),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      count++;
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s('import.success_tasks').replaceAll('{n}', '$count'),
          ),
        ),
      );
    }
  }

  /// Импорт Todoist-задач из структурированного предпросмотра напрямую в Drift.
  Future<void> _importFromStructuredCsv() async {
    if (_csvTasks.isEmpty) return;
    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    for (final task in _csvTasks) {
      final parsedDate = TodoistCsvParser.parseDate(task.date);
      final scheduled =
          parsedDate ?? DateTime(_day.year, _day.month, _day.day, 9, 0);
      await dao.insertItem(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: const Value('local'),
          title: Value(task.content),
          type: const Value('task'),
          priority: Value(TodoistCsvParser.mapPriority(task.priority)),
          status: const Value('pending'),
          scheduledAt: Value(scheduled),
          durationMinutes: const Value(60),
          isProtected: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .s('import.success_todoist')
                .replaceAll('{n}', '${_csvTasks.length}'),
          ),
        ),
      );
    }
  }

  /// Диспетчер кнопки Import: вызывает нужный метод в зависимости от источника.
  Future<void> _doImport() async {
    switch (_source) {
      case _ImportSource.text:
      case _ImportSource.photoAi:
        await _importFromText();
      case _ImportSource.ics:
        await _importFromStructuredIcs();
      case _ImportSource.csv:
        await _importFromStructuredCsv();
      case _ImportSource.cloneWeek:
        break; // заглушка — кнопка недоступна
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<FocusThemeExtension>()!;

    // Ограничиваем высоту прокручиваемой области (55% экрана), чтобы sheet
    // не выходил за пределы экрана на маленьких устройствах (320×568).
    final maxBodyH = MediaQuery.sizeOf(context).height * 0.55;

    return AppSheetContent(
      title: context.s('import.title'),
      primaryButton: FilledButton(
        onPressed: _canImport ? _doImport : null,
        child: Text(context.s('import.btn_import')),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxBodyH),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Выбор дня ---
              _buildDateRow(context, ext, cs),
              const SizedBox(height: 16),
              // --- Выбор источника (chips) ---
              _buildSourceChips(context, ext, cs),
              const SizedBox(height: 16),
              // --- Контент выбранного источника ---
              _buildSourceContent(context, ext, cs, theme.textTheme),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Строка выбора дня
  // ---------------------------------------------------------------------------

  Widget _buildDateRow(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme cs,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _pickDay,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        child: Row(
          children: [
            Icon(PhosphorIcons.calendarBlank(), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.s('import.day_label').replaceAll(
                      '{date}',
                      DateFormat.yMMMd().format(_day),
                    ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(PhosphorIcons.pencilSimple(), size: 16),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Chips выбора источника (горизонтальный скролл — no overflow на 320px)
  // ---------------------------------------------------------------------------

  Widget _buildSourceChips(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme cs,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _sourceChip(
            context, ext, cs,
            _ImportSource.text,
            PhosphorIcons.clipboard(),
            context.s('import.source_text'),
          ),
          const SizedBox(width: 8),
          _sourceChip(
            context, ext, cs,
            _ImportSource.photoAi,
            PhosphorIcons.camera(),
            context.s('import.source_photo'),
          ),
          const SizedBox(width: 8),
          _sourceChip(
            context, ext, cs,
            _ImportSource.ics,
            PhosphorIcons.calendarBlank(),
            context.s('import.source_ics'),
          ),
          const SizedBox(width: 8),
          _sourceChip(
            context, ext, cs,
            _ImportSource.csv,
            PhosphorIcons.listChecks(),
            context.s('import.source_csv'),
          ),
          const SizedBox(width: 8),
          _sourceChip(
            context, ext, cs,
            _ImportSource.cloneWeek,
            PhosphorIcons.clockCounterClockwise(),
            context.s('import.source_clone'),
          ),
        ],
      ),
    );
  }

  Widget _sourceChip(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme cs,
    _ImportSource src,
    PhosphorIconData icon,
    String label,
  ) {
    final selected = _source == src;
    final tt = Theme.of(context).textTheme;
    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 15,
          color: selected ? ext.accentInk : ext.textMuted),
      label: Text(
        label,
        style: tt.labelMedium?.copyWith(
          color: selected ? ext.accentInk : ext.textSecondary,
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
      onSelected: (_) => setState(() => _source = src),
      selectedColor: ext.accentTint,
      backgroundColor: Colors.transparent,
      side: selected
          ? BorderSide(color: cs.primary, width: 1.0)
          : BorderSide(color: ext.border, width: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  // ---------------------------------------------------------------------------
  // Контент в зависимости от источника
  // ---------------------------------------------------------------------------

  Widget _buildSourceContent(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme cs,
    TextTheme tt,
  ) {
    switch (_source) {
      case _ImportSource.text:
        return _buildTextContent(context, ext, tt);
      case _ImportSource.photoAi:
        return _buildPhotoContent(context, ext, tt);
      case _ImportSource.ics:
        return _buildIcsContent(context, ext, cs, tt);
      case _ImportSource.csv:
        return _buildCsvContent(context, ext, cs, tt);
      case _ImportSource.cloneWeek:
        return _buildCloneWeekContent(context, ext, tt);
    }
  }

  // --- Текст ---
  Widget _buildTextContent(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme tt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.s('import.paste_hint_body'),
          style: tt.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 8,
          minLines: 4,
          decoration: InputDecoration(
            hintText: context.s('import.text_hint'),
          ),
        ),
      ],
    );
  }

  // --- Фото-AI ---
  Widget _buildPhotoContent(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme tt,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Кнопка выбора фото
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _recognizing
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: KaiLoader(size: 20, label: null),
                  )
                : Icon(PhosphorIcons.camera(), size: 20),
            label: Text(context.s('import.pick_photo_btn')),
            onPressed: _recognizing ? null : _importFromPhoto,
          ),
        ),
        const SizedBox(height: 12),
        // Поле для просмотра/редактирования результата AI
        Text(
          context.s('import.paste_hint_body'),
          style: tt.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLines: 6,
          minLines: 3,
          decoration: InputDecoration(
            hintText: context.s('import.text_hint'),
          ),
        ),
      ],
    );
  }

  // --- ICS (структурированный предпросмотр) ---
  Widget _buildIcsContent(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (_icsEvents.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.s('import.ics_hint'),
            style: tt.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _pickingIcs
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: KaiLoader(size: 20, label: null),
                    )
                  : Icon(PhosphorIcons.uploadSimple(), size: 20),
              label: Text(context.s('import.pick_ics_btn')),
              onPressed: _pickingIcs ? null : _pickIcsFile,
            ),
          ),
        ],
      );
    }

    // Показываем до 5 событий + "+N ещё"
    const maxShown = 5;
    final shown = _icsEvents.take(maxShown).toList();
    final extra = _icsEvents.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка: «N событий» + кнопка «Выбрать снова»
        Row(
          children: [
            Expanded(
              child: Text(
                context
                    .s('import.ics_found')
                    .replaceAll('{n}', '${_icsEvents.length}')
                    .replaceAll('{date}', DateFormat.yMMMd().format(_day)),
                style: tt.labelLarge?.copyWith(color: ext.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _icsEvents = []),
              icon: Icon(PhosphorIcons.arrowsClockwise(), size: 14),
              label: Text(context.s('import.repick')),
              style: TextButton.styleFrom(
                foregroundColor: ext.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                textStyle: tt.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Карточки событий
        for (final event in shown) ...[
          _IcsEventCard(event: event, ext: ext, cs: cs),
          const SizedBox(height: 6),
        ],
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(
              context.s('import.more_events').replaceAll('{n}', '$extra'),
              style: tt.labelSmall?.copyWith(color: ext.textFaint),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // --- CSV (структурированный предпросмотр) ---
  Widget _buildCsvContent(
    BuildContext context,
    FocusThemeExtension ext,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (_csvTasks.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.s('import.csv_hint'),
            style: tt.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _pickingCsv
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: KaiLoader(size: 20, label: null),
                    )
                  : Icon(PhosphorIcons.uploadSimple(), size: 20),
              label: Text(context.s('import.pick_csv_btn')),
              onPressed: _pickingCsv ? null : _pickCsvFile,
            ),
          ),
        ],
      );
    }

    // Показываем до 8 задач + "+N ещё"
    const maxShown = 8;
    final shown = _csvTasks.take(maxShown).toList();
    final extra = _csvTasks.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Шапка: «N задач» + кнопка «Выбрать снова»
        Row(
          children: [
            Expanded(
              child: Text(
                context.s('import.csv_found').replaceAll('{n}', '${_csvTasks.length}'),
                style: tt.labelLarge?.copyWith(color: ext.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _csvTasks = []),
              icon: Icon(PhosphorIcons.arrowsClockwise(), size: 14),
              label: Text(context.s('import.repick')),
              style: TextButton.styleFrom(
                foregroundColor: ext.textMuted,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                textStyle: tt.labelSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Карточки задач
        for (final task in shown) ...[
          _CsvTaskCard(task: task, ext: ext, cs: cs),
          const SizedBox(height: 6),
        ],
        if (extra > 0)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Text(
              context.s('import.more_events').replaceAll('{n}', '$extra'),
              style: tt.labelSmall?.copyWith(color: ext.textFaint),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  // --- Клонировать неделю (заглушка) ---
  Widget _buildCloneWeekContent(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme tt,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            PhosphorIcons.clockCounterClockwise(),
            size: 20,
            color: ext.textFaint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            context.s('import.clone_week_hint'),
            style: tt.bodyMedium?.copyWith(color: ext.textMuted),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

/// Форматирует длительность в минутах в читаемую строку через l10n.
/// < 60 мин → plMinutes; >= 60 → «Xh Ym» или «Xh» (ключи import.duration_fmt_*).
String _fmtDuration(BuildContext context, int minutes) {
  if (minutes < 60) return plMinutes(context, minutes);
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) {
    return context.s('import.duration_fmt_h').replaceAll('{h}', '$h');
  }
  return context.s('import.duration_fmt_hm')
      .replaceAll('{h}', '$h')
      .replaceAll('{m}', '$m');
}

// ---------------------------------------------------------------------------
// _IcsEventCard — карточка ICS-события
// ---------------------------------------------------------------------------

class _IcsEventCard extends StatelessWidget {
  const _IcsEventCard({
    required this.event,
    required this.ext,
    required this.cs,
  });

  final IcsEvent event;
  final FocusThemeExtension ext;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final dtStart = event.dtStart;

    final timeStr = dtStart != null && !event.isAllDay
        ? DateFormat.Hm().format(dtStart)
        : null;
    final durStr = _fmtDuration(context, event.durationMinutes);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконка события
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(PhosphorIcons.calendar(), size: 20, color: cs.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок (до 2 строк)
                Text(
                  event.summary,
                  style: tt.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                // Метаданные (Wrap — overflow-safe на 320px)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (event.isAllDay)
                      _MetaChip(
                        label: context.s('import.event_all_day'),
                        ext: ext,
                      )
                    else ...[
                      if (timeStr != null) _MetaChip(label: timeStr, ext: ext),
                      _MetaChip(label: durStr, ext: ext),
                    ],
                    if (event.recurrenceRule != null)
                      _MetaChip(
                        label: context.s('import.event_repeats'),
                        icon: PhosphorIcons.repeat(),
                        ext: ext,
                      ),
                    if (event.location != null && event.location!.isNotEmpty)
                      _MetaChip(
                        label: event.location!,
                        icon: PhosphorIcons.mapPin(),
                        ext: ext,
                        maxWidth: 160,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CsvTaskCard — карточка задачи из Todoist CSV
// ---------------------------------------------------------------------------

class _CsvTaskCard extends StatelessWidget {
  const _CsvTaskCard({
    required this.task,
    required this.ext,
    required this.cs,
  });

  final TodoistTask task;
  final FocusThemeExtension ext;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final priority = TodoistCsvParser.mapPriority(task.priority);

    // Цвет и иконка в зависимости от приоритета
    final Color iconColor;
    final PhosphorIconData iconData;
    if (priority == 'main') {
      iconColor = ext.ember;
      iconData = PhosphorIcons.shield(PhosphorIconsStyle.fill);
    } else {
      iconColor = ext.textFaint;
      iconData = PhosphorIcons.checkCircle();
    }

    final String priorityKey;
    if (priority == 'main') {
      priorityKey = 'import.priority_main';
    } else if (priority == 'medium') {
      priorityKey = 'import.priority_medium';
    } else {
      priorityKey = 'import.priority_low';
    }

    final dateStr = (task.date != null && task.date!.isNotEmpty)
        ? task.date!
        : context.s('import.no_date');

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ext.border, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконка приоритета
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Заголовок задачи (до 2 строк)
                Text(
                  task.content,
                  style: tt.titleSmall,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 4),
                // Метаданные (Wrap — overflow-safe)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MetaChip(label: dateStr, ext: ext),
                    _MetaChip(label: context.s(priorityKey), ext: ext),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MetaChip — маленький бейдж для метаданных (время / длительность / повтор)
// ---------------------------------------------------------------------------

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, required this.ext, this.icon, this.maxWidth});

  final String label;
  final FocusThemeExtension ext;
  final PhosphorIconData? icon;

  /// Ограничение ширины текста для длинных значений (например LOCATION) —
  /// иначе строка может не влезть в один run внутри Wrap на 320px.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final labelStyle = tt.labelSmall?.copyWith(color: ext.textMuted);
    final Widget labelWidget = maxWidth != null
        ? ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: Text(
              label,
              style: labelStyle,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          )
        : Text(label, style: labelStyle);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ext.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: ext.textMuted),
            const SizedBox(width: 3),
          ],
          labelWidget,
        ],
      ),
    );
  }
}
