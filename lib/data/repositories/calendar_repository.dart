import 'package:flutter/material.dart';
import '../../domain/models/calendar_event.dart';

/// Repository handling event storage and retrieval.
/// In an enterprise app, this connects to SQLite / Hive / Room / Firestore.
class CalendarRepository {
  CalendarRepository({List<CalendarEvent>? initialEvents})
      : _events = List<CalendarEvent>.from(initialEvents ?? _defaultEvents);

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

  // Pre-populated events around today to make the starter app interactive immediately
  static List<CalendarEvent> get _defaultEvents {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      CalendarEvent(
        id: '1',
        title: 'Team Sync & Flutter Kickoff',
        description: 'Review cross-platform architecture and roadmap.',
        startTime: today.add(const Duration(hours: 10)),
        endTime: today.add(const Duration(hours: 11)),
        color: Colors.indigo,
      ),
      CalendarEvent(
        id: '2',
        title: 'Design Review: Android 14 & iOS 18 UI',
        description: 'Verify Material 3 & Cupertino adaptive patterns.',
        startTime: today.add(const Duration(hours: 14)),
        endTime: today.add(const Duration(hours: 15, minutes: 30)),
        color: Colors.teal,
      ),
      CalendarEvent(
        id: '3',
        title: 'Lunch with Mobile Team',
        description: 'Welcome lunch & project planning.',
        startTime: today.add(const Duration(days: 1, hours: 12)),
        endTime: today.add(const Duration(days: 1, hours: 13)),
        color: Colors.amber.shade800,
      ),
      CalendarEvent(
        id: '4',
        title: 'Release Sprint Planning',
        description: 'Finalize backlog for upcoming release milestone.',
        startTime: today.add(const Duration(days: 3, hours: 9)),
        endTime: today.add(const Duration(days: 3, hours: 10)),
        color: Colors.deepPurple,
      ),
    ];
  }
}
