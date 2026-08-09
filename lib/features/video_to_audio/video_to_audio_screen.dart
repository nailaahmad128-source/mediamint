import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ffmpeg_service.dart';
import '../../core/services/output_location_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/thumbnail_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/conversion_settings_model.dart';
import '../../shared/models/media_file_model.dart';
import '../../shared/models/recent_file_model.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/processing_card.dart';
import '../../shared/widgets/source_file_card.dart';
import '../../shared/widgets/success_result_card.dart';
import '../premium/feature_gate.dart';
import '../premium/subscription_service.dart';
import 'widgets/format_selector.dart';
import 'widgets/bitrate_selector.dart';

enum _ScreenState { empty, selected, processing, success, error }

class VideoToAudioScreen extends StatefulWidget {
  const VideoToAudioScreen({super.key});

  @override
  State<VideoToAudioScreen> createState() => _VideoToAudioScreenState();
}

class _VideoToAudioScreenState extends State<VideoToAudioScreen> {
  final FfmpegService _ffmpeg = FfmpegService();
  final ThumbnailService _thumbnailService = ThumbnailService();
  final OutputLocationService _outputLocation = OutputLocationService();
  final PermissionService _permissions = PermissionService();
  final StorageService _storage = StorageService();
  late final FeatureGate _featureGate;

  _ScreenState _state = _ScreenState.empty;
  MediaFileModel? _sourceFile;
  Uint8List? _thumbnail;
  ConversionSettings _settings = const ConversionSettings(
    format: AppConstants.defaultOutputFormat,
    bitrateKbps: AppConstants.defaultBitrateKbps,
  );

  double? _progress;
  String _stageLabel = '';
  String _errorMessage = '';
  RecentFileModel? _result;

  @override
  void initState() {
    super.initState();
    _featureGate = FeatureGate(SubscriptionService(_storage)..load());
    _loadDefaultSettings();
  }

  Future<void> _loadDefaultSettings() async {
    final format = await _storage.getDefaultOutputFormat();
    final bitrate = await _storage.getDefaultBitrate();
    if (!mounted) return;
    setState(() {
      _settings = ConversionSettings(format: format, bitrateKbps: bitrate);
    });
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedVideoExtensions,
      withData: false,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final size = await FileUtils.sizeOf(path);

    setState(() {
      _sourceFile = MediaFileModel(
        path: path,
        fileName: FileUtils.fileNameOf(path),
        sizeBytes: size,
      );
      _thumbnail = null;
      _state = _ScreenState.selected;
    });

    unawaited(_probeAndThumbnail(path));
  }

  Future<void> _probeAndThumbnail(String path) async {
    try {
      final probeResult = await _ffmpeg.probe(path);
      if (!mounted || _sourceFile?.path != path) return;
      setState(() {
        _sourceFile = _sourceFile!.copyWith(
          durationMs: probeResult.durationMs,
          formatLabel: probeResult.formatName ?? FileUtils.extensionOf(path),
        );
      });

      if (!probeResult.hasAudioStream) {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = 'This video doesn\'t contain an audio track to extract.';
        });
      }
    } catch (e) {
      if (!mounted || _sourceFile?.path != path) return;
      setState(() {
        _sourceFile = _sourceFile!.copyWith(formatLabel: FileUtils.extensionOf(path));
      });
    }

    final thumb = await _thumbnailService.generate(path);
    if (!mounted || _sourceFile?.path != path) return;
    setState(() => _thumbnail = thumb);
  }

  void _clearSelection() {
    setState(() {
      _sourceFile = null;
      _thumbnail = null;
      _result = null;
      _state = _ScreenState.empty;
    });
  }

  Future<void> _extractAudio() async {
    final source = _sourceFile;
    if (source == null) return;

    if (_settings.format == 'WAV' && !_featureGate.isUnlocked(PremiumFeature.wavExport)) {
      _showUpgradeSnack('WAV export');
      return;
    }
    if (_settings.bitrateKbps == 320 && !_featureGate.isUnlocked(PremiumFeature.bitrate320)) {
      _showUpgradeSnack('320 kbps export');
      return;
    }

    final hasPermission = await _permissions.requestMediaReadAccess();
    if (!hasPermission) {
      if (mounted) {
        showAppSnackBar(
          context,
          'MediaMint needs media access to read the selected file.',
          isError: true,
        );
      }
      return;
    }

    setState(() {
      _state = _ScreenState.processing;
      _progress = null;
      _stageLabel = 'Preparing';
    });

    try {
      final saveLocation = await _storage.getSaveLocation();
      final outputDir = await _outputLocation.resolveOutputDirectory(saveLocation);
      final baseName = FileUtils.nameWithoutExtension(source.fileName);
      final outputPath = await FileUtils.uniqueFilePath(
        outputDir.path,
        baseName,
        _settings.fileExtension,
      );

      await _ffmpeg.extractAudio(
        inputPath: source.path,
        outputPath: outputPath,
        format: _settings.format,
        bitrateKbps: _settings.bitrateKbps,
        totalDurationMs: source.durationMs,
        onProgress: (fraction, label) {
          if (!mounted) return;
          setState(() {
            _progress = fraction;
            _stageLabel = label;
          });
        },
      );

      final outputSize = await FileUtils.sizeOf(outputPath);
      final recentFile = RecentFileModel(
        path: outputPath,
        fileName: FileUtils.fileNameOf(outputPath),
        format: _settings.format,
        sizeBytes: outputSize,
        createdAt: DateTime.now(),
        kind: RecentFileKind.extractedAudio,
      );
      await _storage.addRecentFile(recentFile);

      if (!mounted) return;
      setState(() {
        _result = recentFile;
        _state = _ScreenState.success;
      });
    } on MediaProcessingException catch (e) {
      if (!mounted) return;
      if (e.message == 'Cancelled') {
        setState(() => _state = _ScreenState.selected);
      } else {
        setState(() {
          _state = _ScreenState.error;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _ScreenState.error;
        _errorMessage = 'Something went wrong while extracting audio.';
      });
    }
  }

  void _showUpgradeSnack(String featureName) {
    showAppSnackBar(context, '$featureName is a MediaMint Pro feature.');
  }

  Future<void> _cancelProcessing() async {
    await _ffmpeg.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Video to Audio')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppTheme.pagePadding,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _ScreenState.empty:
        return _buildEmptyState();
      case _ScreenState.selected:
        return _buildSelectedState();
      case _ScreenState.processing:
        return _buildProcessingState();
      case _ScreenState.success:
        return _buildSuccessState();
      case _ScreenState.error:
        return _buildErrorState();
    }
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(Icons.video_file_outlined, size: 72, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 20),
        Text('Select a video', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'MP4, MKV, MOV, AVI, WEBM, and more',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _pickVideo,
          icon: const Icon(Icons.folder_open_rounded),
          label: const Text('Choose Video'),
        ),
      ],
    );
  }

  Widget _buildSelectedState() {
    final source = _sourceFile!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VideoPreviewCard(file: source, thumbnail: _thumbnail, onChangeFile: _clearSelection),
        const SizedBox(height: 20),
        Text('Format', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        FormatSelector(
          selected: _settings.format,
          onChanged: (format) => setState(() => _settings = _settings.copyWith(format: format)),
        ),
        if (_settings.bitrateApplies) ...[
          const SizedBox(height: 20),
          Text('Quality', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          BitrateSelector(
            selected: _settings.bitrateKbps,
            isLocked: (kbps) => kbps == 320 && !_featureGate.isUnlocked(PremiumFeature.bitrate320),
            onChanged: (kbps) => setState(() => _settings = _settings.copyWith(bitrateKbps: kbps)),
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _extractAudio,
          icon: const Icon(Icons.graphic_eq_rounded),
          label: const Text('Extract Audio'),
        ),
      ],
    );
  }

  Widget _buildProcessingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VideoPreviewCard(file: _sourceFile!, thumbnail: _thumbnail, onChangeFile: null),
        const SizedBox(height: 20),
        ProcessingCard(
          stageLabel: _stageLabel,
          progress: _progress,
          onCancel: _cancelProcessing,
        ),
      ],
    );
  }

  Widget _buildSuccessState() {
    final result = _result!;
    return SuccessResultCard(
      fileName: result.fileName,
      format: result.format,
      sizeBytes: result.sizeBytes,
      durationMs: _sourceFile?.durationMs,
      onOpen: () => OpenFilex.open(result.path),
      onShare: () => SharePlus.instance.share(ShareParams(files: [XFile(result.path)])),
      onSave: () => showAppSnackBar(context, 'Saved to MediaMint'),
      onConvertAnother: _clearSelection,
    );
  }

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_sourceFile != null)
          _VideoPreviewCard(file: _sourceFile!, thumbnail: _thumbnail, onChangeFile: _clearSelection),
        const SizedBox(height: 16),
        ErrorView(message: _errorMessage, onRetry: _clearSelection),
      ],
    );
  }
}

class _VideoPreviewCard extends StatelessWidget {
  final MediaFileModel file;
  final Uint8List? thumbnail;
  final VoidCallback? onChangeFile;

  const _VideoPreviewCard({required this.file, required this.thumbnail, this.onChangeFile});

  @override
  Widget build(BuildContext context) {
    if (thumbnail == null) {
      return SourceFileCard(file: file, onChangeFile: onChangeFile);
    }

    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(thumbnail!, width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(file.fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (file.formatLabel != null) file.formatLabel!.toUpperCase(),
                      FormatUtils.fileSize(file.sizeBytes),
                      if (file.durationMs != null) FormatUtils.duration(file.durationMs!),
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (onChangeFile != null)
              IconButton(icon: const Icon(Icons.close), onPressed: onChangeFile),
          ],
        ),
      ),
    );
  }

}

void unawaited(Future<void> future) {}
