import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/dio_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_exception.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/chat_message.dart';

part 'ai_chat_notifier.g.dart';


@riverpod
class AiChatNotifier extends _$AiChatNotifier {
  @override
  List<ChatMessage> build(String articleId) {
    return [];
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    final userMessage = ChatMessage(role: 'user', content: text);
    state = [...state, userMessage];
    _isLoading = true;
    ref.notifyListeners();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final response = await DioClient.instance.dio.post<ResponseBody>(
        '${AppConfig.apiBaseUrl}/api/chat',
        data: {
          'article_id': articleId,
          'messages': state.map((m) => m.toJson()).toList(),
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
          },
        ),
      );


      // Add an initial empty model message
      final modelMessage = ChatMessage(role: 'model', content: '');
      state = [...state, modelMessage];

      final transformer = utf8.decoder
          .bind(response.data!.stream)
          .transform(const LineSplitter());

      await for (final line in transformer) {
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
          }
        } catch (e) {
          // Ignore parsing errors for partial chunks if any, but log them
          print('Error parsing chunk: $e');
        }
      }
    } catch (e) {
      String errorMessage = "Sorry, I encountered an error. Please try again later.";
      
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 429) {
          errorMessage = "You've reached the chat limit. Please wait a moment before sending more messages.";
        } else if (statusCode == 400) {
          errorMessage = "The message is too long. Please try a shorter question.";
        } else if (e.error is AppException) {
          errorMessage = (e.error as AppException).message;
        }
      }
      
      state = [...state, ChatMessage(role: 'model', content: errorMessage)];
    } finally {

      _isLoading = false;
      ref.notifyListeners();
    }
  }

  void _appendToLastMessage(String chunk) {
    if (state.isEmpty) return;
    final last = state.last;
    if (last.role != 'model') return;

    state = [
      ...state.sublist(0, state.length - 1),
      last.copyWith(content: last.content + chunk),
    ];
  }

  void _updateLastMessage(String content) {
    if (state.isEmpty) return;
    final last = state.last;
    state = [
      ...state.sublist(0, state.length - 1),
      last.copyWith(content: content),
    ];
  }
}

