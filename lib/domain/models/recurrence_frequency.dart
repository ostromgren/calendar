enum RecurrenceFrequency {
  weekly,
  everyTwoWeeks,
  everyThreeWeeks,
  monthly;

  int get weekInterval => switch (this) {
    RecurrenceFrequency.weekly => 1,
    RecurrenceFrequency.everyTwoWeeks => 2,
    RecurrenceFrequency.everyThreeWeeks => 3,
    RecurrenceFrequency.monthly => 0,
  };
}
