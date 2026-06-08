// FL-TODAY-05: Нижний лист добавления/редактирования задачи.
// - Поле заголовка (autofocus), чипы типа и приоритета, выбор даты и времени.
// - Лимит: максимум 3 main-задачи в день (enforced при выборе приоритета main).
// - Сохранение пишет в Drift через ItemsDao (офлайн-первый подход).
//
// Локальное состояние формы (контроллер, выбранные чипы) — эфемерное,
// поэтому здесь используется StatefulWidget; бизнес-состояние идёт через Riverpod.

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/database.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/id.dart';

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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => Padding(
      // Поднимаем лист над клавиатурой
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AddTaskSheet(day: day, existing: existing),
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
  late String _type;
  late String _priority;
  late DateTime _scheduledAt;
  late int _durationMinutes;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _type = existing?.type ?? 'task';
    _priority = existing?.priority ?? 'medium';
    _scheduledAt = existing?.scheduledAt ?? _defaultScheduledAt();
    _durationMinutes = existing?.durationMinutes ?? 30;
  }

  /// Сегодня, следующий круглый час
  DateTime _defaultScheduledAt() {
    final now = DateTime.now();
    final nextHour = now.hour + 1;
    return DateTime(widget.day.year, widget.day.month, widget.day.day,
        nextHour.clamp(0, 23), 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _onPriorityTap(String priority) async {
    // Лимит main: при выборе main проверяем, что их меньше 3 (кроме уже-main при редактировании)
    if (priority == 'main' && _priority != 'main') {
      final dao = ref.read(itemsDaoProvider);
      final mainCount = await dao.countMainItems(widget.day);
      final alreadyCountsSelf = _isEditing && widget.existing!.priority == 'main';
      final effective = alreadyCountsSelf ? mainCount - 1 : mainCount;
      if (effective >= _maxMainPerDay) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Max 3 main tasks')),
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
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required')),
      );
      return;
    }

    final dao = ref.read(itemsDaoProvider);
    final now = DateTime.now();
    // main-задачи всегда защищены от автопереноса
    final isProtected = _priority == 'main';

    if (_isEditing) {
      await dao.updateItem(
        widget.existing!.id,
        ItemsTableCompanion(
          title: Value(title),
          type: Value(_type),
          priority: Value(_priority),
          scheduledAt: Value(_scheduledAt),
          durationMinutes: Value(_durationMinutes),
          isProtected: Value(isProtected),
          updatedAt: Value(now),
        ),
      );
    } else {
      await dao.insertItem(
        ItemsTableCompanion(
          id: Value(uuidV4()),
          userId: const Value('local'), // заменится на реальный userId на шаге 8 (sync)
          title: Value(title),
          type: Value(_type),
          priority: Value(_priority),
          status: const Value('pending'),
          scheduledAt: Value(_scheduledAt),
          durationMinutes: Value(_durationMinutes),
          isProtected: Value(isProtected),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16), // spacing.md
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEditing ? 'Edit task' : 'New task',
              style: textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),

            // Заголовок
            TextField(
              controller: _titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What needs doing?'),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),

            // Тип
            Text('Type', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _types
                  .map((t) => ChoiceChip(
                        label: Text(t),
                        selected: _type == t,
                        onSelected: (_) => setState(() => _type = t),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Приоритет
            Text('Priority', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _priorities
                  .map((p) => ChoiceChip(
                        label: Text(p),
                        selected: _priority == p,
                        onSelected: (_) => _onPriorityTap(p),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Длительность
            Text('Duration', style: textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _durations
                  .map((d) => ChoiceChip(
                        label: Text(_durationLabel(d)),
                        selected: _durationMinutes == d,
                        onSelected: (_) => setState(() => _durationMinutes = d),
                      ))
                  .toList(),
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
            const SizedBox(height: 24),

            // Сохранить
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(_isEditing ? 'Save changes' : 'Add task'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
