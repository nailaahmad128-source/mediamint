import 'package:flutter/material.dart';
import 'core/constants/app_constants.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

/// Tiny app-wide controller so a theme change made in Settings is reflected
/// immediately, without threading state through every screen or reaching
/// for a full state-management package for one value.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system);

  final StorageService _storage = StorageService();

  Future<void> load() async {
    final saved = await _storage.getThemeMode();
    value = switch (saved) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }

  Future<void> update(AppThemeMode mode) async {
    await _storage.setThemeMode(mode);
    value = switch (mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
  }
}

/// Global instance. Settings screen calls `themeController.update(...)`;
/// MediaMintApp rebuilds automatically via ValueListenableBuilder.
final themeController = ThemeController();

class MediaMintApp extends StatefulWidget {
  const MediaMintApp({super.key});

  @override
  State<MediaMintApp> createState() => _MediaMintAppState();
}

class _MediaMintAppState extends State<MediaMintApp> {
  @override
  void initState() {
    super.initState();
    themeController.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: const HomeScreen(),
        );
      },
    );
  }
}
