// Трекер привычек (бэклог): хорошие с прогрессом + счётчик плохих.
// Локально-первый, без синхронизации.
// Удаление: SwipeToDelete (свайп влево) + кнопка в popup → Undo через snackbar.
// Прогресс (HabitLogsTable) сохраняется при удалении — логи остаются в БД,
// привязаны по habitId. После Undo тот же id возвращается и логи снова видны.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/daos/habits_dao.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/fab_position_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/kai_loader.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import '../../services/notifications/notification_service.dart';

final _habitsProvider = StreamProvider.autoDispose<List<HabitsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchActive();
});

/// Стрим заархивированных привычек — для экрана архива и счётчика «Архив (N)».
final _archivedHabitsProvider =
    StreamProvider.autoDispose<List<HabitsTableData>>((ref) {
  return ref.watch(habitsDaoProvider).watchArchived();
});

/// Реактивный счётчик выполнений привычки за сегодня, кэшируется Riverpod
/// по habitId. Заменяет inline-FutureBuilder: (1) обновляется сразу после
/// logHabit, (2) не пере-запрашивает БД на каждый ребилд родителя,
/// (3) один стрим на привычку (нет N+1 при перерисовке списка).
final _habitTodayCountProvider =
    StreamProvider.autoDispose.family<int, String>((ref, habitId) {
  return ref.watch(habitsDaoProvider).watchCountForDate(habitId, DateTime.now());
});

/// Реактивная сводка статистики привычки (стрик/лучший/всего), кэшируется
/// Riverpod по habit. Эмитит новое значение при каждом logHabit — карточка
/// и HabitDetailSheet обновляются сразу. Один стрим на привычку.
final _habitStatsProvider =
    StreamProvider.autoDispose.family<HabitStats, HabitsTableData>((ref, habit) {
  return ref.watch(habitsDaoProvider).watchStats(habit);
});

/// Карта дни(YYYY-MM-DD)→count за всю историю привычки — для ленты 30 дней
/// в HabitDetailSheet. Future (не stream): лист перечитывает при открытии.
final _habitDayCountsProvider =
    FutureProvider.autoDispose.family<Map<String, int>, String>((ref, habitId) {
  return ref.watch(habitsDaoProvider).dayCountsForHabit(habitId);
});

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(_habitsProvider);
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Кол-во заархивированных — для подписи у иконки архива.
    final archivedCount = ref.watch(_archivedHabitsProvider).value?.length ?? 0;

    final fabLocation = ref.watch(fabPositionProvider).fabLocation;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('habits.title')),
        actions: [
          // Заметный вход в архив привычек. Иконка + (N) когда архив непустой,
          // чтобы пользователь видел, что там что-то есть.
          IconButton(
            icon: const Icon(Icons.archive_outlined),
            tooltip: context.s('habits.archive_title'),
            onPressed: () => context.push('/habits/archive'),
          ),
          if (archivedCount > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text(
                  '$archivedCount',
                  style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: fabLocation,
      floatingActionButton: FloatingActionButton(
        heroTag: 'habits_add_fab',
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: habitsAsync.when(
        // KaiLoader вместо базового CircularProgressIndicator
        loading: () => Center(child: KaiLoader(label: context.s('loading.habits'))),
        error: (e, _) => Center(
          child: Text(
            context.s('error.generic').replaceFirst('{err}', '$e'),
            style: textTheme.bodyMedium?.copyWith(color: ext.ember),
          ),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                // 24dp screen margin
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Emoji заменяется нейтральной иконкой в стиле дизайн-системы
                    Icon(
                      Icons.track_changes_outlined,
                      size: 48,
                      color: ext.textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.s('habits.empty_title'),
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.s('habits.empty_body'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          final good = habits.where((h) => h.type == 'good').toList();
          final bad = habits.where((h) => h.type == 'bad').toList();

          return ListView(
            // 24dp screen margin — spec §4.1
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            children: [
              if (good.isNotEmpty) ...[
                // Секционный заголовок — titleMedium (body font, w600)
                Text(context.s('habits.good_habits'), style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...good.map(
                  (h) => SwipeToDelete(
                    key: ValueKey('habit_${h.id}'),
                    onDelete: () => _deleteHabit(context, ref, h),
                    child: _GoodHabitCard(
                      habit: h,
                      onDelete: () => _deleteHabit(context, ref, h),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (bad.isNotEmpty) ...[
                Text(context.s('habits.break_these'), style: textTheme.titleMedium),
                const SizedBox(height: 8),
                ...bad.map(
                  (h) => SwipeToDelete(
                    key: ValueKey('habit_${h.id}'),
                    onDelete: () => _deleteHabit(context, ref, h),
                    child: _BadHabitCard(
                      habit: h,
                      onDelete: () => _deleteHabit(context, ref, h),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Паттерн безопасного удаления:
  /// 1. Делаем снапшот данных привычки ДО удаления
  /// 2. Удаляем из БД (HabitLogsTable не трогаем — прогресс сохраняется по habitId)
  /// 3. Показываем Undo snackbar
  /// 4. По Undo — восстанавливаем через insertOnConflictUpdate снапшота (тот же id)
  Future<void> _deleteHabit(
    BuildContext context,
    WidgetRef ref,
    HabitsTableData habit,
  ) async {
    final dao = ref.read(habitsDaoProvider);
    // Снапшот сделан до удаления (habit уже пришёл из stream — это актуальная запись)
    final snapshot = habit;
    await dao.deleteHabit(habit.id);
    // Снимаем все слоты напоминаний удалённой привычки.
    await ref.read(notificationServiceProvider).cancelHabitReminders(habit.id);
    if (!context.mounted) return;
    final body = context.s('habits.reminder_body');
    showUndoSnackBar(
      context,
      message: '"${habit.name}" ${context.s('habits.removed')}',
      onUndo: () async {
        await dao.restoreHabit(snapshot);
        // Восстановили привычку → возвращаем её напоминание.
        await _rescheduleHabitReminder(
          ref,
          habitId: snapshot.id,
          reminderMinutes: snapshot.reminderMinutes,
          frequencyType: snapshot.frequencyType,
          weekdayMask: snapshot.weekdayMask,
          title: snapshot.name,
          body: body,
        );
      },
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    // Диалог-тело вынесено в _AddHabitDialog (StatefulWidget) — он сам владеет
    // TextEditingController и освобождает его в своём dispose(). Здесь мы лишь
    // ждём результат и создаём привычку. Так контроллер не используется после
    // dispose (исходная причина red-screen).
    final result = await showDialog<_NewHabitResult>(
      context: context,
      builder: (_) => const _AddHabitDialog(),
    );
    if (result == null) return;
    final id = await ref.read(habitsDaoProvider).createHabit(
          name: result.name,
          type: result.type,
          emoji: result.emoji,
          targetPerDay: result.targetPerDay,
          frequencyType: result.frequencyType,
          weekdayMask: result.weekdayMask,
          weeklyTarget: result.weeklyTarget,
          reminderMinutes: result.reminderMinutes,
        );
    if (!context.mounted) return;
    // Планируем локальное напоминание (slice 4). Если время не задано —
    // computeHabitReminders вернёт пусто, scheduleHabitReminders просто снимет
    // прежние слоты (no-op для новой привычки).
    await _rescheduleHabitReminder(
      ref,
      habitId: id,
      reminderMinutes: result.reminderMinutes,
      frequencyType: result.frequencyType,
      weekdayMask: result.weekdayMask,
      title: result.name,
      body: context.s('habits.reminder_body'),
    );
  }
}

/// (Пере)планирует напоминание привычки через сервис уведомлений.
/// Если [reminderMinutes] задан — гарантирует разрешение (Android 13+/iOS).
/// Best-effort: отказ в разрешении не блокирует (уведомление просто не придёт).
Future<void> _rescheduleHabitReminder(
  WidgetRef ref, {
  required String habitId,
  required int? reminderMinutes,
  required String frequencyType,
  required int weekdayMask,
  required String title,
  required String body,
}) async {
  final service = ref.read(notificationServiceProvider);
  if (reminderMinutes != null) {
    await service.ensurePermission();
  }
  await service.scheduleHabitReminders(
    habitId: habitId,
    reminderMinutes: reminderMinutes,
    frequencyType: frequencyType,
    weekdayMask: weekdayMask,
    title: title,
    body: body,
  );
}

// ---------------------------------------------------------------------------
// Диалог добавления привычки — владеет TextEditingController.
// ---------------------------------------------------------------------------

/// Результат диалога: возвращается через Navigator.pop.
class _NewHabitResult {
  const _NewHabitResult({
    required this.name,
    required this.type,
    required this.emoji,
    required this.targetPerDay,
    required this.frequencyType,
    required this.weekdayMask,
    required this.weeklyTarget,
    required this.reminderMinutes,
  });
  final String name;
  final String type;
  final String emoji;

  /// Время напоминания в минутах от полуночи (slice 4); null = без напоминания.
  final int? reminderMinutes;

  /// Сколько раз в день нужно выполнить (1..N) — делает прогресс-бар осмысленным.
  final int targetPerDay;

  /// Режим частоты (ADR-053): daily | weekly_days | weekly_count.
  final String frequencyType;

  /// Битовая маска дней недели (Пн = бит 0 … Вс = бит 6) — для weekly_days.
  final int weekdayMask;

  /// Сколько раз в неделю (1..7) — для weekly_count.
  final int weeklyTarget;
}

/// Тестовая обёртка: возвращает приватный диалог добавления привычки, чтобы
/// его можно было запумпить в виджет-тесте (overflow на 320px / textScale 1.5)
/// без БД и провайдеров. Не использовать в продакшен-коде.
@visibleForTesting
Widget addHabitDialogForTest() => const _AddHabitDialog();

class _AddHabitDialog extends StatefulWidget {
  const _AddHabitDialog();

  @override
  State<_AddHabitDialog> createState() => _AddHabitDialogState();
}

// Ключи l10n коротких подписей дней недели (Пн..Вс), reuse из Plan-модуля.
// Индекс 0 = Пн (бит 0) … индекс 6 = Вс (бит 6), как weekdayMask в ADR-053.
const _weekdayKeys = <String>[
  'plan.weekday_mon',
  'plan.weekday_tue',
  'plan.weekday_wed',
  'plan.weekday_thu',
  'plan.weekday_fri',
  'plan.weekday_sat',
  'plan.weekday_sun',
];

class _AddHabitDialogState extends State<_AddHabitDialog> {
  late final TextEditingController _nameController;
  String _type = 'good';

  // Частота (ADR-053). По умолчанию — ежедневная (как раньше).
  String _frequencyType = 'daily';
  int _weekdayMask = 127; // все 7 дней выбраны
  int _weeklyTarget = 3; // для weekly_count
  int _targetPerDay = 1; // сколько раз в день

  // Напоминание (slice 4). Выкл по умолчанию; при включении — время дня.
  bool _reminderOn = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 9, minute: 0);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Переключить день недели (индекс 0=Пн..6=Вс). Минимум один день должен
  /// остаться выбранным — последний день нельзя снять.
  void _toggleWeekday(int index) {
    final bit = 1 << index;
    final isOn = (_weekdayMask & bit) != 0;
    if (isOn) {
      final next = _weekdayMask & ~bit;
      if (next == 0) return; // хотя бы один день обязателен
      setState(() => _weekdayMask = next);
    } else {
      setState(() => _weekdayMask |= bit);
    }
  }

  /// Открывает Material time-picker и сохраняет выбранное время.
  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked != null) setState(() => _reminderTime = picked);
  }

  void _submit() {
    final name = _nameController.text.trim();
    // Пустое имя — ничего не делаем (валидация сохранена).
    if (name.isEmpty) return;
    // Напоминание только для хороших привычек и только если тумблер включён.
    final int? reminderMinutes = (_type == 'good' && _reminderOn)
        ? _reminderTime.hour * 60 + _reminderTime.minute
        : null;
    Navigator.of(context).pop(
      _NewHabitResult(
        name: name,
        type: _type,
        emoji: '',
        targetPerDay: _targetPerDay,
        frequencyType: _frequencyType,
        weekdayMask: _weekdayMask,
        // weeklyTarget важен только для weekly_count; иначе 0 (как дефолт БД).
        weeklyTarget: _frequencyType == 'weekly_count' ? _weeklyTarget : 0,
        reminderMinutes: reminderMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.s('habits.new_habit')),
      // SingleChildScrollView — контент высокий (частота + чипы), при textScale
      // 1.5 и малой высоте экрана диалог должен скроллиться, а не переполняться.
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              onSubmitted: (_) => _submit(),
              decoration:
                  InputDecoration(labelText: context.s('habits.habit_name')),
            ),
            const SizedBox(height: 16),
            // Тип: хорошая / плохая. Wrap — против overflow на 320px.
            Text(context.s('habits.type_label')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(context.s('habits.type_good')),
                  selected: _type == 'good',
                  onSelected: (_) => setState(() => _type = 'good'),
                ),
                ChoiceChip(
                  label: Text(context.s('habits.type_bad')),
                  selected: _type == 'bad',
                  onSelected: (_) => setState(() => _type = 'bad'),
                ),
              ],
            ),
            // Частота и «сколько раз в день» — только для хороших привычек
            // (у плохих привычек прогресс/расписание не используются).
            if (_type == 'good') ...[
              const SizedBox(height: 16),
              Text(context.s('habits.frequency_label')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(context.s('habits.freq_daily')),
                    selected: _frequencyType == 'daily',
                    onSelected: (_) =>
                        setState(() => _frequencyType = 'daily'),
                  ),
                  ChoiceChip(
                    label: Text(context.s('habits.freq_weekly_days')),
                    selected: _frequencyType == 'weekly_days',
                    onSelected: (_) =>
                        setState(() => _frequencyType = 'weekly_days'),
                  ),
                  ChoiceChip(
                    label: Text(context.s('habits.freq_weekly_count')),
                    selected: _frequencyType == 'weekly_count',
                    onSelected: (_) =>
                        setState(() => _frequencyType = 'weekly_count'),
                  ),
                ],
              ),
              // weekly_days → 7 чипов-дней (Wrap → переносятся на 320px).
              if (_frequencyType == 'weekly_days') ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < 7; i++)
                      FilterChip(
                        label: Text(context.s(_weekdayKeys[i])),
                        selected: (_weekdayMask & (1 << i)) != 0,
                        onSelected: (_) => _toggleWeekday(i),
                      ),
                  ],
                ),
              ],
              // weekly_count → степпер «X раз в неделю» (1..7).
              if (_frequencyType == 'weekly_count') ...[
                const SizedBox(height: 12),
                _CountStepper(
                  label: context.s('habits.weekly_target_label'),
                  value: _weeklyTarget,
                  min: 1,
                  max: 7,
                  onChanged: (v) => setState(() => _weeklyTarget = v),
                ),
              ],
              const SizedBox(height: 16),
              // «Сколько раз в день» — applies to all modes (1..10).
              _CountStepper(
                label: context.s('habits.target_per_day_label'),
                value: _targetPerDay,
                min: 1,
                max: 10,
                onChanged: (v) => setState(() => _targetPerDay = v),
              ),
              const SizedBox(height: 8),
              // Напоминание: тумблер + выбор времени (slice 4).
              // Expanded на подписи — overflow-safe на 320px / textScale 1.5.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.s('habits.reminder_label'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Switch(
                    value: _reminderOn,
                    onChanged: (v) => setState(() => _reminderOn = v),
                  ),
                ],
              ),
              if (_reminderOn)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time, size: 18),
                    label: Text(_reminderTime.format(context)),
                    onPressed: _pickReminderTime,
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        // FilledButton — единственное первичное действие в диалоге
        FilledButton(
          onPressed: _submit,
          child: Text(context.s('btn.add')),
        ),
      ],
    );
  }
}

/// Маленький степпер «− N +» с подписью. Клемпит значение в [min]..[max].
/// Текст подписи гибкий (Expanded + ellipsis) — переживает 320px / textScale.
class _CountStepper extends StatelessWidget {
  const _CountStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Row(
      children: [
        Expanded(
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: ext.textMuted,
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: ext.textMuted,
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка хорошей привычки — прогресс-бар
// ---------------------------------------------------------------------------

class _GoodHabitCard extends ConsumerWidget {
  const _GoodHabitCard({required this.habit, required this.onDelete});
  final HabitsTableData habit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    // Реактивный счётчик: обновляется сразу после logHabit (стрим из БД).
    final count = ref.watch(_habitTodayCountProvider(habit.id)).value ?? 0;
    final target = habit.targetPerDay;
    final done = count >= target;
    final progress = (count / target).clamp(0.0, 1.0);

    // Текущий стрик (дней подряд) — реактивно из DAO.
    final streak = ref.watch(_habitStatsProvider(habit)).value?.currentStreak ?? 0;

    return Card(
      // Отступ между карточками
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        // Тап по карточке → история/детали привычки.
        onTap: () => showHabitDetailSheet(context, habit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        // 16dp card inner padding — spec §4.1
        padding: const EdgeInsets.all(16),
        child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Emoji из данных привычки
                    Text(
                      habit.emoji.isNotEmpty ? habit.emoji : '',
                      style: const TextStyle(fontSize: 22),
                    ),
                    if (habit.emoji.isNotEmpty) const SizedBox(width: 8),
                    Expanded(
                      child: Text(habit.name, style: textTheme.titleSmall),
                    ),
                    // Кнопка логирования: иконка нейтральная когда не выполнено;
                    // accent (success) — только в состоянии done
                    if (!done)
                      IconButton(
                        icon: Icon(
                          Icons.check_circle_outline,
                          // Иконка нейтральная — не accent, до момента завершения
                          color: ext.textMuted,
                        ),
                        onPressed: () => dao.logHabit(habit.id),
                      )
                    else
                      // Done state — accent moment (success)
                      Icon(Icons.check_circle, color: ext.success),
                    // Кнопка меню: архив + удалить (пользователь хочет оба способа)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: ext.textMuted, size: 20),
                      onSelected: (v) {
                        if (v == 'archive') {
                          dao.archive(habit.id);
                          // Архив = пауза → снимаем напоминания.
                          ref
                              .read(notificationServiceProvider)
                              .cancelHabitReminders(habit.id);
                        }
                        if (v == 'delete') onDelete();
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(context.s('habits.archive')),
                        ),
                        // Пункт удаления с Undo (ember цвет — деструктивное действие)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            context.s('habits.delete'),
                            style: TextStyle(color: ext.ember),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Прогресс-бар осмыслен только при target > 1 (ADR-053).
                // Бинарная привычка (target<=1) → бар скрыт, остаётся текст
                // выполнено/стрик.
                if (target > 1) ...[
                  const SizedBox(height: 8),
                  // Прогресс-бар: accent при done (success moment), иначе textMuted
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: ext.textMuted.withValues(alpha: 0.18),
                      valueColor: AlwaysStoppedAnimation(
                        done ? colorScheme.primary : ext.textMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        done
                            ? context.s('habits.done')
                            : context
                                .s('habits.progress')
                                .replaceFirst('{count}', '$count')
                                .replaceFirst('{target}', '$target'),
                        style: textTheme.bodySmall?.copyWith(
                          // Done: success color; иначе textFaint (самый тихий уровень)
                          color: done ? ext.success : ext.textFaint,
                        ),
                      ),
                    ),
                    // Стрик «🔥 N дней подряд» — только когда серия идёт.
                    if (streak > 0)
                      Text(
                        '🔥 ${context.s('habits.streak_days').replaceFirst('{n}', '$streak')}',
                        style: textTheme.bodySmall?.copyWith(color: ext.ember),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ],
            ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Карточка плохой привычки — счётчик
// ---------------------------------------------------------------------------

class _BadHabitCard extends ConsumerWidget {
  const _BadHabitCard({required this.habit, required this.onDelete});
  final HabitsTableData habit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    // Реактивный счётчик нарушений: обновляется сразу после logHabit.
    final count = ref.watch(_habitTodayCountProvider(habit.id)).value ?? 0;

    // Дней без срыва — реактивно из DAO.
    final daysClean =
        ref.watch(_habitStatsProvider(habit)).value?.daysClean ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        // Тап по карточке → история/детали привычки.
        onTap: () => showHabitDetailSheet(context, habit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        // 16dp card inner padding
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
          children: [
            Text(
              habit.emoji.isNotEmpty ? habit.emoji : '',
              style: const TextStyle(fontSize: 22),
            ),
                if (habit.emoji.isNotEmpty) const SizedBox(width: 8),
                Expanded(child: Text(habit.name, style: textTheme.titleSmall)),
                // Счётчик нарушений: ember при count>0 (признак срочности/проблемы)
                // surface fill — без colorScheme.errorContainer (не стандарт дизайн-системы)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    // Нейтральный фон; текст ember только если count > 0
                    color: count > 0
                        ? ext.ember.withValues(alpha: 0.12)
                        : colorScheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: count > 0 ? ext.ember.withValues(alpha: 0.4) : ext.border,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: textTheme.titleMedium?.copyWith(
                      // Ember — только для плохих событий (согласно 03-components §1)
                      color: count > 0 ? ext.ember : ext.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.add, color: ext.textMuted),
                  onPressed: () => dao.logHabit(habit.id),
                ),
                // Кнопка меню: архив + удалить (пользователь хочет оба способа)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: ext.textMuted, size: 20),
                  onSelected: (v) {
                    if (v == 'archive') {
                      dao.archive(habit.id);
                      // Архив = пауза → снимаем напоминания.
                      ref
                          .read(notificationServiceProvider)
                          .cancelHabitReminders(habit.id);
                    }
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(context.s('habits.archive')),
                    ),
                    // Пункт удаления с Undo (ember цвет — деструктивное действие)
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        context.s('habits.delete'),
                        style: TextStyle(color: ext.ember),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // «N дней без срыва» — успешный нейтральный сигнал под счётчиком.
            if (daysClean > 0) ...[
              const SizedBox(height: 6),
              Text(
                context
                    .s('habits.days_clean')
                    .replaceFirst('{n}', '$daysClean'),
                style: textTheme.bodySmall?.copyWith(color: ext.success),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Экран архива привычек — список заархивированных с действиями
// «Разархивировать» (вернуть в активные) и «Удалить навсегда».
// ---------------------------------------------------------------------------

class HabitsArchiveScreen extends ConsumerWidget {
  const HabitsArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(_archivedHabitsProvider);
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('habits.archive_title'))),
      body: archivedAsync.when(
        loading: () => Center(child: KaiLoader(label: context.s('loading.habits'))),
        error: (e, _) => Center(
          child: Text(
            context.s('error.generic').replaceFirst('{err}', '$e'),
            style: textTheme.bodyMedium?.copyWith(color: ext.ember),
          ),
        ),
        data: (habits) {
          if (habits.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: ext.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      context.s('habits.archive_empty_title'),
                      style: textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.s('habits.archive_empty_body'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              for (final h in habits)
                _ArchivedHabitCard(
                  key: ValueKey('archived_${h.id}'),
                  habit: h,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ArchivedHabitCard extends ConsumerWidget {
  const _ArchivedHabitCard({super.key, required this.habit});
  final HabitsTableData habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final dao = ref.read(habitsDaoProvider);

    // Сводка из DAO — чтобы в архиве была видна инфа о привычке, а не только имя.
    final stats = ref.watch(_habitStatsProvider(habit)).value;
    final isGood = habit.type == 'good';
    final kind = context.s(isGood ? 'habits.kind_good' : 'habits.kind_bad');
    // good → текущий стрик; bad → всего срывов. Плюс дата создания.
    final metric = isGood
        ? '🔥 ${stats?.currentStreak ?? 0}'
        : '${stats?.totalCompletions ?? 0} ${context.s('habits.total_slips').toLowerCase()}';
    final created = _formatDate(habit.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        // Тап → история/детали (даже из архива).
        onTap: () => showHabitDetailSheet(context, habit),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(
              habit.emoji.isNotEmpty ? habit.emoji : '',
              style: const TextStyle(fontSize: 22),
            ),
            if (habit.emoji.isNotEmpty) const SizedBox(width: 8),
            // Имя + краткая инфа под ним — Expanded против overflow на 320px.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(habit.name, style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '$kind · $metric · $created',
                    style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Разархивировать — основное действие (вернуть в активные).
            IconButton(
              icon: Icon(Icons.unarchive_outlined, color: ext.textMuted),
              tooltip: context.s('habits.unarchive'),
              onPressed: () async {
                await dao.unarchive(habit.id);
                if (!context.mounted) return;
                // Разархивация → возвращаем напоминание привычки.
                await _rescheduleHabitReminder(
                  ref,
                  habitId: habit.id,
                  reminderMinutes: habit.reminderMinutes,
                  frequencyType: habit.frequencyType,
                  weekdayMask: habit.weekdayMask,
                  title: habit.name,
                  body: context.s('habits.reminder_body'),
                );
              },
            ),
            // Удалить навсегда — с подтверждением (деструктивное, без Undo).
            IconButton(
              icon: Icon(Icons.delete_outline, color: ext.ember),
              tooltip: context.s('habits.delete'),
              onPressed: () => _confirmDelete(context, ref, dao),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    HabitsDao dao,
  ) async {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${habit.name}" — ${ctx.s('habits.delete_forever_title')}'),
        content: Text(ctx.s('habits.delete_forever_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.s('btn.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ext.ember),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.s('habits.delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await dao.deleteHabit(habit.id);
      // На всякий случай снимаем слоты (у архивных они уже сняты — no-op).
      await ref.read(notificationServiceProvider).cancelHabitReminders(habit.id);
    }
  }
}

/// Короткая дата YYYY-MM-DD (локаль-нейтральная, для подписей в архиве/сводке).
String _formatDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

// ---------------------------------------------------------------------------
// HabitDetailSheet — bottom-sheet истории/деталей привычки.
// Открывается тапом по карточке (good/bad/архив). Содержит:
//   • сводку (текущий стрик, лучший стрик, всего, дата создания),
//   • мини-ленту последних 30 дней с отметками (выполнено/нет — good;
//     нарушения — bad).
// Данные берутся реактивно из DAO (watchStats + dayCountsForHabit).
// ---------------------------------------------------------------------------

/// Открыть лист истории привычки.
Future<void> showHabitDetailSheet(BuildContext context, HabitsTableData habit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HabitDetailSheet(habit: habit),
  );
}

class _HabitDetailSheet extends ConsumerWidget {
  const _HabitDetailSheet({required this.habit});
  final HabitsTableData habit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final isGood = habit.type == 'good';

    final stats = ref.watch(_habitStatsProvider(habit)).value;
    // Карта дни→count для ленты последних 30 дней (разовый запрос, авто-кэш).
    final dayCountsAsync = ref.watch(_habitDayCountsProvider(habit.id));

    return SafeArea(
      child: Padding(
        // 24dp screen margin
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок — эмодзи + имя + крестик закрытия.
              Row(
                children: [
                  if (habit.emoji.isNotEmpty) ...[
                    Text(habit.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(habit.name, style: textTheme.headlineSmall),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.s('btn.close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                context.s(isGood ? 'habits.kind_good' : 'habits.kind_bad'),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: 20),

              // Сводка: текущий стрик · лучший стрик · всего · дата создания.
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _StatTile(
                    label: context.s('habits.current_streak'),
                    value:
                        '${stats?.currentStreak ?? 0} ${context.s('habits.unit_days')}',
                    accent: ext.ember,
                  ),
                  _StatTile(
                    label: context.s('habits.best_streak'),
                    value:
                        '${stats?.bestStreak ?? 0} ${context.s('habits.unit_days')}',
                    accent: ext.ember,
                  ),
                  _StatTile(
                    label: context
                        .s(isGood ? 'habits.total_done' : 'habits.total_slips'),
                    value: '${stats?.totalCompletions ?? 0}',
                    accent: isGood ? ext.success : ext.textMuted,
                  ),
                  _StatTile(
                    label: context.s('habits.created_on'),
                    value: _formatDate(habit.createdAt),
                    accent: ext.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // История — последние 30 дней.
              Text(context.s('habits.history'), style: textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                context.s('habits.last_30_days'),
                style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
              ),
              const SizedBox(height: 12),
              dayCountsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  context.s('error.generic').replaceFirst('{err}', '$e'),
                  style: textTheme.bodySmall?.copyWith(color: ext.ember),
                ),
                data: (counts) => _HistoryStrip(
                  dayCounts: counts,
                  target: habit.targetPerDay,
                  isGood: isGood,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Плитка одной метрики в сводке.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.accent,
  });
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ext.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleMedium?.copyWith(color: accent),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Лента последних 30 дней. Каждая клетка — один день (свежие справа).
///   good: выполнено (count>=target) → success-заливка, иначе пусто.
///   bad: было нарушение (count>0) → ember-заливка, иначе чистый день.
class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({
    required this.dayCounts,
    required this.target,
    required this.isGood,
  });
  final Map<String, int> dayCounts;
  final int target;
  final bool isGood;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final effectiveTarget = target < 1 ? 1 : target;
    final todayUtc = DateTime.utc(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    // 30 дней: от 29 дней назад до сегодня (свежие справа).
    final cells = <Widget>[];
    for (var i = 29; i >= 0; i--) {
      final day = todayUtc.subtract(Duration(days: i));
      final count = dayCounts[dayKey(day)] ?? 0;
      final Color color;
      if (isGood) {
        color = count >= effectiveTarget
            ? ext.success
            : ext.textMuted.withValues(alpha: 0.18);
      } else {
        color = count > 0
            ? ext.ember
            : ext.success.withValues(alpha: 0.30);
      }
      cells.add(
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: ext.border),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: cells,
    );
  }
}
