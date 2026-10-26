import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';

void main() {
  test('local calendars and their categories persist in settings', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final viewModel = CalendarViewModel(
      repository: CalendarRepository(),
      settingsRepository: settings,
    );

    await viewModel.addLocalCalendar('Work');
    final workCalendar = viewModel.localCalendars.last;
    await viewModel.addEventCategory(
      calendarId: workCalendar.id,
      name: 'Meetings',
      color: Colors.deepPurple,
    );
    await viewModel.renameLocalCalendar(workCalendar.id, 'Office');

    final restoredSettings = await SettingsRepository.load();
    final restoredCalendar = restoredSettings.localCalendars.last;
    final categories = restoredSettings.getEventCategories(
      calendarId: restoredCalendar.id,
    );

    expect(restoredCalendar.id, workCalendar.id);
    expect(restoredCalendar.name, 'Office');
    expect(categories, hasLength(1));
    expect(categories.single.name, 'Meetings');
    expect(categories.single.color.toARGB32(), Colors.deepPurple.toARGB32());
    expect(
      restoredSettings.getEventCategories(calendarId: 'personal'),
      isEmpty,
    );
  });

  test('events keep the selected local category and its color', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    await viewModel.addLocalCalendar('Kids');
    final calendar = viewModel.localCalendars.last;
    await viewModel.addEventCategory(
      calendarId: calendar.id,
      name: 'School',
      color: Colors.orange,
    );
    final category = viewModel.categoriesFor(calendar.id).single;
    final now = DateTime.now();

    viewModel.addEvent(
      title: 'School pickup',
      description: '',
      startTime: now,
      endTime: now.add(const Duration(hours: 1)),
      calendar: calendar,
      categoryId: category.id,
      categoryColor: category.color,
    );

    final event = repository.getAllEvents().single;
    expect(event.calendarId, calendar.id);
    expect(event.categoryId, category.id);
    expect(event.color, Colors.orange);
  });
}
