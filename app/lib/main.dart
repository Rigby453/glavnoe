// Точка входа приложения Kaizen
// ProviderScope + MaterialApp.router с темой Focus (по умолчанию)
// AppLifecycleListener + SyncTriggerService (services/sync/sync_trigger_service.dart)
// запускают/останавливают периодический синк по смене состояния приложения;
// на web синк также триггерится напрямую по document.visibilitychange.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_providers.dart';
import 'core/l10n/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/settings/app_usage.dart'; // E3/G2: счётчик запусков
import 'core/settings/text_scale_provider.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/auth_controller.dart';
import 'features/onboarding/setup_flow.dart';
import 'core/settings/posture_reminder_provider.dart' show kPostureRemindersKey;
import 'services/api/api_client.dart';
import 'services/notifications/notification_service.dart';
import 'services/sync/sync_trigger_service.dart';
import 'services/widget/widget_service.dart' show refreshHomeWidget, saveLastOpenedAt;
import 'services/widget/widget_actions.dart' show initWidgetActions;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загружаем SharedPreferences до запуска приложения
  // чтобы ThemeNotifier мог синхронно прочитать сохранённый ключ
  final prefs = await SharedPreferences.getInstance();

  // E3/G2: инкрементируем счётчик запусков ОДИН РАЗ за холодный старт.
  // При первом запуске также записывает first_launch_at.
  await incrementLaunchCount(prefs);

  // Инициализируем таблицы дат intl для сохранённой локали до первого кадра.
  // Это гарантирует, что DateFormat.yMMMMEEEEd() и другие без явной локали
  // используют язык пользователя, а не en_US по умолчанию.
  {
    // Дублируем ключ локально, чтобы не экспортировать внутренний const из locale_provider
    const kLocaleKey = 'app_locale';
    final savedLocale = prefs.getString(kLocaleKey) ?? 'en';
    await applyIntlLocale(savedLocale);
  }

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

    // Инициализируем обработку deep-link действий из домашнего виджета.
    // Cold start: post-frame callback запрашивает pending action через getLaunchAction.
    // Warm start: handler слушает invokeMethod("onWidgetAction") от нативной стороны.
    initWidgetActions(ref);

    // Запускаем периодический синк сразу на холодном старте (пока приложение
    // на переднем плане) — см. SyncTriggerService: без этого залогиненный
    // пользователь, открывший приложение заново, не увидит изменения с
    // других устройств до первого resume.
    ref.read(syncTriggerServiceProvider).start();

    // Запускаем/останавливаем синхронизацию по смене состояния приложения.
    // Ошибки поглощаются внутри syncNow — UI не затрагивается.
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Обновляем last_opened_at при каждом возврате приложения на передний план.
        saveLastOpenedAt();
        ref.read(syncTriggerServiceProvider).start();
        refreshHomeWidget(
          itemsDao: ref.read(itemsDaoProvider),
          streakDao: ref.read(streakDaoProvider),
        );
      },
      // onPause — мобильный уход в фон; onHide — web-таб теряет видимость
      // (desktop/web: onPause не вызывается вовсе, см. AppLifecycleListener).
      // Останавливаем периодический таймер в обоих случаях, чтобы не дёргать
      // сеть, пока пользователь не смотрит на экран.
      onPause: () => ref.read(syncTriggerServiceProvider).stop(),
      onHide: () => ref.read(syncTriggerServiceProvider).stop(),
    );

    // Пере-планируем все статические уведомления при старте (D1: reboot/обновление
    // пакета сбрасывают AlarmManager). Fire-and-forget — ошибки гасятся внутри.
    // Task/habit-напоминания пере-планируются из слоя фичей при открытии задачи.
    {
      final prefs = ref.read(sharedPreferencesProvider);
      ref.read(notificationServiceProvider).rescheduleAllReminders(
            reviewsEnabled: ref.read(notificationsEnabledProvider),
            morningHour: prefs.getInt(reviewMorningHourKey) ?? kMorningHour,
            eveningHour: prefs.getInt(reviewEveningHourKey) ?? kEveningHour,
            postureEnabled:
                prefs.getBool(kPostureRemindersKey) ?? false,
          );
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    // Останавливаем таймер + снимаем web-слушатель visibilitychange, чтобы
    // не течь при уничтожении корневого виджета (провайдер сам диспозится
    // при закрытии ProviderScope, но явный dispose здесь — не помешает).
    ref.read(syncTriggerServiceProvider).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeDataProvider);
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeNotifierProvider);
    // Итоговый масштаб текста = пользовательская настройка × бонус highContrast.
    // Размер 1.15 из design-tokens.json §accessibility.high_contrast.size_boost.
    final isHighContrast = ref.watch(highContrastProvider);
    final userScale = ref.watch(textScaleProvider).scale;
    final scale = userScale * (isHighContrast ? 1.15 : 1.0);

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
