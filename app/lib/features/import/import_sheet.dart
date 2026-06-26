// Импорт расписания вставкой текста (MVP-вариант "paste"/"template").
// Пользователь вставляет строки вида "HH:MM Заголовок" (по одной на строку),
// выбирает день — задачи создаются локально в Drift.
// Фото/голос-импорт требуют AI и относятся к Phase 1.
// ICS + Todoist CSV — файловый импорт без AI (2026-06-17).
//
// Дизайн-система (03-components.md, 02-type-space.md):
// — 24dp горизонтальный отступ (02-type-space.md §4.1 bottom sheet padding)
// — FilledButton = единственный primary action (Import)
// — OutlinedButton = вторичные действия (Photo, ICS, Todoist)
// — KaiLoader(label:…) вместо встроенного CircularProgressIndicator
// — typography roles: headlineSmall (заголовок), bodySmall (hint), labelLarge (кнопки)
// — цвета через ext (FocusThemeExtension)

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/id.dart';
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import 'ics_parser.dart';
import 'todoist_csv_parser.dart';

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

class ImportSheet extends ConsumerStatefulWidget {
  const ImportSheet({required this.day, super.key});

  final DateTime day;

  @override
  ConsumerState<ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends ConsumerState<ImportSheet> {
  final _controller = TextEditingController();
  late DateTime _day;
  bool _recognizing = false;
  bool _importingIcs = false;
  bool _importingTodoist = false;

  @override
  void initState() {
    super.initState();
    _day = widget.day;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
    if (picked != null) setState(() => _day = picked);
  }

  Future<void> _import() async {
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

  /// Phase 1 (premium): распознать расписание с фото через бэкенд-AI.
  /// Результат подставляется в текстовое поле — пользователь проверяет и жмёт Import.
  Future<void> _importFromPhoto() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.s('import.photo_premium_snack')),
        ),
      );
      return;
    }

    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final mediaType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    setState(() => _recognizing = true);
    try {
      final items =
          await ref.read(apiClientProvider).scheduleImportFromPhoto(
                imageBase64: base64Encode(bytes),
                mediaType: mediaType,
                targetDate: DateFormat('yyyy-MM-dd').format(_day),
              );
      // Превращаем { title, scheduled_at } в строки "HH:MM Title" для проверки
      final lines = items.map((dynamic e) {
        final map = e as Map<String, dynamic>;
        final dt = DateTime.tryParse(map['scheduled_at'] as String? ?? '')
            ?.toLocal();
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

  /// Импорт из ICS-файла (Google Calendar / Apple Calendar / Outlook).
  /// Читает файл, парсит события, фильтрует по дате _day,
  /// подставляет строки "HH:MM Title" в текстовое поле для проверки.
  Future<void> _importFromIcs() async {
    setState(() => _importingIcs = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      final path = file.path;

      String content;
      if (bytes != null) {
        content = utf8.decode(bytes, allowMalformed: true);
      } else if (path != null) {
        // На десктопе/мобайле path доступен
        final data = await FilePicker.platform.pickFiles(
          type: FileType.any,
          withData: true,
        );
        if (data == null || data.files.isEmpty || data.files.first.bytes == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.s('import.err_no_file'))),
            );
          }
          return;
        }
        content = utf8.decode(data.files.first.bytes!, allowMalformed: true);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('import.err_no_file'))),
          );
        }
        return;
      }

      final events = IcsParser.parse(content);

      // Фильтруем по дате _day
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

      // Формируем строки "HH:MM Title"
      final lines = dayEvents.map((e) {
        final dt = e.dtStart!;
        final hh = dt.hour.toString().padLeft(2, '0');
        final mm = dt.minute.toString().padLeft(2, '0');
        return '$hh:$mm ${e.summary}';
      }).join('\n');

      _controller.text =
          _controller.text.trim().isEmpty ? lines : '${_controller.text}\n$lines';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .s('import.ics_found')
                .replaceAll('{n}', '${dayEvents.length}')
                .replaceAll('{date}', DateFormat.yMMMd().format(_day)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _importingIcs = false);
    }
  }

  /// Импорт из Todoist CSV.
  /// Задачи создаются напрямую в Drift (без текстового поля),
  /// приоритет маппится из Todoist → Kaizen, дата из CSV или _day 09:00.
  Future<void> _importFromTodoist() async {
    setState(() => _importingTodoist = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('import.err_no_file'))),
          );
        }
        return;
      }

      final content = utf8.decode(file.bytes!, allowMalformed: true);
      final tasks = TodoistCsvParser.parse(content);

      if (tasks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.s('import.err_no_todoist_tasks'))),
          );
        }
        return;
      }

      final dao = ref.read(itemsDaoProvider);
      final now = DateTime.now();

      for (final task in tasks) {
        // Парсим дату из задачи или используем _day
        final parsedDate = TodoistCsvParser.parseDate(task.date);
        final scheduled = parsedDate ??
            DateTime(_day.year, _day.month, _day.day, 9, 0);

        final priority = TodoistCsvParser.mapPriority(task.priority);

        await dao.insertItem(
          ItemsTableCompanion(
            id: Value(uuidV4()),
            userId: const Value('local'),
            title: Value(task.content),
            type: const Value('task'),
            priority: Value(priority),
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
                  .replaceAll('{n}', '${tasks.length}'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _importingTodoist = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Флаг: идёт ли хоть какая-то загрузка (для блокировки кнопки Import)
    final anyLoading = _recognizing || _importingIcs || _importingTodoist;

    return SafeArea(
      child: Padding(
        // 24dp H, 20dp V — bottom sheet inner padding (02-type-space.md §4.1)
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок + крестик закрытия (видимый аффорданс для шита)
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.s('import.title'),
                    style: textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: context.s('btn.close'),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Подсказка: bodySmall (textMuted)
            Text(
              context.s('import.paste_hint_body'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 16),
            // Заметный выбор дня: явно показываем, на какую дату ляжет расписание.
            // Full-width + label с датой, чтобы пользователь не пропустил выбор дня.
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _pickDay,
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 18),
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
                    const Icon(Icons.edit_calendar_outlined, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Текстовое поле расписания
            TextField(
              controller: _controller,
              maxLines: 8,
              minLines: 4,
              decoration: InputDecoration(
                hintText: context.s('import.text_hint'),
              ),
            ),
            const SizedBox(height: 16),

            // --- Вторичные источники импорта: OutlinedButton (03-components.md §5) ---
            // Каждая кнопка — полная ширина, состояние загрузки = KaiLoader вместо
            // встроенного CircularProgressIndicator (SPEC: KaiLoader = drop-in замена)

            // Импорт из фото (AI, Premium)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                // KaiLoader показывается внутри иконки при загрузке
                icon: _recognizing
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: KaiLoader(
                          size: 20,
                          label: null,
                        ),
                      )
                    : const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(context.s('import.btn_from_photo')),
                onPressed: _recognizing ? null : _importFromPhoto,
              ),
            ),
            const SizedBox(height: 8),

            // Импорт из ICS-файла (Google / Apple / Outlook)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _importingIcs
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: KaiLoader(
                          size: 20,
                          label: null,
                        ),
                      )
                    : const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(context.s('import.btn_from_ics')),
                onPressed: _importingIcs ? null : _importFromIcs,
              ),
            ),
            const SizedBox(height: 8),

            // Импорт из Todoist CSV
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: _importingTodoist
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: KaiLoader(
                          size: 20,
                          label: null,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(context.s('import.btn_from_todoist')),
                onPressed: _importingTodoist ? null : _importFromTodoist,
              ),
            ),
            const SizedBox(height: 16),

            // --- Primary CTA: FilledButton (единственная accent-кнопка) ---
            // (03-components.md §2: FilledButton = единственный primary action)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: anyLoading ? null : _import,
                child: Text(context.s('import.btn_import')),
              ),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
