import 'package:flutter/material.dart';
import 'data/repositories/calendar_repository.dart';
import 'ui/core/theme.dart';
import 'ui/features/calendar/view_models/calendar_view_model.dart';
import 'ui/features/calendar/views/calendar_view.dart';

/// Entry point of the Flutter application.
///
/// Android Comparison:
/// - In Android, the OS enters through `Application.onCreate()` and launches the default `Activity`.
/// - In Flutter, execution starts in Dart's top-level `void main()`.
/// - `runApp(...)` inflates the widget tree and attaches it to the screen surface.
void main() {
  // Ensure Flutter engine bindings are initialized before calling native or async code
  WidgetsFlutterBinding.ensureInitialized();

  // Instantiate dependencies (In larger apps, use get_it or Provider for dependency injection)
  final calendarRepository = CalendarRepository();
  final calendarViewModel = CalendarViewModel(repository: calendarRepository);

  runApp(CalendarApp(viewModel: calendarViewModel));
}

/// Root widget of the application.
///
/// Android Comparison:
/// - `StatelessWidget`: Similar to a pure Jetpack Compose `@Composable` function
///   without internal `remember { mutableStateOf(...) }`. It is immutable and re-renders
///   whenever its parent passes new inputs.
/// - `MaterialApp`: Sets up routing, localization, navigation, and theme
///   (analogous to the root Theme / NavHost setup in modern Android Compose).
class CalendarApp extends StatelessWidget {
  const CalendarApp({super.key, required this.viewModel});

  final CalendarViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Automatically adapts to system dark/light mode
      home: CalendarView(viewModel: viewModel),
    );
  }
}
