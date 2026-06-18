// Фокус-сессии (SPEC C8): пресеты 25/5, 50/10, 52/17, 90/20 и фирменный 67/15.
// Таймер с фазами работа/перерыв, Пауза/Стоп. Локальное эфемерное состояние
// (тикающий таймер) → StatefulWidget с Timer; бизнес-данных тут нет.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../mascot/kai_mascot.dart';

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
  _Preset('67 / 15', 67, 15), // фирменный
];

enum _Phase { idle, work, rest }

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

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

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
      // Фаза закончилась — переключаемся
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

  String get _mmss {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final idle = _phase == _Phase.idle;

    return Scaffold(
      appBar: AppBar(title: Text(context.s('focus.title'))),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: idle ? _buildIdle(textTheme) : _buildRunning(textTheme, colorScheme),
      ),
    );
  }

  Widget _buildIdle(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.s('focus.pick_session'), style: textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(context.s('focus.session_hint'), style: textTheme.bodySmall),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_presets.length, (i) {
            return ChoiceChip(
              label: Text(_presets[i].label),
              selected: _presetIndex == i,
              onSelected: (_) => setState(() => _presetIndex = i),
            );
          }),
        ),
        const Spacer(),
        if (_completedFocusBlocks > 0)
          Center(
            child: Text(
              context
                  .s('focus.blocks_today')
                  .replaceAll('{n}', '$_completedFocusBlocks'),
              style: textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.play_arrow),
          label: Text(context.s('focus.btn_start')),
          onPressed: _start,
        ),
      ],
    );
  }

  Widget _buildRunning(TextTheme textTheme, ColorScheme colorScheme) {
    final isWork = _phase == _Phase.work;
    // Kai в углу при активной сессии — ambient, не добавляет тапов (MASCOT.md §6).
    // Используем Consumer точечно, чтобы не менять тип виджета на ConsumerStatefulWidget.
    return Stack(
      children: [
        // Основной контент по центру
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isWork ? context.s('focus.phase_work') : context.s('focus.phase_break'),
              style: textTheme.titleLarge?.copyWith(
                color: isWork ? colorScheme.primary : colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _mmss,
              style: textTheme.displayLarge?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            Text(_preset.label, style: textTheme.bodyMedium),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    _running
                        ? context.s('focus.btn_pause')
                        : context.s('focus.btn_resume'),
                  ),
                  onPressed: _togglePause,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.stop),
                  label: Text(context.s('focus.btn_stop')),
                  onPressed: _stop,
                ),
              ],
            ),
          ],
        ),

        // Kai — тихо «дышит» в правом нижнем углу.
        // IgnorePointer: не перехватывает тапы, не перекрывает кнопки.
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
                  opacity: showKai ? 1.0 : 0.0,
                  duration: reduce ? Duration.zero : kDurationNormal,
                  child: KaiMascot(
                    size: 40,
                    // Во время работы — thinking (сосредоточен вместе с пользователем);
                    // во время перерыва — neutral (спокойно отдыхает).
                    emotion: isWork ? KaiEmotion.thinking : KaiEmotion.neutral,
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
