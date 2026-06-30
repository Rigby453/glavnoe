// Онбординг первого запуска: Language-слайд + короткое вступление (2 слайда
// «зачем приложение») + развилка «Войти / Продолжить как гость».
// Флаг 'onboarding_done' хранится в SharedPreferences; redirect в роутере
// показывает онбординг, пока флаг не выставлен.
//
// Единый поток (без дублирования онбордингов, см. ТЗ редизайна):
//   страница 0       — выбор языка (3+ кнопки; тап выставляет locale + переходит дальше);
//   страницы 1–2     — editorial value slides (короткое вступление, Kai на первой);
//   страница 3 (last)— развилка: «Войти / зарегистрироваться» → /auth,
//                       «Продолжить как гость» → continueOffline() сразу в /setup.
// Вход НЕ обязателен: гость переходит прямо в quiz-онбординг (/setup) без
// промежуточного экрана входа. Пейвол не показывается на этом шаге вообще —
// он стоит в самом конце quiz-флоу (см. setup_flow.dart _finish()).
//
// Редизайн (design-kai): displayLarge/headlineLarge serif,
// xxl breathing room, accent только на активном dot + кнопке Continue.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/animations/constants.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/settings/mascot_provider.dart';
import '../../core/settings/tone_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../features/mascot/kai_mascot.dart';
import '../auth/auth_controller.dart'; // authControllerProvider (continueOffline)

const onboardingDoneKey = 'onboarding_done';

// Индекс language-слайда.
const _kLangPage = 0;

// Value-слайды (после language). PhosphorIconData = IconData, поэтому final вместо const.
class _SlideData {
  _SlideData(this.icon, this.titleKey, this.subtitleKey);
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
}

// Короткое вступление — 2 слайда «зачем приложение» (было 3; третий, про
// дневник, убран ради краткости — спец §1: «1-2 слайда»). Хук + механика
// переноса остаются: они прямо предвосхищают демо-экран в /setup.
final _slides = [
  _SlideData(
    PhosphorIcons.flag(),
    'onboarding.slide1_title',
    'onboarding.slide1_subtitle',
  ),
  _SlideData(
    PhosphorIcons.sunHorizon(),
    'onboarding.slide2_title',
    'onboarding.slide2_subtitle',
  ),
];

// Всего страниц: 1 language + 2 value + 1 развилка (вход/гость).
const _pageCount = 1 + 2 + 1; // 4

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Развилка: вход обязателен НЕ ставится — обе ветки помечают onboarding_done
  // и либо ведут на полноценный /auth (вход/регистрация), либо включают
  // офлайн-режим и идут прямо в quiz-онбординг (/setup).
  // ---------------------------------------------------------------------------

  Future<void> _goToLogin() async {
    await ref.read(sharedPreferencesProvider).setBool(onboardingDoneKey, true);
    if (mounted) context.go('/auth');
  }

  Future<void> _continueAsGuest() async {
    await ref.read(sharedPreferencesProvider).setBool(onboardingDoneKey, true);
    // Гостевой режим (offline-first): данные остаются локально до входа.
    await ref.read(authControllerProvider.notifier).continueOffline();
    if (mounted) context.go('/setup');
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: effectiveDuration(context, kDurationNormal),
        curve: kCurveLift,
      );
    }
    // На развилке (последняя страница) кнопки управляются _buildForkButtons() —
    // дальше двигаться некуда, _next() здесь не вызывается.
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: effectiveDuration(context, kDurationNormal),
        curve: kCurveLift,
      );
    }
  }

  /// Прыжок сразу на развилку — глобальная кнопка «Пропустить» пропускает
  /// только вступительные слайды, а не весь онбординг целиком (развилка САМА
  /// предлагает быстрый путь — «Продолжить как гость»).
  void _skipToFork() {
    _pageController.animateToPage(
      _pageCount - 1,
      duration: effectiveDuration(context, kDurationNormal),
      curve: kCurveLift,
    );
  }

  /// Тап на кнопку языка: выставляет locale LIVE и переходит к следующей странице.
  void _selectLocale(Locale locale) {
    ref.read(localeNotifierProvider.notifier).setLocale(locale);
    _next();
  }

  bool get _isLangPage => _page == _kLangPage;
  bool get _isForkPage => _page == _pageCount - 1;

  // ---------------------------------------------------------------------------
  // Прогресс-индикатор (X/4 + кнопка «Пропустить») — идентичен SetupFlowScreen,
  // чтобы весь онбординг-поток ощущался единым. «Пропустить» скрыта на развилке
  // (там уже есть явный быстрый путь — «Продолжить как гость»).
  // ---------------------------------------------------------------------------

  Widget _buildProgressRow() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (_page + 1) / _pageCount,
                backgroundColor: ext.border,
                color: colorScheme.primary,
                minHeight: 4,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Счётчик «1 / 4» — Flexible+ellipsis: переживает крупный textScale.
          Flexible(
            child: Text(
              '${_page + 1} / $_pageCount',
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelMedium?.copyWith(color: ext.textMuted),
            ),
          ),
          if (!_isForkPage) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: _skipToFork,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                context.s('btn.skip'),
                style: textTheme.labelSmall?.copyWith(color: ext.textMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Нижние кнопки: скрыты на language-слайде; «назад + Next» на value-слайдах;
  // развилка использует свой собственный набор из двух кнопок.
  // ---------------------------------------------------------------------------

  Widget _buildBottomButtons() {
    // Языковой слайд управляется тапом по кнопке языка — нижняя панель не нужна.
    if (_isLangPage) return const SizedBox.shrink();
    if (_isForkPage) return _buildForkButtons();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Row(
        children: [
          if (_page > 0) ...[
            SizedBox(
              width: 52,
              height: 52,
              child: OutlinedButton(
                onPressed: _back,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Icon(PhosphorIcons.arrowLeft(), size: 20),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _next,
                child: Text(context.s('onboarding.btn_next')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Развилка: «назад» + primary «Войти/зарегистрироваться» в первой строке,
  /// secondary «Продолжить как гость» во второй — оба варианта равноценно
  /// заметны (не маленькая ссылка где-то внизу формы входа).
  Widget _buildForkButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: OutlinedButton(
                  onPressed: _back,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Icon(PhosphorIcons.arrowLeft(), size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _goToLogin,
                    child: Text(context.s('onboarding.fork_login_btn')),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: _continueAsGuest,
              child: Text(context.s('onboarding.fork_guest_btn')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final ext = Theme.of(context).extension<FocusThemeExtension>()!;
    final showKai = ref.watch(showKaiProvider);
    final tone = ref.watch(toneProvider);
    final reduce = reduceMotionOf(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Прогресс-бар + счётчик + «Пропустить» — единый стиль с SetupFlowScreen.
            _buildProgressRow(),

            // Страницы
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pageCount,
                itemBuilder: (context, i) {
                  // Страница 0 — выбор языка
                  if (i == _kLangPage) {
                    return _LanguageSlide(
                      ext: ext,
                      textTheme: textTheme,
                      colorScheme: colorScheme,
                      onSelect: _selectLocale,
                    );
                  }
                  // Последняя страница — развилка «Войти / Продолжить как гость»
                  if (i == _pageCount - 1) {
                    return _ForkSlide(
                      showKai: showKai && !reduce,
                      tone: tone,
                      textTheme: textTheme,
                      ext: ext,
                    );
                  }
                  // Страницы 1–2 — value slides (индекс слайда = i - 1)
                  final s = _slides[i - 1];
                  final isFirst = i == 1; // первый value-слайд показывает Kai
                  return _OnboardingSlide(
                    slideData: s,
                    isFirst: isFirst,
                    showKai: showKai && !reduce && isFirst,
                    tone: tone,
                    textTheme: textTheme,
                    colorScheme: colorScheme,
                    ext: ext,
                  );
                },
              ),
            ),

            // Нижняя панель: «назад» + CTA / развилка / пусто на language-слайде.
            _buildBottomButtons(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Слайд выбора языка
// ---------------------------------------------------------------------------

class _LanguageSlide extends ConsumerWidget {
  const _LanguageSlide({
    required this.ext,
    required this.textTheme,
    required this.colorScheme,
    required this.onSelect,
  });

  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final void Function(Locale locale) onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);
    final currentTag = localeTag(locale);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Иконка языка — нейтральная, не accent
          Center(
            child: Icon(
              PhosphorIcons.globe(),
              size: 64,
              color: ext.textMuted,
            ),
          ),
          const SizedBox(height: 32),

          Text(
            context.s('onboarding_quiz.s4_title'),
            style: textTheme.headlineLarge,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 24),

          // Список всех 12 языков — скролл-список внутри Expanded
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: localeEntries.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final entry = localeEntries[i];
                final tag = localeTag(entry.locale);
                return _LangButton(
                  label: entry.displayName,
                  tag: tag,
                  selected: currentTag == tag,
                  colorScheme: colorScheme,
                  ext: ext,
                  textTheme: textTheme,
                  onTap: () => onSelect(entry.locale),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.tag,
    required this.selected,
    required this.colorScheme,
    required this.ext,
    required this.textTheme,
    required this.onTap,
  });

  final String label;
  final String tag;
  final bool selected;
  final ColorScheme colorScheme;
  final FocusThemeExtension ext;
  final TextTheme textTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: kDurationSnap,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? colorScheme.primary : ext.border,
              width: selected ? 1.5 : 1.0,
            ),
            color: selected
                ? colorScheme.primary.withAlpha(18)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? colorScheme.primary : null,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                  color: colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Скролл-безопасная обёртка для центрированного контента слайда.
//
// На обычных экранах контент визуально центрирован по вертикали (как и
// раньше); на узких/маленьких экранах или при крупном textScale, когда
// контент не помещается, ConstrainedBox(minHeight) + SingleChildScrollView
// дают скролл вместо RenderFlex overflow (anti-regression rule B).
// ---------------------------------------------------------------------------

Widget _centeredSlideContent({required Widget child}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 32, // компенсация vertical padding
          ),
          child: Center(child: child),
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Value-слайд (editorial)
// ---------------------------------------------------------------------------

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({
    required this.slideData,
    required this.isFirst,
    required this.showKai,
    required this.tone,
    required this.textTheme,
    required this.colorScheme,
    required this.ext,
  });

  final _SlideData slideData;
  final bool isFirst;
  final bool showKai;
  final AppTone tone;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final FocusThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return _centeredSlideContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kai или иконка — по центру горизонтально
          Center(
            child: showKai
                ? KaiMascot(
                    size: 96,
                    emotion: KaiEmotion.neutral,
                    isHarsh: tone == AppTone.harsh,
                  )
                : Icon(
                    slideData.icon, // PhosphorIconData = IconData, тип совместим
                    size: 64,
                    color: ext.textMuted,
                  ),
          ),

          const SizedBox(height: 48), // xxl breathing room

          Text(
            context.s(slideData.titleKey),
            style: textTheme.headlineLarge,
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 16),

          Text(
            context.s(slideData.subtitleKey),
            style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Развилка: «Войти / Продолжить как гость» (последняя страница intro-флоу).
// Сам контент — только Kai + заголовок + подзаголовок; обе кнопки живут в
// нижней панели (_buildForkButtons), чтобы быть одинаково заметными.
// ---------------------------------------------------------------------------

class _ForkSlide extends StatelessWidget {
  const _ForkSlide({
    required this.showKai,
    required this.tone,
    required this.textTheme,
    required this.ext,
  });

  final bool showKai;
  final AppTone tone;
  final TextTheme textTheme;
  final FocusThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return _centeredSlideContent(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: showKai
                ? KaiMascot(
                    size: 96,
                    emotion: KaiEmotion.success,
                    isHarsh: tone == AppTone.harsh,
                  )
                : Icon(
                    PhosphorIcons.signIn(),
                    size: 64,
                    color: ext.textMuted,
                  ),
          ),
          const SizedBox(height: 48),
          Text(
            context.s('onboarding.fork_title'),
            style: textTheme.headlineLarge,
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 16),
          Text(
            context.s('onboarding.fork_subtitle'),
            style: textTheme.bodyLarge?.copyWith(color: ext.textMuted),
            textAlign: TextAlign.left,
          ),
        ],
      ),
    );
  }
}
