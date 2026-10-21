import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'data/repositories/calendar_repository.dart';
import 'ui/core/theme.dart';
import 'ui/features/calendar/view_models/calendar_view_model.dart';
import 'ui/features/calendar/views/calendar_view.dart';
import 'ui/features/settings/view_models/theme_view_model.dart';

/// Entry point of the Flutter application.
///
/// [WidgetsFlutterBinding.ensureInitialized] must be called before any
/// native or asynchronous initialization. [runApp] inflates the widget
/// tree and attaches it to the screen surface.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate dependencies manually here.
  // In larger apps, consider a dependency injection package such as get_it or riverpod.
  final calendarRepository = CalendarRepository();
  final calendarViewModel = CalendarViewModel(repository: calendarRepository);
  final themeViewModel = ThemeViewModel();

  runApp(CalendarApp(
    viewModel: calendarViewModel,
    themeViewModel: themeViewModel,
  ));
}

/// Root widget of the application.
///
/// Wraps [MaterialApp] in [DynamicColorBuilder] so Android 12+ wallpaper and
/// palette colors are made available to [AppTheme.createTheme].
class CalendarApp extends StatefulWidget {
  const CalendarApp({
    super.key,
    required this.viewModel,
    this.themeViewModel,
  });

  final CalendarViewModel viewModel;
  final ThemeViewModel? themeViewModel;

  @override
  State<CalendarApp> createState() => _CalendarAppState();
}

class _CalendarAppState extends State<CalendarApp> {
  ThemeViewModel? _fallbackThemeViewModel;

  ThemeViewModel get _effectiveThemeViewModel =>
      widget.themeViewModel ?? (_fallbackThemeViewModel ??= ThemeViewModel());

  @override
  void dispose() {
    _fallbackThemeViewModel?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeViewModel = _effectiveThemeViewModel;

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
              title: 'Calendar',
              debugShowCheckedModeBanner: false,
              theme: lightTheme,
              darkTheme: darkTheme,
              themeMode: themeViewModel.themeMode,
              home: CalendarView(
                viewModel: widget.viewModel,
                themeViewModel: themeViewModel,
              ),
            );
          },
        );
      },
    );
  }
}
