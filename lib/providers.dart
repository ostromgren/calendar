import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'data/calendar_intent_service.dart';
import 'data/event_reminder_service.dart';
import 'data/repositories/calendar_repository.dart';
import 'data/repositories/device_calendar_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'ui/features/calendar/view_models/calendar_view_model.dart';
import 'ui/features/settings/view_models/device_calendars_view_model.dart';
import 'ui/features/settings/view_models/theme_view_model.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) =>
      throw StateError('SettingsRepository must be initialized at startup.'),
);

final calendarIntentServiceProvider = Provider<CalendarIntentService?>(
  (ref) => null,
);

final eventReminderServiceProvider = Provider<EventReminderService?>(
  (ref) => null,
);

final calendarRepositoryProvider = Provider<CalendarRepository>(
  (ref) => CalendarRepository(
    initialEvents: ref.watch(settingsRepositoryProvider).localEvents,
  ),
);

final deviceCalendarRepositoryProvider = Provider<DeviceCalendarRepository>(
  (ref) => NativeDeviceCalendarRepository(),
);

final calendarViewModelProvider = ChangeNotifierProvider<CalendarViewModel>(
  (ref) => CalendarViewModel(
    repository: ref.watch(calendarRepositoryProvider),
    settingsRepository: ref.watch(settingsRepositoryProvider),
    reminderService: ref.watch(eventReminderServiceProvider),
  ),
);

final themeViewModelProvider = ChangeNotifierProvider<ThemeViewModel>(
  (ref) =>
      ThemeViewModel(settingsRepository: ref.watch(settingsRepositoryProvider)),
);

final deviceCalendarsViewModelProvider =
    ChangeNotifierProvider<DeviceCalendarsViewModel>(
      (ref) => DeviceCalendarsViewModel(
        repository: ref.watch(deviceCalendarRepositoryProvider),
        settingsRepository: ref.watch(settingsRepositoryProvider),
      ),
    );
