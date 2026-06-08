// Конфигурация маршрутизатора go_router (через Riverpod-провайдер).
// Навигация: 4 таба (Today/Plan/Health/Diary) + /profile + /auth.
// Profile НЕ является табом. /auth — экран входа вне оболочки.
// Redirect уводит на /auth, пока пользователь не вошёл (или не выбрал офлайн-режим).

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../features/auth/auth_controller.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/today/today_screen.dart';
import '../../features/plan/plan_screen.dart';
import '../../features/health/health_screen.dart';
import '../../features/diary/diary_screen.dart';
import '../../features/focus/focus_screen.dart';
import '../../features/profile/profile_screen.dart';
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
      // Вошли — уводим с экранов входа/онбординга в приложение
      if (loc == '/auth' || loc == '/onboarding') return '/today';
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

      // Оболочка с нижней навигацией — 4 таба через StatefulShellRoute
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            ScaffoldWithNavBar(navigationShell: navigationShell),
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
    ],
  );
});
