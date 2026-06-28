// Лист «Собрать программу тренировок» — Kaname redesign §D.
//
// Две ветки:
//   • «Build program» (free, offline) — buildTemplateProgram(...) из анкеты;
//   • «AI program» (premium) — /ai/workout-build → parseAiWorkoutProgram(...).
// KaiLoader при AI-загрузке. Phosphor icons: barbell, sparkle, lightning, x.
// Choice chips: accentTint + accent border when selected (§4.3).
// Sheet pattern: handle · title row + close X · content · кнопки.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/app_sheet.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/settings/water_goal_provider.dart'
    show kUserAgeKey, kUserHeightCmKey, kUserSexKey, kUserWeightKgKey;
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart' show sharedPreferencesProvider;
import '../../core/widgets/kai_loader.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import '../paywall/paywall_screen.dart';
import 'workout_templates.dart';

Future<void> showAiWorkoutSheet(BuildContext context, WidgetRef ref) async {
  await showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _AiWorkoutSheet(),
  );
}

// ---------------------------------------------------------------------------
// Варианты анкеты
// ---------------------------------------------------------------------------

const _goals = <({String value, String labelKey})>[
  (value: 'strength', labelKey: 'workout.ai_goal_strength'),
  (value: 'muscle', labelKey: 'workout.ai_goal_muscle'),
  (value: 'fat_loss', labelKey: 'workout.ai_goal_fat_loss'),
  (value: 'endurance', labelKey: 'workout.ai_goal_endurance'),
  (value: 'general', labelKey: 'workout.ai_goal_general'),
];

const _experiences = <({String value, String labelKey})>[
  (value: 'beginner', labelKey: 'workout.ai_exp_beginner'),
  (value: 'intermediate', labelKey: 'workout.ai_exp_intermediate'),
  (value: 'advanced', labelKey: 'workout.ai_exp_advanced'),
];

const _equipmentOptions = <({String value, String labelKey})>[
  (value: 'barbell', labelKey: 'workout.ai_eq_barbell'),
  (value: 'dumbbells', labelKey: 'workout.ai_eq_dumbbells'),
  (value: 'pullup_bar', labelKey: 'workout.ai_eq_pullup_bar'),
  (value: 'bodyweight', labelKey: 'workout.ai_eq_bodyweight'),
  (value: 'full_gym', labelKey: 'workout.ai_eq_full_gym'),
];

const _minutesPresets = <int>[30, 45, 60, 90];

// ---------------------------------------------------------------------------
// Виджет листа
// ---------------------------------------------------------------------------

class _AiWorkoutSheet extends ConsumerStatefulWidget {
  const _AiWorkoutSheet();

  @override
  ConsumerState<_AiWorkoutSheet> createState() => _AiWorkoutSheetState();
}

class _AiWorkoutSheetState extends ConsumerState<_AiWorkoutSheet> {
  String _goal = 'muscle';
  String _experience = 'beginner';
  final Set<String> _equipment = {'bodyweight'};
  int _daysPerWeek = 3;
  int _minutes = 45;

  final _focusController = TextEditingController();
  final _limitationsController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _focusController.dispose();
    _limitationsController.dispose();
    super.dispose();
  }

  void _toggleEquipment(String value) {
    setState(() {
      if (_equipment.contains(value)) {
        if (_equipment.length > 1) _equipment.remove(value);
      } else {
        _equipment.add(value);
      }
    });
  }

  String? _trimmedOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _buildFree() async {
    final program = buildTemplateProgram(
      goal: _goal,
      experience: _experience,
      equipment: _equipment.toList(),
      daysPerWeek: _daysPerWeek,
    );
    final localized = localizeWorkoutProgram(program, context.s);
    await _save(localized);
  }

  Future<void> _buildAi() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      showPremiumUpsell(context, context.s('workout.ai_premium_feature'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tone =
          ref.read(toneProvider) == AppTone.harsh ? 'harsh' : 'gentle';
      final prefs = ref.read(sharedPreferencesProvider);
      final profile = <String, dynamic>{
        'sex': prefs.getString(kUserSexKey),
        'age': prefs.getInt(kUserAgeKey),
        'weight_kg': prefs.getDouble(kUserWeightKgKey),
        'height_cm': prefs.getInt(kUserHeightCmKey),
      };

      final response = await ref.read(apiClientProvider).aiWorkoutBuild(
            goal: _goal,
            experience: _experience,
            equipment: _equipment.toList(),
            daysPerWeek: _daysPerWeek,
            minutesPerSession: _minutes,
            focus: _trimmedOrNull(_focusController),
            limitations: _trimmedOrNull(_limitationsController),
            tone: tone,
            profile: profile,
          );
      final program = parseAiWorkoutProgram(response);
      if (program.days.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = context.s('workout.ai_empty');
          });
        }
        return;
      }
      await _save(program);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.s('workout.ai_empty');
        });
      }
    }
  }

  Future<void> _save(WorkoutProgram program) async {
    final dao = ref.read(workoutsDaoProvider);
    await saveWorkoutProgram(dao, program);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.s('workout.ai_saved'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Container(
      // Sheet shadow (§4.3 — только шиты)
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(28),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 0,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ext.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Заголовок: barbell icon + название + крестик
              Row(
                children: [
                  Icon(
                    PhosphorIcons.barbell(PhosphorIconsStyle.fill),
                    size: 20,
                    color: colorScheme.primary.withAlpha(180),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.s('workout.ai_title'),
                      style: textTheme.headlineSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(PhosphorIcons.x(), size: 20, color: ext.textMuted),
                    tooltip: context.s('btn.close'),
                    onPressed: () => Navigator.of(context).maybePop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_loading) ...[
                // KaiLoader — AI/loading brand indicator
                Center(
                  child: KaiLoader(label: context.s('workout.ai_loading')),
                ),
                const SizedBox(height: 24),
              ] else ...[
                // Ошибка AI-ветки
                if (_error != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(PhosphorIcons.warningCircle(), size: 16, color: ext.ember),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: textTheme.bodyMedium?.copyWith(color: ext.ember),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Goal
                _FieldLabel(text: context.s('workout.ai_goal'), ext: ext, textTheme: textTheme),
                _ChoiceChips(
                  options: _goals,
                  selected: {_goal},
                  onTap: (v) => setState(() => _goal = v),
                  ext: ext,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),

                // Experience
                _FieldLabel(text: context.s('workout.ai_experience'), ext: ext, textTheme: textTheme),
                _ChoiceChips(
                  options: _experiences,
                  selected: {_experience},
                  onTap: (v) => setState(() => _experience = v),
                  ext: ext,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),

                // Equipment (multi)
                _FieldLabel(text: context.s('workout.ai_equipment'), ext: ext, textTheme: textTheme),
                _ChoiceChips(
                  options: _equipmentOptions,
                  selected: _equipment,
                  onTap: _toggleEquipment,
                  ext: ext,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),

                // Days per week
                _FieldLabel(text: context.s('workout.ai_days'), ext: ext, textTheme: textTheme),
                _Stepper(
                  value: _daysPerWeek,
                  min: 1,
                  max: 7,
                  ext: ext,
                  textTheme: textTheme,
                  onChanged: (v) => setState(() => _daysPerWeek = v),
                ),
                const SizedBox(height: 16),

                // Minutes per session
                _FieldLabel(text: context.s('workout.ai_minutes'), ext: ext, textTheme: textTheme),
                _ChoiceChips(
                  options: [
                    for (final m in _minutesPresets)
                      (value: '$m', labelKey: 'lit:$m min'),
                  ],
                  selected: {'$_minutes'},
                  onTap: (v) => setState(() => _minutes = int.parse(v)),
                  ext: ext,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 16),

                // Focus (optional)
                TextField(
                  controller: _focusController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.s('workout.ai_focus'),
                    hintText: context.s('workout.ai_focus_hint'),
                  ),
                ),
                const SizedBox(height: 12),

                // Limitations (optional)
                TextField(
                  controller: _limitationsController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: context.s('workout.ai_limitations'),
                    hintText: context.s('workout.ai_limitations_hint'),
                  ),
                ),
                const SizedBox(height: 24),

                // Кнопки действий
                // FREE — FilledButton (primary, offline)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: Icon(PhosphorIcons.lightning(PhosphorIconsStyle.fill), size: 18),
                    label: Text(context.s('workout.ai_build_free')),
                    onPressed: _buildFree,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // AI — OutlinedButton с sparkle (premium)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: Icon(PhosphorIcons.sparkle(), size: 18),
                    label: Text(context.s('workout.ai_build_ai')),
                    onPressed: _buildAi,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
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
// Вспомогательные виджеты
// ---------------------------------------------------------------------------

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.text,
    required this.ext,
    required this.textTheme,
  });

  final String text;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: textTheme.labelLarge?.copyWith(color: ext.textMuted),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Группа выбора (single/multi) — Kaname §4.3:
/// accentTint underlay + accent border when selected.
class _ChoiceChips extends StatelessWidget {
  const _ChoiceChips({
    required this.options,
    required this.selected,
    required this.onTap,
    required this.ext,
    required this.colorScheme,
  });

  final List<({String value, String labelKey})> options;
  final Set<String> selected;
  final void Function(String value) onTap;
  final FocusThemeExtension ext;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          Builder(builder: (context) {
            final isSelected = selected.contains(o.value);
            final label = o.labelKey.startsWith('lit:')
                ? o.labelKey.substring(4)
                : context.s(o.labelKey);
            return GestureDetector(
              onTap: () => onTap(o.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? ext.accentTint : colorScheme.surface,
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : ext.border,
                    width: isSelected ? 1.0 : 0.5,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: isSelected ? colorScheme.primary : ext.textMuted,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// Степпер — (§4.3 time stepper pattern): − [value] +.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.ext,
    required this.textTheme,
  });

  final int value;
  final int min;
  final int max;
  final void Function(int) onChanged;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(
          icon: PhosphorIcons.minus(),
          enabled: value > min,
          ext: ext,
          onTap: value > min ? () => onChanged(value - 1) : null,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: 8),
        _StepperButton(
          icon: PhosphorIcons.plus(),
          enabled: value < max,
          ext: ext,
          onTap: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.ext,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final FocusThemeExtension ext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          border: Border.all(color: ext.border, width: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? ext.textMuted : ext.textFaint,
        ),
      ),
    );
  }
}
