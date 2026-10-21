import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/main.dart';
import 'package:calendar/ui/core/theme.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:calendar/ui/features/settings/views/settings_view.dart';
import 'package:calendar/ui/features/calendar/views/widgets/week_number_cell.dart';
import 'package:calendar/ui/features/settings/views/theme_selection_view.dart';

void main() {
  group('Theme & Settings Feature Tests', () {
    late CalendarRepository repository;
    late CalendarViewModel calendarViewModel;
    late ThemeViewModel themeViewModel;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final settings = await SettingsRepository.load();
      repository = CalendarRepository();
      calendarViewModel = CalendarViewModel(
        repository: repository,
        settingsRepository: settings,
      );
      themeViewModel = ThemeViewModel(settingsRepository: settings);
    });

    testWidgets('Settings button (cog wheel) is present in top right AppBar and opens SettingsView', (tester) async {
      await tester.pumpWidget(CalendarApp(
        viewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ));
      await tester.pumpAndSettle();

      // Verify the settings button (cog wheel) exists in AppBar
      final settingsButtonFinder = find.byTooltip('Settings');
      expect(settingsButtonFinder, findsOneWidget);
      expect(find.byIcon(Icons.settings), findsOneWidget);

      // Tap settings button
      await tester.tap(settingsButtonFinder);
      await tester.pumpAndSettle();

      // Verify SettingsView is displayed
      expect(find.byType(SettingsView), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('Themes'), findsOneWidget);
      expect(find.text('Calendar Preferences'), findsOneWidget);
      expect(find.text('First Day of Week'), findsOneWidget);
    });

    testWidgets('Navigating from SettingsView to ThemeSelectionView shows 5 curated themes + dynamic theme', (tester) async {
      await tester.pumpWidget(CalendarApp(
        viewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ));
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      // Tap the 'Themes' list tile
      await tester.tap(find.widgetWithText(ListTile, 'Themes'));
      await tester.pumpAndSettle();

      // Verify ThemeSelectionView is displayed
      expect(find.byType(ThemeSelectionView), findsOneWidget);
      expect(find.text('Live Preview'), findsOneWidget);
      expect(find.text('Brightness'), findsOneWidget);

      // Verify dynamic Android theme card is displayed
      expect(find.text('System Palette (Material You)'), findsOneWidget);
      expect(find.text('Android Material You'), findsOneWidget);

      // Verify all 5 curated themes are displayed
      expect(find.text('Ocean Blue'), findsOneWidget);
      expect(find.text('Emerald Forest'), findsOneWidget);
      expect(find.text('Sunset Amber'), findsOneWidget);
      expect(find.text('Deep Purple'), findsOneWidget);
      expect(find.text('Rose Crimson'), findsOneWidget);
    });

    testWidgets('Selecting a curated theme updates ThemeViewModel', (tester) async {
      await tester.pumpWidget(CalendarApp(
        viewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ));
      await tester.pumpAndSettle();

      // Open settings -> Themes
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Themes'));
      await tester.pumpAndSettle();

      // Select 'Emerald Forest'
      await tester.ensureVisible(find.text('Emerald Forest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Emerald Forest'));
      await tester.pumpAndSettle();

      expect(themeViewModel.currentTheme, AppThemeType.emeraldForest);

      // Select 'Sunset Amber'
      await tester.ensureVisible(find.text('Sunset Amber'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sunset Amber'));
      await tester.pumpAndSettle();

      expect(themeViewModel.currentTheme, AppThemeType.sunsetAmber);

      // Select back to 'System Palette (Material You)'
      await tester.ensureVisible(find.text('System Palette (Material You)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('System Palette (Material You)'));
      await tester.pumpAndSettle();

      expect(themeViewModel.currentTheme, AppThemeType.systemDynamic);
    });

    testWidgets('Switching Brightness mode updates ThemeViewModel', (tester) async {
      await tester.pumpWidget(CalendarApp(
        viewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ));
      await tester.pumpAndSettle();

      // Open settings -> Themes
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Themes'));
      await tester.pumpAndSettle();

      // Switch to Dark mode
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(themeViewModel.themeMode, ThemeMode.dark);

      // Switch to Light mode
      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();

      expect(themeViewModel.themeMode, ThemeMode.light);

      // Switch back to System mode
      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();

      expect(themeViewModel.themeMode, ThemeMode.system);
    });

    testWidgets('Changing First Day of Week in SettingsView updates calendar grid and headers', (tester) async {
      await tester.pumpWidget(CalendarApp(
        viewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ));
      await tester.pumpAndSettle();

      // Open settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      // Tap dropdown for First Day of Week
      await tester.tap(find.byType(DropdownButton<StartingDayOfWeek>));
      await tester.pumpAndSettle();

      // Select 'Sunday'
      await tester.tap(find.text('Sunday').last);
      await tester.pumpAndSettle();

      expect(calendarViewModel.firstDayOfWeek, StartingDayOfWeek.sunday);

      // Return to calendar
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify Sun is the first header
      final sunFinder = find.text('Sun');
      final monFinder = find.text('Mon');
      expect(sunFinder, findsOneWidget);
      expect(monFinder, findsOneWidget);
      expect(tester.getTopLeft(sunFinder).dx < tester.getTopLeft(monFinder).dx, isTrue);

      // Open settings again and select Saturday
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButton<StartingDayOfWeek>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Saturday').last);
      await tester.pumpAndSettle();

      expect(calendarViewModel.firstDayOfWeek, StartingDayOfWeek.saturday);

      await tester.pageBack();
      await tester.pumpAndSettle();

      final satFinder = find.text('Sat');
      expect(satFinder, findsOneWidget);
      expect(tester.getTopLeft(satFinder).dx < tester.getTopLeft(sunFinder).dx, isTrue);
    });

    testWidgets('Toggling Show Week Numbers in SettingsView updates calendar view', (tester) async {
      await tester.pumpWidget(CalendarApp(
        viewModel: calendarViewModel,
        themeViewModel: themeViewModel,
      ));
      await tester.pumpAndSettle();

      // Initially no 'W#' header
      expect(find.text('W#'), findsNothing);

      // Open settings
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      // Toggle 'Show Week Numbers' switch
      await tester.tap(find.widgetWithText(SwitchListTile, 'Show Week Numbers'));
      await tester.pumpAndSettle();

      expect(calendarViewModel.showWeekNumbers, isTrue);

      // Return to calendar
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Verify 'W#' column header is displayed
      expect(find.text('W#'), findsOneWidget);

      // Verify week numbers are present in the grid including Week 43 (current week)
      expect(find.byType(WeekNumberCell), findsWidgets);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('41'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('43'), findsOneWidget); // Week of October 19–25, 2026
      expect(find.text('44'), findsOneWidget);

      // Go back to settings and turn off
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Show Week Numbers'));
      await tester.pumpAndSettle();

      expect(calendarViewModel.showWeekNumbers, isFalse);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('W#'), findsNothing);
      expect(find.byType(WeekNumberCell), findsNothing);
    });

    test('AppTheme.createTheme generates valid light and dark ThemeData with dynamic and seed colors', () {
      // Dynamic fallback
      final dynamicFallback = AppTheme.createTheme(
        brightness: Brightness.light,
        themeType: AppThemeType.systemDynamic,
        dynamicColorScheme: null,
      );
      expect(dynamicFallback.useMaterial3, isTrue);
      expect(dynamicFallback.brightness, Brightness.light);

      // Dynamic custom scheme
      const testScheme = ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF00FF00),
        onPrimary: Color(0xFF000000),
        secondary: Color(0xFF0000FF),
        onSecondary: Color(0xFFFFFFFF),
        error: Color(0xFFFF0000),
        onError: Color(0xFFFFFFFF),
        surface: Color(0xFF121212),
        onSurface: Color(0xFFFFFFFF),
      );

      final dynamicApplied = AppTheme.createTheme(
        brightness: Brightness.dark,
        themeType: AppThemeType.systemDynamic,
        dynamicColorScheme: testScheme,
      );
      expect(dynamicApplied.colorScheme.primary, const Color(0xFF00FF00));

      // Each of the 5 curated themes builds without error
      for (final type in AppThemeType.values) {
        final lightTheme = AppTheme.createTheme(
          brightness: Brightness.light,
          themeType: type,
        );
        final darkTheme = AppTheme.createTheme(
          brightness: Brightness.dark,
          themeType: type,
        );
        expect(lightTheme.useMaterial3, isTrue);
        expect(darkTheme.useMaterial3, isTrue);
      }
    });
  });
}
