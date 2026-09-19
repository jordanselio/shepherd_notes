enum AppointmentType { individual, group }

enum AppointmentKind { bibleStudy, event }

enum RecurrenceType { none, weekly, custom }

class Appointment {
  final int? id;
  final String name;
  final AppointmentType type;
  final AppointmentKind kind;
  final RecurrenceType recurrence;
  final String? dayOfWeek;
  final String time;
  final String endTime;
  final String? location;
  final String? startDate;
  final int? groupSize;
  final bool isDeleted;

  Appointment({
    this.id,
    required this.name,
    required this.type,
    this.kind = AppointmentKind.bibleStudy,
    this.recurrence = RecurrenceType.weekly,
    this.dayOfWeek,
    required this.time,
    required this.endTime,
    this.location,
    this.startDate,
    this.groupSize,
    this.isDeleted = false,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'kind': kind.name,
      'recurrence': recurrence.name,
      'dayOfWeek': dayOfWeek,
      'time': time,
      'endTime': endTime,
      'location': location,
      'startDate': startDate,
      'groupSize': groupSize,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Appointment.fromMap(Map<String, Object?> map) {
    return Appointment(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: AppointmentType.values.byName(map['type'] as String),
      kind: AppointmentKind.values.byName(
        (map['kind'] as String?) ?? 'bibleStudy',
      ),
      recurrence: RecurrenceType.values.byName(
        (map['recurrence'] as String?) ?? 'weekly',
      ),
      dayOfWeek: map['dayOfWeek'] as String?,
      time: map['time'] as String,
      endTime: map['endTime'] as String,
      location: map['location'] as String?,
      startDate: map['startDate'] as String?,
      groupSize: map['groupSize'] as int?,
      isDeleted: ((map['isDeleted'] as int?) ?? 0) == 1,
    );
  }

  Appointment copyWith({
    int? id,
    String? name,
    AppointmentType? type,
    AppointmentKind? kind,
    RecurrenceType? recurrence,
    String? dayOfWeek,
    String? time,
    String? endTime,
    String? location,
    String? startDate,
    int? groupSize,
    bool? isDeleted,
  }) {
    return Appointment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      kind: kind ?? this.kind,
      recurrence: recurrence ?? this.recurrence,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      groupSize: groupSize ?? this.groupSize,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
