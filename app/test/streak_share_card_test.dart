// streak_share_card_test.dart
// MANDATORY anti-regression: overflow guard для StreakShareCard.
//
// Проверяет два сценария из CLAUDE.md §B:
//   1. 320px ширина (узкий iPhone SE) — нет RenderFlex overflow.
//   2. textScale 2.0 (крупный шрифт, a11y) — нет overflow.
//
// Нативный share_plus НЕ тестируется — тестируется только виджет.
// pumpAndSettle НЕ используется (deadlock guard для анимаций).

import 'package:app/core/theme/app_theme.dart';
import 'package:app/features/today/widgets/streak_share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Тестовая тема — FocusThemeExtension с минимальными полями
// (новые поля v4 имеют дефолты, поэтому ненужно перечислять все)
// ---------------------------------------------------------------------------

ThemeData _testTheme() => ThemeData.dark().copyWith(
      extensions: const [
        FocusThemeExtension(
          textMuted: Color(0xFF9E9070),
          ember: Color(0xFFFF6A3D),
          border: Color(0xFF3A3020),
          surfaceElevated: Color(0xFF2E2618),
          textFaint: Color(0xFF736850),
          accentMuted: Color(0xFF26290F),
          success: Color(0xFF4BAF6F),
          borderStrong: Color(0xFF524630),
        ),
      ],
    );

// ---------------------------------------------------------------------------
// Хелпер: оборачивает карточку в MaterialApp с нужным textScale
// ---------------------------------------------------------------------------

Widget _buildCard(int count, {double textScale = 1.0}) {
  // Используем MaterialApp(builder:) а не внешний MediaQuery-враппер:
  // MaterialApp создаёт собственный MediaQuery из метрик View, перезаписывая
  // внешний. builder выполняется ПОСЛЕ того, как MaterialApp создаёт свой
  // MediaQuery, поэтому copyWith здесь фактически применяется к виджетам.
  return MaterialApp(
    theme: _testTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: Center(
        child: StreakShareCard(
          streakCount: count,
          repaintKey: GlobalKey(),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Тесты
// ---------------------------------------------------------------------------

void main() {
  group('StreakShareCard', () {
    testWidgets(
        'рендерится без overflow на 320 × 640 (узкий телефон, textScale 1.0)',
        (tester) async {
      // Устанавливаем узкое окно: 320px — физическая ширина (devicePixelRatio 1.0)
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildCard(42));
      // Один frame — достаточно для layout; pumpAndSettle опущен (animation deadlock)
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('рендерится без overflow при textScale 2.0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildCard(365, textScale: 2.0));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('рендерится без overflow при textScale 2.0 на узком экране',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(_buildCard(99, textScale: 2.0));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('отображает число стрика в карточке', (tester) async {
      await tester.pumpWidget(_buildCard(7));
      await tester.pump();

      // Число '7' должно быть на экране
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('корректно рендерит стрик = 0 (новый пользователь)',
        (tester) async {
      await tester.pumpWidget(_buildCard(0));
      await tester.pump();

      expect(find.text('0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('корректно рендерит большой стрик (4 цифры)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 1000+ дней: проверяем, что FittedBox справляется с длинным числом
      await tester.pumpWidget(_buildCard(1234));
      await tester.pump();

      expect(find.text('1234'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
