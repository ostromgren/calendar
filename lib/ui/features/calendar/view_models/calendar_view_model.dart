import 'package:flutter/foundation.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';

/// ViewModel managing state for the calendar view.
///
/// Android Comparison:
/// - In Android with Jetpack Compose, you write `class CalendarViewModel : ViewModel()`.
/// - In Flutter, `ChangeNotifier` is the built-in foundation for state notification.
/// - In Android, you update `MutableStateFlow.value = ...`.
/// - In Flutter, you update local fields and call `notifyListeners()`, which informs
///   any listening `ListenableBuilder` or UI component to re-render.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({required this.repository}) {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  final CalendarRepository repository;

  late DateTime _selectedDate;
  late DateTime _focusedMonth;

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedMonth => _focusedMonth;

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
