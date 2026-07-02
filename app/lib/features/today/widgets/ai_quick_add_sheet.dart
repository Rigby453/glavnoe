// ИИ-квик-адд (Волна 6, этап 2, docs/AI-ONBOARDING-DESIGN.md).
//
// Голос/текст → POST /api/v1/ai/quick-add → превью-подтверждение через
// showAddTaskSheet(prefill: ...) (решение B). Сохранение делает add_task_sheet
// (Drift insert + sync) — здесь сеть НЕ пишет ничего в БД напрямую.
//
// Premium-гейт (как в других AI-местах): проверяется в showAiQuickAddSheet
// ДО открытия листа — если фичи нет, юзер сразу видит апсейл-снекбар вместо
// пустого голосового листа, который всё равно упрётся в 403.
//
// Sheet-паттерн: AppSheetContent (handle · title · X) — §4.3 Kaname redesign.
// Overflow-safe: 320px / textScale 2.0 / клавиатура — Expanded/ellipsis везде.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/animations/app_sheet.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/l10n/locale_provider.dart';
import '../../../core/settings/timezone_provider.dart';
import '../../../core/widgets/kai_loader.dart';
import '../../../core/widgets/voice_text_field.dart';
import '../../../services/api/api_client.dart';
import '../../auth/auth_controller.dart' show isPremiumProvider;
import '../../paywall/paywall_screen.dart' show showPremiumUpsell;
import 'add_task_sheet.dart';

/// Результат успешного разбора фразы — передаётся из листа наружу через
/// [Navigator.pop], чтобы открыть превью-подтверждение уже НАД исходным
/// (Today/Plan) контекстом, а не над закрывающимся листом.
class _QuickAddResult {
  const _QuickAddResult({required this.prefill, required this.day});
  final AddTaskPrefill prefill;
  final DateTime day;
}

/// Открывает лист ИИ-быстрого добавления задачи.
///
/// [day] — день, на который по умолчанию заводится задача, если ответ ИИ не
/// содержит своей даты (используется и для проверки лимита main-задач в
/// превью-подтверждении). По умолчанию — сегодня.
///
/// Premium-гейт выполняется ЗДЕСЬ, до открытия листа: если фичи нет — сразу
/// апсейл-снекбар (showPremiumUpsell), лист не открывается.
Future<void> showAiQuickAddSheet(
  BuildContext context,
  WidgetRef ref, {
  DateTime? day,
}) async {
  final premium = await ref.read(isPremiumProvider.future);
  if (!context.mounted) return;
  if (!premium) {
    showPremiumUpsell(context, context.s('today.ai_quick_add_feature_name'));
    return;
  }

  final targetDay = day ?? DateTime.now();
  final result = await showAppSheet<_QuickAddResult>(
    context,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: _AiQuickAddSheet(day: targetDay),
    ),
  );

  // Лист уже закрылся (returned) — открываем превью-подтверждение поверх
  // исходного экрана (Today/Plan), тем же путём, что и обычное «+».
  if (result == null) return;
  if (!context.mounted) return;
  await showAddTaskSheet(context, day: result.day, prefill: result.prefill);
}

// ---------------------------------------------------------------------------
// Разбор ответа /ai/quick-add → AddTaskPrefill (чистая функция — тестируема)
// ---------------------------------------------------------------------------

/// Разбирает тело ответа `{ task: {...} }` в [AddTaskPrefill].
///
/// Возвращает null, если в ответе нет задачи с непустым заголовком (ИИ не
/// смог разобрать фразу) — вызывающий код показывает `today.ai_quick_add_parse_error`.
///
/// Маппинг deadline (решение C, AI-ONBOARDING-DESIGN.md): если задан `deadline`
/// и НЕТ `scheduled_at` → type='deadline', scheduledAt=deadline.
/// `note` (место/детали фразы) маппится в поле «Место» формы через
/// [AddTaskPrefill.note] (в Items нет отдельной колонки note).
AddTaskPrefill? parseQuickAddResponse(Map<String, dynamic> response) {
  final task = response['task'];
  if (task is! Map) return null;
  final map = Map<String, dynamic>.from(task);

  final title = (map['title'] as String?)?.trim();
  if (title == null || title.isEmpty) return null;

  String? type = map['type'] as String?;
  final priority = map['priority'] as String?;
  final scheduledAtRaw = map['scheduled_at'] as String?;
  final deadlineRaw = map['deadline'] as String?;
  var scheduledAt =
      scheduledAtRaw != null ? DateTime.tryParse(scheduledAtRaw)?.toLocal() : null;
  final deadline =
      deadlineRaw != null ? DateTime.tryParse(deadlineRaw)?.toLocal() : null;

  if (scheduledAt == null && deadline != null) {
    type = 'deadline';
    scheduledAt = deadline;
  }

  final durationRaw = map['duration_minutes'];
  final durationMinutes = durationRaw is num ? durationRaw.toInt() : null;
  final note = (map['note'] as String?)?.trim();

  return AddTaskPrefill(
    title: title,
    type: type,
    priority: priority,
    scheduledAt: scheduledAt,
    durationMinutes: durationMinutes,
    note: (note == null || note.isEmpty) ? null : note,
  );
}

/// Определяет IANA-таймзону для запроса: override пользователя
/// (`timezoneOverrideProvider`), иначе — зона устройства (FlutterTimezone).
/// На вебе/при ошибке — 'UTC' (сервер всё равно принимает любой валидный
/// идентификатор; расхождение на вебе не критично для превью-подтверждения).
Future<String> resolveQuickAddTimezone(WidgetRef ref) async {
  final override = ref.read(timezoneOverrideProvider);
  if (!override.isAuto && override.iana != null && override.iana!.isNotEmpty) {
    return override.iana!;
  }
  if (kIsWeb) return 'UTC';
  try {
    final info = await FlutterTimezone.getLocalTimezone();
    return info.identifier;
  } catch (_) {
    return 'UTC';
  }
}

// ---------------------------------------------------------------------------
// _AiQuickAddSheet — виджет листа
// ---------------------------------------------------------------------------

class _AiQuickAddSheet extends ConsumerStatefulWidget {
  const _AiQuickAddSheet({required this.day});

  final DateTime day;

  @override
  ConsumerState<_AiQuickAddSheet> createState() => _AiQuickAddSheetState();
}

class _AiQuickAddSheetState extends ConsumerState<_AiQuickAddSheet> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Перерисовка, чтобы кнопка отправки включалась/выключалась по тексту.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => _controller.text.trim().isNotEmpty && !_loading;

  /// Снекбар с ошибкой + кнопкой «Повторить» (§ спека: 502/503 → понятная
  /// ошибка + retry). Лист остаётся открытым, текст сохраняется — повтор
  /// просто дёргает [_send] заново.
  void _showErrorSnack(String messageKey) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(context.s(messageKey)),
          action: SnackBarAction(
            label: context.s('today.ai_quick_add_retry'),
            onPressed: _send,
          ),
        ),
      );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() => _loading = true);

    try {
      final timezone = await resolveQuickAddTimezone(ref);
      if (!mounted) return;
      final locale = localeTag(ref.read(localeNotifierProvider));
      final date = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await ref.read(apiClientProvider).aiQuickAdd(
            text: text,
            date: date,
            timezone: timezone,
            locale: locale,
          );

      final prefill = parseQuickAddResponse(response);
      if (!mounted) return;
      if (prefill == null) {
        setState(() => _loading = false);
        _showErrorSnack('today.ai_quick_add_parse_error');
        return;
      }

      // Задача может относиться к другому дню, чем открытие листа (напр.
      // «завтра в 9») — превью-подтверждение открывается на день из ответа.
      final targetDay = prefill.scheduledAt != null
          ? DateTime(prefill.scheduledAt!.year, prefill.scheduledAt!.month,
              prefill.scheduledAt!.day)
          : widget.day;

      Navigator.of(context)
          .pop(_QuickAddResult(prefill: prefill, day: targetDay));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.statusCode == 403) {
        Navigator.of(context).pop();
        showPremiumUpsell(context, context.s('today.ai_quick_add_feature_name'));
        return;
      }
      // 502/503 (ИИ недоступен) и прочие сетевые сбои — единое понятное
      // сообщение с кнопкой повтора; технический текст e.message не нужен
      // пользователю (Kaname — «понятная ошибка», не стектрейс).
      _showErrorSnack('today.ai_quick_add_error');
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showErrorSnack('today.ai_quick_add_error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetContent(
      title: context.s('today.ai_quick_add_title'),
      primaryButton: FilledButton.icon(
        onPressed: _canSend ? _send : null,
        icon: Icon(PhosphorIcons.sparkle(PhosphorIconsStyle.fill), size: 18),
        label: Text(context.s('today.ai_quick_add_send')),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_loading) ...[
              Center(
                child: KaiLoader(label: context.s('today.ai_quick_add_loading')),
              ),
              const SizedBox(height: 16),
            ] else ...[
              // labelText = hint-текст (а не заголовок листа) — иначе
              // плавающий label поля дублирует заголовок AppSheetContent
              // (два одинаковых Text("AI quick add") в дереве).
              VoiceTextField(
                controller: _controller,
                labelText: context.s('today.ai_quick_add_hint'),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}
