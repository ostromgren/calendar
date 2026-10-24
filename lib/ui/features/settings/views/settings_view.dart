import 'package:flutter/material.dart';
import 'package:calendar/domain/models/app_language.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../core/theme_localization.dart';
import '../../calendar/view_models/calendar_view_model.dart';
import '../view_models/device_calendars_view_model.dart';
import '../view_models/theme_view_model.dart';
import 'device_calendars_view.dart';
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
    this.deviceCalendarsViewModel,
  });

  final ThemeViewModel themeViewModel;
  final CalendarViewModel? calendarViewModel;
  final DeviceCalendarsViewModel? deviceCalendarsViewModel;

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
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case ThemeMode.system:
        return l10n.systemMode;
      case ThemeMode.light:
        return l10n.lightMode;
      case ThemeMode.dark:
        return l10n.darkMode;
    }
  }

  String _languageLabel(AppLanguage language, AppLocalizations l10n) =>
      switch (language) {
        AppLanguage.system => l10n.systemLanguage,
        AppLanguage.english => l10n.englishLanguage,
        AppLanguage.swedish => l10n.swedishLanguage,
      };

  String _startingDayLabel(StartingDayOfWeek day, AppLocalizations l10n) =>
      switch (day) {
        StartingDayOfWeek.monday => l10n.monday,
        StartingDayOfWeek.sunday => l10n.sunday,
        StartingDayOfWeek.saturday => l10n.saturday,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final calendarVm = widget.calendarViewModel;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.themeViewModel, ?calendarVm]),
        builder: (context, _) {
          final currentTheme = widget.themeViewModel.currentTheme;
          final currentMode = widget.themeViewModel.themeMode;
          final activeFirstDay = calendarVm?.firstDayOfWeek ?? _firstDayOfWeek;
          final activeShowWeekNumbers =
              calendarVm?.showWeekNumbers ?? _showWeekNumbers;

          return ListView(
            children: [
              // 1. Appearance Section
              _buildSectionHeader(context, l10n.appearance),
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
                title: Text(
                  l10n.themes,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${currentTheme.localizedTitle(l10n)} • ${_formatThemeMode(currentMode)}',
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
              _buildSectionHeader(context, l10n.calendarPreferences),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.language,
                    color: colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(
                  l10n.language,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: DropdownButton<AppLanguage>(
                  value: widget.themeViewModel.appLanguage,
                  underline: const SizedBox.shrink(),
                  items: AppLanguage.values.map((language) {
                    return DropdownMenuItem(
                      value: language,
                      child: Text(_languageLabel(language, l10n)),
                    );
                  }).toList(),
                  onChanged: (language) {
                    if (language != null) {
                      widget.themeViewModel.setAppLanguage(language);
                    }
                  },
                ),
              ),
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
                title: Text(
                  l10n.firstDayOfWeek,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(_startingDayLabel(activeFirstDay, l10n)),
                trailing: DropdownButton<StartingDayOfWeek>(
                  value: activeFirstDay,
                  underline: const SizedBox.shrink(),
                  items: StartingDayOfWeek.values.map((day) {
                    return DropdownMenuItem(
                      value: day,
                      child: Text(_startingDayLabel(day, l10n)),
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
                title: Text(
                  l10n.showWeekNumbers,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.weekNumbersDescription),
                value: activeShowWeekNumbers,
                onChanged: (val) {
                  setState(() => _showWeekNumbers = val);
                  widget.calendarViewModel?.setShowWeekNumbers(val);
                },
              ),

              const Divider(height: 24),

              if (widget.deviceCalendarsViewModel != null) ...[
                _buildSectionHeader(context, l10n.accounts),
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_circle_outlined,
                      color: colorScheme.onSecondaryContainer,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    l10n.deviceCalendars,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    l10n.deviceCalendarsDescription,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DeviceCalendarsView(
                          viewModel: widget.deviceCalendarsViewModel!,
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 24),
              ],

              // 3. About Section
              _buildSectionHeader(context, l10n.about),
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
                title: Text(
                  l10n.appTitle,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(l10n.versionInfo),
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
