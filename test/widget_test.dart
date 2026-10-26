import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/app_language.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';
import 'package:calendar/ui/features/calendar/calendar_greeting.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/domain/models/recurrence_frequency.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';

import 'test_app.dart';

void main() {
  Future<(CalendarViewModel, ThemeViewModel, SettingsRepository)>
  buildViewModels() async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final viewModel = CalendarViewModel(
      repository: CalendarRepository(),
      settingsRepository: settings,
    );
    final themeViewModel = ThemeViewModel(settingsRepository: settings);
    return (viewModel, themeViewModel, settings);
  }

  testWidgets('event title is required before saving', (tester) async {
    final (viewModel, themeViewModel, settings) = await buildViewModels();

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Event'));
    await tester.pumpAndSettle();

    final saveButton = find.widgetWithText(FilledButton, 'Save Event');
    expect(find.text('Required'), findsOneWidget);
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Event Title'),
      '   ',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Event Title'),
      'Planning',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('Calendar app renders header, grid, and event button', (
    tester,
  ) async {
    final (viewModel, themeViewModel, settings) = await buildViewModels();

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // Verify the time-based AppBar greeting is displayed.
    final l10n = AppLocalizations.of(tester.element(find.byType(AppBar)))!;
    expect(find.text(calendarGreeting(l10n, DateTime.now())), findsOneWidget);

    // Verify weekday headers are displayed
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Fri'), findsOneWidget);

    // Verify New Event FAB is present
    expect(find.text('New Event'), findsOneWidget);

    // Tap the 'New Event' FAB to open modal
    await tester.tap(find.text('New Event'));
    await tester.pumpAndSettle();

    // Verify the modal sheet appears with the Add Event header
    expect(find.text('Add Event'), findsOneWidget);
    expect(find.text('Save Event'), findsOneWidget);

    // Enter title and save
    await tester.enterText(
      find.widgetWithText(TextField, 'Event Title'),
      'Test Meeting',
    );
    final calendarDropdown = find.byKey(
      const ValueKey('event-calendar-dropdown'),
    );
    await tester.ensureVisible(calendarDropdown);
    await tester.tap(calendarDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personal').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    // Modal is dismissed and new event is added
    expect(find.text('Add Event'), findsNothing);
    expect(
      viewModel.selectedDateEvents.any((e) => e.title == 'Test Meeting'),
      isTrue,
    );
    final savedEvent = viewModel.selectedDateEvents.singleWhere(
      (event) => event.title == 'Test Meeting',
    );
    expect(savedEvent.calendarId, 'personal');
    expect(viewModel.lastUsedCalendar.id, 'personal');

    // The last saved calendar is selected the next time the sheet opens.
    await tester.tap(find.text('New Event'));
    await tester.pumpAndSettle();
    expect(find.text('Personal'), findsOneWidget);
    Navigator.of(tester.element(find.text('Add Event'))).pop();
    await tester.pumpAndSettle();

    final restoredSettings = await SettingsRepository.load();
    final restoredViewModel = CalendarViewModel(
      repository: CalendarRepository(),
      settingsRepository: restoredSettings,
    );
    expect(restoredViewModel.lastUsedCalendar.id, 'personal');

    // Scroll down in CustomScrollView to view the new event tile
    await tester.scrollUntilVisible(
      find.text('Test Meeting'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Test Meeting'), findsOneWidget);
  });

  testWidgets('long Swedish greeting scales to fit in the app bar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    await settings.saveAppLanguage(AppLanguage.swedish);
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

    final l10n = AppLocalizations.of(tester.element(find.byType(AppBar)))!;
    final greetingFinder = find.text(calendarGreeting(l10n, DateTime.now()));
    expect(greetingFinder, findsOneWidget);
    expect(
      find.ancestor(of: greetingFinder, matching: find.byType(FittedBox)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('event descriptions start collapsed and can be expanded', (
    tester,
  ) async {
    final (viewModel, themeViewModel, settings) = await buildViewModels();
    final description =
        'Join the meeting: teams.example.com. ${'Additional notes. ' * 20}';
    final now = DateTime.now();
    await viewModel.addEvent(
      title: 'Long description event',
      description: description,
      startTime: DateTime(now.year, now.month, now.day, 9),
      endTime: DateTime(now.year, now.month, now.day, 10),
      calendar: viewModel.lastUsedCalendar,
    );

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(description),
      200,
      scrollable: find.byType(Scrollable).first,
    );

    final descriptionText = find.text(description);
    expect(tester.widget<Text>(descriptionText).maxLines, 2);
    expect(
      tester.widget<Text>(descriptionText).overflow,
      TextOverflow.ellipsis,
    );
    final card = find.byKey(const ValueKey('event-tile-card'));
    final marker = find.byKey(const ValueKey('event-color-marker'));
    final deleteButton = find.byKey(const ValueKey('event-delete-button'));
    final markerPosition = tester.getTopLeft(marker) - tester.getTopLeft(card);
    final deletePosition =
        tester.getTopLeft(deleteButton) - tester.getTopLeft(card);

    await tester.tap(find.byTooltip('Show full description'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(descriptionText).maxLines, isNull);
    expect(tester.getTopLeft(marker) - tester.getTopLeft(card), markerPosition);
    expect(
      tester.getTopLeft(deleteButton) - tester.getTopLeft(card),
      deletePosition,
    );
  });

  testWidgets('event creation uses a local calendar category color', (
    tester,
  ) async {
    final (viewModel, themeViewModel, settings) = await buildViewModels();
    await viewModel.addLocalCalendar('Work');
    final calendar = viewModel.localCalendars.last;
    await viewModel.addEventCategory(
      calendarId: calendar.id,
      name: 'Meetings',
      color: Colors.deepPurple,
    );
    final category = viewModel.categoriesFor(calendar.id).single;

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New Event'));
    await tester.pumpAndSettle();

    final calendarDropdown = find.byKey(
      const ValueKey('event-calendar-dropdown'),
    );
    await tester.ensureVisible(calendarDropdown);
    await tester.tap(calendarDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    final categoryDropdown = find.byKey(
      ValueKey('event-category-dropdown-${calendar.id}'),
    );
    await tester.ensureVisible(categoryDropdown);
    await tester.tap(categoryDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meetings').last);
    await tester.pumpAndSettle();

    final recurrenceDropdown = find.byKey(
      const ValueKey('event-recurrence-dropdown'),
    );
    await tester.ensureVisible(recurrenceDropdown);
    await tester.tap(recurrenceDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every 2 weeks').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('recurrence-end-date-button')),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Event Title'),
      'Project sync',
    );
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Save Event'))
          .onPressed,
      isNotNull,
    );
    await tester.ensureVisible(find.text('Save Event'));
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    final event = viewModel.repository.getAllEvents().single;
    expect(event.title, 'Project sync');
    expect(event.calendarId, calendar.id);
    expect(event.categoryId, category.id);
    expect(event.color.toARGB32(), Colors.deepPurple.toARGB32());
    expect(event.recurrenceFrequency, RecurrenceFrequency.everyTwoWeeks);
    expect(event.recurrenceEndDate, isNotNull);

    await tester.scrollUntilVisible(
      find.text('Project sync'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('event-delete-button')).last);
    await tester.pumpAndSettle();
    expect(find.text('Delete recurring event?'), findsOneWidget);
    expect(find.text('This event only'), findsOneWidget);
    expect(find.text('Entire series'), findsOneWidget);
    await tester.tap(find.text('This event only'));
    await tester.pumpAndSettle();
    expect(viewModel.selectedDateEvents, isEmpty);
    expect(viewModel.repository.getAllEvents(), hasLength(1));
    expect(viewModel.repository.getAllEvents().single.excludedOccurrenceDates, [
      viewModel.repository.getAllEvents().single.occurrenceDateKey(
        event.startTime,
      ),
    ]);
  });

  testWidgets(
    'Whole-day events hide time pickers and save without a time range',
    (tester) async {
      final (viewModel, themeViewModel, settings) = await buildViewModels();

      await tester.pumpWidget(
        createCalendarTestApp(
          settingsRepository: settings,
          calendarViewModel: viewModel,
          themeViewModel: themeViewModel,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Event'));
      await tester.pumpAndSettle();

      final allDayCheckbox = find.byKey(
        const ValueKey('event-all-day-checkbox'),
      );
      await tester.ensureVisible(allDayCheckbox);
      await tester.tap(allDayCheckbox);
      await tester.pumpAndSettle();

      expect(find.text('Whole day'), findsOneWidget);
      expect(find.textContaining('Start:'), findsNothing);
      expect(find.textContaining('End:'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Event Title'),
        'All-day appointment',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Save Event'));
      await tester.tap(find.text('Save Event'));
      await tester.pumpAndSettle();

      final savedEvent = viewModel.selectedDateEvents.single;
      expect(savedEvent.title, 'All-day appointment');
      expect(savedEvent.isAllDay, isTrue);
      expect(savedEvent.startTime.hour, 0);
      expect(savedEvent.startTime.minute, 0);
      expect(savedEvent.endTime.hour, 0);
      expect(savedEvent.endTime.minute, 0);

      await tester.scrollUntilVisible(
        find.text('All-day appointment'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Whole day'), findsOneWidget);
    },
  );

  testWidgets('Swiping forward and backward changes focused month', (
    tester,
  ) async {
    final (viewModel, themeViewModel, settings) = await buildViewModels();

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: viewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();

    final currentMonthLabel = DateFormat('MMMM yyyy')
        .format(viewModel.focusedMonth);
    expect(find.text(currentMonthLabel), findsOneWidget);

    final nextMonthDate = DateTime(
      viewModel.focusedMonth.year,
      viewModel.focusedMonth.month + 1,
      1,
    );
    final nextMonthLabel = DateFormat('MMMM yyyy').format(nextMonthDate);

    final prevMonthDate = DateTime(
      viewModel.focusedMonth.year,
      viewModel.focusedMonth.month - 1,
      1,
    );
    final prevMonthLabel = DateFormat('MMMM yyyy').format(prevMonthDate);

    // Swipe left (fling right-to-left) to go forward one month
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(-300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(nextMonthLabel), findsOneWidget);
    expect(find.text(currentMonthLabel), findsNothing);

    // Swipe right (fling left-to-right) to go backward one month (back to current month)
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(currentMonthLabel), findsOneWidget);

    // Swipe right again to go backward another month
    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(300, 0),
      1000,
    );
    await tester.pumpAndSettle();

    expect(find.text(prevMonthLabel), findsOneWidget);
  });
}
