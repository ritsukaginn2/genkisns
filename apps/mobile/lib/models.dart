import 'package:flutter/material.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.nickname,
    required this.avatarInitial,
    required this.bio,
    required this.ipLocation,
  });

  final String nickname;
  final String avatarInitial;
  final String bio;
  final String ipLocation;
}

@immutable
class AiFriend {
  const AiFriend({
    required this.id,
    required this.name,
    required this.avatarInitial,
    required this.relationship,
    required this.personality,
    required this.speakingStyle,
    required this.color,
  });

  final String id;
  final String name;
  final String avatarInitial;
  final String relationship;
  final String personality;
  final String speakingStyle;
  final Color color;
}

@immutable
class Post {
  const Post({
    required this.id,
    required this.text,
    required this.images,
    required this.createdAt,
    required this.likeCount,
    required this.comments,
    this.userLiked = false,
    this.interactionStatus = InteractionStatus.success,
  });

  final String id;
  final String text;
  final List<PostImageRef> images;
  final DateTime createdAt;
  final int likeCount;
  final List<Comment> comments;
  final bool userLiked;
  final InteractionStatus interactionStatus;

  List<Color> get imageColors => [
    for (final image in images)
      if (image.type == PostMediaType.image && image.previewColor != null)
        image.previewColor!,
  ];

  bool get hasVideo => images.any((image) => image.type == PostMediaType.video);

  int get commentCount {
    var count = comments.length;
    for (final comment in comments) {
      count += comment.replies.length;
    }
    return count;
  }

  Post copyWith({
    String? id,
    String? text,
    List<PostImageRef>? images,
    DateTime? createdAt,
    int? likeCount,
    List<Comment>? comments,
    bool? userLiked,
    InteractionStatus? interactionStatus,
  }) {
    return Post(
      id: id ?? this.id,
      text: text ?? this.text,
      images: images ?? this.images,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      comments: comments ?? this.comments,
      userLiked: userLiked ?? this.userLiked,
      interactionStatus: interactionStatus ?? this.interactionStatus,
    );
  }
}

@immutable
class PostDraft {
  const PostDraft({required this.text, required this.images});

  final String text;
  final List<PostImageRef> images;

  bool get hasContent => text.trim().isNotEmpty || images.isNotEmpty;
}

@immutable
class PostSeed {
  const PostSeed({required this.id, required this.text, required this.images});

  final String id;
  final String text;
  final List<PostImageRef> images;
}

enum PostMediaType { image, video }

enum PostImageSource { camera, album, preview }

enum InteractionStatus { success, fallback }

@immutable
class PostImageRef {
  const PostImageRef({
    required this.id,
    required this.source,
    required this.localRef,
    required this.sortIndex,
    this.type = PostMediaType.image,
    this.thumbnailRef,
    this.durationMillis,
    this.width,
    this.height,
    this.previewColor,
  });

  final String id;
  final PostMediaType type;
  final PostImageSource source;
  final String localRef;
  final String? thumbnailRef;
  final int? durationMillis;
  final int? width;
  final int? height;
  final int sortIndex;
  final Color? previewColor;

  bool get isVideo => type == PostMediaType.video;

  double get aspectRatio {
    final safeWidth = width;
    final safeHeight = height;
    if (safeWidth == null ||
        safeHeight == null ||
        safeWidth <= 0 ||
        safeHeight <= 0) {
      return isVideo ? 16 / 9 : 1;
    }
    return safeWidth / safeHeight;
  }

  static List<PostImageRef> previewColors(List<Color> colors) {
    return [
      for (var index = 0; index < colors.length; index++)
        PostImageRef(
          id: 'preview_image_$index',
          type: PostMediaType.image,
          source: PostImageSource.preview,
          localRef: 'preview://image/$index',
          sortIndex: index,
          previewColor: colors[index],
        ),
    ];
  }
}

@immutable
class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.actorId,
    required this.actorNameSnapshot,
    required this.actorAvatarSnapshot,
    required this.actorColor,
    required this.content,
    required this.createdAt,
    this.likeCount = 12,
    this.userLiked = false,
    this.replies = const [],
  });

  final String id;
  final String postId;
  final String actorId;
  final String actorNameSnapshot;
  final String actorAvatarSnapshot;
  final Color actorColor;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final bool userLiked;
  final List<LocalReply> replies;

  Comment copyWith({
    String? id,
    String? postId,
    String? actorId,
    String? actorNameSnapshot,
    String? actorAvatarSnapshot,
    Color? actorColor,
    String? content,
    DateTime? createdAt,
    int? likeCount,
    bool? userLiked,
    List<LocalReply>? replies,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      actorId: actorId ?? this.actorId,
      actorNameSnapshot: actorNameSnapshot ?? this.actorNameSnapshot,
      actorAvatarSnapshot: actorAvatarSnapshot ?? this.actorAvatarSnapshot,
      actorColor: actorColor ?? this.actorColor,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      userLiked: userLiked ?? this.userLiked,
      replies: replies ?? this.replies,
    );
  }
}

@immutable
class LocalReply {
  const LocalReply({
    required this.id,
    required this.commentId,
    required this.authorNameSnapshot,
    required this.authorAvatarSnapshot,
    required this.targetActorNameSnapshot,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String commentId;
  final String authorNameSnapshot;
  final String authorAvatarSnapshot;
  final String targetActorNameSnapshot;
  final String content;
  final DateTime createdAt;
}
