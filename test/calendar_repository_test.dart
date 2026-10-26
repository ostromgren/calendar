import 'package:flutter_test/flutter_test.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/domain/models/recurrence_frequency.dart';

void main() {
  test('CalendarRepository starts without default events', () {
    final repository = CalendarRepository();

    expect(repository.getAllEvents(), isEmpty);
  });

  test('weekly recurrence expands through its inclusive end date', () {
    final event = CalendarEvent(
      id: 'weekly',
      title: 'Weekly meeting',
      startTime: DateTime(2026, 1, 5, 9),
      endTime: DateTime(2026, 1, 5, 10),
      recurrenceFrequency: RecurrenceFrequency.everyTwoWeeks,
      recurrenceEndDate: DateTime(2026, 2, 2),
    );
    final repository = CalendarRepository(initialEvents: [event]);

    final occurrences = repository.getEventsBetween(
      DateTime(2026, 1, 1),
      DateTime(2026, 2, 15),
    );

    expect(occurrences.map((occurrence) => occurrence.startTime), [
      DateTime(2026, 1, 5, 9),
      DateTime(2026, 1, 19, 9),
      DateTime(2026, 2, 2, 9),
    ]);
  });

  test(
    'monthly recurrence clamps short months and supports single deletion',
    () {
      final event = CalendarEvent(
        id: 'monthly',
        title: 'Monthly meeting',
        startTime: DateTime(2026, 1, 31, 9),
        endTime: DateTime(2026, 1, 31, 10),
        recurrenceFrequency: RecurrenceFrequency.monthly,
        recurrenceEndDate: DateTime(2026, 4, 30),
      );
      final repository = CalendarRepository(initialEvents: [event]);

      final february = repository.getEventsForDay(DateTime(2026, 2, 28)).single;
      expect(february.startTime, DateTime(2026, 2, 28, 9));
      expect(repository.deleteEvent(february.id), isTrue);
      expect(repository.getEventsForDay(DateTime(2026, 2, 28)), isEmpty);
      expect(repository.getEventsForDay(DateTime(2026, 3, 31)), hasLength(1));
      expect(repository.getAllEvents().single.excludedOccurrenceDates, [
        '2026-02-28',
      ]);
    },
  );

  test('recurrence settings persist in event JSON', () {
    final event = CalendarEvent(
      id: 'json',
      title: 'Recurring event',
      startTime: DateTime(2026, 1, 5, 9),
      endTime: DateTime(2026, 1, 5, 10),
      recurrenceFrequency: RecurrenceFrequency.everyThreeWeeks,
      recurrenceEndDate: DateTime(2026, 3, 30),
      excludedOccurrenceDates: const ['2026-01-26'],
    );

    final restored = CalendarEvent.fromJson(event.toJson());

    expect(restored.recurrenceFrequency, RecurrenceFrequency.everyThreeWeeks);
    expect(restored.recurrenceEndDate, event.recurrenceEndDate);
    expect(restored.excludedOccurrenceDates, ['2026-01-26']);
  });

  test('deleting an occurrence can remove the entire recurring series', () {
    final event = CalendarEvent(
      id: 'series',
      title: 'Recurring event',
      startTime: DateTime(2026, 1, 5, 9),
      endTime: DateTime(2026, 1, 5, 10),
      recurrenceFrequency: RecurrenceFrequency.weekly,
      recurrenceEndDate: DateTime(2026, 2, 2),
    );
    final repository = CalendarRepository(initialEvents: [event]);
    final occurrence = repository.getEventsForDay(DateTime(2026, 1, 12)).single;

    expect(repository.isRecurringOccurrence(occurrence.id), isTrue);
    expect(repository.deleteEventSeries(occurrence.id), isTrue);
    expect(repository.getAllEvents(), isEmpty);
    expect(repository.getEventsForDay(DateTime(2026, 1, 19)), isEmpty);
  });
}
