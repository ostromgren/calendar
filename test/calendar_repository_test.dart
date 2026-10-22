import 'package:flutter_test/flutter_test.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';

void main() {
  test('CalendarRepository starts without default events', () {
    final repository = CalendarRepository();

    expect(repository.getAllEvents(), isEmpty);
  });
}
