import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:calendar/ui/features/settings/views/local_calendars_view.dart';

import 'test_app.dart';

void main() {
  testWidgets(
    'local calendar settings offer ICS import and per-calendar export',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.load();
      final viewModel = CalendarViewModel(
        repository: CalendarRepository(),
        settingsRepository: settings,
      );
      final themeViewModel = ThemeViewModel(settingsRepository: settings);
      await tester.pumpWidget(
        createCalendarTestApp(
          settingsRepository: settings,
          calendarViewModel: viewModel,
          themeViewModel: themeViewModel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Local calendars'));
      await tester.pumpAndSettle();

      expect(find.byType(LocalCalendarsView), findsOneWidget);
      expect(
        find.byKey(const ValueKey('import-local-calendar')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('export-calendar-personal')),
        findsOneWidget,
      );
      expect(find.byTooltip('Export calendar'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('delete-calendar-personal')),
        findsNothing,
      );
    },
  );

  testWidgets('deleting a local calendar confirms and removes its contents', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    final themeViewModel = ThemeViewModel(settingsRepository: settings);
    await viewModel.addLocalCalendar('Work');
    final work = viewModel.localCalendars.last;
    await viewModel.addEventCategory(
      calendarId: work.id,
      name: 'Meetings',
      color: Colors.deepPurple,
    );
    await viewModel.addEvent(
      title: 'Planning',
      description: '',
      startTime: DateTime(2026, 10, 26, 9),
      endTime: DateTime(2026, 10, 26, 10),
      calendar: work,
      categoryId: viewModel.categoriesFor(work.id).single.id,
    );

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Local calendars'));
    await tester.pumpAndSettle();

    final deleteWork = find.byKey(ValueKey('delete-calendar-${work.id}'));
    expect(deleteWork, findsOneWidget);
    await tester.tap(deleteWork);
    await tester.pumpAndSettle();
    expect(find.text('Delete local calendar?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(viewModel.localCalendars, hasLength(2));

    await tester.tap(deleteWork);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(viewModel.localCalendars, hasLength(1));
    expect(viewModel.localCalendars.single.id, 'personal');
    expect(viewModel.categoriesFor(work.id), isEmpty);
    expect(repository.getAllEvents(), isEmpty);
    expect(
      find.byKey(const ValueKey('delete-calendar-personal')),
      findsNothing,
    );
    expect((await SettingsRepository.load()).localEvents, isEmpty);
  });

  testWidgets('deleting a category confirms and keeps its events', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    final themeViewModel = ThemeViewModel(settingsRepository: settings);
    await viewModel.addEventCategory(
      calendarId: 'personal',
      name: 'Family',
      color: Colors.orange,
    );
    final category = viewModel.categoriesFor('personal').single;
    await viewModel.addEvent(
      title: 'Pickup',
      description: '',
      startTime: DateTime(2026, 10, 26, 9),
      endTime: DateTime(2026, 10, 26, 10),
      calendar: viewModel.lastUsedCalendar,
      categoryId: category.id,
      categoryColor: category.color,
    );

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Local calendars'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete category'));
    await tester.pumpAndSettle();
    expect(find.text('Delete category?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(viewModel.categoriesFor('personal'), hasLength(1));

    await tester.tap(find.byTooltip('Delete category'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(viewModel.categoriesFor('personal'), isEmpty);
    expect(repository.getAllEvents(), hasLength(1));
    expect(repository.getAllEvents().single.categoryId, isNull);
  });

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

    await viewModel.addEvent(
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

  test(
    'deleting a category keeps events but unassigns that category',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.load();
      final repository = CalendarRepository();
      final viewModel = CalendarViewModel(
        repository: repository,
        settingsRepository: settings,
      );
      await viewModel.addEventCategory(
        calendarId: 'personal',
        name: 'Family',
        color: Colors.orange,
      );
      final category = viewModel.categoriesFor('personal').single;
      await viewModel.addEvent(
        title: 'Pickup',
        description: '',
        startTime: DateTime(2026, 10, 26, 9),
        endTime: DateTime(2026, 10, 26, 10),
        calendar: viewModel.lastUsedCalendar,
        categoryId: category.id,
        categoryColor: category.color,
      );

      await viewModel.deleteEventCategory(category.id);

      expect(viewModel.categoriesFor('personal'), isEmpty);
      expect(repository.getAllEvents().single.categoryId, isNull);
      expect(repository.getAllEvents().single.color, Colors.orange);
      expect(
        (await SettingsRepository.load()).localEvents.single.categoryId,
        isNull,
      );
    },
  );

  test(
    'deleting a calendar removes all events/categories and retains one',
    () async {
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
      await viewModel.addEvent(
        title: 'Pickup',
        description: '',
        startTime: DateTime(2026, 10, 26, 9),
        endTime: DateTime(2026, 10, 26, 10),
        calendar: calendar,
        categoryId: viewModel.categoriesFor(calendar.id).single.id,
      );

      await viewModel.deleteLocalCalendar(calendar.id);

      expect(viewModel.localCalendars, hasLength(1));
      expect(viewModel.lastUsedCalendar.id, 'personal');
      expect(viewModel.categoriesFor(calendar.id), isEmpty);
      expect(repository.getAllEvents(), isEmpty);
      expect((await SettingsRepository.load()).localEvents, isEmpty);
      await expectLater(
        viewModel.deleteLocalCalendar('personal'),
        throwsStateError,
      );
      expect(viewModel.localCalendars.single.id, 'personal');
    },
  );

  test(
    'the original local calendar can be deleted when another remains',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.load();
      final viewModel = CalendarViewModel(
        repository: CalendarRepository(),
        settingsRepository: settings,
      );
      await viewModel.addLocalCalendar('Work');

      await viewModel.deleteLocalCalendar('personal');

      expect(viewModel.localCalendars, hasLength(1));
      expect(viewModel.localCalendars.single.name, 'Work');
      expect(viewModel.lastUsedCalendar.id, viewModel.localCalendars.single.id);
      expect(
        (await SettingsRepository.load()).localCalendars.single.name,
        'Work',
      );
    },
  );

  test(
    'local events persist and reload after a calendar repository restart',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.load();
      final repository = CalendarRepository();
      final viewModel = CalendarViewModel(
        repository: repository,
        settingsRepository: settings,
      );
      final eventStart = DateTime(2026, 10, 26, 9);
      await viewModel.addEvent(
        title: 'Persisted event',
        description: 'Event details',
        startTime: eventStart,
        endTime: eventStart.add(const Duration(hours: 1)),
        calendar: viewModel.lastUsedCalendar,
        categoryColor: Colors.orange,
      );

      final restoredSettings = await SettingsRepository.load();
      final restoredRepository = CalendarRepository(
        initialEvents: restoredSettings.localEvents,
      );

      expect(restoredRepository.getAllEvents(), hasLength(1));
      expect(restoredRepository.getAllEvents().single.title, 'Persisted event');
      expect(
        restoredRepository.getAllEvents().single.color.toARGB32(),
        Colors.orange.toARGB32(),
      );
      await viewModel.deleteEvent(repository.getAllEvents().single.id);
      expect((await SettingsRepository.load()).localEvents, isEmpty);
    },
  );
}
