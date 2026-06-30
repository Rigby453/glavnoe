// FL-DIARY-HISTORY: Запись дневника за ПРОИЗВОЛЬНЫЙ день — просмотр + правка.
// - Режим чтения: настроение + заметка + «что пошло не так» + AI-инсайт
//   (если есть) + кнопка «Изменить».
// - Режим правки: тот же набор полей, что и в diary_screen.dart (форма
//   сегодняшнего дня), но сохраняет/перезаписывает запись ЛЮБОЙ даты через
//   DayLogsDao.saveForDate(date: ...) — без дублей (upsert по дате).
// - Будущие дни недоступны для логирования (кнопка скрыта).
//
// Иконки: Phosphor. Карточки: surface1 + hairline + R14.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import 'diary_history_providers.dart';
import 'diary_insight.dart' show weeklyDiaryInsightProvider;

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

class DiaryDayDetailScreen extends ConsumerStatefulWidget {
  const DiaryDayDetailScreen({super.key, required this.date});

  /// Календарный день (без времени — DateTime(y,m,d)).
  final DateTime date;

  @override
  ConsumerState<DiaryDayDetailScreen> createState() =>
      _DiaryDayDetailScreenState();
}

class _DiaryDayDetailScreenState extends ConsumerState<DiaryDayDetailScreen> {
  final TextEditingController _noteController = TextEditingController();
  int? _mood;
  final Set<String> _issues = {};
  bool _editing = false;
  bool _saving = false;

  /// Нельзя редактировать/добавлять запись за день в будущем.
  bool get _isFuture {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return DateTime(widget.date.year, widget.date.month, widget.date.day)
        .isAfter(todayMidnight);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// Заполняет форму данными текущей записи (или пусто, если её нет) и
  /// переключает экран в режим редактирования.
  void _enterEdit(DayLogsTableData? log) {
    _mood = log?.mood;
    _issues.clear();
    _noteController.text = '';
    _parseNote(log?.note);
    setState(() => _editing = true);
  }

  /// Разбираем note на свободный текст и закодированные теги Issues
  /// (тот же формат, что пишет diary_screen.dart).
  void _parseNote(String? note) {
    if (note == null) return;
    final idx = note.indexOf(_issuesPrefix);
    if (idx == -1) {
      _noteController.text = note;
      return;
    }
    _noteController.text = note.substring(0, idx);
    final tagsPart = note.substring(idx + _issuesPrefix.length);
    for (final raw in tagsPart.split(',')) {
      final key = raw.trim();
      if (_issueL10nKeys.containsKey(key)) _issues.add(key);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final dao = ref.read(dayLogsDaoProvider);
    final freeText = _noteController.text.trim();
    final issuesSuffix =
        _issues.isEmpty ? '' : '$_issuesPrefix${_issues.join(', ')}';
    final combined = '$freeText$issuesSuffix';

    await dao.saveForDate(
      date: widget.date,
      mood: _mood,
      note: combined.isEmpty ? null : combined,
    );

    // Та же first-save-wins логика, что в diary_screen.dart, но ограниченная
    // КОНКРЕТНЫМ днём (getSinceBySource не имеет верхней границы, поэтому
    // дополнительно фильтруем результат по [dayStart, dayEnd) на клиенте —
    // не трогаем DAO ради одной выборки).
    if (_mood != null) {
      final moodDao = ref.read(moodLogsDaoProvider);
      final dayStart =
          DateTime(widget.date.year, widget.date.month, widget.date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final sinceDay = await moodDao.getSinceBySource(dayStart, 'diary');
      final sameDay =
          sinceDay.where((e) => e.loggedAt.isBefore(dayEnd)).toList();
      if (sameDay.isEmpty) {
        await moodDao.insertMood(
          mood: _mood!,
          loggedAt: widget.date,
          source: 'diary',
          note: freeText.isEmpty ? null : freeText,
        );
      }
    }

    ref.invalidate(dayLogProvider(widget.date));
    ref.invalidate(weeklyDiaryInsightProvider);

    if (!mounted) return;
    setState(() {
      _editing = false;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('diary.day_saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final logAsync = ref.watch(dayLogProvider(widget.date));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          DateFormat.yMMMMd().format(widget.date),
          style: textTheme.headlineSmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: logAsync.when(
        data: (log) =>
            _editing ? _buildEditForm(context, ext) : _buildReadView(context, log, ext),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Режим чтения
  // ---------------------------------------------------------------------------

  Widget _buildReadView(
    BuildContext context,
    DayLogsTableData? log,
    FocusThemeExtension ext,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (log == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(
                  context.s('diary.history_no_entry'),
                  style: textTheme.bodyMedium?.copyWith(color: ext.textFaint),
                ),
              ),
            ),
            if (!_isFuture)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(PhosphorIcons.plus(), size: 18),
                  label: Text(context.s('diary.history_add_entry')),
                  onPressed: () => _enterEdit(null),
                ),
              ),
          ],
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
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.mood != null) ...[
            Text(
              context.s('diary.mood'),
              style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              _moodEmojis[log.mood! - 1],
              style: const TextStyle(fontSize: 48),
            ),
            const SizedBox(height: 24),
          ],
          if (noteText.isNotEmpty) ...[
            Text(
              context.s('diary.note'),
              style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ext.border, width: 0.5),
              ),
              child: Text(noteText, style: textTheme.bodyLarge),
            ),
            const SizedBox(height: 24),
          ],
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
          if (log.insight != null && log.insight!.isNotEmpty) ...[
            Text(
              context.s('diary.history_ai_insight'),
              style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: ext.accentMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Text(log.insight!, style: textTheme.bodyMedium),
            ),
            const SizedBox(height: 24),
          ],
          if (!_isFuture)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(PhosphorIcons.pencilSimple(), size: 18),
                label: Text(context.s('btn.edit')),
                onPressed: () => _enterEdit(log),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Режим правки (зеркалит форму diary_screen.dart, но для widget.date)
  // ---------------------------------------------------------------------------

  Widget _buildEditForm(BuildContext context, FocusThemeExtension ext) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final reduce = reduceMotionOf(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Настроение 1..5 ---
          Text(
            context.s('diary.mood'),
            style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final value = i + 1;
              final selected = _mood == value;
              return GestureDetector(
                onTap: () => setState(() => _mood = value),
                child: AnimatedContainer(
                  duration: reduce ? Duration.zero : kDurationSnap,
                  curve: kCurveSnap,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? ext.accentMuted : Colors.transparent,
                    border: Border.all(
                      color: selected ? colorScheme.primary : ext.border,
                      width: selected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    _moodEmojis[i],
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // --- Свободная заметка ---
          Text(
            context.s('diary.note_prompt'),
            style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            style: textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: context.s('diary.note_hint'),
            ),
          ),
          const SizedBox(height: 24),

          // --- What went wrong ---
          Text(
            context.s('diary.what_went_wrong'),
            style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _issueL10nKeys.entries.map((e) {
              final selected = _issues.contains(e.key);
              return FilterChip(
                label: Text(context.s(e.value)),
                selected: selected,
                onSelected: (on) => setState(() {
                  if (on) {
                    _issues.add(e.key);
                  } else {
                    _issues.remove(e.key);
                  }
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // --- Сохранить / Отмена ---
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: KaiLoader(size: 18),
                    )
                  : Text(context.s('diary.save_day')),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed:
                  _saving ? null : () => setState(() => _editing = false),
              child: Text(context.s('btn.cancel')),
            ),
          ),
        ],
      ),
    );
  }
}
