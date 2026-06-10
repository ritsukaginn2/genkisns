import 'dart:io';

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
}
