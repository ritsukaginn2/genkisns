import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/repositories/ai_friend_repository.dart';
import 'data/repositories/post_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/services/data_export_service.dart';
import 'data/services/iap_service.dart';
import 'data/services/icloud_backup_service.dart';
import 'data/services/interaction_service.dart';
import 'data/services/llm_client.dart';
import 'data/stores/post_store.dart';
import 'data/stores/sqlite_post_store.dart';
import 'design_preview/preview_routes.dart';
import 'models.dart';
import 'pages/about_page.dart';
import 'pages/create_post_page.dart';
import 'pages/design_directions_page.dart';
import 'pages/friends_page.dart';
import 'pages/home_page.dart';
import 'pages/icloud_backup_page.dart';
import 'pages/post_detail_page.dart';
import 'pages/profile_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const GenkiSnsApp());
}

typedef PostStoreFactory = Future<PostStore> Function();

class GenkiSnsApp extends StatefulWidget {
  const GenkiSnsApp({super.key, this.postStoreFactory});

  final PostStoreFactory? postStoreFactory;

  @override
  State<GenkiSnsApp> createState() => _GenkiSnsAppState();
}

class _GenkiSnsAppState extends State<GenkiSnsApp> {
  late final UserRepository userRepository;
  late final AiFriendRepository aiFriendRepository;
  final iCloudBackupService = const ICloudBackupService();
  final dataExportService = const DataExportService();
  final llmClient = LLMClient();
  late final IAPService iapService;
  PostRepository? postRepository;
  Timer? iCloudBackupDebounce;
  Object? loadError;

  @override
  void initState() {
    super.initState();
    userRepository = const UserRepository();
    aiFriendRepository = AiFriendRepository();
    iapService = IAPService(llmClient: llmClient);
    _initializeDataLayer();
  }

  void _startBackgroundICloudRestore() {
    // Restore iCloud data in background without blocking startup
    unawaited(
      iCloudBackupService.restoreIfLocalDataMissing().then((_) {
        if (mounted && postRepository != null) {
          // Refresh post list if restore was successful
          setState(() {});
        }
      }).catchError((e) {
        // Silently log errors - don't show to user unless they manually trigger restore
        debugPrint('Background iCloud restore error: $e');
      }),
    );
  }

  @override
  void dispose() {
    iCloudBackupDebounce?.cancel();
    postRepository?.close();
    iapService.dispose();
    super.dispose();
  }

  Future<void> _initializeDataLayer() async {
    try {
      // Initialize LLM client first
      await llmClient.init();

      // Initialize IAP
      await iapService.init();

      final storeFactory = widget.postStoreFactory ?? _defaultPostStoreFactory;
      final store = await storeFactory();
      final repository = PostRepository(
        interactionService: InteractionService(llmClient: llmClient),
        store: store,
      );
      await repository.load();
      if (!mounted) {
        await repository.close();
        return;
      }
      setState(() => postRepository = repository);

      // Start iCloud restore in background after UI is ready (don't block startup)
      if (!kIsWeb && widget.postStoreFactory == null) {
        _startBackgroundICloudRestore();
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => loadError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uri = Uri.base;
    final view = uri.queryParameters['view'];
    final fragment = uri.fragment;

    final previewRoute = buildPreviewRoute(view: view, fragment: fragment);
    final home =
        previewRoute ??
        (postRepository == null
            ? _StartupState(error: loadError)
            : GenkiShell(
                user: userRepository.getDefaultUser(),
                friends: selectedFriends,
                posts: posts,
                onPostCreated: _addPost,
                onTogglePostLike: _togglePostLike,
                onToggleCommentLike: _toggleCommentLike,
                onAddLocalReply: _addLocalReply,
                onDeleteLocalReply: _deleteLocalReply,
                onDeletePost: _deletePost,
                onLoadICloudBackupStatus: iCloudBackupService.status,
                onSetICloudSyncEnabled: _setICloudSyncEnabled,
                onClearLocalContent: _clearLocalContent,
                onExportData: _exportData,
                llmClient: llmClient,
                iapService: iapService,
              ));

    return MaterialApp(
      title: 'GenkiSNS',
      debugShowCheckedModeBanner: false,
      locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
      supportedLocales: const [
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: AppTheme.light(),
      home: home,
    );
  }

  List<AiFriend> get selectedFriends =>
      aiFriendRepository.listSelectedFriends();

  List<Post> get posts => postRepository?.listPosts() ?? const [];

  Future<Post> _addPost(PostDraft draft) async {
    final post = await postRepository!.createPost(
      draft,
      user: userRepository.getDefaultUser(),
      friends: selectedFriends,
    );
    setState(() {});
    _scheduleICloudBackup();
    return post;
  }

  Future<Post> _togglePostLike(String postId) async {
    final post = await postRepository!.togglePostLike(postId);
    setState(() {});
    _scheduleICloudBackup();
    return post;
  }

  Future<Post> _toggleCommentLike(String postId, String commentId) async {
    final post = await postRepository!.toggleCommentLike(
      postId: postId,
      commentId: commentId,
    );
    setState(() {});
    _scheduleICloudBackup();
    return post;
  }

  Future<Post> _addLocalReply(
    String postId,
    String commentId,
    String content,
  ) async {
    final post = await postRepository!.addLocalReply(
      postId: postId,
      commentId: commentId,
      user: userRepository.getDefaultUser(),
      content: content,
    );
    setState(() {});
    _scheduleICloudBackup();
    return post;
  }

  Future<Post> _deleteLocalReply(
    String postId,
    String commentId,
    String replyId,
  ) async {
    final post = await postRepository!.deleteLocalReply(
      postId: postId,
      commentId: commentId,
      replyId: replyId,
    );
    setState(() {});
    _scheduleICloudBackup();
    return post;
  }

  Future<void> _deletePost(String postId) async {
    await postRepository!.deletePost(postId);
    setState(() {});
    _scheduleICloudBackup();
  }

  Future<void> _clearLocalContent() async {
    // Cancel any pending auto-backup so it can't run mid-clear, and leave the
    // iCloud backup untouched — this wipes local content only.
    iCloudBackupDebounce?.cancel();
    await postRepository?.clearAllPosts();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _exportData() async {
    try {
      final posts = postRepository?.listPosts() ?? [];
      final file = await dataExportService.exportPostsAsJson(posts);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已导出数据到: ${file.path.split('/').last}'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败: $e')),
      );
    }
  }

  Future<ICloudBackupStatus> _setICloudSyncEnabled(bool enabled) async {
    iCloudBackupDebounce?.cancel();
    await iCloudBackupService.setSyncEnabled(enabled);
    if (!enabled) {
      return iCloudBackupService.status();
    }

    // Direction-aware turn-on: if this device has nothing yet but the cloud
    // does, pull it down instead of overwriting the cloud backup with an empty
    // state. Otherwise push the current local state up.
    final localEmpty = postRepository?.listPosts().isEmpty ?? true;
    final cloudStatus = await iCloudBackupService.status();
    if (localEmpty && cloudStatus.available && cloudStatus.hasBackup) {
      return _restoreFromICloud();
    }

    try {
      await postRepository?.prepareForBackup();
      await iCloudBackupService.backupNow();
    } on Object {
      // Surface availability via status() below rather than throwing.
    }
    return iCloudBackupService.status();
  }

  Future<ICloudBackupStatus> _restoreFromICloud() async {
    iCloudBackupDebounce?.cancel();
    await postRepository?.close();
    if (mounted) {
      setState(() {
        postRepository = null;
        loadError = null;
      });
    }
    try {
      final status = await iCloudBackupService.restoreNow();
      if (!mounted) return status;
      await _initializeDataLayer();
      return status;
    } catch (_) {
      if (mounted) {
        await _initializeDataLayer();
      }
      rethrow;
    }
  }

  void _scheduleICloudBackup() {
    if (kIsWeb || widget.postStoreFactory != null) return;
    iCloudBackupDebounce?.cancel();
    iCloudBackupDebounce = Timer(const Duration(milliseconds: 900), () {
      unawaited(_runAutomaticICloudBackup());
    });
  }

  Future<void> _runAutomaticICloudBackup() async {
    try {
      if (!await iCloudBackupService.isSyncEnabled()) return;
      await postRepository?.prepareForBackup();
      await iCloudBackupService.backupNow();
    } on Object {
      // Automatic backup must not interrupt the primary local-only flow.
    }
  }
}

Future<PostStore> _defaultPostStoreFactory() async {
  if (kIsWeb) return MemoryPostStore();
  return SqlitePostStore.open();
}

class _StartupState extends StatelessWidget {
  const _StartupState({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: error == null
                ? const CircularProgressIndicator()
                : Text(
                    '本地数据加载失败，请重启 App 再试。',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
          ),
        ),
      ),
    );
  }
}

class GenkiShell extends StatefulWidget {
  const GenkiShell({
    super.key,
    required this.user,
    required this.friends,
    required this.posts,
    required this.onPostCreated,
    required this.onTogglePostLike,
    required this.onToggleCommentLike,
    required this.onAddLocalReply,
    required this.onDeleteLocalReply,
    required this.onDeletePost,
    required this.onLoadICloudBackupStatus,
    required this.onSetICloudSyncEnabled,
    required this.onClearLocalContent,
    required this.onExportData,
    required this.llmClient,
    required this.iapService,
  });

  final UserProfile user;
  final List<AiFriend> friends;
  final List<Post> posts;
  final Future<Post> Function(PostDraft draft) onPostCreated;
  final Future<Post> Function(String postId) onTogglePostLike;
  final Future<Post> Function(String postId, String commentId)
  onToggleCommentLike;
  final Future<Post> Function(String postId, String commentId, String content)
  onAddLocalReply;
  final Future<Post> Function(String postId, String commentId, String replyId)
  onDeleteLocalReply;
  final Future<void> Function(String postId) onDeletePost;
  final Future<ICloudBackupStatus> Function() onLoadICloudBackupStatus;
  final Future<ICloudBackupStatus> Function(bool enabled) onSetICloudSyncEnabled;
  final Future<void> Function() onClearLocalContent;
  final Future<void> Function() onExportData;
  final LLMClient llmClient;
  final IAPService iapService;

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

  Future<void> _publishPost(PostDraft draft) async {
    await widget.onPostCreated(draft);
    if (!mounted) return;
    setState(() {});
    if (Navigator.canPop(context)) {
      Navigator.of(context).pop();
    }
  }

  void _openCreatePost() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreatePostPage(onPublish: _publishPost),
      ),
    );
  }

  void _openPost(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PostDetailPage(
          post: post,
          onTogglePostLike: widget.onTogglePostLike,
          onToggleCommentLike: widget.onToggleCommentLike,
          onAddLocalReply: widget.onAddLocalReply,
          onDeleteLocalReply: widget.onDeleteLocalReply,
          onDeletePost: widget.onDeletePost,
        ),
      ),
    );
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
          onOpenICloudBackup: _openICloudBackup,
          onClearLocalContent: widget.onClearLocalContent,
          onExportData: widget.onExportData,
          llmClient: widget.llmClient,
          iapService: widget.iapService,
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

  void _openICloudBackup() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ICloudBackupPage(
          loadStatus: widget.onLoadICloudBackupStatus,
          onSetSyncEnabled: widget.onSetICloudSyncEnabled,
        ),
      ),
    );
  }
}
