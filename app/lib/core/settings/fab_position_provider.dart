// Настройка горизонтального положения FAB (кнопка «+»).
// Значение по умолчанию — right (правая сторона экрана) — совпадает с
// текущим поведением и не ломает ничего при первом запуске.
// Хранится в SharedPreferences; применяется к Scaffold.floatingActionButtonLocation
// на всех экранах с FAB.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_provider.dart'; // sharedPreferencesProvider

// ---------------------------------------------------------------------------
// Enum и расширение
// ---------------------------------------------------------------------------

/// Горизонтальное положение FAB.
enum FabPosition { left, center, right }

extension FabPositionX on FabPosition {
  /// Маппинг в стандартный [FloatingActionButtonLocation] Material.
  FloatingActionButtonLocation get fabLocation => switch (this) {
        FabPosition.left => FloatingActionButtonLocation.startFloat,
        FabPosition.center => FloatingActionButtonLocation.centerFloat,
        FabPosition.right => FloatingActionButtonLocation.endFloat,
      };
}

// ---------------------------------------------------------------------------
// SharedPreferences ключ
// ---------------------------------------------------------------------------

const _kFabPositionKey = 'fab_position';

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class FabPositionNotifier extends Notifier<FabPosition> {
  @override
  FabPosition build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_kFabPositionKey);
    return FabPosition.values.firstWhere(
      (p) => p.name == saved,
      orElse: () => FabPosition.right, // дефолт — правый угол (текущее поведение)
    );
  }

  Future<void> set(FabPosition position) async {
    await ref.read(sharedPreferencesProvider).setString(_kFabPositionKey, position.name);
    state = position;
  }
}

/// Положение FAB: `left` → startFloat, `center` → centerFloat, `right` → endFloat.
final fabPositionProvider =
    NotifierProvider<FabPositionNotifier, FabPosition>(FabPositionNotifier.new);
