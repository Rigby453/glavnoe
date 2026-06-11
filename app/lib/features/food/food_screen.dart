// Экран «Еда» (Health → Food, Phase 1, C5).
// Поиск продукта (Open Food Facts через бэкенд) / штрихкод / ИИ-фото (premium)
// → выбрать граммы/приём → запись. Итоги дня считаются локально из food_logs.
// Числа КБЖУ — из базы (на 100 г), масштабируются под порцию (food_nutrition).

import 'dart:convert' show base64Encode;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../core/animations/ai_insight_reveal.dart';
import '../../core/animations/ai_pulse_dot.dart';
import '../../core/animations/app_sheet.dart';
import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/settings/nutrition_goals_provider.dart';
import '../../services/api/api_client.dart';
import '../auth/auth_controller.dart';
import 'ai_menu_sheet.dart';
import 'barcode_scanner_screen.dart';
import 'food_balance.dart';
import 'food_nutrition.dart';

const List<String> _meals = ['breakfast', 'lunch', 'dinner', 'snack'];

/// Записи о еде за сегодня (реактивно).
final _todayFoodProvider =
    StreamProvider.autoDispose<List<FoodLogsTableData>>((ref) {
  return ref.watch(foodLogsDaoProvider).watchForDay(DateTime.now());
});

Nutrition _logToNutrition(FoodLogsTableData l) => Nutrition(
      calories: l.calories,
      protein: l.protein,
      fat: l.fat,
      carbs: l.carbs,
      sugar: l.sugar,
      fiber: l.fiber,
    );

class FoodScreen extends ConsumerWidget {
  const FoodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final logs = ref.watch(_todayFoodProvider).valueOrNull ??
        const <FoodLogsTableData>[];
    final totals = sumNutrition(logs.map(_logToNutrition));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food'),
        actions: [
          IconButton(
            tooltip: 'My recipes',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => context.push('/recipes'),
          ),
          IconButton(
            tooltip: 'Shopping list',
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () => context.push('/shopping'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSearchSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _TotalsCard(totals: totals),
          const SizedBox(height: 16),
          // Баланс рациона (SPEC C5, rule-based) — только если что-то съедено
          if (logs.isNotEmpty) ...[
            _BalanceCard(totals: totals),
            const SizedBox(height: 16),
          ],
          // «Собрать ИИ» (SPEC C5, premium): меню дня из рецептов и недавних
          // продуктов; числа пересчитывает код, пользователь подтверждает.
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Build my day with AI (Premium)'),
              onPressed: () => showAiMenuSheet(context, ref),
            ),
          ),
          const SizedBox(height: 8),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Nothing logged today.\nTap "Add food" to search a product.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...logs.map((l) => _FoodRow(log: l)),
        ],
      ),
    );
  }
}

/// Карточка «Баланс рациона» — мягкий вердикт + конкретные подсказки (C5).
class _BalanceCard extends ConsumerWidget {
  const _BalanceCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final balance = evaluateDayBalance(
      totals,
      calorieGoal: ref.watch(calorieGoalProvider),
      proteinGoalG: ref.watch(proteinGoalProvider),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  balance.balanced
                      ? Icons.check_circle_outline
                      : Icons.tips_and_updates_outlined,
                  size: 20,
                  color: balance.balanced
                      ? Colors.green
                      : colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text('Balance', style: textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            if (balance.balanced)
              Text(
                'Nicely balanced today — calories, protein, fiber and sugar all on track.',
                style: textTheme.bodyMedium,
              )
            else
              ...balance.hints.map(
                (h) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('· ', style: textTheme.bodyMedium),
                      Expanded(child: Text(h, style: textTheme.bodyMedium)),
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

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({required this.totals});
  final Nutrition totals;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    String g(double? v) => v == null ? '—' : v.round().toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(g(totals.calories), style: textTheme.headlineMedium),
                const SizedBox(width: 6),
                Text('kcal', style: textTheme.bodyMedium),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Macro(label: 'Protein', value: '${g(totals.protein)} g'),
                _Macro(label: 'Fat', value: '${g(totals.fat)} g'),
                _Macro(label: 'Carbs', value: '${g(totals.carbs)} g'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.cookie_outlined,
                    size: 16, color: colorScheme.secondary),
                const SizedBox(width: 4),
                Text('Sugar ${g(totals.sugar)} g', style: textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.grass_outlined,
                    size: 16, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text('Fiber ${g(totals.fiber)} g', style: textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: textTheme.titleMedium),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _FoodRow extends ConsumerWidget {
  const _FoodRow({required this.log});
  final FoodLogsTableData log;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final kcal = log.calories == null ? '—' : '${log.calories!.round()} kcal';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(log.name),
        subtitle: Text('${log.grams.round()} g · ${log.meal} · $kcal',
            style: textTheme.bodySmall),
        trailing: IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () => ref.read(foodLogsDaoProvider).deleteLog(log.id),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Поиск продукта (нижний лист)
// ---------------------------------------------------------------------------

Future<void> _showSearchSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => const _FoodSearchSheet(),
  );
}

class _FoodSearchSheet extends ConsumerStatefulWidget {
  const _FoodSearchSheet();
  @override
  ConsumerState<_FoodSearchSheet> createState() => _FoodSearchSheetState();
}

class _FoodSearchSheetState extends ConsumerState<_FoodSearchSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  String? _error;

  // Подпись от ИИ-фото: «AI: greek salad (86%)» — показывается над результатами
  String? _aiNote;

  // Голосовой ввод (SPEC C5): локальное распознавание речи → строка поиска.
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _listening = false;

  @override
  void dispose() {
    if (_listening) _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _voiceSearch() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final available = await _speech.initialize(
      onStatus: (status) {
        // Распознавание закончилось само (пауза/таймаут) — гасим индикатор.
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Speech recognition is not available on this device'),
        ),
      );
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _controller.text = result.recognizedWords;
        if (result.finalResult) {
          setState(() => _listening = false);
          _search();
        }
      },
    );
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await ref.read(apiClientProvider).foodSearch(q);
      if (!mounted) return;
      setState(() {
        _results = raw.whereType<Map<String, dynamic>>().toList();
        if (_results.isEmpty) _error = 'Nothing found';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add food', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Search a product…',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _listening ? 'Stop listening' : 'Voice input',
                      icon: Icon(
                        _listening ? Icons.mic : Icons.mic_none,
                        color: _listening
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                      onPressed: _voiceSearch,
                    ),
                    IconButton(
                      tooltip: 'Scan barcode',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                    ),
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _search,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            // ИИ-фото (premium): модель называет блюдо, КБЖУ — из базы
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                // Во время запроса AI — пульс вместо иконки (§7.1)
                icon: _loading
                    ? const AiPulseDot(size: 10)
                    : const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('AI photo (Premium)'),
                onPressed: _loading ? null : _aiPhoto,
              ),
            ),
            if (_aiNote != null)
              AiInsightReveal(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(_aiNote!, style: textTheme.bodySmall),
                ),
              ),
            const SizedBox(height: 4),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_error!, style: textTheme.bodyMedium),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final p = _results[i];
                    final per = p['per_100g'] as Map<String, dynamic>?;
                    final kcal = (per?['calories'] as num?)?.round();
                    return ListTile(
                      title: Text((p['name'] as String?) ?? 'Unknown'),
                      subtitle: Text([
                        if (p['brand'] != null) p['brand'] as String,
                        if (kcal != null) '$kcal kcal / 100g',
                      ].join(' · ')),
                      onTap: () => _addProduct(p),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// ИИ-фото еды (premium, AI-03): снимок → /ai/food-recognize → модель
  /// называет блюдо, бэкенд подбирает продукты с КБЖУ из food DB.
  Future<void> _aiPhoto() async {
    final premium = await ref.read(isPremiumProvider.future);
    if (!mounted) return;
    if (!premium) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Premium feature — AI recognizes food photos'),
          action: SnackBarAction(
            label: 'Upgrade',
            onPressed: () => context.push('/paywall'),
          ),
        ),
      );
      return;
    }

    // Камера предпочтительнее для еды; на платформах без камеры — галерея.
    XFile? picked;
    try {
      picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        imageQuality: 75,
      );
    } catch (_) {
      picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 75,
      );
    }
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final mediaType =
        picked.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

    setState(() {
      _loading = true;
      _error = null;
      _aiNote = null;
    });
    try {
      final result = await ref.read(apiClientProvider).aiFoodRecognize(
            imageBase64: base64Encode(bytes),
            mediaType: mediaType,
          );
      if (!mounted) return;

      final dish = (result['dish'] as String?) ?? '';
      final confidence =
          ((result['confidence'] as num?) ?? 0).toDouble().clamp(0.0, 1.0);
      final products = ((result['products'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();

      if (products.isNotEmpty) {
        setState(() {
          _aiNote = 'AI: $dish (${(confidence * 100).round()}%) — pick a match';
          _results = products;
        });
      } else if (dish.isNotEmpty) {
        // База не нашла соответствий — подставляем блюдо в поиск
        _controller.text = dish;
        setState(() =>
            _aiNote = 'AI: $dish (${(confidence * 100).round()}%)');
        await _search();
      } else {
        setState(() => _error = "Couldn't recognize the food — try again");
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Скан штрихкода → /food/barcode → тот же диалог порции, что и поиск.
  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final product = await ref.read(apiClientProvider).foodBarcode(code);
      if (!mounted) return;
      if (product == null) {
        setState(() => _error = 'Product not found for barcode $code');
      } else {
        setState(() => _results = [product]);
        await _addProduct(product);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addProduct(Map<String, dynamic> product) async {
    final result = await showDialog<({double grams, String meal})>(
      context: context,
      builder: (_) => _PortionDialog(name: (product['name'] as String?) ?? ''),
    );
    if (result == null) return;

    final per = product['per_100g'] as Map<String, dynamic>?;
    double? d(String k) => (per?[k] as num?)?.toDouble();
    final per100g = Nutrition(
      calories: d('calories'),
      protein: d('protein'),
      fat: d('fat'),
      carbs: d('carbs'),
      sugar: d('sugar'),
      fiber: d('fiber'),
    );
    final scaled = scaleNutrition(per100g, result.grams);

    await ref.read(foodLogsDaoProvider).addLog(
          date: DateTime.now(),
          meal: result.meal,
          name: (product['name'] as String?) ?? 'Food',
          grams: result.grams,
          calories: scaled.calories,
          protein: scaled.protein,
          fat: scaled.fat,
          carbs: scaled.carbs,
          sugar: scaled.sugar,
          fiber: scaled.fiber,
        );
    if (mounted) Navigator.of(context).pop(); // закрываем лист поиска
  }
}

/// Диалог выбора граммов и приёма пищи.
class _PortionDialog extends StatefulWidget {
  const _PortionDialog({required this.name});
  final String name;
  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  final _grams = TextEditingController(text: '100');
  String _meal = 'snack';

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Grams'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _meals.map((m) {
              return ChoiceChip(
                label: Text(m),
                selected: _meal == m,
                onSelected: (_) => setState(() => _meal = m),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final grams = double.tryParse(_grams.text.trim());
            if (grams == null || grams <= 0) return;
            Navigator.of(context).pop((grams: grams, meal: _meal));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
