import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../domain/models/calendar_event.dart';
import '../domain/models/event_category.dart';
import '../domain/models/recurrence_frequency.dart';
import 'calendar_intent_parser.dart';

class ImportedCalendar {
  const ImportedCalendar({
    required this.name,
    required this.events,
    required this.categories,
  });

  final String? name;
  final List<CalendarEvent> events;
  final List<EventCategory> categories;
}

class CalendarIcsService {
  const CalendarIcsService();

  String exportCalendar({
    required String name,
    required String calendarId,
    required Iterable<CalendarEvent> events,
    required Iterable<EventCategory> categories,
    DateTime? generatedAt,
  }) {
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final timestamp = _formatDateTime((generatedAt ?? DateTime.now()).toUtc());
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Calendar App//Calendar//EN',
      'CALSCALE:GREGORIAN',
      'X-WR-CALNAME:${_escapeText(name)}',
    ];

    for (final event in events.where(
      (event) => event.calendarId == calendarId,
    )) {
      final category = categoriesById[event.categoryId];
      lines.addAll([
        'BEGIN:VEVENT',
        'UID:${_escapeText(event.id)}@calendar.local',
        'DTSTAMP:$timestamp',
        if (event.isAllDay) ...[
          'DTSTART;VALUE=DATE:${_formatDate(event.startTime)}',
          'DTEND;VALUE=DATE:${_formatDate(event.endTime)}',
        ] else ...[
          'DTSTART:${_formatDateTime(event.startTime.toUtc())}',
          'DTEND:${_formatDateTime(event.endTime.toUtc())}',
        ],
        if (event.recurrenceFrequency != null) _recurrenceRule(event),
        if (event.excludedOccurrenceDates.isNotEmpty) _excludedDates(event),
        'SUMMARY:${_escapeText(event.title)}',
        if (event.description.isNotEmpty)
          'DESCRIPTION:${_escapeText(event.description)}',
        if (category != null) ...[
          'CATEGORIES:${_escapeText(category.name)}',
          'X-APP-CATEGORY-COLOR:#${(category.color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
        ],
        'END:VEVENT',
      ]);
    }
    lines.add('END:VCALENDAR');
    return '${lines.map(_foldLine).join('\r\n')}\r\n';
  }

  ImportedCalendar importCalendar(String contents) {
    if (!contents.toUpperCase().contains('BEGIN:VCALENDAR')) {
      throw const FormatException(
        'The selected file is not an iCalendar file.',
      );
    }
    final externalEvents = parseCalendarFile(contents);
    if (externalEvents.isEmpty) {
      throw const FormatException('The calendar file contains no events.');
    }

    final calendarName = _readCalendarName(contents);
    final categoriesByName = <String, EventCategory>{};
    final events = <CalendarEvent>[];
    for (var index = 0; index < externalEvents.length; index++) {
      final external = externalEvents[index];
      EventCategory? category;
      final categoryName = external.categoryName?.trim();
      if (categoryName != null && categoryName.isNotEmpty) {
        category = categoriesByName.putIfAbsent(categoryName, () {
          final color = external.categoryColor == null
              ? Colors.blue
              : Color(external.categoryColor!);
          return EventCategory(
            id: 'category-import-$index',
            calendarId: '',
            name: categoryName,
            color: color,
          );
        });
      }
      events.add(
        CalendarEvent(
          id: 'import-${DateTime.now().microsecondsSinceEpoch}-$index',
          title: external.title,
          description: external.description,
          startTime: external.startTime,
          endTime: external.endTime,
          isAllDay: external.isAllDay,
          categoryId: category?.id,
          color: category?.color ?? Colors.blue,
          recurrenceFrequency: external.recurrenceFrequency,
          recurrenceEndDate: external.recurrenceEndDate,
          excludedOccurrenceDates: external.excludedOccurrenceDates,
        ),
      );
    }
    return ImportedCalendar(
      name: calendarName,
      events: events,
      categories: List.unmodifiable(categoriesByName.values),
    );
  }

  String? _readCalendarName(String contents) {
    final lines = contents
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final unfolded = <String>[];
    for (final line in lines) {
      if ((line.startsWith(' ') || line.startsWith('\t')) &&
          unfolded.isNotEmpty) {
        unfolded[unfolded.length - 1] += line.substring(1);
      } else {
        unfolded.add(line);
      }
    }
    for (final line in unfolded) {
      if (line.toUpperCase().startsWith('X-WR-CALNAME:')) {
        return line
            .substring(line.indexOf(':') + 1)
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\,', ',')
            .replaceAll(r'\;', ';')
            .replaceAll(r'\\', r'\');
      }
    }
    return null;
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  String _formatDateTime(DateTime value) =>
      '${_formatDate(value)}T'
      '${value.hour.toString().padLeft(2, '0')}'
      '${value.minute.toString().padLeft(2, '0')}'
      '${value.second.toString().padLeft(2, '0')}Z';

  String _recurrenceRule(CalendarEvent event) {
    final frequency = event.recurrenceFrequency!;
    final interval = frequency == RecurrenceFrequency.monthly
        ? 1
        : frequency.weekInterval;
    final endDate = event.recurrenceEndDate;
    final until = endDate == null
        ? ''
        : ';UNTIL=${event.isAllDay ? _formatDate(endDate) : _formatDateTime(DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toUtc())}';
    return 'RRULE:FREQ=${frequency == RecurrenceFrequency.monthly ? 'MONTHLY' : 'WEEKLY'}'
        ';INTERVAL=$interval$until';
  }

  String _excludedDates(CalendarEvent event) {
    final values = event.excludedOccurrenceDates.map((key) {
      final date = DateTime.parse(key);
      final occurrence = event.isAllDay
          ? date
          : DateTime(
              date.year,
              date.month,
              date.day,
              event.startTime.hour,
              event.startTime.minute,
              event.startTime.second,
            ).toUtc();
      return event.isAllDay
          ? _formatDate(occurrence)
          : _formatDateTime(occurrence);
    });
    return 'EXDATE${event.isAllDay ? ';VALUE=DATE' : ''}:${values.join(',')}';
  }

  String _escapeText(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('\r\n', r'\n')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');

  String _foldLine(String line) {
    final chunks = <String>[];
    final current = StringBuffer();
    var byteCount = 0;
    for (final rune in line.runes) {
      final character = String.fromCharCode(rune);
      final characterBytes = utf8.encode(character).length;
      if (byteCount + characterBytes > 75) {
        chunks.add(current.toString());
        current
          ..clear()
          ..write(' ');
        byteCount = 1;
      }
      current.write(character);
      byteCount += characterBytes;
    }
    chunks.add(current.toString());
    return chunks.join('\r\n');
  }
}
