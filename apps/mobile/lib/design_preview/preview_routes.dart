import 'package:flutter/material.dart';

import '../mock/mock_data.dart';
import '../pages/about_page.dart';
import '../pages/create_post_page.dart';
import '../pages/design_directions_page.dart';
import '../pages/friends_page.dart';
import '../pages/home_page.dart';
import '../pages/post_detail_page.dart';
import '../pages/profile_page.dart';
import '../theme/app_theme.dart';
import 'board_preview_page.dart';

Widget? buildPreviewRoute({required String? view, required String fragment}) {
  if (fragment == '/designs' || fragment == 'designs' || view == 'designs') {
    return const DesignDirectionsPage(showAppBar: true);
  }

  return switch (view) {
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
    'create' => CreatePostPage(onPublish: (_) {}, useMockMediaPicker: true),
    'create-image-source' => CreatePostPage(
      onPublish: (_) {},
      initialShowImageSourceSheet: true,
      useMockMediaPicker: true,
    ),
    'create-album-picker' => CreatePostPage(
      onPublish: (_) {},
      initialShowAlbumPicker: true,
      useMockMediaPicker: true,
    ),
    'create-album-reopen' => CreatePostPage(
      onPublish: (_) {},
      initialText: '写到一半又想再补几张照片。',
      initialImageColors: const [
        Color(0xFFDF7F5F),
        Color(0xFF4A8C85),
        Color(0xFF4C6F9D),
      ],
      initialShowAlbumPicker: true,
      useMockMediaPicker: true,
    ),
    'create-images' => CreatePostPage(
      onPublish: (_) {},
      initialText: '今天买到喜欢很久的小东西，想偷偷炫耀一下。',
      initialImageColors: const [
        AppColors.coral,
        AppColors.teal,
        AppColors.blue,
      ],
      useMockMediaPicker: true,
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
      useMockMediaPicker: true,
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
    'detail-replied' => PostDetailPage(
      post: mockPosts.first,
      initialUserRepliesByCommentId: const {
        'c1': ['我也很喜欢这个感觉。'],
      },
    ),
    'detail-reply-delete' => PostDetailPage(
      post: mockPosts.first,
      initialUserRepliesByCommentId: const {
        'c1': ['我也很喜欢这个感觉。'],
      },
      initialShowReplyDeleteConfirmation: true,
    ),
    'detail-reply-deleted' => PostDetailPage(
      post: mockPosts.first,
      initialUserRepliesByCommentId: const {},
    ),
    'profile' => ProfilePage(
      user: defaultUser,
      friends: presetFriends.take(5).toList(),
      postCount: mockPosts.length,
      onOpenAbout: () {},
      onOpenUiLab: () {},
      onOpenFriends: () {},
      onOpenICloudBackup: () {},
      onClearLocalContent: () async {},
    ),
    'about' => const AboutPage(),
    'friends' => FriendsPage(friends: presetFriends.take(5).toList()),
    'board-navigation' => const BoardPreviewPage(
      kind: BoardPreviewKind.navigation,
    ),
    'board-feedback' => const BoardPreviewPage(kind: BoardPreviewKind.feedback),
    'board-components' => const BoardPreviewPage(
      kind: BoardPreviewKind.components,
    ),
    'board-components-core' => const BoardPreviewPage(
      kind: BoardPreviewKind.componentsCore,
    ),
    'board-components-content' => const BoardPreviewPage(
      kind: BoardPreviewKind.componentsContent,
    ),
    _ => null,
  };
}
