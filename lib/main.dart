import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import 'data/calendar_intent_service.dart';
import 'data/event_reminder_service.dart';
import 'data/repositories/settings_repository.dart';
import 'domain/models/app_language.dart';
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
  final dismissActionTitle = switch (settingsRepository.appLanguage) {
    AppLanguage.english => 'Dismiss',
    AppLanguage.swedish => 'Avvisa',
    AppLanguage.system =>
      WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'sv'
          ? 'Avvisa'
          : 'Dismiss',
  };
  final reminderService = EventReminderService(
    dismissActionTitle: dismissActionTitle,
  );
  unawaited(
    reminderService.initialize().catchError((Object error, StackTrace stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'calendar event reminders',
        ),
      );
    }),
  );

  runApp(
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        calendarIntentServiceProvider.overrideWithValue(intentService),
        eventReminderServiceProvider.overrideWithValue(reminderService),
      ],
      child: const CalendarApp(),
    ),
  );
}

/// Root widget of the application.
///
/// Wraps [MaterialApp] in [DynamicColorBuilder] so platform-provided dynamic
/// colors are made available to [AppTheme.createTheme].
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
          customSeedColor: themeViewModel.customThemeColor,
        );
        final darkTheme = AppTheme.createTheme(
          brightness: Brightness.dark,
          themeType: themeViewModel.currentTheme,
          dynamicColorScheme: darkDynamic,
          customSeedColor: themeViewModel.customThemeColor,
        );

        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeViewModel.themeMode,
          locale: themeViewModel.locale,
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: CalendarView(
            intentService: ref.watch(calendarIntentServiceProvider),
            reminderService: ref.watch(eventReminderServiceProvider),
          ),
        );
      },
    );
  }
}
