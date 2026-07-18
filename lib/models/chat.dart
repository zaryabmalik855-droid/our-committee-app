class ChatMessage {
  final String committeeId;
  final String senderName;
  final String senderRole; // 'member' or 'manager'
  final String message;
  final DateTime timestamp;

  ChatMessage({
    required this.committeeId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    required this.timestamp,
  });
}
