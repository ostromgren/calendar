/// A calendar stored locally on this device.
class LocalCalendar {
  const LocalCalendar({required this.id, required this.name});

  final String id;
  final String name;

  static const personal = LocalCalendar(id: 'personal', name: 'Personal');

  Map<String, Object> toJson() => {'id': id, 'name': name};

  factory LocalCalendar.fromJson(Map<String, dynamic> json) =>
      LocalCalendar(id: json['id'] as String, name: json['name'] as String);
}
