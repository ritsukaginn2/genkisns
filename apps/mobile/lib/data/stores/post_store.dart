import '../../models.dart';

abstract class PostStore {
  Future<List<Post>> loadPosts();

  Future<void> upsertPost(Post post);

  Future<void> deletePost(String postId);

  Future<void> deleteAllPosts();

  Future<void> prepareForBackup();

  Future<void> close();
}

class MemoryPostStore implements PostStore {
  MemoryPostStore([List<Post>? initialPosts]) : _posts = [...?initialPosts];

  final List<Post> _posts;

  @override
  Future<List<Post>> loadPosts() async {
    return List.unmodifiable(_posts);
  }

  @override
  Future<void> upsertPost(Post post) async {
    final index = _posts.indexWhere((candidate) => candidate.id == post.id);
    if (index == -1) {
      _posts.insert(0, post);
    } else {
      _posts[index] = post;
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    _posts.removeWhere((post) => post.id == postId);
  }

  @override
  Future<void> deleteAllPosts() async {
    _posts.clear();
  }

  @override
  Future<void> prepareForBackup() async {}

  @override
  Future<void> close() async {}
}
