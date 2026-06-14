import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Resolves stored media references to absolute file paths.
///
/// Media is stored under the app documents directory and referenced by a
/// RELATIVE path (e.g. `post_media/123_album_0.jpg`) so the reference survives
/// app reinstalls — the absolute container path changes every install, but the
/// relative layout is stable. Rendering/playback therefore must resolve the
/// reference against the *current* documents directory before opening a `File`.
class MediaStorage {
  MediaStorage._();

  static String? _documentsRoot;

  /// Caches the documents directory path. Call once at startup before any
  /// media is rendered. Best-effort: on failure [resolve] returns null and
  /// callers fall back to a placeholder.
  static Future<void> init() async {
    try {
      _documentsRoot = (await getApplicationDocumentsDirectory()).path;
    } on Object {
      _documentsRoot = null;
    }
  }

  /// Absolute file path for [ref], or null when it can't be resolved
  /// (sentinel refs used by mock/preview data, or before [init] ran).
  /// A null result means the caller should show a placeholder.
  static String? resolve(String ref) {
    if (ref.isEmpty) return null;
    if (ref.startsWith('preview://') ||
        ref.startsWith('album://') ||
        ref.startsWith('camera://')) {
      return null;
    }
    final root = _documentsRoot;
    if (p.isAbsolute(ref)) {
      // A legacy ref may be an absolute path from a PREVIOUS install whose
      // container UUID is now stale. If it points into our post_media folder,
      // re-anchor it to the current documents directory so the file is found
      // again after a reinstall/restore. Other absolute paths (e.g. live
      // album previews) are current-session and used as-is.
      final marker = ref.indexOf('/post_media/');
      if (marker != -1 && root != null) {
        return p.join(root, ref.substring(marker + 1));
      }
      return ref;
    }
    if (root == null) return null;
    return p.join(root, ref);
  }
}
