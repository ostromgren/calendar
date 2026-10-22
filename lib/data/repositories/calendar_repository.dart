import '../../domain/models/calendar_event.dart';

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
    return _events.where((event) => event.isSameDay(date)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void addEvent(CalendarEvent event) {
    _events.add(event);
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
  }
}
