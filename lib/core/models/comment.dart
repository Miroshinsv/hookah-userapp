class Comment {
  final String commentId;
  final String entityType;
  final String entityId;
  final String userId;
  final String text;
  final DateTime? createdAt;

  Comment({
    required this.commentId,
    required this.entityType,
    required this.entityId,
    required this.userId,
    required this.text,
    this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        commentId: json['commentId'] as String,
        entityType: json['entityType'] as String,
        entityId: json['entityId'] as String,
        userId: json['userId'] as String,
        text: json['text'] as String,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );
}
