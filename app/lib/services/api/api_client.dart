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
  /// При успехе сохраняет access_token.
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/register',
        data: {'email': email, 'password': password, 'name': name},
      );
      final data = response.data!;
      await saveToken(data['access_token'] as String);
      return data;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Вход по email/паролю.
  /// При успехе сохраняет access_token.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data!;
      await saveToken(data['access_token'] as String);
      return data;
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
    String lastSyncAt,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync',
        data: {
          'items': items,
          'water_logs': waterLogs,
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
  // AI (Phase 1, premium)
  // ---------------------------------------------------------------------------

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
