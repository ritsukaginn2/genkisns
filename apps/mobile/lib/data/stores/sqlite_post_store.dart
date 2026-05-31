import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../models.dart';
import 'post_store.dart';

class SqlitePostStore implements PostStore {
  SqlitePostStore._(this._database);

  final Database _database;

  static Future<SqlitePostStore> open() async {
    final databasePath = await getDatabasesPath();
    final path = p.join(databasePath, 'genki_sns_v1.db');
    final database = await openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE posts (
            id TEXT PRIMARY KEY,
            text TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            like_count INTEGER NOT NULL,
            user_liked INTEGER NOT NULL,
            interaction_status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE post_images (
            id TEXT NOT NULL,
            post_id TEXT NOT NULL,
            type TEXT NOT NULL DEFAULT 'image',
            source TEXT NOT NULL,
            local_ref TEXT NOT NULL,
            thumbnail_ref TEXT,
            duration_millis INTEGER,
            sort_index INTEGER NOT NULL,
            preview_color INTEGER,
            PRIMARY KEY (post_id, id),
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE comments (
            id TEXT NOT NULL,
            post_id TEXT NOT NULL,
            actor_id TEXT NOT NULL,
            actor_name_snapshot TEXT NOT NULL,
            actor_avatar_snapshot TEXT NOT NULL,
            actor_color INTEGER NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            like_count INTEGER NOT NULL,
            user_liked INTEGER NOT NULL,
            PRIMARY KEY (post_id, id),
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE local_replies (
            id TEXT NOT NULL,
            post_id TEXT NOT NULL,
            comment_id TEXT NOT NULL,
            author_name_snapshot TEXT NOT NULL,
            author_avatar_snapshot TEXT NOT NULL,
            target_actor_name_snapshot TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            PRIMARY KEY (post_id, comment_id, id),
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE post_images ADD COLUMN type TEXT NOT NULL DEFAULT 'image'",
          );
          await db.execute(
            'ALTER TABLE post_images ADD COLUMN thumbnail_ref TEXT',
          );
          await db.execute(
            'ALTER TABLE post_images ADD COLUMN duration_millis INTEGER',
          );
        }
      },
    );
    return SqlitePostStore._(database);
  }

  @override
  Future<List<Post>> loadPosts() async {
    final postRows = await _database.query('posts', orderBy: 'created_at DESC');
    final posts = <Post>[];
    for (final row in postRows) {
      final postId = row['id'] as String;
      final images = await _loadImages(postId);
      final comments = await _loadComments(postId);
      posts.add(
        Post(
          id: postId,
          text: row['text'] as String,
          images: images,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
          likeCount: row['like_count'] as int,
          comments: comments,
          userLiked: (row['user_liked'] as int) == 1,
          interactionStatus: _decodeInteractionStatus(
            row['interaction_status'] as String,
          ),
        ),
      );
    }
    return List.unmodifiable(posts);
  }

  @override
  Future<void> upsertPost(Post post) async {
    await _database.transaction((txn) async {
      await txn.insert(
        'posts',
        _postRow(post),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'post_images',
        where: 'post_id = ?',
        whereArgs: [post.id],
      );
      await txn.delete(
        'local_replies',
        where: 'post_id = ?',
        whereArgs: [post.id],
      );
      await txn.delete('comments', where: 'post_id = ?', whereArgs: [post.id]);

      for (final image in post.images) {
        await txn.insert('post_images', _imageRow(post.id, image));
      }
      for (final comment in post.comments) {
        await txn.insert('comments', _commentRow(comment));
        for (final reply in comment.replies) {
          await txn.insert('local_replies', _replyRow(post.id, reply));
        }
      }
    });
  }

  @override
  Future<void> close() => _database.close();

  Future<List<PostImageRef>> _loadImages(String postId) async {
    final rows = await _database.query(
      'post_images',
      where: 'post_id = ?',
      whereArgs: [postId],
      orderBy: 'sort_index ASC',
    );
    return [
      for (final row in rows)
        PostImageRef(
          id: row['id'] as String,
          type: _decodeMediaType(row['type'] as String?),
          source: _decodeImageSource(row['source'] as String),
          localRef: row['local_ref'] as String,
          thumbnailRef: row['thumbnail_ref'] as String?,
          durationMillis: row['duration_millis'] as int?,
          sortIndex: row['sort_index'] as int,
          previewColor: _colorFromInt(row['preview_color'] as int?),
        ),
    ];
  }

  Future<List<Comment>> _loadComments(String postId) async {
    final rows = await _database.query(
      'comments',
      where: 'post_id = ?',
      whereArgs: [postId],
      orderBy: 'created_at ASC',
    );
    final comments = <Comment>[];
    for (final row in rows) {
      final commentId = row['id'] as String;
      comments.add(
        Comment(
          id: commentId,
          postId: postId,
          actorId: row['actor_id'] as String,
          actorNameSnapshot: row['actor_name_snapshot'] as String,
          actorAvatarSnapshot: row['actor_avatar_snapshot'] as String,
          actorColor: Color(row['actor_color'] as int),
          content: row['content'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
          likeCount: row['like_count'] as int,
          userLiked: (row['user_liked'] as int) == 1,
          replies: await _loadReplies(postId: postId, commentId: commentId),
        ),
      );
    }
    return comments;
  }

  Future<List<LocalReply>> _loadReplies({
    required String postId,
    required String commentId,
  }) async {
    final rows = await _database.query(
      'local_replies',
      where: 'post_id = ? AND comment_id = ?',
      whereArgs: [postId, commentId],
      orderBy: 'created_at ASC',
    );
    return [
      for (final row in rows)
        LocalReply(
          id: row['id'] as String,
          commentId: commentId,
          authorNameSnapshot: row['author_name_snapshot'] as String,
          authorAvatarSnapshot: row['author_avatar_snapshot'] as String,
          targetActorNameSnapshot: row['target_actor_name_snapshot'] as String,
          content: row['content'] as String,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            row['created_at'] as int,
          ),
        ),
    ];
  }

  Map<String, Object?> _postRow(Post post) {
    return {
      'id': post.id,
      'text': post.text,
      'created_at': post.createdAt.millisecondsSinceEpoch,
      'like_count': post.likeCount,
      'user_liked': post.userLiked ? 1 : 0,
      'interaction_status': post.interactionStatus.name,
    };
  }

  Map<String, Object?> _imageRow(String postId, PostImageRef image) {
    return {
      'id': image.id,
      'post_id': postId,
      'type': image.type.name,
      'source': image.source.name,
      'local_ref': image.localRef,
      'thumbnail_ref': image.thumbnailRef,
      'duration_millis': image.durationMillis,
      'sort_index': image.sortIndex,
      'preview_color': _colorToInt(image.previewColor),
    };
  }

  Map<String, Object?> _commentRow(Comment comment) {
    return {
      'id': comment.id,
      'post_id': comment.postId,
      'actor_id': comment.actorId,
      'actor_name_snapshot': comment.actorNameSnapshot,
      'actor_avatar_snapshot': comment.actorAvatarSnapshot,
      'actor_color': comment.actorColor.toARGB32(),
      'content': comment.content,
      'created_at': comment.createdAt.millisecondsSinceEpoch,
      'like_count': comment.likeCount,
      'user_liked': comment.userLiked ? 1 : 0,
    };
  }

  Map<String, Object?> _replyRow(String postId, LocalReply reply) {
    return {
      'id': reply.id,
      'post_id': postId,
      'comment_id': reply.commentId,
      'author_name_snapshot': reply.authorNameSnapshot,
      'author_avatar_snapshot': reply.authorAvatarSnapshot,
      'target_actor_name_snapshot': reply.targetActorNameSnapshot,
      'content': reply.content,
      'created_at': reply.createdAt.millisecondsSinceEpoch,
    };
  }

  int? _colorToInt(Color? color) => color?.toARGB32();

  Color? _colorFromInt(int? value) => value == null ? null : Color(value);

  PostImageSource _decodeImageSource(String value) {
    return PostImageSource.values.firstWhere(
      (source) => source.name == value,
      orElse: () => PostImageSource.preview,
    );
  }

  PostMediaType _decodeMediaType(String? value) {
    return PostMediaType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PostMediaType.image,
    );
  }

  InteractionStatus _decodeInteractionStatus(String value) {
    return InteractionStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => InteractionStatus.fallback,
    );
  }
}
