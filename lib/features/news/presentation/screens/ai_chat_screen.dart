import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/news_article.dart';
import '../../domain/entities/chat_message.dart';
import '../../application/ai_chat_notifier.dart';

class AiChatScreen extends ConsumerStatefulWidget {
  final NewsArticle article;
  final String? initialMessage;

  const AiChatScreen({super.key, required this.article, this.initialMessage});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _suggestedPrompts = [
    'Context of this story',
    'Explain in simple terms',
    'Key takeaways',
    'Why is this important?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialMessage);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage([String? text]) {
    final message = text ?? _controller.text;
    if (message.isEmpty) return;

    ref
        .read(aiChatNotifierProvider(widget.article.id).notifier)
        .sendMessage(message);
    _controller.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(aiChatNotifierProvider(widget.article.id));
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;

    ref.listen(aiChatNotifierProvider(widget.article.id), (previous, next) {
      final prevMsgs = previous?.messages ?? [];
      final nextMsgs = next.messages;
      if (nextMsgs.isNotEmpty &&
          (prevMsgs.length != nextMsgs.length ||
              (prevMsgs.isNotEmpty &&
                  prevMsgs.last.content != nextMsgs.last.content))) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF6C63FF),
              child: Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Article Assistant',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    widget.article.sourceName,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Chat List ──────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.isEmpty
                  ? (isLoading ? 1 : 1)
                  : messages.length + (isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (messages.isEmpty && !isLoading) {
                  return _EmptyState(articleTitle: widget.article.title);
                }

                if (isLoading && index == messages.length) {
                  return const _TypingIndicator();
                }

                if (index < messages.length) {
                  final msg = messages[index];
                  return _ChatBubble(message: msg);
                }

                return const SizedBox.shrink();
              },
            ),
          ),



          // ── Suggestions ────────────────────────────────────────────────
          if (messages.isEmpty)
            _PromptsList(
              prompts: _suggestedPrompts,
              onTap: _sendMessage,
            ),

          // ── Input area ─────────────────────────────────────────────────
          _InputArea(
            controller: _controller,
            onSend: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6C63FF) : const Color(0xFF1A1E2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFFF0F2FF),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputArea({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.paddingOf(context).bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C14),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1E2E),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ask about this story...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send_rounded, color: Color(0xFF6C63FF)),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptsList extends StatelessWidget {
  final List<String> prompts;
  final Function(String) onTap;

  const _PromptsList({required this.prompts, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prompts.length,
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(prompt),
              backgroundColor: const Color(0xFF1A1E2E),
              labelStyle:
                  const TextStyle(color: Color(0xFF6C63FF), fontSize: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
                side: BorderSide(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
              ),
              onPressed: () => onTap(prompt),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String articleTitle;

  const _EmptyState({required this.articleTitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                size: 40, color: Color(0xFF6C63FF)),
          ),
          const SizedBox(height: 24),
          const Text(
            'How can I help?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ask me anything about "$articleTitle"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF1A1E2E),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF6C63FF),
                shape: BoxShape.circle,
              ),
            );
          }),
        ),
      ),
    );
  }
}
