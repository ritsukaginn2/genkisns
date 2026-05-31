import '../../mock/mock_data.dart';
import '../../models.dart';

class AiFriendRepository {
  AiFriendRepository({List<String>? selectedFriendIds})
    : selectedFriendIds =
          selectedFriendIds ??
          presetFriends.take(5).map((friend) => friend.id).toList();

  final List<String> selectedFriendIds;

  List<AiFriend> listSelectedFriends() {
    if (selectedFriendIds.isEmpty) {
      return presetFriends.take(5).toList();
    }
    final selectedFriends = presetFriends
        .where((friend) => selectedFriendIds.contains(friend.id))
        .toList();
    return selectedFriends.isEmpty
        ? presetFriends.take(5).toList()
        : selectedFriends;
  }
}
