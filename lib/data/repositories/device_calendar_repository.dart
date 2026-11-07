import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/calendar_event.dart';
import '../../domain/models/recurrence_frequency.dart';

class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    this.accountName,
    this.color,
    this.readOnly = false,
  });

  final String id;
  final String name;
  final String? accountName;
  final Color? color;
  final bool readOnly;
}

abstract interface class DeviceCalendarRepository {
  bool get isSupported;

  Future<bool> hasPermission();

  Future<bool> requestPermission();

  Future<void> openAppSettings();

  Future<List<DeviceCalendarInfo>> getCalendars();

  Future<List<CalendarEvent>> getEvents(
    DateTime start,
    DateTime end,
    List<String> calendarIds,
  );

  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    required String description,
    required bool isAllDay,
    RecurrenceFrequency? recurrenceFrequency,
    DateTime? recurrenceEndDate,
  });

  Future<void> updateEvent({
    required String instanceId,
    required String title,
    required DateTime start,
    required DateTime end,
    required String description,
    required bool isAllDay,
    required bool updateSeries,
  });

  Future<void> deleteEvent(String instanceId);

  Future<void> deleteEventSeries(String instanceId);
}

class NativeDeviceCalendarRepository implements DeviceCalendarRepository {
  NativeDeviceCalendarRepository({DeviceCalendar? deviceCalendar})
    : _deviceCalendar = deviceCalendar ?? DeviceCalendar.instance;

  final DeviceCalendar _deviceCalendar;

  @override
  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<bool> hasPermission() async =>
      await _deviceCalendar.hasPermissions() ==
      CalendarPermissionStatus.granted;

  @override
  Future<bool> requestPermission() async =>
      await _deviceCalendar.requestPermissions() ==
      CalendarPermissionStatus.granted;

  @override
  Future<void> openAppSettings() => _deviceCalendar.openAppSettings();

  @override
  Future<List<DeviceCalendarInfo>> getCalendars() async {
    final calendars = await _deviceCalendar.listCalendars();
    return calendars
        .map(
          (calendar) => DeviceCalendarInfo(
            id: calendar.id,
            name: calendar.name,
            accountName: calendar.accountName,
            color: calendar.color,
            readOnly: calendar.readOnly,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CalendarEvent>> getEvents(
    DateTime start,
    DateTime end,
    List<String> calendarIds,
  ) async {
    if (calendarIds.isEmpty) return const [];
    final calendars = await _deviceCalendar.listCalendars();
    final colors = {
      for (final calendar in calendars)
        calendar.id: calendar.color ?? Colors.blue,
    };
    final readOnlyCalendars = {
      for (final calendar in calendars) calendar.id: calendar.readOnly,
    };
    final events = await _deviceCalendar.listEvents(
      start,
      end,
      calendarIds: calendarIds,
    );
    return events
        .map((event) {
          final recurrenceFrequency = _frequencyForRule(event.recurrenceRule);
          final recurrenceEnd = event.recurrenceRule?.end;
          return CalendarEvent(
            id: 'device:${event.instanceId}',
            title: event.title,
            description: event.description ?? '',
            calendarId: event.calendarId,
            startTime: event.startDate,
            endTime: event.endDate,
            isAllDay: event.isAllDay,
            color: event.color ?? colors[event.calendarId] ?? Colors.blue,
            readOnly: readOnlyCalendars[event.calendarId] ?? true,
            isDeviceCalendarEvent: true,
            recurrenceFrequency: recurrenceFrequency,
            recurrenceEndDate: recurrenceEnd is UntilEnd
                ? DateTime(
                    recurrenceEnd.until.year,
                    recurrenceEnd.until.month,
                    recurrenceEnd.until.day,
                  )
                : null,
            isRecurring:
                event.isRecurring ||
                InstanceIdParser.parse(event.instanceId).timestamp != null,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    required String description,
    required bool isAllDay,
    RecurrenceFrequency? recurrenceFrequency,
    DateTime? recurrenceEndDate,
  }) async {
    await _deviceCalendar.createEvent(
      calendarId: calendarId,
      title: title,
      startDate: start,
      endDate: end,
      description: description,
      isAllDay: isAllDay,
      recurrenceRule: _recurrenceRule(
        recurrenceFrequency,
        recurrenceEndDate,
        isAllDay,
      ),
    );
  }

  @override
  Future<void> updateEvent({
    required String instanceId,
    required String title,
    required DateTime start,
    required DateTime end,
    required String description,
    required bool isAllDay,
    required bool updateSeries,
  }) async {
    if (updateSeries) {
      await _deviceCalendar.updateRecurring(
        instanceId,
        EventSpan.allEvents,
        title: title,
        start: start,
        duration: end.difference(start),
        description: Patch.set(description),
        isAllDay: isAllDay,
      );
    } else {
      await _deviceCalendar.updateEvent(
        instanceId: instanceId,
        title: title,
        startDate: start,
        endDate: end,
        description: Patch.set(description),
        isAllDay: isAllDay,
      );
    }
  }

  @override
  Future<void> deleteEvent(String instanceId) =>
      _deviceCalendar.deleteEvent(instanceId: instanceId);

  @override
  Future<void> deleteEventSeries(String instanceId) =>
      _deviceCalendar.deleteRecurring(instanceId, EventSpan.allEvents);
}

RecurrenceFrequency? _frequencyForRule(RecurrenceRule? rule) => switch (rule) {
  WeeklyRecurrence(interval: 1) => RecurrenceFrequency.weekly,
  WeeklyRecurrence(interval: 2) => RecurrenceFrequency.everyTwoWeeks,
  WeeklyRecurrence(interval: 3) => RecurrenceFrequency.everyThreeWeeks,
  MonthlyRecurrence() => RecurrenceFrequency.monthly,
  _ => null,
};

RecurrenceRule? _recurrenceRule(
  RecurrenceFrequency? frequency,
  DateTime? endDate,
  bool isAllDay,
) {
  if (frequency == null) return null;

  final recurrenceEnd = endDate == null
      ? null
      : UntilEnd(
          isAllDay
              ? DateTime.utc(endDate.year, endDate.month, endDate.day)
              : DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                  23,
                  59,
                  59,
                ).toUtc(),
        );
  return switch (frequency) {
    RecurrenceFrequency.weekly => WeeklyRecurrence(end: recurrenceEnd),
    RecurrenceFrequency.everyTwoWeeks => WeeklyRecurrence(
      interval: 2,
      end: recurrenceEnd,
    ),
    RecurrenceFrequency.everyThreeWeeks => WeeklyRecurrence(
      interval: 3,
      end: recurrenceEnd,
    ),
    RecurrenceFrequency.monthly => MonthlyRecurrence(
      interval: 1,
      end: recurrenceEnd,
    ),
  };
}
