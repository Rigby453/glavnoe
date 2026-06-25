// Riverpod-слой пользовательских медитативных сессий.
//
// Связывает CustomMeditationDao (Drift) с UI медитаций: декодирует stepsJson в
// список шагов и отдаёт удобную модель [CustomMeditation]. Список сессий
// watch'ит [customMeditationsProvider]; в тестах его можно переопределить
// фейковыми данными — без Drift.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_providers.dart';
import 'meditation_custom.dart';

/// Пользовательская медитативная сессия (раскодированная из БД).
class CustomMeditation {
  const CustomMeditation({
    required this.id,
    required this.name,
    required this.steps,
  });

  final String id;
  final String name;
  final List<MeditationStep> steps;

  /// Суммарная длительность сессии в секундах (сумма шагов).
  int get totalSeconds => steps.fold<int>(0, (acc, s) => acc + s.seconds);
}

/// Реактивный список пользовательских сессий.
///
/// Сессии с пустым (невалидным) списком шагов отфильтровываются — их нечего
/// проигрывать. Пока стрим грузится — пустой список.
final customMeditationsProvider =
    StreamProvider.autoDispose<List<CustomMeditation>>((ref) {
  final dao = ref.watch(customMeditationDaoProvider);
  return dao.watchAll().map(
        (rows) => rows
            .map(
              (r) => CustomMeditation(
                id: r.id,
                name: r.name,
                steps: decodeSteps(r.stepsJson),
              ),
            )
            .where((m) => m.steps.isNotEmpty)
            .toList(),
      );
});
