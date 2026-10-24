import 'package:calendar/l10n/generated/app_localizations.dart';

String calendarGreeting(AppLocalizations l10n, DateTime time) {
  return switch (time.hour) {
    >= 5 && < 12 => l10n.goodMorning,
    >= 12 && < 17 => l10n.haveGoodDay,
    >= 17 && < 22 => l10n.goodEvening,
    _ => l10n.hopeHadGoodDay,
  };
}
