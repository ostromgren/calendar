import 'package:flutter/material.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/domain/models/event_category.dart';
import 'package:calendar/domain/models/local_calendar.dart';
import 'package:calendar/domain/models/starting_day_of_week.dart';

export 'package:calendar/domain/models/starting_day_of_week.dart';

/// ViewModel for the calendar screen.
///
/// Holds the currently selected date, the focused month shown in the grid,
/// user display preferences (first day of week, week number visibility),
/// and delegates all event persistence to [CalendarRepository].
/// Display-preference changes are automatically persisted via [SettingsRepository].
///
/// Riverpod exposes changes from this notifier to its consumers.
class CalendarViewModel extends ChangeNotifier {
  CalendarViewModel({
    required this.repository,
    required SettingsRepository settingsRepository,
    StartingDayOfWeek? initialFirstDayOfWeek,
    bool? initialShowWeekNumbers,
  }) : _settings = settingsRepository,
       _firstDayOfWeek =
           initialFirstDayOfWeek ?? settingsRepository.firstDayOfWeek,
       _showWeekNumbers =
           initialShowWeekNumbers ?? settingsRepository.showWeekNumbers,
       _localCalendars = settingsRepository.localCalendars,
       _eventCategories = settingsRepository.getEventCategories(),
       _lastUsedCalendar = settingsRepository.lastUsedCalendar {
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _focusedMonth = DateTime(now.year, now.month, 1);
  }

  final CalendarRepository repository;
  final SettingsRepository _settings;

  late DateTime _selectedDate;
  late DateTime _focusedMonth;
  StartingDayOfWeek _firstDayOfWeek;
  bool _showWeekNumbers;
  List<LocalCalendar> _localCalendars;
  List<EventCategory> _eventCategories;
  LocalCalendar _lastUsedCalendar;

  DateTime get selectedDate => _selectedDate;
  DateTime get focusedMonth => _focusedMonth;

  /// Starting day of the week in the monthly grid.
  StartingDayOfWeek get firstDayOfWeek => _firstDayOfWeek;

  /// Whether row-level week indicators (1-53) are displayed.
  bool get showWeekNumbers => _showWeekNumbers;

  /// Calendar selected by default when adding the next event.
  LocalCalendar get lastUsedCalendar => _lastUsedCalendar;
  List<LocalCalendar> get localCalendars => List.unmodifiable(_localCalendars);

  List<EventCategory> categoriesFor(String calendarId) => List.unmodifiable(
    _eventCategories.where((category) => category.calendarId == calendarId),
  );

  Future<void> addLocalCalendar(String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Calendar name cannot be empty.');
    }
    final calendar = LocalCalendar(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      name: normalizedName,
    );
    final calendars = [..._localCalendars, calendar];
    await _settings.saveLocalCalendars(calendars);
    _localCalendars = calendars;
    notifyListeners();
  }

  Future<void> renameLocalCalendar(String id, String name) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Calendar name cannot be empty.');
    }
    final calendars = _localCalendars
        .map(
          (calendar) => calendar.id == id
              ? LocalCalendar(id: calendar.id, name: normalizedName)
              : calendar,
        )
        .toList(growable: false);
    await _settings.saveLocalCalendars(calendars);
    _localCalendars = calendars;
    if (_lastUsedCalendar.id == id) {
      _lastUsedCalendar = calendars.firstWhere((calendar) => calendar.id == id);
    }
    notifyListeners();
  }

  Future<void> addEventCategory({
    required String calendarId,
    required String name,
    required Color color,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Category name cannot be empty.');
    }
    final category = EventCategory(
      id: 'category-${DateTime.now().microsecondsSinceEpoch}',
      calendarId: calendarId,
      name: normalizedName,
      color: color,
    );
    final categories = [..._eventCategories, category];
    await _settings.saveEventCategories(categories);
    _eventCategories = categories;
    notifyListeners();
  }

  /// Destination selected by default when adding the next event.
  String get lastUsedCalendarDestination =>
      _settings.lastUsedCalendarDestination;

  /// Remembers a device calendar as the destination for the next event.
  Future<void> rememberDeviceCalendar(String calendarId) =>
      _settings.saveLastUsedCalendarDestination('device:$calendarId');

  /// Updates the starting day of the week and notifies observing widgets.
  void setFirstDayOfWeek(StartingDayOfWeek day) {
    if (_firstDayOfWeek != day) {
      _firstDayOfWeek = day;
      _settings.saveFirstDayOfWeek(day);
      notifyListeners();
    }
  }

  /// Toggles visibility of row week numbers and notifies observing widgets.
  void setShowWeekNumbers(bool show) {
    if (_showWeekNumbers != show) {
      _showWeekNumbers = show;
      _settings.saveShowWeekNumbers(show);
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
    required LocalCalendar calendar,
    String? categoryId,
    Color? categoryColor,
    bool isAllDay = false,
  }) {
    final newEvent = CalendarEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      calendarId: calendar.id,
      categoryId: categoryId,
      startTime: startTime,
      endTime: endTime,
      isAllDay: isAllDay,
      color: categoryColor ?? Colors.blue,
    );
    repository.addEvent(newEvent);
    _lastUsedCalendar = calendar;
    _settings.saveLastUsedCalendar(calendar);
    notifyListeners();
  }

  void deleteEvent(String id) {
    repository.deleteEvent(id);
    notifyListeners();
  }
}
