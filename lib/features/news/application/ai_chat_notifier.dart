import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/chat_session.dart';
import '../../../core/providers/providers.dart';

part 'ai_chat_notifier.g.dart';

// ── State ─────────────────────────────────────────────────────────────────────
// Using a proper state class instead of plain instance fields so Riverpod
// can observe loading state and widget rebuilds are correct.

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.isLoading = false,
  });

  final List<ChatMessage> messages;
  final bool isLoading;

  AiChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
  }) =>
      AiChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

@riverpod
class AiChatNotifier extends _$AiChatNotifier {
  // Keep a reference to the active stream subscription so we can cancel it if
  // the user navigates away mid-stream (provider gets disposed).
  StreamSubscription<String>? _streamSub;

  @override
  AiChatState build(String articleId, String articleTitle) {
    // Clean up any in-flight stream when the provider is disposed.
    ref.onDispose(() => _streamSub?.cancel());
    
    // Load existing messages if any
    _loadMessages();
    
    return const AiChatState();
  }

  Future<void> _loadMessages() async {
    final repository = ref.read(chatRepositoryProvider);
    final session = await repository.getChatSession(articleId);
    if (session != null && session.messages != null) {
      state = state.copyWith(messages: session.messages);
    }
  }

  List<ChatMessage> get messages => state.messages;
  bool get isLoading => state.isLoading;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(role: 'user', content: text);
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      isLoading: true,
    );

    // Save user message
    final repository = ref.read(chatRepositoryProvider);
    if (state.messages.length == 1 && this.articleTitle != null) {
      await repository.saveChatSession(ChatSession(
        id: this.articleId,
        articleId: this.articleId,
        articleTitle: this.articleTitle!,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    await repository.saveChatMessage(this.articleId, userMessage);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final response = await DioClient.instance.dio.post<ResponseBody>(
        '${AppConfig.apiBaseUrl}/api/chat',
        data: {
          'article_id': articleId,
          'messages': state.messages.map((m) => m.toJson()).toList(),
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );

      // Add an initial empty model message to stream into and clear the
      // loading flag so the typing indicator is replaced by the bubble.
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(role: 'model', content: '')],
        isLoading: false,
      );

      final lineStream = utf8.decoder
          .bind(response.data!.stream)
          .transform(const LineSplitter())
          // ── #17 Fix: bound the entire stream to 90 seconds ────────────────
          // Dio's receiveTimeout does not apply to streaming responses; without
          // this the await-for could hang indefinitely if the backend stalls.
          .timeout(
            const Duration(seconds: 90),
            onTimeout: (sink) => sink.close(),
          );

      bool receivedContent = false;
      await for (final line in lineStream) {
        if (line.trim().isEmpty) continue;

        try {
          final Map<String, dynamic> data = jsonDecode(line);

          if (data.containsKey('error')) {
            _updateLastMessage('Sorry, I encountered an error: ${data['error']}');
            break;
          }

          if (data.containsKey('content')) {
            final String chunk = data['content'];
            _appendToLastMessage(chunk);
            receivedContent = true;
          }
        } catch (e) {
          // Ignore individual malformed chunks — log only in debug.
          debugPrint('[Chat] Error parsing chunk: $e');
        }
      }

      if (!receivedContent) {
        _updateLastMessage(
            'No response was received. The request may have timed out. Please try again.');
      }
      
      // Save AI message
      await repository.saveChatMessage(articleId, state.messages.last);
    } catch (e) {
      String errorMessage =
          'Sorry, I encountered an error. Please try again later.';

      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 429) {
          errorMessage =
              "You've reached the chat limit. Please wait a moment before sending more messages.";
        } else if (statusCode == 400) {
          errorMessage =
              'The message is too long. Please try a shorter question.';
        } else if (e.error is AppException) {
          errorMessage = (e.error as AppException).message;
        }
      }

      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(role: 'model', content: errorMessage),
        ],
      );
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _appendToLastMessage(String chunk) {
    final msgs = state.messages;
    if (msgs.isEmpty || msgs.last.role != 'model') return;
    state = state.copyWith(
      messages: [
        ...msgs.sublist(0, msgs.length - 1),
        msgs.last.copyWith(content: msgs.last.content + chunk),
      ],
    );
  }

  void _updateLastMessage(String content) {
    final msgs = state.messages;
    if (msgs.isEmpty) return;
    state = state.copyWith(
      messages: [
        ...msgs.sublist(0, msgs.length - 1),
        msgs.last.copyWith(content: content),
      ],
    );
  }
}
