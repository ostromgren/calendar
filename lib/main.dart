import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import 'data/calendar_intent_service.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'ui/core/theme.dart';
import 'ui/features/calendar/view_models/calendar_view_model.dart';
import 'ui/features/calendar/views/calendar_view.dart';
import 'ui/features/settings/view_models/theme_view_model.dart';

/// Entry point of the Flutter application.
///
/// [WidgetsFlutterBinding.ensureInitialized] must be called before any
/// native or asynchronous initialization. [runApp] inflates the widget
/// tree and attaches it to the screen surface.
void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final intentService = CalendarIntentService(executableArguments: arguments);

  // Load persisted settings before constructing view models so that the UI
  // starts with the user's last-chosen preferences immediately.
  final settingsRepository = await SettingsRepository.load();

  // Instantiate dependencies manually here.
  // In larger apps, consider a dependency injection package such as get_it or riverpod.
  final calendarRepository = CalendarRepository();
  final calendarViewModel = CalendarViewModel(
    repository: calendarRepository,
    settingsRepository: settingsRepository,
  );
  final themeViewModel = ThemeViewModel(settingsRepository: settingsRepository);

  runApp(
    CalendarApp(
      viewModel: calendarViewModel,
      themeViewModel: themeViewModel,
      intentService: intentService,
    ),
  );
}

/// Root widget of the application.
///
/// Wraps [MaterialApp] in [DynamicColorBuilder] so Android 12+ wallpaper and
/// palette colors are made available to [AppTheme.createTheme].
class CalendarApp extends StatelessWidget {
  const CalendarApp({
    super.key,
    required this.viewModel,
    required this.themeViewModel,
    this.intentService,
  });

  final CalendarViewModel viewModel;
  final ThemeViewModel themeViewModel;
  final CalendarIntentService? intentService;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return ListenableBuilder(
          listenable: themeViewModel,
          builder: (context, _) {
            final lightTheme = AppTheme.createTheme(
              brightness: Brightness.light,
              themeType: themeViewModel.currentTheme,
              dynamicColorScheme: lightDynamic,
            );
            final darkTheme = AppTheme.createTheme(
              brightness: Brightness.dark,
              themeType: themeViewModel.currentTheme,
              dynamicColorScheme: darkDynamic,
            );

            return MaterialApp(
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeViewModel.themeMode,
              locale: themeViewModel.locale,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: CalendarView(
                viewModel: viewModel,
                themeViewModel: themeViewModel,
                intentService: intentService,
              ),
            );
          },
        );
      },
    );
  }
}
