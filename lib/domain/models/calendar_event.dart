import 'package:flutter/material.dart';

import 'recurrence_frequency.dart';

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
    this.categoryId,
    this.description = '',
    this.color = Colors.blue,
    this.readOnly = false,
    this.isDeviceCalendarEvent = false,
    this.recurrenceFrequency,
    this.recurrenceEndDate,
    this.excludedOccurrenceDates = const [],
    bool? isRecurring,
  }) : isRecurring = isRecurring ?? (recurrenceFrequency != null);

  final String id;
  final String title;
  final String description;
  final String calendarId;
  final String? categoryId;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final Color color;
  final bool readOnly;
  final bool isDeviceCalendarEvent;
  final RecurrenceFrequency? recurrenceFrequency;
  final DateTime? recurrenceEndDate;
  final List<String> excludedOccurrenceDates;
  final bool isRecurring;

  /// Returns true if this event falls on the specified [date] (ignoring time-of-day).
  bool isSameDay(DateTime date) {
    return startTime.year == date.year &&
        startTime.month == date.month &&
        startTime.day == date.day;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'calendarId': calendarId,
    'categoryId': categoryId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'isAllDay': isAllDay,
    'color': color.toARGB32(),
    'recurrenceFrequency': recurrenceFrequency?.name,
    'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
    'excludedOccurrenceDates': excludedOccurrenceDates,
    'isRecurring': isRecurring,
  };

  factory CalendarEvent.fromJson(Map<String, dynamic> json) => CalendarEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    calendarId: json['calendarId'] as String? ?? 'personal',
    categoryId: json['categoryId'] as String?,
    startTime: DateTime.parse(json['startTime'] as String),
    endTime: DateTime.parse(json['endTime'] as String),
    isAllDay: json['isAllDay'] as bool? ?? false,
    color: Color(json['color'] as int? ?? Colors.blue.toARGB32()),
    recurrenceFrequency: _recurrenceFrequencyFromJson(
      json['recurrenceFrequency'],
    ),
    recurrenceEndDate: json['recurrenceEndDate'] == null
        ? null
        : DateTime.parse(json['recurrenceEndDate'] as String),
    excludedOccurrenceDates:
        (json['excludedOccurrenceDates'] as List<dynamic>?)?.cast<String>() ??
        const [],
    isRecurring:
        json['isRecurring'] as bool? ?? (json['recurrenceFrequency'] != null),
  );

  /// Kotlin copy() equivalent in Dart idiom.
  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    String? calendarId,
    String? categoryId,
    bool clearCategoryId = false,
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    Color? color,
    bool? readOnly,
    bool? isDeviceCalendarEvent,
    RecurrenceFrequency? recurrenceFrequency,
    DateTime? recurrenceEndDate,
    List<String>? excludedOccurrenceDates,
    bool? isRecurring,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      calendarId: calendarId ?? this.calendarId,
      categoryId: clearCategoryId ? null : categoryId ?? this.categoryId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isAllDay: isAllDay ?? this.isAllDay,
      color: color ?? this.color,
      readOnly: readOnly ?? this.readOnly,
      isDeviceCalendarEvent:
          isDeviceCalendarEvent ?? this.isDeviceCalendarEvent,
      recurrenceFrequency: recurrenceFrequency ?? this.recurrenceFrequency,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      excludedOccurrenceDates:
          excludedOccurrenceDates ?? this.excludedOccurrenceDates,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  DateTime occurrenceStart(int index) {
    final frequency = recurrenceFrequency;
    if (frequency == null || index == 0) return startTime;
    if (frequency == RecurrenceFrequency.monthly) {
      final targetMonth = startTime.month - 1 + index;
      final year = startTime.year + targetMonth ~/ 12;
      final month = targetMonth % 12 + 1;
      final day = startTime.day
          .clamp(1, DateTime(year, month + 1, 0).day)
          .toInt();
      return DateTime(
        year,
        month,
        day,
        startTime.hour,
        startTime.minute,
        startTime.second,
        startTime.millisecond,
        startTime.microsecond,
      );
    }
    return DateTime(
      startTime.year,
      startTime.month,
      startTime.day + 7 * frequency.weekInterval * index,
      startTime.hour,
      startTime.minute,
      startTime.second,
      startTime.millisecond,
      startTime.microsecond,
    );
  }

  String occurrenceDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

RecurrenceFrequency? _recurrenceFrequencyFromJson(Object? value) {
  for (final frequency in RecurrenceFrequency.values) {
    if (frequency.name == value) return frequency;
  }
  return null;
}
