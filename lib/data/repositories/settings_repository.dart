import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar/domain/models/app_language.dart';
import 'package:calendar/domain/models/local_calendar.dart';
import 'package:calendar/domain/models/event_category.dart';
import 'package:calendar/domain/models/starting_day_of_week.dart';
import 'package:calendar/ui/core/theme.dart';

/// Keys used to store settings in [SharedPreferences].
abstract final class _Keys {
  static const String themeType = 'settings.theme_type';
  static const String themeMode = 'settings.theme_mode';
  static const String firstDayOfWeek = 'settings.first_day_of_week';
  static const String showWeekNumbers = 'settings.show_week_numbers';
  static const String lastUsedCalendarId = 'settings.last_used_calendar_id';
  static const String lastUsedCalendarDestination =
      'settings.last_used_calendar_destination';
  static const String appLanguage = 'settings.app_language';
  static const String deviceCalendarIds = 'settings.device_calendar_ids';
  static const String localCalendars = 'settings.local_calendars';
  static const String eventCategories = 'settings.event_categories';
}

/// Persists and retrieves user settings using [SharedPreferences].
///
/// All read methods return a sensible default when no stored value exists.
/// Call [load] once at startup (before the first [runApp]) to obtain an
/// initialised instance that can be injected into the view models.
class SettingsRepository {
  SettingsRepository._(this._prefs);

  final SharedPreferences _prefs;

  /// Creates a [SettingsRepository] by opening (or reusing) the underlying
  /// [SharedPreferences] store.  Must be awaited before [runApp].
  static Future<SettingsRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsRepository._(prefs);
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  /// Returns the last-saved [AppThemeType], defaulting to [AppThemeType.systemDynamic].
  AppThemeType get themeType {
    final stored = _prefs.getString(_Keys.themeType);
    if (stored == null) return AppThemeType.systemDynamic;
    return AppThemeType.values.firstWhere(
      (t) => t.name == stored,
      orElse: () => AppThemeType.systemDynamic,
    );
  }

  /// Persists [value] as the active theme type.
  Future<void> saveThemeType(AppThemeType value) =>
      _prefs.setString(_Keys.themeType, value.name);

  // ---------------------------------------------------------------------------
  // Theme mode
  // ---------------------------------------------------------------------------

  /// Returns the last-saved [ThemeMode], defaulting to [ThemeMode.system].
  ThemeMode get themeMode {
    final stored = _prefs.getString(_Keys.themeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  /// Persists [value] as the active theme mode.
  Future<void> saveThemeMode(ThemeMode value) {
    final label = switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    return _prefs.setString(_Keys.themeMode, label);
  }

  // ---------------------------------------------------------------------------
  // First day of week
  // ---------------------------------------------------------------------------

  /// Returns the last-saved [StartingDayOfWeek], defaulting to [StartingDayOfWeek.monday].
  StartingDayOfWeek get firstDayOfWeek {
    final stored = _prefs.getString(_Keys.firstDayOfWeek);
    if (stored == null) return StartingDayOfWeek.monday;
    return StartingDayOfWeek.values.firstWhere(
      (d) => d.name == stored,
      orElse: () => StartingDayOfWeek.monday,
    );
  }

  /// Persists [value] as the starting day of the week.
  Future<void> saveFirstDayOfWeek(StartingDayOfWeek value) =>
      _prefs.setString(_Keys.firstDayOfWeek, value.name);

  // ---------------------------------------------------------------------------
  // Show week numbers
  // ---------------------------------------------------------------------------

  /// Returns the last-saved week-number visibility flag, defaulting to `false`.
  bool get showWeekNumbers => _prefs.getBool(_Keys.showWeekNumbers) ?? false;

  /// Persists [value] as the week-number visibility preference.
  Future<void> saveShowWeekNumbers(bool value) =>
      _prefs.setBool(_Keys.showWeekNumbers, value);

  // ---------------------------------------------------------------------------
  // Last-used calendar
  // ---------------------------------------------------------------------------

  /// Returns the last-used local calendar, defaulting to Personal.
  LocalCalendar get lastUsedCalendar {
    final stored = _prefs.getString(_Keys.lastUsedCalendarId);
    return localCalendars.firstWhere(
      (calendar) => calendar.id == stored,
      orElse: () => localCalendars.first,
    );
  }

  /// Locally managed calendars, including the original Personal calendar.
  List<LocalCalendar> get localCalendars {
    final stored = _prefs.getString(_Keys.localCalendars);
    if (stored == null) return [LocalCalendar.personal];
    try {
      final values = jsonDecode(stored) as List<dynamic>;
      final calendars = values
          .map((value) => LocalCalendar.fromJson(value as Map<String, dynamic>))
          .toList(growable: false);
      if (calendars.isNotEmpty &&
          calendars.any((calendar) => calendar.id == 'personal')) {
        return calendars;
      }
    } on FormatException catch (error) {
      debugPrint('Could not decode local calendars: $error');
    } on TypeError catch (error) {
      debugPrint('Invalid local calendar data: $error');
    }
    return [LocalCalendar.personal];
  }

  /// Persists user-managed local calendars.
  Future<void> saveLocalCalendars(Iterable<LocalCalendar> calendars) async {
    if (!await _prefs.setString(
      _Keys.localCalendars,
      jsonEncode(calendars.map((calendar) => calendar.toJson()).toList()),
    )) {
      throw StateError('Could not save local calendars.');
    }
  }

  /// User-created categories, optionally limited to one local calendar.
  List<EventCategory> getEventCategories({String? calendarId}) {
    final stored = _prefs.getString(_Keys.eventCategories);
    if (stored == null) return const [];
    try {
      final values = jsonDecode(stored) as List<dynamic>;
      final categories = values
          .map((value) => EventCategory.fromJson(value as Map<String, dynamic>))
          .toList(growable: false);
      return calendarId == null
          ? categories
          : categories
                .where((category) => category.calendarId == calendarId)
                .toList(growable: false);
    } on FormatException catch (error) {
      debugPrint('Could not decode event categories: $error');
    } on TypeError catch (error) {
      debugPrint('Invalid event category data: $error');
    }
    return const [];
  }

  /// Persists user-created event categories.
  Future<void> saveEventCategories(Iterable<EventCategory> categories) async {
    if (!await _prefs.setString(
      _Keys.eventCategories,
      jsonEncode(categories.map((category) => category.toJson()).toList()),
    )) {
      throw StateError('Could not save event categories.');
    }
  }

  /// The last event destination, or the legacy local-calendar preference.
  String get lastUsedCalendarDestination =>
      _prefs.getString(_Keys.lastUsedCalendarDestination) ??
      'local:${lastUsedCalendar.id}';

  /// Persists the destination used for the most recently saved event.
  Future<void> saveLastUsedCalendarDestination(String destination) =>
      _prefs.setString(_Keys.lastUsedCalendarDestination, destination);

  /// Persists the local calendar used for the most recently saved event.
  Future<void> saveLastUsedCalendar(LocalCalendar calendar) async {
    await _prefs.setString(_Keys.lastUsedCalendarId, calendar.id);
    await saveLastUsedCalendarDestination('local:${calendar.id}');
  }

  // ---------------------------------------------------------------------------
  // App language
  // ---------------------------------------------------------------------------

  /// Returns the selected interface language, defaulting to the system language.
  AppLanguage get appLanguage {
    final stored = _prefs.getString(_Keys.appLanguage);
    return AppLanguage.values.firstWhere(
      (language) => language.name == stored,
      orElse: () => AppLanguage.system,
    );
  }

  /// Persists the selected interface language.
  Future<void> saveAppLanguage(AppLanguage language) =>
      _prefs.setString(_Keys.appLanguage, language.name);

  // ---------------------------------------------------------------------------
  // Device calendars
  // ---------------------------------------------------------------------------

  /// Calendar IDs selected for display, or null before the user has selected.
  List<String>? get deviceCalendarIds =>
      _prefs.getStringList(_Keys.deviceCalendarIds);

  /// Persists the device calendars whose events should appear in the app.
  Future<void> saveDeviceCalendarIds(Iterable<String> calendarIds) =>
      _prefs.setStringList(_Keys.deviceCalendarIds, calendarIds.toList());
}
