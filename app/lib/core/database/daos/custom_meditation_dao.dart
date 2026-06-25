// DAO для таблицы custom_meditation — пользовательские медитативные сессии
// (schemaVersion 21). Локально-первый, без синхронизации. Шаги хранятся как
// JSON-строка (см. features/health/meditation_custom.dart), здесь DAO не знает
// о формате — просто читает/пишет колонку stepsJson.

import 'package:drift/drift.dart';

import '../database.dart';
import '../../utils/id.dart';

part 'custom_meditation_dao.g.dart';

@DriftAccessor(tables: [CustomMeditationTable])
class CustomMeditationDao extends DatabaseAccessor<AppDatabase>
    with _$CustomMeditationDaoMixin {
  CustomMeditationDao(super.db);

  /// Все пользовательские сессии, старые первыми (стабильный порядок в списке).
  Stream<List<CustomMeditationTableData>> watchAll() {
    return (select(customMeditationTable)
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Одна сессия по id (для снапшота перед удалением → Undo).
  Future<CustomMeditationTableData?> getById(String id) {
    return (select(customMeditationTable)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Создать сессию. Возвращает сгенерированный id.
  Future<String> create({
    required String name,
    required String stepsJson,
  }) async {
    final id = uuidV4();
    await into(customMeditationTable).insert(
      CustomMeditationTableCompanion(
        id: Value(id),
        name: Value(name),
        stepsJson: Value(stepsJson),
        createdAt: Value(DateTime.now()),
      ),
    );
    return id;
  }

  /// Удалить сессию по id.
  /// Имя метода НЕ `delete` — оно затенило бы унаследованный `delete(table)`
  /// из DatabaseAccessor (используемый ниже), что сломало бы компиляцию.
  Future<void> deleteSession(String id) {
    return (delete(customMeditationTable)..where((t) => t.id.equals(id))).go();
  }

  /// Восстановить сессию из снапшота (после Undo) — тот же id.
  Future<void> restore(CustomMeditationTableData snapshot) {
    return into(customMeditationTable).insertOnConflictUpdate(snapshot);
  }
}
