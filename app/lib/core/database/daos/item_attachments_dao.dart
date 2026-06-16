// DAO для вложений задач (фото/видео). Локальное хранение, без синхронизации.
// Файлы физически удаляются с диска при вызове deleteAttachment.

import 'dart:io';

import 'package:drift/drift.dart';

import '../database.dart';

part 'item_attachments_dao.g.dart';

@DriftAccessor(tables: [ItemAttachmentsTable])
class ItemAttachmentsDao extends DatabaseAccessor<AppDatabase>
    with _$ItemAttachmentsDaoMixin {
  ItemAttachmentsDao(super.db);

  /// Реактивный стрим вложений для задачи [itemId], отсортированных по дате.
  Stream<List<ItemAttachmentsTableData>> watchAttachments(String itemId) {
    return (select(itemAttachmentsTable)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Добавить вложение.
  Future<void> addAttachment(ItemAttachmentsTableCompanion companion) async {
    await into(itemAttachmentsTable).insert(companion);
  }

  /// Удалить вложение по [id] и физически удалить файл с диска.
  Future<void> deleteAttachment(String id) async {
    final rows = await (select(itemAttachmentsTable)
          ..where((t) => t.id.equals(id)))
        .get();
    await (delete(itemAttachmentsTable)..where((t) => t.id.equals(id))).go();
    for (final row in rows) {
      final file = File(row.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// Удалить все вложения задачи (например, при удалении задачи).
  Future<void> deleteAllForItem(String itemId) async {
    final rows = await (select(itemAttachmentsTable)
          ..where((t) => t.itemId.equals(itemId)))
        .get();
    await (delete(itemAttachmentsTable)
          ..where((t) => t.itemId.equals(itemId)))
        .go();
    for (final row in rows) {
      final file = File(row.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
