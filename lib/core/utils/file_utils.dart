import 'dart:io';
import '../constants/app_constants.dart';

class FileUtils {
  FileUtils._();

  static String extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toLowerCase();
  }

  static String nameWithoutExtension(String path) {
    final base = path.split(Platform.pathSeparator).last;
    final dot = base.lastIndexOf('.');
    if (dot == -1) return base;
    return base.substring(0, dot);
  }

  static String fileNameOf(String path) => path.split(Platform.pathSeparator).last;

  static bool isSupportedVideo(String path) =>
      AppConstants.supportedVideoExtensions.contains(extensionOf(path));

  static bool isSupportedAudio(String path) =>
      AppConstants.supportedAudioExtensions.contains(extensionOf(path));

  /// Appends " (2)", " (3)", etc. until [directory] has no file with that
  /// name — used so a repeat conversion never silently overwrites a
  /// previous export.
  static Future<String> uniqueFilePath(String directory, String baseName, String extension) async {
    var candidate = '$directory${Platform.pathSeparator}$baseName.$extension';
    if (!await File(candidate).exists()) return candidate;

    var counter = 2;
    while (true) {
      candidate = '$directory${Platform.pathSeparator}$baseName ($counter).$extension';
      if (!await File(candidate).exists()) return candidate;
      counter++;
    }
  }

  static Future<int> sizeOf(String path) async {
    final file = File(path);
    if (!await file.exists()) return 0;
    return file.length();
  }

  static Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
