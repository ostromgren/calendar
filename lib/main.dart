import 'package:flutter/material.dart';
import 'data/repositories/calendar_repository.dart';
import 'ui/core/theme.dart';
import 'ui/features/calendar/view_models/calendar_view_model.dart';
import 'ui/features/calendar/views/calendar_view.dart';

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

  runApp(CalendarApp(viewModel: calendarViewModel));
}

/// Root widget of the application.
///
/// [CalendarApp] is a [StatelessWidget] because it holds no mutable state of
/// its own — it simply configures [MaterialApp] with the app's theme and
/// navigation root, passing the pre-built [viewModel] down the tree.
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
      themeMode: ThemeMode.system, // Follows the device's light/dark preference.
      home: CalendarView(viewModel: viewModel),
    );
  }
}
