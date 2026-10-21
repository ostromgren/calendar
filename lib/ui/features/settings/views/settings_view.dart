import 'package:flutter/material.dart';
import '../../calendar/view_models/calendar_view_model.dart';
import '../view_models/theme_view_model.dart';
import 'theme_selection_view.dart';

/// The application settings view.
///
/// Houses app preferences such as [ThemeSelectionView], calendar starting day,
/// and week number visibility. Structured to easily accommodate upcoming
/// preferences forward.
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.themeViewModel,
    this.calendarViewModel,
  });

  final ThemeViewModel themeViewModel;
  final CalendarViewModel? calendarViewModel;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Local fallback state if calendarViewModel is not provided
  late bool _showWeekNumbers;
  late StartingDayOfWeek _firstDayOfWeek;

  @override
  void initState() {
    super.initState();
    _showWeekNumbers = widget.calendarViewModel?.showWeekNumbers ?? false;
    _firstDayOfWeek =
        widget.calendarViewModel?.firstDayOfWeek ?? StartingDayOfWeek.monday;
  }

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
    final calendarVm = widget.calendarViewModel;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          widget.themeViewModel,
          ?calendarVm,
        ]),
        builder: (context, _) {
          final currentTheme = widget.themeViewModel.currentTheme;
          final currentMode = widget.themeViewModel.themeMode;
          final activeFirstDay = calendarVm?.firstDayOfWeek ?? _firstDayOfWeek;
          final activeShowWeekNumbers =
              calendarVm?.showWeekNumbers ?? _showWeekNumbers;

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

              // 2. Calendar Preferences Section
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
                subtitle: Text(activeFirstDay.label),
                trailing: DropdownButton<StartingDayOfWeek>(
                  value: activeFirstDay,
                  underline: const SizedBox.shrink(),
                  items: StartingDayOfWeek.values.map((day) {
                    return DropdownMenuItem(
                      value: day,
                      child: Text(day.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _firstDayOfWeek = val);
                      widget.calendarViewModel?.setFirstDayOfWeek(val);
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
                value: activeShowWeekNumbers,
                onChanged: (val) {
                  setState(() => _showWeekNumbers = val);
                  widget.calendarViewModel?.setShowWeekNumbers(val);
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
