import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/main.dart';
import 'package:genki_sns/mock/mock_data.dart';
import 'package:genki_sns/models.dart';
import 'package:genki_sns/pages/create_post_page.dart';
import 'package:genki_sns/pages/home_page.dart';

void main() {
  testWidgets('shows empty home entry point', (tester) async {
    await tester.pumpWidget(const GenkiSnsApp());

    expect(find.text('发布笔记'), findsOneWidget);
    expect(find.text('还没有笔记'), findsOneWidget);
  });

  testWidgets('text-only posts do not render image placeholder', (
    tester,
  ) async {
    final post = Post(
      id: 'text_only',
      text: '今天只想写几句话，不配图。',
      imageColors: const [],
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

  testWidgets('create page autofocuses text field by default', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CreatePostPage(onPublish: (_) {})),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.autofocus, isTrue);
  });

  testWidgets('create page does not autofocus behind initial media sheet', (
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

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.autofocus, isFalse);
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
}
