import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/device_calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/ui/features/settings/view_models/device_calendars_view_model.dart';

class _FakeDeviceCalendarRepository implements DeviceCalendarRepository {
  @override
  bool isSupported = true;

  bool permissionGranted = true;
  final calendars = <DeviceCalendarInfo>[
    const DeviceCalendarInfo(
      id: 'google-primary',
      name: 'Personal',
      accountName: 'person@example.com',
    ),
    const DeviceCalendarInfo(
      id: 'google-work',
      name: 'Work',
      accountName: 'person@example.com',
    ),
  ];
  final events = <CalendarEvent>[
    CalendarEvent(
      id: 'device:event-1',
      title: 'Google event',
      calendarId: 'google-primary',
      startTime: DateTime(2026, 10, 24, 9),
      endTime: DateTime(2026, 10, 24, 10),
      color: Colors.green,
      readOnly: true,
    ),
  ];
  List<String> requestedCalendarIds = const [];
  String? createdCalendarId;
  final deletedInstanceIds = <String>[];

  @override
  Future<List<DeviceCalendarInfo>> getCalendars() async => calendars;

  @override
  Future<List<CalendarEvent>> getEvents(
    DateTime start,
    DateTime end,
    List<String> calendarIds,
  ) async {
    requestedCalendarIds = calendarIds;
    return events
        .where((event) => calendarIds.contains(event.calendarId))
        .toList();
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
    createdCalendarId = calendarId;
    events.add(
      CalendarEvent(
        id: 'device:created-event',
        title: title,
        description: description,
        calendarId: calendarId,
        startTime: start,
        endTime: end,
        isAllDay: isAllDay,
        readOnly: false,
        isDeviceCalendarEvent: true,
      ),
    );
  }

  @override
  Future<void> deleteEvent(String instanceId) async {
    deletedInstanceIds.add(instanceId);
    events.removeWhere((event) => event.id == 'device:$instanceId');
  }

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<bool> requestPermission() async {
    permissionGranted = true;
    return permissionGranted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'loads device calendars and defaults to showing all calendars',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.load();
      final repository = _FakeDeviceCalendarRepository();
      final viewModel = DeviceCalendarsViewModel(
        repository: repository,
        settingsRepository: settings,
      );
      await viewModel.refreshEventsForRange(
        DateTime(2026, 10, 1),
        DateTime(2026, 11, 1),
      );

      await viewModel.load();

      expect(viewModel.calendars, hasLength(2));
      expect(viewModel.selectedCalendarIds, {'google-primary', 'google-work'});
      expect(
        repository.requestedCalendarIds,
        containsAll(viewModel.selectedCalendarIds),
      );
      expect(viewModel.eventsFor(DateTime(2026, 10, 24)), hasLength(1));
      expect(viewModel.hasEventsOn(DateTime(2026, 10, 24)), isTrue);
    },
  );

  test('calendar selection persists and filters device events', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final repository = _FakeDeviceCalendarRepository();
    final viewModel = DeviceCalendarsViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    await viewModel.refreshEventsForRange(
      DateTime(2026, 10, 1),
      DateTime(2026, 11, 1),
    );
    await viewModel.load();

    await viewModel.setCalendarSelected('google-primary', false);

    expect(viewModel.selectedCalendarIds, {'google-work'});
    expect(viewModel.events, isEmpty);
    expect(settings.deviceCalendarIds, ['google-work']);
  });

  test('creates and deletes events in the selected device calendar', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final repository = _FakeDeviceCalendarRepository();
    final viewModel = DeviceCalendarsViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    await viewModel.refreshEventsForRange(
      DateTime(2026, 10, 1),
      DateTime(2026, 11, 1),
    );
    await viewModel.load();

    await viewModel.createEvent(
      calendarId: 'google-work',
      title: 'Planning',
      description: 'Quarterly planning',
      start: DateTime(2026, 10, 24, 11),
      end: DateTime(2026, 10, 24, 12),
      isAllDay: false,
    );

    expect(repository.createdCalendarId, 'google-work');
    expect(viewModel.events.any((event) => event.title == 'Planning'), isTrue);

    await viewModel.deleteEvent('device:event-1');

    expect(repository.deletedInstanceIds, ['event-1']);
    expect(
      viewModel.events.any((event) => event.title == 'Google event'),
      isFalse,
    );
  });
}
