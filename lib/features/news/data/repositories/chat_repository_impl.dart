// lib/features/news/data/repositories/chat_repository_impl.dart
import 'package:drift/drift.dart';
import '../local/app_database.dart';
import '../../domain/entities/chat_session.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';

class ChatRepositoryImpl implements ChatRepository {
  final AppDatabase _db;

  ChatRepositoryImpl({required AppDatabase db}) : _db = db;

  @override
  Future<List<ChatSession>> getChatSessions() async {
    final query = _db.select(_db.chatSessionsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    
    final rows = await query.get();
    
    return rows.map((row) => ChatSession(
      id: row.id,
      articleId: row.articleId,
      articleTitle: row.articleTitle,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    )).toList();
  }

  @override
  Future<ChatSession?> getChatSession(String sessionId) async {
    final sessionRow = await (_db.select(_db.chatSessionsTable)
          ..where((t) => t.id.equals(sessionId)))
        .getSingleOrNull();

    if (sessionRow == null) return null;

    final messageRows = await (_db.select(_db.chatMessagesTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.asc)]))
        .get();

    return ChatSession(
      id: sessionRow.id,
      articleId: sessionRow.articleId,
      articleTitle: sessionRow.articleTitle,
      createdAt: sessionRow.createdAt,
      updatedAt: sessionRow.updatedAt,
      messages: messageRows.map((m) => ChatMessage(
        role: m.role,
        content: m.content,
      )).toList(),
    );
  }

  @override
  Future<void> saveChatSession(ChatSession session) async {
    await _db.into(_db.chatSessionsTable).insertOnConflictUpdate(
      ChatSessionsTableCompanion(
        id: Value(session.id),
        articleId: Value(session.articleId),
        articleTitle: Value(session.articleTitle),
        createdAt: Value(session.createdAt),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  @override
  Future<void> saveChatMessage(String sessionId, ChatMessage message) async {
    await _db.into(_db.chatMessagesTable).insert(
      ChatMessagesTableCompanion.insert(
        sessionId: sessionId,
        role: message.role,
        content: message.content,
      ),
    );
    
    // Update the session's updatedAt timestamp
    await (_db.update(_db.chatSessionsTable)
          ..where((t) => t.id.equals(sessionId)))
        .write(ChatSessionsTableCompanion(updatedAt: Value(DateTime.now())));
  }

  @override
  Future<void> deleteChatSession(String sessionId) async {
    await (_db.delete(_db.chatSessionsTable)..where((t) => t.id.equals(sessionId))).go();
    await (_db.delete(_db.chatMessagesTable)..where((t) => t.sessionId.equals(sessionId))).go();
  }
  
  @override
  Future<void> deleteLastMessages(String sessionId, int count) async {
    final rows = await (_db.select(_db.chatMessagesTable)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])
          ..limit(count))
        .get();
    
    if (rows.isEmpty) return;
    
    final ids = rows.map((r) => r.id).toList();
    await (_db.delete(_db.chatMessagesTable)
          ..where((t) => t.id.isIn(ids)))
        .go();
  }

  @override
  Future<void> clearAllHistory() async {
    await _db.delete(_db.chatSessionsTable).go();
    await _db.delete(_db.chatMessagesTable).go();
  }
}
