import 'package:flutter/material.dart';
import '../../../core/theme.dart';
import '../view_models/theme_view_model.dart';

/// Screen allowing the user to select their calendar theme and brightness mode.
///
/// Features 5 curated themes plus Android 12+ dynamic system palette support.
class ThemeSelectionView extends StatelessWidget {
  const ThemeSelectionView({
    super.key,
    required this.themeViewModel,
  });

  final ThemeViewModel themeViewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeViewModel,
      builder: (context, _) {
        final currentTheme = themeViewModel.currentTheme;
        final currentMode = themeViewModel.themeMode;
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Themes'),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              // 1. Live Calendar Preview Card
              Card(
                color: colorScheme.surfaceContainerHighest.withAlpha(120),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 18,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Live Preview',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Mini calendar banner
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'October 2026',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.chevron_left,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Mini row of days
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _previewDayCell(
                                  label: '19',
                                  isSelected: false,
                                  isToday: false,
                                  colorScheme: colorScheme,
                                  theme: theme,
                                ),
                                _previewDayCell(
                                  label: '20',
                                  isSelected: false,
                                  isToday: true,
                                  colorScheme: colorScheme,
                                  theme: theme,
                                ),
                                _previewDayCell(
                                  label: '21',
                                  isSelected: true,
                                  isToday: false,
                                  colorScheme: colorScheme,
                                  theme: theme,
                                ),
                                _previewDayCell(
                                  label: '22',
                                  isSelected: false,
                                  isToday: false,
                                  colorScheme: colorScheme,
                                  theme: theme,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Mini event chip
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '10:00 - Team Kickoff Sync',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 2. Brightness Mode Section
              Text(
                'Brightness',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto),
                    label: Text('System'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode),
                    label: Text('Light'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode),
                    label: Text('Dark'),
                  ),
                ],
                selected: {currentMode},
                onSelectionChanged: (newSelection) {
                  themeViewModel.setThemeMode(newSelection.first);
                },
              ),

              const SizedBox(height: 24),

              // 3 & 4: Color Themes wrapped in modern RadioGroup
              RadioGroup<AppThemeType>(
                groupValue: currentTheme,
                onChanged: (newTheme) {
                  if (newTheme != null) {
                    themeViewModel.setTheme(newTheme);
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic System Theme Header
                    Text(
                      'Dynamic System Theme',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Special theme for Android (and supported systems) matching your wallpaper and chosen Color Palette.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DynamicThemeCard(
                      themeType: AppThemeType.systemDynamic,
                      isSelected: currentTheme == AppThemeType.systemDynamic,
                      onSelect: () =>
                          themeViewModel.setTheme(AppThemeType.systemDynamic),
                    ),

                    const SizedBox(height: 24),

                    // Curated App Themes Header
                    Text(
                      'Curated Color Themes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...AppThemeType.values
                        .where((t) => !t.isDynamic)
                        .map((themeOption) {
                      return _CuratedThemeTile(
                        themeType: themeOption,
                        isSelected: currentTheme == themeOption,
                        onSelect: () => themeViewModel.setTheme(themeOption),
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _previewDayCell({
    required String label,
    required bool isSelected,
    required bool isToday,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    Color? bg;
    Color fg = colorScheme.onSurface;

    if (isSelected) {
      bg = colorScheme.primary;
      fg = colorScheme.onPrimary;
    } else if (isToday) {
      bg = colorScheme.primaryContainer;
      fg = colorScheme.onPrimaryContainer;
    }

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: isToday && !isSelected
            ? Border.all(color: colorScheme.primary, width: 1.5)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: fg,
          fontWeight:
              isSelected || isToday ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Special card for the Android 12+ Dynamic Color / Material You theme.
class _DynamicThemeCard extends StatelessWidget {
  const _DynamicThemeCard({
    required this.themeType,
    required this.isSelected,
    required this.onSelect,
  });

  final AppThemeType themeType;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.tertiary,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.onPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              themeType.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Android Material You',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          themeType.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Radio<AppThemeType>(
                    value: themeType,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(100),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'On Android 12+, colors dynamically match your wallpaper palette choice. On other platforms, uses modern default tones.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// List tile representing one of the 5 curated color themes.
class _CuratedThemeTile extends StatelessWidget {
  const _CuratedThemeTile({
    required this.themeType,
    required this.isSelected,
    required this.onSelect,
  });

  final AppThemeType themeType;
  final bool isSelected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: isSelected ? 1 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 1.8 : 1,
        ),
      ),
      child: ListTile(
        onTap: onSelect,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: themeType.seedColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(80),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: themeType.seedColor.withAlpha(80),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            themeType.icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          themeType.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          themeType.subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Radio<AppThemeType>(
          value: themeType,
        ),
      ),
    );
  }
}
