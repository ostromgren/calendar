import 'package:flutter/foundation.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/domain/models/starting_day_of_week.dart';

export 'package:calendar/domain/models/starting_day_of_week.dart';

/// ViewModel for the calendar screen.
///
/// Holds the currently selected date, the focused month shown in the grid,
/// user display preferences (first day of week, week number visibility),
/// and delegates all event persistence to [CalendarRepository].
///
/// Call [notifyListeners] after any mutation so that [ListenableBuilder]
/// widgets rebuild automatically with the latest state.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({
    required this.repository,
    StartingDayOfWeek initialFirstDayOfWeek = StartingDayOfWeek.monday,
    bool initialShowWeekNumbers = false,
  })  : _firstDayOfWeek = initialFirstDayOfWeek,
        _showWeekNumbers = initialShowWeekNumbers {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  final CalendarRepository repository;

  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  StartingDayOfWeek _firstDayOfWeek;
  bool _showWeekNumbers;

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedMonth => _focusedMonth;

  /// Starting day of the week in the monthly grid.
  StartingDayOfWeek get firstDayOfWeek => _firstDayOfWeek;

  /// Whether row-level week indicators (1-53) are displayed.
  bool get showWeekNumbers => _showWeekNumbers;

  /// Updates the starting day of the week and notifies observing widgets.
  void setFirstDayOfWeek(StartingDayOfWeek day) {
    if (_firstDayOfWeek != day) {
      _firstDayOfWeek = day;
      notifyListeners();
    }
  }

  /// Toggles visibility of row week numbers and notifies observing widgets.
  void setShowWeekNumbers(bool show) {
    if (_showWeekNumbers != show) {
      _showWeekNumbers = show;
      notifyListeners();
    }
  }

  /// Returns events scheduled on the currently selected date.
  List<CalendarEvent> get selectedDateEvents =>
      repository.getEventsForDay(_selectedDate);

  /// Checks if any events exist on the specified [date] (used to display dot indicators).
  bool hasEventsOn(DateTime date) {
    return repository.getEventsForDay(date).isNotEmpty;
  }

  void selectDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    // If the selected date is in a different month, adjust the focused month view
    if (_focusedMonth.year != date.year || _focusedMonth.month != date.month) {
      _focusedMonth = DateTime(date.year, date.month, 1);
    }
    notifyListeners();
  }

  void goToToday() {
    final now = DateTime.now();
    selectDate(DateTime(now.year, now.month, now.day));
  }

  void previousMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    notifyListeners();
  }

  void nextMonth() {
    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    notifyListeners();
  }

  void addEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) {
    final newEvent = CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      startTime: startTime,
      endTime: endTime,
    );
    repository.addEvent(newEvent);
    notifyListeners();
  }

  void deleteEvent(String id) {
    repository.deleteEvent(id);
    notifyListeners();
  }
}
