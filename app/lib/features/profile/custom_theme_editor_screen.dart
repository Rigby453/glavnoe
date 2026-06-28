// Экран редактора пользовательской темы.
// Маршрут: /profile/custom-theme (05-custom-theme.md §2).
// Компоненты: превью, переключатель режима, сетка свотчей, пикер цвета, слайдер тепла.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/custom_theme_provider.dart';
import '../../core/theme/theme_provider.dart';

// ---------------------------------------------------------------------------
// Курируемая сетка акцентов (05-custom-theme.md §1)
// ---------------------------------------------------------------------------

/// 16 свотчей: 4 строки × 4 столбца (тёплые / прохладные / земляные / неон).
const List<Color> _kAccentSwatches = [
  // Тёплые
  Color(0xFFD9F24B), Color(0xFFF2A93B), Color(0xFFFF6A3D), Color(0xFFE85D75),
  // Прохладные
  Color(0xFF6FB6A3), Color(0xFF5B7CFA), Color(0xFF85C1E9), Color(0xFFA78BFA),
  // Земляные
  Color(0xFFC9A96E), Color(0xFF8DB87E), Color(0xFF9B8EC4), Color(0xFFD4A5A5),
  // Неон
  Color(0xFFC8FF4D), Color(0xFFFFE600), Color(0xFF00E5A0), Color(0xFFFF4FA3),
];

// ---------------------------------------------------------------------------
// Упрощённая структура цветов для превью
// ---------------------------------------------------------------------------

class _PreviewPalette {
  const _PreviewPalette({
    required this.bg,
    required this.surface,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.accent,
    required this.onAccent,
    required this.border,
  });
  final Color bg;
  final Color surface;
  final Color text;
  final Color textMuted;
  final Color textFaint;
  final Color accent;
  final Color onAccent;
  final Color border;
}

// ---------------------------------------------------------------------------
// Провайдер деривации для конкретного конфига (используется только в editor)
// ---------------------------------------------------------------------------

/// Деривация превью-палитры.
/// Kaname v4 shim: custom-тема заменяется accent-пикером в Phase 4;
/// сейчас возвращает day+indigo как плейсхолдер.
// ignore: deprecated_member_use
_PreviewPalette _derivePreviewPalette(CustomThemeConfig config) {
  final theme = AppTheme.build(theme: AppThemeKey.day);
  final cs = theme.colorScheme;
  final ext = theme.extension<FocusThemeExtension>();

  return _PreviewPalette(
    bg: theme.scaffoldBackgroundColor,
    surface: cs.surface,
    text: cs.onSurface,
    textMuted: ext?.textMuted ?? cs.onSurfaceVariant,
    textFaint: ext?.textFaint ?? cs.onSurfaceVariant.withValues(alpha: 0.6),
    accent: cs.primary,
    onAccent: cs.onPrimary,
    border: ext?.border ?? cs.outline,
  );
}

// ---------------------------------------------------------------------------
// Экран редактора
// ---------------------------------------------------------------------------

class CustomThemeEditorScreen extends ConsumerStatefulWidget {
  const CustomThemeEditorScreen({super.key});

  @override
  ConsumerState<CustomThemeEditorScreen> createState() =>
      _CustomThemeEditorScreenState();
}

class _CustomThemeEditorScreenState
    extends ConsumerState<CustomThemeEditorScreen> {
  // --- Редактируемое состояние ---
  late bool _isDark;
  late Color _accent;
  late int _bgHueDelta;

  // Флаг: показывать предупреждение о принудительной корректировке акцента
  bool _accentWasForced = false;

  // Кэш превью-палитры — пересчитывается при каждом изменении
  late _PreviewPalette _previewPalette;

  @override
  void initState() {
    super.initState();
    // Инициализируем из сохранённой конфигурации или умолчаниями
    final saved = ref.read(customThemeNotifierProvider);
    _isDark = saved?.isDark ?? true;
    _accent = saved?.accentColor ?? _kAccentSwatches.first;
    _bgHueDelta = saved?.bgHueDelta ?? 0;
    _previewPalette = _derivePreviewPalette(_currentConfig);
  }

  // Вспомогательный метод: конфиг из текущего состояния
  CustomThemeConfig get _currentConfig => CustomThemeConfig(
        isDark: _isDark,
        accentColor: _accent,
        bgHueDelta: _bgHueDelta,
      );

  // Пересчёт превью и флага принудительной коррекции
  void _recompute() {
    final config = _currentConfig;
    // Kaname v4 shim: custom-тема = day+indigo; forced всегда false для shim.
    final preview = _derivePreviewPalette(config);
    const forced = false;
    setState(() {
      _previewPalette = preview;
      _accentWasForced = forced;
    });
  }

  // Сохранить и вернуться
  Future<void> _save() async {
    await ref
        .read(customThemeNotifierProvider.notifier)
        .save(_currentConfig);
    // Kaname v4 shim: custom-тема → day; Phase 4 подключит accent-пикер.
    await ref
        .read(themeNotifierProvider.notifier)
        .setTheme(AppThemeKey.day);
    if (mounted) context.pop();
  }

  // Сброс — подтверждение, затем сброс → откат на focus → pop
  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.s('custom_theme.reset_confirm_title')),
        content: Text(context.s('custom_theme.reset_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.s('btn.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.s('custom_theme.reset')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(customThemeNotifierProvider.notifier).reset();
    // Если была выбрана тема day (куда shim перенаправлял custom) — оставляем day.
    // Phase 4 уточнит логику через accent-пикер.
    if (ref.read(themeNotifierProvider) == AppThemeKey.day) {
      // Уже на day — ничего не делаем.
    }
    if (mounted) context.pop();
  }

  // Открыть кастомный пикер цвета
  Future<void> _openCustomColorPicker() async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => _SimpleColorPickerDialog(initial: _accent),
    );
    if (picked != null) {
      setState(() => _accent = picked);
      _recompute();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('custom_theme.title')),
        actions: [
          TextButton(
            onPressed: _reset,
            child: Text(
              context.s('custom_theme.reset'),
              style: TextStyle(color: colorScheme.error),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(context.s('custom_theme.save')),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ----------------------------------------------------------------
            // 1. Живой превью
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _LivePreview(palette: _previewPalette),
            ),

            // ----------------------------------------------------------------
            // 2. Базовый режим
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                context.s('custom_theme.base_mode'),
                style: textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: true,
                    label: Text(context.s('custom_theme.dark')),
                    icon: const Icon(Icons.dark_mode_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text(context.s('custom_theme.light')),
                    icon: const Icon(Icons.light_mode_outlined, size: 18),
                  ),
                ],
                selected: {_isDark},
                showSelectedIcon: false,
                onSelectionChanged: (s) {
                  setState(() => _isDark = s.first);
                  _recompute();
                },
              ),
            ),

            // ----------------------------------------------------------------
            // 3. Сетка акцентов
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                context.s('custom_theme.accent_color'),
                style: textTheme.titleSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1,
                ),
                itemCount: _kAccentSwatches.length,
                itemBuilder: (_, i) {
                  final swatch = _kAccentSwatches[i];
                  final selected = _accent == swatch;
                  return _AccentSwatch(
                    color: swatch,
                    selected: selected,
                    onTap: () {
                      setState(() => _accent = swatch);
                      _recompute();
                    },
                  );
                },
              ),
            ),

            // Кнопка кастомного цвета
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(Icons.colorize_outlined, size: 18),
                  label: Text(context.s('custom_theme.custom_color')),
                  onPressed: _openCustomColorPicker,
                ),
              ),
            ),

            // Предупреждение о принудительной коррекции акцента
            if (_accentWasForced)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  context.s('custom_theme.accent_forced'),
                  style: textTheme.bodySmall
                      ?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),

            // ----------------------------------------------------------------
            // 4. Дополнительные настройки (скрытые за ExpansionTile)
            // ----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Card(
                child: ExpansionTile(
                  title: Text(context.s('custom_theme.customize_more')),
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  context.s('custom_theme.bg_warmth'),
                                  style: textTheme.bodyMedium,
                                ),
                              ),
                              Text(
                                '${_bgHueDelta > 0 ? '+' : ''}$_bgHueDelta',
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                          Slider(
                            value: _bgHueDelta.toDouble(),
                            min: -30,
                            max: 30,
                            divisions: 60,
                            label: '$_bgHueDelta',
                            onChanged: (v) {
                              setState(() => _bgHueDelta = v.round());
                              _recompute();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Живой превью (мини-макет экрана Today)
// ---------------------------------------------------------------------------

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.palette});

  final _PreviewPalette palette;

  @override
  Widget build(BuildContext context) {
    final dur = effectiveDuration(context, kDurationNormal);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: dur,
        curve: kCurveLift,
        height: 190,
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        // Превью — мини-макет фиксированного размера: системный text-scale
        // (Profile → Text size = Extra large) НЕ должен его растягивать,
        // иначе fixed-height Column переполняется (overflow + жёлто-чёрные полосы).
        child: MediaQuery.withNoTextScaling(
          child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Строка приветствия
                  AnimatedDefaultTextStyle(
                    duration: dur,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    child: const Text('Good morning'),
                  ),
                  const SizedBox(height: 3),
                  AnimatedDefaultTextStyle(
                    duration: dur,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                    ),
                    child: const Text('Today'),
                  ),
                  const SizedBox(height: 12),
                  // Три пилюли-задачи
                  ...List.generate(3, (i) => _TaskPill(
                    palette: palette,
                    isFirst: i == 0,
                    width: 80 - i * 16.0,
                    dur: dur,
                  )),
                ],
              ),
            ),
            // FAB в правом нижнем углу
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedContainer(
                duration: dur,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.add,
                  size: 20,
                  color: palette.onAccent,
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _TaskPill extends StatelessWidget {
  const _TaskPill({
    required this.palette,
    required this.isFirst,
    required this.width,
    required this.dur,
  });

  final _PreviewPalette palette;
  final bool isFirst;
  final double width;
  final Duration dur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: AnimatedContainer(
        duration: dur,
        height: 28,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: dur,
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isFirst ? palette.accent : palette.border,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              AnimatedContainer(
                duration: dur,
                width: width,
                height: 8,
                decoration: BoxDecoration(
                  color: palette.textFaint,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Свотч акцента
// ---------------------------------------------------------------------------

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = effectiveDuration(context, kDurationFast);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: duration,
        curve: kCurveSnap,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface,
                  width: 2.5,
                )
              : Border.all(color: Colors.transparent, width: 2.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: selected
            ? Center(
                child: Icon(
                  Icons.check,
                  size: 18,
                  color: _contrastColor(color),
                ),
              )
            : null,
      ),
    );
  }

  // Выбирает чёрный или белый контрастный цвет для иконки
  Color _contrastColor(Color bg) {
    double lin(double v) =>
        v <= 0.04045
            ? v / 12.92
            : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final l = 0.2126 * lin(bg.r) + 0.7152 * lin(bg.g) + 0.0722 * lin(bg.b);
    return l > 0.35 ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
  }
}

// ---------------------------------------------------------------------------
// Простой HSV пикер цвета (диалог)
// ---------------------------------------------------------------------------

class _SimpleColorPickerDialog extends StatefulWidget {
  const _SimpleColorPickerDialog({required this.initial});

  final Color initial;

  @override
  State<_SimpleColorPickerDialog> createState() =>
      _SimpleColorPickerDialogState();
}

class _SimpleColorPickerDialogState extends State<_SimpleColorPickerDialog> {
  late double _hue;
  late double _sat;
  late double _val;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.initial);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  Color get _color => HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(context.s('custom_theme.custom_color')),
      content: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Предпросмотр выбранного цвета
            AnimatedContainer(
              duration: kDurationFast,
              height: 48,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            // Оттенок (Hue)
            Row(
              children: [
                Text('Hue', style: textTheme.labelSmall),
                const Spacer(),
                Text('${_hue.round()}°', style: textTheme.labelSmall),
              ],
            ),
            Slider(
              value: _hue,
              min: 0,
              max: 360,
              divisions: 360,
              onChanged: (v) => setState(() => _hue = v),
            ),
            // Насыщенность (Sat)
            Row(
              children: [
                Text('Saturation', style: textTheme.labelSmall),
                const Spacer(),
                Text('${(_sat * 100).round()}%', style: textTheme.labelSmall),
              ],
            ),
            Slider(
              value: _sat,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (v) => setState(() => _sat = v),
            ),
            // Яркость (Value)
            Row(
              children: [
                Text('Brightness', style: textTheme.labelSmall),
                const Spacer(),
                Text('${(_val * 100).round()}%', style: textTheme.labelSmall),
              ],
            ),
            Slider(
              value: _val,
              min: 0,
              max: 1,
              divisions: 100,
              onChanged: (v) => setState(() => _val = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_color),
          child: Text(context.s('custom_theme.save')),
        ),
      ],
    );
  }
}
