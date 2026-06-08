// FL-DIARY-01: Форма дневника за сегодня.
// - Настроение 1-5 (эмодзи), свободная заметка, мульти-выбор "What went wrong?".
// - Сохранение — upsert в Drift через DayLogsDao (один ряд на день).
// - Теги "What went wrong" кодируются в note (отдельной колонки в схеме нет).
// Локальное эфемерное состояние формы → StatefulWidget; данные идут через Riverpod.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_providers.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import 'diary_insight.dart';

/// Метки тегов "What went wrong?" — ключ (хранится) → подпись (показывается)
const Map<String, String> _issueLabels = {
  'social_media': 'Social media',
  'went_out': 'Went out',
  'was_tired': 'Was tired',
  'sick': 'Sick',
  'other': 'Other',
};

const List<String> _moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];
const String _issuesPrefix = '\n\nIssues: ';

class DiaryScreen extends ConsumerStatefulWidget {
  const DiaryScreen({super.key});

  @override
  ConsumerState<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends ConsumerState<DiaryScreen> {
  final TextEditingController _noteController = TextEditingController();
  int? _mood; // 1..5
  final Set<String> _issues = {};
  bool _loaded = false;
  bool _insightLoading = false;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  /// Загружаем запись за сегодня (если есть) и заполняем форму.
  Future<void> _loadExisting() async {
    final dao = ref.read(dayLogsDaoProvider);
    final existing = await dao.getForDate(DateTime.now());
    if (existing != null) {
      _mood = existing.mood;
      _parseNote(existing.note);
    }
    if (mounted) setState(() => _loaded = true);
  }

  /// Разбираем note на свободный текст и закодированные теги Issues.
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
      if (_issueLabels.containsKey(key)) _issues.add(key);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final dao = ref.read(dayLogsDaoProvider);
    final freeText = _noteController.text.trim();
    final issuesSuffix =
        _issues.isEmpty ? '' : '$_issuesPrefix${_issues.join(', ')}';
    final combined = '$freeText$issuesSuffix';

    await dao.saveForDate(
      date: DateTime.now(),
      mood: _mood,
      note: combined.isEmpty ? null : combined,
    );

    // Пересчитать бесплатный инсайт с учётом только что сохранённого дня.
    ref.invalidate(weeklyDiaryInsightProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Day saved')),
      );
    }
  }

  /// AI-инсайт по дневнику (premium). Результат показываем в диалоге.
  Future<void> _getInsight() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Premium feature — upgrade for AI insights'),
        ),
      );
      return;
    }
    setState(() => _insightLoading = true);
    try {
      final insight =
          await ref.read(apiClientProvider).aiDiaryInsight('gentle');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Insight'),
          content: Text(insight),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _insightLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How was today?', style: textTheme.headlineSmall),
          const SizedBox(height: 16),

          // Настроение 1..5
          Text('Mood', style: textTheme.labelMedium),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(5, (i) {
              final value = i + 1;
              final selected = _mood == value;
              return GestureDetector(
                onTap: () => setState(() => _mood = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120), // fast
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.25)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected
                          ? colorScheme.primary
                          : colorScheme.outline,
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

          // Свободная заметка
          Text('Anything interesting today?', style: textTheme.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Write a few words…',
            ),
          ),
          const SizedBox(height: 24),

          // What went wrong — мульти-выбор
          Text('What went wrong?', style: textTheme.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _issueLabels.entries.map((e) {
              final selected = _issues.contains(e.key);
              return FilterChip(
                label: Text(e.value),
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

          // Сохранить день
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save Day'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _insightLoading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Get insight (Premium)'),
              onPressed: _insightLoading ? null : _getInsight,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_view_week, size: 18),
              label: const Text('This week'),
              onPressed: () => context.push('/wrapped'),
            ),
          ),
          const SizedBox(height: 24),
          const _QuickInsightCard(),
        ],
      ),
    );
  }
}

/// Бесплатный (rule-based) инсайт за неделю — считается локально из Drift.
/// Премиум-AI-инсайт глубже и живёт в отдельной кнопке выше.
class _QuickInsightCard extends ConsumerWidget {
  const _QuickInsightCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyDiaryInsightProvider);
    final insight = async.valueOrNull;
    if (insight == null || insight.isEmpty) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: colorScheme.primary, size: 18),
                const SizedBox(width: 8),
                Text('This week', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            ...insight.lines.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $line', style: textTheme.bodyMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
