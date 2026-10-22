import 'package:flutter_test/flutter_test.dart';
import 'package:calendar/data/calendar_intent_parser.dart';

void main() {
  group('parseCalendarFile', () {
    test('parses a timed event and unescapes its text', () {
      final events = parseCalendarFile('''
BEGIN:VCALENDAR
BEGIN:VEVENT
DTSTART:20261022T103000Z
DTEND:20261022T113000Z
SUMMARY:Planning\\, review
DESCRIPTION:First line\\nSecond line
END:VEVENT
END:VCALENDAR
''');

      expect(events, hasLength(1));
      expect(events.single.title, 'Planning, review');
      expect(events.single.description, 'First line\nSecond line');
      expect(
        events.single.startTime,
        DateTime.utc(2026, 10, 22, 10, 30).toLocal(),
      );
      expect(
        events.single.endTime,
        DateTime.utc(2026, 10, 22, 11, 30).toLocal(),
      );
      expect(events.single.isAllDay, isFalse);
    });

    test('parses all-day events and unfolded lines', () {
      final events = parseCalendarFile(
        'BEGIN:VEVENT\r\n'
        'DTSTART;VALUE=DATE:20261022\r\n'
        'SUMMARY:Planning \r\n meeting\r\n'
        'END:VEVENT\r\n',
      );

      expect(events, hasLength(1));
      expect(events.single.title, 'Planning meeting');
      expect(events.single.isAllDay, isTrue);
      expect(events.single.startTime, DateTime(2026, 10, 22));
    });

    test('ignores malformed events', () {
      expect(
        parseCalendarFile('BEGIN:VEVENT\nSUMMARY:No date\nEND:VEVENT'),
        isEmpty,
      );
      expect(parseCalendarFile('not a calendar'), isEmpty);
    });
  });
}
