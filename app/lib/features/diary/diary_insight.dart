// Бесплатный (rule-based) инсайт для дневника — ТЗ C6: «инсайт (rule-based;
// ИИ глубже — paid)». Считается ЛОКАЛЬНО из Drift, без сети и без бэкенда:
// % закрытых главных задач за неделю, текущая серия, главная причина срывов,
// среднее настроение. Премиум-AI-инсайт (глубже) остаётся отдельной кнопкой.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';

/// Формат тегов «What went wrong?» в note (зеркалит diary_screen):
/// свободный текст + "\n\nIssues: tag1, tag2".
const String _kIssuesPrefix = '\n\nIssues: ';

/// Ключ тега → человекочитаемая подпись (зеркалит diary_screen).
const Map<String, String> _kIssueLabels = {
  'social_media': 'social media',
  'went_out': 'going out',
  'was_tired': 'tiredness',
  'sick': 'feeling sick',
  'other': 'other',
};

const List<String> _kMoodEmojis = ['😞', '😕', '😐', '🙂', '😄'];

/// Результат инсайта: список коротких строк (пусто = показывать нечего).
class DiaryInsight {
  const DiaryInsight(this.lines);
  final List<String> lines;
  bool get isEmpty => lines.isEmpty;
}

/// Чистая функция построения инсайта — без I/O, легко тестируется.
DiaryInsight buildWeeklyInsight({
  required int mainTotal,
  required int mainDone,
  required int streak,
  double? moodAvg,
  String? topIssueLabel,
}) {
  final lines = <String>[];

  if (mainTotal > 0) {
    final pct = ((mainDone / mainTotal) * 100).round();
    lines.add('Closed $mainDone of $mainTotal main tasks this week ($pct%).');
  }

  if (streak > 0) {
    lines.add('🔥 $streak-day streak — keep it going.');
  }

  if (topIssueLabel != null) {
    lines.add('Most common blocker lately: $topIssueLabel.');
  }

  if (moodAvg != null) {
    final idx = (moodAvg.round() - 1).clamp(0, _kMoodEmojis.length - 1);
    lines.add('Average mood: ${_kMoodEmojis[idx]} (${moodAvg.toStringAsFixed(1)}/5).');
  }

  return DiaryInsight(lines);
}

/// Парсит теги Issues из note (тот же формат, что пишет diary_screen).
List<String> parseIssueKeys(String? note) {
  if (note == null) return const [];
  final idx = note.indexOf(_kIssuesPrefix);
  if (idx == -1) return const [];
  final tagsPart = note.substring(idx + _kIssuesPrefix.length);
  return [
    for (final raw in tagsPart.split(','))
      if (_kIssueLabels.containsKey(raw.trim())) raw.trim(),
  ];
}

/// План vs факт за сегодня (SPEC C6).
class PlanVsFact {
  const PlanVsFact({
    required this.planned,
    required this.done,
    required this.skipped,
  });
  final int planned;
  final int done;
  final int skipped;

  bool get isEmpty => planned == 0;
}

/// Провайдер плана/факта на сегодня (реактивно из Drift).
final todayPlanVsFactProvider =
    StreamProvider.autoDispose<PlanVsFact>((ref) {
  return ref.watch(itemsDaoProvider).watchTodayItems(DateTime.now()).map(
    (items) => PlanVsFact(
      planned: items.length,
      done: items.where((i) => i.status == 'done').length,
      skipped: items.where((i) => i.status == 'skipped').length,
    ),
  );
});

/// Провайдер: собирает локальные данные за последние 7 дней и строит инсайт.
final weeklyDiaryInsightProvider =
    FutureProvider.autoDispose<DiaryInsight>((ref) async {
  final now = DateTime.now();
  final todayStart = DateTime.utc(now.year, now.month, now.day);
  final weekStart = todayStart.subtract(const Duration(days: 6));
  final weekEnd = todayStart.add(const Duration(days: 1));

  // Главные задачи за неделю
  final items =
      await ref.read(itemsDaoProvider).itemsInRange(weekStart, weekEnd);
  final main = items.where((i) => i.priority == 'main').toList();
  final mainDone = main.where((i) => i.status == 'done').length;

  // Серия
  final streak = await ref.read(streakDaoProvider).getStreak();

  // Записи дневника за неделю: настроение + причины срывов
  final logs = await ref.read(dayLogsDaoProvider).since(weekStart);

  final moods = [for (final l in logs) if (l.mood != null) l.mood!];
  final double? moodAvg =
      moods.isEmpty ? null : moods.reduce((a, b) => a + b) / moods.length;

  // Самая частая причина срывов
  final counts = <String, int>{};
  for (final l in logs) {
    for (final key in parseIssueKeys(l.note)) {
      counts[key] = (counts[key] ?? 0) + 1;
    }
  }
  String? topIssueLabel;
  if (counts.isNotEmpty) {
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    topIssueLabel = _kIssueLabels[top.key];
  }

  return buildWeeklyInsight(
    mainTotal: main.length,
    mainDone: mainDone,
    streak: streak?.current ?? 0,
    moodAvg: moodAvg,
    topIssueLabel: topIssueLabel,
  );
});
