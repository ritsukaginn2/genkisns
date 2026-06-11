import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import '../../models.dart';

class DataExportService {
  const DataExportService();

  /// Export all posts with comments and replies to JSON
  Future<File> exportPostsAsJson(List<Post> posts) async {
    final data = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'postCount': posts.length,
      'posts': [
        for (final post in posts)
          <String, dynamic>{
            'id': post.id,
            'text': post.text,
            'createdAt': post.createdAt.toIso8601String(),
            'likeCount': post.likeCount,
            'userLiked': post.userLiked,
            'interactionStatus': post.interactionStatus.name,
            'images': [
              for (final image in post.images)
                <String, dynamic>{
                  'id': image.id,
                  'type': image.type.name,
                  'source': image.source.name,
                  'durationMillis': image.durationMillis,
                  'width': image.width,
                  'height': image.height,
                  'sortIndex': image.sortIndex,
                }
            ],
            'comments': [
              for (final comment in post.comments)
                <String, dynamic>{
                  'id': comment.id,
                  'actorId': comment.actorId,
                  'actorNameSnapshot': comment.actorNameSnapshot,
                  'content': comment.content,
                  'createdAt': comment.createdAt.toIso8601String(),
                  'likeCount': comment.likeCount,
                  'userLiked': comment.userLiked,
                  'replies': [
                    for (final reply in comment.replies)
                      <String, dynamic>{
                        'id': reply.id,
                        'authorNameSnapshot': reply.authorNameSnapshot,
                        'targetActorNameSnapshot': reply.targetActorNameSnapshot,
                        'content': reply.content,
                        'createdAt': reply.createdAt.toIso8601String(),
                      }
                  ],
                }
            ],
          },
      ],
    };

    final json = jsonEncode(data);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'genki_sns_export_$timestamp.json';

    final docDir = await getApplicationDocumentsDirectory();
    final file = File('${docDir.path}/$filename');
    await file.writeAsString(json);

    return file;
  }

  /// Export minimal text summary for quick backup
  Future<String> exportPostsAsText(List<Post> posts) async {
    final buffer = StringBuffer();
    buffer.writeln('GenkiSNS Data Export');
    buffer.writeln('Exported at: ${DateTime.now()}');
    buffer.writeln('Total posts: ${posts.length}');
    buffer.writeln('');

    for (final post in posts) {
      buffer.writeln('---');
      buffer.writeln('Post: ${post.id}');
      buffer.writeln('Date: ${post.createdAt}');
      buffer.writeln('Likes: ${post.likeCount}');
      buffer.writeln('Comments: ${post.comments.length}');
      buffer.writeln('Text: ${post.text}');
      buffer.writeln('');
    }

    return buffer.toString();
  }
}
