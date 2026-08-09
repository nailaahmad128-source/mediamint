import 'dart:typed_data';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Generates a JPEG thumbnail for a selected video, used on the Video to
/// Audio preview card. Failures return null rather than throwing — a
/// missing thumbnail should never block a conversion, it just falls back
/// to a generic file icon in the UI.
class ThumbnailService {
  Future<Uint8List?> generate(String videoPath) async {
    try {
      return await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 200,
        quality: 70,
      );
    } catch (_) {
      return null;
    }
  }
}
