import 'package:flutter/material.dart';
import '../../domain/entities/news_article.dart';
import '../screens/ai_chat_screen.dart';
import '../../../../theme/theme.dart';

class AiQuickChatSheet extends StatefulWidget {
  final NewsArticle article;

  const AiQuickChatSheet({super.key, required this.article});

  @override
  State<AiQuickChatSheet> createState() => _AiQuickChatSheetState();
}

class _AiQuickChatSheetState extends State<AiQuickChatSheet> {
  final TextEditingController _controller = TextEditingController();

  static const List<String> _suggestedPrompts = [
    'Context of this story',
    'Explain in simple terms',
    'Key takeaways',
    'Why is this important?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToChat([String? initialMessage]) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AiChatScreen(
          article: widget.article,
          initialMessage: initialMessage ?? _controller.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryCategory = widget.article.categories.isNotEmpty
        ? widget.article.categories.first
        : null;
    final catColor = AppTheme.categoryColor(primaryCategory?.name ?? 'world');
    final bgColor = Color.lerp(const Color(0xFF0A0C14), catColor, 0.12)!;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom +
            MediaQuery.viewInsetsOf(context).bottom +
            24,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Header
          Row(
            children: [
              const Icon(Icons.auto_awesome,
                  color: Color(0xFF6C63FF), size: 28),
              const SizedBox(width: 12),
              const Text(
                'Article Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Ask about: "${widget.article.title}"',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 32),

          // Suggested chips
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: _suggestedPrompts
                .map((prompt) => _PromptChip(
                      label: prompt,
                      onTap: () => _navigateToChat(prompt),
                    ))
                .toList(),
          ),
          const SizedBox(height: 32),

          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C14).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    autofocus: false,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Type a question...',
                      hintStyle:
                          TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _navigateToChat(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF6C63FF)),
                  onPressed: () => _navigateToChat(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
          border:
              Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF0F2FF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
