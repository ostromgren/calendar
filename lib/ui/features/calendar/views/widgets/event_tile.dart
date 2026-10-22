import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

/// Renders a single event card in the daily schedule view.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, required this.onDelete});

  final CalendarEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final timeFormat = DateFormat('HH:mm');
    final timeRange =
        '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: event.color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        title: Text(
          event.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              event.isAllDay ? l10n.wholeDay : timeRange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(event.description, style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          tooltip: l10n.deleteEvent,
          onPressed: onDelete,
        ),
      ),
    );
  }
}
