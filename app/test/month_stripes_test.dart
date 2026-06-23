// Юнит-тесты цвета полоски-задачи для месячного блочного вида (FEATURE 2).
// taskStripeColor — чистая функция: пользовательский цвет-метка имеет приоритет,
// иначе ember для exam/deadline, accent (primary) для main, иначе нейтральный
// border/outline. ext передаём null → проверяем ветки фоллбэка на ColorScheme.

import 'package:app/core/database/database.dart';
import 'package:app/features/plan/widgets/time_grid.dart';
import 'package:app/features/today/task_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Минимальная фабрика item для теста цвета полоски.
ItemsTableData makeItem({
  String type = 'task',
  String priority = 'medium',
  String? color,
}) {
  return ItemsTableData(
    id: 'i1',
    userId: 'local',
    title: 'T',
    type: type,
    priority: priority,
    status: 'pending',
    scheduledAt: DateTime(2026, 6, 22, 10),
    durationMinutes: 30,
    isProtected: false,
    recurrenceRule: null,
    moduleLink: null,
    color: color,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
}

void main() {
  const scheme = ColorScheme.dark(
    primary: Color(0xFFD9F24B), // accent
    secondary: Color(0xFFFF6A3D), // ember-фоллбэк
    outline: Color(0xFF3A3020), // border-фоллбэк
  );

  group('taskStripeColor', () {
    test('пользовательский цвет-метка имеет приоритет над типом', () {
      final item = makeItem(type: 'exam', color: 'blue');
      expect(taskStripeColor(item, null, scheme), taskColorFromKey('blue'));
    });

    test('exam → ember (secondary при ext == null)', () {
      final item = makeItem(type: 'exam');
      expect(taskStripeColor(item, null, scheme), scheme.secondary);
    });

    test('deadline → ember (secondary при ext == null)', () {
      final item = makeItem(type: 'deadline');
      expect(taskStripeColor(item, null, scheme), scheme.secondary);
    });

    test('priority=main → accent (primary)', () {
      final item = makeItem(type: 'task', priority: 'main');
      expect(taskStripeColor(item, null, scheme), scheme.primary);
    });

    test('обычная задача → нейтральный border (outline при ext == null)', () {
      final item = makeItem(type: 'task', priority: 'low');
      expect(taskStripeColor(item, null, scheme), scheme.outline);
    });

    test('неизвестный ключ цвета откатывается на правило типа/приоритета', () {
      final item = makeItem(type: 'task', priority: 'main', color: 'no-such');
      // taskColorFromKey('no-such') == null → дальше main → primary.
      expect(taskStripeColor(item, null, scheme), scheme.primary);
    });
  });
}
