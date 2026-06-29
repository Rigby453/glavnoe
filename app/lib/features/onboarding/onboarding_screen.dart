// Онбординг первого запуска: Language-слайд + 3 слайда о сути продукта,
// затем переход к входу.
// Флаг 'onboarding_done' хранится в SharedPreferences; redirect в роутере
// показывает онбординг, пока флаг не выставлен.
//
// Страница 0: выбор языка (3 кнопки; тап выставляет locale + переходит дальше).
// Страницы 1–3: editorial value slides (Kai на первой).
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
  _SlideData(
    PhosphorIcons.bookOpen(),
    'onboarding.slide3_title',
    'onboarding.slide3_subtitle',
  ),
];

// Всего страниц: 1 language + 3 value.
const _pageCount = 1 + 3; // 4

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

  Future<void> _finish() async {
    await ref.read(sharedPreferencesProvider).setBool(onboardingDoneKey, true);
    if (mounted) context.go('/auth');
  }

  void _next() {
    if (_page < _pageCount - 1) {
      _pageController.nextPage(
        duration: effectiveDuration(context, kDurationNormal),
        curve: kCurveLift,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_page > 0) {
      _pageController.previousPage(
        duration: effectiveDuration(context, kDurationNormal),
        curve: kCurveLift,
      );
    }
  }

  /// Тап на кнопку языка: выставляет locale LIVE и переходит к следующей странице.
  void _selectLocale(Locale locale) {
    ref.read(localeNotifierProvider.notifier).setLocale(locale);
    _next();
  }

  bool get _isLangPage => _page == _kLangPage;
  bool get _isLastPage => _page == _pageCount - 1;

  // ---------------------------------------------------------------------------
  // Прогресс-индикатор (X/4 + кнопка «Пропустить») — идентичен SetupFlowScreen,
  // чтобы весь онбординг-поток ощущался единым.
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
          const SizedBox(width: 8),
          TextButton(
            onPressed: _finish,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            child: Text(
              context.s('btn.skip'),
              style: textTheme.labelSmall?.copyWith(color: ext.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Нижние кнопки (скрыты на language-слайде; на value-слайдах: назад + CTA)
  // ---------------------------------------------------------------------------

  Widget _buildBottomButtons() {
    // Языковой слайд управляется тапом по кнопке языка — нижняя панель не нужна.
    if (_isLangPage) return const SizedBox.shrink();
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
                child: Text(
                  _isLastPage
                      ? context.s('onboarding.btn_get_started')
                      : context.s('onboarding.btn_next'),
                ),
              ),
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
                  // Страницы 1–3 — value slides (индекс слайда = i - 1)
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

            // Нижняя панель: «назад» + CTA (или пусто на language-слайде).
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
