class ChatMessage {
  final String role;
  final String content;

  /// Number of web sources the assistant consulted for this message, when it
  /// used Google Search grounding. Null means the model answered without
  /// searching (or this is a user message).
  final int? searchSourceCount;

  ChatMessage({
    required this.role,
    required this.content,
    this.searchSourceCount,
  });

  ChatMessage copyWith({String? role, String? content, int? searchSourceCount}) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      searchSourceCount: searchSourceCount ?? this.searchSourceCount,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      searchSourceCount: json['search_source_count'] as int?,
    );
  }

  // Only role/content are sent to the backend; it ignores extra fields anyway.
  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}
