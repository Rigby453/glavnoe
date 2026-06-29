// Экран редактора пользовательской темы.
// Маршрут: /profile/custom-theme (05-custom-theme.md §2).
// Kaname v4: HSV-пикер (Hue/Saturation/Brightness слайдеры) удалён;
// выбор акцента заменён на 6 курируемых AccentKey (Phase 4).

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
// Соответствие AccentKey → репрезентативный цвет (light/day из design-tokens)
// ---------------------------------------------------------------------------

/// Канонические цвета акцентов для свотчей (light/day из design-tokens.json §accents).
const Map<AccentKey, Color> _kAccentKeyColors = {
  AccentKey.indigo:  Color(0xFF4B57C9),
  AccentKey.emerald: Color(0xFF1D9E75),
  AccentKey.violet:  Color(0xFF7A4FC9),
  AccentKey.ochre:   Color(0xFFB5772A),
  AccentKey.rose:    Color(0xFFC24E78),
  AccentKey.slate:   Color(0xFF3F6E9E),
};

// ---------------------------------------------------------------------------
// Контрастный цвет (чёрный или белый) для иконки поверх цветного свотча
// ---------------------------------------------------------------------------

Color _contrastColor(Color bg) {
  double lin(double v) =>
      v <= 0.04045
          ? v / 12.92
          : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final l = 0.2126 * lin(bg.r) + 0.7152 * lin(bg.g) + 0.0722 * lin(bg.b);
  return l > 0.35 ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
}

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
// Деривация превью-палитры
// ---------------------------------------------------------------------------

/// Деривация превью-палитры из конфига.
/// Каркас (поверхности, текст, border) берётся из day-темы;
/// акцент берётся из config.accentColor (отражает выбранный AccentKey).
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
    accent: config.accentColor,
    onAccent: _contrastColor(config.accentColor),
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
  late AccentKey _accentKey;
  late int _bgHueDelta;

  // Кэш превью-палитры — пересчитывается при каждом изменении
  late _PreviewPalette _previewPalette;

  @override
  void initState() {
    super.initState();
    // Инициализируем из сохранённой конфигурации и текущего акцента
    final saved = ref.read(customThemeNotifierProvider);
    _isDark = saved?.isDark ?? true;
    _accentKey = ref.read(accentNotifierProvider);
    _bgHueDelta = saved?.bgHueDelta ?? 0;
    _previewPalette = _derivePreviewPalette(_currentConfig);
  }

  // Вспомогательный метод: конфиг из текущего состояния
  CustomThemeConfig get _currentConfig => CustomThemeConfig(
        isDark: _isDark,
        accentColor: _kAccentKeyColors[_accentKey] ??
            _kAccentKeyColors[AccentKey.indigo]!,
        bgHueDelta: _bgHueDelta,
      );

  // Пересчёт превью при изменении состояния
  void _recompute() {
    setState(() {
      _previewPalette = _derivePreviewPalette(_currentConfig);
    });
  }

  // Сохранить: записать конфиг + установить тему day + установить акцент → pop
  Future<void> _save() async {
    await ref
        .read(customThemeNotifierProvider.notifier)
        .save(_currentConfig);
    // Kaname v4: custom-тема → day + выбранный акцент (Phase 4).
    await ref
        .read(themeNotifierProvider.notifier)
        .setTheme(AppThemeKey.day);
    await ref
        .read(accentNotifierProvider.notifier)
        .setAccent(_accentKey);
    if (mounted) context.pop();
  }

  // Сброс — подтверждение, затем сброс конфига и акцента → pop
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
    await ref
        .read(accentNotifierProvider.notifier)
        .setAccent(AccentKey.indigo);
    if (mounted) context.pop();
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
            // 2. Базовый режим (тёмная / светлая основа)
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
            // 3. Акцент — 6 AccentKey свотчей (заменяет HSV-пикер)
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
              child: _AccentKeyRow(
                selected: _accentKey,
                onChanged: (key) {
                  setState(() => _accentKey = key);
                  _recompute();
                },
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
        // НЕ должен его растягивать (overflow + жёлто-чёрные полосы).
        child: MediaQuery.withNoTextScaling(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Строка приветствия — локализованная
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text(context.s('today.greeting_morning')),
                    ),
                    const SizedBox(height: 3),
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11,
                      ),
                      child: Text(context.s('nav.today')),
                    ),
                    const SizedBox(height: 12),
                    // Три пилюли-задачи
                    ...List.generate(
                      3,
                      (i) => _TaskPill(
                        palette: palette,
                        isFirst: i == 0,
                        width: 80 - i * 16.0,
                        dur: dur,
                      ),
                    ),
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
// Ряд из 6 AccentKey свотчей (заменяет HSV-пикер и сетку 16 цветов)
// ---------------------------------------------------------------------------

/// Горизонтальный Wrap из 6 курируемых свотчей акцентов.
/// Используется в CustomThemeEditorScreen вместо HSV-слайдеров.
class _AccentKeyRow extends StatelessWidget {
  const _AccentKeyRow({
    required this.selected,
    required this.onChanged,
  });

  final AccentKey selected;
  final ValueChanged<AccentKey> onChanged;

  @override
  Widget build(BuildContext context) {
    final dur = effectiveDuration(context, kDurationFast);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: AccentKey.values.map((key) {
        final color = _kAccentKeyColors[key]!;
        final isSelected = selected == key;

        return GestureDetector(
          onTap: () => onChanged(key),
          child: AnimatedContainer(
            duration: dur,
            curve: kCurveSnap,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: onSurface, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
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
      }).toList(),
    );
  }
}
