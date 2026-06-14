import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/data/repositories/ai_friend_repository.dart';
import 'package:genki_sns/data/repositories/post_repository.dart';
import 'package:genki_sns/data/repositories/user_repository.dart';
import 'package:genki_sns/data/services/interaction_service.dart';
import 'package:genki_sns/data/services/llm_client.dart';
import 'package:genki_sns/models.dart';

void main() {
  test('creates an image-only post through repository', () async {
    final repository = PostRepository(interactionService: InteractionService());
    final friends = AiFriendRepository().listSelectedFriends();

    final post = await repository.createPost(
      PostDraft(
        text: '',
        images: PostImageRef.previewColors(const [Colors.pink]),
      ),
      user: const UserRepository().getDefaultUser(),
      friends: friends,
    );

    expect(post.text, isEmpty);
    expect(post.imageColors, [Colors.pink]);
    expect(post.comments, isNotEmpty);
    expect(post.interactionStatus, InteractionStatus.success);
    expect(repository.listPosts(), [post]);
  });

  test('creates a video-only post through repository', () async {
    final repository = PostRepository(interactionService: InteractionService());
    final friends = AiFriendRepository().listSelectedFriends();

    final post = await repository.createPost(
      const PostDraft(
        text: '',
        images: [
          PostImageRef(
            id: 'video_1',
            type: PostMediaType.video,
            source: PostImageSource.camera,
            localRef: '/tmp/video.mov',
            thumbnailRef: '/tmp/video.jpg',
            durationMillis: 12000,
            sortIndex: 0,
          ),
        ],
      ),
      user: const UserRepository().getDefaultUser(),
      friends: friends,
    );

    expect(post.text, isEmpty);
    expect(post.hasVideo, isTrue);
    expect(post.comments, isNotEmpty);
    expect(repository.listPosts(), [post]);
  });

  test('rejects empty post drafts', () async {
    final repository = PostRepository(interactionService: InteractionService());

    expect(
      repository.createPost(
        const PostDraft(text: '', images: []),
        user: const UserRepository().getDefaultUser(),
        friends: const [],
      ),
      throwsArgumentError,
    );
  });

  test(
    'persists post likes, comment likes, replies and reply deletion',
    () async {
      final repository = PostRepository(
        interactionService: InteractionService(),
      );
      final user = const UserRepository().getDefaultUser();
      final friends = AiFriendRepository().listSelectedFriends();

      final post = await repository.createPost(
        const PostDraft(text: '需要一点回应。', images: []),
        user: user,
        friends: friends,
      );
      final commentId = post.comments.first.id;

      final likedPost = await repository.togglePostLike(post.id);
      expect(likedPost.userLiked, isTrue);
      expect(likedPost.likeCount, post.likeCount + 1);

      final likedComment = await repository.toggleCommentLike(
        postId: post.id,
        commentId: commentId,
      );
      expect(likedComment.comments.first.userLiked, isTrue);
      expect(
        likedComment.comments.first.likeCount,
        post.comments.first.likeCount + 1,
      );

      final repliedPost = await repository.addLocalReply(
        postId: post.id,
        commentId: commentId,
        user: user,
        content: '我也这么觉得。',
      );
      final reply = repliedPost.comments.first.replies.single;
      expect(reply.authorNameSnapshot, user.nickname);
      expect(
        reply.targetActorNameSnapshot,
        post.comments.first.actorNameSnapshot,
      );
      expect(repliedPost.commentCount, post.commentCount + 1);

      final deletedReplyPost = await repository.deleteLocalReply(
        postId: post.id,
        commentId: commentId,
        replyId: reply.id,
      );
      expect(deletedReplyPost.comments.first.replies, isEmpty);
    },
  );

  test('deletes posts through repository', () async {
    final repository = PostRepository(interactionService: InteractionService());
    final user = const UserRepository().getDefaultUser();

    final post = await repository.createPost(
      const PostDraft(text: '这条稍后删除。', images: []),
      user: user,
      friends: AiFriendRepository().listSelectedFriends(),
    );

    await repository.deletePost(post.id);

    expect(repository.listPosts(), isEmpty);
    expect(() => repository.getPost(post.id), throwsStateError);
  });

  test('clears all posts and their local media', () async {
    final repository = PostRepository(interactionService: InteractionService());
    final user = const UserRepository().getDefaultUser();
    final friends = AiFriendRepository().listSelectedFriends();
    final tempDir = await Directory.systemTemp.createTemp(
      'genki_sns_clear_all_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final mediaFile = File('${tempDir.path}/image.jpg');
    await mediaFile.writeAsString('image');

    await repository.createPost(
      const PostDraft(text: '第一条。', images: []),
      user: user,
      friends: friends,
    );
    await repository.createPost(
      PostDraft(
        text: '第二条带图。',
        images: [
          PostImageRef(
            id: 'image_1',
            source: PostImageSource.album,
            localRef: mediaFile.path,
            sortIndex: 0,
          ),
        ],
      ),
      user: user,
      friends: friends,
    );
    expect(repository.listPosts(), hasLength(2));

    await repository.clearAllPosts();

    expect(repository.listPosts(), isEmpty);
    expect(await mediaFile.exists(), isFalse);
  });

  test('deletes local media files when deleting a post', () async {
    final repository = PostRepository(interactionService: InteractionService());
    final user = const UserRepository().getDefaultUser();
    final tempDir = await Directory.systemTemp.createTemp(
      'genki_sns_media_delete_test_',
    );
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final mediaFile = File('${tempDir.path}/image.jpg');
    final thumbnailFile = File('${tempDir.path}/thumb.jpg');
    await mediaFile.writeAsString('image');
    await thumbnailFile.writeAsString('thumb');

    final post = await repository.createPost(
      PostDraft(
        text: '',
        images: [
          PostImageRef(
            id: 'image_1',
            source: PostImageSource.album,
            localRef: mediaFile.path,
            thumbnailRef: thumbnailFile.path,
            sortIndex: 0,
          ),
        ],
      ),
      user: user,
      friends: AiFriendRepository().listSelectedFriends(),
    );

    await repository.deletePost(post.id);

    expect(await mediaFile.exists(), isFalse);
    expect(await thumbnailFile.exists(), isFalse);
  });

  test('LLM upgrade preserves local comment likes and replies', () async {
    final llmClient = _ControlledLlmClient();
    final updateCompleter = Completer<Post>();
    final repository = PostRepository(
      interactionService: InteractionService(llmClient: llmClient),
      onPostUpdated: (post) {
        if (!updateCompleter.isCompleted) updateCompleter.complete(post);
      },
    );
    final user = const UserRepository().getDefaultUser();
    final friends = AiFriendRepository().listSelectedFriends();

    final post = await repository.createPost(
      const PostDraft(text: '等待真实回应。', images: []),
      user: user,
      friends: friends,
    );
    final originalComment = post.comments.first;
    await repository.toggleCommentLike(
      postId: post.id,
      commentId: originalComment.id,
    );
    await repository.addLocalReply(
      postId: post.id,
      commentId: originalComment.id,
      user: user,
      content: '这是本地回复。',
    );

    llmClient.complete();
    final updated = await updateCompleter.future.timeout(
      const Duration(seconds: 1),
    );

    expect(updated.comments.first.content, '真实 LLM 评论。');
    expect(updated.comments.first.postId, post.id);
    expect(updated.comments.first.userLiked, isTrue);
    expect(updated.comments.first.likeCount, 4);
    expect(updated.comments.first.replies.single.content, '这是本地回复。');
    expect(
      updated.comments.first.replies.single.commentId,
      updated.comments.first.id,
    );
  });

  test(
    'LLM upgrade keeps replies when the same actor returns multiple comments',
    () async {
      final llmClient = _MultiCommentLlmClient();
      final updateCompleter = Completer<Post>();
      final repository = PostRepository(
        interactionService: InteractionService(llmClient: llmClient),
        onPostUpdated: (post) {
          if (!updateCompleter.isCompleted) updateCompleter.complete(post);
        },
      );
      final user = const UserRepository().getDefaultUser();
      final friends = AiFriendRepository().listSelectedFriends();

      final post = await repository.createPost(
        const PostDraft(text: '等待多条回应。', images: []),
        user: user,
        friends: friends,
      );
      final mikaComment = post.comments.firstWhere(
        (comment) => comment.actorId == 'friend_mika',
      );
      await repository.addLocalReply(
        postId: post.id,
        commentId: mikaComment.id,
        user: user,
        content: '挂在第一条上的回复。',
      );

      llmClient.complete();
      final updated = await updateCompleter.future.timeout(
        const Duration(seconds: 1),
      );

      final mikaComments = updated.comments
          .where((comment) => comment.actorId == 'friend_mika')
          .toList();
      expect(mikaComments, hasLength(2));
      expect(mikaComments.first.content, '第一条真实评论。');
      expect(mikaComments.first.replies.single.content, '挂在第一条上的回复。');
      expect(
        mikaComments.first.replies.single.commentId,
        mikaComments.first.id,
      );
      expect(mikaComments[1].replies, isEmpty);
    },
  );

  test('tryGenerateWithLlm returns null when polling times out', () async {
    final service = InteractionService(llmClient: _TimeoutLlmClient());
    final result = await service.tryGenerateWithLlm(
      post: const PostSeed(id: 'post_timeout', text: '超时降级。', images: []),
      user: const UserRepository().getDefaultUser(),
      friends: AiFriendRepository().listSelectedFriends(),
      now: DateTime.now(),
    );
    expect(result, isNull);
  });

  test(
    'tryGenerateWithLlm returns null when the backend signals fallback',
    () async {
      final service = InteractionService(llmClient: _FallbackLlmClient());
      final result = await service.tryGenerateWithLlm(
        post: const PostSeed(id: 'post_fallback', text: '受限降级。', images: []),
        user: const UserRepository().getDefaultUser(),
        friends: AiFriendRepository().listSelectedFriends(),
        now: DateTime.now(),
      );
      expect(result, isNull);
    },
  );
}

class _ControlledLlmClient extends LLMClient {
  _ControlledLlmClient() : super(isDevelopment: true);

  final _resultReady = Completer<void>();

  @override
  bool get isBackendConfigured => true;

  void complete() {
    if (!_resultReady.isCompleted) _resultReady.complete();
  }

  @override
  Future<void> init() async {}

  @override
  Future<InteractionJobResponse> createInteractionJob({
    required String postId,
    required String? text,
    required int imageCount,
    required bool hasVideo,
    required int videoCount,
    required List<AiFriend> friends,
    required String userName,
    required String? userBio,
  }) async {
    return InteractionJobResponse(jobId: 'job_1', status: JobStatus.queued);
  }

  @override
  Future<InteractionJobDetailResponse?> getJobResult(
    String jobId, {
    int maxAttempts = 30,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    await _resultReady.future;
    return InteractionJobDetailResponse(
      jobId: jobId,
      status: JobStatus.completed,
      result: JobResult(
        aiLikeCount: 18,
        comments: [
          CommentData(
            actorId: 'friend_mika',
            content: '真实 LLM 评论。',
            likeCount: 3,
          ),
        ],
      ),
    );
  }
}

/// Returns two comments from the same actor to exercise the merge logic.
class _MultiCommentLlmClient extends LLMClient {
  _MultiCommentLlmClient() : super(isDevelopment: true);

  final _resultReady = Completer<void>();

  @override
  bool get isBackendConfigured => true;

  void complete() {
    if (!_resultReady.isCompleted) _resultReady.complete();
  }

  @override
  Future<void> init() async {}

  @override
  Future<InteractionJobResponse> createInteractionJob({
    required String postId,
    required String? text,
    required int imageCount,
    required bool hasVideo,
    required int videoCount,
    required List<AiFriend> friends,
    required String userName,
    required String? userBio,
  }) async {
    return InteractionJobResponse(jobId: 'job_multi', status: JobStatus.queued);
  }

  @override
  Future<InteractionJobDetailResponse?> getJobResult(
    String jobId, {
    int maxAttempts = 30,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    await _resultReady.future;
    return InteractionJobDetailResponse(
      jobId: jobId,
      status: JobStatus.completed,
      result: JobResult(
        aiLikeCount: 20,
        comments: [
          CommentData(
            actorId: 'friend_mika',
            content: '第一条真实评论。',
            likeCount: 2,
          ),
          CommentData(
            actorId: 'friend_mika',
            content: '第二条真实评论。',
            likeCount: 1,
          ),
        ],
      ),
    );
  }
}

/// Polling never resolves to a terminal result (simulates a timeout).
class _TimeoutLlmClient extends LLMClient {
  _TimeoutLlmClient() : super(isDevelopment: true);

  @override
  bool get isBackendConfigured => true;

  @override
  Future<void> init() async {}

  @override
  Future<InteractionJobResponse> createInteractionJob({
    required String postId,
    required String? text,
    required int imageCount,
    required bool hasVideo,
    required int videoCount,
    required List<AiFriend> friends,
    required String userName,
    required String? userBio,
  }) async {
    return InteractionJobResponse(
      jobId: 'job_timeout',
      status: JobStatus.queued,
    );
  }

  @override
  Future<InteractionJobDetailResponse?> getJobResult(
    String jobId, {
    int maxAttempts = 30,
    Duration initialDelay = const Duration(milliseconds: 500),
  }) async {
    return null;
  }
}

/// Rejects job creation with a fallback-required signal (blocked/limited/etc.).
class _FallbackLlmClient extends LLMClient {
  _FallbackLlmClient() : super(isDevelopment: true);

  @override
  bool get isBackendConfigured => true;

  @override
  Future<void> init() async {}

  @override
  Future<InteractionJobResponse> createInteractionJob({
    required String postId,
    required String? text,
    required int imageCount,
    required bool hasVideo,
    required int videoCount,
    required List<AiFriend> friends,
    required String userName,
    required String? userBio,
  }) async {
    throw BackendFallbackException('installation_blocked');
  }
}
