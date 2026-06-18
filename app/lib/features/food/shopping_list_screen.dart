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

// ---------------------------------------------------------------------------
// Провайдер — реактивный список покупок
// ---------------------------------------------------------------------------

/// Реактивный список всех позиций (unchecked сверху, checked снизу).
final _shoppingListProvider =
    StreamProvider.autoDispose<List<ShoppingItemsTableData>>((ref) {
  return ref.watch(shoppingDaoProvider).watchAll();
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
      message: '"${item.name}" removed',
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s('food.shopping_list_title')),
        actions: [
          // «Clear checked» — виден только если есть отмеченные позиции
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
          // --- Поле добавления ---
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
                IconButton(
                  tooltip: context.s('btn.add'),
                  icon: const Icon(Icons.add),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // --- Список / пустое состояние ---
          Expanded(
            child: items.isEmpty
                ? _EmptyState()
                : ListView.builder(
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
    final textMuted = theme.colorScheme.onSurface.withAlpha(120);

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      // Фон при свайпе вправо-влево: красный с иконкой удаления
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.error,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onError),
      ),
      confirmDismiss: (_) => onDismiss(),
      child: ListTile(
        leading: AnimatedCheck(
          checked: item.checked,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        title: Text(
          item.name,
          style: item.checked
              ? TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: textMuted,
                )
              : null,
        ),
        // Количество серым справа (если указано)
        trailing: item.quantity != null
            ? Text(
                item.quantity!,
                style: theme.textTheme.bodySmall?.copyWith(color: textMuted),
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
// Пустое состояние
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurface.withAlpha(80);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 56, color: muted),
          const SizedBox(height: 16),
          Text(
            context.s('food.shopping_empty'),
            style: textTheme.bodyMedium?.copyWith(color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
