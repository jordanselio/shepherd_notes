class Task {
  final int? id;
  final String title;
  final String? dueDate; // ISO date, yyyy-MM-dd; null = no date
  final int? appointmentId; // null = General
  final DateTime? completedAt; // null = open
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    this.id,
    required this.title,
    this.dueDate,
    this.appointmentId,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDone => completedAt != null;

  Task copyWith({
    String? title,
    String? dueDate,
    bool clearDueDate = false,
    int? appointmentId,
    bool clearAppointmentId = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      appointmentId: clearAppointmentId
          ? null
          : (appointmentId ?? this.appointmentId),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'dueDate': dueDate,
      'appointmentId': appointmentId,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      dueDate: map['dueDate'] as String?,
      appointmentId: map['appointmentId'] as int?,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
