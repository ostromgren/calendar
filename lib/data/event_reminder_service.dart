import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../domain/models/calendar_event.dart';
import '../domain/models/recurrence_frequency.dart';

class EventReminderTarget {
  const EventReminderTarget({
    required this.eventKey,
    required this.title,
    required this.startTime,
    this.eventId,
    this.minutesBefore,
  });

  final String eventKey;
  final String title;
  final DateTime startTime;
  final String? eventId;
  final int? minutesBefore;

  String toPayload() => jsonEncode({
    'eventKey': eventKey,
    'eventId': eventId,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'minutesBefore': minutesBefore,
  });

  static EventReminderTarget? fromPayload(String? payload) {
    if (payload == null) return null;
    try {
      final values = jsonDecode(payload) as Map<String, dynamic>;
      return EventReminderTarget(
        eventKey: values['eventKey'] as String,
        eventId: values['eventId'] as String?,
        title: values['title'] as String,
        startTime: DateTime.parse(values['startTime'] as String),
        minutesBefore: (values['minutesBefore'] as num?)?.toInt(),
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}

class EventReminderService {
  static const dismissActionId = 'dismiss_reminder';

  EventReminderService({
    FlutterLocalNotificationsPlugin? plugin,
    this.dismissActionTitle = 'Dismiss',
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  final String dismissActionTitle;
  final ValueNotifier<EventReminderTarget?> target =
      ValueNotifier<EventReminderTarget?>(null);
  Future<void>? _initialization;

  static EventReminderTarget? targetForResponse(NotificationResponse response) {
    if (response.actionId == dismissActionId) return null;
    return EventReminderTarget.fromPayload(response.payload);
  }

  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }

    final initialized = await _plugin.initialize(
      settings: InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
          notificationCategories: [
            DarwinNotificationCategory(
              'event_reminders',
              actions: [
                DarwinNotificationAction.plain(
                  dismissActionId,
                  dismissActionTitle,
                  options: {DarwinNotificationActionOption.destructive},
                ),
              ],
            ),
          ],
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        if (response.actionId == dismissActionId) {
          final notificationId = response.id;
          if (notificationId != null) {
            unawaited(_plugin.cancel(id: notificationId));
          }
          return;
        }
        target.value = targetForResponse(response);
      },
      onDidReceiveBackgroundNotificationResponse:
          EventReminderService._handleBackgroundNotificationResponse,
    );
    if (initialized == null) {
      throw StateError('Could not initialize event reminders.');
    }

    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      final response = launchDetails?.notificationResponse;
      if (response != null) target.value = targetForResponse(response);
    }
  }

  Future<EventReminderTarget?> reminderForEvent(CalendarEvent event) async {
    await initialize();
    final eventKey = keyForEvent(event);
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      final reminderTarget = EventReminderTarget.fromPayload(
        notification.payload,
      );
      if (reminderTarget != null &&
          (reminderTarget.eventKey == eventKey ||
              reminderTarget.title == event.title) &&
          reminderTarget.startTime.isAtSameMomentAs(event.startTime)) {
        return reminderTarget;
      }
    }
    return null;
  }

  Future<void> scheduleEvent({
    required CalendarEvent event,
    required int minutesBefore,
    required String body,
  }) async {
    await initialize();
    final eventKey = keyForEvent(event);
    final occurrences = _upcomingOccurrences(event)
        .where(
          (occurrence) => occurrence
              .subtract(Duration(minutes: minutesBefore))
              .isAfter(DateTime.now()),
        )
        .toList(growable: false);
    if (occurrences.isEmpty) return;

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final notificationsGranted = await android
          .requestNotificationsPermission();
      if (notificationsGranted == false) {
        throw StateError('Notification permission was not granted.');
      }
      if (await android.canScheduleExactNotifications() != true &&
          await android.requestExactAlarmsPermission() != true) {
        throw StateError('Exact alarm permission was not granted.');
      }
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null &&
        await ios.requestPermissions(alert: true, badge: true, sound: true) !=
            true) {
      throw StateError('Notification permission was not granted.');
    }

    for (final occurrence in occurrences) {
      final dueTime = occurrence.subtract(Duration(minutes: minutesBefore));

      final occurrenceId = event.isDeviceCalendarEvent
          ? null
          : event.recurrenceFrequency == null
          ? event.id
          : '${event.id}::${event.occurrenceDateKey(occurrence)}';
      final notificationTarget = EventReminderTarget(
        eventKey: eventKey,
        eventId: occurrenceId,
        title: event.title,
        startTime: occurrence,
        minutesBefore: minutesBefore,
      );
      final notificationId = _notificationId(
        '$eventKey|${occurrence.toUtc().microsecondsSinceEpoch}',
      );

      await _plugin.zonedSchedule(
        id: notificationId,
        title: event.title,
        body: body,
        scheduledDate: tz.TZDateTime.from(dueTime.toUtc(), tz.UTC),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'event_reminders',
            'Event reminders',
            channelDescription: 'Notifications before calendar events',
            importance: Importance.high,
            priority: Priority.high,
            actions: [
              AndroidNotificationAction(
                dismissActionId,
                dismissActionTitle,
                cancelNotification: true,
              ),
            ],
          ),
          iOS: DarwinNotificationDetails(categoryIdentifier: 'event_reminders'),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: notificationTarget.toPayload(),
      );
    }
  }

  @pragma('vm:entry-point')
  static void _handleBackgroundNotificationResponse(
    NotificationResponse response,
  ) {
    final notificationId = response.id;
    if (response.actionId == EventReminderService.dismissActionId &&
        notificationId != null) {
      unawaited(FlutterLocalNotificationsPlugin().cancel(id: notificationId));
    }
  }

  Future<void> cancelEvent(
    String eventKey, {
    String? eventId,
    DateTime? occurrenceStartTime,
  }) async {
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      final reminderTarget = EventReminderTarget.fromPayload(
        notification.payload,
      );
      if (reminderTarget?.eventKey != eventKey) continue;
      if (eventId != null && reminderTarget?.eventId != eventId) continue;
      if (occurrenceStartTime != null &&
          reminderTarget?.startTime.isAtSameMomentAs(occurrenceStartTime) !=
              true) {
        continue;
      }
      await _plugin.cancel(id: notification.id);
    }
  }

  static String keyForEvent(CalendarEvent event) {
    if (!event.isDeviceCalendarEvent) {
      final occurrenceSeparator = event.id.indexOf('::');
      return occurrenceSeparator < 0
          ? event.id
          : event.id.substring(0, occurrenceSeparator);
    }
    return 'device|${event.calendarId}|${event.title}|'
        '${event.startTime.toUtc().microsecondsSinceEpoch}';
  }

  Iterable<DateTime> _upcomingOccurrences(CalendarEvent event) sync* {
    final frequency = event.recurrenceFrequency;
    if (frequency == null) {
      yield event.startTime;
      return;
    }

    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 366));
    var firstIndex = 0;
    if (event.startTime.isBefore(now)) {
      firstIndex = switch (frequency) {
        RecurrenceFrequency.monthly =>
          ((now.year - event.startTime.year) * 12 +
                  now.month -
                  event.startTime.month -
                  1)
              .clamp(0, 100000)
              .toInt(),
        _ =>
          (now.difference(event.startTime).inDays ~/
                      (frequency.weekInterval * 7) -
                  1)
              .clamp(0, 100000)
              .toInt(),
      };
    }

    for (var offset = 0; offset < 64; offset++) {
      final occurrence = event.occurrenceStart(firstIndex + offset);
      if (occurrence.isAfter(horizon)) break;
      final recurrenceEnd = event.recurrenceEndDate;
      if (recurrenceEnd != null &&
          occurrence.isAfter(
            DateTime(
              recurrenceEnd.year,
              recurrenceEnd.month,
              recurrenceEnd.day,
              23,
              59,
              59,
            ),
          )) {
        break;
      }
      yield occurrence;
    }
  }

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
