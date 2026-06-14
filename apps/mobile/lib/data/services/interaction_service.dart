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
    if (llmClient == null || !llmClient!.isBackendConfigured) return null;
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

    final selectedFriends = friends.isEmpty
        ? presetFriends.take(3).toList()
        : friends;
    final imageCount = post.images
        .where((image) => image.type == PostMediaType.image)
        .length;
    final videoCount = post.images
        .where((image) => image.type == PostMediaType.video)
        .length;

    // Create job, then poll for the result. Any thrown error (quota, rate limit,
    // backend fallback, timeout) propagates to tryGenerateWithLlm, which logs it
    // and keeps the local template interactions.
    final jobResponse = await llmClient!.createInteractionJob(
      postId: post.id,
      text: post.text,
      imageCount: imageCount,
      hasVideo: videoCount > 0,
      videoCount: videoCount,
      friends: selectedFriends,
      userName: user.nickname,
      userBio: user.bio,
    );

    final jobDetail = await llmClient!.getJobResult(jobResponse.jobId);

    if (jobDetail == null || jobDetail.status == JobStatus.failed) {
      _logger.e('Job failed or timed out: ${jobDetail?.reason}');
      throw Exception('LLM job failed');
    }

    final llmResult = jobDetail.result;
    if (llmResult == null) {
      throw Exception('No result from LLM');
    }

    // Convert LLM result to Comment objects.
    final comments = <Comment>[];
    for (final commentData in llmResult.comments) {
      final friend = _resolveFriend(commentData.actorId, selectedFriends);
      if (friend == null) {
        // The backend validates actor_id against the friends we sent, so this
        // should not happen. If it does, skip the comment rather than silently
        // attributing it to the wrong friend.
        _logger.w(
          'Skipping LLM comment with unknown actor_id: ${commentData.actorId}',
        );
        continue;
      }
      comments.add(
        Comment(
          id: 'c_${now.millisecondsSinceEpoch}_${comments.length}',
          postId: post.id,
          actorId: friend.id,
          actorNameSnapshot: friend.name,
          actorAvatarSnapshot: friend.avatarInitial,
          actorColor: friend.color,
          content: commentData.content,
          createdAt: now,
          likeCount: commentData.likeCount,
          replies: const [],
        ),
      );
    }

    if (comments.isEmpty) {
      throw Exception('LLM returned no usable comments');
    }

    return InteractionResult(
      likeCount: llmResult.aiLikeCount,
      comments: comments,
      usedFallback: false,
    );
  }

  /// Resolves a backend `actor_id` to a known friend, or null if it matches
  /// neither the friends we sent nor any preset friend.
  AiFriend? _resolveFriend(String actorId, List<AiFriend> selectedFriends) {
    for (final friend in selectedFriends) {
      if (friend.id == actorId) return friend;
    }
    for (final friend in presetFriends) {
      if (friend.id == actorId) return friend;
    }
    return null;
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
