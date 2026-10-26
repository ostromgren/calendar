import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/app_language.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';
import 'package:calendar/ui/features/calendar/calendar_greeting.dart';
import 'package:calendar/ui/core/theme.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:calendar/ui/features/settings/views/settings_view.dart';
import 'package:calendar/ui/features/calendar/views/widgets/week_number_cell.dart';
import 'package:calendar/ui/features/settings/views/theme_selection_view.dart';
import 'package:calendar/ui/features/settings/views/advanced_color_picker_view.dart';

import 'test_app.dart';

void main() {
  group('Theme & Settings Feature Tests', () {
    late CalendarRepository repository;
    late CalendarViewModel calendarViewModel;
    late ThemeViewModel themeViewModel;
    late SettingsRepository settingsRepository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      settingsRepository = await SettingsRepository.load();
      repository = CalendarRepository();
      calendarViewModel = CalendarViewModel(
        repository: repository,
        settingsRepository: settingsRepository,
      );
      themeViewModel = ThemeViewModel(settingsRepository: settingsRepository);
    });

    testWidgets(
      'Settings button (cog wheel) is present in top right AppBar and opens SettingsView',
      (tester) async {
        await tester.pumpWidget(
          createCalendarTestApp(
            settingsRepository: settingsRepository,
            calendarViewModel: calendarViewModel,
            themeViewModel: themeViewModel,
          ),
        );
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
      },
    );

    testWidgets(
      'Selecting Swedish localizes the app and persists the language',
      (tester) async {
        await tester.pumpWidget(
          createCalendarTestApp(
            settingsRepository: settingsRepository,
            calendarViewModel: calendarViewModel,
            themeViewModel: themeViewModel,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        final languageDropdown = find.byWidgetPredicate(
          (widget) => widget is DropdownButton<AppLanguage>,
        );
        await tester.tap(languageDropdown);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Swedish').last);
        await tester.pumpAndSettle();

        expect(find.text('Inställningar'), findsOneWidget);
        expect(find.text('Språk'), findsOneWidget);
        expect(settingsRepository.appLanguage, AppLanguage.swedish);
        expect(
          ThemeViewModel(settingsRepository: await SettingsRepository.load())
              .appLanguage,
          AppLanguage.swedish,
        );

        Navigator.of(tester.element(find.byType(SettingsView))).pop();
        await tester.pumpAndSettle();
        expect(
          find.text(
            calendarGreeting(
              AppLocalizations.of(tester.element(find.byType(AppBar)))!,
              DateTime.now(),
            ),
          ),
          findsOneWidget,
        );
        expect(
          find.text(
            DateFormat(
              'MMMM yyyy',
              'sv',
            ).format(calendarViewModel.focusedMonth),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byTooltip('Inställningar'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byWidgetPredicate(
            (widget) => widget is DropdownButton<AppLanguage>,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('System').last);
        await tester.pumpAndSettle();
        Navigator.of(tester.element(find.byType(SettingsView))).pop();
        await tester.pumpAndSettle();

        expect(
          find.text(
            calendarGreeting(
              AppLocalizations.of(tester.element(find.byType(AppBar)))!,
              DateTime.now(),
            ),
          ),
          findsOneWidget,
        );
        expect(settingsRepository.appLanguage, AppLanguage.system);
      },
    );

    testWidgets(
      'Navigating from SettingsView to ThemeSelectionView shows 5 curated themes + dynamic theme',
      (tester) async {
        await tester.pumpWidget(
          createCalendarTestApp(
            settingsRepository: settingsRepository,
            calendarViewModel: calendarViewModel,
            themeViewModel: themeViewModel,
          ),
        );
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

        // Verify the system theme is platform-neutral.
        expect(find.text('System Palette'), findsOneWidget);
        expect(find.textContaining('Android'), findsNothing);

        // Verify all 5 curated themes are displayed
        expect(find.text('Ocean Blue'), findsOneWidget);
        expect(find.text('Emerald Forest'), findsOneWidget);
        expect(find.text('Sunset Amber'), findsOneWidget);
        expect(find.text('Deep Purple'), findsOneWidget);
        expect(find.text('Rose Crimson'), findsOneWidget);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('advanced-color-option')))
              .dy,
          greaterThan(tester.getTopLeft(find.text('Rose Crimson')).dy),
        );
      },
    );

    testWidgets('Selecting a curated theme updates ThemeViewModel', (
      tester,
    ) async {
      await tester.pumpWidget(
        createCalendarTestApp(
          settingsRepository: settingsRepository,
          calendarViewModel: calendarViewModel,
          themeViewModel: themeViewModel,
        ),
      );
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

      // Select back to the system palette.
      await tester.ensureVisible(find.text('System Palette'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('System Palette'));
      await tester.pumpAndSettle();

      expect(themeViewModel.currentTheme, AppThemeType.systemDynamic);
    });

    testWidgets('Switching Brightness mode updates ThemeViewModel', (
      tester,
    ) async {
      await tester.pumpWidget(
        createCalendarTestApp(
          settingsRepository: settingsRepository,
          calendarViewModel: calendarViewModel,
          themeViewModel: themeViewModel,
        ),
      );
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

    testWidgets(
      'Advanced color picker applies and persists custom theme color',
      (tester) async {
        themeViewModel.setCustomThemeColor(const Color(0xFF797979));
        await tester.pumpWidget(
          createCalendarTestApp(
            settingsRepository: settingsRepository,
            calendarViewModel: calendarViewModel,
            themeViewModel: themeViewModel,
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme!
              .colorScheme
              .primary,
          AppTheme.createTheme(
            brightness: Brightness.light,
            themeType: AppThemeType.custom,
            customSeedColor: const Color(0xFF797979),
          ).colorScheme.primary,
        );
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Themes'));
        await tester.pumpAndSettle();

        final advancedOption = find.byKey(
          const ValueKey('advanced-color-option'),
        );
        await tester.ensureVisible(advancedOption);
        await tester.pumpAndSettle();
        await tester.tap(advancedOption);
        await tester.pumpAndSettle();
        expect(find.byType(AdvancedColorPickerView), findsOneWidget);

        final hexField = find.byKey(const ValueKey('custom-color-hex'));
        final grayPreview = tester.widget<FilledButton>(
          find.byKey(const ValueKey('custom-color-preview-button')),
        );
        expect(
          grayPreview.style!.backgroundColor!.resolve({}),
          AppTheme.createTheme(
            brightness: Brightness.light,
            themeType: AppThemeType.custom,
            customSeedColor: const Color(0xFF797979),
          ).colorScheme.primary,
        );
        final ringRect = tester.getRect(
          find.byKey(const ValueKey('custom-color-hue-ring')),
        );
        await tester.tapAt(
          Offset(ringRect.center.dx, ringRect.top + ringRect.height * 0.05),
        );
        await tester.pump();
        final hueSelection = tester
            .widget<TextField>(hexField)
            .controller!
            .text
            .substring(1);
        final hueColor = Color(int.parse('FF$hueSelection', radix: 16));
        expect(HSVColor.fromColor(hueColor).hue, closeTo(0, 1));
        expect(HSVColor.fromColor(hueColor).saturation, greaterThan(0.7));

        await tester.enterText(hexField, '#E91E63');
        await tester.pump();
        expect(find.byType(AdvancedColorPickerView), findsOneWidget);
        final previewButton = tester.widget<FilledButton>(
          find.byKey(const ValueKey('custom-color-preview-button')),
        );
        expect(
          previewButton.style!.backgroundColor!.resolve({}),
          AppTheme.createTheme(
            brightness: Brightness.light,
            themeType: AppThemeType.custom,
            customSeedColor: const Color(0xFFE91E63),
          ).colorScheme.primary,
        );
        final applyButton = find.byKey(const ValueKey('apply-custom-color'));
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(applyButton, findsOneWidget);
        await tester.tap(applyButton);
        await tester.pumpAndSettle();

        expect(themeViewModel.currentTheme, AppThemeType.custom);
        expect(themeViewModel.customThemeColor, const Color(0xFFE91E63));
        expect(settingsRepository.themeType, AppThemeType.custom);
        expect(settingsRepository.customThemeColor, const Color(0xFFE91E63));
        expect(
          tester
              .widget<MaterialApp>(find.byType(MaterialApp))
              .theme!
              .colorScheme
              .primary,
          AppTheme.createTheme(
            brightness: Brightness.light,
            themeType: AppThemeType.custom,
            customSeedColor: const Color(0xFFE91E63),
          ).colorScheme.primary,
        );
        expect(
          AppTheme.createTheme(
            brightness: Brightness.light,
            themeType: themeViewModel.currentTheme,
            customSeedColor: themeViewModel.customThemeColor,
          ).colorScheme.primary,
          isNot(const Color(0xFF2563EB)),
        );
      },
    );

    testWidgets(
      'Changing First Day of Week in SettingsView updates calendar grid and headers',
      (tester) async {
        await tester.pumpWidget(
          createCalendarTestApp(
            settingsRepository: settingsRepository,
            calendarViewModel: calendarViewModel,
            themeViewModel: themeViewModel,
          ),
        );
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
        expect(
          tester.getTopLeft(sunFinder).dx < tester.getTopLeft(monFinder).dx,
          isTrue,
        );

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
        expect(
          tester.getTopLeft(satFinder).dx < tester.getTopLeft(sunFinder).dx,
          isTrue,
        );
      },
    );

    testWidgets(
      'Toggling Show Week Numbers in SettingsView updates calendar view',
      (tester) async {
        await tester.pumpWidget(
          createCalendarTestApp(
            settingsRepository: settingsRepository,
            calendarViewModel: calendarViewModel,
            themeViewModel: themeViewModel,
          ),
        );
        await tester.pumpAndSettle();

        // Initially no 'W#' header
        expect(find.text('W#'), findsNothing);

        // Open settings
        await tester.tap(find.byTooltip('Settings'));
        await tester.pumpAndSettle();

        // Toggle 'Show Week Numbers' switch
        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Show Week Numbers'),
        );
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

        await tester.tap(
          find.widgetWithText(SwitchListTile, 'Show Week Numbers'),
        );
        await tester.pumpAndSettle();

        expect(calendarViewModel.showWeekNumbers, isFalse);

        await tester.pageBack();
        await tester.pumpAndSettle();

        expect(find.text('W#'), findsNothing);
        expect(find.byType(WeekNumberCell), findsNothing);
      },
    );

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
