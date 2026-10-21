import 'package:flutter/material.dart';
import '../view_models/theme_view_model.dart';
import 'theme_selection_view.dart';

/// The application settings view.
///
/// Houses app preferences such as [ThemeSelectionView] and is structured
/// to easily accommodate upcoming settings forward (e.g., calendar defaults,
/// reminders, first day of week).
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.themeViewModel,
  });

  final ThemeViewModel themeViewModel;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  bool _showWeekNumbers = false;
  String _firstDayOfWeek = 'Monday';

  String _formatThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Mode';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: widget.themeViewModel,
        builder: (context, _) {
          final currentTheme = widget.themeViewModel.currentTheme;
          final currentMode = widget.themeViewModel.themeMode;

          return ListView(
            children: [
              // 1. Appearance Section
              _buildSectionHeader(context, 'Appearance'),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.palette_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Themes',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${currentTheme.title} • ${_formatThemeMode(currentMode)}',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ThemeSelectionView(
                        themeViewModel: widget.themeViewModel,
                      ),
                    ),
                  );
                },
              ),

              const Divider(height: 24),

              // 2. Calendar Preferences Section (Extensible for future settings)
              _buildSectionHeader(context, 'Calendar Preferences'),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.calendar_view_week_outlined,
                    color: colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'First Day of Week',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_firstDayOfWeek),
                trailing: DropdownButton<String>(
                  value: _firstDayOfWeek,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'Monday', child: Text('Monday')),
                    DropdownMenuItem(value: 'Sunday', child: Text('Sunday')),
                    DropdownMenuItem(value: 'Saturday', child: Text('Saturday')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _firstDayOfWeek = val);
                    }
                  },
                ),
              ),
              SwitchListTile(
                secondary: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.format_list_numbered_rounded,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Show Week Numbers',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Display week indicators on calendar rows'),
                value: _showWeekNumbers,
                onChanged: (val) {
                  setState(() => _showWeekNumbers = val);
                },
              ),

              const Divider(height: 24),

              // 3. About Section
              _buildSectionHeader(context, 'About'),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.info_outline,
                    color: colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Calendar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Version 1.0.0 • Material 3 & Dynamic Color'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 4),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
