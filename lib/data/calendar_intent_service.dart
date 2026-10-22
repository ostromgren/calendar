import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:calendar/data/calendar_intent_parser.dart';
import 'package:calendar/data/calendar_file_reader_stub.dart'
    if (dart.library.io) 'package:calendar/data/calendar_file_reader_io.dart'
    as calendar_file;
import 'package:calendar/domain/models/external_calendar_event.dart';

class CalendarIntentFailure {
  const CalendarIntentFailure(this.message, {this.details});

  final String message;
  final String? details;
}

/// Receives native calendar create requests and .ics file-open requests.
class CalendarIntentService extends ChangeNotifier {
  static const _channel = MethodChannel('calendar/native_intents');
  final List<ExternalCalendarEvent> _pendingEvents = [];
  CalendarIntentFailure? _error;

  CalendarIntentService({this.executableArguments = const []}) {
    if (!kIsWeb) {
      _channel.setMethodCallHandler(_handleNativeCall);
      unawaited(_loadPendingEvents());
    }
  }

  final List<String> executableArguments;
  bool get hasPendingEvents => _pendingEvents.isNotEmpty;

  ExternalCalendarEvent takeNextEvent() => _pendingEvents.removeAt(0);

  CalendarIntentFailure? takeError() {
    final error = _error;
    _error = null;
    return error;
  }

  Future<void> _loadPendingEvents() async {
    try {
      final pending = await _channel.invokeListMethod<Object?>(
        'takePendingEvents',
      );
      if (pending != null) {
        for (final item in pending) {
          if (item is Map) _addPayload(Map<Object?, Object?>.from(item));
        }
      }
    } on MissingPluginException {
      // Platforms without native association support have no pending request.
    } on PlatformException catch (error) {
      _reportError(
        CalendarIntentFailure(
          'calendarFileReadError',
          details: error.message ?? '',
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.windows) {
      for (final argument in executableArguments) {
        if (argument.toLowerCase().endsWith('.ics')) {
          _addPayload({'kind': 'file', 'path': argument});
        }
      }
    }
  }

  Future<Object?> _handleNativeCall(MethodCall call) async {
    if (call.method == 'incomingCalendarRequest' && call.arguments is Map) {
      _addPayload(Map<Object?, Object?>.from(call.arguments as Map));
    }
    return null;
  }

  void _addPayload(Map<Object?, Object?> payload) {
    final kind = payload['kind'];
    if (kind == 'error') {
      _reportError(
        CalendarIntentFailure(
          payload['code'] as String? ?? 'calendarFileReadError',
          details: payload['details'] as String? ?? '',
        ),
      );
      return;
    }
    if (kind == 'file' && payload['path'] is String) {
      unawaited(_readFile(payload['path']! as String));
      return;
    }
    if (kind == 'ics' && payload['contents'] is String) {
      _addCalendarFile(payload['contents']! as String);
      return;
    }
    if (kind != 'event') return;

    final start = _readDate(payload['startTime']);
    if (start == null) return;
    final allDay = payload['allDay'] == true;
    final end =
        _readDate(payload['endTime']) ??
        (allDay ? start : start.add(const Duration(hours: 1)));
    _pendingEvents.add(
      ExternalCalendarEvent(
        title: payload['title'] as String? ?? '',
        description: payload['description'] as String? ?? '',
        startTime: start,
        endTime: end,
        isAllDay: allDay,
      ),
    );
    notifyListeners();
  }

  DateTime? _readDate(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  Future<void> _readFile(String path) async {
    try {
      _addCalendarFile(await calendar_file.readCalendarFile(path));
    } on calendar_file.CalendarFileReadException catch (error) {
      _reportError(
        CalendarIntentFailure('calendarFileReadError', details: error.message),
      );
    }
  }

  void _addCalendarFile(String contents) {
    final events = parseCalendarFile(contents);
    if (events.isEmpty) {
      _reportError(const CalendarIntentFailure('invalidCalendarFile'));
      return;
    }
    _pendingEvents.addAll(events);
    notifyListeners();
  }

  void _reportError(CalendarIntentFailure error) {
    _error = error;
    notifyListeners();
  }
}
