// Просмотр записей дневника за прошлые даты
// Календарь + выбор даты → отображение записи

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';

/// Запись дневника за конкретный день
final dayLogProvider = FutureProvider.family
    .autoDispose<DayLogsTableData?, DateTime>((ref, date) async {
      final start = DateTime.utc(date.year, date.month, date.day);
      return ref.watch(dayLogsDaoProvider).getForDate(start);
    });

/// Ключ тега → ключ локализации (зеркалит diary_screen).
const Map<String, String> _issueL10nKeys = {
  'social_media': 'diary.issue_social_media',
  'went_out': 'diary.issue_went_out',
  'was_tired': 'diary.issue_was_tired',
  'sick': 'diary.issue_sick',
  'other': 'diary.issue_other',
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
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final dayLog = ref.watch(dayLogProvider(_selectedDate));

    return Scaffold(
      // elevation=0, bg из темы — AppBar без тени (02-type-space.md §4.3)
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        // headlineSmall — display font, заголовок экрана-модалки
        title: Text(
          context.s('diary.history_screen_title'),
          style: textTheme.headlineSmall,
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Выбор даты — используем surface с hairline border (не surfaceContainer)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            color: colorScheme.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.s('diary.history_select_date'),
                  style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
                ),
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
                            // surface fill + border outline (02-type-space.md §4.3)
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: ext.border,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _formatDateFull(_selectedDate),
                                  textAlign: TextAlign.center,
                                  // bodyMedium w600 — дата читается как важная, но не heading
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                // textFaint — tertiary icon, не CTA
                                color: ext.textFaint,
                              ),
                            ],
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
          // Тонкий разделитель вместо тяжёлого divider
          Divider(height: 1, thickness: 0.5, color: ext.border),
          // Содержимое записи
          Expanded(
            child: dayLog.when(
              data: (log) => _buildDayContent(context, log, textTheme, ext),
              // KaiLoader вместо стандартного спиннера (spec §6)
              loading: () => Center(
                child: KaiLoader(label: context.s('loading.generic')),
              ),
              error: (err, st) => Center(
                child: Text(
                  context.s('error.generic').replaceFirst('{err}', '$err'),
                  style: textTheme.bodyMedium?.copyWith(color: ext.ember),
                ),
              ),
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
    FocusThemeExtension ext,
  ) {
    if (log == null) {
      return Center(
        child: Text(
          context.s('diary.history_no_entry'),
          // textFaint — tertiary, пустое состояние (01-color.md §New Tokens)
          style: textTheme.bodyMedium?.copyWith(color: ext.textFaint),
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
      // 24dp горизонтальные поля (02-type-space.md §4.1)
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Настроение
          if (log.mood != null) ...[
            Text(context.s('diary.mood'), style: textTheme.titleSmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 12),
            // Эмодзи большой — фиксированный размер (не текстовая роль)
            Text(
              _moodEmojis[log.mood! - 1],
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 24),
          ],
          // Заметка
          if (noteText.isNotEmpty) ...[
            Text(context.s('diary.note'), style: textTheme.titleSmall?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // surface fill + hairline border (02-type-space.md §4.3 «Content card at rest»)
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ext.border, width: 0.5),
              ),
              child: Text(noteText, style: textTheme.bodyLarge),
            ),
            const SizedBox(height: 24),
          ],
          // Теги "что пошло не так"
          if (issues.isNotEmpty) ...[
            Text(
              context.s('diary.history_what_went_wrong'),
              style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: issues
                  .map(
                    (issue) => Chip(
                      label: Text(
                        _issueL10nKeys.containsKey(issue)
                            ? context.s(_issueL10nKeys[issue]!)
                            : issue,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
          ],
          // AI-инсайт: accentMuted фон (low-emphasis accent fill, 01-color.md §New Tokens)
          if (log.insight != null && log.insight!.isNotEmpty) ...[
            Text(
              context.s('diary.history_ai_insight'),
              style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // accentMuted: low-emphasis accent fill для AI-контента
                color: ext.accentMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  width: 0.5,
                ),
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
