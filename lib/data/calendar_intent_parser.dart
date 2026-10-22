import 'package:calendar/domain/models/external_calendar_event.dart';

/// Parses common RFC 5545 event fields used when opening an .ics invite.
List<ExternalCalendarEvent> parseCalendarFile(String contents) {
  final unfoldedLines = contents
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n');
  final lines = <String>[];
  for (final line in unfoldedLines) {
    if ((line.startsWith(' ') || line.startsWith('\t')) && lines.isNotEmpty) {
      lines[lines.length - 1] += line.substring(1);
    } else {
      lines.add(line);
    }
  }

  final events = <ExternalCalendarEvent>[];
  Map<String, String>? properties;
  for (final line in lines) {
    if (line.toUpperCase() == 'BEGIN:VEVENT') {
      properties = {};
      continue;
    }
    if (line.toUpperCase() == 'END:VEVENT') {
      if (properties != null) {
        final event = _parseEvent(properties);
        if (event != null) events.add(event);
      }
      properties = null;
      continue;
    }
    if (properties == null) continue;

    final separator = line.indexOf(':');
    if (separator < 0) continue;
    final key = line.substring(0, separator).split(';').first.toUpperCase();
    properties[key] = line.substring(separator + 1);
  }

  return events;
}

ExternalCalendarEvent? _parseEvent(Map<String, String> properties) {
  final rawStart = properties['DTSTART'];
  if (rawStart == null) return null;

  final start = _parseDate(rawStart);
  if (start == null) return null;
  final allDay = rawStart.length == 8;
  final rawEnd = properties['DTEND'];
  final parsedEnd = rawEnd == null ? null : _parseDate(rawEnd);
  final end = allDay ? start : parsedEnd ?? start.add(const Duration(hours: 1));

  return ExternalCalendarEvent(
    title: _unescape(properties['SUMMARY'] ?? ''),
    description: _unescape(properties['DESCRIPTION'] ?? ''),
    startTime: start,
    endTime: end,
    isAllDay: allDay,
  );
}

DateTime? _parseDate(String value) {
  final isUtc = value.endsWith('Z');
  final normalized = isUtc ? value.substring(0, value.length - 1) : value;
  final digits = normalized.replaceAll('T', '');
  if (!RegExp(r'^\d{8}(\d{6})?$').hasMatch(digits)) return null;

  final year = int.parse(digits.substring(0, 4));
  final month = int.parse(digits.substring(4, 6));
  final day = int.parse(digits.substring(6, 8));
  final hour = digits.length > 8 ? int.parse(digits.substring(8, 10)) : 0;
  final minute = digits.length > 8 ? int.parse(digits.substring(10, 12)) : 0;
  final second = digits.length > 8 ? int.parse(digits.substring(12, 14)) : 0;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;

  final date = isUtc
      ? DateTime.utc(year, month, day, hour, minute, second)
      : DateTime(year, month, day, hour, minute, second);
  if (date.year != year || date.month != month || date.day != day) return null;
  return isUtc ? date.toLocal() : date;
}

String _unescape(String value) => value
    .replaceAll(r'\n', '\n')
    .replaceAll(r'\N', '\n')
    .replaceAll(r'\,', ',')
    .replaceAll(r'\;', ';')
    .replaceAll(r'\\', r'\');
