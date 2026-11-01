import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/main.dart';
import 'package:calendar/providers.dart';
import 'package:calendar/ui/features/calendar/view_models/calendar_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/device_calendars_view_model.dart';
import 'package:calendar/ui/features/settings/view_models/theme_view_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Widget createCalendarTestApp({
  required SettingsRepository settingsRepository,
  required CalendarViewModel calendarViewModel,
  required ThemeViewModel themeViewModel,
  DeviceCalendarsViewModel? deviceCalendarsViewModel,
}) {
  return ProviderScope(
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepository),
      calendarRepositoryProvider.overrideWithValue(
        calendarViewModel.repository,
      ),
      calendarViewModelProvider.overrideWith((ref) => calendarViewModel),
      themeViewModelProvider.overrideWith((ref) => themeViewModel),
      if (deviceCalendarsViewModel != null)
        deviceCalendarsViewModelProvider.overrideWith(
          (ref) => deviceCalendarsViewModel,
        ),
    ],
    child: const CalendarApp(),
  );
}
