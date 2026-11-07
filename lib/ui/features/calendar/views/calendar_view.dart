import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:calendar/domain/models/calendar_event.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../../data/calendar_intent_service.dart';
import '../../../../data/event_reminder_service.dart';
import '../../../../data/repositories/device_calendar_repository.dart';
import '../../../../providers.dart';
import '../../../../domain/models/external_calendar_event.dart';
import '../../../../domain/models/event_category.dart';
import '../../settings/view_models/device_calendars_view_model.dart';
import '../../settings/views/settings_view.dart';
import '../../../../domain/models/local_calendar.dart';
import '../../../../domain/models/recurrence_frequency.dart';
import '../calendar_greeting.dart';
import '../view_models/calendar_view_model.dart';
import 'widgets/day_cell.dart';
import 'widgets/event_tile.dart';
import 'widgets/month_header.dart';
import 'widgets/week_number_cell.dart';

/// The main calendar screen.
///
/// Renders a full monthly grid with selectable day cells and a scrollable
/// daily event list below. Supports custom starting days (Monday, Sunday, Saturday)
/// and optional ISO 8601 week number indicators.
///
/// Uses [CustomScrollView] with [SliverGrid] and [SliverList] so the entire page
/// scrolls as one unified surface, avoiding layout overflows across different
/// device sizes and orientations.
///
/// Watches calendar state through Riverpod and handles screen-level lifecycle.
class CalendarView extends ConsumerStatefulWidget {
  const CalendarView({super.key, this.intentService, this.reminderService});

  final CalendarIntentService? intentService;
  final EventReminderService? reminderService;

  @override
  ConsumerState<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends ConsumerState<CalendarView>
    with WidgetsBindingObserver {
  CalendarViewModel get _viewModel => ref.read(calendarViewModelProvider);
  DeviceCalendarsViewModel get _deviceCalendarsViewModel =>
      ref.read(deviceCalendarsViewModelProvider);
  bool _processingIncomingEvents = false;
  DateTime? _requestedDeviceEventsMonth;
  bool _isAgendaView = false;
  EventReminderTarget? _reminderTarget;
  final GlobalKey _reminderTargetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.intentService?.addListener(_processIncomingEvents);
    widget.reminderService?.target.addListener(_handleReminderTarget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processIncomingEvents();
      _handleReminderTarget();
      _syncWidgetEvents();
      _loadDeviceCalendars();
    });
  }

  Future<void> _syncWidgetEvents() async {
    try {
      await _viewModel.syncWidgetEvents();
    } on PlatformException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'calendar widget sync',
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intentService != widget.intentService) {
      oldWidget.intentService?.removeListener(_processIncomingEvents);
      widget.intentService?.addListener(_processIncomingEvents);
      _processIncomingEvents();
    }
    if (oldWidget.reminderService != widget.reminderService) {
      oldWidget.reminderService?.target.removeListener(_handleReminderTarget);
      widget.reminderService?.target.addListener(_handleReminderTarget);
      _handleReminderTarget();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.intentService?.removeListener(_processIncomingEvents);
    widget.reminderService?.target.removeListener(_handleReminderTarget);
    super.dispose();
  }

  void _handleReminderTarget() {
    final target = widget.reminderService?.target.value;
    if (target == null) return;
    _viewModel.selectDate(target.startTime);
    setState(() => _reminderTarget = target);
    unawaited(_scrollToReminderTarget(target));
  }

  Future<void> _scrollToReminderTarget(EventReminderTarget target) async {
    if (target.eventId == null) {
      final dayStart = DateTime(
        target.startTime.year,
        target.startTime.month,
        target.startTime.day,
      );
      await _deviceCalendarsViewModel.load();
      await _deviceCalendarsViewModel.refreshEventsForRange(
        dayStart,
        dayStart.add(const Duration(days: 1)),
      );
    }
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _reminderTargetKey.currentContext;
      if (targetContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.3,
            duration: const Duration(milliseconds: 300),
          ),
        );
      }
    });
  }

  Key _eventTileKey(CalendarEvent event) {
    final target = _reminderTarget;
    if (target != null &&
        ((target.eventId != null && target.eventId == event.id) ||
            (target.title == event.title &&
                target.startTime.isAtSameMomentAs(event.startTime)))) {
      return _reminderTargetKey;
    }
    return ValueKey('event-${event.id}');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _loadDeviceCalendars();
      _refreshWidget();
    } else if (state == AppLifecycleState.paused) {
      _refreshWidget();
    }
  }

  Future<void> _refreshWidget() async {
    try {
      await _viewModel.refreshWidget();
    } on PlatformException catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'calendar widget refresh',
        ),
      );
    }
  }

  Future<void> _loadDeviceCalendars() async {
    final calendarsViewModel = _deviceCalendarsViewModel;
    await calendarsViewModel.load();
    if (mounted) {
      _refreshDeviceEventsForMonth(_viewModel.focusedMonth);
    }
  }

  void _refreshDeviceEventsForMonth(DateTime month) {
    final calendarsViewModel = _deviceCalendarsViewModel;
    final monthKey = DateTime(month.year, month.month);
    if (_requestedDeviceEventsMonth == monthKey) return;
    _requestedDeviceEventsMonth = monthKey;
    final start = DateTime(
      month.year,
      month.month,
      1,
    ).subtract(const Duration(days: 7));
    final end = DateTime(
      month.year,
      month.month + 1,
      1,
    ).add(const Duration(days: 7));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        calendarsViewModel.refreshEventsForRange(start, end);
      }
    });
  }

  List<CalendarEvent> _eventsFor(DateTime date) {
    final events = [
      ..._viewModel.selectedDateEvents,
      ..._deviceCalendarsViewModel.eventsFor(date),
    ]..sort((first, second) => first.startTime.compareTo(second.startTime));
    return events;
  }

  Map<DateTime, List<CalendarEvent>> _agendaEventsFor(DateTime month) {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final events =
        [
          ..._viewModel.repository.getEventsBetween(start, end),
          ..._deviceCalendarsViewModel.events,
        ]..removeWhere(
          (event) =>
              event.startTime.isBefore(start) || !event.startTime.isBefore(end),
        );
    events.sort((first, second) => first.startTime.compareTo(second.startTime));

    final groupedEvents = <DateTime, List<CalendarEvent>>{};
    for (final event in events) {
      final date = DateTime(
        event.startTime.year,
        event.startTime.month,
        event.startTime.day,
      );
      groupedEvents.putIfAbsent(date, () => []).add(event);
    }
    return groupedEvents;
  }

  bool _hasEventsOn(DateTime date) =>
      _viewModel.hasEventsOn(date) ||
      _deviceCalendarsViewModel.hasEventsOn(date);

  List<Color> _eventColorsOn(DateTime date) => {
    ..._viewModel.repository.getEventsForDay(date).map((event) => event.color),
    ..._deviceCalendarsViewModel.eventsFor(date).map((event) => event.color),
  }.toList(growable: false);

  Future<void> _processIncomingEvents() async {
    final service = widget.intentService;
    if (!mounted || _processingIncomingEvents || service == null) return;

    _processingIncomingEvents = true;
    try {
      while (mounted && service.hasPendingEvents) {
        final event = service.takeNextEvent();
        _viewModel.selectDate(event.startTime);
        await _showAddEventDialog(context, initialEvent: event);
      }
    } finally {
      _processingIncomingEvents = false;
    }
    if (mounted) {
      final error = service.takeError();
      if (error != null) {
        final l10n = AppLocalizations.of(context)!;
        final message = switch (error.message) {
          'invalidCalendarFile' => l10n.invalidCalendarFile,
          'calendarFileReadError' => l10n.calendarFileReadError(
            error.details ?? '',
          ),
          _ => error.message,
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  /// Generates the ordered 7 weekday labels starting from [firstDay].
  List<String> _buildWeekdayLabels(
    StartingDayOfWeek firstDay,
    AppLocalizations l10n,
  ) {
    final labels = [
      l10n.mondayShort,
      l10n.tuesdayShort,
      l10n.wednesdayShort,
      l10n.thursdayShort,
      l10n.fridayShort,
      l10n.saturdayShort,
      l10n.sundayShort,
    ];
    final startIndex = (firstDay.dateTimeWeekday - 1) % 7;
    return List.generate(7, (i) => labels[(startIndex + i) % 7]);
  }

  /// Generates the list of 35 or 42 dates that make up the monthly calendar grid,
  /// padding with days from the previous and next month to form complete weeks
  /// starting on [firstDay].
  List<DateTime> _buildMonthGrid(
    DateTime focusedMonth,
    StartingDayOfWeek firstDay,
  ) {
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final int leadingDays =
        ((firstDayOfMonth.weekday - firstDay.dateTimeWeekday) % 7 + 7) % 7;

    // Start from the firstDay before or on the first day of the month
    final startDate = firstDayOfMonth.subtract(Duration(days: leadingDays));

    // Calculate total days (either 35 or 42 to fill all rows evenly)
    final daysInMonth = DateTime(
      focusedMonth.year,
      focusedMonth.month + 1,
      0,
    ).day;
    final totalCells = (leadingDays + daysInMonth) > 35 ? 42 : 35;

    return List.generate(
      totalCells,
      (index) =>
          DateTime(startDate.year, startDate.month, startDate.day + index),
    );
  }

  /// Calculates the ISO 8601 week number for a given date.
  ///
  /// Uses pure UTC calculations to prevent local Daylight Saving Time (DST)
  /// transitions from truncating day differences and skewing week numbers.
  int _getIsoWeekNumber(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    // Find Thursday of the current week (ISO 8601 defines week 1 by Thursday)
    final thursday = utcDate.add(Duration(days: 4 - utcDate.weekday));
    // Find the first Thursday of that year (which is guaranteed to be in Week 1)
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final firstThursday = firstDayOfYear.add(
      Duration(days: (4 - firstDayOfYear.weekday + 7) % 7),
    );

    return thursday.difference(firstThursday).inDays ~/ 7 + 1;
  }

  Widget _buildDayCell(
    DateTime date,
    DateTime focusedMonth,
    DateTime selectedDate,
    DateTime today,
  ) {
    final isCurrentMonth = date.month == focusedMonth.month;
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected =
        date.year == selectedDate.year &&
        date.month == selectedDate.month &&
        date.day == selectedDate.day;

    return DayCell(
      date: date,
      isSelected: isSelected,
      isToday: isToday,
      isCurrentMonth: isCurrentMonth,
      hasEvents: _hasEventsOn(date),
      eventColors: _eventColorsOn(date),
      onTap: () => _viewModel.selectDate(date),
    );
  }

  double _horizontalDragDelta = 0;

  void _onHorizontalDragStart(DragStartDetails details) {
    _horizontalDragDelta = 0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _horizontalDragDelta += details.primaryDelta ?? 0;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    const velocityThreshold = 150.0;
    const distanceThreshold = 40.0;

    if (velocity < -velocityThreshold) {
      _viewModel.nextMonth();
    } else if (velocity > velocityThreshold) {
      _viewModel.previousMonth();
    } else if (_horizontalDragDelta < -distanceThreshold) {
      _viewModel.nextMonth();
    } else if (_horizontalDragDelta > distanceThreshold) {
      _viewModel.previousMonth();
    }
    _horizontalDragDelta = 0;
  }

  void _onHorizontalDragCancel() {
    _horizontalDragDelta = 0;
  }

  Future<void> _showAddEventDialog(
    BuildContext context, {
    ExternalCalendarEvent? initialEvent,
    CalendarEvent? editingEvent,
    bool updateSeries = false,
    int? initialReminderMinutesBefore,
    String? initialReminderEventKey,
  }) {
    final calendarsViewModel = _deviceCalendarsViewModel;
    final reminderService = ref.read(eventReminderServiceProvider);
    final l10n = AppLocalizations.of(context)!;
    final selectedCalendarIds = calendarsViewModel.selectedCalendarIds;
    final deviceCalendars = calendarsViewModel.calendars
        .where(
          (calendar) =>
              !calendar.readOnly && selectedCalendarIds.contains(calendar.id),
        )
        .toList(growable: false);
    final selectedLocalCalendar = editingEvent == null
        ? _viewModel.lastUsedCalendar
        : _viewModel.localCalendars.firstWhere(
            (calendar) => calendar.id == editingEvent.calendarId,
            orElse: () => _viewModel.lastUsedCalendar,
          );
    final calendarDestination = editingEvent == null
        ? _viewModel.lastUsedCalendarDestination
        : editingEvent.isDeviceCalendarEvent
        ? 'device:${editingEvent.calendarId}'
        : 'local:${editingEvent.calendarId}';
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _AddEventBottomSheet(
          selectedDate:
              editingEvent?.startTime ??
              initialEvent?.startTime ??
              _viewModel.selectedDate,
          initialCalendar: selectedLocalCalendar,
          initialCalendarDestination: calendarDestination,
          localCalendars: _viewModel.localCalendars,
          categoriesForCalendar: _viewModel.categoriesFor,
          deviceCalendars: deviceCalendars,
          initialEvent: initialEvent,
          editingEvent: editingEvent,
          updateSeries: updateSeries,
          initialReminderMinutesBefore:
              initialReminderMinutesBefore ??
              editingEvent?.reminderMinutesBefore,
          onSave:
              ({
                required String title,
                required String description,
                required DateTime startTime,
                required DateTime endTime,
                required LocalCalendar calendar,
                required String? categoryId,
                required Color? categoryColor,
                required String? deviceCalendarId,
                required bool isAllDay,
                required RecurrenceFrequency? recurrenceFrequency,
                required DateTime? recurrenceEndDate,
                required int? reminderMinutesBefore,
              }) async {
                if (editingEvent != null &&
                    editingEvent.isDeviceCalendarEvent) {
                  final reminderService = ref.read(
                    eventReminderServiceProvider,
                  );
                  final oldReminderMinutes =
                      initialReminderMinutesBefore ??
                      editingEvent.reminderMinutesBefore;
                  final updatedReminderEvent = CalendarEvent(
                    id: editingEvent.id,
                    title: title,
                    description: description,
                    calendarId: editingEvent.calendarId,
                    startTime: startTime,
                    endTime: endTime,
                    isAllDay: isAllDay,
                    color: editingEvent.color,
                    readOnly: editingEvent.readOnly,
                    isDeviceCalendarEvent: true,
                    recurrenceFrequency: updateSeries
                        ? editingEvent.recurrenceFrequency
                        : null,
                    recurrenceEndDate: updateSeries
                        ? editingEvent.recurrenceEndDate
                        : null,
                    isRecurring: updateSeries && editingEvent.isRecurring,
                  );
                  if (oldReminderMinutes != null && reminderService == null) {
                    throw StateError('Event reminders are not available.');
                  }
                  await reminderService?.cancelEvent(
                    initialReminderEventKey ??
                        EventReminderService.keyForEvent(editingEvent),
                    occurrenceStartTime: updateSeries
                        ? null
                        : editingEvent.startTime,
                  );
                  try {
                    if (reminderMinutesBefore != null) {
                      if (reminderService == null) {
                        throw StateError('Event reminders are not available.');
                      }
                      await reminderService.scheduleEvent(
                        event: updatedReminderEvent,
                        minutesBefore: reminderMinutesBefore,
                        body: l10n.eventStartsAt(
                          DateFormat.jm(
                            Localizations.localeOf(context).toString(),
                          ).format(startTime),
                        ),
                      );
                    }
                    await calendarsViewModel.updateEvent(
                      eventId: editingEvent.id,
                      title: title,
                      description: description,
                      start: startTime,
                      end: endTime,
                      isAllDay: isAllDay,
                      updateSeries: updateSeries,
                    );
                  } catch (_) {
                    await reminderService?.cancelEvent(
                      EventReminderService.keyForEvent(updatedReminderEvent),
                      occurrenceStartTime: updateSeries ? null : startTime,
                    );
                    if (oldReminderMinutes != null && reminderService != null) {
                      final oldReminderEvent = CalendarEvent(
                        id: editingEvent.id,
                        title: editingEvent.title,
                        description: editingEvent.description,
                        calendarId: editingEvent.calendarId,
                        startTime: editingEvent.startTime,
                        endTime: editingEvent.endTime,
                        isAllDay: editingEvent.isAllDay,
                        color: editingEvent.color,
                        isDeviceCalendarEvent: true,
                        recurrenceFrequency: updateSeries
                            ? editingEvent.recurrenceFrequency
                            : null,
                        recurrenceEndDate: updateSeries
                            ? editingEvent.recurrenceEndDate
                            : null,
                        isRecurring: updateSeries && editingEvent.isRecurring,
                      );
                      await reminderService.scheduleEvent(
                        event: oldReminderEvent,
                        minutesBefore: oldReminderMinutes,
                        body: l10n.eventStartsAt(
                          DateFormat.jm(
                            Localizations.localeOf(context).toString(),
                          ).format(editingEvent.startTime),
                        ),
                      );
                    }
                    rethrow;
                  }
                } else if (editingEvent != null) {
                  await _viewModel.updateEvent(
                    existingEvent: editingEvent,
                    title: title,
                    description: description,
                    startTime: startTime,
                    endTime: endTime,
                    calendar: calendar,
                    categoryId: categoryId,
                    categoryColor: categoryColor,
                    isAllDay: isAllDay,
                    recurrenceFrequency: recurrenceFrequency,
                    recurrenceEndDate: recurrenceEndDate,
                    reminderMinutesBefore: reminderMinutesBefore,
                    reminderBody: reminderMinutesBefore == null
                        ? null
                        : l10n.eventStartsAt(
                            DateFormat.jm(
                              Localizations.localeOf(context).toString(),
                            ).format(startTime),
                          ),
                    previousReminderBody:
                        editingEvent.reminderMinutesBefore == null
                        ? null
                        : l10n.eventStartsAt(
                            DateFormat.jm(
                              Localizations.localeOf(context).toString(),
                            ).format(editingEvent.startTime),
                          ),
                    updateSeries: updateSeries,
                  );
                } else if (deviceCalendarId == null) {
                  await _viewModel.addEvent(
                    title: title,
                    description: description,
                    startTime: startTime,
                    endTime: endTime,
                    calendar: calendar,
                    categoryId: categoryId,
                    categoryColor: categoryColor,
                    isAllDay: isAllDay,
                    recurrenceFrequency: recurrenceFrequency,
                    recurrenceEndDate: recurrenceEndDate,
                    reminderMinutesBefore: reminderMinutesBefore,
                    reminderBody: reminderMinutesBefore == null
                        ? null
                        : l10n.eventStartsAt(
                            DateFormat.jm(
                              Localizations.localeOf(context).toString(),
                            ).format(startTime),
                          ),
                  );
                } else {
                  final reminderEvent = reminderMinutesBefore == null
                      ? null
                      : CalendarEvent(
                          id:
                              'device|$deviceCalendarId|$title|'
                              '${startTime.toUtc().microsecondsSinceEpoch}',
                          title: title,
                          description: description,
                          calendarId: deviceCalendarId,
                          startTime: startTime,
                          endTime: endTime,
                          isAllDay: isAllDay,
                          isDeviceCalendarEvent: true,
                          recurrenceFrequency: recurrenceFrequency,
                          recurrenceEndDate: recurrenceEndDate,
                        );
                  if (reminderEvent != null && reminderMinutesBefore != null) {
                    if (reminderService == null) {
                      throw StateError('Event reminders are not available.');
                    }
                    await reminderService.scheduleEvent(
                      event: reminderEvent,
                      minutesBefore: reminderMinutesBefore,
                      body: l10n.eventStartsAt(
                        DateFormat.jm(
                          Localizations.localeOf(context).toString(),
                        ).format(startTime),
                      ),
                    );
                  }
                  try {
                    await calendarsViewModel.createEvent(
                      calendarId: deviceCalendarId,
                      title: title,
                      description: description,
                      start: startTime,
                      end: endTime,
                      isAllDay: isAllDay,
                      recurrenceFrequency: recurrenceFrequency,
                      recurrenceEndDate: recurrenceEndDate,
                    );
                  } catch (_) {
                    if (reminderEvent != null) {
                      await reminderService!.cancelEvent(
                        EventReminderService.keyForEvent(reminderEvent),
                      );
                    }
                    rethrow;
                  }
                  await _viewModel.rememberDeviceCalendar(deviceCalendarId);
                }
              },
        );
      },
    );
  }

  Future<void> _showEditEventDialog(CalendarEvent event) async {
    var updateSeries = false;
    if (event.isRecurring) {
      final l10n = AppLocalizations.of(context)!;
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.editRecurringEventTitle),
          content: Text(l10n.editRecurringEventConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.deleteThisEventOnly),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.deleteEntireSeries),
            ),
          ],
        ),
      );
      if (choice == null) return;
      updateSeries = choice;
    }

    var eventToEdit = event;
    if (updateSeries &&
        !event.isDeviceCalendarEvent &&
        event.id.contains('::')) {
      final seriesId = event.id.substring(0, event.id.indexOf('::'));
      eventToEdit = _viewModel.repository.getAllEvents().firstWhere(
        (storedEvent) => storedEvent.id == seriesId,
      );
    }

    var reminderMinutesBefore = eventToEdit.reminderMinutesBefore;
    String? reminderEventKey;
    if (eventToEdit.isDeviceCalendarEvent) {
      final reminderTarget = await ref
          .read(eventReminderServiceProvider)
          ?.reminderForEvent(eventToEdit);
      reminderMinutesBefore = reminderTarget?.minutesBefore;
      reminderEventKey = reminderTarget?.eventKey;
    }
    if (!mounted) return;
    await _showAddEventDialog(
      context,
      editingEvent: eventToEdit,
      updateSeries: updateSeries,
      initialReminderMinutesBefore: reminderMinutesBefore,
      initialReminderEventKey: reminderEventKey,
    );
  }

  Future<void> _deleteEvent(CalendarEvent event) async {
    final l10n = AppLocalizations.of(context)!;
    var deleteSeries = false;
    final isRecurring =
        event.isRecurring ||
        _viewModel.repository.isRecurringOccurrence(event.id);

    if (isRecurring) {
      final deleteChoice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.deleteRecurringEventTitle),
          content: Text(l10n.deleteRecurringEventConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.deleteThisEventOnly),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.deleteEntireSeries),
            ),
          ],
        ),
      );
      if (deleteChoice == null) return;
      deleteSeries = deleteChoice;
    } else if (event.isDeviceCalendarEvent) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.deleteSyncedEventTitle),
          content: Text(l10n.deleteSyncedEventConfirmation),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.deleteEvent),
            ),
          ],
        ),
      );
      if (shouldDelete != true) return;
    }

    try {
      if (event.isDeviceCalendarEvent) {
        if (deleteSeries) {
          await _deviceCalendarsViewModel.deleteEventSeries(event.id);
        } else {
          await _deviceCalendarsViewModel.deleteEvent(event.id);
        }
      } else if (deleteSeries) {
        await _viewModel.deleteEventSeries(event.id);
      } else {
        await _viewModel.deleteEvent(event.id);
      }
      await widget.reminderService?.cancelEvent(
        EventReminderService.keyForEvent(event),
        eventId: deleteSeries ? null : event.id,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.calendarWriteError(error.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(calendarViewModelProvider);
    ref.watch(deviceCalendarsViewModelProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final focusedMonth = _viewModel.focusedMonth;
    _refreshDeviceEventsForMonth(focusedMonth);
    final selectedDate = _viewModel.selectedDate;
    final events = _eventsFor(selectedDate);
    final agendaEvents = _agendaEventsFor(focusedMonth);
    final firstDay = _viewModel.firstDayOfWeek;
    final showWeekNumbers = _viewModel.showWeekNumbers;
    final gridDays = _buildMonthGrid(focusedMonth, firstDay);
    final weekdayHeaders = _buildWeekdayLabels(firstDay, l10n);

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            calendarGreeting(l10n, now),
            maxLines: 1,
            softWrap: false,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(_isAgendaView ? Icons.calendar_month : Icons.view_agenda),
          tooltip: _isAgendaView ? l10n.calendarView : l10n.agendaView,
          onPressed: () => setState(() => _isAgendaView = !_isAgendaView),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.settings,
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (context) => const SettingsView(),
                    ),
                  )
                  .then((_) => _loadDeviceCalendars());
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEventDialog(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.newEvent),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final horizontalPadding = constraints.maxWidth >= 600 ? 24.0 : 0.0;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _onHorizontalDragCancel,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: CustomScrollView(
                slivers: [
                  // 1. Month Header (Previous / Next / Today)
                  SliverToBoxAdapter(
                    child: MonthHeader(
                      focusedMonth: focusedMonth,
                      onPreviousMonth: _viewModel.previousMonth,
                      onNextMonth: _viewModel.nextMonth,
                      onToday: _viewModel.goToToday,
                    ),
                  ),

                  if (!_isAgendaView) ...[
                    // 2. Weekday Header Row
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Row(
                          children: [
                            if (showWeekNumbers)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    l10n.weekNumberShort,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.outline,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            ...weekdayHeaders.map((day) {
                              return Expanded(
                                child: Center(
                                  child: Text(
                                    day,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 6)),

                    // 3. Calendar Grid (7 columns, or 8 with week numbers)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: showWeekNumbers ? 8 : 7,
                          childAspectRatio: showWeekNumbers ? 1.05 : 1.2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (showWeekNumbers) {
                              final row = index ~/ 8;
                              final col = index % 8;

                              if (col == 0) {
                                final thursdayOffset =
                                    firstDay == StartingDayOfWeek.sunday
                                    ? 4
                                    : (firstDay == StartingDayOfWeek.saturday
                                          ? 5
                                          : 3);
                                final weekNumber = _getIsoWeekNumber(
                                  gridDays[row * 7 + thursdayOffset],
                                );
                                return WeekNumberCell(
                                  weekNumber: weekNumber,
                                  tooltipBuilder: l10n.weekTooltip,
                                );
                              }

                              final dayIndex = row * 7 + (col - 1);
                              final date = gridDays[dayIndex];
                              return _buildDayCell(
                                date,
                                focusedMonth,
                                selectedDate,
                                today,
                              );
                            }

                            final date = gridDays[index];
                            return _buildDayCell(
                              date,
                              focusedMonth,
                              selectedDate,
                              today,
                            );
                          },
                          childCount: showWeekNumbers
                              ? (gridDays.length ~/ 7) * 8
                              : gridDays.length,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: Divider(height: 16)),

                    // 4. Selected Date Summary Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat(
                                  'EEEE, MMM d',
                                  locale,
                                ).format(selectedDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              l10n.eventCount(events.length),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 5. Daily Events List or Empty State
                    if (events.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_available,
                                  size: 40,
                                  color: theme.colorScheme.outlineVariant,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.noEventsScheduled,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: events.length,
                        itemBuilder: (context, index) {
                          final event = events[index];
                          return EventTile(
                            key: _eventTileKey(event),
                            event: event,
                            onDelete: () => _deleteEvent(event),
                            onEdit: () => _showEditEventDialog(event),
                          );
                        },
                      ),
                  ] else if (agendaEvents.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.event_available,
                                size: 40,
                                color: theme.colorScheme.outlineVariant,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.noEventsScheduled,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.outline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    for (final entry in agendaEvents.entries) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(
                            DateFormat('EEEE, MMM d', locale).format(entry.key),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: entry.value.length,
                        itemBuilder: (context, index) {
                          final event = entry.value[index];
                          return EventTile(
                            key: _eventTileKey(event),
                            event: event,
                            onDelete: () => _deleteEvent(event),
                            onEdit: () => _showEditEventDialog(event),
                          );
                        },
                      ),
                    ],

                  // Bottom padding so content is never obscured by the FloatingActionButton
                  const SliverToBoxAdapter(child: SizedBox(height: 80)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Modal bottom sheet widget for adding new events.
///
/// Disposes its text controllers when the sheet closes.
class _AddEventBottomSheet extends StatefulWidget {
  const _AddEventBottomSheet({
    required this.selectedDate,
    required this.initialCalendar,
    required this.initialCalendarDestination,
    required this.localCalendars,
    required this.categoriesForCalendar,
    required this.deviceCalendars,
    this.initialEvent,
    this.editingEvent,
    this.updateSeries = false,
    this.initialReminderMinutesBefore,
    required this.onSave,
  });

  final DateTime selectedDate;
  final LocalCalendar initialCalendar;
  final String initialCalendarDestination;
  final List<LocalCalendar> localCalendars;
  final List<EventCategory> Function(String calendarId) categoriesForCalendar;
  final List<DeviceCalendarInfo> deviceCalendars;
  final ExternalCalendarEvent? initialEvent;
  final CalendarEvent? editingEvent;
  final bool updateSeries;
  final int? initialReminderMinutesBefore;
  final Future<void> Function({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required LocalCalendar calendar,
    required String? categoryId,
    required Color? categoryColor,
    required String? deviceCalendarId,
    required bool isAllDay,
    required RecurrenceFrequency? recurrenceFrequency,
    required DateTime? recurrenceEndDate,
    required int? reminderMinutesBefore,
  })
  onSave;

  @override
  State<_AddEventBottomSheet> createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<_AddEventBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  int _endDateOffset = 0;
  bool _isAllDay = false;
  RecurrenceFrequency? _recurrenceFrequency;
  DateTime? _recurrenceEndDate;
  late String _selectedCalendarId;
  String? _selectedCategoryId;
  int? _reminderMinutesBefore;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.editingEvent?.title ?? widget.initialEvent?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text:
          widget.editingEvent?.description ??
          widget.initialEvent?.description ??
          '',
    );
    final destination = widget.initialCalendarDestination;
    final hasAvailableDeviceCalendar =
        destination.startsWith('device:') &&
        widget.deviceCalendars.any(
          (calendar) =>
              destination == 'device:${calendar.id}' && !calendar.readOnly,
        );
    _selectedCalendarId = hasAvailableDeviceCalendar
        ? destination
        : 'local:${widget.initialCalendar.id}';
    final event = widget.editingEvent;
    final initialStartTime = event?.startTime ?? widget.initialEvent?.startTime;
    final initialEndTime = event?.endTime ?? widget.initialEvent?.endTime;
    _isAllDay = event?.isAllDay ?? widget.initialEvent?.isAllDay ?? false;
    _selectedCategoryId = event?.categoryId;
    _reminderMinutesBefore = widget.initialReminderMinutesBefore;
    if (event != null || widget.initialEvent != null) {
      _recurrenceFrequency =
          event?.recurrenceFrequency ??
          widget.initialEvent?.recurrenceFrequency;
      _recurrenceEndDate =
          event?.recurrenceEndDate ?? widget.initialEvent?.recurrenceEndDate;
    }
    if (initialStartTime != null && initialEndTime != null && !_isAllDay) {
      _startTime = TimeOfDay.fromDateTime(initialStartTime);
      _endTime = TimeOfDay.fromDateTime(initialEndTime);
      _endDateOffset =
          DateTime(
                initialEndTime.year,
                initialEndTime.month,
                initialEndTime.day,
              )
              .difference(
                DateTime(
                  initialStartTime.year,
                  initialStartTime.month,
                  initialStartTime.day,
                ),
              )
              .inDays;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
    final locale = Localizations.localeOf(context).toString();
    final selectedDateFormatted = DateFormat(
      'EEEE, MMM d, yyyy',
      locale,
    ).format(widget.selectedDate);
    final selectedLocalCalendar = _selectedCalendarId.startsWith('local:')
        ? widget.localCalendars.firstWhere(
            (calendar) =>
                calendar.id == _selectedCalendarId.substring('local:'.length),
            orElse: () => widget.initialCalendar,
          )
        : null;
    final categories = selectedLocalCalendar == null
        ? const <EventCategory>[]
        : widget.categoriesForCalendar(selectedLocalCalendar.id);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingEvent == null ? l10n.addEvent : l10n.editEvent,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.forDate(selectedDateFormatted),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.eventTitle,
                helperText: l10n.required,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const ValueKey('event-calendar-dropdown'),
              initialValue: _selectedCalendarId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.saveToCalendar,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month),
                helperText: selectedLocalCalendar != null
                    ? l10n.savedLocallyOnDevice
                    : l10n.savedToDeviceCalendar,
              ),
              items: [
                ...widget.localCalendars.map(
                  (calendar) => DropdownMenuItem(
                    value: 'local:${calendar.id}',
                    child: Text(calendar.name),
                  ),
                ),
                ...widget.deviceCalendars.map(
                  (calendar) => DropdownMenuItem(
                    value: 'device:${calendar.id}',
                    child: Text(
                      calendar.accountName == null
                          ? calendar.name
                          : '${calendar.name} • ${calendar.accountName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: _isSaving || widget.editingEvent != null
                  ? null
                  : (calendarId) {
                      if (calendarId != null) {
                        setState(() {
                          _selectedCalendarId = calendarId;
                          _selectedCategoryId = null;
                        });
                      }
                    },
            ),
            if (selectedLocalCalendar != null && categories.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                key: ValueKey(
                  'event-category-dropdown-${selectedLocalCalendar.id}',
                ),
                initialValue: _selectedCategoryId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.categoryName,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.label_outline),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(l10n.noCategory),
                  ),
                  ...categories.map(
                    (category) => DropdownMenuItem<String?>(
                      value: category.id,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 7,
                            backgroundColor: category.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(category.name)),
                        ],
                      ),
                    ),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (categoryId) =>
                          setState(() => _selectedCategoryId = categoryId),
              ),
            ],
            if (widget.editingEvent?.isDeviceCalendarEvent != true &&
                !(widget.editingEvent?.isRecurring == true &&
                    !widget.updateSeries) &&
                (selectedLocalCalendar != null ||
                    _selectedCalendarId.startsWith('device:'))) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceFrequency?>(
                key: const ValueKey('event-recurrence-dropdown'),
                initialValue: _recurrenceFrequency,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l10n.recurrence,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem<RecurrenceFrequency?>(
                    value: null,
                    child: Text(l10n.noRecurrence),
                  ),
                  ...RecurrenceFrequency.values.map(
                    (frequency) => DropdownMenuItem<RecurrenceFrequency?>(
                      value: frequency,
                      child: Text(_recurrenceLabel(l10n, frequency)),
                    ),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (frequency) {
                        setState(() {
                          _recurrenceFrequency = frequency;
                          _recurrenceEndDate = frequency == null
                              ? null
                              : _recurrenceEndDate ??
                                    DateTime(
                                      widget.selectedDate.year + 1,
                                      widget.selectedDate.month,
                                      widget.selectedDate.day,
                                    );
                        });
                      },
              ),
              if (_recurrenceFrequency != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('recurrence-end-date-button'),
                  icon: const Icon(Icons.event_available),
                  label: Text(
                    l10n.recurrenceEndDate(
                      DateFormat.yMMMd(locale).format(_recurrenceEndDate!),
                    ),
                  ),
                  onPressed: _isSaving
                      ? null
                      : () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: _recurrenceEndDate!,
                            firstDate: DateTime(
                              widget.selectedDate.year,
                              widget.selectedDate.month,
                              widget.selectedDate.day,
                            ),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setState(() => _recurrenceEndDate = selected);
                          }
                        },
                ),
              ],
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              key: const ValueKey('event-reminder-dropdown'),
              initialValue: _reminderMinutesBefore,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.eventReminder,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.notifications_outlined),
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(l10n.noReminder),
                ),
                DropdownMenuItem<int?>(
                  value: 15,
                  child: Text(l10n.reminder15Minutes),
                ),
                DropdownMenuItem<int?>(
                  value: 30,
                  child: Text(l10n.reminder30Minutes),
                ),
                DropdownMenuItem<int?>(
                  value: 60,
                  child: Text(l10n.reminder1Hour),
                ),
                DropdownMenuItem<int?>(
                  value: 180,
                  child: Text(l10n.reminder3Hours),
                ),
                DropdownMenuItem<int?>(
                  value: 360,
                  child: Text(l10n.reminder6Hours),
                ),
                DropdownMenuItem<int?>(
                  value: 720,
                  child: Text(l10n.reminder12Hours),
                ),
                DropdownMenuItem<int?>(
                  value: 1440,
                  child: Text(l10n.reminder24Hours),
                ),
              ],
              onChanged: _isSaving
                  ? null
                  : (minutes) =>
                        setState(() => _reminderMinutesBefore = minutes),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.calendarWriteError(_saveError!),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            CheckboxListTile(
              key: const ValueKey('event-all-day-checkbox'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.wholeDay),
              value: _isAllDay,
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (isAllDay) {
                setState(() => _isAllDay = isAllDay ?? false);
              },
            ),
            if (!_isAllDay) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(l10n.startTime(_startTime.format(context))),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _startTime,
                        );
                        if (picked != null) {
                          final endMinutes =
                              picked.hour * 60 + picked.minute + 60;
                          setState(() {
                            _startTime = picked;
                            _endDateOffset = endMinutes ~/ (24 * 60);
                            final minutesInDay = endMinutes % (24 * 60);
                            _endTime = TimeOfDay(
                              hour: minutesInDay ~/ 60,
                              minute: minutesInDay % 60,
                            );
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule),
                      label: Text(l10n.endTime(_endTime.format(context))),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _endTime,
                        );
                        if (picked != null) {
                          setState(() {
                            _endTime = picked;
                            _endDateOffset =
                                picked.hour * 60 + picked.minute <
                                    _startTime.hour * 60 + _startTime.minute
                                ? 1
                                : 0;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving || _titleController.text.trim().isEmpty
                    ? null
                    : () async {
                        final title = _titleController.text.trim();
                        if (title.isEmpty) return;

                        final date = widget.selectedDate;
                        final startDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          _isAllDay ? 0 : _startTime.hour,
                          _isAllDay ? 0 : _startTime.minute,
                        );
                        final endDateTime = _isAllDay
                            ? DateTime(date.year, date.month, date.day + 1)
                            : DateTime(date.year, date.month, date.day)
                                  .add(Duration(days: _endDateOffset))
                                  .add(
                                    Duration(
                                      hours: _endTime.hour,
                                      minutes: _endTime.minute,
                                    ),
                                  );
                        Color? selectedCategoryColor;
                        for (final category in categories) {
                          if (category.id == _selectedCategoryId) {
                            selectedCategoryColor = category.color;
                            break;
                          }
                        }

                        setState(() {
                          _isSaving = true;
                          _saveError = null;
                        });
                        try {
                          await widget.onSave(
                            title: title,
                            description: _descriptionController.text.trim(),
                            startTime: startDateTime,
                            endTime: endDateTime,
                            calendar:
                                selectedLocalCalendar ?? widget.initialCalendar,
                            categoryId: _selectedCategoryId,
                            categoryColor: selectedCategoryColor,
                            deviceCalendarId:
                                _selectedCalendarId.startsWith('device:')
                                ? _selectedCalendarId.substring(
                                    'device:'.length,
                                  )
                                : null,
                            isAllDay: _isAllDay,
                            recurrenceFrequency: _recurrenceFrequency,
                            recurrenceEndDate: _recurrenceEndDate,
                            reminderMinutesBefore: _reminderMinutesBefore,
                          );
                          if (!mounted) return;
                          navigator.pop();
                        } catch (error) {
                          if (mounted) {
                            setState(() => _saveError = error.toString());
                          }
                        } finally {
                          if (mounted) setState(() => _isSaving = false);
                        }
                      },
                child: Text(
                  widget.editingEvent == null
                      ? l10n.saveEvent
                      : l10n.saveEventChanges,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _recurrenceLabel(
    AppLocalizations l10n,
    RecurrenceFrequency frequency,
  ) => switch (frequency) {
    RecurrenceFrequency.weekly => l10n.weekly,
    RecurrenceFrequency.everyTwoWeeks => l10n.everyTwoWeeks,
    RecurrenceFrequency.everyThreeWeeks => l10n.everyThreeWeeks,
    RecurrenceFrequency.monthly => l10n.monthly,
  };
}
