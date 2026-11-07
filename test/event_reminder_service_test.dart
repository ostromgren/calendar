import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calendar/data/event_reminder_service.dart';

const _notificationChannel = MethodChannel(
  'dexterous.com/flutter/local_notifications',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('iOS initialization permits deferred notification permissions', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_notificationChannel, (call) async {
          if (call.method == 'initialize') return false;
          return null;
        });
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_notificationChannel, null);
    });

    await expectLater(EventReminderService().initialize(), completes);
  });

  test('dismiss action does not route to the event', () {
    final target = EventReminderTarget(
      eventKey: 'event-1',
      eventId: 'event-1',
      title: 'Planning',
      startTime: DateTime(2026, 10, 24, 9),
    );
    final response = NotificationResponse(
      id: 17,
      actionId: EventReminderService.dismissActionId,
      payload: target.toPayload(),
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
    );

    expect(EventReminderService.targetForResponse(response), isNull);
  });

  test('notification body tap still routes to its event', () {
    final target = EventReminderTarget(
      eventKey: 'event-1',
      eventId: 'event-1',
      title: 'Planning',
      startTime: DateTime(2026, 10, 24, 9),
    );
    final response = NotificationResponse(
      id: 17,
      payload: target.toPayload(),
      notificationResponseType: NotificationResponseType.selectedNotification,
    );

    expect(
      EventReminderService.targetForResponse(response)?.eventId,
      'event-1',
    );
  });
}
