// Экран медитаций — перестилизован под «Kaname» redesign (§4.2 cards + Phosphor).
// Бизнес-логика, данные сессий и аудио/TTS НЕ изменены — только визуал/UX.
//
// Изменения: карточки surface1 + 0.5dp hairline + R14, Phosphor-иконки,
// форматтер таймера в MM:SS (без хардкода 's'), audio-панель с Phosphor.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/database/database_providers.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/l10n/plurals.dart';
import '../../core/mood/meditation_mood_log.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/swipe_to_delete.dart';
import '../../core/widgets/undo_snack_bar.dart';
import 'meditation_audio.dart';
import 'meditation_custom_providers.dart';
import 'meditation_editor_screen.dart';

// ---------------------------------------------------------------------------
// Модели данных — без изменений
// ---------------------------------------------------------------------------

class _Step {
  const _Step({required this.textKey, required this.seconds});
  final String textKey;
  final int seconds;
}

class _RunStep {
  const _RunStep({required this.text, required this.seconds});
  final String text;
  final int seconds;
}

class _RunSession {
  const _RunSession({
    required this.id,
    required this.name,
    required this.steps,
  });
  final String id;
  final String name;
  final List<_RunStep> steps;
}

// _Session — не const: poseIcon хранит IconData из PhosphorIcons.xxx(),
// которые не являются const-выражениями.
class _Session {
  _Session({
    required this.id,
    required this.nameKey,
    required this.duration,
    required this.descKey,
    required this.steps,
    required this.poseNameKey,
    required this.poseDescKey,
    required this.poseIcon,
  });
  final String id;
  final String nameKey;
  final int duration;
  final String descKey;
  final List<_Step> steps;
  final String poseNameKey;
  final String poseDescKey;
  final IconData poseIcon; // Phosphor IconData (bed/personSimpleTaiChi/sun/moon/flowerLotus)
}

// Иконки поз через Phosphor — lazy, вычисляются один раз.
final _sessions = <_Session>[
  _Session(
    id: 'body_scan',
    nameKey: 'meditation.body_scan.name',
    duration: 10,
    descKey: 'meditation.body_scan.desc',
    poseNameKey: 'meditation.body_scan.pose_name',
    poseDescKey: 'meditation.body_scan.pose_desc',
    poseIcon: PhosphorIcons.bed(), // лёжа на спине
    steps: const [
      _Step(textKey: 'meditation.body_scan.step1', seconds: 60),
      _Step(textKey: 'meditation.body_scan.step2', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step3', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step4', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step5', seconds: 90),
      _Step(textKey: 'meditation.body_scan.step6', seconds: 90),
    ],
  ),
  _Session(
    id: 'focus_reset',
    nameKey: 'meditation.focus_reset.name',
    duration: 5,
    descKey: 'meditation.focus_reset.desc',
    poseNameKey: 'meditation.focus_reset.pose_name',
    poseDescKey: 'meditation.focus_reset.pose_desc',
    poseIcon: PhosphorIcons.personSimpleTaiChi(), // прямая посадка
    steps: const [
      _Step(textKey: 'meditation.focus_reset.step1', seconds: 30),
      _Step(textKey: 'meditation.focus_reset.step2', seconds: 60),
      _Step(textKey: 'meditation.focus_reset.step3', seconds: 60),
      _Step(textKey: 'meditation.focus_reset.step4', seconds: 60),
      _Step(textKey: 'meditation.focus_reset.step5', seconds: 30),
    ],
  ),
  _Session(
    id: 'exam_calm',
    nameKey: 'meditation.exam_calm.name',
    duration: 7,
    descKey: 'meditation.exam_calm.desc',
    poseNameKey: 'meditation.exam_calm.pose_name',
    poseDescKey: 'meditation.exam_calm.pose_desc',
    poseIcon: PhosphorIcons.personSimpleTaiChi(), // устойчивая посадка
    steps: const [
      _Step(textKey: 'meditation.exam_calm.step1', seconds: 60),
      _Step(textKey: 'meditation.exam_calm.step2', seconds: 90),
      _Step(textKey: 'meditation.exam_calm.step3', seconds: 90),
      _Step(textKey: 'meditation.exam_calm.step4', seconds: 60),
      _Step(textKey: 'meditation.exam_calm.step5', seconds: 60),
    ],
  ),
  _Session(
    id: 'sleep_prep',
    nameKey: 'meditation.sleep_prep.name',
    duration: 15,
    descKey: 'meditation.sleep_prep.desc',
    poseNameKey: 'meditation.sleep_prep.pose_name',
    poseDescKey: 'meditation.sleep_prep.pose_desc',
    poseIcon: PhosphorIcons.bed(), // лёжа в постели
    steps: const [
      _Step(textKey: 'meditation.sleep_prep.step1', seconds: 60),
      _Step(textKey: 'meditation.sleep_prep.step2', seconds: 90),
      _Step(textKey: 'meditation.sleep_prep.step3', seconds: 90),
      _Step(textKey: 'meditation.sleep_prep.step4', seconds: 90),
      _Step(textKey: 'meditation.sleep_prep.step5', seconds: 120),
      _Step(textKey: 'meditation.sleep_prep.step6', seconds: 120),
      _Step(textKey: 'meditation.sleep_prep.step7', seconds: 120),
    ],
  ),
  _Session(
    id: 'stress_relief',
    nameKey: 'meditation.stress_relief.name',
    duration: 8,
    descKey: 'meditation.stress_relief.desc',
    poseNameKey: 'meditation.stress_relief.pose_name',
    poseDescKey: 'meditation.stress_relief.pose_desc',
    poseIcon: PhosphorIcons.personSimpleTaiChi(), // удобная поза сидя
    steps: const [
      _Step(textKey: 'meditation.stress_relief.step1', seconds: 40),
      _Step(textKey: 'meditation.stress_relief.step2', seconds: 80),
      _Step(textKey: 'meditation.stress_relief.step3', seconds: 80),
      _Step(textKey: 'meditation.stress_relief.step4', seconds: 80),
      _Step(textKey: 'meditation.stress_relief.step5', seconds: 60),
      _Step(textKey: 'meditation.stress_relief.step6', seconds: 60),
    ],
  ),
  _Session(
    id: 'anxiety_reset',
    nameKey: 'meditation.anxiety_reset.name',
    duration: 5,
    descKey: 'meditation.anxiety_reset.desc',
    poseNameKey: 'meditation.anxiety_reset.pose_name',
    poseDescKey: 'meditation.anxiety_reset.pose_desc',
    poseIcon: PhosphorIcons.personSimpleTaiChi(), // устойчивая посадка
    steps: const [
      _Step(textKey: 'meditation.anxiety_reset.step1', seconds: 30),
      _Step(textKey: 'meditation.anxiety_reset.step2', seconds: 60),
      _Step(textKey: 'meditation.anxiety_reset.step3', seconds: 60),
      _Step(textKey: 'meditation.anxiety_reset.step4', seconds: 60),
      _Step(textKey: 'meditation.anxiety_reset.step5', seconds: 60),
    ],
  ),
  _Session(
    id: 'morning_wake',
    nameKey: 'meditation.morning_wake.name',
    duration: 5,
    descKey: 'meditation.morning_wake.desc',
    poseNameKey: 'meditation.morning_wake.pose_name',
    poseDescKey: 'meditation.morning_wake.pose_desc',
    poseIcon: PhosphorIcons.sun(), // прямая посадка / стоя
    steps: const [
      _Step(textKey: 'meditation.morning_wake.step1', seconds: 30),
      _Step(textKey: 'meditation.morning_wake.step2', seconds: 60),
      _Step(textKey: 'meditation.morning_wake.step3', seconds: 60),
      _Step(textKey: 'meditation.morning_wake.step4', seconds: 60),
      _Step(textKey: 'meditation.morning_wake.step5', seconds: 30),
    ],
  ),
  _Session(
    id: 'gratitude_reset',
    nameKey: 'meditation.gratitude_reset.name',
    duration: 8,
    descKey: 'meditation.gratitude_reset.desc',
    poseNameKey: 'meditation.gratitude_reset.pose_name',
    poseDescKey: 'meditation.gratitude_reset.pose_desc',
    poseIcon: PhosphorIcons.flowerLotus(), // удобная сидя / лёжа
    steps: const [
      _Step(textKey: 'meditation.gratitude_reset.step1', seconds: 60),
      _Step(textKey: 'meditation.gratitude_reset.step2', seconds: 120),
      _Step(textKey: 'meditation.gratitude_reset.step3', seconds: 90),
      _Step(textKey: 'meditation.gratitude_reset.step4', seconds: 90),
      _Step(textKey: 'meditation.gratitude_reset.step5', seconds: 60),
    ],
  ),
  _Session(
    id: 'deep_work_entry',
    nameKey: 'meditation.deep_work_entry.name',
    duration: 4,
    descKey: 'meditation.deep_work_entry.desc',
    poseNameKey: 'meditation.deep_work_entry.pose_name',
    poseDescKey: 'meditation.deep_work_entry.pose_desc',
    poseIcon: PhosphorIcons.personSimpleTaiChi(), // рабочая посадка за столом
    steps: const [
      _Step(textKey: 'meditation.deep_work_entry.step1', seconds: 30),
      _Step(textKey: 'meditation.deep_work_entry.step2', seconds: 60),
      _Step(textKey: 'meditation.deep_work_entry.step3', seconds: 90),
      _Step(textKey: 'meditation.deep_work_entry.step4', seconds: 30),
    ],
  ),
  _Session(
    id: 'evening_unwind',
    nameKey: 'meditation.evening_unwind.name',
    duration: 10,
    descKey: 'meditation.evening_unwind.desc',
    poseNameKey: 'meditation.evening_unwind.pose_name',
    poseDescKey: 'meditation.evening_unwind.pose_desc',
    poseIcon: PhosphorIcons.moon(), // лёжа / откинувшись в кресле
    steps: const [
      _Step(textKey: 'meditation.evening_unwind.step1', seconds: 60),
      _Step(textKey: 'meditation.evening_unwind.step2', seconds: 90),
      _Step(textKey: 'meditation.evening_unwind.step3', seconds: 90),
      _Step(textKey: 'meditation.evening_unwind.step4', seconds: 60),
      _Step(textKey: 'meditation.evening_unwind.step5', seconds: 90),
      _Step(textKey: 'meditation.evening_unwind.step6', seconds: 120),
    ],
  ),
];

// Резолвит встроенную сессию в рантайм-модель плеера.
_RunSession _builtinToRun(BuildContext context, _Session session) {
  return _RunSession(
    id: session.id,
    name: context.s(session.nameKey),
    steps: session.steps
        .map((st) => _RunStep(text: context.s(st.textKey), seconds: st.seconds))
        .toList(),
  );
}

// Резолвит пользовательскую сессию (СЫРОЙ текст) в рантайм-модель.
_RunSession _customToRun(CustomMeditation m) {
  return _RunSession(
    id: m.id,
    name: m.name,
    steps: m.steps
        .map((st) => _RunStep(text: st.text, seconds: st.seconds))
        .toList(),
  );
}

void _openPlayer(BuildContext context, _RunSession session) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _SessionPlayerScreen(session: session),
    ),
  );
}

// Превью позы для встроенной сессии — показываем ПЕРЕД плеером.
void _openPosePreview(BuildContext context, _Session session) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => _PosePreviewScreen(session: session),
    ),
  );
}

// ---------------------------------------------------------------------------
// Вспомогательный виджет: круглая иконка-аватар для карточки
// ---------------------------------------------------------------------------

Widget _buildSessionAvatar({
  required FocusThemeExtension ext,
  required IconData icon,
  double size = 44,
  double iconSize = 20,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: ext.accentMuted,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: ext.textMuted, size: iconSize),
  );
}

// ---------------------------------------------------------------------------
// Session list screen
// ---------------------------------------------------------------------------

// Тонкая обёртка со своим Scaffold+AppBar — для прямого маршрута /meditation
// (deep-link из block_tool_router.dart: задача с moduleLink='meditation').
// Объединённый экран /mind (mind_screen.dart) использует MeditationLibraryBody
// напрямую, без второго AppBar.
class MeditationScreen extends StatelessWidget {
  const MeditationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.s('meditation.title'))),
      body: const MeditationLibraryBody(),
    );
  }
}

/// Тело экрана медитаций (список встроенных + пользовательских сессий).
/// Без своего Scaffold/AppBar — переиспользуется и в [MeditationScreen],
/// и как одна из вкладок объединённого экрана «Практики» (mind_screen.dart).
class MeditationLibraryBody extends ConsumerWidget {
  const MeditationLibraryBody({super.key});

  void _openEditor(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const MeditationEditorScreen()),
    );
  }

  Future<void> _deleteCustom(
    BuildContext context,
    WidgetRef ref,
    CustomMeditation m,
  ) async {
    final dao = ref.read(customMeditationDaoProvider);
    final snapshot = await dao.getById(m.id);
    if (snapshot == null) return;
    await dao.deleteSession(m.id);
    if (!context.mounted) return;
    showUndoSnackBar(
      context,
      message: '"${m.name}" ${context.s('meditation.removed')}',
      onUndo: () async => dao.restore(snapshot),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    final custom = ref.watch(customMeditationsProvider).valueOrNull ??
        const <CustomMeditation>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      children: [
        // Встроенные сессии — §4.2 object cards.
        for (final session in _sessions) ...[
          _SessionCard(session: session, ext: ext, textTheme: textTheme),
          const SizedBox(height: 8),
        ],
        // Пользовательские сессии: SwipeToDelete (влево = удалить + Undo).
        for (final m in custom) ...[
          SwipeToDelete(
            key: ValueKey('swipe_custom_med_${m.id}'),
            onDelete: () => _deleteCustom(context, ref, m),
            child: _CustomSessionCard(
              session: m,
              ext: ext,
              textTheme: textTheme,
              onDelete: () => _deleteCustom(context, ref, m),
            ),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        // Создать свою сессию — ghost-кнопка, выравнена по левому краю.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _openEditor(context),
            icon: Icon(PhosphorIcons.plus(), size: 20),
            label: Text(context.s('meditation.create_button')),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// §4.2 Карточка встроенной сессии
// ---------------------------------------------------------------------------

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.ext,
    required this.textTheme,
  });

  final _Session session;
  final FocusThemeExtension ext;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPosePreview(context, session),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Аватар: нейтральный (accentMuted фон, textMuted иконка lotus).
              _buildSessionAvatar(
                ext: ext,
                icon: PhosphorIcons.flowerLotus(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.s(session.nameKey),
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.s(session.descKey),
                      style: textTheme.bodySmall?.copyWith(
                        color: ext.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plMinutes(context, session.duration)} · ${plSteps(context, session.steps.length)}',
                      style: textTheme.labelSmall?.copyWith(
                        color: ext.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(PhosphorIcons.caretRight(), color: ext.textFaint, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// §4.2 Карточка пользовательской сессии
// ---------------------------------------------------------------------------

class _CustomSessionCard extends StatelessWidget {
  const _CustomSessionCard({
    required this.session,
    required this.ext,
    required this.textTheme,
    required this.onDelete,
  });

  final CustomMeditation session;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final minutes = (session.totalSeconds / 60).round().clamp(1, 1 << 30);

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openPlayer(context, _customToRun(session)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildSessionAvatar(
                ext: ext,
                icon: PhosphorIcons.flowerLotus(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Имя — СЫРОЙ пользовательский текст.
                    Text(
                      session.name,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${plMinutes(context, minutes)} · ${plSteps(context, session.steps.length)}',
                      style: textTheme.labelSmall?.copyWith(
                        color: ext.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              // Кнопка удаления — ember (destructive, §4.3).
              IconButton(
                icon: Icon(PhosphorIcons.trash(), size: 20, color: ext.ember),
                tooltip: context.s('btn.delete'),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pose preview screen — показывается перед плеером для встроенных сессий.
// SingleChildScrollView + FilledButton на всю ширину: выживает на 320px / textScale 2.
// ---------------------------------------------------------------------------

class _PosePreviewScreen extends StatelessWidget {
  const _PosePreviewScreen({required this.session});

  final _Session session;

  void _start(BuildContext context) {
    // Заменяем превью плеером; возврат из плеера ведёт прямо к списку.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => _SessionPlayerScreen(
          session: _builtinToRun(context, session),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.s(session.nameKey)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Иконка позы — большой нейтральный круг (96dp).
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: ext.accentMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  session.poseIcon,
                  color: colorScheme.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              // Приглашение — bodyMedium + textMuted.
              Text(
                context.s('meditation.pose_heading'),
                style: textTheme.bodyMedium?.copyWith(color: ext.textMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Название позы — titleLarge.
              Text(
                context.s(session.poseNameKey),
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              // Описание позы — bodyMedium, переносится по словам.
              Text(
                context.s(session.poseDescKey),
                style: textTheme.bodyMedium?.copyWith(
                  color: ext.textSecondary,
                  height: 1.55,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              // ONE primary FilledButton — кнопка «Начать».
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: Icon(PhosphorIcons.play(PhosphorIconsStyle.fill), size: 18),
                  label: Text(context.s('meditation.start')),
                  onPressed: () => _start(context),
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
// Session player screen
// ---------------------------------------------------------------------------

class _SessionPlayerScreen extends ConsumerStatefulWidget {
  const _SessionPlayerScreen({required this.session});
  final _RunSession session;

  @override
  ConsumerState<_SessionPlayerScreen> createState() =>
      _SessionPlayerScreenState();
}

class _SessionPlayerScreenState extends ConsumerState<_SessionPlayerScreen>
    with TickerProviderStateMixin {
  int _stepIndex = 0;
  int _remaining = 0;
  Timer? _timer;

  // Первый шаг стартуем в didChangeDependencies — MediaQuery уже доступен.
  bool _started = false;

  bool _paused = false;

  late AnimationController _arcController;

  // — Аудио (оба канала выключены по умолчанию) —
  bool _narrationEnabled = false;
  bool _ambientEnabled = false;
  double _ambientVolume = kMeditationAmbientDefaultVolume;
  bool _audioControlsOpen = false;

  // Сервисы создаются лениво.
  MeditationNarrator? _narrator;
  MeditationAmbientPlayer? _ambient;

  MeditationNarrator get _narratorOrCreate =>
      (_narrator ??= ref.read(meditationNarratorProvider))!;
  MeditationAmbientPlayer get _ambientOrCreate =>
      (_ambient ??= ref.read(meditationAmbientPlayerProvider))!;

  String get _localeTag => localeTag(Localizations.localeOf(context));

  bool get _isLastStep => _stepIndex >= widget.session.steps.length - 1;
  _RunStep get _currentStep => widget.session.steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    _arcController = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _loadAudioPrefs();
      _startStep(widget.session.steps[0]);
    }
  }

  void _loadAudioPrefs() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      _narrationEnabled =
          prefs.getBool(kMeditationNarrationEnabledKey) ?? false;
      _ambientEnabled = prefs.getBool(kMeditationAmbientEnabledKey) ?? false;
      _ambientVolume = prefs.getDouble(kMeditationAmbientVolumeKey) ??
          kMeditationAmbientDefaultVolume;
    } catch (_) {
      // prefs недоступны — дефолты.
    }
    if (_ambientEnabled) {
      _ambientOrCreate.start(_ambientVolume);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _arcController.dispose();
    _narrator?.stop();
    _narrator?.dispose();
    _ambient?.stop();
    _ambient?.dispose();
    super.dispose();
  }

  Future<void> _setNarration(bool value) async {
    setState(() => _narrationEnabled = value);
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(kMeditationNarrationEnabledKey, value);
    } catch (_) {}
    if (value) {
      _narratorOrCreate.speak(_currentStep.text, _localeTag);
    } else {
      _narrator?.stop();
    }
  }

  Future<void> _setAmbient(bool value) async {
    setState(() => _ambientEnabled = value);
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setBool(kMeditationAmbientEnabledKey, value);
    } catch (_) {}
    if (value) {
      _ambientOrCreate.start(_ambientVolume);
    } else {
      _ambient?.stop();
    }
  }

  void _onAmbientVolumeChanged(double value) {
    setState(() => _ambientVolume = value);
    _ambient?.setVolume(value);
  }

  Future<void> _persistAmbientVolume(double value) async {
    try {
      await ref
          .read(sharedPreferencesProvider)
          .setDouble(kMeditationAmbientVolumeKey, value);
    } catch (_) {}
  }

  void _startStep(_RunStep step) {
    _timer?.cancel();
    _paused = false;
    _remaining = step.seconds;

    if (_narrationEnabled) {
      _narratorOrCreate.speak(step.text, _localeTag);
    }

    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!reduce) {
      _arcController.duration = Duration(seconds: step.seconds);
      _arcController.forward(from: 0);
    } else {
      _arcController.value = 0;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_paused) return;
      setState(() => _remaining--);
      if (_remaining <= 0) {
        t.cancel();
        _onStepDone();
      }
    });
  }

  void _togglePause() {
    final reduce = MediaQuery.disableAnimationsOf(context);
    setState(() => _paused = !_paused);
    if (_paused) {
      if (!reduce) _arcController.stop();
    } else {
      if (!reduce) _arcController.forward(from: _arcController.value);
    }
  }

  void _onStepDone() {
    if (_isLastStep) {
      _showCompletionDialog();
    } else {
      _advanceStep();
    }
  }

  void _advanceStep() {
    setState(() => _stepIndex++);
    _startStep(widget.session.steps[_stepIndex]);
  }

  void _showCompletionDialog() {
    _timer?.cancel();
    _arcController.stop();

    const moodEmojis = ['😞', '😕', '😐', '🙂', '😄'];

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        int? selectedMood;
        final noteController = TextEditingController();
        final reduce = MediaQuery.disableAnimationsOf(dialogContext);

        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final ext = Theme.of(ctx).extension<FocusThemeExtension>()!;
            final colorScheme = Theme.of(ctx).colorScheme;
            final textTheme = Theme.of(ctx).textTheme;

            return AlertDialog(
              // Phosphor flowerLotus — success color, не accent (discipline).
              icon: Icon(
                PhosphorIcons.flowerLotus(PhosphorIconsStyle.fill),
                size: 40,
                color: ext.success,
              ),
              title: Text(ctx.s('meditation.session_complete')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${widget.session.name}"',
                      style: textTheme.bodyMedium?.copyWith(
                        color: ext.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ctx.s('meditation.mood_prompt'),
                      style: textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    // Шкала 1..5 — Wrap защищает от overflow (320px / textScale 2).
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(5, (i) {
                        final value = i + 1;
                        final selected = selectedMood == value;
                        return GestureDetector(
                          onTap: () => setDialogState(
                            () => selectedMood = selected ? null : value,
                          ),
                          child: AnimatedContainer(
                            duration: reduce ? Duration.zero : kDurationSnap,
                            curve: kCurveSnap,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selected
                                  ? ext.accentMuted
                                  : Colors.transparent,
                              border: Border.all(
                                color: selected
                                    ? colorScheme.primary
                                    : ext.border,
                                width: selected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Text(
                              moodEmojis[i],
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: ctx.s('meditation.mood_note_hint'),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final noteText = noteController.text.trim();
                    final moodSnapshot = selectedMood;
                    if (ctx.mounted) Navigator.of(ctx).pop();
                    noteController.dispose();
                    if (moodSnapshot != null) {
                      final dao = ref.read(moodLogsDaoProvider);
                      await appendMeditationMood(
                        dao,
                        MeditationMoodEntry(
                          sessionId: widget.session.id,
                          mood: moodSnapshot,
                          note: noteText.isEmpty ? null : noteText,
                          loggedAt: DateTime.now(),
                        ),
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.s('meditation.mood_saved')),
                          ),
                        );
                      }
                    }
                    if (mounted) Navigator.of(context).pop();
                  },
                  child: Text(ctx.s('btn.done')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final stepCount = widget.session.steps.length;
    final reduce = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.session.name),
        centerTitle: true,
        actions: [
          // Иконка аудио-панели: speakerHigh (закрыта) / slidersHorizontal (открыта).
          IconButton(
            icon: Icon(
              _audioControlsOpen
                  ? PhosphorIcons.slidersHorizontal()
                  : PhosphorIcons.speakerHigh(),
            ),
            tooltip: context.s('meditation.audio.controls'),
            onPressed: () =>
                setState(() => _audioControlsOpen = !_audioControlsOpen),
          ),
        ],
      ),
      body: SafeArea(
        // LayoutBuilder + SingleChildScrollView: никогда не переполняется.
        // При достатке места — растягивается на всю высоту; иначе — скроллится.
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      // Аудио-панель (раскрывается иконкой в AppBar).
                      if (_audioControlsOpen) ...[
                        _buildAudioControls(context, ext, textTheme),
                        const SizedBox(height: 16),
                      ],

                      // Прогресс шагов — labelSmall + textMuted.
                      // Flexible на левом тексте: при textScale 2.0 на 320px
                      // строка «Step 1 / 10» не выходит за правый край Row.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${context.s('meditation.step')} ${_stepIndex + 1} / $stepCount',
                              style: textTheme.labelSmall?.copyWith(
                                color: ext.textMuted,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Процент завершения (дополнительный контекст) — вправо.
                          Text(
                            '${((_stepIndex + 1) / stepCount * 100).round()}%',
                            style: textTheme.labelSmall?.copyWith(
                              color: ext.textFaint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Тонкий прогресс-бар — accent (несёт смысл прогресса).
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: (_stepIndex + 1) / stepCount,
                          minHeight: 3,
                          backgroundColor: ext.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Дуга таймера 200×200 — accent.
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: reduce
                            ? _StaticArcTimer(
                                remaining: _remaining,
                                total: _currentStep.seconds,
                                color: colorScheme.primary,
                                trackColor: ext.border,
                                textTheme: textTheme,
                              )
                            : AnimatedBuilder(
                                animation: _arcController,
                                builder: (_, _) => CustomPaint(
                                  painter: _ArcPainter(
                                    progress: 1 - _arcController.value,
                                    color: colorScheme.primary,
                                    trackColor: ext.border,
                                  ),
                                  child: Center(
                                    child: Text(
                                      _formatTime(_remaining),
                                      style: textTheme.displaySmall,
                                    ),
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 40),

                      // Текст шага — bodyLarge, центрально. Flexible не переполняет.
                      Flexible(
                        child: Center(
                          child: Text(
                            _currentStep.text,
                            style: textTheme.bodyLarge?.copyWith(
                              color: ext.textSecondary,
                              height: 1.55,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Пауза / Продолжить — OutlinedButton (вторичное).
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(
                            _paused
                                ? PhosphorIcons.play(PhosphorIconsStyle.fill)
                                : PhosphorIcons.pause(PhosphorIconsStyle.fill),
                            size: 18,
                          ),
                          label: Text(
                            _paused
                                ? context.s('focus.btn_resume')
                                : context.s('focus.btn_pause'),
                          ),
                          onPressed: _togglePause,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ONE primary FilledButton — единственное первичное действие.
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            if (_isLastStep) {
                              _showCompletionDialog();
                            } else {
                              _arcController.stop();
                              _advanceStep();
                            }
                          },
                          child: Text(
                            _isLastStep
                                ? context.s('meditation.finish')
                                : context.s('meditation.next'),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Завершить сессию — TextButton (низкий приоритет).
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(context.s('meditation.end_session')),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Компактная панель аудио: нарративный TTS + фоновый эмбиент + громкость.
  Widget _buildAudioControls(
    BuildContext context,
    FocusThemeExtension ext,
    TextTheme textTheme,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: ext.border, width: 0.5),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Озвучка шагов.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                PhosphorIcons.waveform(),
                color: ext.textMuted,
                size: 20,
              ),
              title: Text(
                context.s('meditation.audio.narration'),
                style: textTheme.bodyMedium,
              ),
              value: _narrationEnabled,
              onChanged: _setNarration,
            ),
            // Фоновый эмбиент.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                PhosphorIcons.wind(),
                color: ext.textMuted,
                size: 20,
              ),
              title: Text(
                context.s('meditation.audio.ambient'),
                style: textTheme.bodyMedium,
              ),
              value: _ambientEnabled,
              onChanged: _setAmbient,
            ),
            // Громкость — только когда эмбиент включён.
            if (_ambientEnabled) ...[
              Row(
                children: [
                  Icon(
                    PhosphorIcons.speakerHigh(),
                    color: ext.textFaint,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.s('meditation.audio.volume'),
                      style:
                          textTheme.bodySmall?.copyWith(color: ext.textMuted),
                    ),
                  ),
                  Text(
                    '${(_ambientVolume * 100).round()}%',
                    style:
                        textTheme.labelSmall?.copyWith(color: ext.textFaint),
                  ),
                ],
              ),
              Slider(
                value: _ambientVolume,
                onChanged: _onAmbientVolumeChanged,
                onChangeEnd: _persistAmbientVolume,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // MM:SS формат — без хардкода 's' суффикса, универсален для всех локалей.
  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// CustomPainters
// ---------------------------------------------------------------------------

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - 10;

    // Фоновая дорожка.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );

    // Прогресс-дуга — accent.
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor;
}

// Статичная дуга + время для reduce-motion режима.
class _StaticArcTimer extends StatelessWidget {
  const _StaticArcTimer({
    required this.remaining,
    required this.total,
    required this.color,
    required this.trackColor,
    required this.textTheme,
  });

  final int remaining;
  final int total;
  final Color color;
  final Color trackColor;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? remaining / total : 0.0;
    final m = remaining ~/ 60;
    final s = remaining % 60;
    final label = '$m:${s.toString().padLeft(2, '0')}';

    return CustomPaint(
      painter: _ArcPainter(
        progress: progress,
        color: color,
        trackColor: trackColor,
      ),
      child: Center(
        child: Text(label, style: textTheme.displaySmall),
      ),
    );
  }
}
