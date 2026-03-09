class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  ChatMessage copyWith({String? role, String? content}) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

