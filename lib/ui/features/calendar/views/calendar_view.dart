import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../settings/view_models/theme_view_model.dart';
import '../../settings/views/settings_view.dart';
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
    this.themeViewModel,
  });

  final CalendarViewModel viewModel;
  final ThemeViewModel? themeViewModel;

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late final ThemeViewModel _themeViewModel;

  @override
  void initState() {
    super.initState();
    _themeViewModel = widget.themeViewModel ?? ThemeViewModel();
  }

  /// Generates the ordered 7 weekday labels starting from [firstDay].
  List<String> _buildWeekdayLabels(StartingDayOfWeek firstDay) {
    const defaultHeaders = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final startIndex = (firstDay.dateTimeWeekday - 1) % 7;
    return List.generate(7, (i) => defaultHeaders[(startIndex + i) % 7]);
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
    final daysInMonth =
        DateTime(focusedMonth.year, focusedMonth.month + 1, 0).day;
    final totalCells = (leadingDays + daysInMonth) > 35 ? 42 : 35;

    return List.generate(
      totalCells,
      (index) => DateTime(
        startDate.year,
        startDate.month,
        startDate.day + index,
      ),
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
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSelected = date.year == selectedDate.year &&
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

  void _showAddEventDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _AddEventBottomSheet(
          selectedDate: widget.viewModel.selectedDate,
          onSave: ({
            required String title,
            required String description,
            required DateTime startTime,
            required DateTime endTime,
          }) {
            widget.viewModel.addEvent(
              title: title,
              description: description,
              startTime: startTime,
              endTime: endTime,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        final weekdayHeaders = _buildWeekdayLabels(firstDay);

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Calendar'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
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
            label: const Text('New Event'),
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
                                'W#',
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

                const SliverToBoxAdapter(
                  child: SizedBox(height: 6),
                ),

                // 3. Calendar Grid (7 columns, or 8 with week numbers)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  sliver: SliverGrid(
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: showWeekNumbers ? 8 : 7,
                      childAspectRatio: showWeekNumbers ? 1.05 : 1.2,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (showWeekNumbers) {
                          final row = index ~/ 8;
                          final col = index % 8;

                          if (col == 0) {
                            final thursdayOffset = firstDay ==
                                    StartingDayOfWeek.sunday
                                ? 4
                                : (firstDay == StartingDayOfWeek.saturday
                                    ? 5
                                    : 3);
                            final weekNumber = _getIsoWeekNumber(
                              gridDays[row * 7 + thursdayOffset],
                            );
                            return WeekNumberCell(weekNumber: weekNumber);
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

                const SliverToBoxAdapter(
                  child: Divider(height: 16),
                ),

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
                          DateFormat('EEEE, MMM d').format(selectedDate),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${events.length} ${events.length == 1 ? 'event' : 'events'}',
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
                              'No events scheduled',
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
                const SliverToBoxAdapter(
                  child: SizedBox(height: 80),
                ),
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
    required this.onSave,
  });

  final DateTime selectedDate;
  final void Function({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
  }) onSave;

  @override
  State<_AddEventBottomSheet> createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<_AddEventBottomSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final FocusNode _titleFocusNode;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  Animation<double>? _routeAnimation;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _titleFocusNode = FocusNode();

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
    final selectedDateFormatted =
        DateFormat('EEEE, MMM d, yyyy').format(widget.selectedDate);

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
              'Add Event',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'For $selectedDateFormatted',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              decoration: const InputDecoration(
                labelText: 'Event Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.event),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule),
                    label: Text('Start: ${_startTime.format(context)}'),
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
                    label: Text('End: ${_endTime.format(context)}'),
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
                    _startTime.hour,
                    _startTime.minute,
                  );
                  final endDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    _endTime.hour,
                    _endTime.minute,
                  );

                  widget.onSave(
                    title: title,
                    description: _descriptionController.text.trim(),
                    startTime: startDateTime,
                    endTime: endDateTime,
                  );

                  Navigator.of(context).pop();
                },
                child: const Text('Save Event'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
