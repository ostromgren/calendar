import 'package:calendar/l10n/generated/app_localizations_en.dart';
import 'package:calendar/l10n/generated/app_localizations_sv.dart';
import 'package:calendar/ui/features/calendar/calendar_greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('calendarGreeting', () {
    final english = AppLocalizationsEn();
    final swedish = AppLocalizationsSv();

    test('selects English greetings based on local hour', () {
      expect(
        calendarGreeting(english, DateTime(2026, 1, 1, 4)),
        'Hope you had a good day!',
      );
      expect(
        calendarGreeting(english, DateTime(2026, 1, 1, 5)),
        'Good morning!',
      );
      expect(
        calendarGreeting(english, DateTime(2026, 1, 1, 12)),
        'Hope you have a good day!',
      );
      expect(
        calendarGreeting(english, DateTime(2026, 1, 1, 17)),
        'Good evening!',
      );
      expect(
        calendarGreeting(english, DateTime(2026, 1, 1, 22)),
        'Hope you had a good day!',
      );
    });

    test('selects Swedish greetings based on local hour', () {
      expect(calendarGreeting(swedish, DateTime(2026, 1, 1, 7)), 'God morgon!');
      expect(
        calendarGreeting(swedish, DateTime(2026, 1, 1, 13)),
        'Hoppas du får en fin dag!',
      );
      expect(calendarGreeting(swedish, DateTime(2026, 1, 1, 19)), 'God kväll!');
      expect(
        calendarGreeting(swedish, DateTime(2026, 1, 1, 23)),
        'Hoppas du har haft en fin dag!',
      );
    });
  });
}
