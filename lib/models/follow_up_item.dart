class FollowUpItem {
  final int? id;
  final int sessionId;
  final String content;
  final bool isDone;

  FollowUpItem({
    this.id,
    required this.sessionId,
    required this.content,
    this.isDone = false,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'content': content,
      'isDone': isDone ? 1 : 0,
    };
  }

  factory FollowUpItem.fromMap(Map<String, Object?> map) {
    return FollowUpItem(
      id: map['id'] as int?,
      sessionId: map['sessionId'] as int,
      content: map['content'] as String,
      isDone: (map['isDone'] as int) == 1,
    );
  }
}
