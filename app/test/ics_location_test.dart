// Юнит-тесты парсинга LOCATION в ICS-событиях (lib/features/import/ics_parser.dart).
// Чистый Dart, без Drift и без виджетов — IcsParser не зависит от платформы.

import 'package:app/features/import/ics_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _wrap(String body) => 'BEGIN:VCALENDAR\r\n'
    'VERSION:2.0\r\n'
    '$body\r\n'
    'END:VCALENDAR\r\n';

String _vevent(String lines) => 'BEGIN:VEVENT\r\n$lines\r\nEND:VEVENT';

void main() {
  group('IcsParser — LOCATION', () {
    test('LOCATION:Room 302 → event.location == "Room 302"', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Math lecture\r\n'
        'DTSTART:20240617T090000\r\n'
        'LOCATION:Room 302',
      ));
      final events = IcsParser.parse(ics);
      expect(events, hasLength(1));
      expect(events.single.location, 'Room 302');
    });

    test('экранированные символы раскрываются: Bldg A\\, Floor 2 → Bldg A, Floor 2', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Meeting\r\n'
        'DTSTART:20240617T090000\r\n'
        r'LOCATION:Bldg A\, Floor 2',
      ));
      final events = IcsParser.parse(ics);
      expect(events.single.location, 'Bldg A, Floor 2');
    });

    test('нет LOCATION → event.location == null', () {
      final ics = _wrap(_vevent(
        'SUMMARY:No venue\r\n'
        'DTSTART:20240617T090000',
      ));
      final events = IcsParser.parse(ics);
      expect(events.single.location, isNull);
    });

    test('пустой LOCATION: → null, а не пустая строка', () {
      final ics = _wrap(_vevent(
        'SUMMARY:Empty venue\r\n'
        'DTSTART:20240617T090000\r\n'
        'LOCATION:',
      ));
      final events = IcsParser.parse(ics);
      expect(events.single.location, isNull);
    });
  });
}
