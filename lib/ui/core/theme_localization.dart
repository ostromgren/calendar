import 'package:calendar/l10n/generated/app_localizations.dart';

import 'theme.dart';

extension AppThemeTypeLocalization on AppThemeType {
  String localizedTitle(AppLocalizations l10n) => switch (this) {
    AppThemeType.systemDynamic => l10n.systemPaletteTheme,
    AppThemeType.oceanBlue => l10n.oceanBlueTheme,
    AppThemeType.emeraldForest => l10n.emeraldForestTheme,
    AppThemeType.sunsetAmber => l10n.sunsetAmberTheme,
    AppThemeType.deepPurple => l10n.deepPurpleTheme,
    AppThemeType.roseCrimson => l10n.roseCrimsonTheme,
  };

  String localizedSubtitle(AppLocalizations l10n) => switch (this) {
    AppThemeType.systemDynamic => l10n.systemPaletteDescription,
    AppThemeType.oceanBlue => l10n.oceanBlueDescription,
    AppThemeType.emeraldForest => l10n.emeraldForestDescription,
    AppThemeType.sunsetAmber => l10n.sunsetAmberDescription,
    AppThemeType.deepPurple => l10n.deepPurpleDescription,
    AppThemeType.roseCrimson => l10n.roseCrimsonDescription,
  };
}
