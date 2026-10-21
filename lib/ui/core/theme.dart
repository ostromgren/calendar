import 'package:flutter/material.dart';

/// Available themes in the calendar application.
///
/// Includes 5 curated Material 3 themes plus 1 dynamic theme
/// for Android 12+ (which extracts the system color palette and wallpaper tones).
enum AppThemeType {
  /// The special Android theme that follows system wallpaper and palette settings.
  systemDynamic(
    title: 'System Palette (Material You)',
    subtitle: 'Follows Android wallpaper & system color palette',
    seedColor: Color(0xFF2563EB),
    isDynamic: true,
    icon: Icons.auto_awesome_rounded,
  ),

  /// Modern royal blue theme.
  oceanBlue(
    title: 'Ocean Blue',
    subtitle: 'Classic royal blue with crisp indigo tones',
    seedColor: Color(0xFF2563EB),
    isDynamic: false,
    icon: Icons.water_drop_outlined,
  ),

  /// Refreshing emerald green theme.
  emeraldForest(
    title: 'Emerald Forest',
    subtitle: 'Natural rich emerald and soothing sage',
    seedColor: Color(0xFF059669),
    isDynamic: false,
    icon: Icons.forest_outlined,
  ),

  /// Warm terracotta and amber theme.
  sunsetAmber(
    title: 'Sunset Amber',
    subtitle: 'Warm terracotta, golden amber, and dusk glow',
    seedColor: Color(0xFFD97706),
    isDynamic: false,
    icon: Icons.wb_sunny_outlined,
  ),

  /// Vibrant violet and lavender theme.
  deepPurple(
    title: 'Deep Purple',
    subtitle: 'Rich imperial violet with elegant lavender',
    seedColor: Color(0xFF7C3AED),
    isDynamic: false,
    icon: Icons.flare_outlined,
  ),

  /// Vibrant ruby and rose theme.
  roseCrimson(
    title: 'Rose Crimson',
    subtitle: 'Modern ruby red with soft crimson blush',
    seedColor: Color(0xFFE11D48),
    isDynamic: false,
    icon: Icons.favorite_border_rounded,
  );

  const AppThemeType({
    required this.title,
    required this.subtitle,
    required this.seedColor,
    required this.isDynamic,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final Color seedColor;
  final bool isDynamic;
  final IconData icon;
}

/// App theme configuration using modern Material 3.
///
/// Supports curated color seeds as well as dynamic platform color schemes
/// (Material You on Android 12+).
class AppTheme {
  /// Builds a [ThemeData] instance for the requested [themeType] and [brightness].
  ///
  /// If [themeType] is [AppThemeType.systemDynamic] and a non-null [dynamicColorScheme]
  /// is supplied (e.g. from `DynamicColorBuilder`), [dynamicColorScheme] is applied directly.
  /// Otherwise, a new scheme is generated via [ColorScheme.fromSeed] using the theme's [seedColor].
  static ThemeData createTheme({
    required Brightness brightness,
    required AppThemeType themeType,
    ColorScheme? dynamicColorScheme,
  }) {
    final ColorScheme colorScheme;
    if (themeType == AppThemeType.systemDynamic && dynamicColorScheme != null) {
      colorScheme = dynamicColorScheme;
    } else {
      colorScheme = ColorScheme.fromSeed(
        seedColor: themeType.seedColor,
        brightness: brightness,
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: brightness == Brightness.light
                ? Colors.grey.withAlpha(50)
                : Colors.white.withAlpha(30),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Default light theme (for backwards compatibility).
  static ThemeData get lightTheme => createTheme(
        brightness: Brightness.light,
        themeType: AppThemeType.oceanBlue,
      );

  /// Default dark theme (for backwards compatibility).
  static ThemeData get darkTheme => createTheme(
        brightness: Brightness.dark,
        themeType: AppThemeType.oceanBlue,
      );
}
