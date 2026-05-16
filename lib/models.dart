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
    required this.imageColors,
    required this.createdAt,
    required this.likeCount,
    required this.comments,
  });

  final String id;
  final String text;
  final List<Color> imageColors;
  final DateTime createdAt;
  final int likeCount;
  final List<Comment> comments;

  int get commentCount => comments.length;
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
  });

  final String id;
  final String postId;
  final String actorId;
  final String actorNameSnapshot;
  final String actorAvatarSnapshot;
  final Color actorColor;
  final String content;
  final DateTime createdAt;
}
