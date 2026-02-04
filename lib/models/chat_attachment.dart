class ChatAttachment {
  final String name;
  final String path;
  final String contextText;
  final DateTime addedAt;

  const ChatAttachment({
    required this.name,
    required this.path,
    required this.contextText,
    required this.addedAt,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'path': path,
        'contextText': contextText,
        'addedAt': addedAt.toIso8601String(),
      };

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    return ChatAttachment(
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      contextText: map['contextText'] ?? '',
      addedAt: DateTime.tryParse(map['addedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
