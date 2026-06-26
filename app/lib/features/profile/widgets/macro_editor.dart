// Виджет редактирования КБЖУ (цели по макронутриентам).
//
// Встраивается в любой экран через MacroEditor().
// Публичный API: const MacroEditor({super.key}) — параметров нет,
// всё состояние берётся из Riverpod (macroOverrideProvider + nutritionTargetsProvider).
//
// Режимы:
//   • override disabled → read-only расчётные нормы + кнопка «Set my own targets»
//   • override enabled + autoBalance=true → поле kcal + строки БЖУ с лок-кнопками
//   • override enabled + autoBalance=false → строки БЖУ независимо; ккал=производное
//
// Клетчатка и сахар — только чтение, из nutritionTargetsProvider.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/settings/macro_override_provider.dart';
import '../../../core/settings/nutrition_targets.dart';
import '../../../core/theme/app_theme.dart';

/// Редактор целей КБЖУ. Самодостаточный ConsumerStatefulWidget;
/// встраивается в любой ScrollView без параметров.
///
/// [previewTargets] — необязательное live-превью расчётных норм из ЛОКАЛЬНЫХ
/// (ещё не сохранённых) значений экрана редактирования антропометрии. Когда
/// override ВЫКЛЮЧЕН и превью задано — read-only нормы (ккал/БЖУ/клетчатка/сахар)
/// берутся из превью, чтобы реагировать на изменения веса/роста/возраста/пола/
/// активности/цели немедленно (как live-норма воды). Когда override включён —
/// превью игнорируется: калории берутся из пользовательских целей и не должны
/// меняться от антропометрии.
class MacroEditor extends ConsumerStatefulWidget {
  const MacroEditor({super.key, this.previewTargets});

  /// Live-превью расчётных норм из локальных значений экрана (см. описание класса).
  final NutritionTargets? previewTargets;

  @override
  ConsumerState<MacroEditor> createState() => _MacroEditorState();
}

class _MacroEditorState extends ConsumerState<MacroEditor> {
  // Контроллеры для полей ввода (заново инициализируются при включении override).
  late final TextEditingController _kcalCtrl;
  late final TextEditingController _proteinCtrl;
  late final TextEditingController _fatCtrl;
  late final TextEditingController _carbsCtrl;

  // Флаг: обновляем контроллеры программно (не вызываем setMacro в это время).
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(macroOverrideProvider);
    _kcalCtrl = TextEditingController(text: '${s.kcalTarget}');
    _proteinCtrl = TextEditingController(text: '${s.proteinG}');
    _fatCtrl = TextEditingController(text: '${s.fatG}');
    _carbsCtrl = TextEditingController(text: '${s.carbsG}');

    _kcalCtrl.addListener(_onKcalChanged);
    _proteinCtrl.addListener(() => _onMacroChanged('protein', _proteinCtrl));
    _fatCtrl.addListener(() => _onMacroChanged('fat', _fatCtrl));
    _carbsCtrl.addListener(() => _onMacroChanged('carbs', _carbsCtrl));
  }

  @override
  void dispose() {
    _kcalCtrl.dispose();
    _proteinCtrl.dispose();
    _fatCtrl.dispose();
    _carbsCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Слушатели изменений текстовых полей
  // ---------------------------------------------------------------------------

  void _onKcalChanged() {
    if (_syncing) return;
    final val = int.tryParse(_kcalCtrl.text.trim());
    if (val != null && val >= 0) {
      ref.read(macroOverrideProvider.notifier).setKcalTarget(val);
    }
  }

  void _onMacroChanged(String macro, TextEditingController ctrl) {
    if (_syncing) return;
    final val = int.tryParse(ctrl.text.trim());
    if (val != null && val >= 0) {
      ref.read(macroOverrideProvider.notifier).setMacro(macro, val);
    }
  }

  // ---------------------------------------------------------------------------
  // Синхронизация контроллеров с состоянием (после авто-баланса)
  // ---------------------------------------------------------------------------

  void _syncControllers(MacroOverrideState s) {
    _syncing = true;
    // Обновляем только если пользователь не редактирует поле прямо сейчас.
    _updateIfNotFocused(_kcalCtrl, '${s.kcalTarget}');
    _updateIfNotFocused(_proteinCtrl, '${s.proteinG}');
    _updateIfNotFocused(_fatCtrl, '${s.fatG}');
    _updateIfNotFocused(_carbsCtrl, '${s.carbsG}');
    _syncing = false;
  }

  void _updateIfNotFocused(TextEditingController ctrl, String value) {
    // Обновляем поле только если значение отличается от текущего.
    // Флаг _syncing блокирует обратный вызов слушателей → нет зацикливания.
    if (ctrl.text != value) {
      ctrl.text = value;
      // Перемещаем курсор в конец после программного изменения.
      ctrl.selection = TextSelection.collapsed(offset: value.length);
    }
  }

  // ---------------------------------------------------------------------------
  // Включить override, засеяв из расчётных норм
  // ---------------------------------------------------------------------------

  Future<void> _enableWithSeed() async {
    // Засеваем из live-превью, если оно есть (отражает несохранённые поля),
    // иначе — из сохранённых расчётных норм.
    final NutritionTargets computed =
        widget.previewTargets ?? ref.read(nutritionTargetsProvider);
    final notifier = ref.read(macroOverrideProvider.notifier);
    await notifier.setEnabled(true);
    await notifier.setKcalTarget(computed.kcal);
    await notifier.setMacro('protein', computed.proteinG);
    await notifier.setMacro('fat', computed.fatG);
    await notifier.setMacro('carbs', computed.carbsG);

    // Синхронизируем поля с засеянными значениями.
    _syncing = true;
    _kcalCtrl.text = '${computed.kcal}';
    _proteinCtrl.text = '${computed.proteinG}';
    _fatCtrl.text = '${computed.fatG}';
    _carbsCtrl.text = '${computed.carbsG}';
    _syncing = false;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final overrideState = ref.watch(macroOverrideProvider);
    final providerTargets = ref.watch(nutritionTargetsProvider);
    // В авто-режиме (override выкл) при наличии live-превью показываем его —
    // это даёт мгновенную реакцию на изменение антропометрии до Save.
    // В режиме override превью игнорируем: калории берутся из целей пользователя.
    final targets = (!overrideState.enabled && widget.previewTargets != null)
        ? widget.previewTargets!
        : providerTargets;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // После авто-баланса провайдер меняет graммы — синхронизируем контроллеры.
    if (overrideState.enabled) {
      _syncControllers(overrideState);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- Заголовок секции ----
        Text(
          context.s('macro_editor.title'),
          style: textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        if (!overrideState.enabled) ...[
          // ----------------------------------------------------------------
          // Режим: override отключён — показываем расчётные нормы только чтение
          // ----------------------------------------------------------------
          Text(
            context.s('macro_editor.recommended'),
            style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 8),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.kcal'),
            value: targets.kcal,
            unit: context.s('macro_editor.kcal_unit'),
          ),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.protein'),
            value: targets.proteinG,
            unit: context.s('macro_editor.grams_unit'),
          ),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.fat'),
            value: targets.fatG,
            unit: context.s('macro_editor.grams_unit'),
          ),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.carbs'),
            value: targets.carbsG,
            unit: context.s('macro_editor.grams_unit'),
          ),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.fiber'),
            value: targets.fiberG,
            unit: context.s('macro_editor.grams_unit'),
          ),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.sugar_max'),
            value: targets.sugarMaxG,
            unit: context.s('macro_editor.grams_unit'),
          ),
          const SizedBox(height: 16),
          // Кнопка «Задать свои цели»
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _enableWithSeed,
              child: Text(context.s('macro_editor.set_own')),
            ),
          ),
        ] else ...[
          // ----------------------------------------------------------------
          // Режим: override включён — редактируемые поля
          // ----------------------------------------------------------------

          // ---- Переключатель авто-баланса ----
          _AutoBalanceSwitch(
            value: overrideState.autoBalance,
            onChanged: (v) {
              ref.read(macroOverrideProvider.notifier).setAutoBalance(v);
            },
            hintText: context.s('macro_editor.auto_balance_hint'),
          ),
          const SizedBox(height: 12),

          // ---- Ккал (цель в авто-режиме / производное в ручном) ----
          if (overrideState.autoBalance) ...[
            _EditableMacroRow(
              label: context.s('macro_editor.kcal'),
              unit: context.s('macro_editor.kcal_unit'),
              controller: _kcalCtrl,
              showLock: false,
              isLocked: false,
              onLockToggle: null,
              lockTooltipLock: '',
              lockTooltipUnlock: '',
            ),
          ] else ...[
            // Ручной режим: ккал = производное, только чтение
            _ReadOnlyMacroRow(
              label: context.s('macro_editor.derived_kcal_label'),
              value: overrideState.derivedKcal,
              unit: context.s('macro_editor.kcal_unit'),
            ),
          ],

          const SizedBox(height: 4),

          // ---- Строки БЖУ ----
          _EditableMacroRow(
            label: context.s('macro_editor.protein'),
            unit: context.s('macro_editor.grams_unit'),
            controller: _proteinCtrl,
            showLock: overrideState.autoBalance,
            isLocked: overrideState.lockProtein,
            onLockToggle: overrideState.autoBalance
                ? (v) => ref
                    .read(macroOverrideProvider.notifier)
                    .setLock('protein', v)
                : null,
            lockTooltipLock: context.s('macro_editor.lock'),
            lockTooltipUnlock: context.s('macro_editor.unlock'),
          ),
          _EditableMacroRow(
            label: context.s('macro_editor.fat'),
            unit: context.s('macro_editor.grams_unit'),
            controller: _fatCtrl,
            showLock: overrideState.autoBalance,
            isLocked: overrideState.lockFat,
            onLockToggle: overrideState.autoBalance
                ? (v) =>
                    ref.read(macroOverrideProvider.notifier).setLock('fat', v)
                : null,
            lockTooltipLock: context.s('macro_editor.lock'),
            lockTooltipUnlock: context.s('macro_editor.unlock'),
          ),
          _EditableMacroRow(
            label: context.s('macro_editor.carbs'),
            unit: context.s('macro_editor.grams_unit'),
            controller: _carbsCtrl,
            showLock: overrideState.autoBalance,
            isLocked: overrideState.lockCarbs,
            onLockToggle: overrideState.autoBalance
                ? (v) => ref
                    .read(macroOverrideProvider.notifier)
                    .setLock('carbs', v)
                : null,
            lockTooltipLock: context.s('macro_editor.lock'),
            lockTooltipUnlock: context.s('macro_editor.unlock'),
          ),

          // ---- Эффективные ккал (в авто-режиме = kcalTarget) ----
          if (overrideState.autoBalance) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.s('macro_editor.effective_kcal_label'),
                    style:
                        textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${overrideState.effectiveKcal} ${context.s('macro_editor.kcal_unit')}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          // ---- Клетчатка + сахар (только чтение — от nutritionTargetsProvider) ----
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.fiber'),
            value: targets.fiberG,
            unit: context.s('macro_editor.grams_unit'),
          ),
          _ReadOnlyMacroRow(
            label: context.s('macro_editor.sugar_max'),
            value: targets.sugarMaxG,
            unit: context.s('macro_editor.grams_unit'),
          ),

          const SizedBox(height: 16),

          // ---- Кнопка «Сбросить к рекомендованным» ----
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                ref.read(macroOverrideProvider.notifier).reset();
              },
              child: Text(
                context.s('macro_editor.reset'),
                style: TextStyle(color: ext.ember),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _AutoBalanceSwitch — строка переключателя режима авто-баланса
// ---------------------------------------------------------------------------

class _AutoBalanceSwitch extends StatelessWidget {
  const _AutoBalanceSwitch({
    required this.value,
    required this.onChanged,
    required this.hintText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.s('macro_editor.auto_balance'),
                style: textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                hintText,
                style:
                    textTheme.bodySmall?.copyWith(color: ext.textMuted),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ReadOnlyMacroRow — строка нормы только для чтения
// ---------------------------------------------------------------------------

class _ReadOnlyMacroRow extends StatelessWidget {
  const _ReadOnlyMacroRow({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final int value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$value $unit',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EditableMacroRow — строка БЖУ с текстовым полем и опциональной кнопкой лока
// ---------------------------------------------------------------------------

class _EditableMacroRow extends StatelessWidget {
  const _EditableMacroRow({
    required this.label,
    required this.unit,
    required this.controller,
    required this.showLock,
    required this.isLocked,
    required this.onLockToggle,
    required this.lockTooltipLock,
    required this.lockTooltipUnlock,
  });

  final String label;
  final String unit;
  final TextEditingController controller;

  /// true — показывать иконку замка (только в режиме авто-баланса).
  final bool showLock;
  final bool isLocked;

  /// null — замок не нажимается (ручной режим).
  final ValueChanged<bool>? onLockToggle;

  final String lockTooltipLock;
  final String lockTooltipUnlock;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Метка макроса
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Поле ввода — фиксированная ширина, не растягивается
          SizedBox(
            width: 72,
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(5),
              ],
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Единица измерения
          Text(
            unit,
            style: textTheme.bodySmall,
          ),
          // Кнопка лока (только в авто-режиме)
          if (showLock) ...[
            const SizedBox(width: 4),
            Tooltip(
              message: isLocked ? lockTooltipUnlock : lockTooltipLock,
              child: IconButton(
                icon: Icon(
                  isLocked ? Icons.lock : Icons.lock_open_outlined,
                  size: 20,
                ),
                onPressed: onLockToggle != null
                    ? () => onLockToggle!(!isLocked)
                    : null,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ),
          ] else ...[
            // Резервируем место, чтобы ширина строк была одинаковой
            const SizedBox(width: 36),
          ],
        ],
      ),
    );
  }
}
