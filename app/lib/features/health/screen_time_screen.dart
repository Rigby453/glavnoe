// Экран Screen Time — ежедневные лимиты + реальный трекинг использования (Android).
// Лимиты: SharedPreferences, ключ 'screen_time_limits' (JSON).
// Использование: плагин usage_stats (спец-разрешение PACKAGE_USAGE_STATS),
//   агрегируется по категориям. Блокировок приложений НЕТ — только предупреждения.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import 'screen_time_advice.dart';
import 'screen_time_provider.dart';
import 'screen_time_usage_provider.dart';

/// Иконки для категорий — нейтральные (textMuted), не accent (03-components §1).
const _categoryIcons = <String, IconData>{
  'social': Icons.people_outline,
  'video': Icons.play_circle_outline,
  'games': Icons.sports_esports_outlined,
  'browsing': Icons.language_outlined,
  'messaging': Icons.chat_bubble_outline,
  'other': Icons.apps_outlined,
};

/// Максимальный лимит слайдера (мин). 12 часов = 720 мин.
const _kSliderMaxMinutes = 720.0;

/// Минимальный лимит слайдера (мин).
const _kSliderMinMinutes = 15.0;

/// Шаг слайдера (мин).
const _kSliderStep = 15.0;

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
    // Обновляем данные каждый раз, когда пользователь открывает экран —
    // провайдер не autoDispose, поэтому без этого цифры могут быть stale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(screenTimeUsageProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Возврат из системных настроек (после выдачи разрешения) → перепроверяем.
    if (state == AppLifecycleState.resumed) {
      ref.read(screenTimeUsageProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final limits = ref.watch(screenTimeLimitsProvider);
    final usage = ref.watch(screenTimeUsageProvider);
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('screentime.title')),
        // FIX 3: убрана кнопка «обновить» из AppBar.
        // Обновление доступно через RefreshIndicator (свайп) и при resume.
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(screenTimeUsageProvider.notifier).refresh(),
        child: ListView(
          // 24dp screen margin — spec §4.1
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
          children: [
          // Заголовок экрана — headlineMedium, display font (серифный), 32sp w700
          Text(
            context.s('screentime.title'),
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            context.s('screentime.set_daily_limits'),
            style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
          ),
          const SizedBox(height: 24),

          // --- Section 1: Set daily limits ---
          Text(
            context.s('screentime.set_daily_limits'),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: screenTimeCategories.entries
                  // 'other' не имеет смысла ограничивать — не показываем в лимитах
                  .where((e) => e.key != 'other')
                  .map(
                    (entry) => _CategoryTile(
                      categoryKey: entry.key,
                      categoryName: entry.value,
                      icon: _categoryIcons[entry.key] ?? Icons.apps_outlined,
                      currentMinutes: limits[entry.key] ?? 0,
                    ),
                  )
                  .toList(),
            ),
          ),

          const SizedBox(height: 24),

          // --- Section 2: Usage data (real, Android) ---
          Text(context.s('screentime.usage_data'), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          _UsageSection(usage: usage, limits: limits),

          const SizedBox(height: 24),

          // --- Section 3: Tips ---
          Text(context.s('screentime.tips'), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TipRow(
                    icon: Icons.pause_circle_outline,
                    text: context.s('screentime.tip_autoplay'),
                    ext: ext,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 12),
                  _TipRow(
                    icon: Icons.invert_colors_outlined,
                    text: context.s('screentime.tip_grayscale'),
                    ext: ext,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 12),
                  _TipRow(
                    icon: Icons.hotel_outlined,
                    text: context.s('screentime.tip_phone_away'),
                    ext: ext,
                    textTheme: textTheme,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
        ),
      ),
    );
  }
}

/// Секция реального использования: состояние разрешения / гранта / over-limit.
/// Иконки нейтральные (textMuted); ember только для over-limit (§1 ACCENT DISCIPLINE).
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
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.insights_outlined, color: ext.textMuted, size: 20),
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
                  // Перепроверка также произойдёт по resume, но дублируем явно.
                  await ref.read(screenTimeUsageProvider.notifier).refresh();
                },
                child: Text(context.s('screentime.grant_access_btn')),
              ),
            ],
          ),
        ),
      );
    }

    // 2) Ошибка чтения данных.
    if (usage.hasError) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: ext.ember, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.s('screentime.usage_error'),
                  style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3) Разрешение есть. Если совсем нет данных — мягкий пустой стейт.
    final totalUsed =
        usage.usedMinutes.values.fold<int>(0, (a, b) => a + b);
    if (totalUsed == 0 && !usage.isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline, color: ext.textMuted, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.s('screentime.no_usage_yet'),
                  style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4) Список категорий с прогрессом / over-limit + строка «Total today».
    return Card(
      child: Column(
        children: [
          // «Total today» — сумма всех категорий (включая other).
          _TotalTodayTile(totalMinutes: totalUsed),

          // Стандартные категории с лимитами.
          ...screenTimeCategories.entries
              .where((e) => e.key != 'other')
              .map(
                (entry) => _UsageTile(
                  categoryKey: entry.key,
                  categoryName: entry.value,
                  icon: _categoryIcons[entry.key] ?? Icons.apps_outlined,
                  usedMinutes: usage.usedMinutes[entry.key] ?? 0,
                  limitMinutes: limits[entry.key] ?? 0,
                  isOther: false,
                ),
              ),

          // Категория «Other» — только информационная, без лимита/предупреждений.
          if ((usage.usedMinutes['other'] ?? 0) > 0)
            _UsageTile(
              categoryKey: 'other',
              categoryName: context.s('screentime.category_other'),
              icon: Icons.apps_outlined,
              usedMinutes: usage.usedMinutes['other'] ?? 0,
              limitMinutes: 0, // без лимита (всегда)
              isOther: true,
            ),
        ],
      ),
    );
  }
}

/// Строка «Total today» — суммарное экранное время за день по всем категориям.
class _TotalTodayTile extends StatelessWidget {
  const _TotalTodayTile({required this.totalMinutes});

  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    final timeStr = hours > 0
        ? (mins > 0 ? '${hours}h ${mins}m' : '${hours}h')
        : '${mins}m';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.today_outlined, size: 20, color: ext.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.s('screentime.total_today'),
              style: textTheme.bodyLarge,
            ),
          ),
          Text(
            timeStr,
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

/// Плитка использования одной категории: «used X / limit Y», прогресс-бар,
/// индикатор превышения (ember + «over by N» / «limit reached»).
/// Для [isOther]==true: только информационная строка, без лимита/прогресса/советов.
class _UsageTile extends ConsumerWidget {
  const _UsageTile({
    required this.categoryKey,
    required this.categoryName,
    required this.icon,
    required this.usedMinutes,
    required this.limitMinutes,
    required this.isOther,
  });

  final String categoryKey;
  final String categoryName;
  final IconData icon;
  final int usedMinutes;
  final int limitMinutes;
  // true для 'other' — только информация, без лимита и советов.
  final bool isOther;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final primary = Theme.of(context).colorScheme.primary;

    // Для 'other' всегда без лимита и без предупреждений.
    final hasLimit = !isOther && limitMinutes > 0;
    final isOver = hasLimit && usedMinutes >= limitMinutes;
    final overBy = usedMinutes - limitMinutes;

    // Бесплатный «зашитый» совет — только для стандартных категорий.
    final tone = ref.watch(toneProvider);
    final level = isOther
        ? ScreenTimeLevel.ok
        : screenTimeLevel(usedMinutes, limitMinutes, categoryKey);
    final adviceKey = isOther
        ? null
        : screenTimeAdviceKey(categoryKey, level, tone);

    // Прогресс: used/limit, ограничен [0..1]. Без лимита — индикатор не показываем.
    final double? progress = hasLimit
        ? (usedMinutes / limitMinutes).clamp(0.0, 1.0).toDouble()
        : null;

    // Подпись: «used X / limit Y min» или просто «used X min» без лимита.
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
              Icon(icon, size: 20, color: isOver ? ext.ember : ext.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(categoryName, style: textTheme.bodyLarge),
              ),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: isOver ? ext.ember : ext.textMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
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
          // Совет по категории — только для стандартных категорий (не 'other').
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

/// Плитка одной категории с текущим лимитом. Тап → боттом-шит с ползунком.
/// Иконки — textMuted (нейтральные); accent только для active/selected — §1 ACCENT DISCIPLINE.
class _CategoryTile extends ConsumerWidget {
  const _CategoryTile({
    required this.categoryKey,
    required this.categoryName,
    required this.icon,
    required this.currentMinutes,
  });

  final String categoryKey;
  final String categoryName;
  final IconData icon;
  final int currentMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final subtitle = currentMinutes == 0
        ? context.s('screentime.no_limit')
        : '$currentMinutes ${context.s('screentime.min_per_day')}';

    return ListTile(
      // Иконки нейтральные (textMuted) — не accent (wall-of-lime anti-pattern)
      leading: Icon(icon, color: ext.textMuted),
      title: Text(categoryName, style: textTheme.bodyLarge),
      subtitle: Text(
        subtitle,
        style: textTheme.bodySmall?.copyWith(
          // «over limit» hint: показываем ember при нулевом лимите как напоминание
          color: currentMinutes == 0 ? ext.textFaint : ext.textMuted,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: ext.textMuted),
      onTap: () => _showLimitSheet(context, ref),
    );
  }

  void _showLimitSheet(BuildContext context, WidgetRef ref) {
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

/// Боттом-шит с ползунком 15–720 мин (шаг 15 = 47 делений) и переключателем «No limit».
/// FIX 2: максимум повышен с 3ч (180) до 12ч (720).
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
  late double _sliderValue; // в минутах, кратно 15

  @override
  void initState() {
    super.initState();
    _noLimit = widget.initialMinutes == 0;
    // Если лимит 0, ползунок ставим на 60 мин как дефолт для удобства.
    // Клампим в новый диапазон 15–720.
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
    final hours = displayMinutes ~/ 60;
    final mins = displayMinutes % 60;
    final timeLabel = hours > 0
        ? (mins > 0 ? '${hours}h ${mins}min' : '${hours}h')
        : '${mins}min';

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
          // Handle — hairline (border color, нейтральный)
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

          // Заголовок шита — headlineSmall + крестик закрытия.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(widget.categoryName, style: textTheme.headlineSmall),
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
            context.s('screentime.set_daily_time_limit'),
            style: textTheme.bodyMedium?.copyWith(
              color: ext.textMuted,
            ),
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

          // Slider (disabled when _noLimit)
          // Reduce-motion: AnimatedOpacity соответствует spec (toggle opacity, не scale)
          AnimatedOpacity(
            opacity: _noLimit ? 0.38 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('15 min', style: textTheme.bodySmall),
                    // Большая цифра текущего лимита — displaySmall, accent (primary CTA metric)
                    Text(
                      timeLabel,
                      style: textTheme.displaySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    // FIX 2: динамический максимум (12ч)
                    Text('12 h', style: textTheme.bodySmall),
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

          // Единственное первичное действие — FilledButton (§2 BUTTON HIERARCHY)
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

/// Строка совета с иконкой и текстом.
/// Иконки — textMuted (нейтральные); текст — bodyMedium.
class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.text,
    required this.ext,
    required this.textTheme,
  });

  final IconData icon;
  final String text;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Иконки советов — textMuted (декоративные, не accent)
        Icon(icon, size: 20, color: ext.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: textTheme.bodyMedium),
        ),
      ],
    );
  }
}
