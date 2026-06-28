// Экран «Список покупок» (SPEC C5, Phase 1).
// Kaname redesign §4.2: hairline-divided check rows, accentTint suggestion chips,
// Phosphor icons, KaiMascot empty state. Свайп влево = удаление + Undo-тост.
// Локальный, офлайн-первый. Синхронизация — Фаза 3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/animations/animated_check.dart';
import '../../core/animations/app_toast.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../features/mascot/kai_mascot.dart';
import 'shopping_suggestions.dart';

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Реактивный список всех позиций (unchecked сверху, checked снизу).
final _shoppingListProvider =
    StreamProvider.autoDispose<List<ShoppingItemsTableData>>((ref) {
  return ref.watch(shoppingDaoProvider).watchAll();
});

/// Предложения на основе истории еды (последние 30 дней).
final _shoppingSuggestionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final basketAsync = ref.watch(_shoppingListProvider);
  final basket = basketAsync.valueOrNull ?? const [];
  final basketNames = basket.map((i) => i.name).toSet();

  final dao = ref.read(foodLogsDaoProvider);
  final rawLogs = await dao.recentLogs(kSuggestionDays);

  final entries = rawLogs
      .map((l) => FoodLogEntry(name: l.name, date: l.date))
      .toList();

  return computeShoppingSuggestions(
    logs: entries,
    basketNames: basketNames,
  );
});

// ---------------------------------------------------------------------------
// Экран
// ---------------------------------------------------------------------------

class ShoppingListScreen extends ConsumerStatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  ConsumerState<ShoppingListScreen> createState() =>
      _ShoppingListScreenState();
}

class _ShoppingListScreenState extends ConsumerState<ShoppingListScreen> {
  final _addController = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _addController.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    _addFocus.requestFocus();
    await ref.read(shoppingDaoProvider).insertItem(name: text);
  }

  /// Свайп-удаление: тост «removed» + Undo.
  Future<bool> _onDismiss(
    BuildContext context,
    ShoppingItemsTableData item,
  ) async {
    await ref.read(shoppingDaoProvider).deleteItem(item.id);
    if (!context.mounted) return true;
    showAppToast(
      context,
      variant: AppToastVariant.removed,
      message: context
          .s('food.shopping_item_removed')
          .replaceFirst('{name}', item.name),
      onUndo: () {
        ref.read(shoppingDaoProvider).insertItem(
              name: item.name,
              quantity: item.quantity,
            );
      },
    );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(_shoppingListProvider).valueOrNull ?? const [];
    final hasChecked = items.any((i) => i.checked);
    final checkedCount = items.where((i) => i.checked).length;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('food.shopping_list_title')),
        actions: [
          // AppBar TextButton «Убрать отмеченные» — дублирует баннер-кнопку
          if (hasChecked)
            TextButton(
              onPressed: () async {
                await ref.read(shoppingDaoProvider).clearChecked();
              },
              child: Text(context.s('food.clear_checked')),
            ),
        ],
      ),
      body: Column(
        children: [
          // --- Поле добавления (24dp горизонтальный отступ, §4.3) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    focusNode: _addFocus,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      hintText: context.s('food.shopping_add_hint'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка добавления — заполненная иконка (FilledButton.icon
                // с одним действием = primary per §4.3; plain IconButton тоже ok
                // для поля-with-button паттерна)
                IconButton(
                  tooltip: context.s('btn.add'),
                  icon: Icon(
                    PhosphorIcons.plusCircle(),
                    color: cs.primary,
                  ),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          // Разделитель (0.5dp hairline)
          Divider(
            height: 1,
            thickness: 0.5,
            color: ext?.border,
          ),

          // --- Секция «Рекомендуется» ---
          const _SuggestedSection(),

          // --- Баннер «Убрать купленные (N)» ---
          if (hasChecked)
            _ClearCheckedBanner(
              key: const ValueKey('clear_checked_banner'),
              count: checkedCount,
              onClear: () async {
                await ref.read(shoppingDaoProvider).clearChecked();
              },
            ),

          // --- Список / пустое состояние ---
          Expanded(
            child: items.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ShoppingTile(
                        key: ValueKey(item.id),
                        item: item,
                        onDismiss: () => _onDismiss(context, item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Баннер «Убрать купленные (N)»
// ---------------------------------------------------------------------------

/// Полноширинная кнопка-баннер над списком. Появляется только если есть
/// отмеченные позиции. FilledButton.tonal — визуально доминирует над TextButton.
class _ClearCheckedBanner extends StatelessWidget {
  const _ClearCheckedBanner({
    super.key,
    required this.count,
    required this.onClear,
  });

  final int count;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonal(
          key: const ValueKey('clear_checked_btn'),
          onPressed: onClear,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(PhosphorIcons.checkCircle(), size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  context
                      .s('food.clear_checked_n')
                      .replaceFirst('{n}', '$count'),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
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
// Строка списка
// ---------------------------------------------------------------------------

class _ShoppingTile extends ConsumerWidget {
  const _ShoppingTile({
    required this.item,
    required this.onDismiss,
    super.key,
  });

  final ShoppingItemsTableData item;
  final Future<bool> Function() onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final faintColor = ext?.textFaint ?? theme.colorScheme.onSurface.withAlpha(120);
    final mutedColor = ext?.textMuted ?? theme.colorScheme.onSurface.withAlpha(153);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      // Фон свайпа: ember (danger semantics) + trash icon
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(
          PhosphorIcons.trash(),
          color: theme.colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) => onDismiss(),
      // §4.2: hairline row — InkWell + Padding + Row, NOT ListTile
      child: InkWell(
        onTap: () {
          ref.read(shoppingDaoProvider).setChecked(item.id, !item.checked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              // Анимированный чек — accent fill (§4.3 positive state)
              AnimatedCheck(
                checked: item.checked,
                color: theme.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              // Название занимает всё доступное место; ellipsis при переполнении
              Expanded(
                child: Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: item.checked
                      ? theme.textTheme.bodyMedium?.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: faintColor,
                        )
                      : theme.textTheme.bodyMedium,
                ),
              ),
              // Количество — textMuted, справа (если задано)
              if (item.quantity != null) ...[
                const SizedBox(width: 8),
                Text(
                  item.quantity!,
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
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
// Секция «Предложения»
// ---------------------------------------------------------------------------

/// Показывает секцию «Suggested for you» с чипами из истории питания.
/// Скрыта целиком, если предложений нет.
class _SuggestedSection extends ConsumerWidget {
  const _SuggestedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(_shoppingSuggestionsProvider);

    final suggestions = suggestionsAsync.valueOrNull;
    if (suggestions == null || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? theme.colorScheme.onSurface.withAlpha(153);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Text(
            context.s('food.suggested_section'),
            style: theme.textTheme.titleSmall?.copyWith(color: mutedColor),
          ),
        ),
        // Горизонтально прокручиваемые чипы (§4.3 choice chip pattern)
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final name = suggestions[index];
              return _SuggestionChip(name: name);
            },
          ),
        ),
        const SizedBox(height: 8),
        Divider(
          height: 1,
          thickness: 0.5,
          color: ext?.border,
        ),
      ],
    );
  }
}

/// Один чип предложения. По тапу добавляет продукт в корзину.
/// Стиль §4.3: accentTint фон + accent border — мягкое приглашение.
class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ext = theme.extension<FocusThemeExtension>();
    // accentTint — мягкий фон (§4.3 suggestion chip)
    final tintColor = ext?.accentTint ?? cs.primary.withAlpha(20);
    final inkColor = ext?.accentInk ?? cs.primary;

    return ActionChip(
      avatar: Icon(PhosphorIcons.plus(), size: 16, color: inkColor),
      label: Text(
        name,
        style: theme.textTheme.bodySmall?.copyWith(color: inkColor),
      ),
      // accentTint фон + тонкая accent-рамка (§4.3)
      backgroundColor: tintColor,
      side: BorderSide(color: cs.primary.withAlpha(100), width: 0.5),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        ref.read(shoppingDaoProvider).insertItem(name: name);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Пустое состояние — KaiMascot (neutral, 64) (§4.2)
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tone = ref.watch(toneProvider);
    final tt = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    final mutedColor = ext?.textMuted ?? Theme.of(context).colorScheme.onSurface.withAlpha(153);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KaiMascot(
              size: 64,
              emotion: KaiEmotion.neutral,
              isHarsh: tone == AppTone.harsh,
            ),
            const SizedBox(height: 16),
            Text(
              context.s('food.shopping_empty'),
              style: tt.bodyMedium?.copyWith(color: mutedColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
