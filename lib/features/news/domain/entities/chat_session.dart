// lib/features/news/domain/entities/chat_session.dart
import 'chat_message.dart';

class ChatSession {
  final String id;
  final String articleId;
  final String articleTitle;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ChatMessage>? messages;

  const ChatSession({
    required this.id,
    required this.articleId,
    required this.articleTitle,
    required this.createdAt,
    required this.updatedAt,
    this.messages,
  });
}
