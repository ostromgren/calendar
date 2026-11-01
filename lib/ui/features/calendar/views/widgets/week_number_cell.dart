import 'package:material_ui/material_ui.dart';

/// Renders a subtle indicator cell displaying the ISO 8601 week number
/// for a row in the monthly calendar grid.
class WeekNumberCell extends StatelessWidget {
  const WeekNumberCell({
    super.key,
    required this.weekNumber,
    required this.tooltipBuilder,
  });

  final int weekNumber;
  final String Function(int week) tooltipBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Tooltip(
        message: tooltipBuilder(weekNumber),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(90),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colorScheme.outlineVariant.withAlpha(80),
              width: 0.8,
            ),
          ),
          child: Text(
            '$weekNumber',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.outline,
              fontSize: 10,
            ),
          ),
        ),
      ),
    );
  }
}
