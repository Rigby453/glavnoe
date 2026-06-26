// Конфигурация маршрутизатора go_router (через Riverpod-провайдер).
// Навигация: 4 таба (Today/Plan/Health/Diary) + /profile + /auth.
// Profile НЕ является табом. /auth — экран входа вне оболочки.
// Redirect уводит на /auth, пока пользователь не вошёл (или не выбрал офлайн-режим).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


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
import '../../features/profile/custom_theme_editor_screen.dart';
import '../../features/profile/my_data_screen.dart';
import '../../features/wrapped/wrapped_screen.dart';
import '../../features/food/shopping_list_screen.dart';
import '../../features/food/recipes_screen.dart';
import '../../features/food/recipe_editor_screen.dart';
import '../../features/health/breathing_screen.dart';
import '../../features/health/warmup_screen.dart';
import '../../features/health/workouts_screen.dart';
import '../../features/health/workout_editor_screen.dart';
import '../../features/health/workout_trainer_screen.dart';
import '../../features/health/exercise_history_screen.dart';
import '../../features/health/session_detail_screen.dart';
import '../../features/health/sleep_report_screen.dart';
import '../../features/health/water_fullscreen_screen.dart';
import '../../features/health/water_report_screen.dart';
import '../../features/diary/diary_history_screen.dart';
import '../../features/plan/goals_screen.dart';
import '../../features/health/meditation_screen.dart';
import '../../features/health/screen_time_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/profile/terms_screen.dart';
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
  ref.listen<bool>(authControllerProvider, (_, next) => refresh.value = next);

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
      GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),

      // Восстановление пароля (вне оболочки)
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
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
          // Неактивные вкладки — Offstage: состояние ветки сохраняется, но они
          // НЕ рисуются. Раньше использовался AnimatedOpacity внутри
          // TickerMode(enabled:active) — тикер неактивной ветки замораживался,
          // её затухание не доходило до 0, и прозрачные экраны (Health/Diary,
          // без своего фона) показывали предыдущую вкладку сквозь себя.
          final activeIndex = navigationShell.currentIndex;

          return Stack(
            fit: StackFit.expand,
            children: List.generate(children.length, (i) {
              final active = i == activeIndex;
              return Offstage(
                offstage: !active,
                child: TickerMode(
                  enabled: active,
                  child: children[i],
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

      // /profile/custom-theme — редактор пользовательской темы (05-custom-theme.md §2)
      GoRoute(
        path: '/profile/custom-theme',
        builder: (context, state) => const CustomThemeEditorScreen(),
      ),

      // /profile/my-data — экран «Мои данные» (объединяет тело/цель/воду/макросы/питание/здоровье)
      GoRoute(
        path: '/profile/my-data',
        builder: (context, state) => const MyDataScreen(),
      ),

      // /focus — фокус-сессии (из Health), вне оболочки
      GoRoute(path: '/focus', builder: (context, state) => const FocusScreen()),

      // /food — модуль еды (из Health), вне оболочки.
      // ?meal=<slot> — при открытии из задачи-приёма (moduleLink meal:*)
      // экран доскролливает к этой секции и кратко её подсвечивает.
      GoRoute(
        path: '/food',
        builder: (context, state) =>
            FoodScreen(targetMeal: state.uri.queryParameters['meal']),
      ),

      // /wrapped — weekly wrapped (из Diary), вне оболочки
      GoRoute(
        path: '/wrapped',
        builder: (context, state) => const WrappedScreen(),
      ),

      // /sleep-report — полный отчёт сна, вне оболочки
      GoRoute(
        path: '/sleep-report',
        builder: (context, state) => const SleepReportScreen(),
      ),

      // /water — полноэкранный трекер воды
      GoRoute(
        path: '/water',
        builder: (context, state) => const WaterFullscreenScreen(),
      ),
      // /water-report — полный отчёт воды, вне оболочки
      GoRoute(
        path: '/water-report',
        builder: (context, state) => const WaterReportScreen(),
      ), // /paywall — подписка Premium (из профиля и AI-апселлов), вне оболочки
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
        builder: (context, state) =>
            RecipeEditorScreen(recipeId: state.pathParameters['id']!),
      ),

      // /breathing — дыхательные сессии (SPEC C5, Ф2), вне оболочки
      GoRoute(
        path: '/breathing',
        builder: (context, state) => const BreathingScreen(),
      ),

      // /warmup — зарядка/растяжка: гайдед-рутины «проснуться», вне оболочки
      GoRoute(
        path: '/warmup',
        builder: (context, state) => const WarmupScreen(),
      ),

      // /workouts — список шаблонов тренировок (Phase 2), вне оболочки
      GoRoute(
        path: '/workouts',
        builder: (context, state) => const WorkoutsScreen(),
      ),
      GoRoute(
        path: '/workouts/:id',
        builder: (context, state) =>
            WorkoutEditorScreen(workoutId: state.pathParameters['id']!),
      ),
      // Режим «тренер»: пошаговое прохождение тренировки (Ф2)
      GoRoute(
        path: '/workouts/:id/train',
        builder: (context, state) =>
            WorkoutTrainerScreen(workoutId: state.pathParameters['id']!),
      ),
      // История упражнения (Feature B): прошлые подходы + динамика веса.
      // :id здесь — id упражнения (не тренировки). Имя для заголовка может
      // прийти через ?name= (опционально; экран сам подтянет его из БД).
      GoRoute(
        path: '/workouts/exercise/:id/history',
        builder: (context, state) => ExerciseHistoryScreen(
          exerciseId: state.pathParameters['id']!,
          exerciseName: state.uri.queryParameters['name'],
        ),
      ),
      // Журнал одной сессии (Part 1): «Тренировка <дата>». :id — id сессии.
      // ?date= (ISO старта) → заголовок-дата, ?name= → подзаголовок-программа.
      GoRoute(
        path: '/workouts/session/:id',
        builder: (context, state) {
          final rawDate = state.uri.queryParameters['date'];
          return SessionDetailScreen(
            sessionId: state.pathParameters['id']!,
            startedAt: rawDate == null ? null : DateTime.tryParse(rawDate),
            workoutName: state.uri.queryParameters['name'],
          );
        },
      ),

      // /diary-history — история записей дневника, вне оболочки
      GoRoute(
        path: '/diary-history',
        builder: (context, state) => const DiaryHistoryScreen(),
      ),

      // /goals — долгосрочные цели (SPEC C4), push-route вне оболочки
      GoRoute(path: '/goals', builder: (context, state) => const GoalsScreen()),

      // /meditation — текстовые медитации (Ф2), вне оболочки
      GoRoute(
        path: '/meditation',
        builder: (context, state) => const MeditationScreen(),
      ),
      // /screen-time — лимиты экранного времени по категориям
      GoRoute(
        path: '/screen-time',
        builder: (context, state) => const ScreenTimeScreen(),
      ),

      // /terms — пользовательское соглашение и политика конфиденциальности
      GoRoute(path: '/terms', builder: (context, state) => const TermsScreen()),
    ],
  );
});
