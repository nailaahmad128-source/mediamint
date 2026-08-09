import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/ffmpeg_service.dart';
import '../../core/services/output_location_service.dart';
import '../../core/services/permission_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_utils.dart';
import '../../core/utils/format_utils.dart';
import '../../shared/models/media_file_model.dart';
import '../../shared/models/recent_file_model.dart';
import '../../shared/widgets/error_view.dart';
import '../../shared/widgets/processing_card.dart';
import '../../shared/widgets/source_file_card.dart';
import '../../shared/widgets/success_result_card.dart';

enum _CompressionLevel { low, medium, high, custom }

extension on _CompressionLevel {
  String get label => switch (this) {
        _CompressionLevel.low => 'Low',
        _CompressionLevel.medium => 'Medium',
        _CompressionLevel.high => 'High',
        _CompressionLevel.custom => 'Custom',
      };

  int get bitrateKbps => switch (this) {
        _CompressionLevel.low => 192,
        _CompressionLevel.medium => 128,
        _CompressionLevel.high => 64,
        _CompressionLevel.custom => 96,
      };
}

enum _State { empty, selected, processing, success, error }

class CompressorScreen extends StatefulWidget {
  const CompressorScreen({super.key});

  @override
  State<CompressorScreen> createState() => _CompressorScreenState();
}

class _CompressorScreenState extends State<CompressorScreen> {
  final FfmpegService _ffmpeg = FfmpegService();
  final OutputLocationService _outputLocation = OutputLocationService();
  final PermissionService _permissions = PermissionService();
  final StorageService _storage = StorageService();

  _State _state = _State.empty;
  MediaFileModel? _source;
  _CompressionLevel _level = _CompressionLevel.medium;
  int _customBitrate = 96;
  double? _progress;
  String _errorMessage = '';
  RecentFileModel? _result;

  int get _targetBitrate =>
      _level == _CompressionLevel.custom ? _customBitrate : _level.bitrateKbps;

  int? get _estimatedSizeBytes {
    final durationMs = _source?.durationMs;
    if (durationMs == null || durationMs <= 0) return null;
    final durationSec = durationMs / 1000;
    return (_targetBitrate * 1000 / 8 * durationSec).round();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: AppConstants.supportedAudioExtensions,
    );
    if (result == null || result.files.single.path == null) return;

    final path = result.files.single.path!;
    final size = await FileUtils.sizeOf(path);
    setState(() {
      _source = MediaFileModel(path: path, fileName: FileUtils.fileNameOf(path), sizeBytes: size);
      _state = _State.selected;
    });

    try {
      final probe = await _ffmpeg.probe(path);
      if (!mounted || _source?.path != path) return;
      setState(() {
        _source = _source!.copyWith(
          durationMs: probe.durationMs,
          formatLabel: probe.formatName ?? FileUtils.extensionOf(path),
        );
      });
    } catch (_) {
      // Estimated-size display just stays hidden if duration can't be read.
    }
  }

  void _reset() {
    setState(() {
      _source = null;
      _result = null;
      _state = _State.empty;
    });
  }

  Future<void> _compress() async {
    final source = _source;
    if (source == null) return;

    final hasPermission = await _permissions.requestMediaReadAccess();
    if (!hasPermission) {
      if (mounted) showAppSnackBar(context, 'MediaMint needs media access.', isError: true);
      return;
    }

    setState(() {
      _state = _State.processing;
      _progress = null;
    });

    try {
      final saveLocation = await _storage.getSaveLocation();
      final outputDir = await _outputLocation.resolveOutputDirectory(saveLocation);
      final extension = FileUtils.extensionOf(source.path);
      final outExtension = extension == 'wav' ? 'mp3' : extension; // WAV can't shrink via bitrate.
      final baseName = '${FileUtils.nameWithoutExtension(source.fileName)} (compressed)';
      final outputPath = await FileUtils.uniqueFilePath(outputDir.path, baseName, outExtension);

      await _ffmpeg.compressAudio(
        inputPath: source.path,
        outputPath: outputPath,
        targetBitrateKbps: _targetBitrate,
        totalDurationMs: source.durationMs,
        onProgress: (fraction, _) {
          if (!mounted) return;
          setState(() => _progress = fraction);
        },
      );

      final size = await FileUtils.sizeOf(outputPath);
      final recent = RecentFileModel(
        path: outputPath,
        fileName: FileUtils.fileNameOf(outputPath),
        format: outExtension.toUpperCase(),
        sizeBytes: size,
        createdAt: DateTime.now(),
        kind: RecentFileKind.compressedAudio,
      );
      await _storage.addRecentFile(recent);

      if (!mounted) return;
      setState(() {
        _result = recent;
        _state = _State.success;
      });
    } on MediaProcessingException catch (e) {
      if (!mounted) return;
      if (e.message == 'Cancelled') {
        setState(() => _state = _State.selected);
      } else {
        setState(() {
          _state = _State.error;
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _state = _State.error;
        _errorMessage = 'Something went wrong while compressing this file.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Compressor')),
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
      case _State.empty:
        return Column(
          children: [
            const SizedBox(height: 32),
            Icon(Icons.compress_rounded, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 20),
            Text('Select an audio file', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.folder_open_rounded),
              label: const Text('Choose Audio'),
            ),
          ],
        );

      case _State.selected:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SourceFileCard(file: _source!, icon: Icons.audiotrack_rounded, onChangeFile: _reset),
            const SizedBox(height: 20),
            Text('Compression level', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _CompressionLevel.values.map((level) {
                return ChoiceChip(
                  label: Text(level.label),
                  selected: _level == level,
                  onSelected: (_) => setState(() => _level = level),
                );
              }).toList(),
            ),
            if (_level == _CompressionLevel.custom) ...[
              const SizedBox(height: 16),
              Text('Custom bitrate: $_customBitrate kbps'),
              Slider(
                value: _customBitrate.toDouble(),
                min: 32,
                max: 256,
                divisions: 28,
                label: '$_customBitrate kbps',
                onChanged: (v) => setState(() => _customBitrate = v.round()),
              ),
            ],
            const SizedBox(height: 12),
            if (_estimatedSizeBytes != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.insights_outlined, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Estimated output size: ${FormatUtils.fileSize(_estimatedSizeBytes!)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _compress,
              icon: const Icon(Icons.compress_rounded),
              label: const Text('Compress Audio'),
            ),
          ],
        );

      case _State.processing:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SourceFileCard(file: _source!, icon: Icons.audiotrack_rounded),
            const SizedBox(height: 20),
            ProcessingCard(
              stageLabel: 'Compressing audio',
              progress: _progress,
              onCancel: () => _ffmpeg.cancel(),
            ),
          ],
        );

      case _State.success:
        final result = _result!;
        return SuccessResultCard(
          title: 'Audio Compressed',
          fileName: result.fileName,
          format: result.format,
          sizeBytes: result.sizeBytes,
          durationMs: _source?.durationMs,
          onOpen: () => OpenFilex.open(result.path),
          onShare: () => SharePlus.instance.share(ShareParams(files: [XFile(result.path)])),
          onSave: () => showAppSnackBar(context, 'Saved to MediaMint'),
          onConvertAnother: _reset,
        );

      case _State.error:
        return ErrorView(message: _errorMessage, onRetry: _reset);
    }
  }
}
