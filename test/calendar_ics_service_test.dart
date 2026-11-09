import 'dart:convert';

import 'package:calendar/data/calendar_ics_service.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/domain/models/event_category.dart';
import 'package:calendar/domain/models/recurrence_frequency.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = CalendarIcsService();

  test('export and import preserve calendar events and app categories', () {
    final category = EventCategory(
      id: 'work-category',
      calendarId: 'work',
      name: 'Work, urgent',
      color: const Color(0xFF7C4DFF),
    );
    final timedEvent = CalendarEvent(
      id: 'meeting-1',
      title: 'Planning; review',
      description: 'First line\nSecond, line',
      calendarId: 'work',
      categoryId: category.id,
      startTime: DateTime(2026, 10, 26, 9),
      endTime: DateTime(2026, 10, 26, 10),
    );
    final allDayEvent = CalendarEvent(
      id: 'all-day-1',
      title: 'Holiday',
      calendarId: 'work',
      startTime: DateTime(2026, 10, 27),
      endTime: DateTime(2026, 10, 28),
      isAllDay: true,
    );
    final contents = service.exportCalendar(
      name: 'Work calendar',
      calendarId: 'work',
      events: [timedEvent, allDayEvent],
      categories: [category],
      generatedAt: DateTime.utc(2026, 1, 1),
    );

    expect(contents, contains('X-WR-CALNAME:Work calendar'));
    expect(contents, contains(r'SUMMARY:Planning\; review'));
    expect(contents, contains(r'DESCRIPTION:First line\nSecond\, line'));
    expect(contents, contains(r'CATEGORIES:Work\, urgent'));
    expect(contents, contains('X-APP-CATEGORY-COLOR:#7C4DFF'));
    expect(contents, contains('DTSTART;VALUE=DATE:20261027'));
    expect(contents, contains('DTEND;VALUE=DATE:20261028'));

    final imported = service.importCalendar(contents);
    expect(imported.name, 'Work calendar');
    expect(imported.events, hasLength(2));
    expect(imported.events.first.title, timedEvent.title);
    expect(imported.events.first.description, timedEvent.description);
    expect(imported.events.first.startTime, timedEvent.startTime);
    expect(imported.events.first.endTime, timedEvent.endTime);
    expect(imported.events.first.categoryId, imported.categories.single.id);
    expect(imported.categories.single.name, category.name);
    expect(imported.categories.single.color, category.color);
    expect(imported.events.last.isAllDay, isTrue);
    expect(imported.events.last.endTime, allDayEvent.endTime);
  });

  test('export folds long UTF-8 lines within the RFC line limit', () {
    final contents = service.exportCalendar(
      name: 'Family',
      calendarId: 'family',
      events: [
        CalendarEvent(
          id: 'long-description',
          title: 'Meeting',
          description: 'Å😀' * 60,
          calendarId: 'family',
          startTime: DateTime(2026, 10, 26, 9),
          endTime: DateTime(2026, 10, 26, 10),
        ),
      ],
      categories: const [],
    );

    for (final line in contents.split('\r\n')) {
      expect(utf8.encode(line).length, lessThanOrEqualTo(75));
    }
  });

  test('ICS import and export preserve supported recurring rules', () {
    final event = CalendarEvent(
      id: 'recurring',
      title: 'Biweekly meeting',
      calendarId: 'work',
      startTime: DateTime(2026, 1, 5, 9),
      endTime: DateTime(2026, 1, 5, 10),
      recurrenceFrequency: RecurrenceFrequency.everyTwoWeeks,
      recurrenceEndDate: DateTime(2026, 2, 2),
      excludedOccurrenceDates: const ['2026-01-19'],
    );

    final contents = service.exportCalendar(
      name: 'Work',
      calendarId: 'work',
      events: [event],
      categories: const [],
    );
    final imported = service.importCalendar(contents).events.single;

    expect(contents, contains('RRULE:FREQ=WEEKLY;INTERVAL=2;UNTIL='));
    expect(imported.recurrenceFrequency, RecurrenceFrequency.everyTwoWeeks);
    expect(imported.recurrenceEndDate, DateTime(2026, 2, 2));
    expect(imported.excludedOccurrenceDates, ['2026-01-19']);
  });

  test('import rejects files without calendar events', () {
    expect(
      () => service.importCalendar('BEGIN:VCALENDAR\r\nEND:VCALENDAR\r\n'),
      throwsFormatException,
    );
    expect(
      () => service.importCalendar('not a calendar'),
      throwsFormatException,
    );
  });

  test('import creates a separate persistent local calendar', () async {
    SharedPreferences.setMockInitialValues({});
    final widgetMethods = <String>[];
    const widgetChannel = MethodChannel('calendar/widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(widgetChannel, (call) async {
          widgetMethods.add(call.method);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(widgetChannel, null);
    });
    final settings = await SettingsRepository.load();
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    final imported = service.importCalendar('''
BEGIN:VCALENDAR
VERSION:2.0
X-WR-CALNAME:Imported family
BEGIN:VEVENT
DTSTART:20261026T090000Z
DTEND:20261026T100000Z
SUMMARY:School pickup
CATEGORIES:Kids
X-APP-CATEGORY-COLOR:#008577
END:VEVENT
END:VCALENDAR
''');

    await viewModel.importLocalCalendar(
      name: imported.name!,
      imported: imported,
    );

    final importedCalendar = viewModel.localCalendars.last;
    expect(importedCalendar.name, 'Imported family');
    expect(repository.getAllEvents().single.calendarId, importedCalendar.id);
    expect(viewModel.categoriesFor(importedCalendar.id).single.name, 'Kids');
    expect(
      (await SettingsRepository.load()).localEvents.single.title,
      'School pickup',
    );
    expect(widgetMethods, contains('refreshWidget'));
  });
}
