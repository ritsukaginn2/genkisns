import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/data/stores/sqlite_post_store.dart';
import 'package:genki_sns/models.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dbPath = p.join(await getDatabasesPath(), 'genki_sns_v1.db');
    await deleteDatabase(dbPath);
  });

  test(
    'persists posts with images, likes, comments and local replies',
    () async {
      final store = await SqlitePostStore.open();
      final post = Post(
        id: 'post_1',
        text: '本地保存测试',
        images: const [
          PostImageRef(
            id: 'image_1',
            source: PostImageSource.album,
            localRef: '/tmp/a.jpg',
            sortIndex: 0,
            previewColor: Colors.pink,
          ),
          PostImageRef(
            id: 'video_1',
            type: PostMediaType.video,
            source: PostImageSource.camera,
            localRef: '/tmp/a.mov',
            thumbnailRef: '/tmp/a_thumb.jpg',
            durationMillis: 23000,
            sortIndex: 1,
          ),
        ],
        createdAt: DateTime(2026, 5, 24, 22),
        likeCount: 18,
        userLiked: true,
        interactionStatus: InteractionStatus.fallback,
        comments: [
          Comment(
            id: 'comment_1',
            postId: 'post_1',
            actorId: 'friend_mika',
            actorNameSnapshot: '美香',
            actorAvatarSnapshot: '美',
            actorColor: Colors.orange,
            content: '已经存好了。',
            createdAt: DateTime(2026, 5, 24, 22, 1),
            likeCount: 3,
            userLiked: true,
            replies: [
              LocalReply(
                id: 'reply_1',
                commentId: 'comment_1',
                authorNameSnapshot: 'Ritsuka',
                authorAvatarSnapshot: 'R',
                targetActorNameSnapshot: '美香',
                content: '收到。',
                createdAt: DateTime(2026, 5, 24, 22, 2),
              ),
            ],
          ),
        ],
      );

      await store.upsertPost(post);
      await store.close();

      final reopenedStore = await SqlitePostStore.open();
      addTearDown(reopenedStore.close);
      final posts = await reopenedStore.loadPosts();

      expect(posts.single.text, '本地保存测试');
      expect(posts.single.images.first.localRef, '/tmp/a.jpg');
      expect(posts.single.images.last.type, PostMediaType.video);
      expect(posts.single.images.last.thumbnailRef, '/tmp/a_thumb.jpg');
      expect(posts.single.images.last.durationMillis, 23000);
      expect(posts.single.userLiked, isTrue);
      expect(posts.single.interactionStatus, InteractionStatus.fallback);
      expect(posts.single.comments.single.userLiked, isTrue);
      expect(posts.single.comments.single.replies.single.content, '收到。');
    },
  );
}
