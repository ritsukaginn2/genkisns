import '../../mock/mock_data.dart';
import '../../models.dart';

class InteractionResult {
  const InteractionResult({
    required this.likeCount,
    required this.comments,
    required this.usedFallback,
  });

  final int likeCount;
  final List<Comment> comments;
  final bool usedFallback;
}

class InteractionService {
  const InteractionService();

  Future<InteractionResult> generateInitialInteractions({
    required PostSeed post,
    required UserProfile user,
    required List<AiFriend> friends,
    required DateTime now,
  }) async {
    final comments = generateTemplateComments(
      post: post,
      friends: friends,
      now: now,
    );
    if (comments.isEmpty) {
      return _fallback(post: post, friends: friends, now: now);
    }

    return InteractionResult(
      likeCount: _likeCountFor(
        post: post,
        user: user,
        friends: friends,
        comments: comments,
      ),
      comments: comments,
      usedFallback: false,
    );
  }

  InteractionResult _fallback({
    required PostSeed post,
    required List<AiFriend> friends,
    required DateTime now,
  }) {
    final comments = generateTemplateComments(
      post: post,
      friends: friends.isEmpty ? presetFriends.take(1).toList() : friends,
      now: now,
    );
    return InteractionResult(
      likeCount: comments.length + 8,
      comments: comments,
      usedFallback: true,
    );
  }

  int _likeCountFor({
    required PostSeed post,
    required UserProfile user,
    required List<AiFriend> friends,
    required List<Comment> comments,
  }) {
    final userBoost = user.nickname.trim().isEmpty ? 0 : 1;
    final textBoost = post.text.trim().isEmpty ? 0 : 4;
    final hasVideo = post.images.any(
      (image) => image.type == PostMediaType.video,
    );
    final imageCount = post.images
        .where((image) => image.type == PostMediaType.image)
        .length;
    final mediaBoost = hasVideo ? 6 : (imageCount * 2).clamp(0, 10).toInt();
    return comments.length +
        friends.length +
        8 +
        userBoost +
        textBoost +
        mediaBoost;
  }
}
