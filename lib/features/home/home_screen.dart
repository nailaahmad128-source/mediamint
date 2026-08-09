import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/models/recent_file_model.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/section_header.dart';
import '../audio_cutter/audio_cutter_screen.dart';
import '../compressor/compressor_screen.dart';
import '../premium/premium_screen.dart';
import '../recent_files/recent_files_screen.dart';
import '../recent_files/widgets/recent_file_tile.dart';
import '../ringtone/ringtone_screen.dart';
import '../settings/settings_screen.dart';
import '../video_to_audio/video_to_audio_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storage = StorageService();
  List<RecentFileModel> _recentPreview = [];
  bool _loadingRecents = true;

  @override
  void initState() {
    super.initState();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    final files = await _storage.getRecentFiles();
    if (!mounted) return;
    setState(() {
      _recentPreview = files.take(3).toList();
      _loadingRecents = false;
    });
  }

  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _loadRecents();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppConstants.appName),
            Text(
              AppConstants.appTagline,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppTheme.pagePadding,
          children: [
            _PrimaryActionCard(
              onTap: () => _openAndRefresh(const VideoToAudioScreen()),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Tools'),
            _ToolGrid(
              onAudioCutter: () => _openAndRefresh(const AudioCutterScreen()),
              onRingtoneMaker: () => _openAndRefresh(const RingtoneScreen()),
              onCompressor: () => _openAndRefresh(const CompressorScreen()),
            ),
            const SizedBox(height: 28),
            SectionHeader(
              title: 'Recent Files',
              trailing: _recentPreview.isEmpty
                  ? null
                  : TextButton(
                      onPressed: () => _openAndRefresh(const RecentFilesScreen()),
                      child: const Text('See all'),
                    ),
            ),
            _buildRecentSection(),
            const SizedBox(height: 28),
            _PremiumBanner(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSection() {
    if (_loadingRecents) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_recentPreview.isEmpty) {
      return const Card(
        child: EmptyState(
          icon: Icons.audiotrack_rounded,
          title: 'No recent files',
          message: 'Your converted audio files will appear here.',
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < _recentPreview.length; i++) ...[
            RecentFileTile(
              file: _recentPreview[i],
              onOpen: () {},
              onShare: () {},
              onRename: () {},
              onDelete: () {},
              dense: true,
            ),
            if (i != _recentPreview.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _PrimaryActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _PrimaryActionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.graphic_eq_rounded, color: scheme.onPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Video to Audio',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: scheme.onPrimary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Extract MP3, M4A, or WAV from any video',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  final VoidCallback onAudioCutter;
  final VoidCallback onRingtoneMaker;
  final VoidCallback onCompressor;

  const _ToolGrid({
    required this.onAudioCutter,
    required this.onRingtoneMaker,
    required this.onCompressor,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.92,
      children: [
        _ToolTile(icon: Icons.content_cut_rounded, label: 'Audio Cutter', onTap: onAudioCutter),
        _ToolTile(icon: Icons.music_note_rounded, label: 'Ringtone Maker', onTap: onRingtoneMaker),
        _ToolTile(icon: Icons.compress_rounded, label: 'Compressor', onTap: onCompressor),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: scheme.primary, size: 26),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.surfaceContainerHigh,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unlock MediaMint Pro', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Higher quality exports, batch tools, and more',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
