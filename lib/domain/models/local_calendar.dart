/// A calendar stored locally on this device.
class LocalCalendar {
  const LocalCalendar({required this.id, required this.name});

  final String id;
  final String name;

  static const personal = LocalCalendar(id: 'personal', name: 'Personal');
  static const all = [personal];

  static LocalCalendar fromId(String id) {
    return all.firstWhere(
      (calendar) => calendar.id == id,
      orElse: () => personal,
    );
  }
}
