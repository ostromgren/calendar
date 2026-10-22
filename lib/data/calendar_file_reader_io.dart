import 'dart:io';

class CalendarFileReadException implements Exception {
  const CalendarFileReadException(this.message);

  final String message;
}

Future<String> readCalendarFile(String path) async {
  try {
    return await File(path).readAsString();
  } on FileSystemException catch (error) {
    throw CalendarFileReadException(error.message);
  }
}
