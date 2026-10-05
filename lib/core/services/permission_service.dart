import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// MediaMint avoids broad storage permissions wherever the OS lets it.
///
/// - Android 13+ (API 33+): scoped media permissions (READ_MEDIA_AUDIO /
///   READ_MEDIA_VIDEO). File selection itself goes through the system file
///   picker (Storage Access Framework), which needs no permission at all —
///   these are only requested for the Recent Files scan and probing.
/// - Android 6-12 (API 23-32): legacy READ_EXTERNAL_STORAGE.
/// - Below API 23: permissions are granted at install time; nothing to request.
///
/// Saving MediaMint's own output never requires a storage permission: it
/// writes to the app's private external files directory by default, which
/// is always writable without permission.
class PermissionService {
  int? _cachedSdkInt;

  Future<int> _sdkInt() async {
    if (_cachedSdkInt != null) return _cachedSdkInt!;
    if (!Platform.isAndroid) return _cachedSdkInt = 0;
    final info = await DeviceInfoPlugin().androidInfo;
    return _cachedSdkInt = info.version.sdkInt;
  }

  Future<bool> requestMediaReadAccess() async {
    if (!Platform.isAndroid) return true;
    final sdkInt = await _sdkInt();

    if (sdkInt >= 33) {
      final statuses = await [Permission.audio, Permission.videos].request();
      return statuses.values.every((s) => s.isGranted);
    }
    if (sdkInt >= 23) {
      final status = await Permission.storage.request();
      return status.isGranted;
    }
    return true; // Pre-Marshmallow: granted at install time.
  }

  Future<bool> hasMediaReadAccess() async {
    if (!Platform.isAndroid) return true;
    final sdkInt = await _sdkInt();

    if (sdkInt >= 33) {
      return await Permission.audio.isGranted && await Permission.videos.isGranted;
    }
    if (sdkInt >= 23) {
      return Permission.storage.isGranted;
    }
    return true;
  }

  bool isPermanentlyDenied(PermissionStatus status) => status.isPermanentlyDenied;

  Future<void> openSettings() => openAppSettings();
}
