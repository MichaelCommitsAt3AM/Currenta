import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/chat_message.dart';
import '../domain/entities/chat_session.dart';
import '../../../core/providers/providers.dart';

part 'ai_chat_notifier.g.dart';

const int _maxInputChars = 500;
const int _maxHistoryMessages = 7; // latest user + up to 6 prior turns
const int _maxHistoryMessageChars = 1200;

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
  CancelToken? _cancelToken;
  Timer? _throttleTimer;
  String _chunkBuffer = '';

  @override
  AiChatState build(String articleId, String articleTitle) {
    // Clean up any in-flight stream when the provider is disposed.
    ref.onDispose(() {
      _streamSub?.cancel();
      _cancelToken?.cancel('Provider disposed');
      _throttleTimer?.cancel();
    });

    // Load existing messages if any
    _loadMessages();

    return const AiChatState();
  }

  Future<void> _loadMessages() async {
    final repository = ref.read(chatRepositoryProvider);
    final session = await repository.getChatSession(articleId);
    if (session != null && session.messages != null) {
      // Only update messages if the current state is still empty.
      // This prevents overwriting a new message if the user sends one
      // while the initial history is still being fetched from the database.
      if (state.messages.isEmpty) {
        state = state.copyWith(messages: session.messages);
      }
    }
  }

  List<ChatMessage> get messages => state.messages;
  bool get isLoading => state.isLoading;

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    // Avoid concurrent stream requests that can corrupt message ordering.
    if (state.isLoading) return;

    if (trimmed.length > _maxInputChars) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            role: 'model',
            content:
                'The message is too long. Please keep it under $_maxInputChars characters.',
          ),
        ],
      );
      return;
    }

    final userMessage = ChatMessage(role: 'user', content: trimmed);
    final nextMessages = [...state.messages, userMessage];
    state = state.copyWith(
      messages: nextMessages,
      isLoading: true,
    );

    // Save user message
    final repository = ref.read(chatRepositoryProvider);
    if (state.messages.length == 1) {
      await repository.saveChatSession(ChatSession(
        id: articleId,
        articleId: articleId,
        articleTitle: articleTitle,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    await repository.saveChatMessage(articleId, userMessage);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      // Streaming can be buffered under some HTTP/2 adapters; use the default
      // IO adapter for this endpoint to preserve incremental chunk delivery.
      final streamingDio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 0),
        ),
      );
      streamingDio.httpClientAdapter = IOHttpClientAdapter();

      _cancelToken = CancelToken();

      final response = await streamingDio.post<ResponseBody>(
        '${AppConfig.apiBaseUrl}/api/chat',
        data: {
          'article_id': articleId,
          'messages': _buildPayloadMessages(nextMessages)
              .map((m) => m.toJson())
              .toList(),
        },
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            if (session != null)
              'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );

      // Add an initial empty model message to stream into.
      // Use nextMessages here to ensure we don't lose the user prompt if
      // state.messages was somehow reset by a parallel operation.
      state = state.copyWith(
        messages: [...nextMessages, ChatMessage(role: 'model', content: '')],
        isLoading: true,
      );

      final chunkStream = utf8.decoder
          .bind(response.data!.stream)
          // ── #17 Fix: bound the entire stream to 90 seconds ────────────────
          // Dio's receiveTimeout does not apply to streaming responses; without
          // this the await-for could hang indefinitely if the backend stalls.
          .timeout(
            const Duration(seconds: 90),
            onTimeout: (sink) => sink.close(),
          );

      bool receivedContent = false;
      String buffer = '';

      await for (final chunkText in chunkStream) {
        buffer += chunkText;

        int newlineIndex;
        while ((newlineIndex = buffer.indexOf('\n')) != -1) {
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.isEmpty) continue;

          try {
            final Map<String, dynamic> data = jsonDecode(line);

            if (data.containsKey('error')) {
              _updateLastMessage(
                  'Sorry, I encountered an error: ${data['error']}');
              break;
            }

            if (data.containsKey('content')) {
              final String token = data['content'];
              if (token.isEmpty) continue;

              if (!receivedContent) {
                receivedContent = true;
                // Force immediate flush for first token so user sees response start
                state = state.copyWith(
                  messages: [
                    ...state.messages.sublist(0, state.messages.length - 1),
                    state.messages.last.copyWith(content: token),
                  ],
                );
              } else {
                _appendToLastMessage(token);
              }
            } else if (data.containsKey('citations_text')) {
              final String citationsText = data['citations_text'];
              if (citationsText.isNotEmpty) {
                receivedContent = true;
                _throttleTimer?.cancel();
                _chunkBuffer = '';
                _updateLastMessage(citationsText);
              }
            }
          } catch (e) {
            // Ignore individual malformed chunks — log only in debug.
            debugPrint('[Chat] Error parsing chunk: $e');
          }
        }
      }

      // Ensure any remaining buffered chunks are flushed.
      _throttleTimer?.cancel();
      _flushBuffer();

      final trailing = buffer.trim();
      if (trailing.isNotEmpty) {
        try {
          final Map<String, dynamic> data = jsonDecode(trailing);
          if (data.containsKey('error')) {
            _updateLastMessage(
                'Sorry, I encountered an error: ${data['error']}');
          } else if (data.containsKey('content')) {
            final String token = data['content'];
            if (token.isNotEmpty) {
              if (!receivedContent) {
                receivedContent = true;
                state = state.copyWith(
                  messages: [
                    ...state.messages.sublist(0, state.messages.length - 1),
                    state.messages.last.copyWith(content: token),
                  ],
                );
              } else {
                _appendToLastMessage(token);
                _flushBuffer(); // Flush trailing immediately
              }
            }
          } else if (data.containsKey('citations_text')) {
            final String citationsText = data['citations_text'];
            if (citationsText.isNotEmpty) {
              receivedContent = true;
              _throttleTimer?.cancel();
              _chunkBuffer = '';
              _updateLastMessage(citationsText);
            }
          }
        } catch (e) {
          debugPrint('[Chat] Error parsing trailing chunk: $e');
        }
      }

      if (!receivedContent) {
        _updateLastMessage(
            'No response was received. The request may have timed out. Please try again.');
        state = state.copyWith(isLoading: false);
      }

      // Save AI message
      await repository.saveChatMessage(articleId, state.messages.last);
    } catch (e) {
      // Ensure throttled streaming state can't flush into the error message.
      _throttleTimer?.cancel();
      _chunkBuffer = '';

      String errorMessage =
          'Sorry, I encountered an error. Please try again later.';

      if (e is DioException) {
        if (e.type == DioExceptionType.cancel) {
          errorMessage = 'Message stopped.';
        } else {
          final statusCode = e.response?.statusCode;
          final detail = _extractErrorDetail(e.response?.data);

          if (statusCode == 429) {
            errorMessage =
                "You've reached the chat limit. Please wait a moment before sending more messages.";
          } else if (statusCode == 400 && detail != null) {
            if (detail.toLowerCase().contains('too long')) {
              errorMessage =
                  'The message is too long. Please try a shorter question.';
            } else {
              errorMessage = detail;
            }
          } else if (statusCode == 400) {
            errorMessage =
                'The request could not be processed. Please try again.';
          } else if (e.error is AppException) {
            errorMessage = (e.error as AppException).message;
          }
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
      _cancelToken = null;

      // Always stop any pending flush timer and clear buffer so subsequent
      // messages cannot receive stale chunks.
      _throttleTimer?.cancel();
      _throttleTimer = null;
      _chunkBuffer = '';
    }
  }

  void stopGeneration() {
    _cancelToken?.cancel("User stopped generation");
    _cancelToken = null;
    _throttleTimer?.cancel();
    _flushBuffer();
    state = state.copyWith(isLoading: false);
  }

  Future<void> editLastMessage(String newText) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;

    // 1. Stop any current generation
    stopGeneration();

    final msgs = state.messages;
    if (msgs.isEmpty) return;

    int messagesToRemove = 0;
    // Find the last user message and the subsequent messages
    // If last is model, we remove both the model response and the user prompt.
    // If last is user, we remove just the user prompt.
    if (msgs.last.role == 'model') {
      messagesToRemove = 2;
    } else if (msgs.last.role == 'user') {
      messagesToRemove = 1;
    }

    if (messagesToRemove == 0) return;

    // 2. Update local state
    final nextMessages = msgs.sublist(0, msgs.length - messagesToRemove);
    state = state.copyWith(messages: nextMessages);

    // 3. Update repository
    final repository = ref.read(chatRepositoryProvider);
    await repository.deleteLastMessages(articleId, messagesToRemove);

    // 4. Send the new message
    await sendMessage(trimmed);
  }

  void _appendToLastMessage(String chunk) {
    _chunkBuffer += chunk;

    // If we're already waiting to flush, just keep buffering.
    if (_throttleTimer?.isActive ?? false) return;

    // Schedule a flush in 50ms to reduce UI update frequency.
    _throttleTimer = Timer(const Duration(milliseconds: 50), _flushBuffer);
  }

  void _flushBuffer() {
    if (_chunkBuffer.isEmpty) return;

    final msgs = state.messages;
    if (msgs.isEmpty || msgs.last.role != 'model') return;

    state = state.copyWith(
      messages: [
        ...msgs.sublist(0, msgs.length - 1),
        msgs.last.copyWith(content: msgs.last.content + _chunkBuffer),
      ],
    );
    _chunkBuffer = '';
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

  List<ChatMessage> _buildPayloadMessages(List<ChatMessage> messages) {
    final start = messages.length > _maxHistoryMessages
        ? messages.length - _maxHistoryMessages
        : 0;

    final sliced = messages.sublist(start);
    return sliced
        .where((m) => (m.role == 'user' || m.role == 'model'))
        .map((m) {
      final content = m.content;
      final isLatestUser = identical(m, sliced.last) && m.role == 'user';
      final maxLen = isLatestUser ? _maxInputChars : _maxHistoryMessageChars;

      if (content.length <= maxLen) return m;
      return m.copyWith(content: content.substring(0, maxLen));
    }).toList(growable: false);
  }

  String? _extractErrorDetail(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final detail = responseData['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail.trim();
      }
    }

    if (responseData is String && responseData.trim().isNotEmpty) {
      return responseData.trim();
    }

    return null;
  }
}
