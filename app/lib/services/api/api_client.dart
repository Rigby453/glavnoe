// Dio HTTP-клиент для Kaizen
// Все запросы к бэкенду проходят через этот класс.
// Базовый URL задаётся через --dart-define=API_BASE_URL при сборке.
// Токен хранится в SharedPreferences; 401 очищает токен и зовёт onUnauthorized
// (его вешает main.dart → сброс auth-состояния → роутер уводит на /auth).

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/theme_provider.dart';

// ---------------------------------------------------------------------------
// Константы
// ---------------------------------------------------------------------------

const _kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

const _kTokenKey = 'auth_token';
const _kLastSyncAtKey = 'last_sync_at';

// ---------------------------------------------------------------------------
// Исключение API
// ---------------------------------------------------------------------------

/// Исключение, бросаемое при HTTP-ошибках.
/// [message] — текст ошибки из тела ответа или DioException.message
/// [statusCode] — HTTP-код (может быть null при сетевой ошибке)
class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

// ---------------------------------------------------------------------------
// Основной клиент
// ---------------------------------------------------------------------------

class ApiClient {
  ApiClient(this._prefs) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _kBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Добавляем Bearer-токен, если он сохранён
          final token = _prefs.getString(_kTokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Язык пользователя → бэкенд (AI отвечает на этом языке).
          // Ключ 'app_locale' пишется LocaleNotifier (locale_provider.dart).
          final lang = _prefs.getString('app_locale') ?? 'en';
          options.headers['Accept-Language'] = lang;
          handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // Токен истёк/невалиден: очищаем его и уведомляем приложение,
            // чтобы оно сбросило auth-состояние и роутер увёл на /auth.
            await _prefs.remove(_kTokenKey);
            debugPrint('[ApiClient] 401 received — token cleared');
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );
  }

  final SharedPreferences _prefs;
  late final Dio _dio;

  /// Колбэк на 401 (сессия истекла). Вешается из main.dart, чтобы сбросить
  /// auth-состояние и увести пользователя на экран входа. null = не задан.
  void Function()? onUnauthorized;

  // ---------------------------------------------------------------------------
  // Хелперы хранилища токена / last_sync_at
  // ---------------------------------------------------------------------------

  /// Читает токен из SharedPreferences. Null = не авторизован.
  String? get token => _prefs.getString(_kTokenKey);

  /// Сохраняет токен авторизации.
  Future<void> saveToken(String token) => _prefs.setString(_kTokenKey, token);

  /// Удаляет токен (логаут).
  Future<void> clearToken() => _prefs.remove(_kTokenKey);

  /// Читает метку времени последней успешной синхронизации (ISO 8601).
  /// Возвращает начало эпохи, если синхронизация ещё не выполнялась.
  String get lastSyncAt =>
      _prefs.getString(_kLastSyncAtKey) ?? '1970-01-01T00:00:00.000Z';

  /// Сохраняет метку времени последней синхронизации.
  Future<void> saveLastSyncAt(String isoString) =>
      _prefs.setString(_kLastSyncAtKey, isoString);

  // ---------------------------------------------------------------------------
  // Внутренний хелпер обработки ошибок
  // ---------------------------------------------------------------------------

  /// Оборачивает DioException в ApiException с читаемым сообщением.
  Never _throw(DioException e) {
    final statusCode = e.response?.statusCode;
    String message;

    if (e.response?.data is Map<String, dynamic>) {
      message = (e.response!.data as Map<String, dynamic>)['error'] as String? ??
          e.message ??
          'Unknown error';
    } else {
      message = e.message ?? 'Network error';
    }

    throw ApiException(message, statusCode);
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// Регистрирует нового пользователя.
  /// Передаётся РОВНО ОДИН идентификатор: [email] ИЛИ [phone] (E.164, +7XXXXXXXXXX).
  /// При успехе сохраняет access_token.
  Future<Map<String, dynamic>> register({
    String? email,
    String? phone,
    required String password,
    required String name,
  }) async {
    assert(
      (email != null) ^ (phone != null),
      'register: передайте email ИЛИ phone, но не оба',
    );
    try {
      final body = <String, dynamic>{'password': password, 'name': name};
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: body,
      );
      final data = response.data!;
      await saveToken(data['access_token'] as String);
      return data;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Вход по паролю. Идентификатор — [email] ИЛИ [phone] (E.164, +7XXXXXXXXXX).
  /// При успехе сохраняет access_token.
  Future<Map<String, dynamic>> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    assert(
      (email != null) ^ (phone != null),
      'login: передайте email ИЛИ phone, но не оба',
    );
    try {
      final body = <String, dynamic>{'password': password};
      if (email != null) body['email'] = email;
      if (phone != null) body['phone'] = phone;
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: body,
      );
      final data = response.data!;
      await saveToken(data['access_token'] as String);
      return data;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// DEV-переключение тарифа (только не-production бэкенд). Возвращает пользователя.
  /// Реальные платежи появятся в Phase 1; до тех пор так включаем premium для теста AI.
  Future<Map<String, dynamic>> devUpgrade({String tier = 'premium'}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/subscription/dev-upgrade',
        data: {'tier': tier},
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Данные текущего авторизованного пользователя.
  Future<Map<String, dynamic>> me() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Запрос кода сброса пароля. Возвращает dev_code если есть (dev-режим).
  Future<String?> forgotPassword(String email) async {
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/forgot-password',
        data: {'email': email},
      );
      return resp.data?['dev_code'] as String?;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Сброс пароля по коду.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/api/v1/auth/reset-password',
        data: {
          'email': email,
          'code': code,
          'new_password': newPassword,
        },
      );
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------------

  /// Список задач в диапазоне дат.
  /// [from] / [to] передаются как ISO 8601 query-параметры, если указаны.
  Future<List<dynamic>> getItems({DateTime? from, DateTime? to}) async {
    try {
      final queryParams = <String, String>{};
      if (from != null) queryParams['from'] = from.toUtc().toIso8601String();
      if (to != null) queryParams['to'] = to.toUtc().toIso8601String();

      final response = await _dio.get<List<dynamic>>(
        '/api/v1/items',
        queryParameters: queryParams.isEmpty ? null : queryParams,
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Создать новую задачу.
  Future<Map<String, dynamic>> createItem(Map<String, dynamic> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/items',
        data: body,
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Частичное обновление задачи (PATCH).
  Future<Map<String, dynamic>> updateItem(
    String id,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/items/$id',
        data: body,
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Удалить задачу (ожидается 204 без тела).
  Future<void> deleteItem(String id) async {
    try {
      await _dio.delete<void>('/api/v1/items/$id');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Streaks
  // ---------------------------------------------------------------------------

  /// Текущая серия пользователя.
  Future<Map<String, dynamic>> getStreak() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/v1/streaks');
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Sync
  // ---------------------------------------------------------------------------

  /// Дельта-синхронизация: отправляем изменённые записи, получаем обновления сервера.
  /// [items] — задачи в snake_case; [waterLogs] — записи воды (append-only).
  /// [lastSyncAt] — ISO 8601 метка последней синхронизации.
  Future<Map<String, dynamic>> sync(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> waterLogs,
    String lastSyncAt, {
    List<String> deletedItemIds = const [],
    List<Map<String, dynamic>> dayLogs = const [],
    List<Map<String, dynamic>> foodLogs = const [],
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync',
        data: {
          'items': items,
          'water_logs': waterLogs,
          'food_logs': foodLogs,
          'day_logs': dayLogs,
          'deleted_item_ids': deletedItemIds,
          'last_sync_at': lastSyncAt,
        },
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Engine
  // ---------------------------------------------------------------------------

  /// Правиловой (бесплатный) редистрибьютор задач.
  /// Возвращает предложенный план, ничего не сохраняет.
  /// [targetDate] — дата в формате YYYY-MM-DD.
  Future<Map<String, dynamic>> redistribute(String targetDate) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/redistribute',
        data: {'target_date': targetDate},
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Food (Open Food Facts через бэкенд)
  // ---------------------------------------------------------------------------

  /// Текстовый поиск продуктов. Возвращает список { code, name, brand, per_100g }.
  Future<List<dynamic>> foodSearch(String query) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/food/search',
        queryParameters: {'q': query},
      );
      return (response.data?['products'] as List<dynamic>?) ?? <dynamic>[];
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Поиск продукта по штрихкоду. Возвращает продукт или null (404).
  Future<Map<String, dynamic>?> foodBarcode(String code) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/api/v1/food/barcode/$code');
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Share (Ф3, ADR-030)
  // ---------------------------------------------------------------------------

  /// Создать view-only веб-ссылку на план в диапазоне [from, to).
  /// Возвращает публичный URL (живёт 7 дней).
  Future<String> createShareLink({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/share',
        data: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      );
      return (response.data?['url'] as String?) ?? '';
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Читает публичный план по токену (без авторизации).
  /// Возвращает { owner_name, from, to, items: [...] }.
  /// 404 → ApiException с сообщением из тела ответа (или 'Plan not found').
  Future<Map<String, dynamic>> fetchSharedPlan(String token) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/v1/share/$token',
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // AI (Phase 1, premium)
  // ---------------------------------------------------------------------------

  /// Распознать еду по фото (premium, 3/день). Возвращает
  /// { dish, portion_description, confidence, products: [...] }.
  Future<Map<String, dynamic>> aiFoodRecognize({
    required String imageBase64,
    required String mediaType,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/food-recognize',
        data: {'image_base64': imageBase64, 'media_type': mediaType},
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Wrapped-сводка одним абзацем (premium). Числа считает клиент (код).
  Future<String> aiWrappedSummary({
    required int periodDays,
    required int tasksDone,
    required int tasksTotal,
    required int mainDone,
    required int mainTotal,
    double? avgMood,
    required int waterMl,
    String? topIssue,
    required String tone,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/wrapped-summary',
        data: {
          'period_days': periodDays,
          'tasks_done': tasksDone,
          'tasks_total': tasksTotal,
          'main_done': mainDone,
          'main_total': mainTotal,
          'avg_mood': avgMood,
          'water_ml': waterMl,
          'top_issue': topIssue,
          'tone': tone,
        },
      );
      return (response.data?['summary'] as String?) ?? '';
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// «Собрать ИИ» (premium): дневное меню из кандидатов клиента.
  /// [candidates] — [{ name, per_100g: {...} }]; модель возвращает только
  /// name+grams, числа КБЖУ пересчитывает клиент (код).
  /// [healthProfile] — опциональный профиль здоровья (аллергии/заживление/дефицит);
  /// передаётся в тело запроса как health_profile ТОЛЬКО когда непустой.
  Future<Map<String, dynamic>> aiMenuBuild({
    required List<Map<String, dynamic>> candidates,
    required int calorieGoal,
    required int proteinGoalG,
    List<String> meals = const ['breakfast', 'lunch', 'dinner'],
    required String tone,
    Map<String, String>? healthProfile,
  }) async {
    try {
      final body = <String, dynamic>{
        'candidates': candidates,
        'calorie_goal': calorieGoal,
        'protein_goal_g': proteinGoalG,
        'meals': meals,
        'tone': tone,
      };
      // Включаем профиль здоровья только если он непустой (не null и не всё пустые строки).
      if (healthProfile != null &&
          healthProfile.values.any((v) => v.trim().isNotEmpty)) {
        body['health_profile'] = healthProfile;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/menu-build',
        data: body,
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Распознать расписание с фото (premium). Возвращает список { title, scheduled_at }.
  /// [mediaType] — 'image/jpeg' или 'image/png'; [targetDate] — 'YYYY-MM-DD'.
  Future<List<dynamic>> scheduleImportFromPhoto({
    required String imageBase64,
    required String mediaType,
    required String targetDate,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/schedule-import',
        data: {
          'image_base64': imageBase64,
          'media_type': mediaType,
          'target_date': targetDate,
        },
      );
      return (response.data?['items'] as List<dynamic>?) ?? <dynamic>[];
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Tone-aware утреннее сообщение (premium). Возвращает текст.
  Future<String> aiMorningMessage({
    required int pendingCount,
    required String tone,
    String? userName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/morning-message',
        data: {
          'pending_count': pendingCount,
          'tone': tone,
          'user_name': ?userName,
        },
      );
      return (response.data?['message'] as String?) ?? '';
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Умное перераспределение (premium). Возвращает список планов { label, reason, items }.
  Future<List<dynamic>> aiRedistribute(String targetDate) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/redistribute',
        data: {'target_date': targetDate},
      );
      return (response.data?['plans'] as List<dynamic>?) ?? <dynamic>[];
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Инсайт по дневнику (premium). Возвращает текст.
  Future<String> aiDiaryInsight(String tone) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/diary-insight',
        data: {'tone': tone},
      );
      return (response.data?['insight'] as String?) ?? '';
    } on DioException catch (e) {
      _throw(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Co-study (Ф3, ADR-030)
  // ---------------------------------------------------------------------------

  /// Список друзей с их статусом (in_session, session_minutes).
  Future<List<Map<String, dynamic>>> getFriends() async {
    try {
      final r = await _dio.get<List<dynamic>>('/api/v1/friends');
      return List<Map<String, dynamic>>.from(r.data ?? []);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Добавить друга по email.
  Future<void> addFriend(String email) async {
    try {
      await _dio.post<void>('/api/v1/friends', data: {'email': email});
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Отписаться от друга.
  Future<void> removeFriend(String friendId) async {
    try {
      await _dio.delete<void>('/api/v1/friends/$friendId');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Начать учебную сессию. Возвращает { id, started_at }.
  Future<Map<String, dynamic>> startSession() async {
    try {
      final r = await _dio.post<Map<String, dynamic>>('/api/v1/study-sessions');
      return r.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Завершить учебную сессию. Возвращает обновлённую запись.
  Future<Map<String, dynamic>> endSession(String sessionId, int minutes) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/study-sessions/$sessionId',
        data: {'minutes': minutes},
      );
      return r.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Найти активную сессию по 8-символьному коду.
  Future<Map<String, dynamic>> getSessionByCode(String code) async {
    try {
      final r = await _dio.get('/api/v1/study-sessions/join/$code');
      return Map<String, dynamic>.from(r.data);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Недельная таблица лидеров (rank, email, minutes, is_me).
  Future<List<Map<String, dynamic>>> getLeaderboard() async {
    try {
      final r = await _dio.get<List<dynamic>>('/api/v1/leaderboard');
      return List<Map<String, dynamic>>.from(r.data ?? []);
    } on DioException catch (e) {
      _throw(e);
    }
  }
}

// ---------------------------------------------------------------------------
// Riverpod провайдер
// ---------------------------------------------------------------------------

/// Провайдер Dio-клиента.
/// Читает sharedPreferencesProvider — должен быть переопределён в ProviderScope
/// (как это сделано в main.dart).
final apiClientProvider = Provider<ApiClient>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return ApiClient(prefs);
});
