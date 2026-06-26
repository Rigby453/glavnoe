// Экран «Список покупок» (SPEC C5, Phase 1).
// Локальный, офлайн-первый. Синхронизация с бэкендом — Фаза 3.
// Нет новых пакетов: drift + riverpod + go_router + uuid.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/animations/animated_check.dart';
import '../../core/animations/app_toast.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/theme/app_theme.dart';
import 'shopping_suggestions.dart';

// ---------------------------------------------------------------------------
// Провайдеры
// ---------------------------------------------------------------------------

/// Реактивный список всех позиций (unchecked сверху, checked снизу).
final _shoppingListProvider =
    StreamProvider.autoDispose<List<ShoppingItemsTableData>>((ref) {
  return ref.watch(shoppingDaoProvider).watchAll();
});

/// Провайдер предложений: следит за корзиной и историей еды,
/// возвращает отсортированный список рекомендуемых имён продуктов.
/// autoDispose — освобождается при уходе с экрана.
final _shoppingSuggestionsProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  // Читаем текущую корзину реактивно (следим через AsyncValue)
  final basketAsync = ref.watch(_shoppingListProvider);
  final basket = basketAsync.valueOrNull ?? const [];
  final basketNames = basket.map((i) => i.name).toSet();

  // Одноразово читаем последние 30 дней логов еды (Future, не Stream)
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

  // Добавляем позицию; после добавления очищаем поле и возвращаем фокус.
  Future<void> _submit() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;
    _addController.clear();
    _addFocus.requestFocus();
    await ref.read(shoppingDaoProvider).insertItem(name: text);
  }

  // Свайп-удаление: показываем тост «removed» с кнопкой Undo.
  // Undo вставляет элемент заново с новым UUID (офлайн-первый, без конфликтов).
  Future<bool> _onDismiss(
    BuildContext context,
    ShoppingItemsTableData item,
  ) async {
    await ref.read(shoppingDaoProvider).deleteItem(item.id);
    if (!context.mounted) return true;
    showAppToast(
      context,
      variant: AppToastVariant.removed,
      // Локализованное сообщение с подстановкой имени позиции
      message: context.s('food.shopping_item_removed').replaceFirst('{name}', item.name),
      onUndo: () {
        // Вставляем заново с новым UUID и теми же данными
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
    final ext = Theme.of(context).extension<FocusThemeExtension>();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('food.shopping_list_title')),
        actions: [
          // «Clear checked» — виден только если есть отмеченные позиции
          // TextButton (лёгкое действие) — не нужен FilledButton
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
          // --- Поле добавления (24dp горизонтальный отступ) ---
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
                // Кнопка добавления — IconButton (не FilledButton, чтобы не перетягивать акцент)
                IconButton(
                  tooltip: context.s('btn.add'),
                  icon: Icon(
                    Icons.add_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          // Разделитель — тонкий (0.5dp) без лишней высоты
          Divider(
            height: 1,
            thickness: 0.5,
            color: ext?.border,
          ),

          // --- Секция «Рекомендуется» (скрыта, если предложений нет) ---
          const _SuggestedSection(),

          // --- Список / пустое состояние ---
          Expanded(
            child: items.isEmpty
                ? _EmptyState()
                : ListView.builder(
                    // Небольшой вертикальный отступ вверху списка
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
    // textFaint — для зачёркнутых (выполненных) позиций
    final faintColor = ext?.textFaint ?? theme.colorScheme.onSurface.withAlpha(120);
    // textMuted — для количества
    final mutedColor = ext?.textMuted ?? theme.colorScheme.onSurface.withAlpha(153);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      // Фон при свайпе: colorScheme.error (= ember семантика)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) => onDismiss(),
      child: ListTile(
        // Чекбокс-анимация — accent (выполнено = positiveState, 03-components §1)
        leading: AnimatedCheck(
          checked: item.checked,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        title: Text(
          item.name,
          style: item.checked
              ? theme.textTheme.bodyLarge?.copyWith(
                  decoration: TextDecoration.lineThrough,
                  color: faintColor,
                )
              : null,
        ),
        // Количество — bodySmall muted справа
        trailing: item.quantity != null
            ? Text(
                item.quantity!,
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              )
            : null,
        onTap: () {
          ref
              .read(shoppingDaoProvider)
              .setChecked(item.id, !item.checked);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Секция «Предложения на основе истории»
// ---------------------------------------------------------------------------

/// Показывает раздел «Recommended for you» с чипами продуктов из истории питания.
/// Если предложений нет (история пустая / всё уже в корзине) — скрыта целиком.
class _SuggestedSection extends ConsumerWidget {
  const _SuggestedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(_shoppingSuggestionsProvider);

    // Пока загружается или нет предложений — ничего не показываем
    final suggestions = suggestionsAsync.valueOrNull;
    if (suggestions == null || suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ?? theme.colorScheme.onSurface.withAlpha(153);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок секции — стиль titleSmall muted, как в _SectionHeader task_list
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
          child: Text(
            context.s('food.suggested_section'),
            style: theme.textTheme.titleSmall?.copyWith(color: mutedColor),
          ),
        ),
        // Горизонтально прокручиваемый ряд чипов
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
            itemCount: suggestions.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final name = suggestions[index];
              return _SuggestionChip(name: name);
            },
          ),
        ),
        // Нижний разделитель перед основным списком
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
class _SuggestionChip extends ConsumerWidget {
  const _SuggestionChip({required this.name});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ext = theme.extension<FocusThemeExtension>();
    final mutedColor =
        ext?.textMuted ?? theme.colorScheme.onSurface.withAlpha(153);

    return ActionChip(
      // Иконка «+» как affordance
      avatar: Icon(
        Icons.add,
        size: 16,
        color: mutedColor,
      ),
      label: Text(
        name,
        style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
      ),
      // Визуально лёгкий: нет заливки, тонкая рамка border-цвета темы
      backgroundColor: Colors.transparent,
      side: BorderSide(
        color: ext?.border ?? theme.colorScheme.outline.withAlpha(80),
        width: 0.8,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () {
        ref.read(shoppingDaoProvider).insertItem(name: name);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Пустое состояние
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>();
    // textFaint — третичный уровень для пустых состояний
    final faintColor = ext?.textFaint ?? Theme.of(context).colorScheme.onSurface.withAlpha(80);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 56, color: faintColor),
            const SizedBox(height: 16),
            Text(
              context.s('food.shopping_empty'),
              style: textTheme.bodyMedium?.copyWith(color: faintColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
