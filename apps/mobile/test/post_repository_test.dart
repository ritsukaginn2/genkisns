import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/data/repositories/ai_friend_repository.dart';
import 'package:genki_sns/data/repositories/post_repository.dart';
import 'package:genki_sns/data/repositories/user_repository.dart';
import 'package:genki_sns/data/services/interaction_service.dart';
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
}
