import 'package:flutter/material.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/app_language.dart';

import '../../../core/theme.dart';

/// ViewModel managing active theme and brightness preferences.
///
/// Holds the selected [AppThemeType] and [ThemeMode], notifying listeners
/// whenever the user modifies their theme settings. Changes are automatically
/// persisted via [SettingsRepository] so they survive app restarts.
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({
    required SettingsRepository settingsRepository,
    AppThemeType? initialTheme,
    ThemeMode? initialThemeMode,
  }) : _settings = settingsRepository,
       _currentTheme = initialTheme ?? settingsRepository.themeType,
       _themeMode = initialThemeMode ?? settingsRepository.themeMode,
       _appLanguage = settingsRepository.appLanguage;

  final SettingsRepository _settings;
  AppThemeType _currentTheme;
  ThemeMode _themeMode;
  AppLanguage _appLanguage;

  /// The currently selected app theme.
  AppThemeType get currentTheme => _currentTheme;

  /// The active theme mode (system, light, or dark).
  ThemeMode get themeMode => _themeMode;

  /// The selected interface language.
  AppLanguage get appLanguage => _appLanguage;

  /// The locale passed to [MaterialApp], or null to follow the system locale.
  Locale? get locale => _appLanguage.locale;

  /// Updates the active theme, persists the choice, and notifies all observing widgets.
  void setTheme(AppThemeType theme) {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      _settings.saveThemeType(theme);
      notifyListeners();
    }
  }

  /// Updates the theme brightness mode, persists the choice, and notifies all observing widgets.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _settings.saveThemeMode(mode);
      notifyListeners();
    }
  }

  /// Updates and persists the interface language preference.
  void setAppLanguage(AppLanguage language) {
    if (_appLanguage != language) {
      _appLanguage = language;
      _settings.saveAppLanguage(language);
      notifyListeners();
    }
  }
}
