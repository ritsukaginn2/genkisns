import 'package:flutter_test/flutter_test.dart';
import 'package:genki_sns/data/services/image_picker_service.dart';
import 'package:genki_sns/models.dart';

void main() {
  test('creates stable album image refs for reopening picker selection', () {
    const service = ImagePickerService();
    final options = service.listAlbumOptions();

    final picked = service.fromAlbum(id: 7, albumIndex: options[2].index);
    final ref = picked.toPostImageRef(sortIndex: 0);

    expect(picked.albumIndex, options[2].index);
    expect(picked.localRef, options[2].localRef);
    expect(ref.source, PostImageSource.album);
    expect(ref.localRef, options[2].localRef);
  });

  test('creates camera image refs separately from album selection', () {
    const service = ImagePickerService();

    final picked = service.fromCamera(id: 1);

    expect(picked.albumIndex, isNull);
    expect(picked.source, PostImageSource.camera);
    expect(picked.localRef, 'camera://image/1');
  });

  test('creates camera video refs with media type', () {
    const service = ImagePickerService();

    final picked = service.fromCameraVideo(id: 2);
    final ref = picked.toPostImageRef(sortIndex: 0);

    expect(picked.type, PostMediaType.video);
    expect(ref.type, PostMediaType.video);
    expect(ref.source, PostImageSource.camera);
    expect(ref.localRef, 'camera://video/2');
    expect(ref.durationMillis, 18000);
  });
}
