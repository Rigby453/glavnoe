// Редактор пользовательской дыхательной техники.
// Kaname redesign: карточки фаз = surface + hairline (0.5dp) + R14; Phosphor-иконки;
// степперы секунд и циклов; превью суммарной длительности. Сохранение → CustomBreathingDao.create.
//
// Overflow-безопасность: весь контент в ListView; каждая фаза — карточка с
// вертикальной раскладкой (Dropdown в Expanded, степпер в Wrap), поэтому экран
// выживает на 320px при textScale 1.5.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import 'breathing_custom.dart';
import 'breathing_engine.dart';

/// Типы фаз, доступные в редакторе (совпадают с label'ами движка).
const _phaseTypes = ['Inhale', 'Hold', 'Exhale'];

const _kMinPhaseSeconds = 1;
const _kMaxPhaseSeconds = 60;
const _kMinCycles = 1;
const _kMaxCycles = 20;

/// Изменяемая фаза в редакторе (до сохранения).
class _EditPhase {
  _EditPhase({required this.type, required this.seconds});
  String type;
  int seconds;
}

class BreathingEditorScreen extends ConsumerStatefulWidget {
  const BreathingEditorScreen({super.key});

  @override
  ConsumerState<BreathingEditorScreen> createState() =>
      _BreathingEditorScreenState();
}

class _BreathingEditorScreenState extends ConsumerState<BreathingEditorScreen> {
  final _nameController = TextEditingController();

  // Дефолтный шаблон — простой вдох/выдох, чтобы было что редактировать.
  final List<_EditPhase> _phases = [
    _EditPhase(type: 'Inhale', seconds: 4),
    _EditPhase(type: 'Exhale', seconds: 4),
  ];

  int _cycles = 4;

  @override
  void initState() {
    super.initState();
    // Перерисовываем кнопку Save при изменении имени.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // --- Локализация типа фазы (переиспользуем ключи фаз) ---
  String _localizeType(String type) {
    switch (type) {
      case 'Inhale':
        return context.s('breathing.inhale');
      case 'Exhale':
        return context.s('breathing.exhale');
      case 'Hold':
        return context.s('breathing.hold');
      default:
        return type;
    }
  }

  // --- Сумма секунд одного цикла ---
  int get _cycleSeconds =>
      _phases.fold<int>(0, (acc, p) => acc + p.seconds);

  Duration get _totalDuration => Duration(seconds: _cycleSeconds * _cycles);

  String _formatTotal(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _phases.isNotEmpty;

  // --- Конвертация в фазы движка ---
  // expand/hold выводятся из типа: Inhale→растёт, Exhale→сжимается,
  // Hold→фиксирует предыдущее состояние круга.
  List<BreathPhase> _buildEnginePhases() {
    final out = <BreathPhase>[];
    var lastExpand = true;
    for (final p in _phases) {
      final isHold = p.type == 'Hold';
      bool expand;
      if (p.type == 'Inhale') {
        expand = true;
        lastExpand = true;
      } else if (p.type == 'Exhale') {
        expand = false;
        lastExpand = false;
      } else {
        expand = lastExpand;
      }
      out.add(BreathPhase(
        label: p.type,
        duration: Duration(seconds: p.seconds),
        expand: expand,
        hold: isHold,
      ));
    }
    return out;
  }

  Future<void> _save() async {
    final json = encodePhases(_buildEnginePhases());
    await ref.read(customBreathingDaoProvider).create(
          name: _nameController.text.trim(),
          phasesJson: json,
          cycles: _cycles,
        );
    if (mounted) Navigator.of(context).pop();
  }

  void _addPhase() {
    setState(() => _phases.add(_EditPhase(type: 'Inhale', seconds: 4)));
  }

  void _removePhase(int index) {
    setState(() => _phases.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('breathing.create_title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // --- Имя техники ---
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: context.s('breathing.name_label'),
              ),
            ),
            const SizedBox(height: 24),

            // --- Список фаз ---
            Text(context.s('breathing.phases'), style: textTheme.titleMedium),
            const SizedBox(height: 12),
            ...List.generate(_phases.length, (i) => _buildPhaseCard(i)),
            const SizedBox(height: 8),

            // Добавить фазу — ghost-кнопка
            TextButton.icon(
              onPressed: _addPhase,
              icon: Icon(PhosphorIcons.plus(), size: 16),
              label: Text(context.s('breathing.add_phase')),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                foregroundColor: ext.accentInk,
              ),
            ),
            const SizedBox(height: 16),

            // --- Циклы ---
            _buildCyclesRow(textTheme, ext),
            const SizedBox(height: 16),

            // --- Превью суммарной длительности ---
            Row(
              children: [
                Icon(PhosphorIcons.timer(), size: 20, color: ext.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${context.s('breathing.total')}: ${_formatTotal(_totalDuration)}',
                    style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // --- Сохранить ---
            FilledButton.icon(
              onPressed: _canSave ? _save : null,
              icon: Icon(PhosphorIcons.check()),
              label: Text(context.s('btn.save')),
            ),
          ],
        ),
      ),
    );
  }

  // Карточка одной фазы: surface + hairline + R14; тип (dropdown) + удалить; степпер секунд.
  Widget _buildPhaseCard(int index) {
    final phase = _phases[index];
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14), // R14 per spec §4.2 cards
        border: Border.all(color: ext.border, width: 0.5), // hairline
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButton<String>(
                    value: phase.type,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                    items: _phaseTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(_localizeType(t)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => phase.type = v);
                    },
                  ),
                ),
                // Кнопка удаления — ember Phosphor trash; disabled при одной фазе.
                IconButton(
                  icon: Icon(
                    PhosphorIcons.trash(),
                    color: _phases.length > 1 ? ext.ember : ext.textFaint,
                    size: 20,
                  ),
                  tooltip: context.s('btn.delete'),
                  onPressed:
                      _phases.length > 1 ? () => _removePhase(index) : null,
                ),
              ],
            ),
            // Степпер секунд в Wrap — переносится на узком экране/большом тексте.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  icon: Icon(
                    PhosphorIcons.minus(),
                    size: 20,
                    color: phase.seconds > _kMinPhaseSeconds
                        ? null
                        : ext.textFaint,
                  ),
                  onPressed: phase.seconds > _kMinPhaseSeconds
                      ? () => setState(() => phase.seconds--)
                      : null,
                ),
                Text(
                  plSeconds(context, phase.seconds),
                  style: textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    PhosphorIcons.plus(),
                    size: 20,
                    color: phase.seconds < _kMaxPhaseSeconds
                        ? null
                        : ext.textFaint,
                  ),
                  onPressed: phase.seconds < _kMaxPhaseSeconds
                      ? () => setState(() => phase.seconds++)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCyclesRow(TextTheme textTheme, FocusThemeExtension ext) {
    return Row(
      children: [
        Expanded(
          child: Text(
            context.s('breathing.cycles'),
            style: textTheme.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: Icon(
            PhosphorIcons.minus(),
            size: 20,
            color: _cycles > _kMinCycles ? null : ext.textFaint,
          ),
          onPressed: _cycles > _kMinCycles
              ? () => setState(() => _cycles--)
              : null,
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$_cycles',
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        IconButton(
          icon: Icon(
            PhosphorIcons.plus(),
            size: 20,
            color: _cycles < _kMaxCycles ? null : ext.textFaint,
          ),
          onPressed: _cycles < _kMaxCycles
              ? () => setState(() => _cycles++)
              : null,
        ),
      ],
    );
  }
}
