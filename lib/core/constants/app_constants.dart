/// Central place for values that show up in more than one feature.
/// Keeping these out of individual screens avoids magic numbers/strings
/// scattered across the codebase.
class AppConstants {
  AppConstants._();

  static const String appName = 'MediaMint';
  static const String appTagline = 'Simple media tools. Private by design.';
  static const String appSubtitle = 'Video & Audio Studio';

  // Ringtone rules (Android does not let third-party apps reliably set the
  // system ringtone without a MediaStore write + RingtoneManager call that
  // varies a lot by OEM — we cap length to keep exports sane either way).
  static const int ringtoneMaxSeconds = 30;

  // Recent files list cap — this is metadata only (path + a few fields),
  // stored as JSON in SharedPreferences, so this is a UX cap, not a storage one.
  static const int recentFilesMax = 100;

  static const List<String> supportedVideoExtensions = [
    'mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v', '3gp', 'flv', 'wmv',
  ];

  static const List<String> supportedAudioExtensions = [
    'mp3', 'm4a', 'wav', 'aac', 'flac', 'ogg', 'opus', 'wma',
  ];

  static const List<String> audioOutputFormats = ['MP3', 'M4A', 'WAV'];

  // WAV is uncompressed PCM — bitrate as a concept doesn't apply to it,
  // so screens should hide the bitrate selector when format == WAV.
  static const List<int> bitrateOptionsKbps = [64, 128, 192, 256, 320];

  static const int defaultBitrateKbps = 192;
  static const String defaultOutputFormat = 'MP3';

  static const Duration snackbarDuration = Duration(seconds: 3);
}

/// Keys used for SharedPreferences. Grouped here so a rename doesn't
/// silently orphan previously-saved user data.
class PrefsKeys {
  PrefsKeys._();

  static const String themeMode = 'settings.themeMode';
  static const String defaultOutputFormat = 'settings.defaultOutputFormat';
  static const String defaultBitrate = 'settings.defaultBitrate';
  static const String saveLocation = 'settings.saveLocation';
  static const String autoDeleteTemp = 'settings.autoDeleteTemp';
  static const String hapticFeedback = 'settings.hapticFeedback';
  static const String recentFiles = 'data.recentFiles';
  static const String devPremiumOverride = 'dev.premiumOverride';
}
