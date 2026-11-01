import 'package:material_ui/material_ui.dart';

/// Renders a single day cell inside the calendar grid.
class DayCell extends StatelessWidget {
  const DayCell({
    super.key,
    required this.date,
    required this.isSelected,
    required this.isToday,
    required this.isCurrentMonth,
    required this.hasEvents,
    this.eventColors = const [],
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool isToday;
  final bool isCurrentMonth;
  final bool hasEvents;
  final List<Color> eventColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Color? backgroundColor;
    Color textColor = isCurrentMonth
        ? colorScheme.onSurface
        : colorScheme.onSurface.withAlpha(80);

    if (isSelected) {
      backgroundColor = colorScheme.primary;
      textColor = colorScheme.onPrimary;
    } else if (isToday) {
      backgroundColor = colorScheme.primaryContainer;
      textColor = colorScheme.onPrimaryContainer;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: colorScheme.primary, width: 1.5)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: isSelected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            // Event indicator dot
            if (hasEvents)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final color in eventColors.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? colorScheme.onPrimary : color,
                      ),
                    ),
                  if (eventColors.isEmpty)
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.primary,
                      ),
                    ),
                ],
              )
            else
              const SizedBox(height: 5),
          ],
        ),
      ),
    );
  }
}
