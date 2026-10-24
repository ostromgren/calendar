import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/device_calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/main.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/device_calendars_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:calendar/ui/features/settings/views/device_calendars_view.dart';

class _FakeDeviceCalendarRepository implements DeviceCalendarRepository {
  @override
  bool isSupported = true;

  bool _hasPermission = false;

  @override
  Future<List<DeviceCalendarInfo>> getCalendars() async => const [
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

  @override
  Future<List<CalendarEvent>> getEvents(
    DateTime start,
    DateTime end,
    List<String> calendarIds,
  ) async => const [];

  String? createdCalendarId;

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
  }

  @override
  Future<void> deleteEvent(String instanceId) async {}

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
      CalendarApp(
        viewModel: calendarViewModel,
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

  testWidgets('new event can be saved to a synced account calendar', (
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
      CalendarApp(
        viewModel: calendarViewModel,
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
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    expect(repository.createdCalendarId, 'google-work');
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
}
