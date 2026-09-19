class Session {
  final int? id;
  final int appointmentId;
  final String date; // ISO date, yyyy-MM-dd
  final String time; // "HH:mm"
  final String? passageTopic;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Session({
    this.id,
    required this.appointmentId,
    required this.date,
    required this.time,
    this.passageTopic,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  DateTime get dateTime => DateTime.parse(date);

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'date': date,
      'time': time,
      'passageTopic': passageTopic,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Session.fromMap(Map<String, Object?> map) {
    return Session(
      id: map['id'] as int?,
      appointmentId: map['appointmentId'] as int,
      date: map['date'] as String,
      time: map['time'] as String,
      passageTopic: map['passageTopic'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
