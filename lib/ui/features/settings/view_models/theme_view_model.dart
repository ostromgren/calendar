import 'package:flutter/material.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
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
  })  : _settings = settingsRepository,
        _currentTheme = initialTheme ?? settingsRepository.themeType,
        _themeMode = initialThemeMode ?? settingsRepository.themeMode;

  final SettingsRepository _settings;
  AppThemeType _currentTheme;
  ThemeMode _themeMode;

  /// The currently selected app theme.
  AppThemeType get currentTheme => _currentTheme;

  /// The active theme mode (system, light, or dark).
  ThemeMode get themeMode => _themeMode;

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
}
