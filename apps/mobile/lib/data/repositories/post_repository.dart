import 'dart:async';
import 'dart:io';

import '../../models.dart';
import '../services/media_storage.dart';
import '../services/interaction_service.dart';
import '../stores/post_store.dart';

class PostRepository {
  PostRepository({
    required this.interactionService,
    PostStore? store,
    this.onPostUpdated,
  }) : store = store ?? MemoryPostStore();

  final InteractionService interactionService;
  final PostStore store;

  /// Notified when a post is updated outside a direct user action (e.g. the
  /// background LLM upgrade replaces template interactions).
  final void Function(Post post)? onPostUpdated;

  final List<Post> _posts = [];

  List<Post> listPosts() => List.unmodifiable(_posts);

  Future<void> load() async {
    final storedPosts = await store.loadPosts();
    _posts
      ..clear()
      ..addAll(storedPosts);
  }

  Future<void> close() => store.close();

  Future<void> prepareForBackup() => store.prepareForBackup();

  Post getPost(String postId) {
    final index = _postIndex(postId);
    return _posts[index];
  }

  Future<Post> createPost(
    PostDraft draft, {
    required UserProfile user,
    required List<AiFriend> friends,
  }) async {
    if (!draft.hasContent) {
      throw ArgumentError('PostDraft must contain text or media.');
    }

    final now = DateTime.now();
    final seed = PostSeed(
      id: 'post_${now.microsecondsSinceEpoch}',
      text: draft.text.trim(),
      images: List.unmodifiable(draft.images),
    );
    // V1: local template interactions, generated synchronously — publishing
    // never waits on the network.
    final interactions = interactionService.generateLocalInteractions(
      post: seed,
      friends: friends,
      now: now,
    );
    final post = Post(
      id: seed.id,
      text: seed.text,
      images: seed.images,
      createdAt: now,
      likeCount: interactions.likeCount,
      comments: interactions.comments,
      interactionStatus: InteractionStatus.success,
    );

    _posts.insert(0, post);
    await store.upsertPost(post);

    // V1.6: upgrade to real LLM interactions in the background when available.
    unawaited(
      _upgradeInteractionsWithLlm(
        seed: seed,
        user: user,
        friends: friends,
        now: now,
      ),
    );
    return post;
  }

  Future<void> _upgradeInteractionsWithLlm({
    required PostSeed seed,
    required UserProfile user,
    required List<AiFriend> friends,
    required DateTime now,
  }) async {
    final result = await interactionService.tryGenerateWithLlm(
      post: seed,
      user: user,
      friends: friends,
      now: now,
    );
    if (result == null) return;

    // The post may have been deleted or liked while the LLM was working.
    final index = _posts.indexWhere((post) => post.id == seed.id);
    if (index == -1) return;
    final current = _posts[index];
    final mergedComments = _mergeLlmComments(
      postId: current.id,
      existing: current.comments,
      incoming: result.comments,
    );
    final updated = current.copyWith(
      likeCount: result.likeCount + (current.userLiked ? 1 : 0),
      comments: mergedComments,
      interactionStatus: result.usedFallback
          ? InteractionStatus.fallback
          : InteractionStatus.success,
    );
    await _replacePost(updated);
    onPostUpdated?.call(updated);
  }

  List<Comment> _mergeLlmComments({
    required String postId,
    required List<Comment> existing,
    required List<Comment> incoming,
  }) {
    if (incoming.isEmpty) return existing;

    final consumedExistingIds = <String>{};
    final merged = <Comment>[];
    for (final llmComment in incoming) {
      final matched = _findMatchingExistingComment(
        llmComment: llmComment,
        existing: existing,
        consumedExistingIds: consumedExistingIds,
      );
      if (matched != null) {
        consumedExistingIds.add(matched.id);
      }
      merged.add(
        _mergeCommentState(
          postId: postId,
          llmComment: llmComment,
          existingComment: matched,
        ),
      );
    }

    for (final existingComment in existing) {
      if (consumedExistingIds.contains(existingComment.id)) continue;
      if (existingComment.userLiked || existingComment.replies.isNotEmpty) {
        merged.add(existingComment.copyWith(postId: postId));
      }
    }

    return merged;
  }

  Comment? _findMatchingExistingComment({
    required Comment llmComment,
    required List<Comment> existing,
    required Set<String> consumedExistingIds,
  }) {
    for (final comment in existing) {
      if (!consumedExistingIds.contains(comment.id) &&
          comment.id == llmComment.id) {
        return comment;
      }
    }
    for (final comment in existing) {
      if (!consumedExistingIds.contains(comment.id) &&
          comment.actorId == llmComment.actorId) {
        return comment;
      }
    }
    return null;
  }

  Comment _mergeCommentState({
    required String postId,
    required Comment llmComment,
    required Comment? existingComment,
  }) {
    final userLiked = existingComment?.userLiked ?? false;
    final replies = existingComment == null
        ? const <LocalReply>[]
        : [
            for (final reply in existingComment.replies)
              LocalReply(
                id: reply.id,
                commentId: llmComment.id,
                authorNameSnapshot: reply.authorNameSnapshot,
                authorAvatarSnapshot: reply.authorAvatarSnapshot,
                targetActorNameSnapshot: llmComment.actorNameSnapshot,
                content: reply.content,
                createdAt: reply.createdAt,
              ),
          ];
    return llmComment.copyWith(
      postId: postId,
      likeCount: llmComment.likeCount + (userLiked ? 1 : 0),
      userLiked: userLiked,
      replies: replies,
    );
  }

  Future<Post> togglePostLike(String postId) {
    final post = getPost(postId);
    final nextLiked = !post.userLiked;
    final nextLikeCount = nextLiked
        ? post.likeCount + 1
        : (post.likeCount - 1).clamp(0, post.likeCount).toInt();

    return _replacePost(
      post.copyWith(likeCount: nextLikeCount, userLiked: nextLiked),
    );
  }

  Future<Post> toggleCommentLike({
    required String postId,
    required String commentId,
  }) {
    final post = getPost(postId);
    final updatedComments = [
      for (final comment in post.comments)
        if (comment.id == commentId)
          _toggleCommentLikeState(comment)
        else
          comment,
    ];

    return _replacePost(post.copyWith(comments: updatedComments));
  }

  Future<Post> addLocalReply({
    required String postId,
    required String commentId,
    required UserProfile user,
    required String content,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Local reply content must not be empty.');
    }

    final post = getPost(postId);
    final updatedComments = [
      for (final comment in post.comments)
        if (comment.id == commentId)
          comment.copyWith(
            replies: [
              ...comment.replies,
              LocalReply(
                id: 'reply_${DateTime.now().microsecondsSinceEpoch}',
                commentId: commentId,
                authorNameSnapshot: user.nickname,
                authorAvatarSnapshot: user.avatarInitial,
                targetActorNameSnapshot: comment.actorNameSnapshot,
                content: trimmed,
                createdAt: DateTime.now(),
              ),
            ],
          )
        else
          comment,
    ];

    return _replacePost(post.copyWith(comments: updatedComments));
  }

  Future<Post> deleteLocalReply({
    required String postId,
    required String commentId,
    required String replyId,
  }) {
    final post = getPost(postId);
    final updatedComments = [
      for (final comment in post.comments)
        if (comment.id == commentId)
          comment.copyWith(
            replies: [
              for (final reply in comment.replies)
                if (reply.id != replyId) reply,
            ],
          )
        else
          comment,
    ];

    return _replacePost(post.copyWith(comments: updatedComments));
  }

  Future<void> deletePost(String postId) async {
    final index = _postIndex(postId);
    final post = _posts.removeAt(index);
    await store.deletePost(postId);
    await _deletePostMedia(post);
  }

  /// Removes every post and its media from the local store. Does not touch any
  /// iCloud backup.
  Future<void> clearAllPosts() async {
    final removed = List<Post>.from(_posts);
    _posts.clear();
    await store.deleteAllPosts();
    for (final post in removed) {
      await _deletePostMedia(post);
    }
  }

  Comment _toggleCommentLikeState(Comment comment) {
    final nextLiked = !comment.userLiked;
    final nextLikeCount = nextLiked
        ? comment.likeCount + 1
        : (comment.likeCount - 1).clamp(0, comment.likeCount).toInt();

    return comment.copyWith(likeCount: nextLikeCount, userLiked: nextLiked);
  }

  Future<Post> _replacePost(Post updatedPost) async {
    final index = _postIndex(updatedPost.id);
    _posts[index] = updatedPost;
    await store.upsertPost(updatedPost);
    return updatedPost;
  }

  int _postIndex(String postId) {
    final index = _posts.indexWhere((post) => post.id == postId);
    if (index == -1) {
      throw StateError('Post not found: $postId');
    }
    return index;
  }

  Future<void> _deletePostMedia(Post post) async {
    for (final image in post.images) {
      await _deleteFileRef(image.localRef);
      final thumbnailRef = image.thumbnailRef;
      if (thumbnailRef != null) {
        await _deleteFileRef(thumbnailRef);
      }
    }
  }

  Future<void> _deleteFileRef(String ref) async {
    final path = MediaStorage.resolve(ref);
    if (path == null) return;
    final file = File(path);
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // A post delete should not be blocked by best-effort media cleanup.
    }
  }
}
