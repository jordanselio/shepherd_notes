class PrayerRequest {
  final int? id;
  final int? appointmentId;
  final int? sessionId;
  final String content;
  final bool isAnswered;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final String? answeredNote;

  PrayerRequest({
    this.id,
    this.appointmentId,
    this.sessionId,
    required this.content,
    required this.isAnswered,
    required this.createdAt,
    this.answeredAt,
    this.answeredNote,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'appointmentId': appointmentId,
      'sessionId': sessionId,
      'content': content,
      'isAnswered': isAnswered ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'answeredAt': answeredAt?.toIso8601String(),
      'answeredNote': answeredNote,
    };
  }

  factory PrayerRequest.fromMap(Map<String, Object?> map) {
    return PrayerRequest(
      id: map['id'] as int?,
      appointmentId: map['appointmentId'] as int?,
      sessionId: map['sessionId'] as int?,
      content: map['content'] as String,
      isAnswered: (map['isAnswered'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      answeredAt: map['answeredAt'] != null
          ? DateTime.parse(map['answeredAt'] as String)
          : null,
      answeredNote: map['answeredNote'] as String?,
    );
  }
}
