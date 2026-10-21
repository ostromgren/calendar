import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/main.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';

void main() {
  testWidgets('Calendar app renders header, grid, and event button', (tester) async {
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(repository: repository);

    await tester.pumpWidget(CalendarApp(viewModel: viewModel));
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
    await tester.enterText(find.widgetWithText(TextField, 'Event Title'), 'Test Meeting');
    await tester.tap(find.text('Save Event'));
    await tester.pumpAndSettle();

    // Modal is dismissed and new event is added
    expect(find.text('Add Event'), findsNothing);
    expect(viewModel.selectedDateEvents.any((e) => e.title == 'Test Meeting'), isTrue);

    // Scroll down in CustomScrollView to view the new event tile
    await tester.scrollUntilVisible(
      find.text('Test Meeting'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Test Meeting'), findsOneWidget);
  });

  testWidgets('Swiping forward and backward changes focused month', (tester) async {
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(repository: repository);

    await tester.pumpWidget(CalendarApp(viewModel: viewModel));
    await tester.pumpAndSettle();

    final currentMonthLabel = DateFormat('MMMM yyyy').format(viewModel.focusedMonth);
    expect(find.text(currentMonthLabel), findsOneWidget);

    final nextMonthDate = DateTime(viewModel.focusedMonth.year, viewModel.focusedMonth.month + 1, 1);
    final nextMonthLabel = DateFormat('MMMM yyyy').format(nextMonthDate);

    final prevMonthDate = DateTime(viewModel.focusedMonth.year, viewModel.focusedMonth.month - 1, 1);
    final prevMonthLabel = DateFormat('MMMM yyyy').format(prevMonthDate);

    // Swipe left (fling right-to-left) to go forward one month
    await tester.fling(find.byType(CustomScrollView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text(nextMonthLabel), findsOneWidget);
    expect(find.text(currentMonthLabel), findsNothing);

    // Swipe right (fling left-to-right) to go backward one month (back to current month)
    await tester.fling(find.byType(CustomScrollView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text(currentMonthLabel), findsOneWidget);

    // Swipe right again to go backward another month
    await tester.fling(find.byType(CustomScrollView), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text(prevMonthLabel), findsOneWidget);
  });
}
