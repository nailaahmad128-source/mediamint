import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Resolves the directory MediaMint writes converted files into.
///
/// Default ("app"): the app's own external files directory
/// (`/Android/data/com.mediamint.app/files/MediaMint`) — always writable
/// with zero permissions, survives app updates, and is cleaned up
/// automatically if the app is uninstalled. This is what "Save" and
/// "Share" operate on.
///
/// Optional ("downloads"): a MediaMint folder under the public Downloads
/// directory, for people who want the files visible to other apps'
/// file browsers without going through Share. On Android 10+ this still
/// works without WRITE_EXTERNAL_STORAGE because we only ever write files
/// MediaMint itself created (no arbitrary path access needed).
class OutputLocationService {
  Future<Directory> resolveOutputDirectory(String saveLocationSetting) async {
    if (saveLocationSetting == 'downloads') {
      final downloadsDir = await _publicDownloadsMediaMintDir();
      if (downloadsDir != null) return downloadsDir;
    }
    return _appMediaMintDir();
  }

  Future<Directory> _appMediaMintDir() async {
    final base = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/MediaMint');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory?> _publicDownloadsMediaMintDir() async {
    if (!Platform.isAndroid) return null;
    try {
      // /storage/emulated/0/Download/MediaMint — writable on modern Android
      // without a broad permission because we only write our own files here,
      // never read or enumerate arbitrary files in this directory.
      const path = '/storage/emulated/0/Download/MediaMint';
      final dir = Directory(path);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (_) {
      return null; // Fall back to app directory if the device restricts this.
    }
  }

  Future<Directory> tempDirectory() async {
    final dir = await getTemporaryDirectory();
    final mediaMintTemp = Directory('${dir.path}/mediamint_tmp');
    if (!await mediaMintTemp.exists()) {
      await mediaMintTemp.create(recursive: true);
    }
    return mediaMintTemp;
  }

  Future<void> clearTempDirectory() async {
    final dir = await tempDirectory();
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        try {
          await entity.delete(recursive: true);
        } catch (_) {
          // Best-effort cleanup — a locked file here shouldn't crash anything.
        }
      }
    }
  }
}
