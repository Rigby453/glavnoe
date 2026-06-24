// DAO для вложений задач (фото/видео). Локальное хранение, без синхронизации.
// Файлы физически удаляются с диска при вызове deleteAttachment.

import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  /// Future-вариант: вложения задачи [itemId], отсортированы по дате.
  /// Нужен там, где у задачи ещё нет id и стрим не подходит (новая задача с
  /// временным itemId '__pending__').
  Future<List<ItemAttachmentsTableData>> getAttachments(String itemId) {
    return (select(itemAttachmentsTable)
          ..where((t) => t.itemId.equals(itemId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Перепривязать все вложения с [fromItemId] на [toItemId].
  /// Используется при сохранении новой задачи: вложения, добавленные до
  /// сохранения, временно лежат под '__pending__' и здесь получают реальный id.
  Future<void> reassignItemId(String fromItemId, String toItemId) async {
    await (update(itemAttachmentsTable)
          ..where((t) => t.itemId.equals(fromItemId)))
        .write(ItemAttachmentsTableCompanion(itemId: Value(toItemId)));
  }

  /// Удалить вложение по [id] и физически удалить файл с диска.
  Future<void> deleteAttachment(String id) async {
    final rows = await (select(itemAttachmentsTable)
          ..where((t) => t.id.equals(id)))
        .get();
    await (delete(itemAttachmentsTable)..where((t) => t.id.equals(id))).go();
    for (final row in rows) {
      await _deleteFileIfAny(row.localPath);
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
      await _deleteFileIfAny(row.localPath);
    }
  }

  /// Удаляет файл вложения с диска, если [localPath] — это реальный путь.
  /// На вебе вложения хранятся как data-URI прямо в localPath (нет файла на
  /// диске), а dart:io File на вебе не работает — поэтому пропускаем web и
  /// data-URI значения.
  Future<void> _deleteFileIfAny(String localPath) async {
    if (kIsWeb || localPath.startsWith('data:')) return;
    final file = File(localPath);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
