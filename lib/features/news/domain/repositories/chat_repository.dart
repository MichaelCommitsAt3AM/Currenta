// lib/features/news/domain/repositories/chat_repository.dart
import '../entities/chat_session.dart';
import '../entities/chat_message.dart';

abstract class ChatRepository {
  Future<List<ChatSession>> getChatSessions();
  Future<ChatSession?> getChatSession(String sessionId);
  Future<void> saveChatSession(ChatSession session);
  Future<void> saveChatMessage(String sessionId, ChatMessage message);
  Future<void> deleteChatSession(String sessionId);
  Future<void> deleteLastMessages(String sessionId, int count);
  Future<void> clearAllHistory();
}
