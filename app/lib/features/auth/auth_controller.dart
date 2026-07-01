// Контроллер авторизации.
// Состояние = "можно войти в приложение": есть JWT-токен ИЛИ выбран офлайн-режим.
// Офлайн-режим (гость) сохраняет offline-first поведение: можно пользоваться
// приложением без аккаунта, синхронизация включится после входа.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import '../../core/settings/food_preferences_provider.dart'
    show foodPreferencesProvider;
import '../../core/settings/macro_override_provider.dart'
    show macroOverrideProvider;
import '../../core/settings/nutrition_targets.dart' show nutritionTargetsProvider;
import '../../core/settings/water_goal_provider.dart' show waterGoalProvider;
import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../services/api/api_client.dart';
import '../../services/streak/freeze_accrual_service.dart'
    show kLocalPremiumUntilKey;
import '../../services/sync/guest_migration_service.dart';
import '../../services/sync/profile_adoption_service.dart'
    show applyServerProfile;
import '../../services/sync/sync_service.dart';
import '../onboarding/setup_flow.dart' show setupDoneKey;

const _kGuestKey = 'guest_mode';

/// Решает, нужно ли пометить локальный `setup_done` как пройденный по ответу
/// сервера (объект `user` из auth-ответа или /me).
/// Возвращает true ТОЛЬКО когда сервер явно сообщает `onboarding_done == true`.
/// Серверный false/отсутствие поля НЕ должны стирать локально завершённый
/// онбординг — поэтому здесь только «истина включает».
bool shouldMarkSetupDone(Map<String, dynamic> user) =>
    user['onboarding_done'] == true;

class AuthController extends Notifier<bool> {
  @override
  bool build() {
    final api = ref.read(apiClientProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    return api.token != null || (prefs.getBool(_kGuestKey) ?? false);
  }

  /// Вошли ли по реальному аккаунту (есть токен), а не как гость.
  bool get isAuthenticated => ref.read(apiClientProvider).token != null;

  /// Вход по паролю. Передайте [email] ИЛИ [phone] — не оба.
  ///
  /// C2 — миграция гостевых данных: если пользователь до входа работал в
  /// офлайн-режиме (guest_mode=true), все локальные данные выгружаются на
  /// сервер до смены состояния авторизации. Это гарантирует, что гостевые
  /// задачи/вода/дневник не потеряются и станут видны на других устройствах.
  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    // Читаем флаг ДО login-запроса, пока он ещё выставлен.
    final wasGuest =
        ref.read(sharedPreferencesProvider).getBool(_kGuestKey) ?? false;

    final resp = await ref.read(apiClientProvider).login(
          email: email,
          phone: phone,
          password: password,
        );

    // ADR-062: адопция профиля (антропометрия/цели питания/вода) с сервера —
    // сервер — источник истины для вернувшегося пользователя на новом
    // устройстве (устраняет расхождение норм КБЖУ между устройствами).
    // Делаем ДО гостевой миграции и ДО фонового синка задач (_syncInBackground
    // ниже), как и требуется — профиль не зависит от синка Items/Water/DayLogs.
    await _adoptServerProfile(resp['user']);

    // C2: токен уже сохранён внутри apiClient.login() → можно мигрировать.
    // Выполняем ДО _clearGuest(): флаг нам уже не нужен (прочитан выше),
    // но порядок «миграция → сброс флага» безопаснее (при ошибке следующий
    // login повторит попытку).
    if (wasGuest) {
      await ref.read(guestMigrationServiceProvider).migrateIfNeeded();
    }

    await _clearGuest();
    await _reconcileSetupFlag(resp);
    state = true;

    // Фоновый синк всегда, независимо от гостевой миграции: миграция уже
    // сделала свой syncNow(), но повторный вызов идемпотентен (это просто
    // очередная дельта-синхронизация) и служит подстраховкой — например,
    // если другое устройство успело записать изменения на сервер между
    // миграцией и этим моментом.
    _syncInBackground();
  }

  /// Регистрация. Передайте [email] ИЛИ [phone] — не оба.
  ///
  /// C2 — аналогично login(): пользователь мог поработать как гость, затем
  /// решить зарегистрироваться. Выгружаем гостевые данные на новый аккаунт.
  Future<void> register({
    String? email,
    String? phone,
    required String password,
    required String name,
  }) async {
    // Читаем флаг ДО регистрации — после _clearGuest() он исчезнет.
    final wasGuest =
        ref.read(sharedPreferencesProvider).getBool(_kGuestKey) ?? false;

    final resp = await ref.read(apiClientProvider).register(
          email: email,
          phone: phone,
          password: password,
          name: name,
        );

    // ADR-062: адопция профиля с сервера (обычно no-op для новой
    // регистрации — сервер ещё не хранит ничего, кроме дефолтов), но
    // держим тот же путь, что и в login(), на случай будущих server-side
    // дефолтов/повторной регистрации по уже существующему email на сервере.
    await _adoptServerProfile(resp['user']);

    // C2: мигрируем гостевые данные (если были) до смены состояния.
    if (wasGuest) {
      await ref.read(guestMigrationServiceProvider).migrateIfNeeded();
    }

    await _clearGuest();
    await _reconcileSetupFlag(resp);
    state = true;

    // Всегда синкаем в фоне (см. комментарий в login() — идемпотентно и
    // безопасно повторить даже после миграции гостевых данных).
    _syncInBackground();
  }

  /// Сверяет серверный флаг онбординга с локальным `setup_done` ДО смены
  /// state — чтобы роутер не показал setup-флоу при входе в уже настроенный
  /// аккаунт (web/новое устройство). Серверный false НЕ стирает локальный
  /// флаг (он — оффлайн-кэш): только server true ставит true.
  Future<void> _reconcileSetupFlag(Map<String, dynamic> authResponse) async {
    final user = authResponse['user'];
    if (user is Map<String, dynamic> && shouldMarkSetupDone(user)) {
      await ref.read(sharedPreferencesProvider).setBool(setupDoneKey, true);
    }
  }

  // ---------------------------------------------------------------------------
  // ADR-062 — адопция профиля (антропометрия/цели питания/вода) с сервера
  // ---------------------------------------------------------------------------

  /// Применяет объект `user` (из login/register/GET me) к локальным prefs
  /// через [applyServerProfile] и инвалидирует провайдеры, которые кэшируют
  /// вычисленные из этих ключей значения — иначе UI покажет старые нормы до
  /// следующего пересчёта. Ошибки поглощаются: адопция не должна блокировать
  /// вход/регистрацию/старт приложения (offline-first).
  Future<void> _adoptServerProfile(Object? user) async {
    if (user is! Map<String, dynamic>) return;
    try {
      await applyServerProfile(user, ref.read(sharedPreferencesProvider));
      ref.invalidate(nutritionTargetsProvider);
      ref.invalidate(macroOverrideProvider);
      ref.invalidate(waterGoalProvider);
      ref.invalidate(foodPreferencesProvider);
    } catch (e) {
      debugPrint('[AuthController] Адопция профиля с сервера не удалась: $e');
    }
  }

  /// Если уже авторизован (токен сохранён с прошлой сессии — пользователь не
  /// разлогинивался в ЭТОЙ сессии приложения) — подтягивает профиль с сервера
  /// ОДИН РАЗ на холодном старте. Адопция в [login]/[register] покрывает
  /// только момент входа; без этого метода уже залогиненное на двух
  /// устройствах приложение не увидит профиль, изменённый на другом
  /// устройстве, до следующего явного login(). Fire-and-forget-безопасно:
  /// вызывающий код (main.dart) не обязан await'ить или обрабатывать ошибки.
  Future<void> adoptServerProfileOnStartup() async {
    if (!isAuthenticated) return;
    try {
      final me = await ref.read(apiClientProvider).me();
      await _adoptServerProfile(me);
    } catch (e) {
      debugPrint('[AuthController] Стартовая адопция профиля не удалась: $e');
    }
  }

  /// Продолжить без аккаунта — данные остаются локально (Drift), без синхронизации.
  Future<void> continueOffline() async {
    await ref.read(sharedPreferencesProvider).setBool(_kGuestKey, true);
    state = true;
  }

  /// Пересчитать состояние входа (например, после 401 — токен уже очищен
  /// интерсептором ApiClient). Если токена нет и не гость → роутер уводит на /auth.
  void refreshAuthState() {
    final api = ref.read(apiClientProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    state = api.token != null || (prefs.getBool(_kGuestKey) ?? false);
  }

  /// Выход: чистим токен, офлайн-флаг, локальные prefs-данные и Drift-БД.
  /// После этого другой аккаунт не увидит чужих задач/данных.
  Future<void> logout() async {
    // 1. Инвалидируем JWT-токен на API-клиенте
    await ref.read(apiClientProvider).clearToken();
    // 2. Сбрасываем гостевой флаг
    await _clearGuest();
    // 3. Сбрасываем локальный премиум-override (привязан к пользователю)
    await ref.read(sharedPreferencesProvider).remove(kLocalPremiumUntilKey);
    // 4. Удаляем ВСЕ пользовательские строки из Drift в одной транзакции
    await ref.read(appDatabaseProvider).clearAllUserData();
    state = false;
  }

  Future<void> _clearGuest() async {
    await ref.read(sharedPreferencesProvider).remove(_kGuestKey);
  }

  void _syncInBackground() {
    // Первичная синхронизация после входа — не блокируем UI.
    ref.read(syncServiceProvider).syncNow();
  }
}

/// true = пользователь может войти в приложение (аккаунт или офлайн-режим).
final authControllerProvider =
    NotifierProvider<AuthController, bool>(AuthController.new);

/// Премиум-статус (из /me ИЛИ локального override local_premium_until).
///
/// Проверяет оба источника:
///   1. Серверный tier == 'premium' (только при наличии токена).
///   2. local_premium_until в SharedPreferences — выдаётся как награда за
///      накопление заморозок (см. FreezeAccrualService).
/// Возвращает true если хотя бы один источник активен.
final isPremiumProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(authControllerProvider); // пересчёт при смене статуса входа

  // Проверить локальный override (offline-first, без сети).
  final prefs = ref.read(sharedPreferencesProvider);
  final localUntilRaw = prefs.getString(kLocalPremiumUntilKey);
  if (localUntilRaw != null) {
    try {
      final localUntil = DateTime.parse(localUntilRaw).toUtc();
      if (DateTime.now().toUtc().isBefore(localUntil)) {
        return true; // локальная награда ещё активна
      }
    } catch (_) {}
  }

  // Проверить серверный тир.
  final api = ref.read(apiClientProvider);
  if (api.token == null) return false;
  try {
    final me = await api.me();
    return me['subscription_tier'] == 'premium';
  } on ApiException {
    return false;
  }
});

