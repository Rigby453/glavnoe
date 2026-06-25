// Секция «Профиль здоровья» + «Расписание сна» — публичный виджет,
// извлечённый из profile_screen. Используется в MyDataScreen.
// Провайдер healthProfileProvider уже хранит данные — всегда предзаполнена.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/health_profile_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/voice_text_field.dart';

// ---------------------------------------------------------------------------
// HealthProfileSection — основной публичный виджет
// ---------------------------------------------------------------------------

/// Секция «Профиль здоровья» в профиле / экране «Мои данные».
/// Показывает аллергии, заживление, дефициты, расписание сна.
/// По нажатию «Редактировать» раскрывает inline-редактор.
class HealthProfileSection extends ConsumerStatefulWidget {
  const HealthProfileSection({super.key});

  @override
  ConsumerState<HealthProfileSection> createState() =>
      _HealthProfileSectionState();
}

class _HealthProfileSectionState extends ConsumerState<HealthProfileSection> {
  bool _editing = false;

  late final TextEditingController _allergiesCtrl;
  late String _healingChoice;
  late final TextEditingController _deficienciesCtrl;

  late int _bedtimeHour;
  late int _wakeHour;

  @override
  void initState() {
    super.initState();
    final hp = ref.read(healthProfileProvider);
    _allergiesCtrl = TextEditingController(text: hp.allergies);
    _healingChoice = hp.healing;
    _deficienciesCtrl = TextEditingController(text: hp.deficiencies);
    _bedtimeHour = hp.bedtimeHour;
    _wakeHour = hp.wakeHour;
  }

  @override
  void dispose() {
    _allergiesCtrl.dispose();
    _deficienciesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(healthProfileProvider.notifier).save(HealthProfile(
          allergies: _allergiesCtrl.text,
          healing: _healingChoice,
          deficiencies: _deficienciesCtrl.text,
          bedtimeHour: _bedtimeHour,
          wakeHour: _wakeHour,
        ));
    if (!mounted) return;
    setState(() => _editing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('health_profile.saved_snack'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final hp = ref.watch(healthProfileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции + кнопка редактирования
        Row(
          children: [
            Expanded(
              child: Text(
                context.s('health_profile.section_title'),
                style: textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: () {
                if (_editing) {
                  // Отмена — сброс к сохранённым значениям
                  final current = ref.read(healthProfileProvider);
                  _allergiesCtrl.text = current.allergies;
                  _healingChoice = current.healing;
                  _deficienciesCtrl.text = current.deficiencies;
                  _bedtimeHour = current.bedtimeHour;
                  _wakeHour = current.wakeHour;
                }
                setState(() => _editing = !_editing);
              },
              child: Text(_editing
                  ? context.s('btn.cancel')
                  : context.s('health_profile.edit_btn')),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (_editing) ...[
          _HealthProfileEditor(
            allergiesCtrl: _allergiesCtrl,
            healingChoice: _healingChoice,
            onHealingChanged: (v) => setState(() => _healingChoice = v),
            deficienciesCtrl: _deficienciesCtrl,
            bedtimeHour: _bedtimeHour,
            wakeHour: _wakeHour,
            onBedtimeChanged: (v) => setState(() => _bedtimeHour = v),
            onWakeChanged: (v) => setState(() => _wakeHour = v),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            child: Text(context.s('health_profile.btn_save')),
          ),
        ] else ...[
          if (hp.isEmpty)
            Text(
              context.s('health_profile.empty_hint'),
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
            )
          else
            _HealthProfileView(profile: hp),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _HealthProfileView — режим просмотра
// ---------------------------------------------------------------------------

class _HealthProfileView extends StatelessWidget {
  const _HealthProfileView({required this.profile});

  final HealthProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    Widget field(String label, String value) {
      if (value.trim().isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: textTheme.labelMedium?.copyWith(color: ext.textMuted)),
            const SizedBox(height: 2),
            Text(value, style: textTheme.bodyMedium),
          ],
        ),
      );
    }

    String healingLabel(String value) => switch (value) {
          'fast' => context.s('health_profile.healing_fast'),
          'week' => context.s('health_profile.healing_week'),
          'slow' => context.s('health_profile.healing_slow'),
          _ => value,
        };

    String formatHour(int h) {
      final period = h < 12 ? 'AM' : 'PM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:00 $period';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field(context.s('health_profile.q_allergies'), profile.allergies),
        if (profile.healing.isNotEmpty)
          field(
            context.s('health_profile.q_healing_label'),
            healingLabel(profile.healing),
          ),
        field(context.s('health_profile.q_deficiencies'), profile.deficiencies),
        field(
          context.s('health_profile.sleep_schedule_label'),
          '${context.s('health_profile.bedtime_label')}: ${formatHour(profile.bedtimeHour)} · '
          '${context.s('health_profile.wake_label')}: ${formatHour(profile.wakeHour)}',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _HealthProfileEditor — inline-редактор
// ---------------------------------------------------------------------------

class _HealthProfileEditor extends StatelessWidget {
  const _HealthProfileEditor({
    required this.allergiesCtrl,
    required this.healingChoice,
    required this.onHealingChanged,
    required this.deficienciesCtrl,
    required this.bedtimeHour,
    required this.wakeHour,
    required this.onBedtimeChanged,
    required this.onWakeChanged,
  });

  final TextEditingController allergiesCtrl;
  final String healingChoice;
  final ValueChanged<String> onHealingChanged;
  final TextEditingController deficienciesCtrl;
  final int bedtimeHour;
  final int wakeHour;
  final ValueChanged<int> onBedtimeChanged;
  final ValueChanged<int> onWakeChanged;

  String _formatHour(int h) {
    final period = h < 12 ? 'AM' : 'PM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:00 $period';
  }

  Future<void> _pickTime(
    BuildContext context,
    int currentHour,
    ValueChanged<int> onChanged,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: 0),
    );
    if (picked != null) onChanged(picked.hour);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    final healingOptions = [
      ('fast', context.s('health_profile.healing_fast')),
      ('week', context.s('health_profile.healing_week')),
      ('slow', context.s('health_profile.healing_slow')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Аллергии ----
        VoiceTextField(
          controller: allergiesCtrl,
          labelText: context.s('health_profile.q_allergies'),
          maxLines: 3,
        ),
        const SizedBox(height: 16),

        // ---- Скорость заживления ----
        Text(
          context.s('health_profile.q_healing_label'),
          style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: healingOptions.map((pair) {
            final value = pair.$1;
            final label = pair.$2;
            final selected = healingChoice == value;
            return ChoiceChip(
              label: Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              selected: selected,
              onSelected: (_) => onHealingChanged(selected ? '' : value),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        // ---- Дефициты ----
        VoiceTextField(
          controller: deficienciesCtrl,
          labelText: context.s('health_profile.q_deficiencies'),
          maxLines: 3,
        ),
        const SizedBox(height: 20),

        // ---- Расписание сна ----
        Text(
          context.s('health_profile.sleep_schedule_label'),
          style: textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          context.s('health_profile.sleep_schedule_hint'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.bedtime_outlined, size: 18),
                label: Flexible(
                  child: Text(
                    '${context.s('health_profile.bedtime_label')}: ${_formatHour(bedtimeHour)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () => _pickTime(context, bedtimeHour, onBedtimeChanged),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: ext.border),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.wb_sunny_outlined, size: 18),
                label: Flexible(
                  child: Text(
                    '${context.s('health_profile.wake_label')}: ${_formatHour(wakeHour)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: () => _pickTime(context, wakeHour, onWakeChanged),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(color: ext.border),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
