import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/main.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';

void main() {
  Future<(CalendarViewModel, ThemeViewModel)> buildViewModels() async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final viewModel = CalendarViewModel(
      repository: CalendarRepository(),
      settingsRepository: settings,
    );
    final themeViewModel = ThemeViewModel(settingsRepository: settings);
    return (viewModel, themeViewModel);
  }

  testWidgets('Calendar app renders header, grid, and event button', (
    tester,
  ) async {
    final (viewModel, themeViewModel) = await buildViewModels();

    await tester.pumpWidget(
      CalendarApp(viewModel: viewModel, themeViewModel: themeViewModel),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    // Verify AppBar title is displayed
    expect(find.text('My Calendar'), findsOneWidget);

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

  testWidgets(
    'Whole-day events hide time pickers and save without a time range',
    (tester) async {
      final (viewModel, themeViewModel) = await buildViewModels();

      await tester.pumpWidget(
        CalendarApp(viewModel: viewModel, themeViewModel: themeViewModel),
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
    final (viewModel, themeViewModel) = await buildViewModels();

    await tester.pumpWidget(
      CalendarApp(viewModel: viewModel, themeViewModel: themeViewModel),
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
