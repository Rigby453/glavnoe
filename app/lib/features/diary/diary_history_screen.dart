// Просмотр записей дневника за прошлые даты
// Календарь + выбор даты → отображение записи

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';

/// Запись дневника за конкретный день
final dayLogProvider = FutureProvider.family
    .autoDispose<DayLogsTableData?, DateTime>((ref, date) async {
      final start = DateTime.utc(date.year, date.month, date.day);
      return ref.watch(dayLogsDaoProvider).getForDate(start);
    });

const Map<String, String> _issueLabels = {
  'social_media': 'Social media',
  'went_out': 'Went out',
  'was_tired': 'Was tired',
  'sick': 'Sick',
  'other': 'Other',
};

const List<String> _moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const String _issuesPrefix = '\n\nIssues: ';

class DiaryHistoryScreen extends ConsumerStatefulWidget {
  const DiaryHistoryScreen({super.key});

  @override
  ConsumerState<DiaryHistoryScreen> createState() => _DiaryHistoryScreenState();
}

class _DiaryHistoryScreenState extends ConsumerState<DiaryHistoryScreen> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final dayLog = ref.watch(dayLogProvider(_selectedDate));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text('Diary History', style: textTheme.headlineSmall),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Календарь
          Container(
            padding: const EdgeInsets.all(16),
            color: colorScheme.surfaceContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Date', style: textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        setState(() {
                          _selectedDate = _selectedDate.subtract(
                            const Duration(days: 1),
                          );
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _showDatePicker(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colorScheme.outline),
                          ),
                          child: Text(
                            _formatDateFull(_selectedDate),
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _selectedDate.isBefore(DateTime.now())
                          ? () {
                              setState(() {
                                _selectedDate = _selectedDate.add(
                                  const Duration(days: 1),
                                );
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Содержимое записи
          Expanded(
            child: dayLog.when(
              data: (log) =>
                  _buildDayContent(context, log, textTheme, colorScheme),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayContent(
    BuildContext context,
    DayLogsTableData? log,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    if (log == null) {
      return Center(
        child: Text(
          'No entry for this day',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
        ),
      );
    }

    // Парсим issue из note
    String noteText = log.note ?? '';
    List<String> issues = [];
    if (noteText.contains(_issuesPrefix)) {
      final parts = noteText.split(_issuesPrefix);
      noteText = parts[0];
      issues = parts[1].split(', ').where((i) => i.isNotEmpty).toList();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Настроение
          if (log.mood != null) ...[
            Text('Mood', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              _moodEmojis[log.mood! - 1],
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 24),
          ],
          // Заметка
          if (noteText.isNotEmpty) ...[
            Text('Note', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(noteText, style: textTheme.bodyMedium),
            ),
            const SizedBox(height: 24),
          ],
          // Issues
          if (issues.isNotEmpty) ...[
            Text('What Went Wrong', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: issues
                  .map(
                    (issue) => Chip(label: Text(_issueLabels[issue] ?? issue)),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          // AI-инсайт
          if (log.insight != null && log.insight!.isNotEmpty) ...[
            Text('AI Insight', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(log.insight!, style: textTheme.bodyMedium),
            ),
          ],
        ],
      ),
    );
  }

  void _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  String _formatDateFull(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final weekday = weekdays[date.weekday - 1];
    return '$weekday, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
