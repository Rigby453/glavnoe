// Редактор пользовательской медитативной сессии.
// Имя + упорядоченный список шагов (многострочный текст инструкции + секунды),
// живое превью суммарной длительности (mm:ss). Сохранение → CustomMeditationDao.
//
// Overflow-безопасность: весь контент в ScrollView; каждый шаг — карточка с
// вертикальной раскладкой (поле текста на всю ширину, степпер в Wrap), поэтому
// экран выживает на 320px при textScale 1.5.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import 'meditation_custom.dart';

const _kMinStepSeconds = 5;
const _kMaxStepSeconds = 600;
const _kStepIncrement = 5;

/// Изменяемый шаг в редакторе (до сохранения).
/// Держит собственный TextEditingController для поля инструкции.
class _EditStep {
  _EditStep({String text = '', required this.seconds})
      : controller = TextEditingController(text: text);
  final TextEditingController controller;
  int seconds;

  String get text => controller.text.trim();

  void dispose() => controller.dispose();
}

class MeditationEditorScreen extends ConsumerStatefulWidget {
  const MeditationEditorScreen({super.key});

  @override
  ConsumerState<MeditationEditorScreen> createState() =>
      _MeditationEditorScreenState();
}

class _MeditationEditorScreenState
    extends ConsumerState<MeditationEditorScreen> {
  final _nameController = TextEditingController();

  // Дефолтный шаблон — один пустой шаг, чтобы было что редактировать.
  final List<_EditStep> _steps = [
    _EditStep(seconds: 60),
  ];

  @override
  void initState() {
    super.initState();
    // Перерисовываем кнопку Save при изменении имени.
    _nameController.addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _nameController.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    super.dispose();
  }

  // --- Сумма секунд всех шагов ---
  int get _totalSeconds => _steps.fold<int>(0, (acc, s) => acc + s.seconds);

  Duration get _totalDuration => Duration(seconds: _totalSeconds);

  String _formatTotal(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // Сохранять можно, если есть имя и хотя бы один шаг с непустым текстом.
  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _steps.any((s) => s.text.isNotEmpty);

  Future<void> _save() async {
    // В БД пишем только шаги с непустым текстом (пустые отбрасываются кодеком).
    final steps = _steps
        .where((s) => s.text.isNotEmpty)
        .map((s) => MeditationStep(text: s.text, seconds: s.seconds))
        .toList();
    if (steps.isEmpty) return;
    final json = encodeSteps(steps);
    await ref.read(customMeditationDaoProvider).create(
          name: _nameController.text.trim(),
          stepsJson: json,
        );
    if (mounted) Navigator.of(context).pop();
  }

  void _addStep() {
    setState(() => _steps.add(_EditStep(seconds: 60)));
  }

  void _removeStep(int index) {
    setState(() {
      final removed = _steps.removeAt(index);
      removed.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('meditation.create_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // --- Имя сессии ---
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.s('meditation.name_label'),
              ),
            ),
            const SizedBox(height: 24),

            // --- Список шагов ---
            Text(context.s('meditation.steps'), style: textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(_steps.length, (i) => _buildStepCard(i)),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: Text(context.s('meditation.add_step')),
              ),
            ),
            const SizedBox(height: 16),

            // --- Превью суммарной длительности ---
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 20, color: ext.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.s('meditation.total')}: ${_formatTotal(_totalDuration)}',
                    style: textTheme.titleMedium?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- Сохранить ---
            FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: const Icon(Icons.check),
              label: Text(context.s('btn.save')),
            ),
          ],
        ),
      ),
    );
  }

  // Карточка одного шага: многострочное поле инструкции + удалить; снизу степпер.
  Widget _buildStepCard(int index) {
    final step = _steps[index];
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.s('meditation.step')} ${index + 1}',
                    style: textTheme.titleSmall?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: ext.ember),
                  tooltip: context.s('btn.delete'),
                  // Минимум один шаг — иначе сессию нечего проигрывать.
                  onPressed:
                      _steps.length > 1 ? () => _removeStep(index) : null,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Многострочное поле инструкции — СЫРОЙ пользовательский текст.
            TextField(
              controller: step.controller,
              onChanged: (_) => _onChanged(),
              maxLines: null,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.s('meditation.instruction_hint'),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            // Степпер секунд в Wrap — переносится на узком экране/большом тексте.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: step.seconds > _kMinStepSeconds
                      ? () => setState(
                          () => step.seconds -= _kStepIncrement)
                      : null,
                ),
                Text(plSeconds(context, step.seconds)),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: step.seconds < _kMaxStepSeconds
                      ? () => setState(
                          () => step.seconds += _kStepIncrement)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
