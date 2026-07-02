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

// ИИ-генерация на Render (холодный старт + Gemini) может занимать существенно дольше
// обычных запросов. Передаём этот receiveTimeout пер-реквест в Options для /ai/* генераций.
const _aiReceiveTimeout = Duration(seconds: 120);

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
// PATCH /auth/me — сборка тела запроса (ADR-062)
// ---------------------------------------------------------------------------

/// Собирает тело PATCH /api/v1/auth/me: в результат попадают ТОЛЬКО заданные
/// (non-null) поля, ключи — snake_case (контракт /docs/api-spec.yaml).
/// Чистая функция — тестируется без Dio (см. test/api_client_profile_test.dart).
Map<String, dynamic> buildProfileUpdateBody({
  bool? onboardingDone,
  String? name,
  String? avatarPreset,
  double? weightKg,
  int? heightCm,
  int? ageYears,
  String? sex,
  String? activityLevel,
  String? foodGoal,
  int? calorieGoal,
  bool? macroOverrideEnabled,
  int? macroKcalTarget,
  int? macroProteinG,
  int? macroFatG,
  int? macroCarbsG,
  int? waterGoalMl,
}) {
  final body = <String, dynamic>{};
  if (onboardingDone != null) body['onboarding_done'] = onboardingDone;
  if (name != null) body['name'] = name;
  if (avatarPreset != null) body['avatar_preset'] = avatarPreset;
  if (weightKg != null) body['weight_kg'] = weightKg;
  if (heightCm != null) body['height_cm'] = heightCm;
  if (ageYears != null) body['age_years'] = ageYears;
  if (sex != null) body['sex'] = sex;
  if (activityLevel != null) body['activity_level'] = activityLevel;
  if (foodGoal != null) body['food_goal'] = foodGoal;
  if (calorieGoal != null) body['calorie_goal'] = calorieGoal;
  if (macroOverrideEnabled != null) {
    body['macro_override_enabled'] = macroOverrideEnabled;
  }
  if (macroKcalTarget != null) body['macro_kcal_target'] = macroKcalTarget;
  if (macroProteinG != null) body['macro_protein_g'] = macroProteinG;
  if (macroFatG != null) body['macro_fat_g'] = macroFatG;
  if (macroCarbsG != null) body['macro_carbs_g'] = macroCarbsG;
  if (waterGoalMl != null) body['water_goal_ml'] = waterGoalMl;
  return body;
}

// ---------------------------------------------------------------------------
// Основной клиент
// ---------------------------------------------------------------------------

class ApiClient {
  ApiClient(this._prefs) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _kBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 45),
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

  /// Частичное обновление профиля текущего пользователя (PATCH /auth/me).
  /// Все параметры опциональны; в тело запроса попадают ТОЛЬКО заданные
  /// (non-null) поля — см. [buildProfileUpdateBody]. ADR-062: антропометрия
  /// (weight/height/age/sex/activity), цели питания (food_goal/calorie_goal/
  /// macro_override_*) и норма воды теперь синхронизируются через аккаунт —
  /// раньше жили только в SharedPreferences устройства, что давало
  /// расхождение посчитанных норм КБЖУ между устройствами одного аккаунта.
  /// Возвращает обновлённого пользователя. snake_case в теле запроса.
  /// [name]/[avatarPreset] — отображаемое имя и пресет аватара (профиль
  /// синхронизируется между устройствами одного аккаунта, см. profile_identity_provider.dart).
  Future<Map<String, dynamic>> updateProfile({
    bool? onboardingDone,
    String? name,
    String? avatarPreset,
    double? weightKg,
    int? heightCm,
    int? ageYears,
    String? sex,
    String? activityLevel,
    String? foodGoal,
    int? calorieGoal,
    bool? macroOverrideEnabled,
    int? macroKcalTarget,
    int? macroProteinG,
    int? macroFatG,
    int? macroCarbsG,
    int? waterGoalMl,
  }) async {
    try {
      final body = buildProfileUpdateBody(
        onboardingDone: onboardingDone,
        name: name,
        avatarPreset: avatarPreset,
        weightKg: weightKg,
        heightCm: heightCm,
        ageYears: ageYears,
        sex: sex,
        activityLevel: activityLevel,
        foodGoal: foodGoal,
        calorieGoal: calorieGoal,
        macroOverrideEnabled: macroOverrideEnabled,
        macroKcalTarget: macroKcalTarget,
        macroProteinG: macroProteinG,
        macroFatG: macroFatG,
        macroCarbsG: macroCarbsG,
        waterGoalMl: waterGoalMl,
      );
      final response = await _dio.patch<Map<String, dynamic>>(
        '/api/v1/auth/me',
        data: body,
      );
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
  /// [streak] — опциональный блок заморозок { freeze_count, last_freeze_accrual_at }.
  ///   Включается в тело ТОЛЬКО если не null (по образцу water/food/daylogs).
  Future<Map<String, dynamic>> sync(
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> waterLogs,
    String lastSyncAt, {
    List<String> deletedItemIds = const [],
    List<Map<String, dynamic>> dayLogs = const [],
    List<Map<String, dynamic>> foodLogs = const [],
    Map<String, dynamic>? streak,
  }) async {
    try {
      final body = <String, dynamic>{
        'items': items,
        'water_logs': waterLogs,
        'food_logs': foodLogs,
        'day_logs': dayLogs,
        'deleted_item_ids': deletedItemIds,
        'last_sync_at': lastSyncAt,
      };
      // Блок заморозок — только если есть данные (freeze_count или курсор)
      if (streak != null) {
        body['streak'] = streak;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/sync',
        data: body,
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
        options: Options(receiveTimeout: _aiReceiveTimeout),
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
        options: Options(receiveTimeout: _aiReceiveTimeout),
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
  /// [foodPrefs] — опциональные пищевые предпочтения (диета/цель/лайки/дизлайки);
  /// передаётся как food_prefs ТОЛЬКО когда непустой (isEmpty == false).
  /// [fatGoalG]/[carbsGoalG]/[sugarMaxG]/[fiberMinG] — опциональные цели по
  /// БЖУ/сахару/клетчатке (snake_case в теле; отправляются только если не null).
  /// Бэкенд старается уложиться в них (ADR-046); back-compat — все nullable.
  Future<Map<String, dynamic>> aiMenuBuild({
    required List<Map<String, dynamic>> candidates,
    required int calorieGoal,
    required int proteinGoalG,
    int? fatGoalG,
    int? carbsGoalG,
    int? sugarMaxG,
    int? fiberMinG,
    List<String> meals = const ['breakfast', 'lunch', 'dinner'],
    required String tone,
    Map<String, String>? healthProfile,
    Map<String, dynamic>? foodPrefs,
  }) async {
    try {
      final body = <String, dynamic>{
        'candidates': candidates,
        'calorie_goal': calorieGoal,
        'protein_goal_g': proteinGoalG,
        // Полные цели БЖУ передаём только если заданы (опционально, back-compat).
        // null-aware элемент (?value) опускает пару, когда значение null.
        'fat_goal_g': ?fatGoalG,
        'carbs_goal_g': ?carbsGoalG,
        'sugar_max_g': ?sugarMaxG,
        'fiber_min_g': ?fiberMinG,
        'meals': meals,
        'tone': tone,
      };
      // Включаем профиль здоровья только если он непустой (не null и не всё пустые строки).
      if (healthProfile != null &&
          healthProfile.values.any((v) => v.trim().isNotEmpty)) {
        body['health_profile'] = healthProfile;
      }
      // Включаем пищевые предпочтения только если они непустые.
      if (foodPrefs != null && foodPrefs.isNotEmpty) {
        body['food_prefs'] = foodPrefs;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/menu-build',
        data: body,
        options: Options(receiveTimeout: _aiReceiveTimeout),
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// «AI-программа тренировок» (Feature A, premium). Бэкенд выступает тренером и
  /// возвращает недельную программу: { program_name, days:[{ title, exercises:[
  /// { name, sets, reps(строка), rest_seconds, note? }] }], note }.
  /// Вес/нагрузку модель НЕ назначает (первый проход — просто).
  /// [equipment] — доступный инвентарь (barbell/dumbbells/pullup_bar/bodyweight/
  /// full_gym); модель использует ТОЛЬКО его.
  /// [focus]/[limitations] — опциональные; передаются только если не null.
  /// [profile] — опциональный контекст атлета { sex, age, weight_kg, height_cm };
  /// включается в тело как profile ТОЛЬКО когда непустой.
  Future<Map<String, dynamic>> aiWorkoutBuild({
    required String goal,
    required String experience,
    required List<String> equipment,
    required int daysPerWeek,
    required int minutesPerSession,
    String? focus,
    String? limitations,
    required String tone,
    Map<String, dynamic>? profile,
  }) async {
    try {
      final body = <String, dynamic>{
        'goal': goal,
        'experience': experience,
        'equipment': equipment,
        'days_per_week': daysPerWeek,
        'minutes_per_session': minutesPerSession,
        // null-aware элемент (?value) опускает пару, когда значение null.
        'focus': ?focus,
        'limitations': ?limitations,
        'tone': tone,
      };
      // Профиль атлета — только если непустой (не null и хоть одно поле задано).
      if (profile != null && profile.values.any((v) => v != null)) {
        body['profile'] = profile;
      }
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/workout-build',
        data: body,
        options: Options(receiveTimeout: _aiReceiveTimeout),
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
        options: Options(receiveTimeout: _aiReceiveTimeout),
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
        options: Options(receiveTimeout: _aiReceiveTimeout),
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
        options: Options(receiveTimeout: _aiReceiveTimeout),
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
        options: Options(receiveTimeout: _aiReceiveTimeout),
      );
      return (response.data?['insight'] as String?) ?? '';
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// ИИ быстрое добавление задачи (Волна 6, этап 2, premium): свободная фраза
  /// (голос/текст) → одна структурированная задача. Сервер ничего не сохраняет —
  /// клиент показывает превью-подтверждение (add_task_sheet) перед записью.
  /// [text] — фраза пользователя; [date] — опорная дата 'YYYY-MM-DD' для
  /// разбора относительных дат («завтра», «через час»); [timezone] — IANA
  /// (напр. 'Europe/Moscow'); [locale] — опциональное переопределение языка
  /// ответа (по умолчанию бэкенд берёт Accept-Language).
  /// Возвращает { task: { title, type, priority, scheduled_at?, deadline?,
  /// duration_minutes?, note? } } как есть (snake_case) — парсинг на клиенте.
  Future<Map<String, dynamic>> aiQuickAdd({
    required String text,
    required String date,
    required String timezone,
    String? locale,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/quick-add',
        data: {
          'text': text,
          'date': date,
          'timezone': timezone,
          'locale': ?locale,
        },
        options: Options(receiveTimeout: _aiReceiveTimeout),
      );
      return response.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// ИИ-онбординг «брейн-дамп» (Волна 6, этап 3, premium): свободный текст
  /// ответов на онбординг → черновик плана (цели + задачи). Сервер ничего не
  /// сохраняет — клиент показывает превью перед записью (решение B).
  /// [answers] — свободный текст брейн-дампа; [date]/[timezone]/[locale] —
  /// как в [aiQuickAdd]. Возвращает { goals: [...], tasks: [...], food_prefs?: {...} }
  /// как есть (snake_case) — парсинг на клиенте.
  Future<Map<String, dynamic>> aiOnboardingPlan({
    required String answers,
    required String date,
    required String timezone,
    String? locale,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/v1/ai/onboarding-plan',
        data: {
          'answers': answers,
          'date': date,
          'timezone': timezone,
          'locale': ?locale,
        },
        options: Options(receiveTimeout: _aiReceiveTimeout),
      );
      return response.data!;
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

  // ---------------------------------------------------------------------------
  // Study groups (Ф3) — настоящие группы поверх одиночных сессий.
  // ---------------------------------------------------------------------------

  /// Список моих групп (где я accepted). Поля: id, name, code, is_owner,
  /// member_count, pending_count.
  Future<List<Map<String, dynamic>>> getStudyGroups() async {
    try {
      final r = await _dio.get<List<dynamic>>('/api/v1/study-groups');
      return List<Map<String, dynamic>>.from(r.data ?? []);
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Детали группы: id, name, code, is_owner, members [{ user_id, email, role, status }].
  Future<Map<String, dynamic>> getStudyGroup(String groupId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/api/v1/study-groups/$groupId');
      return r.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Создать группу. Возвращает { id, name, code, created_at }.
  Future<Map<String, dynamic>> createStudyGroup(String name) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/api/v1/study-groups',
        data: {'name': name},
      );
      return r.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Подать заявку на вступление по коду. Возвращает { group_id, name, status }.
  Future<Map<String, dynamic>> joinStudyGroup(String code) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>('/api/v1/study-groups/join/$code');
      return r.data!;
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Владелец принимает заявку участника.
  Future<void> acceptGroupMember(String groupId, String userId) async {
    try {
      await _dio.post<void>('/api/v1/study-groups/$groupId/members/$userId/accept');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Владелец отклоняет заявку участника.
  Future<void> declineGroupMember(String groupId, String userId) async {
    try {
      await _dio.post<void>('/api/v1/study-groups/$groupId/members/$userId/decline');
    } on DioException catch (e) {
      _throw(e);
    }
  }

  /// Выйти из группы. Если выходит владелец — группа удаляется целиком.
  /// Возвращает { deleted_group: bool }.
  Future<Map<String, dynamic>> leaveStudyGroup(String groupId) async {
    try {
      final r = await _dio.delete<Map<String, dynamic>>(
        '/api/v1/study-groups/$groupId/leave',
      );
      return r.data ?? <String, dynamic>{};
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
