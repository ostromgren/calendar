import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

/// Month header with month/year title, previous/next controls, and a "Today" shortcut.
class MonthHeader extends StatelessWidget {
  const MonthHeader({
    super.key,
    required this.focusedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onToday,
  });

  final DateTime focusedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final monthLabel = DateFormat('MMMM yyyy', locale).format(focusedMonth);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              monthLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              TextButton(onPressed: onToday, child: Text(l10n.today)),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: l10n.previousMonth,
                onPressed: onPreviousMonth,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: l10n.nextMonth,
                onPressed: onNextMonth,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
