import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/providers/providers.dart';
import '../../../../core/utils/browser_service.dart';
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
  final GlobalKey _pendingUserMessageKey = GlobalKey();

  bool _pendingAnchorRequested = false;
  bool _hasAnchoredPendingMessage = false;
  bool _userScrolledAway = false;
  int? _pendingUserIndex;

  static const List<String> _suggestedPrompts = [
    'Context of this story',
    'Explain in simple terms',
    'Key takeaways',
    'Why is this important?',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScrollPosition);
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendMessage(widget.initialMessage);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollPosition);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return _scrollController.position.extentAfter < 80;
  }

  void _handleScrollPosition() {
    _userScrolledAway = !_isNearBottom();
  }

  bool _hasNonEmptyModelAfter(List<ChatMessage> messages, int userIndex) {
    for (var i = userIndex + 1; i < messages.length; i++) {
      final m = messages[i];
      if (m.role == 'model' && m.content.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  void _anchorPendingMessageNearTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasAnchoredPendingMessage) return;

      final ctx = _pendingUserMessageKey.currentContext;
      if (ctx == null) return;

      _hasAnchoredPendingMessage = true;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.08,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _tryAutoFollowBottom() {
    if (!mounted || !_scrollController.hasClients || _userScrolledAway) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients || _userScrolledAway) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendMessage([String? text]) {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty) return;

    // Retract keyboard immediately on send.
    FocusManager.instance.primaryFocus?.unfocus();

    final provider =
        aiChatNotifierProvider(widget.article.id, widget.article.title);
    final currentMessages = ref.read(provider).messages;

    _pendingAnchorRequested = true;
    _hasAnchoredPendingMessage = false;
    _pendingUserIndex = currentMessages.length;
    _userScrolledAway = false;

    ref.read(provider.notifier).sendMessage(message);
    _controller.clear();

    // Schedule anchor immediately so the sent user message moves near top
    // as soon as the next frame containing it is laid out.
    _anchorPendingMessageNearTop();
  }

  Future<void> _startNewChat() async {
    await ref.read(chatRepositoryProvider).deleteChatSession(widget.article.id);
    ref.invalidate(
        aiChatNotifierProvider(widget.article.id, widget.article.title));

    if (!mounted) return;
    _controller.clear();
    _pendingAnchorRequested = false;
    _hasAnchoredPendingMessage = false;
    _pendingUserIndex = null;
    _userScrolledAway = false;
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref
        .watch(aiChatNotifierProvider(widget.article.id, widget.article.title));
    final messages = chatState.messages;
    final isLoading = chatState.isLoading;

    // Optimization: Calculate lastUserIndex once per build instead of per itemBuilder scan.
    int lastUserIndex = -1;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == 'user') {
        lastUserIndex = i;
        break;
      }
    }

    final showPendingPlaceholder = _pendingUserIndex != null &&
        _pendingUserIndex! >= 0 &&
        _pendingUserIndex! < messages.length &&
        !_hasNonEmptyModelAfter(messages, _pendingUserIndex!) &&
        !messages.skip(_pendingUserIndex! + 1).any((m) => m.role == 'model');

    ref.listen(aiChatNotifierProvider(widget.article.id, widget.article.title),
        (previous, next) {
      final prevMsgs = previous?.messages ?? [];
      final nextMsgs = next.messages;

      if (_pendingAnchorRequested && nextMsgs.isNotEmpty) {
        for (var i = nextMsgs.length - 1; i >= 0; i--) {
          if (nextMsgs[i].role == 'user') {
            _pendingUserIndex = i;
            break;
          }
        }

        if (_pendingUserIndex != null) {
          _anchorPendingMessageNearTop();
        }
      }

      if (_pendingUserIndex != null &&
          _hasNonEmptyModelAfter(nextMsgs, _pendingUserIndex!)) {
        _pendingAnchorRequested = false;
      }

      final changed = nextMsgs.isNotEmpty &&
          (prevMsgs.length != nextMsgs.length ||
              (prevMsgs.isNotEmpty &&
                  prevMsgs.last.content != nextMsgs.last.content));

      // Don't chase the bottom while a response is still streaming in —
      // the user's sent message is already anchored near the top via
      // _anchorPendingMessageNearTop, and forcing the view down on every
      // growing chunk fights any manual scrolling the user does to read
      // along. Only auto-follow for changes once generation has finished.
      if (changed && !_pendingAnchorRequested && !next.isLoading) {
        _tryAutoFollowBottom();
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
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined, color: Colors.white),
            onPressed: _startNewChat,
          ),
        ],
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
                    widget.article.sourceName.trim(),
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
                  ? 1
                  : messages.length + (showPendingPlaceholder ? 1 : 0),
              itemBuilder: (context, index) {
                if (messages.isEmpty && !isLoading) {
                  return _EmptyState(articleTitle: widget.article.title);
                }

                if (messages.isEmpty) {
                  return const _ReservedResponseArea();
                }

                if (showPendingPlaceholder &&
                    index == (_pendingUserIndex! + 1)) {
                  return const _ReservedResponseArea();
                }

                final msgIndex =
                    showPendingPlaceholder && index > (_pendingUserIndex! + 1)
                        ? index - 1
                        : index;

                if (msgIndex < 0 || msgIndex >= messages.length) {
                  return const SizedBox.shrink();
                }

                final msg = messages[msgIndex];
                // Stable keys prevent expensive element destruction during streaming.
                final messageKey = msgIndex == _pendingUserIndex
                    ? _pendingUserMessageKey
                    : ValueKey('msg_${msgIndex}_${msg.role}');

                return _ChatBubble(
                  key: messageKey,
                  message: msg,
                  isEditable: (msgIndex == lastUserIndex) && !isLoading,
                  // Optimization: Render simple Text during generation, switch to Markdown once done.
                  isStreaming: isLoading && msgIndex == messages.length - 1,
                  onEdit: () => _showEditSheet(context, msg.content),
                );
              },
            ),
          ),

          // ── Suggestions ────────────────────────────────────────────────
          if (messages.isEmpty && !isLoading)
            _PromptsList(
              prompts: _suggestedPrompts,
              onTap: _sendMessage,
            ),

          // ── Input area ─────────────────────────────────────────────────
          _InputArea(
            controller: _controller,
            isLoading: isLoading,
            onSend: () => _sendMessage(),
            onStop: () {
              final provider = aiChatNotifierProvider(
                  widget.article.id, widget.article.title);
              ref.read(provider.notifier).stopGeneration();
            },
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, String initialText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditMessageSheet(
        initialText: initialText,
        onSave: (newText) {
          final provider =
              aiChatNotifierProvider(widget.article.id, widget.article.title);
          ref.read(provider.notifier).editLastMessage(newText);
        },
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isEditable;
  final bool isStreaming;
  final VoidCallback? onEdit;

  const _ChatBubble({
    super.key,
    required this.message,
    this.isEditable = false,
    this.isStreaming = false,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isEditable)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.edit_outlined,
                  color: Colors.white38,
                  size: 18,
                ),
                onPressed: onEdit,
                tooltip: 'Edit message',
              ),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.75,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF6C63FF),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                child: Text(
                  message.content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (message.content.trim().isEmpty) {
      return const _ReservedResponseArea();
    }

    // AI Response - Full Screen style like ChatGPT
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isStreaming)
            Text(
              message.content,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                height: 1.6,
                letterSpacing: 0.2,
              ),
            )
          else
            MarkdownBody(
              data: message.content,
              selectable: true,
              onTapLink: (text, href, title) {
                if (href != null) {
                  BrowserService.instance.openUrl(context, href);
                }
              },
              styleSheet: MarkdownStyleSheet(
              blockSpacing: 16,
              p: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 16,
                height: 1.6,
                letterSpacing: 0.2,
              ),
              h1: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              h2: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              h3: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
              listBullet: const TextStyle(
                color: Color(0xFF6C63FF),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              listIndent: 24,
              blockquote: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
              blockquotePadding: const EdgeInsets.all(12),
              blockquoteDecoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: const Border(
                  left: BorderSide(color: Color(0xFF6C63FF), width: 3),
                ),
              ),
              code: TextStyle(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                fontFamily: 'monospace',
                fontSize: 14,
                color: const Color(0xFF6C63FF),
              ),
              codeblockPadding: const EdgeInsets.all(12),
              codeblockDecoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              horizontalRuleDecoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservedResponseArea extends StatelessWidget {
  const _ReservedResponseArea();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 14,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _TypingIndicator(),
        ],
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _InputArea({
    required this.controller,
    required this.isLoading,
    required this.onSend,
    required this.onStop,
  });

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
                inputFormatters: [LengthLimitingTextInputFormatter(500)],
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Ask about this story...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
              ),
            ),
            IconButton(
              icon: Icon(
                isLoading ? Icons.stop_circle_rounded : Icons.send_rounded,
                color: const Color(0xFF6C63FF),
              ),
              onPressed: isLoading ? onStop : onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditMessageSheet extends StatefulWidget {
  final String initialText;
  final Function(String) onSave;

  const _EditMessageSheet({required this.initialText, required this.onSave});

  @override
  State<_EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<_EditMessageSheet> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF1A1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.paddingOf(context).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Edit Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0A0C14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _controller,
                autofocus: true,
                maxLines: 5,
                minLines: 1,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Edit your message...',
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  final text = _controller.text.trim();
                  if (text.isNotEmpty && text != widget.initialText) {
                    widget.onSave(text);
                  }
                  Navigator.pop(context);
                },
                child: const Text(
                  'Resend',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
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

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final double begin = index * 0.15;
              final double end = (begin + 0.4).clamp(0.0, 1.0);
              final double value = _controller.value;

              double shift = 0.0;
              if (value >= begin && value <= end) {
                final double relative = (value - begin) / (end - begin);
                shift = math.sin(math.pi * relative);
              }

              return Container(
                margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF)
                      .withValues(alpha: 0.4 + (shift * 0.6)),
                  shape: BoxShape.circle,
                ),
                transform: Matrix4.translationValues(0, -shift * 4, 0),
              );
            },
          );
        }),
      ),
    );
  }
}
