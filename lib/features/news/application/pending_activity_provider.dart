// lib/features/news/application/pending_activity_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pending_activity_provider.g.dart';

enum PendingAction { like, favorite, chat, notInterested }

class PendingActivity {
  final PendingAction action;
  final String articleId;

  const PendingActivity({
    required this.action,
    required this.articleId,
  });
}

@riverpod
class PendingActivityNotifier extends _$PendingActivityNotifier {
  @override
  PendingActivity? build() => null;

  void set(PendingAction action, String articleId) {
    state = PendingActivity(action: action, articleId: articleId);
  }

  void clear() {
    state = null;
  }
}
