// Экран Screen Time — ежедневные лимиты для отвлекающих категорий приложений.
// Хранение: SharedPreferences, ключ 'screen_time_limits' (JSON).
// Нет интеграции с платформой — только пользовательские лимиты.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import 'screen_time_provider.dart';

/// Иконки для категорий.
const _categoryIcons = <String, IconData>{
  'social': Icons.people_outline,
  'video': Icons.play_circle_outline,
  'games': Icons.sports_esports_outlined,
  'browsing': Icons.language_outlined,
  'messaging': Icons.chat_bubble_outline,
};

class ScreenTimeScreen extends ConsumerWidget {
  const ScreenTimeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limits = ref.watch(screenTimeLimitsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('screentime.title'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Section 1: Set daily limits ---
          Text(context.s('screentime.set_daily_limits'), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: screenTimeCategories.entries
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

          // --- Section 2: Usage data (stub) ---
          Text(context.s('screentime.usage_data'), style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.s('screentime.usage_coming_soon'),
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

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
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 12),
                  _TipRow(
                    icon: Icons.invert_colors_outlined,
                    text: context.s('screentime.tip_grayscale'),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 12),
                  _TipRow(
                    icon: Icons.hotel_outlined,
                    text: context.s('screentime.tip_phone_away'),
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Плитка одной категории с текущим лимитом. Тап → боттом-шит с ползунком.
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
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = currentMinutes == 0
        ? context.s('screentime.no_limit')
        : '$currentMinutes ${context.s('screentime.min_per_day')}';

    return ListTile(
      leading: Icon(icon, color: colorScheme.primary),
      title: Text(categoryName),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
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

/// Боттом-шит с ползунком 0–180 мин (шаг 15) и переключателем «No limit».
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
    // Если лимит 0, ползунок ставим на 60 мин как дефолт для удобства
    _sliderValue = _noLimit
        ? 60
        : widget.initialMinutes.toDouble().clamp(15, 180);
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
    final colorScheme = Theme.of(context).colorScheme;

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
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(widget.categoryName, style: textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            context.s('screentime.set_daily_time_limit'),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          // «No limit» toggle
          Row(
            children: [
              Expanded(
                child: Text(context.s('screentime.no_limit'), style: textTheme.bodyLarge),
              ),
              Switch.adaptive(
                value: _noLimit,
                onChanged: (v) => setState(() => _noLimit = v),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Slider (disabled when _noLimit)
          AnimatedOpacity(
            opacity: _noLimit ? 0.4 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('15 min', style: textTheme.bodySmall),
                    Text(
                      timeLabel,
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                      ),
                    ),
                    Text('3 h', style: textTheme.bodySmall),
                  ],
                ),
                Slider(
                  value: _sliderValue,
                  min: 15,
                  max: 180,
                  divisions: 11, // (180-15)/15 = 11 шагов
                  label: timeLabel,
                  onChanged: _noLimit
                      ? null
                      : (v) => setState(() => _sliderValue = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

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
class _TipRow extends StatelessWidget {
  const _TipRow({
    required this.icon,
    required this.text,
    required this.colorScheme,
    required this.textTheme,
  });

  final IconData icon;
  final String text;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: textTheme.bodyMedium),
        ),
      ],
    );
  }
}
