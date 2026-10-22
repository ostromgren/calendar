class CalendarFileReadException implements Exception {
  const CalendarFileReadException(this.message);

  final String message;
}

Future<String> readCalendarFile(String path) async {
  throw const CalendarFileReadException(
    'Calendar file reading is not supported on this platform.',
  );
}
