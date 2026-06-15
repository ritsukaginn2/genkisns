import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/data/services/interaction_service.dart';
import 'package:genki_sns/data/stores/post_store.dart';
import 'package:genki_sns/main.dart';
import 'package:genki_sns/mock/mock_data.dart';
import 'package:genki_sns/models.dart';
import 'package:genki_sns/pages/create_post_page.dart';
import 'package:genki_sns/pages/home_page.dart';

void main() {
  testWidgets('shows empty home entry point', (tester) async {
    await tester.pumpWidget(
      GenkiSnsApp(postStoreFactory: () async => MemoryPostStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('发布笔记'), findsOneWidget);
    expect(find.text('还没有笔记'), findsOneWidget);
  });

  testWidgets('text-only posts do not render image placeholder', (
    tester,
  ) async {
    final post = Post(
      id: 'text_only',
      text: '今天只想写几句话，不配图。',
      images: const [],
      createdAt: DateTime(2026, 5, 24, 20, 30),
      likeCount: 3,
      comments: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          user: defaultUser,
          posts: [post],
          onOpenPost: (_) {},
          onCreatePost: () {},
          onOpenProfile: () {},
        ),
      ),
    );

    expect(find.text('今天只想写几句话，不配图。'), findsOneWidget);
    expect(find.byIcon(Icons.image), findsNothing);
  });

  testWidgets('create page focuses text field after the push transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CreatePostPage(onPublish: (_) {}),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    // Mid-transition the keyboard must stay down so it does not slide up on
    // top of the route animation.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.testTextInput.isVisible, isFalse);

    // Once the transition settles the text field gains focus.
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('create page does not focus behind initial media sheet', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          onPublish: (_) {},
          initialShowImageSourceSheet: true,
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 260));
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('create page allows image-only posts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          onPublish: (_) {},
          initialImageColors: const [Colors.pink],
        ),
      ),
    );

    final publishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '发布'),
    );
    expect(publishButton.onPressed, isNotNull);
  });

  testWidgets('create page blocks empty posts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CreatePostPage(onPublish: (_) {})),
    );

    final publishButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '发布'),
    );
    expect(publishButton.onPressed, isNull);
  });

  testWidgets('create page unfocuses text field when tapping outside', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CreatePostPage(onPublish: (_) {})),
    );

    await tester.showKeyboard(find.byType(TextField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('媒体'));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('create page can add a mock camera video from camera entry', (
    tester,
  ) async {
    PostDraft? publishedDraft;

    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostPage(
          onPublish: (draft) {
            publishedDraft = draft;
          },
          useMockMediaPicker: true,
          mockCameraMediaType: PostMediaType.video,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('相机'));
    await tester.pumpAndSettle();

    expect(find.text('1 个视频'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, '发布'));
    await tester.pumpAndSettle();

    expect(publishedDraft, isNotNull);
    expect(publishedDraft!.images.single.type, PostMediaType.video);
  });

  testWidgets('publishes a post and persists detail interactions', (
    tester,
  ) async {
    await tester.pumpWidget(
      GenkiSnsApp(
        postStoreFactory: () async => MemoryPostStore(),
        // Deliver AI interactions immediately (no stagger) so the detail page
        // has comments to interact with.
        interactionService: InteractionService(
          firstDelaySeconds: 0,
          gapSeconds: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '发布笔记'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '今天需要一点回应。');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '发布'));
    await tester.pumpAndSettle();

    expect(find.text('今天需要一点回应。'), findsOneWidget);

    await tester.tap(find.text('今天需要一点回应。'));
    await tester.pumpAndSettle();
    expect(find.text('笔记详情'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border).first);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite), findsWidgets);

    await tester.tap(find.text('回复').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '我也这么觉得。');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, '发送'));
    await tester.pumpAndSettle();
    expect(find.text('我也这么觉得。'), findsOneWidget);

    await tester.tap(find.byTooltip('删除回复'));
    await tester.pumpAndSettle();
    expect(find.text('删除这条回复？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除回复'));
    await tester.pumpAndSettle();
    expect(find.text('我也这么觉得。'), findsNothing);

    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('删除笔记'), findsOneWidget);

    await tester.tap(find.text('删除笔记'));
    await tester.pumpAndSettle();
    expect(find.text('删除这篇笔记？'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除笔记'));
    await tester.pumpAndSettle();
    expect(find.text('笔记详情'), findsNothing);
    expect(find.text('今天需要一点回应。'), findsNothing);
    expect(find.text('还没有笔记'), findsOneWidget);
  });
}
