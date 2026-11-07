import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

/// Renders a single event card in the daily schedule view.
class EventTile extends StatefulWidget {
  const EventTile({
    super.key,
    required this.event,
    required this.onDelete,
    required this.onEdit,
  });

  final CalendarEvent event;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  @override
  State<EventTile> createState() => _EventTileState();
}

class _EventTileState extends State<EventTile> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final event = widget.event;
    final timeFormat = DateFormat('HH:mm');
    final timeRange =
        '${timeFormat.format(event.startTime)} - ${timeFormat.format(event.endTime)}';

    return Card(
      key: const ValueKey('event-tile-card'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                key: const ValueKey('event-color-marker'),
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: event.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AnimatedSize(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.topLeft,
                            child: Text(
                              event.description,
                              key: ValueKey(_isDescriptionExpanded),
                              maxLines: _isDescriptionExpanded ? null : 2,
                              overflow: _isDescriptionExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 32,
                            height: 32,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 20,
                          tooltip: _isDescriptionExpanded
                              ? l10n.collapseDescription
                              : l10n.expandDescription,
                          icon: Icon(
                            _isDescriptionExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                          ),
                          onPressed: () => setState(
                            () => _isDescriptionExpanded =
                                !_isDescriptionExpanded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (!event.readOnly)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('event-edit-button'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: l10n.editEvent,
                    onPressed: widget.onEdit,
                  ),
                  IconButton(
                    key: const ValueKey('event-delete-button'),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    tooltip: l10n.deleteEvent,
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
