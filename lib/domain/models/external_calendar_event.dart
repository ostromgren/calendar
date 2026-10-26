import 'recurrence_frequency.dart';

/// An event received from another app or an .ics calendar file.
class ExternalCalendarEvent {
  const ExternalCalendarEvent({
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    this.categoryName,
    this.categoryColor,
    this.recurrenceFrequency,
    this.recurrenceEndDate,
    this.excludedOccurrenceDates = const [],
  });

  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final String? categoryName;
  final int? categoryColor;
  final RecurrenceFrequency? recurrenceFrequency;
  final DateTime? recurrenceEndDate;
  final List<String> excludedOccurrenceDates;
}
