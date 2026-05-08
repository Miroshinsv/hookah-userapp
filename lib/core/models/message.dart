class ChatMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String? ?? '',
        senderId: json['senderId'] as String? ?? '',
        senderRole: json['senderRole'] as String? ?? '',
        text: json['text'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '',
      );
}
