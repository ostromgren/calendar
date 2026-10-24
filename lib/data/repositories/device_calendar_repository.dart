import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/models/calendar_event.dart';

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
  });

  Future<void> deleteEvent(String instanceId);
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
        .map(
          (event) => CalendarEvent(
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
          ),
        )
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
  }) async {
    await _deviceCalendar.createEvent(
      calendarId: calendarId,
      title: title,
      startDate: start,
      endDate: end,
      description: description,
      isAllDay: isAllDay,
    );
  }

  @override
  Future<void> deleteEvent(String instanceId) =>
      _deviceCalendar.deleteEvent(instanceId: instanceId);
}
