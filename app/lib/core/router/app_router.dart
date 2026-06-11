// Конфигурация маршрутизатора go_router (через Riverpod-провайдер).
// Навигация: 4 таба (Today/Plan/Health/Diary) + /profile + /auth.
// Profile НЕ является табом. /auth — экран входа вне оболочки.
// Redirect уводит на /auth, пока пользователь не вошёл (или не выбрал офлайн-режим).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../animations/constants.dart'; // effectiveDuration

import '../theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/setup_flow.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/health/health_screen.dart';
import '../../features/diary/diary_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/food/food_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/wrapped/wrapped_screen.dart';
import '../../features/food/shopping_list_screen.dart';
import '../../features/food/recipes_screen.dart';
import '../../features/food/recipe_editor_screen.dart';
import '../../features/health/breathing_screen.dart';
import '../../features/health/posture_screen.dart';
import '../../features/health/workouts_screen.dart';
import '../../features/health/workout_editor_screen.dart';
import 'scaffold_with_nav_bar.dart';

/// Индексы табов
enum TabIndex {
  today(0),
  plan(1),
  health(2),
  diary(3);

  const TabIndex(this.value);
  final int value;
}

/// GoRouter как провайдер: redirect зависит от статуса авторизации,
/// refreshListenable пересчитывает маршрут при его смене.
final routerProvider = Provider<GoRouter>((ref) {
  // Мост между Riverpod-состоянием и go_router (Listenable для refresh).
  final refresh = ValueNotifier<bool>(ref.read(authControllerProvider));
  ref.onDispose(refresh.dispose);
  ref.listen<bool>(
    authControllerProvider,
    (_, next) => refresh.value = next,
  );

  final prefs = ref.read(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: '/today',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // 1) Онбординг первого запуска — пока не пройден, держим на /onboarding
      final onboardingDone = prefs.getBool(onboardingDoneKey) ?? false;
      if (!onboardingDone) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      // 2) Авторизация (или офлайн-режим)
      final canEnter = ref.read(authControllerProvider);
      if (!canEnter) {
        return loc == '/auth' ? null : '/auth';
      }

      // 3) Настройка после входа (SPEC C1: единый поток) — один раз
      final setupDone = prefs.getBool(setupDoneKey) ?? false;
      if (!setupDone) {
        return loc == '/setup' ? null : '/setup';
      }

      // Вошли и настроились — уводим со служебных экранов в приложение
      if (loc == '/auth' || loc == '/onboarding' || loc == '/setup') {
        return '/today';
      }
      return null;
    },
    routes: [
      // Онбординг первого запуска (вне оболочки)
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Экран входа / регистрации (вне оболочки)
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),

      // Настройка после входа: интересы → импорт → время разборов → тон →
      // тема → нормы (SPEC C1, единый поток)
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupFlowScreen(),
      ),

      // Оболочка с нижней навигацией — 4 таба через StatefulShellRoute.
      // navigatorContainerBuilder даёт кроссфейд при смене вкладок (ANIMATIONS.md §8.1).
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          // 150ms — ANIMATIONS.md §8.1
          const kTabCrossfade = Duration(milliseconds: 150);
          final duration = effectiveDuration(context, kTabCrossfade);
          final activeIndex = navigationShell.currentIndex;

          return Stack(
            fit: StackFit.expand,
            children: List.generate(children.length, (i) {
              final active = i == activeIndex;
              return IgnorePointer(
                ignoring: !active,
                child: TickerMode(
                  enabled: active,
                  child: AnimatedOpacity(
                    opacity: active ? 1.0 : 0.0,
                    duration: duration,
                    curve: Curves.easeOut,
                    child: children[i],
                  ),
                ),
              );
            }),
          );
        },
        branches: [
          // Таб 0: Today
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          // Таб 1: Plan
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
              ),
            ],
          ),
          // Таб 2: Health
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/health',
                builder: (context, state) => const HealthScreen(),
              ),
            ],
          ),
          // Таб 3: Diary
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/diary',
                builder: (context, state) => const DiaryScreen(),
              ),
            ],
          ),
        ],
      ),

      // /profile — НЕ таб, открывается из AppBar leading кнопки
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),

      // /focus — фокус-сессии (из Health), вне оболочки
      GoRoute(
        path: '/focus',
        builder: (context, state) => const FocusScreen(),
      ),

      // /food — модуль еды (из Health), вне оболочки
      GoRoute(
        path: '/food',
        builder: (context, state) => const FoodScreen(),
      ),

      // /wrapped — weekly wrapped (из Diary), вне оболочки
      GoRoute(
        path: '/wrapped',
        builder: (context, state) => const WrappedScreen(),
      ),

      // /paywall — подписка Premium (из профиля и AI-апселлов), вне оболочки
      GoRoute(
        path: '/paywall',
        builder: (context, state) => const PaywallScreen(),
      ),

      // /shopping — список покупок (SPEC C5, Phase 1), вне оболочки
      GoRoute(
        path: '/shopping',
        builder: (context, state) => const ShoppingListScreen(),
      ),

      // /recipes — рецепты из ингредиентов (SPEC C5, Phase 1), вне оболочки
      GoRoute(
        path: '/recipes',
        builder: (context, state) => const RecipesScreen(),
      ),
      GoRoute(
        path: '/recipes/:id',
        builder: (context, state) => RecipeEditorScreen(
          recipeId: state.pathParameters['id']!,
        ),
      ),

      // /breathing — дыхательные сессии (SPEC C5, Ф2), вне оболочки
      GoRoute(
        path: '/breathing',
        builder: (context, state) => const BreathingScreen(),
      ),

      // /posture — упражнения + напоминания об осанке (SPEC C5, Ф2), вне оболочки
      GoRoute(
        path: '/posture',
        builder: (context, state) => const PostureScreen(),
      ),

      // /workouts — список шаблонов тренировок (Phase 2), вне оболочки
      GoRoute(
        path: '/workouts',
        builder: (context, state) => const WorkoutsScreen(),
      ),
      GoRoute(
        path: '/workouts/:id',
        builder: (context, state) => WorkoutEditorScreen(
          workoutId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});
