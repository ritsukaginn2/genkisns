import 'package:logger/logger.dart';
import '../../mock/mock_data.dart';
import '../../models.dart';
import 'llm_client.dart';

final Logger _logger = Logger();

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
  final LLMClient? llmClient;

  InteractionService({this.llmClient});

  /// V1 primary path: local template interactions, generated synchronously so
  /// publishing never waits on the network.
  InteractionResult generateLocalInteractions({
    required PostSeed post,
    required List<AiFriend> friends,
    required DateTime now,
  }) {
    return _fallback(post: post, friends: friends, now: now);
  }

  /// V1.6 upgrade path: try the real LLM backend in the background.
  /// Returns null when no client is configured or generation fails — callers
  /// keep the local template interactions in that case.
  Future<InteractionResult?> tryGenerateWithLlm({
    required PostSeed post,
    required UserProfile user,
    required List<AiFriend> friends,
    required DateTime now,
  }) async {
    if (llmClient == null) return null;
    try {
      return await _generateWithLLM(
        post: post,
        user: user,
        friends: friends,
        now: now,
      );
    } catch (e) {
      _logger.w('LLM generation failed, keeping local interactions: $e');
      return null;
    }
  }

  /// Generate interactions using real LLM backend
  Future<InteractionResult> _generateWithLLM({
    required PostSeed post,
    required UserProfile user,
    required List<AiFriend> friends,
    required DateTime now,
  }) async {
    if (llmClient == null) throw Exception('LLM client not initialized');

    // Get friends IDs
    final friendIds = friends.isEmpty
        ? presetFriends.take(3).map((f) => f.id).toList()
        : friends.map((f) => f.id).toList();

    try {
      // Create job
      final jobResponse = await llmClient!.createInteractionJob(
        postId: 'post_${now.millisecondsSinceEpoch}',
        text: post.text,
        imageCount: post.images.length,
        friendIds: friendIds,
        userName: user.nickname,
        userBio: user.bio,
      );

      // Poll result
      final jobDetail = await llmClient!.getJobResult(jobResponse.jobId);

      if (jobDetail == null || jobDetail.status == JobStatus.failed) {
        _logger.e('Job failed or timed out: ${jobDetail?.reason}');
        throw Exception('LLM job failed');
      }

      if (jobDetail.result == null) {
        throw Exception('No result from LLM');
      }

      // Convert LLM result to Comment objects
      final llmResult = jobDetail.result!;
      final comments = <Comment>[];

      for (final commentData in llmResult.comments) {
        final friend = friends.firstWhere(
          (f) => f.id == commentData.actorId,
          orElse: () => presetFriends.firstWhere(
            (f) => f.id == commentData.actorId,
            orElse: () => presetFriends.first,
          ),
        );

        comments.add(Comment(
          id: 'c_${now.millisecondsSinceEpoch}_${comments.length}',
          postId: '', // Will be set by PostRepository
          actorId: friend.id,
          actorNameSnapshot: friend.name,
          actorAvatarSnapshot: friend.avatarInitial,
          actorColor: friend.color,
          content: commentData.content,
          createdAt: now,
          likeCount: commentData.likeCount,
          replies: const [],
        ));
      }

      return InteractionResult(
        likeCount: llmResult.aiLikeCount,
        comments: comments,
        usedFallback: false,
      );
    } on QuotaExceededException {
      _logger.w('Quota exceeded, using fallback');
      rethrow;
    } on RateLimitedException {
      _logger.w('Rate limited, using fallback');
      rethrow;
    }
  }

  /// Fall back to template-based generation (local, fast)
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

}
