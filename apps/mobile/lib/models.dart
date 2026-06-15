import 'package:flutter/foundation.dart';
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          text == other.text &&
          listEquals(images, other.images) &&
          createdAt == other.createdAt &&
          likeCount == other.likeCount &&
          listEquals(comments, other.comments) &&
          userLiked == other.userLiked &&
          interactionStatus == other.interactionStatus;

  @override
  int get hashCode =>
      id.hashCode ^
      text.hashCode ^
      images.hashCode ^
      createdAt.hashCode ^
      likeCount.hashCode ^
      comments.hashCode ^
      userLiked.hashCode ^
      interactionStatus.hashCode;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostImageRef &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          source == other.source &&
          localRef == other.localRef &&
          thumbnailRef == other.thumbnailRef &&
          durationMillis == other.durationMillis &&
          width == other.width &&
          height == other.height &&
          sortIndex == other.sortIndex &&
          previewColor == other.previewColor;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      source.hashCode ^
      localRef.hashCode ^
      thumbnailRef.hashCode ^
      durationMillis.hashCode ^
      width.hashCode ^
      height.hashCode ^
      sortIndex.hashCode ^
      previewColor.hashCode;
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
    this.deliverAt,
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

  /// When this AI comment should become visible to the user. Null means it is
  /// already delivered (legacy data or immediate). Used for staggered, real-
  /// person-paced delivery so comments trickle in instead of appearing at once.
  final DateTime? deliverAt;

  /// True once [now] has reached this comment's scheduled delivery time.
  bool isDeliveredAt(DateTime now) =>
      deliverAt == null || !deliverAt!.isAfter(now);

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
    DateTime? deliverAt,
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
      deliverAt: deliverAt ?? this.deliverAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Comment &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          postId == other.postId &&
          actorId == other.actorId &&
          actorNameSnapshot == other.actorNameSnapshot &&
          actorAvatarSnapshot == other.actorAvatarSnapshot &&
          actorColor == other.actorColor &&
          content == other.content &&
          createdAt == other.createdAt &&
          likeCount == other.likeCount &&
          userLiked == other.userLiked &&
          listEquals(replies, other.replies) &&
          deliverAt == other.deliverAt;

  @override
  int get hashCode =>
      id.hashCode ^
      postId.hashCode ^
      actorId.hashCode ^
      actorNameSnapshot.hashCode ^
      actorAvatarSnapshot.hashCode ^
      actorColor.hashCode ^
      content.hashCode ^
      createdAt.hashCode ^
      likeCount.hashCode ^
      userLiked.hashCode ^
      replies.hashCode ^
      deliverAt.hashCode;
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalReply &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          commentId == other.commentId &&
          authorNameSnapshot == other.authorNameSnapshot &&
          authorAvatarSnapshot == other.authorAvatarSnapshot &&
          targetActorNameSnapshot == other.targetActorNameSnapshot &&
          content == other.content &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      commentId.hashCode ^
      authorNameSnapshot.hashCode ^
      authorAvatarSnapshot.hashCode ^
      targetActorNameSnapshot.hashCode ^
      content.hashCode ^
      createdAt.hashCode;
}
