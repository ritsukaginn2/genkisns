import 'package:flutter/material.dart';

import 'mock/mock_data.dart';
import 'models.dart';
import 'pages/about_page.dart';
import 'pages/create_post_page.dart';
import 'pages/friends_page.dart';
import 'pages/onboarding_page.dart';
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
      home = const DesignDirectionsPage();
    } else {
      home = switch (view) {
        'home' => HomePage(
            user: defaultUser,
            posts: mockPosts,
            onOpenPost: (_) {},
            onCreatePost: () {},
          ),
        'home-empty' => HomePage(
            user: defaultUser,
            posts: const [],
            onOpenPost: (_) {},
            onCreatePost: () {},
          ),
        'create' => CreatePostPage(onPublish: (_) {}),
        'detail' => PostDetailPage(post: mockPosts.first),
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
        'onboarding-1' => OnboardingPage(
            initialStep: 0,
            onComplete: (u, f) {},
          ),
        'onboarding-2' => OnboardingPage(
            initialStep: 1,
            onComplete: (u, f) {},
          ),
        'onboarding-3' => OnboardingPage(
            initialStep: 2,
            onComplete: (u, f) {},
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
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomePage(
        user: widget.user,
        posts: widget.posts,
        onOpenPost: _openPost,
        onCreatePost: () => setState(() => currentIndex = 1),
      ),
      CreatePostPage(onPublish: _publishPost),
      ProfilePage(
        user: widget.user,
        friends: widget.friends,
        postCount: widget.posts.length,
        onOpenAbout: _openAbout,
        onOpenUiLab: _openUiLab,
        onOpenFriends: _openFriends,
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '首页',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: '发布',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: '我的',
          ),
        ],
      ),
    );
  }

  void _publishPost(PostDraft draft) {
    widget.onPostCreated(draft);
    setState(() => currentIndex = 0);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已发布，AI 评论会陆续出现')));
  }

  void _openPost(Post post) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => PostDetailPage(post: post)));
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
