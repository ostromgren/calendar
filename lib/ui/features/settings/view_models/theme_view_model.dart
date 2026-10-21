import 'package:flutter/material.dart';
import '../../../core/theme.dart';

/// ViewModel managing active theme and brightness preferences.
///
/// Holds the selected [AppThemeType] and [ThemeMode], notifying listeners
/// whenever the user modifies their theme settings.
class ThemeViewModel extends ChangeNotifier {
  ThemeViewModel({
    AppThemeType initialTheme = AppThemeType.systemDynamic,
    ThemeMode initialThemeMode = ThemeMode.system,
  })  : _currentTheme = initialTheme,
        _themeMode = initialThemeMode;

  AppThemeType _currentTheme;
  ThemeMode _themeMode;

  /// The currently selected app theme.
  AppThemeType get currentTheme => _currentTheme;

  /// The active theme mode (system, light, or dark).
  ThemeMode get themeMode => _themeMode;

  /// Updates the active theme and notifies all observing widgets.
  void setTheme(AppThemeType theme) {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
    }
  }

  /// Updates the theme brightness mode and notifies all observing widgets.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }
}
