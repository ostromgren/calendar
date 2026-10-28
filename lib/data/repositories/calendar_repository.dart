import '../../domain/models/calendar_event.dart';
import '../../domain/models/recurrence_frequency.dart';

/// Repository handling event storage and retrieval.
/// In an enterprise app, this connects to SQLite / Hive / Room / Firestore.
class CalendarRepository {
  CalendarRepository({List<CalendarEvent>? initialEvents})
    : _events = List<CalendarEvent>.from(initialEvents ?? const []);

  final List<CalendarEvent> _events;

  List<CalendarEvent> getAllEvents() {
    return List.unmodifiable(_events);
  }

  List<CalendarEvent> getEventsForDay(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    return getEventsBetween(dayStart, dayStart.add(const Duration(days: 1)));
  }

  List<CalendarEvent> getEventsBetween(DateTime start, DateTime end) {
    final events = <CalendarEvent>[];
    for (final event in _events) {
      if (event.recurrenceFrequency == null) {
        if (!event.startTime.isBefore(start) && event.startTime.isBefore(end)) {
          events.add(event);
        }
        continue;
      }

      var index = _firstOccurrenceIndex(event, start);
      while (true) {
        final occurrenceStart = event.occurrenceStart(index);
        if (!occurrenceStart.isBefore(end)) break;
        final occurrenceDate = DateTime(
          occurrenceStart.year,
          occurrenceStart.month,
          occurrenceStart.day,
        );
        final recurrenceEnd = event.recurrenceEndDate;
        if (recurrenceEnd != null &&
            occurrenceDate.isAfter(
              DateTime(
                recurrenceEnd.year,
                recurrenceEnd.month,
                recurrenceEnd.day,
              ),
            )) {
          break;
        }
        final dateKey = event.occurrenceDateKey(occurrenceStart);
        if (!occurrenceStart.isBefore(start) &&
            !event.excludedOccurrenceDates.contains(dateKey)) {
          events.add(
            CalendarEvent(
              id: '${event.id}::$dateKey',
              title: event.title,
              description: event.description,
              calendarId: event.calendarId,
              categoryId: event.categoryId,
              startTime: occurrenceStart,
              endTime: event.isAllDay
                  ? DateTime(
                      occurrenceStart.year,
                      occurrenceStart.month,
                      occurrenceStart.day + 1,
                    )
                  : occurrenceStart.add(
                      event.endTime.difference(event.startTime),
                    ),
              isAllDay: event.isAllDay,
              color: event.color,
              readOnly: event.readOnly,
              isDeviceCalendarEvent: event.isDeviceCalendarEvent,
              isRecurring: true,
            ),
          );
        }
        index++;
      }
    }
    events.sort((first, second) => first.startTime.compareTo(second.startTime));
    return events;
  }

  void addEvent(CalendarEvent event) {
    _events.add(event);
  }

  bool deleteEvent(String id) {
    final index = _events.indexWhere((event) => event.id == id);
    if (index >= 0) {
      _events.removeAt(index);
      return true;
    }
    for (var index = 0; index < _events.length; index++) {
      final event = _events[index];
      final prefix = '${event.id}::';
      if (event.recurrenceFrequency == null || !id.startsWith(prefix)) continue;
      final dateKey = id.substring(prefix.length);
      final occurrenceIndex = _occurrenceIndexForDate(event, dateKey);
      if (occurrenceIndex < 0) return false;
      final occurrenceDate = event.occurrenceStart(occurrenceIndex);
      if (event.occurrenceDateKey(occurrenceDate) != dateKey) return false;
      _events[index] = event.copyWith(
        excludedOccurrenceDates: [...event.excludedOccurrenceDates, dateKey],
      );
      return true;
    }
    return false;
  }

  bool isRecurringOccurrence(String id) {
    for (final event in _events) {
      if (event.recurrenceFrequency != null && id.startsWith('${event.id}::')) {
        return true;
      }
    }
    return false;
  }

  bool deleteEventSeries(String id) {
    final index = _events.indexWhere((event) {
      return event.recurrenceFrequency != null &&
          (event.id == id || id.startsWith('${event.id}::'));
    });
    if (index < 0) return false;
    _events.removeAt(index);
    return true;
  }

  void replaceAllEvents(Iterable<CalendarEvent> events) {
    _events
      ..clear()
      ..addAll(events);
  }

  int _firstOccurrenceIndex(CalendarEvent event, DateTime rangeStart) {
    final frequency = event.recurrenceFrequency!;
    if (rangeStart.isBefore(event.startTime)) return 0;
    if (frequency == RecurrenceFrequency.monthly) {
      final monthDifference =
          (rangeStart.year - event.startTime.year) * 12 +
          rangeStart.month -
          event.startTime.month;
      return (monthDifference - 1).clamp(0, monthDifference).toInt();
    }
    final weekInterval = frequency.weekInterval;
    final dayDifference =
        DateTime(rangeStart.year, rangeStart.month, rangeStart.day)
            .difference(
              DateTime(
                event.startTime.year,
                event.startTime.month,
                event.startTime.day,
              ),
            )
            .inDays;
    final intervalDays = 7 * weekInterval;
    return (dayDifference ~/ intervalDays - 1)
        .clamp(0, dayDifference ~/ intervalDays)
        .toInt();
  }

  int _occurrenceIndexForDate(CalendarEvent event, String dateKey) {
    final date = DateTime.tryParse(dateKey);
    if (date == null) return -1;
    final frequency = event.recurrenceFrequency!;
    if (frequency == RecurrenceFrequency.monthly) {
      return (date.year - event.startTime.year) * 12 +
          date.month -
          event.startTime.month;
    }
    final difference = date
        .difference(
          DateTime(
            event.startTime.year,
            event.startTime.month,
            event.startTime.day,
          ),
        )
        .inDays;
    final intervalDays = frequency.weekInterval * 7;
    if (difference < 0 || difference % intervalDays != 0) return -1;
    return difference ~/ intervalDays;
  }
}
