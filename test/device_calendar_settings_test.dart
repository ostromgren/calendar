import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/device_calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/domain/models/recurrence_frequency.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/device_calendars_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:calendar/ui/features/settings/views/device_calendars_view.dart';

import 'test_app.dart';

class _FakeDeviceCalendarRepository implements DeviceCalendarRepository {
  @override
  bool isSupported = true;

  bool _hasPermission = false;

  final calendars = const [
    DeviceCalendarInfo(
      id: 'google-primary',
      name: 'Personal',
      accountName: 'person.with.a.very.long.email.address@example.com',
    ),
    DeviceCalendarInfo(
      id: 'google-work',
      name: 'Work',
      accountName: 'person.with.a.very.long.email.address@example.com',
    ),
  ];
  final events = <CalendarEvent>[];

  @override
  Future<List<DeviceCalendarInfo>> getCalendars() async => calendars;

  @override
  Future<List<CalendarEvent>> getEvents(
    DateTime start,
    DateTime end,
    List<String> calendarIds,
  ) async =>
      events.where((e) => calendarIds.contains(e.calendarId)).toList();

  String? createdCalendarId;
  RecurrenceFrequency? createdRecurrenceFrequency;
  DateTime? createdRecurrenceEndDate;
  final deletedInstanceIds = <String>[];
  final deletedSeriesInstanceIds = <String>[];

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
    createdCalendarId = calendarId;
    createdRecurrenceFrequency = recurrenceFrequency;
    createdRecurrenceEndDate = recurrenceEndDate;
    events.add(
      CalendarEvent(
        id: recurrenceFrequency != null
            ? 'device:created-event@${start.millisecondsSinceEpoch}'
            : 'device:created-event',
        title: title,
        description: description,
        calendarId: calendarId,
        startTime: start,
        endTime: end,
        isAllDay: isAllDay,
        readOnly: false,
        isDeviceCalendarEvent: true,
        isRecurring: recurrenceFrequency != null,
        recurrenceFrequency: recurrenceFrequency,
        recurrenceEndDate: recurrenceEndDate,
      ),
    );
  }

  @override
  Future<void> deleteEvent(String instanceId) async {
    deletedInstanceIds.add(instanceId);
    events.removeWhere((e) => e.id == 'device:$instanceId');
  }

  @override
  Future<void> deleteEventSeries(String instanceId) async {
    deletedSeriesInstanceIds.add(instanceId);
    final baseId = instanceId.contains('@')
        ? instanceId.substring(0, instanceId.lastIndexOf('@'))
        : instanceId;
    events.removeWhere((event) {
      final rawId = event.id.startsWith('device:')
          ? event.id.substring('device:'.length)
          : event.id;
      final eventBaseId = rawId.contains('@')
          ? rawId.substring(0, rawId.lastIndexOf('@'))
          : rawId;
      return eventBaseId == baseId;
    });
  }

  @override
  Future<bool> hasPermission() async => _hasPermission;

  @override
  Future<void> openAppSettings() async {}

  @override
  Future<bool> requestPermission() async {
    _hasPermission = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(CalendarViewModel, ThemeViewModel, DeviceCalendarsViewModel)>
  createViewModels(_FakeDeviceCalendarRepository repository) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    return (
      CalendarViewModel(
        repository: CalendarRepository(),
        settingsRepository: settings,
      ),
      ThemeViewModel(settingsRepository: settings),
      DeviceCalendarsViewModel(
        repository: repository,
        settingsRepository: settings,
      ),
    );
  }

  testWidgets('account settings grant access and list device calendars', (
    tester,
  ) async {
    final (calendarViewModel, themeViewModel, deviceCalendarsViewModel) =
        await createViewModels(_FakeDeviceCalendarRepository());

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: deviceCalendarsViewModel.settingsRepository,
        calendarViewModel: calendarViewModel,
        themeViewModel: themeViewModel,
        deviceCalendarsViewModel: deviceCalendarsViewModel,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Device calendars'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Device calendars'));
    await tester.pumpAndSettle();

    expect(find.byType(DeviceCalendarsView), findsOneWidget);
    expect(find.text('Allow calendar access'), findsOneWidget);
    await tester.tap(find.text('Allow calendar access'));
    await tester.pumpAndSettle();

    expect(
      find.text('person.with.a.very.long.email.address@example.com'),
      findsOneWidget,
    );
    expect(find.text('Personal'), findsOneWidget);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
  });

  testWidgets('recurring event can be saved to a synced account calendar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeDeviceCalendarRepository();
    final (calendarViewModel, themeViewModel, deviceCalendarsViewModel) =
        await createViewModels(repository);
    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: deviceCalendarsViewModel.settingsRepository,
        calendarViewModel: calendarViewModel,
        themeViewModel: themeViewModel,
        deviceCalendarsViewModel: deviceCalendarsViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Device calendars'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Device calendars'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Allow calendar access'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckboxListTile).first);
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('New Event'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Event Title'),
      'Synced event',
    );
    final calendarDropdown = find.byKey(
      const ValueKey('event-calendar-dropdown'),
    );
    await tester.ensureVisible(calendarDropdown);
    await tester.tap(calendarDropdown);
    await tester.pumpAndSettle();
    expect(
      find.text('Personal • person.with.a.very.long.email.address@example.com'),
      findsNothing,
    );
    await tester.tap(
      find.text('Work • person.with.a.very.long.email.address@example.com'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final recurrenceDropdown = find.byKey(
      const ValueKey('event-recurrence-dropdown'),
    );
    await tester.ensureVisible(recurrenceDropdown);
    await tester.tap(recurrenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 2 weeks'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repository.createdCalendarId, 'google-work');
    expect(
      repository.createdRecurrenceFrequency,
      RecurrenceFrequency.everyTwoWeeks,
    );
    expect(repository.createdRecurrenceEndDate, isNotNull);
    expect(find.text('Add Event'), findsNothing);

    await tester.tap(find.text('New Event'));
    await tester.pumpAndSettle();
    expect(
      find.text('Work • person.with.a.very.long.email.address@example.com'),
      findsOneWidget,
    );
    expect(
      (await SettingsRepository.load()).lastUsedCalendarDestination,
      'device:google-work',
    );
  });

  testWidgets(
    'recurring event on device calendar can be deleted as entire series or single occurrence',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final repository = _FakeDeviceCalendarRepository();
      repository._hasPermission = true;
      repository.events.addAll([
        CalendarEvent(
          id: 'device:recurring-ev@${now.millisecondsSinceEpoch}',
          title: 'Recurring Standup',
          calendarId: 'google-primary',
          startTime: DateTime(now.year, now.month, now.day, 10),
          endTime: DateTime(now.year, now.month, now.day, 11),
          readOnly: false,
          isDeviceCalendarEvent: true,
          isRecurring: true,
        ),
      ]);

      final (calendarViewModel, themeViewModel, deviceCalendarsViewModel) =
          await createViewModels(repository);
      await deviceCalendarsViewModel.load();

      await tester.pumpWidget(
        createCalendarTestApp(
          settingsRepository: deviceCalendarsViewModel.settingsRepository,
          calendarViewModel: calendarViewModel,
          themeViewModel: themeViewModel,
          deviceCalendarsViewModel: deviceCalendarsViewModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recurring Standup'), findsOneWidget);

      // Tap delete on recurring device event
      await tester.tap(find.byKey(const ValueKey('event-delete-button')));
      await tester.pumpAndSettle();

      expect(find.text('Delete recurring event?'), findsOneWidget);
      expect(find.text('This event only'), findsOneWidget);
      expect(find.text('Entire series'), findsOneWidget);

      // Tap Entire series
      await tester.tap(find.text('Entire series'));
      await tester.pumpAndSettle();

      expect(
        repository.deletedSeriesInstanceIds,
        ['recurring-ev@${now.millisecondsSinceEpoch}'],
      );
      expect(find.text('Recurring Standup'), findsNothing);
    },
  );

  testWidgets(
    'non-recurring event on device calendar shows synced deletion confirmation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final repository = _FakeDeviceCalendarRepository();
      repository._hasPermission = true;
      repository.events.add(
        CalendarEvent(
          id: 'device:single-event-1',
          title: 'One-off Sync Event',
          calendarId: 'google-primary',
          startTime: DateTime(now.year, now.month, now.day, 14),
          endTime: DateTime(now.year, now.month, now.day, 15),
          readOnly: false,
          isDeviceCalendarEvent: true,
          isRecurring: false,
        ),
      );

      final (calendarViewModel, themeViewModel, deviceCalendarsViewModel) =
          await createViewModels(repository);
      await deviceCalendarsViewModel.load();

      await tester.pumpWidget(
        createCalendarTestApp(
          settingsRepository: deviceCalendarsViewModel.settingsRepository,
          calendarViewModel: calendarViewModel,
          themeViewModel: themeViewModel,
          deviceCalendarsViewModel: deviceCalendarsViewModel,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('One-off Sync Event'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('event-delete-button')));
      await tester.pumpAndSettle();

      expect(find.text('Delete synced event?'), findsOneWidget);
      expect(find.text('Delete event'), findsOneWidget);

      await tester.tap(find.text('Delete event'));
      await tester.pumpAndSettle();

      expect(repository.deletedInstanceIds, ['single-event-1']);
      expect(find.text('One-off Sync Event'), findsNothing);
    },
  );
}
