import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/calendar/views/widgets/month_header.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('top-left button switches between calendar and agenda views', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final today = DateTime.now();
    final futureDate = DateTime(today.year, today.month, today.day + 2, 10);
    final repository = CalendarRepository(
      initialEvents: [
        CalendarEvent(
          id: 'agenda-event',
          title: 'Agenda test event',
          startTime: futureDate,
          endTime: futureDate.add(const Duration(hours: 1)),
        ),
      ],
    );
    final calendarViewModel = CalendarViewModel(
      repository: repository,
      settingsRepository: settings,
    );
    final themeViewModel = ThemeViewModel(settingsRepository: settings);

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Agenda test event'), findsNothing);
    await tester.tap(find.byTooltip('Show agenda view'));
    await tester.pumpAndSettle();

    expect(find.text('Agenda test event'), findsOneWidget);
    await tester.tap(find.byTooltip('Show calendar view'));
    await tester.pumpAndSettle();

    expect(find.text('Agenda test event'), findsNothing);
  });

  testWidgets('wide phone layout adds side gutters without centering content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsRepository.load();
    final calendarViewModel = CalendarViewModel(
      repository: CalendarRepository(),
      settingsRepository: settings,
    );
    final themeViewModel = ThemeViewModel(settingsRepository: settings);

    await tester.pumpWidget(
      createCalendarTestApp(
        settingsRepository: settings,
        calendarViewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ),
    );
    await tester.pumpAndSettle();

    final monthHeaderRect = tester.getRect(find.byType(MonthHeader));
    expect(monthHeaderRect.left, 24);
    expect(monthHeaderRect.width, greaterThan(700));
    expect(tester.takeException(), isNull);
  });
}
