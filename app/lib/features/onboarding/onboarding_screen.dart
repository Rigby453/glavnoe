// Онбординг первого запуска: 3 слайда о сути продукта, затем переход к входу.
// Флаг 'onboarding_done' хранится в SharedPreferences; redirect в роутере
// показывает онбординг, пока флаг не выставлен.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider

const onboardingDoneKey = 'onboarding_done';

class _SlideData {
  const _SlideData(this.icon, this.titleKey, this.subtitleKey);
  final IconData icon;
  final String titleKey;
  final String subtitleKey;
}

const _slides = [
  _SlideData(
    Icons.flag_outlined,
    'onboarding.slide1_title',
    'onboarding.slide1_subtitle',
  ),
  _SlideData(
    Icons.wb_twilight,
    'onboarding.slide2_title',
    'onboarding.slide2_subtitle',
  ),
  _SlideData(
    Icons.menu_book_outlined,
    'onboarding.slide3_title',
    'onboarding.slide3_subtitle',
  ),
];

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
    if (_page < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200), // normal
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(context.s('btn.skip')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(s.icon, size: 72, color: colorScheme.primary),
                        const SizedBox(height: 32),
                        Text(
                          context.s(s.titleKey),
                          style: textTheme.headlineMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.s(s.subtitleKey),
                          style: textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Индикатор страниц
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? colorScheme.primary
                        : colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(
                    isLast
                        ? context.s('onboarding.btn_get_started')
                        : context.s('onboarding.btn_next'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
