import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:calendar/l10n/generated/app_localizations.dart';

import '../../../../data/calendar_intent_service.dart';
import '../../../../domain/models/external_calendar_event.dart';
import '../../settings/view_models/theme_view_model.dart';
import '../../settings/views/settings_view.dart';
import '../../../../domain/models/local_calendar.dart';
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
/// Listens to [CalendarViewModel] via [ListenableBuilder] and rebuilds only
/// when [CalendarViewModel.notifyListeners] is called.
class CalendarView extends StatefulWidget {
  const CalendarView({
    super.key,
    required this.viewModel,
    required this.themeViewModel,
    this.intentService,
  });

  final CalendarViewModel viewModel;
  final ThemeViewModel themeViewModel;
  final CalendarIntentService? intentService;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  ThemeViewModel get _themeViewModel => widget.themeViewModel;
  bool _processingIncomingEvents = false;

  @override
  void initState() {
    super.initState();
    widget.intentService?.addListener(_processIncomingEvents);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processIncomingEvents();
    });
  }

  @override
  void didUpdateWidget(covariant CalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.intentService != widget.intentService) {
      oldWidget.intentService?.removeListener(_processIncomingEvents);
      widget.intentService?.addListener(_processIncomingEvents);
      _processIncomingEvents();
    }
  }

  @override
  void dispose() {
    widget.intentService?.removeListener(_processIncomingEvents);
    super.dispose();
  }

  Future<void> _processIncomingEvents() async {
    final service = widget.intentService;
    if (!mounted || _processingIncomingEvents || service == null) return;

    _processingIncomingEvents = true;
    try {
      while (mounted && service.hasPendingEvents) {
        final event = service.takeNextEvent();
        widget.viewModel.selectDate(event.startTime);
        await _showAddEventDialog(context, event);
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
      hasEvents: widget.viewModel.hasEventsOn(date),
      onTap: () => widget.viewModel.selectDate(date),
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
      widget.viewModel.nextMonth();
    } else if (velocity > velocityThreshold) {
      widget.viewModel.previousMonth();
    } else if (_horizontalDragDelta < -distanceThreshold) {
      widget.viewModel.nextMonth();
    } else if (_horizontalDragDelta > distanceThreshold) {
      widget.viewModel.previousMonth();
    }
    _horizontalDragDelta = 0;
  }

  void _onHorizontalDragCancel() {
    _horizontalDragDelta = 0;
  }

  Future<void> _showAddEventDialog(
    BuildContext context, [
    ExternalCalendarEvent? initialEvent,
  ]) {
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
              initialEvent?.startTime ?? widget.viewModel.selectedDate,
          initialCalendar: widget.viewModel.lastUsedCalendar,
          initialEvent: initialEvent,
          onSave:
              ({
                required String title,
                required String description,
                required DateTime startTime,
                required DateTime endTime,
                required LocalCalendar calendar,
                required bool isAllDay,
              }) {
                widget.viewModel.addEvent(
                  title: title,
                  description: description,
                  startTime: startTime,
                  endTime: endTime,
                  calendar: calendar,
                  isAllDay: isAllDay,
                );
              },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final focusedMonth = widget.viewModel.focusedMonth;
        final selectedDate = widget.viewModel.selectedDate;
        final events = widget.viewModel.selectedDateEvents;
        final firstDay = widget.viewModel.firstDayOfWeek;
        final showWeekNumbers = widget.viewModel.showWeekNumbers;
        final gridDays = _buildMonthGrid(focusedMonth, firstDay);
        final weekdayHeaders = _buildWeekdayLabels(firstDay, l10n);

        return Scaffold(
          appBar: AppBar(
            title: Text(l10n.myCalendar),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: l10n.settings,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => SettingsView(
                        themeViewModel: _themeViewModel,
                        calendarViewModel: widget.viewModel,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddEventDialog(context),
            icon: const Icon(Icons.add),
            label: Text(l10n.newEvent),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onHorizontalDragCancel: _onHorizontalDragCancel,
            child: CustomScrollView(
              slivers: [
                // 1. Month Header (Previous / Next / Today)
                SliverToBoxAdapter(
                  child: MonthHeader(
                    focusedMonth: focusedMonth,
                    onPreviousMonth: widget.viewModel.previousMonth,
                    onNextMonth: widget.viewModel.nextMonth,
                    onToday: widget.viewModel.goToToday,
                  ),
                ),

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
                        Text(
                          DateFormat(
                            'EEEE, MMM d',
                            locale,
                          ).format(selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
                        event: event,
                        onDelete: () => widget.viewModel.deleteEvent(event.id),
                      );
                    },
                  ),

                // Bottom padding so content is never obscured by the FloatingActionButton
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Modal bottom sheet widget for adding new events.
///
/// Disposes its [TextEditingController] and [FocusNode] instances cleanly on exit,
/// and defers keyboard focus until the entrance animation completes to avoid
/// frame drops on Android.
class _AddEventBottomSheet extends StatefulWidget {
  const _AddEventBottomSheet({
    required this.selectedDate,
    required this.initialCalendar,
    this.initialEvent,
    required this.onSave,
  });

  final DateTime selectedDate;
  final LocalCalendar initialCalendar;
  final ExternalCalendarEvent? initialEvent;
  final void Function({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required LocalCalendar calendar,
    required bool isAllDay,
  })
  onSave;

  @override
  State<_AddEventBottomSheet> createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<_AddEventBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final FocusNode _titleFocusNode;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _isAllDay = false;
  late LocalCalendar _selectedCalendar;
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialEvent?.title ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialEvent?.description ?? '',
    );
    _titleFocusNode = FocusNode();
    _selectedCalendar = widget.initialCalendar;
    _isAllDay = widget.initialEvent?.isAllDay ?? false;
    if (widget.initialEvent != null && !_isAllDay) {
      _startTime = TimeOfDay.fromDateTime(widget.initialEvent!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.initialEvent!.endTime);
    }

    // Defer focusing the title TextField until after the bottom sheet's
    // entrance animation completes. This prevents Android's software keyboard
    // from opening mid-transition, which causes severe frame drops and jank.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final route = ModalRoute.of(context);
      if (route != null && route.animation != null) {
        _routeAnimation = route.animation;
        if (_routeAnimation!.isCompleted) {
          _titleFocusNode.requestFocus();
        } else {
          _routeAnimation!.addStatusListener(_handleAnimationStatus);
        }
      }
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted) {
        _titleFocusNode.requestFocus();
      }
      _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_handleAnimationStatus);
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final selectedDateFormatted = DateFormat(
      'EEEE, MMM d, yyyy',
      locale,
    ).format(widget.selectedDate);

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
              l10n.addEvent,
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
              focusNode: _titleFocusNode,
              decoration: InputDecoration(
                labelText: l10n.eventTitle,
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
            DropdownButtonFormField<LocalCalendar>(
              key: const ValueKey('event-calendar-dropdown'),
              initialValue: _selectedCalendar,
              decoration: InputDecoration(
                labelText: l10n.saveToCalendar,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_month),
                helperText: l10n.savedLocallyOnDevice,
              ),
              items: LocalCalendar.all
                  .map(
                    (calendar) => DropdownMenuItem(
                      value: calendar,
                      child: Text(l10n.personalCalendar),
                    ),
                  )
                  .toList(),
              onChanged: (calendar) {
                if (calendar != null) {
                  setState(() => _selectedCalendar = calendar);
                }
              },
            ),
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
                          setState(() => _startTime = picked);
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
                          setState(() => _endTime = picked);
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
                onPressed: () {
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
                  final endDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    _isAllDay ? 0 : _endTime.hour,
                    _isAllDay ? 0 : _endTime.minute,
                  );

                  widget.onSave(
                    title: title,
                    description: _descriptionController.text.trim(),
                    startTime: startDateTime,
                    endTime: endDateTime,
                    calendar: _selectedCalendar,
                    isAllDay: _isAllDay,
                  );

                  Navigator.of(context).pop();
                },
                child: Text(l10n.saveEvent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
