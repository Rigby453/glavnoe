// Точка входа приложения Kaizen
// ProviderScope + MaterialApp.router с темой Focus (по умолчанию)
// AppLifecycleListener запускает syncNow() при возврате приложения на передний план.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_providers.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/settings/text_scale_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_controller.dart';
import 'features/onboarding/setup_flow.dart';
import 'services/api/api_client.dart';
import 'services/notifications/notification_service.dart';
import 'services/sync/sync_service.dart';
import 'services/widget/widget_service.dart' show refreshHomeWidget, saveLastOpenedAt;

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

    // Записываем timestamp первого открытия (для «дней без захода» в виджете).
    saveLastOpenedAt();

    // Запускаем синхронизацию при возврате приложения на передний план.
    // Ошибки поглощаются внутри syncNow — UI не затрагивается.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Обновляем last_opened_at при каждом возврате приложения на передний план.
        saveLastOpenedAt();
        ref.read(syncServiceProvider).syncNow();
        refreshHomeWidget(
          itemsDao: ref.read(itemsDaoProvider),
          streakDao: ref.read(streakDaoProvider),
        );
      },
    );

    // Перепланируем ежедневные напоминания при запуске (если включены) —
    // расписание может сброситься после обновления приложения. Fire-and-forget.
    // Часы разборов — из настройки онбординга (setup_flow), дефолт 8/20.
    if (ref.read(notificationsEnabledProvider)) {
      final prefs = ref.read(sharedPreferencesProvider);
      ref.read(notificationServiceProvider).scheduleDailyReviews(
            morningHour: prefs.getInt(reviewMorningHourKey) ?? kMorningHour,
            eveningHour: prefs.getInt(reviewEveningHourKey) ?? kEveningHour,
          );
    }
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
    final locale = ref.watch(localeNotifierProvider);
    // Итоговый масштаб текста = пользовательская настройка × бонус Contrast-темы.
    final isContrast =
        ref.watch(themeNotifierProvider) == AppThemeKey.contrast;
    final userScale = ref.watch(textScaleProvider).scale;
    final scale = userScale * (isContrast ? 1.15 : 1.0);

    return MaterialApp.router(
      title: 'Kaizen',
      debugShowCheckedModeBanner: false,
      theme: theme,
      routerConfig: router,
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        if (scale == 1.0) return child;
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        );
      },
    );
  }
}
