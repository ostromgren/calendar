import 'package:flutter/material.dart';

/// Represents a scheduled calendar event.
///
/// In Dart, classes with final fields and a const constructor provide
/// immutability (similar to Kotlin data classes with val properties).
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.isAllDay = false,
    this.calendarId = 'personal',
    this.description = '',
    this.color = Colors.blue,
    this.readOnly = false,
    this.isDeviceCalendarEvent = false,
  });

  final String id;
  final String title;
  final String description;
  final String calendarId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final Color color;
  final bool readOnly;
  final bool isDeviceCalendarEvent;

  /// Returns true if this event falls on the specified [date] (ignoring time-of-day).
  bool isSameDay(DateTime date) {
    return startTime.year == date.year &&
        startTime.month == date.month &&
        startTime.day == date.day;
  }

  /// Kotlin copy() equivalent in Dart idiom.
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? calendarId,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    Color? color,
    bool? readOnly,
    bool? isDeviceCalendarEvent,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      calendarId: calendarId ?? this.calendarId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      readOnly: readOnly ?? this.readOnly,
      isDeviceCalendarEvent:
          isDeviceCalendarEvent ?? this.isDeviceCalendarEvent,
    );
  }
}
