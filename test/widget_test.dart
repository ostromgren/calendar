import 'package:flutter_test/flutter_test.dart';

import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/main.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';

void main() {
  testWidgets('Calendar app renders header, grid, and event button', (tester) async {
    final repository = CalendarRepository();
    final viewModel = CalendarViewModel(repository: repository);

    // Build the CalendarApp and trigger a frame.
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
  });
}
