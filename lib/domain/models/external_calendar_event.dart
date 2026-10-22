/// An event received from another app or an .ics calendar file.
class ExternalCalendarEvent {
  const ExternalCalendarEvent({
    required this.title,
    required this.description,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
  });

  final String title;
  final String description;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
}
