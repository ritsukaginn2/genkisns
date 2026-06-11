import 'package:logger/logger.dart';
import '../../mock/mock_data.dart';
import '../../models.dart';
import 'llm_client.dart';

final logger = Logger();

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

  /// Generate initial interactions using LLM or fallback to local template
  Future<InteractionResult> generateInitialInteractions({
    required PostSeed post,
    required UserProfile user,
    required List<AiFriend> friends,
    required DateTime now,
  }) async {
    // If no LLM client, use fallback immediately
    if (llmClient == null) {
      logger.w('No LLM client available, using fallback');
      return _fallback(post: post, friends: friends, now: now);
    }

    try {
      // Try to use real LLM
      return await _generateWithLLM(
        post: post,
        user: user,
        friends: friends,
        now: now,
      );
    } catch (e) {
      logger.e('LLM generation failed: $e, using fallback');
      // Fall back to template generation
      return _fallback(post: post, friends: friends, now: now);
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
        logger.e('Job failed or timed out: ${jobDetail?.reason}');
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
      logger.w('Quota exceeded, using fallback');
      rethrow;
    } on RateLimitedException {
      logger.w('Rate limited, using fallback');
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
