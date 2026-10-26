import 'package:flutter/material.dart';

/// A user-created event category belonging to one local calendar.
class EventCategory {
  const EventCategory({
    required this.id,
    required this.calendarId,
    required this.name,
    required this.color,
  });

  final String id;
  final String calendarId;
  final String name;
  final Color color;

  Map<String, Object> toJson() => {
    'id': id,
    'calendarId': calendarId,
    'name': name,
    'color': color.toARGB32(),
  };

  factory EventCategory.fromJson(Map<String, dynamic> json) => EventCategory(
    id: json['id'] as String,
    calendarId: json['calendarId'] as String,
    name: json['name'] as String,
    color: Color(json['color'] as int),
  );
}
