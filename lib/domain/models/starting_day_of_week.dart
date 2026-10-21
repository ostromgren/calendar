/// Represents the starting day of the week for the calendar grid.
enum StartingDayOfWeek {
  /// Week starts on Monday (ISO 8601 standard).
  monday(DateTime.monday, 'Monday', 'Mon'),

  /// Week starts on Sunday (standard in US, Canada, Japan, etc.).
  sunday(DateTime.sunday, 'Sunday', 'Sun'),

  /// Week starts on Saturday (standard in parts of the Middle East).
  saturday(DateTime.saturday, 'Saturday', 'Sat');

  const StartingDayOfWeek(
    this.dateTimeWeekday,
    this.label,
    this.shortLabel,
  );

  /// The integer weekday representation matching [DateTime.weekday] (1 for Monday, 7 for Sunday).
  final int dateTimeWeekday;

  /// Full user-facing display label.
  final String label;

  /// Short display label.
  final String shortLabel;
}
