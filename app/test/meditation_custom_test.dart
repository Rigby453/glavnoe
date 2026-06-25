// Юнит-тесты кодека пользовательских медитативных сессий (meditation_custom.dart).
// Чистые функции encodeSteps/decodeSteps — без Flutter/Drift.
// Проверяем: пустой список, один шаг, многошаговый порядок, точный round-trip,
// безопасную деградацию битого JSON в пустой список и фильтрацию неполных полей.

import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/health/meditation_custom.dart';

void main() {
  group('encode/decode round-trip', () {
    test('пустой список → "[]" → пустой список', () {
      final json = encodeSteps(const []);
      expect(json, '[]');
      expect(decodeSteps(json), isEmpty);
    });

    test('один шаг round-trip сохраняет text и seconds', () {
      const steps = [MeditationStep(text: 'Breathe slowly', seconds: 60)];
      final decoded = decodeSteps(encodeSteps(steps));
      expect(decoded, hasLength(1));
      expect(decoded.first.text, 'Breathe slowly');
      expect(decoded.first.seconds, 60);
    });

    test('многошаговый round-trip сохраняет порядок', () {
      const steps = [
        MeditationStep(text: 'Settle in', seconds: 30),
        MeditationStep(text: 'Scan your body', seconds: 90),
        MeditationStep(text: 'Rest in stillness', seconds: 120),
      ];
      final decoded = decodeSteps(encodeSteps(steps));
      expect(decoded.map((s) => s.text).toList(),
          ['Settle in', 'Scan your body', 'Rest in stillness']);
      expect(decoded.map((s) => s.seconds).toList(), [30, 90, 120]);
    });

    test('сырой текст с кавычками/юникодом переживает round-trip', () {
      const steps = [
        MeditationStep(text: 'Скажи себе: «я спокоен» 🙂', seconds: 45),
      ];
      final decoded = decodeSteps(encodeSteps(steps));
      expect(decoded, hasLength(1));
      expect(decoded.first.text, 'Скажи себе: «я спокоен» 🙂');
      expect(decoded.first.seconds, 45);
    });
  });

  group('decode — безопасная деградация', () {
    test('битый JSON → пустой список', () {
      expect(decodeSteps('not json {{{'), isEmpty);
    });

    test('пустая строка → пустой список', () {
      expect(decodeSteps(''), isEmpty);
    });

    test('JSON-объект (не массив) → пустой список', () {
      expect(decodeSteps('{"text":"hi"}'), isEmpty);
    });

    test('JSON null → пустой список', () {
      expect(decodeSteps('null'), isEmpty);
    });

    test('массив с мусором: невалидные элементы отброшены, валидные оставлены',
        () {
      // Валидный шаг + строка + шаг без seconds + пустой text + seconds<=0.
      const json = '[{"text":"Focus on breath","seconds":60},'
          '"garbage",'
          '{"text":"No seconds"},'
          '{"text":"   ","seconds":30},'
          '{"text":"Zero","seconds":0}]';
      final decoded = decodeSteps(json);
      expect(decoded, hasLength(1));
      expect(decoded.first.text, 'Focus on breath');
      expect(decoded.first.seconds, 60);
    });

    test('seconds как число с плавающей точкой усекается до int', () {
      const json = '[{"text":"Hold","seconds":59.9}]';
      final decoded = decodeSteps(json);
      expect(decoded, hasLength(1));
      expect(decoded.first.seconds, 59);
    });

    test('text не-строка → элемент отброшен', () {
      const json = '[{"text":123,"seconds":30}]';
      expect(decodeSteps(json), isEmpty);
    });
  });
}
