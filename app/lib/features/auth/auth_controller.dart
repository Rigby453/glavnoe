// Контроллер авторизации.
// Состояние = "можно войти в приложение": есть JWT-токен ИЛИ выбран офлайн-режим.
// Офлайн-режим (гость) сохраняет offline-first поведение: можно пользоваться
// приложением без аккаунта, синхронизация включится после входа.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../services/api/api_client.dart';
import '../../services/streak/freeze_accrual_service.dart'
    show kLocalPremiumUntilKey;
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
  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final resp = await ref.read(apiClientProvider).login(
          email: email,
          phone: phone,
          password: password,
        );
    await _clearGuest();
    await _reconcileSetupFlag(resp);
    state = true;
    _syncInBackground();
  }

  /// Регистрация. Передайте [email] ИЛИ [phone] — не оба.
  Future<void> register({
    String? email,
    String? phone,
    required String password,
    required String name,
  }) async {
    final resp = await ref.read(apiClientProvider).register(
          email: email,
          phone: phone,
          password: password,
          name: name,
        );
    await _clearGuest();
    await _reconcileSetupFlag(resp);
    state = true;
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

  /// Выход: чистим токен и офлайн-флаг → возврат на экран входа.
  Future<void> logout() async {
    await ref.read(apiClientProvider).clearToken();
    await _clearGuest();
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

