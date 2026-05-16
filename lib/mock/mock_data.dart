import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';

const defaultUser = UserProfile(
  nickname: 'Ritsuka',
  avatarInitial: 'R',
  bio: '把真实 SNS 不方便发的快乐，先存在这里。',
  ipLocation: '发布时自动识别',
);

const presetFriends = [
  AiFriend(
    id: 'friend_mika',
    name: '美香',
    avatarInitial: '美',
    relationship: '高中同学',
    personality: '会夸、爱起哄',
    speakingStyle: '像很熟的老朋友，句子短，反应快。',
    color: AppColors.coral,
  ),
  AiFriend(
    id: 'friend_qiao',
    name: '乔乔',
    avatarInitial: '乔',
    relationship: '毒舌闺蜜',
    personality: '嘴硬心软、精准吐槽',
    speakingStyle: '先损一句，再认真夸。',
    color: AppColors.teal,
  ),
  AiFriend(
    id: 'friend_sen',
    name: '森也',
    avatarInitial: '森',
    relationship: '暧昧学长',
    personality: '温柔、细节控',
    speakingStyle: '语气克制，但会注意到细节。',
    color: AppColors.blue,
  ),
  AiFriend(
    id: 'friend_aki',
    name: 'Aki',
    avatarInitial: 'A',
    relationship: '技术宅前同事',
    personality: '理性、偶尔冷笑话',
    speakingStyle: '像认真看完内容后给反馈。',
    color: AppColors.yellow,
  ),
  AiFriend(
    id: 'friend_lan',
    name: '岚姐',
    avatarInitial: '岚',
    relationship: '热心姐姐',
    personality: '温暖、生活感强',
    speakingStyle: '会关心体验，也会自然夸一句。',
    color: Color(0xFF8E6BBE),
  ),
  AiFriend(
    id: 'friend_yui',
    name: '由衣',
    avatarInitial: '由',
    relationship: '旅行搭子',
    personality: '兴奋、爱问细节',
    speakingStyle: '会像刚看到朋友圈一样追问地点和体验。',
    color: Color(0xFFB95D7A),
  ),
  AiFriend(
    id: 'friend_ren',
    name: 'Ren',
    avatarInitial: 'R',
    relationship: '网友',
    personality: '松弛、会玩梗',
    speakingStyle: '评论像路过但很会接梗的网友。',
    color: Color(0xFF5E8C61),
  ),
  AiFriend(
    id: 'friend_momo',
    name: '桃子',
    avatarInitial: '桃',
    relationship: '前同事',
    personality: '细腻、审美在线',
    speakingStyle: '会注意照片、语气和生活质感。',
    color: Color(0xFFB27C46),
  ),
];

List<Comment> generateFallbackComments({
  required PostSeed post,
  required List<AiFriend> friends,
  required DateTime now,
}) {
  final selectedFriends = friends.take(5).toList();
  final templates = [
    '这条真的很适合发出来，被我刷到会停下来看的那种。',
    '懂你想分享这个的心情了，质感好好。',
    '有点太会生活了吧，今天的快乐浓度超标。',
    '这不发出来可惜了，应该多来几张。',
    '我宣布这条已经赢了，氛围感很在线。',
  ];

  return [
    for (var index = 0; index < selectedFriends.length; index++)
      Comment(
        id: 'comment_${post.id}_$index',
        postId: post.id,
        actorId: selectedFriends[index].id,
        actorNameSnapshot: selectedFriends[index].name,
        actorAvatarSnapshot: selectedFriends[index].avatarInitial,
        actorColor: selectedFriends[index].color,
        content: templates[index % templates.length],
        createdAt: now.add(Duration(seconds: 6 + index * 18)),
      ),
  ];
}

final mockPosts = <Post>[
  Post(
    id: 'preview_1',
    text: '心心念念几个月的东西终于到手了。不想发到真社交，但还是想被看见一下。',
    imageColors: [AppColors.teal, Color(0xFF9BC5FF)],
    createdAt: DateTime(2026, 5, 10, 14, 22),
    likeCount: 18,
    comments: [
      Comment(id: 'c1', postId: 'preview_1', actorId: 'friend_mika', actorNameSnapshot: '美香', actorAvatarSnapshot: '美', actorColor: AppColors.coral, content: '这个颜色太适合你了', createdAt: DateTime(2026, 5, 10, 14, 28)),
      Comment(id: 'c2', postId: 'preview_1', actorId: 'friend_sen', actorNameSnapshot: '森也', actorAvatarSnapshot: '森', actorColor: AppColors.blue, content: '第一张有种安静的光感，很配你。', createdAt: DateTime(2026, 5, 10, 14, 35)),
      Comment(id: 'c3', postId: 'preview_1', actorId: 'friend_qiao', actorNameSnapshot: '乔乔', actorAvatarSnapshot: '乔', actorColor: AppColors.teal, content: '不发出来才可惜了，必须让我看到。', createdAt: DateTime(2026, 5, 10, 14, 52)),
    ],
  ),
  Post(
    id: 'preview_2',
    text: '咖啡、干净的桌面、新袜子。小幸福存档。',
    imageColors: [Color(0xFFFFB6D1)],
    createdAt: DateTime(2026, 5, 9, 9, 14),
    likeCount: 9,
    comments: [
      Comment(id: 'c4', postId: 'preview_2', actorId: 'friend_aki', actorNameSnapshot: 'Aki', actorAvatarSnapshot: 'A', actorColor: AppColors.yellow, content: '稳稳的小幸福。', createdAt: DateTime(2026, 5, 9, 9, 20)),
    ],
  ),
  Post(
    id: 'preview_3',
    text: '今晚做了一锅很努力的汤。没人知道我花了两个小时，但我知道。',
    imageColors: [Color(0xFFFFD166), AppColors.coral],
    createdAt: DateTime(2026, 5, 8, 20, 7),
    likeCount: 24,
    comments: [
      Comment(id: 'c5', postId: 'preview_3', actorId: 'friend_lan', actorNameSnapshot: '岚姐', actorAvatarSnapshot: '岚', actorColor: Color(0xFF8E6BBE), content: '认真过日子的能量感，爱了。', createdAt: DateTime(2026, 5, 8, 20, 15)),
      Comment(id: 'c6', postId: 'preview_3', actorId: 'friend_mika', actorNameSnapshot: '美香', actorAvatarSnapshot: '美', actorColor: AppColors.coral, content: '两小时值了，这种事只有自己懂。', createdAt: DateTime(2026, 5, 8, 20, 31)),
    ],
  ),
  Post(
    id: 'preview_4',
    text: '买了那件外套。镜子说可以。',
    imageColors: [],
    createdAt: DateTime(2026, 5, 7, 16, 44),
    likeCount: 12,
    comments: [
      Comment(id: 'c7', postId: 'preview_4', actorId: 'friend_qiao', actorNameSnapshot: '乔乔', actorAvatarSnapshot: '乔', actorColor: AppColors.teal, content: '镜子不会骗你的。', createdAt: DateTime(2026, 5, 7, 16, 50)),
    ],
  ),
];

@immutable
class PostSeed {
  const PostSeed({
    required this.id,
    required this.text,
    required this.imageColors,
  });

  final String id;
  final String text;
  final List<Color> imageColors;
}
