// Контроллер авторизации.
// Состояние = "можно войти в приложение": есть JWT-токен ИЛИ выбран офлайн-режим.
// Офлайн-режим (гость) сохраняет offline-first поведение: можно пользоваться
// приложением без аккаунта, синхронизация включится после входа.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_provider.dart'; // sharedPreferencesProvider
import '../../services/api/api_client.dart';
import '../../services/sync/sync_service.dart';

const _kGuestKey = 'guest_mode';

class AuthController extends Notifier<bool> {
  @override
  bool build() {
    final api = ref.read(apiClientProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    return api.token != null || (prefs.getBool(_kGuestKey) ?? false);
  }

  /// Вошли ли по реальному аккаунту (есть токен), а не как гость.
  bool get isAuthenticated => ref.read(apiClientProvider).token != null;

  Future<void> login(String email, String password) async {
    await ref.read(apiClientProvider).login(email: email, password: password);
    await _clearGuest();
    state = true;
    _syncInBackground();
  }

  Future<void> register(String email, String password, String name) async {
    await ref
        .read(apiClientProvider)
        .register(email: email, password: password, name: name);
    await _clearGuest();
    state = true;
    _syncInBackground();
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

/// Премиум-статус (из /me). false в офлайн-режиме или без аккаунта.
final isPremiumProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(authControllerProvider); // пересчёт при смене статуса входа
  final api = ref.read(apiClientProvider);
  if (api.token == null) return false;
  try {
    final me = await api.me();
    return me['subscription_tier'] == 'premium';
  } on ApiException {
    return false;
  }
});
