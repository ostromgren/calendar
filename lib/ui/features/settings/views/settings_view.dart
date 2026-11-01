import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calendar/domain/models/app_language.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../../providers.dart';
import '../../../core/theme_localization.dart';
import '../../calendar/view_models/calendar_view_model.dart';
import 'device_calendars_view.dart';
import 'local_calendars_view.dart';
import 'theme_selection_view.dart';

/// The application settings view.
class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  String _formatThemeMode(ThemeMode mode, AppLocalizations l10n) =>
      switch (mode) {
        ThemeMode.system => l10n.systemMode,
        ThemeMode.light => l10n.lightMode,
        ThemeMode.dark => l10n.darkMode,
      };

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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final themeViewModel = ref.watch(themeViewModelProvider);
    final calendarViewModel = ref.watch(calendarViewModelProvider);
    final deviceCalendarsViewModel = ref.watch(
      deviceCalendarsViewModelProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${themeViewModel.currentTheme.localizedTitle(l10n)} • '
              '${_formatThemeMode(themeViewModel.themeMode, l10n)}',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const ThemeSelectionView(),
              ),
            ),
          ),
          const Divider(height: 24),
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
              value: themeViewModel.appLanguage,
              underline: const SizedBox.shrink(),
              items: AppLanguage.values
                  .map(
                    (language) => DropdownMenuItem(
                      value: language,
                      child: Text(_languageLabel(language, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (language) {
                if (language != null) {
                  themeViewModel.setAppLanguage(language);
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _startingDayLabel(calendarViewModel.firstDayOfWeek, l10n),
            ),
            trailing: DropdownButton<StartingDayOfWeek>(
              value: calendarViewModel.firstDayOfWeek,
              underline: const SizedBox.shrink(),
              items: StartingDayOfWeek.values
                  .map(
                    (day) => DropdownMenuItem(
                      value: day,
                      child: Text(_startingDayLabel(day, l10n)),
                    ),
                  )
                  .toList(),
              onChanged: (day) {
                if (day != null) calendarViewModel.setFirstDayOfWeek(day);
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(l10n.weekNumbersDescription),
            value: calendarViewModel.showWeekNumbers,
            onChanged: calendarViewModel.setShowWeekNumbers,
          ),
          const Divider(height: 24),
          _buildSectionHeader(context, l10n.localCalendars),
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                color: colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            title: Text(
              l10n.localCalendars,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(l10n.localCalendarsDescription),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LocalCalendarsView(),
              ),
            ),
          ),
          const Divider(height: 24),
          if (deviceCalendarsViewModel.isSupported) ...[
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
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const DeviceCalendarsView(),
                ),
              ),
            ),
            const Divider(height: 24),
          ],
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
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(l10n.versionInfo),
          ),
        ],
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
