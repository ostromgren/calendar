import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar/domain/models/app_language.dart';
import 'package:calendar/domain/models/local_calendar.dart';
import 'package:calendar/domain/models/starting_day_of_week.dart';
import 'package:calendar/ui/core/theme.dart';

/// Keys used to store settings in [SharedPreferences].
abstract final class _Keys {
  static const String themeType = 'settings.theme_type';
  static const String themeMode = 'settings.theme_mode';
  static const String firstDayOfWeek = 'settings.first_day_of_week';
  static const String showWeekNumbers = 'settings.show_week_numbers';
  static const String lastUsedCalendarId = 'settings.last_used_calendar_id';
  static const String appLanguage = 'settings.app_language';
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
    return stored == null
        ? LocalCalendar.personal
        : LocalCalendar.fromId(stored);
  }

  /// Persists the calendar used for the most recently saved event.
  Future<void> saveLastUsedCalendar(LocalCalendar calendar) =>
      _prefs.setString(_Keys.lastUsedCalendarId, calendar.id);

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
}
