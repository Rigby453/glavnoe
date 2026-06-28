// Редактор пользовательской медитативной сессии — перестилизован под «Kaname».
// Бизнес-логика (имя + шаги, степпер секунд, превью длительности, сохранение в Drift) СОХРАНЕНА.
// Изменения: Phosphor-иконки, card surface1 + hairline + R12, §4.3 stepper layout.
//
// Overflow-безопасность: весь контент в ScrollView; карточка шага — вертикальный layout,
// степпер в Wrap. Выживает на 320px при textScale 1.5.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import 'meditation_custom.dart';

const _kMinStepSeconds = 5;
const _kMaxStepSeconds = 600;
const _kStepIncrement = 5;

/// Изменяемый шаг в редакторе (до сохранения).
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

  final List<_EditStep> _steps = [
    _EditStep(seconds: 60),
  ];

  @override
  void initState() {
    super.initState();
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

  int get _totalSeconds => _steps.fold<int>(0, (acc, s) => acc + s.seconds);

  Duration get _totalDuration => Duration(seconds: _totalSeconds);

  // MM:SS без хардкода суффиксов.
  String _formatTotal(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _steps.any((s) => s.text.isNotEmpty);

  Future<void> _save() async {
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
    final colorScheme = Theme.of(context).colorScheme;

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

            // --- Шаги ---
            Text(context.s('meditation.steps'), style: textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(_steps.length, (i) => _buildStepCard(i, ext, textTheme, colorScheme)),
            const SizedBox(height: 4),

            // Добавить шаг — ghost-кнопка.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addStep,
                icon: Icon(PhosphorIcons.plus(), size: 20),
                label: Text(context.s('meditation.add_step')),
              ),
            ),
            const SizedBox(height: 16),

            // --- Превью суммарной длительности ---
            Row(
              children: [
                Icon(PhosphorIcons.timer(), size: 20, color: ext.textMuted),
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

            // --- Сохранить (ONE primary FilledButton) ---
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _canSave ? _save : null,
                icon: Icon(PhosphorIcons.check(), size: 18),
                label: Text(context.s('btn.save')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Карточка шага: §4.2 surface1 + hairline + R12.
  // Инструкция на всю ширину, степпер в Wrap → выживает на 320px / textScale 1.5.
  Widget _buildStepCard(
    int index,
    FocusThemeExtension ext,
    TextTheme textTheme,
    ColorScheme colorScheme,
  ) {
    final step = _steps[index];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        color: colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: ext.border, width: 0.5),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Шапка шага: номер + кнопка удаления.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${context.s('meditation.step')} ${index + 1}',
                      style: textTheme.labelLarge?.copyWith(
                        color: ext.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      PhosphorIcons.trash(),
                      size: 18,
                      color: ext.ember,
                    ),
                    tooltip: context.s('btn.delete'),
                    // Минимум один шаг — иначе нечего проигрывать.
                    onPressed:
                        _steps.length > 1 ? () => _removeStep(index) : null,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Поле инструкции — СЫРОЙ пользовательский текст.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextField(
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
              ),
              const SizedBox(height: 8),
              // §4.3 Time stepper: − [value] + в Wrap → переносится на узком экране.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 0,
                  children: [
                    IconButton(
                      icon: Icon(PhosphorIcons.minusCircle(), size: 20),
                      color: step.seconds > _kMinStepSeconds
                          ? ext.textMuted
                          : ext.textFaint,
                      onPressed: step.seconds > _kMinStepSeconds
                          ? () => setState(() => step.seconds -= _kStepIncrement)
                          : null,
                    ),
                    // Значение — используем localized plSeconds.
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 80),
                      child: Text(
                        plSeconds(context, step.seconds),
                        style: textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: Icon(PhosphorIcons.plusCircle(), size: 20),
                      color: step.seconds < _kMaxStepSeconds
                          ? ext.textMuted
                          : ext.textFaint,
                      onPressed: step.seconds < _kMaxStepSeconds
                          ? () => setState(() => step.seconds += _kStepIncrement)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
