import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../../shared/models/recent_file_model.dart';

enum AppThemeMode { system, light, dark }

/// Everything MediaMint remembers between launches, all of it local:
/// user preferences and a small JSON array describing files the app has
/// created. No database, no server — this is intentionally the simplest
/// thing that could work for data this size.
class StorageService {
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  // ---- Settings ----

  Future<AppThemeMode> getThemeMode() async {
    final prefs = await _instance;
    final value = prefs.getString(PrefsKeys.themeMode);
    return AppThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => AppThemeMode.system,
    );
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final prefs = await _instance;
    await prefs.setString(PrefsKeys.themeMode, mode.name);
  }

  Future<String> getDefaultOutputFormat() async {
    final prefs = await _instance;
    return prefs.getString(PrefsKeys.defaultOutputFormat) ??
        AppConstants.defaultOutputFormat;
  }

  Future<void> setDefaultOutputFormat(String format) async {
    final prefs = await _instance;
    await prefs.setString(PrefsKeys.defaultOutputFormat, format);
  }

  Future<int> getDefaultBitrate() async {
    final prefs = await _instance;
    return prefs.getInt(PrefsKeys.defaultBitrate) ??
        AppConstants.defaultBitrateKbps;
  }

  Future<void> setDefaultBitrate(int kbps) async {
    final prefs = await _instance;
    await prefs.setInt(PrefsKeys.defaultBitrate, kbps);
  }

  /// 'app' (app-private Music folder) or 'downloads' (public Downloads).
  Future<String> getSaveLocation() async {
    final prefs = await _instance;
    return prefs.getString(PrefsKeys.saveLocation) ?? 'app';
  }

  Future<void> setSaveLocation(String location) async {
    final prefs = await _instance;
    await prefs.setString(PrefsKeys.saveLocation, location);
  }

  Future<bool> getAutoDeleteTemp() async {
    final prefs = await _instance;
    return prefs.getBool(PrefsKeys.autoDeleteTemp) ?? true;
  }

  Future<void> setAutoDeleteTemp(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(PrefsKeys.autoDeleteTemp, value);
  }

  Future<bool> getHapticFeedback() async {
    final prefs = await _instance;
    return prefs.getBool(PrefsKeys.hapticFeedback) ?? true;
  }

  Future<void> setHapticFeedback(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(PrefsKeys.hapticFeedback, value);
  }

  // ---- Dev-mode premium override (see SubscriptionService) ----

  Future<bool> getDevPremiumOverride() async {
    final prefs = await _instance;
    return prefs.getBool(PrefsKeys.devPremiumOverride) ?? false;
  }

  Future<void> setDevPremiumOverride(bool value) async {
    final prefs = await _instance;
    await prefs.setBool(PrefsKeys.devPremiumOverride, value);
  }

  // ---- Recent files ----

  Future<List<RecentFileModel>> getRecentFiles() async {
    final prefs = await _instance;
    final raw = prefs.getString(PrefsKeys.recentFiles);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => RecentFileModel.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      // Corrupted prefs entry shouldn't crash the app — treat as empty.
      return [];
    }
  }

  Future<void> addRecentFile(RecentFileModel file) async {
    final current = await getRecentFiles();
    current.insert(0, file);
    final trimmed = current.take(AppConstants.recentFilesMax).toList();
    await _saveRecentFiles(trimmed);
  }

  Future<void> removeRecentFile(String path) async {
    final current = await getRecentFiles();
    current.removeWhere((f) => f.path == path);
    await _saveRecentFiles(current);
  }

  Future<void> renameRecentFile(String path, String newFileName) async {
    final current = await getRecentFiles();
    final index = current.indexWhere((f) => f.path == path);
    if (index == -1) return;
    current[index] = current[index].copyWith(fileName: newFileName);
    await _saveRecentFiles(current);
  }

  /// Replaces a stored path (used after a rename that also renames the file
  /// on disk) — keeps the recent-files entry pointing at a file that exists.
  Future<void> updateRecentFilePath(String oldPath, String newPath, String newFileName) async {
    final current = await getRecentFiles();
    final index = current.indexWhere((f) => f.path == oldPath);
    if (index == -1) return;
    final updated = RecentFileModel(
      path: newPath,
      fileName: newFileName,
      format: current[index].format,
      sizeBytes: current[index].sizeBytes,
      createdAt: current[index].createdAt,
      kind: current[index].kind,
    );
    current[index] = updated;
    await _saveRecentFiles(current);
  }

  Future<void> _saveRecentFiles(List<RecentFileModel> files) async {
    final prefs = await _instance;
    final raw = jsonEncode(files.map((f) => f.toJson()).toList());
    await prefs.setString(PrefsKeys.recentFiles, raw);
  }
}
