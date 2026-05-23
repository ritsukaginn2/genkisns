import 'package:flutter/material.dart';

import 'mock/mock_data.dart';
import 'models.dart';
import 'pages/about_page.dart';
import 'pages/board_preview_page.dart';
import 'pages/create_post_page.dart';
import 'pages/friends_page.dart';
import 'pages/design_directions_page.dart';
import 'pages/home_page.dart';
import 'pages/post_detail_page.dart';
import 'pages/profile_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GenkiSnsApp());
}

class GenkiSnsApp extends StatefulWidget {
  const GenkiSnsApp({super.key});

  @override
  State<GenkiSnsApp> createState() => _GenkiSnsAppState();
}

class _GenkiSnsAppState extends State<GenkiSnsApp> {
  final UserProfile user = defaultUser;
  final List<String> selectedFriendIds = presetFriends
      .take(5)
      .map((friend) => friend.id)
      .toList();
  final posts = <Post>[];

  List<AiFriend> get selectedFriends {
    if (selectedFriendIds.isEmpty) {
      return presetFriends;
    }
    return presetFriends
        .where((friend) => selectedFriendIds.contains(friend.id))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final view = uri.queryParameters['view'];
    final fragment = uri.fragment;

    final Widget home;
    if (fragment == '/designs' || fragment == 'designs' || view == 'designs') {
      home = const DesignDirectionsPage(showAppBar: true);
    } else {
      home = switch (view) {
        'home' => HomePage(
          user: defaultUser,
          posts: mockPosts,
          onOpenPost: (_) {},
          onCreatePost: () {},
          onOpenProfile: () {},
        ),
        'home-empty' => HomePage(
          user: defaultUser,
          posts: const [],
          onOpenPost: (_) {},
          onCreatePost: () {},
          onOpenProfile: () {},
        ),
        'create' => CreatePostPage(onPublish: (_) {}),
        'create-images' => CreatePostPage(
          onPublish: (_) {},
          initialText: '今天买到喜欢很久的小东西，想偷偷炫耀一下。',
          initialImageColors: const [
            AppColors.coral,
            AppColors.teal,
            AppColors.blue,
          ],
        ),
        'create-full' => CreatePostPage(
          onPublish: (_) {},
          initialText: '九宫格快乐存档。每一张都想被认真看见。',
          initialImageColors: const [
            AppColors.coral,
            AppColors.teal,
            AppColors.blue,
            AppColors.yellow,
            Color(0xFF8E6BBE),
            Color(0xFF5E8C61),
            Color(0xFFB95D7A),
            Color(0xFF668DA8),
            Color(0xFFB27C46),
          ],
        ),
        'detail' => PostDetailPage(post: mockPosts.first),
        'detail-text' => PostDetailPage(post: mockPosts.last),
        'detail-liked' => PostDetailPage(
          post: mockPosts.first,
          initialPostLiked: true,
        ),
        'detail-comment-liked' => PostDetailPage(
          post: mockPosts.first,
          initialLikedCommentIds: {'c1'},
        ),
        'detail-reply' => PostDetailPage(
          post: mockPosts.first,
          initialReplyTargetCommentId: 'c1',
        ),
        'profile' => ProfilePage(
          user: defaultUser,
          friends: presetFriends.take(5).toList(),
          postCount: mockPosts.length,
          onOpenAbout: () {},
          onOpenUiLab: () {},
          onOpenFriends: () {},
        ),
        'about' => const AboutPage(),
        'friends' => FriendsPage(friends: presetFriends.take(5).toList()),
        'board-navigation' => const BoardPreviewPage(
          kind: BoardPreviewKind.navigation,
        ),
        'board-feedback' => const BoardPreviewPage(
          kind: BoardPreviewKind.feedback,
        ),
        'board-components' => const BoardPreviewPage(
          kind: BoardPreviewKind.components,
        ),
        'board-components-core' => const BoardPreviewPage(
          kind: BoardPreviewKind.componentsCore,
        ),
        'board-components-content' => const BoardPreviewPage(
          kind: BoardPreviewKind.componentsContent,
        ),
        _ => GenkiShell(
          user: user,
          friends: selectedFriends,
          posts: posts,
          onPostCreated: _addPost,
        ),
      };
    }

    return MaterialApp(
      title: 'GenkiSNS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => home),
    );
  }

  Post _addPost(PostDraft draft) {
    final now = DateTime.now();
    final postSeed = PostSeed(
      id: 'post_${now.microsecondsSinceEpoch}',
      text: draft.text,
      imageColors: draft.imageColors,
    );
    final comments = generateFallbackComments(
      post: postSeed,
      friends: selectedFriends,
      now: now,
    );
    final post = Post(
      id: postSeed.id,
      text: postSeed.text,
      imageColors: postSeed.imageColors,
      createdAt: now,
      likeCount: selectedFriends.length + 12,
      comments: comments,
    );

    setState(() => posts.insert(0, post));
    return post;
  }
}

class GenkiShell extends StatefulWidget {
  const GenkiShell({
    super.key,
    required this.user,
    required this.friends,
    required this.posts,
    required this.onPostCreated,
  });

  final UserProfile user;
  final List<AiFriend> friends;
  final List<Post> posts;
  final Post Function(PostDraft draft) onPostCreated;

  @override
  State<GenkiShell> createState() => _GenkiShellState();
}

class _GenkiShellState extends State<GenkiShell> {
  @override
  Widget build(BuildContext context) {
    return HomePage(
      user: widget.user,
      posts: widget.posts,
      onOpenPost: _openPost,
      onCreatePost: _openCreatePost,
      onOpenProfile: _openProfile,
    );
  }

  void _publishPost(PostDraft draft) {
    widget.onPostCreated(draft);
    setState(() {});
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(milliseconds: 1600),
        content: Text('已发布，AI 评论会陆续出现'),
      ),
    );
  }

  void _openCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePostPage(onPublish: _publishPost),
      ),
    );
  }

  void _openPost(Post post) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PostDetailPage(post: post)));
  }

  void _openProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          user: widget.user,
          friends: widget.friends,
          postCount: widget.posts.length,
          onOpenAbout: _openAbout,
          onOpenUiLab: _openUiLab,
          onOpenFriends: _openFriends,
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const AboutPage()));
  }

  void _openUiLab() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const DesignDirectionsPage(showAppBar: true),
      ),
    );
  }

  void _openFriends() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FriendsPage(friends: widget.friends),
      ),
    );
  }
}
