import '../../models.dart';
import '../services/interaction_service.dart';
import '../stores/post_store.dart';

class PostRepository {
  PostRepository({required this.interactionService, PostStore? store})
    : store = store ?? MemoryPostStore();

  final InteractionService interactionService;
  final PostStore store;
  final List<Post> _posts = [];

  List<Post> listPosts() => List.unmodifiable(_posts);

  Future<void> load() async {
    final storedPosts = await store.loadPosts();
    _posts
      ..clear()
      ..addAll(storedPosts);
  }

  Future<void> close() => store.close();

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
    final interactions = await interactionService.generateInitialInteractions(
      post: seed,
      user: user,
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
      interactionStatus: interactions.usedFallback
          ? InteractionStatus.fallback
          : InteractionStatus.success,
    );

    _posts.insert(0, post);
    await store.upsertPost(post);
    return post;
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
}
