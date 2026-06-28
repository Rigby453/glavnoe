// Фокус-сессии (SPEC C8): пресеты 25/5, 50/10, 52/17, 90/20, 67/15.
// Kaname redesign §Phase 5: полный рестайл.
//
// Idle:   heading + пресет-чипы (pill, accentTint when selected) + одна Start CTA.
// Running: большой MM:SS mono-таймер + метка фазы + Pause/Stop (secondary)
//          + Kai ambient в углу (IgnorePointer).
// Трение: PopScope → AlertDialog при попытке уйти с активной сессии.
//
// Дизайн-система (design-tokens v4, REDESIGN-KANAME §4.3):
//   Чипы: accentTint fill + accent border (selected) / surface + hairline (idle).
//   Таймер: displayLarge (40sp) + tabular figures — «мономерные» цифры.
//   Kai: size 56, thinking(work) / neutral(rest), IgnorePointer.
//   Кнопки: ONE FilledButton (Start); Pause/Stop = OutlinedButton (secondary).
//   Иконки: Phosphor (play-fill для Start, pause/play/stop regular для управления).
//   reduce-motion уважается во всех AnimatedContainer/AnimatedOpacity.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../mascot/kai_mascot.dart';

// ---------------------------------------------------------------------------
// Данные пресетов (не переводятся — числовые метки)
// ---------------------------------------------------------------------------

class _Preset {
  const _Preset(this.label, this.workMin, this.breakMin);
  final String label;
  final int workMin;
  final int breakMin;
}

const _presets = [
  _Preset('25 / 5', 25, 5),
  _Preset('50 / 10', 50, 10),
  _Preset('52 / 17', 52, 17),
  _Preset('90 / 20', 90, 20),
  _Preset('67 / 15', 67, 15), // фирменный формат
];

enum _Phase { idle, work, rest }

// ---------------------------------------------------------------------------
// Виджет
// ---------------------------------------------------------------------------

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  int _presetIndex = 0;
  _Phase _phase = _Phase.idle;
  int _secondsLeft = 0;
  bool _running = false;
  Timer? _ticker;
  int _completedFocusBlocks = 0;

  _Preset get _preset => _presets[_presetIndex];

  // Активна ли сессия (не в idle)
  bool get _inSession => _phase != _Phase.idle;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Логика таймера (бизнес-логика не меняется)
  // ---------------------------------------------------------------------------

  void _start() {
    setState(() {
      _phase = _Phase.work;
      _secondsLeft = _preset.workMin * 60;
      _running = true;
    });
    _arm();
  }

  void _arm() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      if (_secondsLeft > 1) {
        setState(() => _secondsLeft--);
        return;
      }
      // Фаза закончилась — переключаем
      setState(() {
        if (_phase == _Phase.work) {
          _completedFocusBlocks++;
          _phase = _Phase.rest;
          _secondsLeft = _preset.breakMin * 60;
        } else {
          _phase = _Phase.work;
          _secondsLeft = _preset.workMin * 60;
        }
      });
    });
  }

  void _togglePause() => setState(() => _running = !_running);

  void _stop() {
    _ticker?.cancel();
    setState(() {
      _phase = _Phase.idle;
      _running = false;
      _secondsLeft = 0;
    });
  }

  // ---------------------------------------------------------------------------
  // Мягкое трение при навигации «назад» из активной сессии
  // ---------------------------------------------------------------------------

  /// Показывает диалог подтверждения и, если пользователь соглашается,
  /// останавливает сессию и возвращается назад.
  Future<void> _showExitDialog(BuildContext context) async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final ext = Theme.of(ctx).extension<FocusThemeExtension>();
        return AlertDialog(
          title: Text(ctx.s('focus.exit_title')),
          content: Text(ctx.s('focus.exit_body')),
          actions: [
            // «Остаться» — не деструктивное, первое
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(ctx.s('focus.exit_stay')),
            ),
            // «Уйти» — деструктивное, ember
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                ctx.s('focus.exit_leave'),
                style: TextStyle(color: ext?.ember),
              ),
            ),
          ],
        );
      },
    );

    if (leave == true && mounted) {
      // Останавливаем сессию → canPop станет true после rebuild.
      // addPostFrameCallback гарантирует pop ПОСЛЕ пересборки PopScope.
      _stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Форматирование таймера MM:SS
  // ---------------------------------------------------------------------------

  String get _mmss {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return PopScope(
      // Системный back разрешён только из idle; во время сессии — трение
      canPop: !_inSession,
      onPopInvoked: (didPop) {
        if (didPop) return; // pop прошёл — ничего не делать
        _showExitDialog(context);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(context.s('focus.title'))),
        body: Padding(
          // 24dp экранные поля (design-tokens §spacing.lg)
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: _inSession
              ? _buildRunning(textTheme, colorScheme, ext)
              : _buildIdle(textTheme, colorScheme, ext),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Idle — выбор пресета
  // ---------------------------------------------------------------------------

  Widget _buildIdle(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Заголовок — headlineMedium (22sp, w500)
        Text(
          context.s('focus.pick_session'),
          style: textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        // Подсказка о форматах — bodySmall, textMuted
        Text(
          context.s('focus.session_hint'),
          style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
        ),
        const SizedBox(height: 24),
        // Пресет-чипы: pill-border, accentTint при выборе (§4.3 tokens)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(
            _presets.length,
            (i) => _buildPresetChip(i, colorScheme, ext, textTheme),
          ),
        ),
        const Spacer(),
        // Счётчик блоков (только если есть хоть один)
        if (_completedFocusBlocks > 0) ...[
          Center(
            child: Text(
              context
                  .s('focus.blocks_today')
                  .replaceAll('{n}', '$_completedFocusBlocks'),
              style: textTheme.bodySmall?.copyWith(color: ext.textMuted),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // Единственная primary CTA на экране — FilledButton (accent)
        FilledButton.icon(
          icon: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 20),
          label: Text(context.s('focus.btn_start')),
          onPressed: _start,
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Один пресет-чип. Pill-форма, animated container.
  Widget _buildPresetChip(
    int index,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    final selected = _presetIndex == index;
    final reduce = reduceMotionOf(context);

    return GestureDetector(
      onTap: () => setState(() => _presetIndex = index),
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : kDurationFast,
        curve: kCurveLift,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          // Выбранный: accentTint подложка; не выбранный: surface
          color: selected ? ext.accentTint : colorScheme.surface,
          borderRadius: BorderRadius.circular(999), // pill
          border: Border.all(
            color: selected ? colorScheme.primary : ext.border,
            width: selected ? 1.0 : 0.5, // hairline vs selected border
          ),
        ),
        child: Text(
          _presets[index].label,
          style: textTheme.labelLarge?.copyWith(
            color: selected ? ext.accentInk : ext.textMuted,
            // Табулярные цифры: ширина цифр фиксирована, не скачет при анимации
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Running — таймер + управление + Kai
  // ---------------------------------------------------------------------------

  Widget _buildRunning(
    TextTheme textTheme,
    ColorScheme colorScheme,
    FocusThemeExtension ext,
  ) {
    final isWork = _phase == _Phase.work;

    // Stack(expand): заполняет всё доступное пространство Scaffold body
    return Stack(
      fit: StackFit.expand,
      children: [
        // Основной контент — вертикально по центру
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Метка фазы — titleMedium: accent(work) / textMuted(rest)
              Text(
                isWork
                    ? context.s('focus.phase_work')
                    : context.s('focus.phase_break'),
                style: textTheme.titleMedium?.copyWith(
                  color: isWork ? colorScheme.primary : ext.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              // Большой таймер MM:SS — displayLarge (40sp) + mono-цифры
              Text(
                _mmss,
                style: textTheme.displayLarge?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              // Пресет-подпись — bodySmall, textFaint (самый тихий)
              Text(
                _preset.label,
                style: textTheme.bodySmall?.copyWith(
                  color: ext.textFaint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 48),
              // Pause/Resume + Stop — оба OutlinedButton (secondary)
              // Flexible позволяет кнопкам сжаться на узких экранах (320px)
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        _running
                            ? PhosphorIcons.pause()
                            : PhosphorIcons.play(),
                        size: 20,
                      ),
                      label: Text(
                        _running
                            ? context.s('focus.btn_pause')
                            : context.s('focus.btn_resume'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _togglePause,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: OutlinedButton.icon(
                      icon: Icon(PhosphorIcons.stop(), size: 20),
                      label: Text(
                        context.s('focus.btn_stop'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _stop,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Kai — ambient в правом нижнем углу.
        // IgnorePointer: не перехватывает тапы, не мешает кнопкам.
        Positioned(
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Consumer(
              builder: (context, ref, _) {
                final showKai = ref.watch(showKaiProvider);
                if (!showKai) return const SizedBox.shrink();
                final isHarsh = ref.watch(toneProvider) == AppTone.harsh;
                final reduce = reduceMotionOf(context);
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: reduce ? Duration.zero : kDurationNormal,
                  child: KaiMascot(
                    size: 56,
                    // thinking — во время работы; neutral — во время перерыва
                    emotion:
                        isWork ? KaiEmotion.thinking : KaiEmotion.neutral,
                    isHarsh: isHarsh,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
