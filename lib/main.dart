import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import 'data/calendar_intent_service.dart';
import 'data/repositories/settings_repository.dart';
import 'providers.dart';
import 'ui/core/theme.dart';
import 'ui/features/calendar/views/calendar_view.dart';

/// Entry point of the Flutter application.
///
/// [WidgetsFlutterBinding.ensureInitialized] must be called before any
/// native or asynchronous initialization. [runApp] inflates the widget
/// tree and attaches it to the screen surface.
void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final intentService = CalendarIntentService(executableArguments: arguments);

  // Load settings before providers create view models so startup uses the
  // user's saved preferences.
  final settingsRepository = await SettingsRepository.load();

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        calendarIntentServiceProvider.overrideWithValue(intentService),
      ],
      child: const CalendarApp(),
    ),
  );
}

/// Root widget of the application.
///
/// Wraps [MaterialApp] in [DynamicColorBuilder] so Android 12+ wallpaper and
/// palette colors are made available to [AppTheme.createTheme].
class CalendarApp extends ConsumerWidget {
  const CalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final themeViewModel = ref.watch(themeViewModelProvider);
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
            intentService: ref.watch(calendarIntentServiceProvider),
          ),
        );
      },
    );
  }
}
