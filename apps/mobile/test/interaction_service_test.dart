import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/data/repositories/ai_friend_repository.dart';
import 'package:genki_sns/data/repositories/user_repository.dart';
import 'package:genki_sns/data/services/interaction_service.dart';
import 'package:genki_sns/models.dart';

void main() {
  test('generates local template interactions synchronously', () {
    final friends = AiFriendRepository().listSelectedFriends();

    final result = InteractionService().generateLocalInteractions(
      post: const PostSeed(id: 'post_1', text: '今天很好。', images: []),
      friends: friends,
      now: DateTime(2026, 5, 24, 21),
    );

    expect(result.likeCount, greaterThan(result.comments.length));
    expect(result.comments, isNotEmpty);
    expect(result.comments.first.actorId, friends.first.id);
  });

  test('local template falls back to preset friends when no friends passed', () {
    final result = InteractionService().generateLocalInteractions(
      post: const PostSeed(id: 'post_2', text: '本地模板。', images: []),
      friends: const [],
      now: DateTime(2026, 5, 24, 21),
    );

    expect(result.comments, isNotEmpty);
  });

  test('LLM upgrade returns null when no client is configured', () async {
    final result = await InteractionService().tryGenerateWithLlm(
      post: const PostSeed(id: 'post_3', text: '无后端。', images: []),
      user: const UserRepository().getDefaultUser(),
      friends: const [],
      now: DateTime(2026, 5, 24, 21),
    );

    expect(result, isNull);
  });
}
