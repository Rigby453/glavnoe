// Экран Screen Time — ежедневные лимиты + реальный трекинг использования (Android).
// Лимиты: SharedPreferences, ключ 'screen_time_limits' (JSON).
// Использование: плагин usage_stats (спец-разрешение PACKAGE_USAGE_STATS),
//   агрегируется по категориям. Блокировок приложений НЕТ — только предупреждения.
// Restyle «Kaname» §4.2: hairline-card, Phosphor-иконки, section-labels,
//   локализованные форматы времени. Бизнес-логика сохранена полностью.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import 'screen_time_advice.dart';
import 'screen_time_overrides_provider.dart';
import 'screen_time_provider.dart';
import 'screen_time_usage_provider.dart';

// ---------------------------------------------------------------------------
// Константы слайдера (мин)
// ---------------------------------------------------------------------------

/// Максимальный лимит слайдера (мин). 12 часов = 720 мин.
const _kSliderMaxMinutes = 720.0;

/// Минимальный лимит слайдера (мин).
const _kSliderMinMinutes = 15.0;

/// Шаг слайдера (мин).
const _kSliderStep = 15.0;

// ---------------------------------------------------------------------------
// Вспомогательные функции
// ---------------------------------------------------------------------------

/// Форматирует минуты в локализованную строку длительности.
/// Использует l10n-ключи screentime.fmt_h_only / fmt_h_min / fmt_min.
String _fmtDuration(BuildContext context, int minutes) {
  if (minutes >= 60) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) {
      return context.s('screentime.fmt_h_only').replaceAll('{h}', '$h');
    }
    return context
        .s('screentime.fmt_h_min')
        .replaceAll('{h}', '$h')
        .replaceAll('{m}', '$m');
  }
  return context.s('screentime.fmt_min').replaceAll('{m}', '$minutes');
}

/// Phosphor-иконка для категории экранного времени.
/// «other» и неизвестные → squaresFour.
IconData _categoryIcon(String key) => switch (key) {
      'social' => PhosphorIcons.users(),
      'video' => PhosphorIcons.playCircle(),
      'games' => PhosphorIcons.gameController(),
      'browsing' => PhosphorIcons.globe(),
      'messaging' => PhosphorIcons.chatCircle(),
      _ => PhosphorIcons.squaresFour(),
    };

// ---------------------------------------------------------------------------
// Главный экран
// ---------------------------------------------------------------------------

class ScreenTimeScreen extends ConsumerStatefulWidget {
  const ScreenTimeScreen({super.key});

  @override
  ConsumerState<ScreenTimeScreen> createState() => _ScreenTimeScreenState();
}

class _ScreenTimeScreenState extends ConsumerState<ScreenTimeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Обновляем данные каждый раз при открытии экрана.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(screenTimeUsageProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Возврат из системных настроек → перепроверяем разрешение.
    if (state == AppLifecycleState.resumed) {
      ref.read(screenTimeUsageProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final limits = ref.watch(screenTimeLimitsProvider);
    final usage = ref.watch(screenTimeUsageProvider);
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        // Phosphor arrowLeft — §icon-map
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft()),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(context.s('screentime.title')),
        // Обновление — только pull-to-refresh (свайп вниз)
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(screenTimeUsageProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          // Боковой отступ 24 — design-tokens §spacing.lg
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
          children: [
            // --- Section 1: Установить лимиты ---
            _SectionLabel(context.s('screentime.set_daily_limits')),
            _HairlineCard(
              children: _buildLimitRows(context, limits, ext),
            ),
            const SizedBox(height: 24),

            // --- Section 2: Данные об использовании ---
            _SectionLabel(context.s('screentime.usage_data')),
            _UsageSection(usage: usage, limits: limits),
            const SizedBox(height: 24),

            // --- Section 3: Советы ---
            _SectionLabel(context.s('screentime.tips')),
            _HairlineCard(
              children: [
                _TipRow(
                  icon: PhosphorIcons.pauseCircle(),
                  text: context.s('screentime.tip_autoplay'),
                ),
                Divider(height: 1, thickness: 0.5, color: ext.border),
                _TipRow(
                  icon: PhosphorIcons.palette(),
                  text: context.s('screentime.tip_grayscale'),
                ),
                Divider(height: 1, thickness: 0.5, color: ext.border),
                _TipRow(
                  icon: PhosphorIcons.moon(),
                  text: context.s('screentime.tip_phone_away'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  /// Строит строки лимитов с hairline-разделителями (кроме 'other').
  List<Widget> _buildLimitRows(
    BuildContext context,
    Map<String, int> limits,
    FocusThemeExtension ext,
  ) {
    final entries = screenTimeCategories.entries
        .where((e) => e.key != 'other')
        .toList();
    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      rows.add(_CategoryLimitRow(
        categoryKey: entry.key,
        // Локализованное имя категории (не hardcoded English из provider)
        categoryName: context.s('screentime.cat_${entry.key}'),
        currentMinutes: limits[entry.key] ?? 0,
      ));
      if (i < entries.length - 1) {
        rows.add(Divider(height: 1, thickness: 0.5, color: ext.border));
      }
    }
    return rows;
  }
}

// ---------------------------------------------------------------------------
// Общие компоненты §4.2
// ---------------------------------------------------------------------------

/// Заголовок секции — labelMedium, textMuted (Kaname §4.2).
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: ext.textMuted,
              letterSpacing: 0.3,
            ),
      ),
    );
  }
}

/// Карточка: surface1 + hairline (0.5dp) + R14, без тени (Kaname §4.2).
class _HairlineCard extends StatelessWidget {
  const _HairlineCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border.all(color: ext.border, width: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        // Немного меньший радиус чтобы обрезать содержимое без артефактов границы
        borderRadius: BorderRadius.circular(13.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка лимита категории
// ---------------------------------------------------------------------------

/// Строка лимита одной категории. Тап → боттом-шит с ползунком.
/// Стиль: hairline row (§4.2), Phosphor-иконка, caretRight.
class _CategoryLimitRow extends StatelessWidget {
  const _CategoryLimitRow({
    required this.categoryKey,
    required this.categoryName,
    required this.currentMinutes,
  });

  final String categoryKey;
  final String categoryName;
  final int currentMinutes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final subtitle = currentMinutes == 0
        ? context.s('screentime.no_limit')
        : _fmtDuration(context, currentMinutes);

    return InkWell(
      onTap: () => _showLimitSheet(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Иконки нейтральные (textMuted) — не accent (§accent-discipline)
            Icon(_categoryIcon(categoryKey), size: 20, color: ext.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(categoryName, style: textTheme.bodyLarge),
            ),
            const SizedBox(width: 8),
            Text(
              subtitle,
              style: textTheme.bodySmall?.copyWith(
                color: currentMinutes == 0 ? ext.textFaint : ext.textMuted,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 8),
            Icon(PhosphorIcons.caretRight(), size: 16, color: ext.textFaint),
          ],
        ),
      ),
    );
  }

  void _showLimitSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LimitBottomSheet(
        categoryKey: categoryKey,
        categoryName: categoryName,
        initialMinutes: currentMinutes,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Секция «Данные об использовании»
// ---------------------------------------------------------------------------

/// Секция использования: 4 состояния — нет разрешения / ошибка / нет данных / данные.
/// Иконки нейтральные (textMuted); ember только при over-limit (§accent-discipline).
class _UsageSection extends ConsumerWidget {
  const _UsageSection({required this.usage, required this.limits});

  final ScreenTimeUsageState usage;
  final Map<String, int> limits;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // 1) Нет разрешения → карточка с объяснением и кнопкой «Дать доступ».
    if (!usage.isGranted) {
      return _HairlineCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIcons.chartLine(),
                        color: ext.textMuted, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.s('screentime.grant_access_title'),
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  context.s('screentime.grant_access_body'),
                  style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () async {
                    await ref
                        .read(screenTimeUsageProvider.notifier)
                        .requestPermission();
                    await ref
                        .read(screenTimeUsageProvider.notifier)
                        .refresh();
                  },
                  child: Text(context.s('screentime.grant_access_btn')),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 2) Ошибка чтения данных.
    if (usage.hasError) {
      return _HairlineCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.warningCircle(),
                    color: ext.ember, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.s('screentime.usage_error'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 3) Разрешение есть, но данных ещё нет.
    final totalUsed =
        usage.usedMinutes.values.fold<int>(0, (a, b) => a + b);
    if (totalUsed == 0 && !usage.isLoading) {
      return _HairlineCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(PhosphorIcons.checkCircle(),
                    color: ext.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.s('screentime.no_usage_yet'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // 4) Данные с прогресс-барами; over-limit = ember.
    final rows = <Widget>[];

    // «Total today» — строка суммы всех категорий.
    rows.add(_TotalTodayRow(totalMinutes: totalUsed));

    // Стандартные категории с лимитами (кроме 'other').
    for (final entry
        in screenTimeCategories.entries.where((e) => e.key != 'other')) {
      rows.add(Divider(height: 1, thickness: 0.5, color: ext.border));
      rows.add(_UsageTile(
        categoryKey: entry.key,
        // Локализованное имя — не hardcoded English из provider
        categoryName: context.s('screentime.cat_${entry.key}'),
        usedMinutes: usage.usedMinutes[entry.key] ?? 0,
        limitMinutes: limits[entry.key] ?? 0,
        isOther: false,
      ));
    }

    // Категория 'other' — только информационная, без лимита.
    if ((usage.usedMinutes['other'] ?? 0) > 0) {
      rows.add(Divider(height: 1, thickness: 0.5, color: ext.border));
      rows.add(_UsageTile(
        categoryKey: 'other',
        categoryName: context.s('screentime.category_other'),
        usedMinutes: usage.usedMinutes['other'] ?? 0,
        limitMinutes: 0,
        isOther: true,
      ));
    }

    // Per-app breakdown — переназначение категорий сохранено полностью.
    if (usage.perPackageMinutes.isNotEmpty) {
      rows.add(_AppsBreakdownSection(usage: usage));
    }

    return _HairlineCard(children: rows);
  }
}

// ---------------------------------------------------------------------------
// Строка «Total today»
// ---------------------------------------------------------------------------

/// Суммарное экранное время за день — первая строка в Usage-карточке.
class _TotalTodayRow extends StatelessWidget {
  const _TotalTodayRow({required this.totalMinutes});
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(PhosphorIcons.calendarCheck(), size: 20, color: ext.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.s('screentime.total_today'),
              style: textTheme.bodyLarge,
            ),
          ),
          Text(
            _fmtDuration(context, totalMinutes),
            style: textTheme.bodySmall?.copyWith(
              color: ext.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Плитка использования одной категории
// ---------------------------------------------------------------------------

/// Использование категории: прогресс-бар, over-limit = ember.
/// [isOther]==true: только информационная строка, без лимита/прогресса/советов.
class _UsageTile extends ConsumerWidget {
  const _UsageTile({
    required this.categoryKey,
    required this.categoryName,
    required this.usedMinutes,
    required this.limitMinutes,
    required this.isOther,
  });

  final String categoryKey;
  final String categoryName;
  final int usedMinutes;
  final int limitMinutes;
  final bool isOther;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final primary = Theme.of(context).colorScheme.primary;

    final hasLimit = !isOther && limitMinutes > 0;
    final isOver = hasLimit && usedMinutes >= limitMinutes;
    final overBy = usedMinutes - limitMinutes;

    // Бесплатный «зашитый» совет для стандартных категорий.
    final tone = ref.watch(toneProvider);
    final level = isOther
        ? ScreenTimeLevel.ok
        : screenTimeLevel(usedMinutes, limitMinutes, categoryKey);
    final adviceKey =
        isOther ? null : screenTimeAdviceKey(categoryKey, level, tone);

    // Прогресс: used/limit, ограничен [0..1].
    final double? progress = hasLimit
        ? (usedMinutes / limitMinutes).clamp(0.0, 1.0).toDouble()
        : null;

    // Подпись: «used / limit» или просто «used».
    final usedLabel = '${context.s('screentime.used_today')}: '
        '$usedMinutes ${context.s('screentime.min_per_day')}';
    final subtitle = hasLimit
        ? '$usedMinutes / $limitMinutes ${context.s('screentime.min_per_day')}'
        : usedLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _categoryIcon(categoryKey),
                size: 20,
                color: isOver ? ext.ember : ext.textMuted,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(categoryName, style: textTheme.bodyLarge),
              ),
              const SizedBox(width: 8),
              // Flexible + ellipsis: защита от overflow на 320dp / textScale 1.5
              Flexible(
                child: Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: isOver ? ext.ember : ext.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (hasLimit) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: ext.border,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isOver ? ext.ember : primary,
                ),
              ),
            ),
            if (isOver) ...[
              const SizedBox(height: 6),
              Text(
                overBy > 0
                    ? '${context.s('screentime.over_limit')} '
                        '$overBy ${context.s('screentime.min_per_day')}'
                    : context.s('screentime.limit_reached'),
                style: textTheme.bodySmall?.copyWith(color: ext.ember),
              ),
            ],
          ],
          // Совет — только для стандартных категорий при наличии данных.
          if (!isOther && usedMinutes > 0 && adviceKey != null) ...[
            const SizedBox(height: 6),
            Text(
              context.s(adviceKey),
              style: textTheme.bodySmall?.copyWith(
                color: level == ScreenTimeLevel.tooMuch
                    ? ext.ember
                    : ext.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Боттом-шит: лимит категории
// ---------------------------------------------------------------------------

/// Боттом-шит со слайдером 15–720 мин (шаг 15 = 47 делений) и переключателем.
class _LimitBottomSheet extends ConsumerStatefulWidget {
  const _LimitBottomSheet({
    required this.categoryKey,
    required this.categoryName,
    required this.initialMinutes,
  });

  final String categoryKey;
  final String categoryName;
  final int initialMinutes;

  @override
  ConsumerState<_LimitBottomSheet> createState() => _LimitBottomSheetState();
}

class _LimitBottomSheetState extends ConsumerState<_LimitBottomSheet> {
  late bool _noLimit;
  late double _sliderValue; // минуты, кратно 15

  @override
  void initState() {
    super.initState();
    _noLimit = widget.initialMinutes == 0;
    // Если лимит 0 → дефолт 60 мин. Клампим в диапазон 15–720.
    _sliderValue = _noLimit
        ? 60
        : widget.initialMinutes
            .toDouble()
            .clamp(_kSliderMinMinutes, _kSliderMaxMinutes);
  }

  Future<void> _save() async {
    final minutes = _noLimit ? 0 : _sliderValue.round();
    await ref
        .read(screenTimeLimitsProvider.notifier)
        .setLimit(widget.categoryKey, minutes);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final displayMinutes = _sliderValue.round();
    final timeLabel = _fmtDuration(context, displayMinutes);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle — hairline-цвет, нейтральный
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
          const SizedBox(height: 20),

          // Заголовок + Phosphor ✕ закрытия
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.categoryName,
                  style: textTheme.headlineSmall,
                ),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.x()),
                tooltip: context.s('btn.close'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.s('screentime.set_daily_time_limit'),
            style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 24),

          // «No limit» toggle
          Row(
            children: [
              Expanded(
                child: Text(
                  context.s('screentime.no_limit'),
                  style: textTheme.bodyLarge,
                ),
              ),
              Switch.adaptive(
                value: _noLimit,
                onChanged: (v) => setState(() => _noLimit = v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider (анимация opacity при _noLimit, соответствует spec reduce-motion)
          AnimatedOpacity(
            opacity: _noLimit ? 0.38 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Локализованная метка минимума (15 мин)
                    Text(
                      _fmtDuration(context, 15),
                      style: textTheme.bodySmall,
                    ),
                    // Текущее значение — displaySmall, accent (CTA-метрика)
                    Text(
                      timeLabel,
                      style: textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    // Локализованная метка максимума (12 ч)
                    Text(
                      _fmtDuration(context, 720),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
                Slider(
                  value: _sliderValue,
                  min: _kSliderMinMinutes,
                  max: _kSliderMaxMinutes,
                  // (720 - 15) / 15 = 47 делений
                  divisions: ((_kSliderMaxMinutes - _kSliderMinMinutes) /
                          _kSliderStep)
                      .round(),
                  label: timeLabel,
                  onChanged: _noLimit
                      ? null
                      : (v) => setState(() => _sliderValue = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Единственная первичная кнопка (§4.3 BUTTON HIERARCHY)
          FilledButton(
            onPressed: _save,
            child: Text(
              _noLimit
                  ? context.s('screentime.remove_limit')
                  : '${context.s('screentime.set_daily_time_limit')} · $timeLabel',
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Строка совета
// ---------------------------------------------------------------------------

/// Строка совета: Phosphor-иконка + bodyMedium текст (§4.2 hairline row).
class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконки советов — textMuted (декоративные, не accent)
          Icon(icon, size: 20, color: ext.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-app breakdown + category override UI (СОХРАНЕНО ПОЛНОСТЬЮ)
// ---------------------------------------------------------------------------

/// Последние N сегментов имени пакета для читаемого отображения.
/// «com.miHoYo.GenshinImpact» → «miHoYo.GenshinImpact»
String _pkgDisplayName(String packageName) {
  final parts = packageName.split('.');
  if (parts.length >= 2) {
    return '${parts[parts.length - 2]}.${parts.last}';
  }
  return packageName;
}

/// Подраздел «Приложения» внутри карточки Usage data.
/// Показывает все приложения с ненулевым временем, отсортированные по убыванию.
/// Длинные списки (>8) скрываются за кнопкой «Показать ещё».
/// Тап на строке → _AppCategoryPickerSheet для переназначения категории.
class _AppsBreakdownSection extends ConsumerStatefulWidget {
  const _AppsBreakdownSection({required this.usage});
  final ScreenTimeUsageState usage;

  @override
  ConsumerState<_AppsBreakdownSection> createState() =>
      _AppsBreakdownSectionState();
}

class _AppsBreakdownSectionState
    extends ConsumerState<_AppsBreakdownSection> {
  static const _kInitialMax = 8;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final userOverrides = ref.watch(screenTimeOverridesProvider);
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Сортируем по убыванию минут, фильтруем нулевые.
    final apps = widget.usage.perPackageMinutes.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (apps.isEmpty) return const SizedBox.shrink();

    final showAll = _expanded || apps.length <= _kInitialMax;
    final visible = showAll ? apps : apps.sublist(0, _kInitialMax);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, thickness: 0.5, color: ext.border),
        // Заголовок подраздела — labelMedium, textMuted
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            context.s('screentime.apps_section'),
            style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
          ),
        ),
        ...visible.map((entry) {
          final pkg = entry.key;
          final minutes = entry.value;
          // Эффективная категория: user override первым, затем из state.
          final effectiveCat = userOverrides[pkg] ??
              widget.usage.perPackageCategories[pkg] ??
              'other';
          final hasOverride = userOverrides.containsKey(pkg);
          return _AppRow(
            packageName: pkg,
            minutes: minutes,
            effectiveCategory: effectiveCat,
            hasUserOverride: hasOverride,
            onTap: () =>
                _showCategoryPicker(context, pkg, effectiveCat, hasOverride),
          );
        }),
        // Кнопка «ещё N» / «свернуть» — локализованная
        if (apps.length > _kInitialMax)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: ext.textMuted,
            ),
            child: Text(
              _expanded
                  ? context.s('screentime.apps_collapse')
                  : context
                      .s('screentime.apps_show_more')
                      .replaceAll('{n}', '${apps.length - _kInitialMax}'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
          ),
      ],
    );
  }

  void _showCategoryPicker(
    BuildContext context,
    String packageName,
    String currentCategory,
    bool hasOverride,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AppCategoryPickerSheet(
        packageName: packageName,
        currentCategory: currentCategory,
        hasUserOverride: hasOverride,
      ),
    );
  }
}

/// Строка одного приложения в per-app breakdown.
/// Phosphor deviceMobile + chip категории + маркер оверрайда + pencilSimple.
class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.packageName,
    required this.minutes,
    required this.effectiveCategory,
    required this.hasUserOverride,
    required this.onTap,
  });

  final String packageName;
  final int minutes;
  final String effectiveCategory;
  final bool hasUserOverride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final catLabel = context.s('screentime.cat_$effectiveCategory');
    final timeLabel = _fmtDuration(context, minutes);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
        child: Row(
          children: [
            Icon(PhosphorIcons.deviceMobile(), size: 18, color: ext.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pkgDisplayName(packageName),
                    style: textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    timeLabel,
                    style: textTheme.bodySmall
                        ?.copyWith(color: ext.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Метка категории — chip-like (border + R12)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: ext.border,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    catLabel,
                    style:
                        textTheme.bodySmall?.copyWith(color: ext.textMuted),
                  ),
                  // Маркер «есть пользовательский оверрайд» — точка accent
                  if (hasUserOverride) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(PhosphorIcons.pencilSimple(), size: 16, color: ext.textMuted),
          ],
        ),
      ),
    );
  }
}

/// Нижний лист выбора категории для конкретного приложения.
/// Показывает все категории в виде hairline-строк с checkCircle/circle.
/// Сохраняет оверрайд и запускает refresh() агрегации.
class _AppCategoryPickerSheet extends ConsumerStatefulWidget {
  const _AppCategoryPickerSheet({
    required this.packageName,
    required this.currentCategory,
    required this.hasUserOverride,
  });

  final String packageName;
  final String currentCategory;
  final bool hasUserOverride;

  @override
  ConsumerState<_AppCategoryPickerSheet> createState() =>
      _AppCategoryPickerSheetState();
}

class _AppCategoryPickerSheetState
    extends ConsumerState<_AppCategoryPickerSheet> {
  late String _selected;

  // Порядок категорий в пикере (все 6, включая 'other').
  static const _kCategories = [
    'social',
    'video',
    'games',
    'browsing',
    'messaging',
    'other',
  ];

  @override
  void initState() {
    super.initState();
    _selected = widget.currentCategory;
  }

  Future<void> _save() async {
    await ref
        .read(screenTimeOverridesProvider.notifier)
        .setOverride(widget.packageName, _selected);
    // Fire-and-forget: обновляем агрегацию с новым оверрайдом.
    ref.read(screenTimeUsageProvider.notifier).refresh();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.s('screentime.category_changed')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _reset() async {
    await ref
        .read(screenTimeOverridesProvider.notifier)
        .removeOverride(widget.packageName);
    ref.read(screenTimeUsageProvider.notifier).refresh();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
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
          const SizedBox(height: 20),
          // Заголовок + Phosphor ✕
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.s('screentime.reassign_title'),
                      style: textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 2),
                    // Имя пакета — truncated, bodySmall textMuted
                    Text(
                      _pkgDisplayName(widget.packageName),
                      style: textTheme.bodySmall
                          ?.copyWith(color: ext.textMuted),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(PhosphorIcons.x()),
                tooltip: context.s('btn.close'),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Список категорий — hairline InkWell rows с checkCircle/circle
          ..._kCategories.map((cat) {
            final isSelected = _selected == cat;
            return InkWell(
              onTap: () => setState(() => _selected = cat),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(_categoryIcon(cat), size: 20, color: ext.textMuted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.s('screentime.cat_$cat'),
                        style: textTheme.bodyLarge,
                      ),
                    ),
                    // fill+accent когда выбрано, regular+textMuted иначе (§icon-rule)
                    Icon(
                      isSelected
                          ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                          : PhosphorIcons.circle(),
                      size: 20,
                      color: isSelected ? accent : ext.textMuted,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          // Основная кнопка — сохранить (§4.3 ONE primary per sheet)
          FilledButton(
            onPressed: _save,
            child: Text(context.s('btn.save')),
          ),
          // Кнопка сброса оверрайда (только если задан)
          if (widget.hasUserOverride) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _reset,
              child: Text(context.s('screentime.reset_to_default')),
            ),
          ],
        ],
      ),
    );
  }
}
