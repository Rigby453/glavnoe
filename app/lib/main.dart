// Точка входа приложения Kaizen
// ProviderScope + MaterialApp.router с темой Focus (по умолчанию)
// AppLifecycleListener запускает syncNow() при возврате приложения на передний план.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_controller.dart';
import 'services/api/api_client.dart';
import 'services/sync/sync_service.dart';
import 'services/widget/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем SharedPreferences до запуска приложения
  // чтобы ThemeNotifier мог синхронно прочитать сохранённый ключ
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      // Пробрасываем уже инициализированный экземпляр SharedPreferences
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const KaizenApp(),
    ),
  );
}

/// Корневой виджет приложения.
/// ConsumerStatefulWidget необходим для AppLifecycleListener (требует dispose).
class KaizenApp extends ConsumerStatefulWidget {
  const KaizenApp({super.key});

  @override
  ConsumerState<KaizenApp> createState() => _KaizenAppState();
}

class _KaizenAppState extends ConsumerState<KaizenApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    // На 401 (истёкшая сессия) ApiClient очищает токен и зовёт этот колбэк —
    // сбрасываем auth-состояние, чтобы роутер увёл пользователя на /auth.
    ref.read(apiClientProvider).onUnauthorized =
        () => ref.read(authControllerProvider.notifier).refreshAuthState();
    // Запускаем синхронизацию при возврате приложения на передний план.
    // Ошибки поглощаются внутри syncNow — UI не затрагивается.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(syncServiceProvider).syncNow();
        refreshHomeWidget(
          itemsDao: ref.read(itemsDaoProvider),
          streakDao: ref.read(streakDaoProvider),
        );
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeDataProvider);
    final router = ref.watch(routerProvider);
    // Contrast-тема: крупный шрифт (×1.15) через системный textScaler — безопасно.
    final isContrast =
        ref.watch(themeNotifierProvider) == AppThemeKey.contrast;

    return MaterialApp.router(
      title: 'Kaizen',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      builder: (context, child) {
        if (!isContrast || child == null) return child ?? const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(1.15)),
          child: child,
        );
      },
    );
  }
}
