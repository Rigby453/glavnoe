// Экран дыхательных упражнений (SPEC C5 Ф2 «дыхание»).
// Kaname redesign §E:
//   idle    = чипы техник (Box/Calm/Simple + custom) + чипы длительности + Start;
//   running = круговой гид (вдох растёт / выдох сжимается, цвет по фазе) + таймер + Stop;
//   done    = success «Done».
// Движок логики (breathing_engine.dart) не тронут — только визуальный слой.
// Анимация круга следует ANIMATIONS.md §0: effectiveDuration + reduceMotionOf.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/plurals.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/undo_snack_bar.dart';
import 'breathing_custom_providers.dart';
import 'breathing_editor_screen.dart';
import 'breathing_engine.dart';

// Доступные длительности сессии (минуты; label строится через plMinutes в build)
const _sessionDurationMinutes = [1, 3, 5];

/// Длительность fade-анимации подписи фазы.
const _kFadeDuration = Duration(milliseconds: 150);

/// Длительность анимации смены цвета круга.
const _kColorDuration = Duration(milliseconds: 300);

/// Включает «подрагивание» круга на фазе задержки дыхания (Hold).
/// true  → круг чуть вибрирует масштабом («затаённое» дыхание).
/// false → запасной вариант: на задержке круг просто стоит неподвижно.
const kHoldJitter = true;

/// Период одного колебания джиттера на задержке (туда-обратно).
const _kJitterPeriod = Duration(milliseconds: 900);

/// Амплитуда джиттера в долях масштаба (крошечная: ±0.015).
const _kJitterAmplitude = 0.015;

// Тонкая обёртка со своим Scaffold+AppBar — для прямого маршрута /breathing
// (deep-link из block_tool_router.dart: задача с moduleLink='breathing').
// Объединённый экран /mind (mind_screen.dart) использует BreathingSessionBody
// напрямую, без второго AppBar.
class BreathingScreen extends StatelessWidget {
  const BreathingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIcons.wind(), size: 20),
            const SizedBox(width: 8),
            // Flexible: при малой ширине (320px) и крупном textScale (1.5+)
            // текст не выходит за ширину Row в AppBar.
            Flexible(
              child: Text(
                context.s('breathing.title'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: const BreathingSessionBody(),
    );
  }
}

/// Тело дыхательной сессии (выбор техники → активная сессия → завершение).
/// Без своего Scaffold/AppBar — переиспользуется и в [BreathingScreen], и как
/// одна из вкладок объединённого экрана «Практики» (mind_screen.dart).
class BreathingSessionBody extends ConsumerStatefulWidget {
  const BreathingSessionBody({super.key});

  @override
  ConsumerState<BreathingSessionBody> createState() =>
      _BreathingSessionBodyState();
}

class _BreathingSessionBodyState extends ConsumerState<BreathingSessionBody>
    with TickerProviderStateMixin {
  // --- Настройки ---
  // Выбранная техника: 'builtin:<index>' для встроенного пресета либо id
  // пользовательской техники из БД.
  String _selectedId = 'builtin:0';
  int _durationMinutes = 3;

  // Снапшот фаз запущенной сессии (захватывается на _start, чтобы изменения
  // списка техник во время сессии не ломали анимацию).
  List<BreathPhase> _runningPhases = const [];

  // Последний известный список пользовательских техник (обновляется в build).
  List<CustomTechnique> _customTechniques = const [];

  // --- Состояние сессии ---
  bool _running = false;
  bool _done = false;
  // Флаг паузы: таймер/_elapsed заморожены, анимации остановлены.
  bool _paused = false;

  /// Прошедшее время внутри сессии (обновляется тикером).
  Duration _elapsed = Duration.zero;

  /// Оставшееся время (считается от totalDuration - elapsed).
  Duration _remaining = Duration.zero;

  Timer? _ticker;

  // --- Анимация круга (масштаб) ---
  late AnimationController _circleController;
  late Animation<double> _circleScale;

  // Целевой масштаб для AnimationController: 0.6=выдох, 1.0=вдох
  double _targetScale = 0.6;

  // --- Джиттер круга на задержке дыхания (Hold) ---
  // Отдельный repeat-контроллер 0..1; в дельту масштаба превращается через sin.
  late AnimationController _jitterController;
  bool _holdActive = false;

  // --- Анимация цвета круга ---
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;
  Color _currentCircleColor = Colors.transparent;
  Color _targetCircleColor = Colors.transparent;

  // --- Анимация fade подписи фазы ---
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // --- Текущая фаза ---
  String _lastPhaseLabel = '';

  Duration get _totalDuration => Duration(minutes: _durationMinutes);

  /// Фазы выбранной техники (встроенной или пользовательской).
  /// Если выбранная пользовательская техника удалена — откат на первый пресет.
  List<BreathPhase> _phasesForSelected() {
    if (_selectedId.startsWith('builtin:')) {
      final idx = int.tryParse(_selectedId.substring('builtin:'.length)) ?? 0;
      final i = idx.clamp(0, breathingPresets.length - 1);
      return breathingPresets[i].phases;
    }
    for (final t in _customTechniques) {
      if (t.id == _selectedId) return t.phases;
    }
    return breathingPresets[0].phases;
  }

  /// Локализация имени встроенного пресета (имена-данные → ключи переводов).
  String _localizePresetName(String name) {
    switch (name) {
      case 'Box 4-4-4-4':
        return context.s('breathing.preset_box');
      case 'Calm 4-7-8':
        return context.s('breathing.preset_calm');
      case 'Simple 5-5':
        return context.s('breathing.preset_simple');
      default:
        return name;
    }
  }

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BreathingEditorScreen()),
    );
  }

  /// Удаление пользовательской техники с Undo.
  Future<void> _deleteCustom(CustomTechnique t) async {
    final dao = ref.read(customBreathingDaoProvider);
    final snapshot = await dao.getById(t.id);
    if (snapshot == null) return;
    await dao.deleteTechnique(t.id);
    if (_selectedId == t.id) {
      setState(() => _selectedId = 'builtin:0');
    }
    if (!mounted) return;
    showUndoSnackBar(
      context,
      message: '"${t.name}" ${context.s('breathing.removed')}',
      onUndo: () async => dao.restore(snapshot),
    );
  }

  @override
  void initState() {
    super.initState();

    // Анимация масштаба круга
    _circleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _circleScale = Tween<double>(begin: 0.6, end: 0.6).animate(
      CurvedAnimation(parent: _circleController, curve: kCurveLift),
    );

    // Контроллер джиттера: бесконечный repeat, дельту считаем по value через sin.
    _jitterController = AnimationController(
      vsync: this,
      duration: _kJitterPeriod,
    );

    // Анимация цвета круга
    _colorController = AnimationController(
      vsync: this,
      duration: _kColorDuration,
    );
    _colorAnimation = ColorTween(
      begin: Colors.transparent,
      end: Colors.transparent,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));

    // Анимация fade подписи фазы
    _fadeController = AnimationController(
      vsync: this,
      duration: _kFadeDuration,
      value: 1.0,
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Инициализируем цвет после получения контекста
    _currentCircleColor = Theme.of(context).colorScheme.primary;
    _targetCircleColor = _currentCircleColor;
    _colorAnimation = ColorTween(
      begin: _currentCircleColor,
      end: _targetCircleColor,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _circleController.dispose();
    _jitterController.dispose();
    _colorController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Цвет круга по метке фазы
  // Inhale=accent, Exhale=success, Hold=textMuted.
  // ---------------------------------------------------------------------------

  Color _colorForPhaseLabel(String label) {
    final cs = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    switch (label) {
      case 'Inhale':
        return cs.primary;
      case 'Exhale':
        return ext.success;
      case 'Hold':
      default:
        return ext.textMuted;
    }
  }

  // ---------------------------------------------------------------------------
  // Локализация метки фазы (label из engine остаётся на EN для switch-логики)
  // ---------------------------------------------------------------------------

  String _localizePhaseLabel(BuildContext ctx, String engineLabel) {
    switch (engineLabel) {
      case 'Inhale':
        return ctx.s('breathing.inhale');
      case 'Exhale':
        return ctx.s('breathing.exhale');
      case 'Hold':
        return ctx.s('breathing.hold');
      default:
        return engineLabel;
    }
  }

  // ---------------------------------------------------------------------------
  // Запуск / остановка / пауза
  // ---------------------------------------------------------------------------

  void _start() {
    final total = _totalDuration;
    _runningPhases = _phasesForSelected();
    _currentCircleColor = _colorForPhaseLabel('Inhale');
    _targetCircleColor = _currentCircleColor;
    _colorAnimation = ColorTween(
      begin: _currentCircleColor,
      end: _targetCircleColor,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));
    _colorController.value = 1.0;
    _fadeController.value = 1.0;
    _lastPhaseLabel = '';
    _paused = false;
    setState(() {
      _running = true;
      _done = false;
      _elapsed = Duration.zero;
      _remaining = total;
    });
    _arm();
  }

  void _stop() {
    _ticker?.cancel();
    _circleController.stop();
    _jitterController.stop();
    _holdActive = false;
    _colorController.stop();
    setState(() {
      _running = false;
      _done = false;
      _paused = false;
      _elapsed = Duration.zero;
      _remaining = Duration.zero;
      _lastPhaseLabel = '';
    });
  }

  /// Пауза / Продолжить: замораживает _elapsed и анимации дыхательного круга.
  void _togglePause() {
    final reduce = reduceMotionOf(context);
    setState(() => _paused = !_paused);
    if (_paused) {
      if (!reduce) {
        _circleController.stop();
        _jitterController.stop();
        _colorController.stop();
      }
    } else {
      if (!reduce) {
        if (_holdActive) {
          if (!_jitterController.isAnimating) _jitterController.repeat();
        } else {
          if (!_circleController.isCompleted) {
            _circleController.forward(from: _circleController.value);
          }
        }
        if (!_colorController.isCompleted) {
          _colorController.forward(from: _colorController.value);
        }
      }
    }
  }

  void _arm() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_running || _paused) return;
      setState(() {
        _elapsed += const Duration(milliseconds: 50);
        final newRemaining = _totalDuration - _elapsed;
        if (newRemaining <= Duration.zero) {
          _remaining = Duration.zero;
          _running = false;
          _done = true;
          _ticker?.cancel();
          _circleController.stop();
          _jitterController.stop();
          _holdActive = false;
          _colorController.stop();
          return;
        }
        _remaining = newRemaining;
        _updateCircleAnimation();
      });
    });
    _updateCircleAnimation();
  }

  // ---------------------------------------------------------------------------
  // Анимация круга
  // ---------------------------------------------------------------------------

  void _updateCircleAnimation() {
    if (!mounted) return;
    final reduce = reduceMotionOf(context);
    final result = phaseAt(_runningPhases, _elapsed);
    final phase = result.phase;

    if (phase.label != _lastPhaseLabel) {
      _triggerPhaseFade(phase.label, reduce);
      _animateColorToPhase(phase.label, reduce);

      if (!reduce) {
        if (!phase.hold) {
          _holdActive = false;
          _jitterController.stop();
          final phaseDuration = phase.duration;
          _circleController.duration = phaseDuration;
          final from = _targetScale;
          _targetScale = phase.expand ? 1.0 : 0.6;
          _circleScale = Tween<double>(begin: from, end: _targetScale).animate(
            CurvedAnimation(parent: _circleController, curve: kCurveLift),
          );
          _circleController.forward(from: 0.0);
        } else {
          _circleController.stop();
          if (kHoldJitter) {
            _holdActive = true;
            if (!_jitterController.isAnimating) {
              _jitterController.repeat();
            }
          } else {
            _holdActive = false;
            _jitterController.stop();
          }
        }
      }

      _lastPhaseLabel = phase.label;
    }
  }

  Future<void> _triggerPhaseFade(String newLabel, bool reduce) async {
    if (reduce || !mounted) return;
    await _fadeController.reverse();
    if (mounted) _fadeController.forward();
  }

  void _animateColorToPhase(String phaseLabel, bool reduce) {
    if (!mounted) return;
    final newColor = _colorForPhaseLabel(phaseLabel);
    final fromColor = _colorAnimation.value ?? _currentCircleColor;
    _currentCircleColor = fromColor;
    _targetCircleColor = newColor;
    _colorController.stop();
    _colorAnimation = ColorTween(
      begin: fromColor,
      end: newColor,
    ).animate(CurvedAnimation(parent: _colorController, curve: Curves.easeInOut));
    if (reduce) {
      _colorController.value = 1.0;
    } else {
      _colorController.forward(from: 0.0);
    }
  }

  // ---------------------------------------------------------------------------
  // Утилиты
  // ---------------------------------------------------------------------------

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double _jitterDelta() {
    if (!_holdActive) return 0.0;
    return math.sin(_jitterController.value * 2 * math.pi) * _kJitterAmplitude;
  }

  int _phaseSecondsLeft(BreathPhase phase, double phaseProgress) {
    final totalSecs = phase.duration.inSeconds;
    final elapsed = (phaseProgress * totalSecs).floor();
    final left = totalSecs - elapsed;
    return left.clamp(1, totalSecs);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final custom = ref.watch(customTechniquesProvider).valueOrNull ??
        const <CustomTechnique>[];
    _customTechniques = custom;

    return SafeArea(
      child: Padding(
        // 24dp screen margin — spec §4.1
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: _done
            ? _buildDone(textTheme)
            : _running
                ? _buildRunning(textTheme)
                : _buildIdle(textTheme, custom),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Экран выбора пресета и длительности
  // ---------------------------------------------------------------------------

  Widget _buildIdle(TextTheme textTheme, List<CustomTechnique> custom) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Прокручиваемая область: список техник может расти, а textScale —
        // увеличивать высоту. Start закреплён внизу, вне прокрутки.
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.s('breathing.choose_technique'),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 16),

                // Чипы выбора техники: встроенные пресеты + пользовательские.
                // §4.3 choice chips: selected = accentTint + accent border.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final aw = constraints.maxWidth;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < breathingPresets.length; i++)
                          _TechChip(
                            label:
                                _localizePresetName(breathingPresets[i].name),
                            selected: _selectedId == 'builtin:$i',
                            maxContentWidth: aw,
                            onTap: () =>
                                setState(() => _selectedId = 'builtin:$i'),
                          ),
                        // Пользовательские техники — с кнопкой удаления.
                        for (final t in custom)
                          _TechChip(
                            label: t.name,
                            selected: _selectedId == t.id,
                            maxContentWidth: aw,
                            onTap: () => setState(() => _selectedId = t.id),
                            onDelete: () => _deleteCustom(t),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Создать свою технику — ghost-кнопка
                TextButton.icon(
                  onPressed: _openEditor,
                  icon: Icon(PhosphorIcons.plus(), size: 16),
                  label: Text(context.s('breathing.create_button')),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    foregroundColor: ext.accentInk,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  context.s('breathing.duration'),
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                // Чипы длительности — локализованы через plMinutes (§ anti-regression)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final aw = constraints.maxWidth;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _sessionDurationMinutes.map((mins) {
                        return _TechChip(
                          label: plMinutes(context, mins),
                          selected: _durationMinutes == mins,
                          maxContentWidth: aw,
                          onTap: () =>
                              setState(() => _durationMinutes = mins),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Единственное первичное действие — FilledButton (Start)
        FilledButton.icon(
          icon: Icon(PhosphorIcons.play()),
          label: Text(context.s('breathing.start')),
          onPressed: _start,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Экран активной сессии
  // ---------------------------------------------------------------------------

  Widget _buildRunning(TextTheme textTheme) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final reduce = reduceMotionOf(context);

    final result = phaseAt(_runningPhases, _elapsed);
    final phase = result.phase;
    final secsLeft = _phaseSecondsLeft(phase, result.phaseProgress);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Круг — центральный элемент с текстом фазы и счётчиком внутри
        Center(
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _circleController,
              _jitterController,
              _colorController,
              _fadeController,
            ]),
            builder: (context, _) {
              final scale =
                  reduce ? 0.8 : (_circleScale.value + _jitterDelta());
              final circleColor =
                  _colorAnimation.value ?? colorScheme.primary;
              return _BreathCircle(
                scale: scale,
                color: circleColor,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Подпись фазы
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        _localizePhaseLabel(context, phase.label),
                        style: textTheme.headlineSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Обратный счётчик секунд фазы
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Text(
                        '$secsLeft',
                        style: textTheme.titleLarge?.copyWith(
                          color: ext.textMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 40),

        // Оставшееся время сессии — крупный display-таймер
        Center(
          child: Text(
            _formatDuration(_remaining),
            style: textTheme.headlineMedium?.copyWith(
              color: ext.textMuted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 48),

        // Управление: Пауза/Продолжить + Стоп (оба OutlinedButton —
        // не перетягивают акцент у дыхательного круга).
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(
                  _paused ? PhosphorIcons.play() : PhosphorIcons.pause(),
                ),
                label: Text(
                  _paused
                      ? context.s('focus.btn_resume')
                      : context.s('focus.btn_pause'),
                ),
                onPressed: _togglePause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: Icon(PhosphorIcons.stop()),
                label: Text(context.s('breathing.stop')),
                onPressed: _stop,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Экран завершения сессии
  // ---------------------------------------------------------------------------

  Widget _buildDone(TextTheme textTheme) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Иконка завершения — success (Phosphor fill per spec §1 ACCENT DISCIPLINE)
        Center(
          child: Icon(
            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            size: 72,
            color: ext.success,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          '${context.s('breathing.session_complete')} · ${plMinutes(context, _durationMinutes)}',
          style: textTheme.headlineSmall,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        const SizedBox(height: 56),
        // Единственное первичное действие — FilledButton
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.s('btn.done')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chip выбора техники / длительности (§4.3 choice chips)
// ---------------------------------------------------------------------------

/// Универсальный chip для выбора техники и длительности.
/// selected  → accentTint bg + accent border (1dp) + accentInk text.
/// unselected → surface bg + border hairline (0.5dp) + ink text.
/// [onDelete] — если задан, показывает иконку «×» справа.
class _TechChip extends StatelessWidget {
  const _TechChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.maxContentWidth,
    this.onDelete,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  /// Реальная доступная ширина ряда чипов (из LayoutBuilder вокруг Wrap).
  /// Надёжнее MediaQuery: совпадает с фактическим layout и в тесте, и в
  /// узких контейнерах (split-view/планшет).
  final double maxContentWidth;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? ext.accentTint : colorScheme.surface,
          borderRadius: BorderRadius.circular(999), // pill
          border: Border.all(
            color: selected ? colorScheme.primary : ext.border,
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                8,
                onDelete != null ? 4 : 12,
                8,
              ),
              // ConstrainedBox: чип не шире экрана (320px) даже при длинном
              // пользовательском имени и textScale 1.5. Вычитаем: паддинг
              // экрана (48dp) + паддинги чипа (24dp) + иконка удаления (24dp).
              // На 320px: max = 320-48-24 = 248dp (без delete) или 224dp (с delete).
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  // maxContentWidth — уже доступная ширина ряда (без паддинга
                  // экрана); вычитаем паддинги самого чипа и иконку удаления.
                  maxWidth: maxContentWidth - 24 - (onDelete != null ? 24 : 0),
                ),
                child: Text(
                  label,
                  style: textTheme.labelLarge?.copyWith(
                    color: selected ? ext.accentInk : colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 10, 8),
                  child: Icon(
                    PhosphorIcons.x(),
                    size: 14,
                    color: ext.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Виджет круга
// ---------------------------------------------------------------------------

/// Гид дыхания: большое ФИКСИРОВАННОЕ внешнее кольцо (ориентир) + внутренний
/// заполненный круг, который растёт к кольцу на вдохе и сжимается на выдохе.
///
/// [scale] — значение контроллера фазы в диапазоне 0.6 (выдох) … 1.0 (вдох).
/// Внешнее кольцо всегда базового размера 220×220 — статичный ориентир.
/// [child] — контент по центру (подпись фазы + счётчик), НЕ масштабируется.
class _BreathCircle extends StatelessWidget {
  const _BreathCircle({
    required this.scale,
    required this.color,
    this.child,
  });

  final double scale;
  final Color color;
  final Widget? child;

  static const _baseSize = 220.0;

  // Диапазон диаметра внутреннего круга как доли от _baseSize.
  static const _minInnerFraction = 0.30; // выдох (scale = 0.6)
  static const _maxInnerFraction = 0.92; // вдох  (scale = 1.0)

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    // Маппинг 0.6..1.0 → 0.30..0.92, с защитой от выхода за границы.
    final t = ((scale - 0.6) / 0.4).clamp(0.0, 1.0);
    final innerFraction =
        _minInnerFraction + t * (_maxInnerFraction - _minInnerFraction);
    final innerSize = _baseSize * innerFraction;

    return SizedBox(
      width: _baseSize,
      height: _baseSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Внешнее кольцо — фиксированный ориентир (ext.border hairline).
          Container(
            width: _baseSize,
            height: _baseSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: ext.border,
                width: 1.0,
              ),
            ),
          ),
          // Ореол: мягкая засветка цветом фазы под внутренним кругом.
          Container(
            width: innerSize + 24,
            height: innerSize + 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.08),
            ),
          ),
          // Внутренний заполненный круг — растёт/сжимается по фазе.
          Container(
            width: innerSize,
            height: innerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.20),
              border: Border.all(
                color: color.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
          ),
          // Текст по центру — полный размер, поверх круга, без масштабирования.
          ?child,
        ],
      ),
    );
  }
}
