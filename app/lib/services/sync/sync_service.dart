// Офлайн-первый сервис синхронизации Kaizen
// Принцип: сначала запись в Drift, синхронизация — вторична.
// Стратегия слияния: last-write-wins по updated_at (сервер авторитетен для возвращаемых им записей).
//
// Текущие ограничения:
// - Удалённые локально записи НЕ синхронизируются: мы отправляем дельту по updated_at,
//   удалённые строки просто отсутствуют в локальной БД.
// TODO: track deletes via SyncQueueTable (таблица уже существует в схеме)

// Именованные параметры конструктора не могут начинаться с "_", поэтому поля
// присваиваются через список инициализации (а не initializing formals).
// ignore_for_file: prefer_initializing_formals

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/database.dart';
import '../../core/database/database_providers.dart';
import '../../core/database/daos/day_logs_dao.dart';
import '../../core/database/daos/streak_dao.dart';
import '../../core/theme/theme_provider.dart' show sharedPreferencesProvider;
import '../api/api_client.dart';
import '../streak/freeze_accrual_service.dart' show kLastFreezeAccrualKey;

class SyncService {
  SyncService({
    required ApiClient apiClient,
    required AppDatabase db,
    required StreakDao streakDao,
    required SharedPreferences prefs,
  })  : _apiClient = apiClient,
        _db = db,
        _streakDao = streakDao,
        _prefs = prefs;

  final ApiClient _apiClient;
  final AppDatabase _db;
  final StreakDao _streakDao;
  final SharedPreferences _prefs;

  // ---------------------------------------------------------------------------
  // Основной метод синхронизации
  // ---------------------------------------------------------------------------

  /// Выполняет дельта-синхронизацию с сервером.
  ///
  /// 1. Проверяет наличие токена — без авторизации синхронизация бессмысленна.
  /// 2. Читает last_sync_at из SharedPreferences (по умолчанию — эпоха).
  /// 3. Собирает локальные записи, изменённые после last_sync_at (исходящие).
  /// 4. Вызывает POST /api/v1/sync.
  /// 5. Мержит updated_items из ответа в Drift через insertOnConflictUpdate
  ///    (last-write-wins: сервер авторитетен для возвращаемых записей).
  /// 6. Обновляет last_sync_at = DateTime.now().toUtc().
  ///
  /// Все ошибки поглощаются: метод никогда не бросает в UI — offline-first.
  Future<void> syncNow() async {
    // Шаг 1: без токена синхронизацию не запускаем
    if (_apiClient.token == null) {
      debugPrint('[SyncService] No auth token — skipping sync');
      return;
    }

    try {
      // Шаг 2: читаем метку последней синхронизации
      final lastSyncAt = _apiClient.lastSyncAt;
      final lastSyncDate = DateTime.parse(lastSyncAt);

      // Шаг 3: локальные записи, обновлённые ПОСЛЕ lastSyncAt (исходящие изменения)
      final localItems = await (_db.select(
        _db.itemsTable,
      )..where((t) => t.updatedAt.isBiggerThanValue(lastSyncDate))).get();

      // Каждой исходящей задаче прикрепляем её подзадачи вложенным массивом
      // `subtasks` (snake_case, schemaVersion 14). Last-write-wins на уровне
      // задачи: сервер хранит присланный набор целиком.
      final outgoing = <Map<String, dynamic>>[];
      for (final item in localItems) {
        final map = _itemToSnakeCase(item);
        map['subtasks'] = await _subtasksForItem(item.id);
        outgoing.add(map);
      }

      // Исходящие записи воды (append-only): добавленные после lastSyncAt
      final localWater = await (_db.select(
        _db.waterLogsTable,
      )..where((t) => t.loggedAt.isBiggerThanValue(lastSyncDate))).get();
      final outgoingWater = localWater.map(_waterToSnakeCase).toList();

      // Исходящие записи еды (append-only, ADR-024): созданные после lastSyncAt
      final localFood = await (_db.select(
        _db.foodLogsTable,
      )..where((t) => t.createdAt.isBiggerThanValue(lastSyncDate))).get();
      final outgoingFood = localFood.map(_foodToSnakeCase).toList();

      // Исходящие удаления (tombstones из sync_queue): items, операция delete
      final deleteRows =
          await (_db.select(_db.syncQueueTable)..where(
                (t) =>
                    t.operation.equals('delete') & t.tableName_.equals('items'),
              ))
              .get();
      final deletedItemIds = deleteRows.map((r) => r.recordId).toSet().toList();

      // Исходящие записи дневника (изменённые после lastSyncAt)
      final dayLogsDao = DayLogsDao(_db);
      final localDayLogs = await dayLogsDao.changedSince(lastSyncDate);
      final outgoingDayLogs = localDayLogs.map(_dayLogToSnakeCase).toList();

      // Блок заморозок для отправки (ADR-044).
      // freeze_count берём из Drift StreakTable; курсор — из SharedPreferences.
      // Включаем в тело запроса только если у нас есть хоть какие-то данные.
      Map<String, dynamic>? streakBlock;
      final localStreak = await _streakDao.getStreak();
      final localLastAccrual = _prefs.getString(kLastFreezeAccrualKey);
      if (localStreak != null || localLastAccrual != null) {
        streakBlock = {
          'freeze_count': localStreak?.freezeCount ?? 0,
          'last_freeze_accrual_at': localLastAccrual, // null допустим по контракту
        };
      }

      debugPrint(
        '[SyncService] Syncing ${outgoing.length} items, '
        '${outgoingWater.length} water logs, '
        '${outgoingFood.length} food logs, '
        '${outgoingDayLogs.length} day logs, '
        '${deletedItemIds.length} deletions, lastSyncAt=$lastSyncAt'
        '${streakBlock != null ? ", streak=${streakBlock['freeze_count']} freezes" : ""}',
      );

      // Шаг 4: отправляем на сервер
      final response = await _apiClient.sync(
        outgoing,
        outgoingWater,
        lastSyncAt,
        deletedItemIds: deletedItemIds,
        dayLogs: outgoingDayLogs,
        foodLogs: outgoingFood,
        streak: streakBlock,
      );

      // Удаления доставлены — очищаем обработанные tombstones
      if (deleteRows.isNotEmpty) {
        final processedIds = deleteRows.map((r) => r.id).toList();
        await (_db.delete(
          _db.syncQueueTable,
        )..where((t) => t.id.isIn(processedIds))).go();
      }

      // Шаг 5: мержим входящие обновления от сервера в Drift
      final updatedItems =
          (response['updated_items'] as List<dynamic>?) ?? <dynamic>[];

      if (updatedItems.isNotEmpty) {
        await _db.transaction(() async {
          for (final raw in updatedItems) {
            if (raw is! Map<String, dynamic>) continue;
            final companion = _snakeCaseToCompanion(raw);
            await _db.into(_db.itemsTable).insertOnConflictUpdate(companion);
            // Подзадачи задачи: если сервер прислал массив `subtasks` —
            // заменяем локальный набор целиком (LWW на уровне задачи).
            // Отсутствие ключа = сервер не управляет подзадачами этой задачи →
            // локальные подзадачи не трогаем.
            final itemId = raw['id'] as String?;
            final subtasksRaw = raw['subtasks'];
            if (itemId != null && subtasksRaw is List) {
              await _replaceSubtasks(itemId, subtasksRaw);
            }
          }
        });
        debugPrint('[SyncService] Merged ${updatedItems.length} server items');
      }

      // Шаг 5b: мержим записи воды от сервера (upsert по id; append-only)
      final updatedWater =
          (response['updated_water_logs'] as List<dynamic>?) ?? <dynamic>[];

      if (updatedWater.isNotEmpty) {
        await _db.transaction(() async {
          for (final raw in updatedWater) {
            if (raw is! Map<String, dynamic>) continue;
            await _db
                .into(_db.waterLogsTable)
                .insertOnConflictUpdate(_waterSnakeCaseToCompanion(raw));
          }
        });
        debugPrint('[SyncService] Merged ${updatedWater.length} water logs');
      }

      // Шаг 5b': мержим записи еды от сервера (upsert по id; append-only)
      final updatedFood =
          (response['updated_food_logs'] as List<dynamic>?) ?? <dynamic>[];
      if (updatedFood.isNotEmpty) {
        await _db.transaction(() async {
          for (final raw in updatedFood) {
            if (raw is! Map<String, dynamic>) continue;
            final companion = _foodSnakeCaseToCompanion(raw);
            if (companion == null) continue;
            await _db.into(_db.foodLogsTable).insertOnConflictUpdate(companion);
          }
        });
        debugPrint('[SyncService] Merged ${updatedFood.length} food logs');
      }

      // Шаг 5c: мержим записи дневника от сервера (ключ — дата; LWW)
      final updatedDayLogs =
          (response['updated_day_logs'] as List<dynamic>?) ?? <dynamic>[];
      if (updatedDayLogs.isNotEmpty) {
        for (final raw in updatedDayLogs) {
          if (raw is! Map<String, dynamic>) continue;
          final dateStr = raw['date'] as String?;
          if (dateStr == null) continue;
          final date = DateTime.tryParse(dateStr);
          if (date == null) continue;
          await dayLogsDao.upsertFromServerByDate(
            date: date,
            mood: (raw['mood'] as num?)?.toInt(),
            note: raw['note'] as String?,
            insight: raw['insight'] as String?,
            createdAt:
                DateTime.tryParse(raw['created_at'] as String? ?? '') ??
                DateTime.now(),
            updatedAt:
                DateTime.tryParse(raw['updated_at'] as String? ?? '') ??
                DateTime.now(),
          );
        }
        debugPrint('[SyncService] Merged ${updatedDayLogs.length} day logs');
      }

      // Шаг 5d: применяем удаления с других устройств (без создания нового
      // надгробия — удаляем напрямую, минуя ItemsDao.deleteItem).
      final serverDeletedIds =
          (response['deleted_item_ids'] as List<dynamic>?) ?? <dynamic>[];
      if (serverDeletedIds.isNotEmpty) {
        for (final raw in serverDeletedIds) {
          if (raw is! String) continue;
          await (_db.delete(
            _db.itemsTable,
          )..where((t) => t.id.equals(raw))).go();
        }
        debugPrint(
          '[SyncService] Applied ${serverDeletedIds.length} remote deletions',
        );
      }

      // Шаг 5e: адоптируем серверные значения заморозок (ADR-044, LWW).
      // Сервер уже выполнил LWW по last_freeze_accrual_at между устройствами —
      // клиент принимает пришедшие значения как авторитетные.
      // Правило: если сервер вернул null last_freeze_accrual_at (не знает о заморозках) —
      // не затираем локальные данные (приоритет первого устройства с данными).
      final serverStreak = response['streak'] as Map<String, dynamic>?;
      if (serverStreak != null) {
        final serverLastAccrual = serverStreak['last_freeze_accrual_at'] as String?;
        if (serverLastAccrual != null) {
          // Сервер знает о заморозках — принимаем его значения целиком.
          final serverFreezeCount = (serverStreak['freeze_count'] as num?)?.toInt();
          if (serverFreezeCount != null) {
            await _streakDao.updateStreak(
              StreakTableCompanion(freezeCount: Value(serverFreezeCount)),
            );
            debugPrint(
              '[SyncService] Adopted server freeze_count=$serverFreezeCount',
            );
          }
          await _prefs.setString(kLastFreezeAccrualKey, serverLastAccrual);
          debugPrint(
            '[SyncService] Adopted server last_freeze_accrual_at=$serverLastAccrual',
          );
        } else {
          // Сервер вернул null курсор: не трогаем локальные данные.
          debugPrint(
            '[SyncService] Server streak.last_freeze_accrual_at=null — local values preserved',
          );
        }

        // Дополнительно: синхронизируем current/longest/last_completed_date стрика,
        // если сервер вернул их в том же объекте streak.
        final serverCurrent = (serverStreak['current'] as num?)?.toInt();
        final serverLongest = (serverStreak['longest'] as num?)?.toInt();
        final serverLastDateStr = serverStreak['last_completed_date'] as String?;
        final serverLastDate = serverLastDateStr != null
            ? DateTime.tryParse(serverLastDateStr)
            : null;

        if (serverCurrent != null || serverLongest != null || serverLastDate != null) {
          final companion = StreakTableCompanion(
            current: serverCurrent != null ? Value(serverCurrent) : const Value.absent(),
            longest: serverLongest != null ? Value(serverLongest) : const Value.absent(),
            lastCompletedDate:
                serverLastDate != null ? Value(serverLastDate) : const Value.absent(),
          );
          await _streakDao.updateStreak(companion);
          debugPrint(
            '[SyncService] Adopted server streak: current=$serverCurrent '
            'longest=$serverLongest last_completed_date=$serverLastDateStr',
          );
        }
      }

      // Шаг 6: сохраняем метку успешной синхронизации
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await _apiClient.saveLastSyncAt(nowUtc);
      debugPrint('[SyncService] Sync complete, last_sync_at=$nowUtc');
    } catch (e, stack) {
      // Offline-first: ошибки синхронизации не должны ломать UI
      debugPrint('[SyncService] Sync failed: $e');
      debugPrintStack(label: '[SyncService]', stackTrace: stack);
    }
  }

  // ---------------------------------------------------------------------------
  // Конвертация ItemsTableData → snake_case Map (для API)
  // ---------------------------------------------------------------------------

  /// Сериализует локальную запись в snake_case для отправки на сервер.
  /// user_id = 'local' до реализации авторизации; сервер игнорирует это поле
  /// и подставляет свой userId из JWT.
  Map<String, dynamic> _itemToSnakeCase(ItemsTableData item) {
    return {
      'id': item.id,
      'user_id': item.userId, // сервер перезапишет своим userId
      'title': item.title,
      'type': item.type,
      'priority': item.priority,
      'status': item.status,
      'scheduled_at': item.scheduledAt.toUtc().toIso8601String(),
      'duration_minutes': item.durationMinutes,
      'is_protected': item.isProtected,
      'recurrence_rule': item.recurrenceRule,
      'reminder_minutes_before': item.reminderMinutesBefore,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'updated_at': item.updatedAt.toUtc().toIso8601String(),
    };
  }

  // ---------------------------------------------------------------------------
  // Конвертация snake_case Map (от сервера) → ItemsTableCompanion (для Drift)
  // ---------------------------------------------------------------------------

  /// Парсит ответ сервера (snake_case) в Drift-companion для upsert.
  /// Поля обязательны согласно схеме Item в api-spec.yaml.
  ItemsTableCompanion _snakeCaseToCompanion(Map<String, dynamic> m) {
    return ItemsTableCompanion(
      id: Value(m['id'] as String),
      userId: Value(m['user_id'] as String),
      title: Value(m['title'] as String),
      type: Value(m['type'] as String),
      priority: Value((m['priority'] as String?) ?? 'medium'),
      status: Value((m['status'] as String?) ?? 'pending'),
      scheduledAt: Value(DateTime.parse(m['scheduled_at'] as String).toLocal()),
      durationMinutes: Value((m['duration_minutes'] as int?) ?? 30),
      isProtected: Value((m['is_protected'] as bool?) ?? false),
      recurrenceRule: Value(m['recurrence_rule'] as String?),
      reminderMinutesBefore: Value((m['reminder_minutes_before'] as num?)?.toInt()),
      createdAt: Value(DateTime.parse(m['created_at'] as String)),
      updatedAt: Value(DateTime.parse(m['updated_at'] as String)),
    );
  }

  // ---------------------------------------------------------------------------
  // Subtasks: Drift ↔ snake_case (вложены в задачу, schemaVersion 14)
  // ---------------------------------------------------------------------------

  /// Подзадачи задачи [itemId] → массив snake_case для отправки.
  /// Контракт: { id, title, done, sort_order } (item_id подразумевается родителем).
  Future<List<Map<String, dynamic>>> _subtasksForItem(String itemId) async {
    final rows = await (_db.select(_db.subtasksTable)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .get();
    return rows
        .map((s) => <String, dynamic>{
              'id': s.id,
              'title': s.title,
              'done': s.done,
              'sort_order': s.sortOrder,
            })
        .toList();
  }

  /// Заменяет локальные подзадачи задачи [itemId] присланным сервером набором
  /// (LWW на уровне задачи). Должен вызываться внутри транзакции.
  Future<void> _replaceSubtasks(String itemId, List<dynamic> raw) async {
    await (_db.delete(_db.subtasksTable)
          ..where((t) => t.itemId.equals(itemId)))
        .go();
    for (final s in raw) {
      if (s is! Map<String, dynamic>) continue;
      final id = s['id'] as String?;
      final title = s['title'] as String?;
      if (id == null || title == null) continue;
      await _db.into(_db.subtasksTable).insert(
            SubtasksTableCompanion(
              id: Value(id),
              itemId: Value(itemId),
              title: Value(title),
              done: Value((s['done'] as bool?) ?? false),
              sortOrder: Value((s['sort_order'] as num?)?.toInt() ?? 0),
            ),
          );
    }
  }

  // ---------------------------------------------------------------------------
  // WaterLog: Drift ↔ snake_case
  // ---------------------------------------------------------------------------

  /// Локальная запись воды → snake_case для отправки (user_id ставит сервер).
  Map<String, dynamic> _waterToSnakeCase(WaterLogsTableData log) {
    return {
      'id': log.id,
      'amount_ml': log.amountMl,
      'logged_at': log.loggedAt.toUtc().toIso8601String(),
    };
  }

  /// Ответ сервера (snake_case) → WaterLogsTableCompanion для upsert.
  /// Локальная таблица не хранит user_id — поле игнорируем.
  WaterLogsTableCompanion _waterSnakeCaseToCompanion(Map<String, dynamic> m) {
    return WaterLogsTableCompanion(
      id: Value(m['id'] as String),
      amountMl: Value((m['amount_ml'] as num).toInt()),
      loggedAt: Value(DateTime.parse(m['logged_at'] as String)),
    );
  }

  // ---------------------------------------------------------------------------
  // FoodLog: Drift ↔ snake_case (append-only, ADR-024)
  // ---------------------------------------------------------------------------

  /// Локальная запись еды → snake_case для отправки (user_id ставит сервер).
  Map<String, dynamic> _foodToSnakeCase(FoodLogsTableData f) {
    final u = f.date.toUtc();
    final dateStr =
        '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
    return {
      'id': f.id,
      'date': dateStr,
      'meal': f.meal,
      'name': f.name,
      'grams': f.grams,
      'calories': f.calories,
      'protein': f.protein,
      'fat': f.fat,
      'carbs': f.carbs,
      'sugar': f.sugar,
      'fiber': f.fiber,
      'created_at': f.createdAt.toUtc().toIso8601String(),
    };
  }

  /// Ответ сервера (snake_case) → FoodLogsTableCompanion для upsert.
  /// null при битой записи (нет обязательных полей).
  FoodLogsTableCompanion? _foodSnakeCaseToCompanion(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    final dateStr = m['date'] as String?;
    final name = m['name'] as String?;
    if (id == null || dateStr == null || name == null) return null;
    final date = DateTime.tryParse('${dateStr}T00:00:00.000Z');
    final createdAt =
        DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now();
    if (date == null) return null;
    return FoodLogsTableCompanion(
      id: Value(id),
      date: Value(date),
      meal: Value((m['meal'] as String?) ?? 'snack'),
      name: Value(name),
      grams: Value((m['grams'] as num?)?.toDouble() ?? 100),
      calories: Value((m['calories'] as num?)?.toDouble()),
      protein: Value((m['protein'] as num?)?.toDouble()),
      fat: Value((m['fat'] as num?)?.toDouble()),
      carbs: Value((m['carbs'] as num?)?.toDouble()),
      sugar: Value((m['sugar'] as num?)?.toDouble()),
      fiber: Value((m['fiber'] as num?)?.toDouble()),
      createdAt: Value(createdAt),
    );
  }

  // ---------------------------------------------------------------------------
  // DayLog → snake_case (для отправки). Дата — YYYY-MM-DD; user_id ставит сервер.
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _dayLogToSnakeCase(DayLogsTableData d) {
    final u = d.date.toUtc();
    final dateStr =
        '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
    return {
      'date': dateStr,
      'mood': d.mood,
      'note': d.note,
      'updated_at': d.updatedAt.toUtc().toIso8601String(),
    };
  }
}

// ---------------------------------------------------------------------------
// Riverpod провайдер
// ---------------------------------------------------------------------------

/// Провайдер сервиса синхронизации.
/// Зависит от apiClientProvider, appDatabaseProvider, streakDaoProvider, sharedPreferencesProvider.
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiClient: ref.read(apiClientProvider),
    db: ref.read(appDatabaseProvider),
    streakDao: ref.read(streakDaoProvider),
    prefs: ref.read(sharedPreferencesProvider),
  );
});
