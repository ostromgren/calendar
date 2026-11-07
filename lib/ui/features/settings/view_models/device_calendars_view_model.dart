import 'package:flutter/foundation.dart';

import '../../../../data/repositories/device_calendar_repository.dart';
import '../../../../data/repositories/settings_repository.dart';
import '../../../../domain/models/calendar_event.dart';
import '../../../../domain/models/recurrence_frequency.dart';

class DeviceCalendarsViewModel extends ChangeNotifier {
  DeviceCalendarsViewModel({
    required this.repository,
    required this.settingsRepository,
  }) : _selectedCalendarIds =
           settingsRepository.deviceCalendarIds?.toSet() ?? <String>{};

  final DeviceCalendarRepository repository;
  final SettingsRepository settingsRepository;
  List<DeviceCalendarInfo> _calendars = const [];
  Set<String> _selectedCalendarIds;
  List<CalendarEvent> _events = const [];
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _hasPermission = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isSupported => repository.isSupported;
  bool get hasPermission => _hasPermission;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<DeviceCalendarInfo> get calendars => List.unmodifiable(_calendars);
  Set<String> get selectedCalendarIds => Set.unmodifiable(_selectedCalendarIds);
  List<CalendarEvent> get events => List.unmodifiable(_events);

  List<CalendarEvent> eventsFor(DateTime date) {
    final dayStart = DateTime(date.year, date.month, date.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    return _events
        .where(
          (event) =>
              event.startTime.isBefore(nextDay) &&
              event.endTime.isAfter(dayStart),
        )
        .toList(growable: false);
  }

  bool hasEventsOn(DateTime date) => eventsFor(date).isNotEmpty;

  Future<void> load() async {
    if (!isSupported || _isLoading) return;
    await _runLoading(() async {
      _hasPermission = await repository.hasPermission();
      if (_hasPermission) {
        await _loadCalendars();
      } else {
        _calendars = const [];
        _events = const [];
      }
    });
  }

  Future<bool> requestAccess() async {
    if (!isSupported || _isLoading) return false;
    var granted = false;
    await _runLoading(() async {
      _hasPermission = await repository.requestPermission();
      granted = _hasPermission;
      if (_hasPermission) {
        await _loadCalendars();
      } else {
        _calendars = const [];
        _events = const [];
      }
    });
    return granted;
  }

  Future<void> refresh() async {
    if (!isSupported || _isLoading) return;
    await _runLoading(() async {
      _hasPermission = await repository.hasPermission();
      if (_hasPermission) {
        await _loadCalendars();
      } else {
        _calendars = const [];
        _events = const [];
      }
    });
  }

  Future<void> openAppSettings() => repository.openAppSettings();

  Future<void> setCalendarSelected(String calendarId, bool selected) async {
    if (selected) {
      _selectedCalendarIds.add(calendarId);
    } else {
      _selectedCalendarIds.remove(calendarId);
    }
    await settingsRepository.saveDeviceCalendarIds(_selectedCalendarIds);
    notifyListeners();
    await refreshEvents();
  }

  Future<void> refreshEventsForRange(DateTime start, DateTime end) async {
    _rangeStart = start;
    _rangeEnd = end;
    await refreshEvents();
  }

  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
    required String description,
    required bool isAllDay,
    RecurrenceFrequency? recurrenceFrequency,
    DateTime? recurrenceEndDate,
  }) async {
    final calendar = _calendars.where((item) => item.id == calendarId);
    if (!_hasPermission ||
        calendar.isEmpty ||
        calendar.first.readOnly ||
        title.trim().isEmpty ||
        end.isBefore(start)) {
      throw StateError('Cannot create an event in the selected calendar.');
    }
    await repository.createEvent(
      calendarId: calendarId,
      title: title.trim(),
      start: start,
      end: end,
      description: description,
      isAllDay: isAllDay,
      recurrenceFrequency: recurrenceFrequency,
      recurrenceEndDate: recurrenceEndDate,
    );
    await refreshEvents();
  }

  Future<void> deleteEvent(String eventId) async {
    const prefix = 'device:';
    if (!eventId.startsWith(prefix) || !_hasPermission) {
      throw StateError('Cannot delete this device calendar event.');
    }
    await repository.deleteEvent(eventId.substring(prefix.length));
    await refreshEvents();
  }

  Future<void> updateEvent({
    required String eventId,
    required String title,
    required DateTime start,
    required DateTime end,
    required String description,
    required bool isAllDay,
    required bool updateSeries,
  }) async {
    const prefix = 'device:';
    final calendar = _calendars.where(
      (item) => item.id == _eventCalendarId(eventId),
    );
    if (!eventId.startsWith(prefix) ||
        !_hasPermission ||
        calendar.isEmpty ||
        calendar.first.readOnly ||
        title.trim().isEmpty ||
        end.isBefore(start)) {
      throw StateError('Cannot update this device calendar event.');
    }
    await repository.updateEvent(
      instanceId: eventId.substring(prefix.length),
      title: title.trim(),
      start: start,
      end: end,
      description: description,
      isAllDay: isAllDay,
      updateSeries: updateSeries,
    );
    await refreshEvents();
  }

  Future<void> deleteEventSeries(String eventId) async {
    const prefix = 'device:';
    if (!eventId.startsWith(prefix) || !_hasPermission) {
      throw StateError('Cannot delete this device calendar event.');
    }
    await repository.deleteEventSeries(eventId.substring(prefix.length));
    await refreshEvents();
  }

  String _eventCalendarId(String eventId) {
    return _events
            .where((event) => event.id == eventId)
            .map((event) => event.calendarId)
            .firstOrNull ??
        '';
  }

  Future<void> _loadCalendars() async {
    _calendars = await repository.getCalendars();
    final availableIds = _calendars.map((calendar) => calendar.id).toSet();
    final storedIds = settingsRepository.deviceCalendarIds;
    if (storedIds == null) {
      _selectedCalendarIds = availableIds;
      await settingsRepository.saveDeviceCalendarIds(_selectedCalendarIds);
    } else {
      _selectedCalendarIds = storedIds.toSet().intersection(availableIds);
      if (!setEquals(_selectedCalendarIds, storedIds.toSet())) {
        await settingsRepository.saveDeviceCalendarIds(_selectedCalendarIds);
      }
    }
    await refreshEvents();
  }

  Future<void> refreshEvents() async {
    final start = _rangeStart;
    final end = _rangeEnd;
    if (!_hasPermission ||
        start == null ||
        end == null ||
        _selectedCalendarIds.isEmpty) {
      _events = const [];
      _errorMessage = null;
      notifyListeners();
      return;
    }
    try {
      _events = await repository.getEvents(
        start,
        end,
        _selectedCalendarIds.toList(growable: false),
      );
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      _events = const [];
    }
    notifyListeners();
  }

  Future<void> _runLoading(Future<void> Function() operation) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await operation();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
