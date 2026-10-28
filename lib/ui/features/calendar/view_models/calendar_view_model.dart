import 'package:flutter/material.dart';
import 'package:calendar/data/repositories/calendar_repository.dart';
import 'package:calendar/data/repositories/settings_repository.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/domain/models/event_category.dart';
import 'package:calendar/domain/models/local_calendar.dart';
import 'package:calendar/domain/models/recurrence_frequency.dart';
import 'package:calendar/domain/models/starting_day_of_week.dart';
import 'package:calendar/data/calendar_ics_service.dart';

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

  Future<void> importLocalCalendar({
    required String name,
    required ImportedCalendar imported,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Calendar name cannot be empty.');
    }
    final calendarId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final calendar = LocalCalendar(id: calendarId, name: normalizedName);
    final importedCategories = imported.categories
        .map(
          (category) => EventCategory(
            id: '$calendarId-${category.id}',
            calendarId: calendarId,
            name: category.name,
            color: category.color,
          ),
        )
        .toList(growable: false);
    final categoryIds = {
      for (var index = 0; index < imported.categories.length; index++)
        imported.categories[index].id: importedCategories[index].id,
    };
    final events = imported.events
        .map(
          (event) => event.copyWith(
            id: '$calendarId-${event.id}',
            calendarId: calendarId,
            categoryId: event.categoryId == null
                ? null
                : categoryIds[event.categoryId],
          ),
        )
        .toList(growable: false);
    final calendars = [..._localCalendars, calendar];
    final categories = [..._eventCategories, ...importedCategories];
    final allEvents = [...repository.getAllEvents(), ...events];

    await _settings.saveLocalCalendars(calendars);
    await _settings.saveEventCategories(categories);
    await _settings.saveLocalEvents(allEvents);
    for (final event in events) {
      repository.addEvent(event);
    }
    _localCalendars = calendars;
    _eventCategories = categories;
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

  Future<void> deleteLocalCalendar(String id) async {
    if (_localCalendars.length <= 1) {
      throw StateError('At least one local calendar must remain.');
    }
    final calendar = _localCalendars.where((item) => item.id == id);
    if (calendar.isEmpty) return;

    final calendars = _localCalendars
        .where((item) => item.id != id)
        .toList(growable: false);
    final categories = _eventCategories
        .where((category) => category.calendarId != id)
        .toList(growable: false);
    final events = repository
        .getAllEvents()
        .where((event) => event.calendarId != id)
        .toList(growable: false);
    final deletedLastUsed = _lastUsedCalendar.id == id;

    await _settings.saveLocalCalendars(calendars);
    await _settings.saveEventCategories(categories);
    await _settings.saveLocalEvents(events);
    if (deletedLastUsed) {
      await _settings.saveLastUsedCalendar(calendars.first);
      _lastUsedCalendar = calendars.first;
    }
    _localCalendars = calendars;
    _eventCategories = categories;
    repository.replaceAllEvents(events);
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

  Future<void> deleteEventCategory(String categoryId) async {
    final category = _eventCategories.where((item) => item.id == categoryId);
    if (category.isEmpty) return;

    final categories = _eventCategories
        .where((item) => item.id != categoryId)
        .toList(growable: false);
    final events = repository
        .getAllEvents()
        .map(
          (event) => event.categoryId == categoryId
              ? event.copyWith(clearCategoryId: true)
              : event,
        )
        .toList(growable: false);

    await _settings.saveEventCategories(categories);
    await _settings.saveLocalEvents(events);
    _eventCategories = categories;
    repository.replaceAllEvents(events);
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

  Future<void> syncWidgetEvents() => _settings.syncWidgetEvents();

  /// Asks the home-screen widget to reload immediately (e.g. on app lifecycle changes).
  Future<void> refreshWidget() => _settings.refreshWidget();

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

  Future<void> addEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required LocalCalendar calendar,
    String? categoryId,
    Color? categoryColor,
    bool isAllDay = false,
    RecurrenceFrequency? recurrenceFrequency,
    DateTime? recurrenceEndDate,
  }) async {
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
      recurrenceFrequency: recurrenceFrequency,
      recurrenceEndDate: recurrenceEndDate,
    );
    repository.addEvent(newEvent);
    try {
      await _settings.saveLocalEvents(repository.getAllEvents());
    } catch (_) {
      repository.deleteEvent(newEvent.id);
      rethrow;
    }
    _lastUsedCalendar = calendar;
    await _settings.saveLastUsedCalendar(calendar);
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await _deleteEvent(id, repository.deleteEvent);
  }

  Future<void> deleteEventSeries(String id) async {
    await _deleteEvent(id, repository.deleteEventSeries);
  }

  Future<void> _deleteEvent(String id, bool Function(String) remove) async {
    final previousEvents = repository.getAllEvents();
    if (!remove(id)) return;
    try {
      await _settings.saveLocalEvents(repository.getAllEvents());
    } catch (_) {
      repository.replaceAllEvents(previousEvents);
      rethrow;
    }
    notifyListeners();
  }
}
