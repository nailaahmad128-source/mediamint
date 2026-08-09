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

enum _State { empty, selected, processing, success, error }

class AudioCutterScreen extends StatefulWidget {
  const AudioCutterScreen({super.key});

  @override
  State<AudioCutterScreen> createState() => _AudioCutterScreenState();
}

class _AudioCutterScreenState extends State<AudioCutterScreen> {
  final FfmpegService _ffmpeg = FfmpegService();
  final OutputLocationService _outputLocation = OutputLocationService();
  final PermissionService _permissions = PermissionService();
  final StorageService _storage = StorageService();

  _State _state = _State.empty;
  MediaFileModel? _source;
  RangeValues _range = const RangeValues(0, 1);
  double? _progress;
  String _errorMessage = '';
  RecentFileModel? _result;

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
      final durationMs = probe.durationMs ?? 0;
      setState(() {
        _source = _source!.copyWith(
          durationMs: durationMs,
          formatLabel: probe.formatName ?? FileUtils.extensionOf(path),
        );
        _range = RangeValues(0, durationMs.toDouble());
      });
    } catch (_) {
      // Duration stays null — the trim slider falls back to a manual
      // seconds entry in that edge case (see _durationKnown below).
    }
  }

  void _reset() {
    setState(() {
      _source = null;
      _result = null;
      _state = _State.empty;
    });
  }

  bool get _durationKnown => (_source?.durationMs ?? 0) > 0;

  Future<void> _cut() async {
    final source = _source;
    if (source == null || !_durationKnown) return;

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
      final outExtension = AppConstants.supportedAudioExtensions.contains(extension)
          ? extension
          : 'mp3';
      final baseName = '${FileUtils.nameWithoutExtension(source.fileName)} (cut)';
      final outputPath = await FileUtils.uniqueFilePath(outputDir.path, baseName, outExtension);

      await _ffmpeg.cutAudio(
        inputPath: source.path,
        outputPath: outputPath,
        startMs: _range.start.round(),
        endMs: _range.end.round(),
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
        kind: RecentFileKind.cutAudio,
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
        _errorMessage = 'Something went wrong while cutting this file.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audio Cutter')),
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
            Icon(Icons.content_cut_rounded, size: 72, color: Theme.of(context).colorScheme.outline),
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
            SourceFileCard(
              file: _source!,
              icon: Icons.audiotrack_rounded,
              onChangeFile: _reset,
            ),
            const SizedBox(height: 20),
            if (_durationKnown) ...[
              Text('Trim range', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              RangeSlider(
                values: _range,
                min: 0,
                max: _source!.durationMs!.toDouble(),
                labels: RangeLabels(
                  FormatUtils.duration(_range.start.round()),
                  FormatUtils.duration(_range.end.round()),
                ),
                onChanged: (values) => setState(() => _range = values),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Start: ${FormatUtils.duration(_range.start.round())}'),
                  Text('End: ${FormatUtils.duration(_range.end.round())}'),
                ],
              ),
            ] else
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Reading file duration…'),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _durationKnown ? _cut : null,
              icon: const Icon(Icons.content_cut_rounded),
              label: const Text('Cut Audio'),
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
              stageLabel: 'Cutting audio',
              progress: _progress,
              onCancel: () => _ffmpeg.cancel(),
            ),
          ],
        );

      case _State.success:
        final result = _result!;
        return SuccessResultCard(
          fileName: result.fileName,
          format: result.format,
          sizeBytes: result.sizeBytes,
          durationMs: _range.end.round() - _range.start.round(),
          onOpen: () => OpenFilex.open(result.path),
          onShare: () => SharePlus.instance.share(ShareParams(files: [XFile(result.path)])),
          onSave: () => showAppSnackBar(context, 'Saved to MediaMint'),
          onConvertAnother: _reset,
        );

      case _State.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ErrorView(message: _errorMessage, onRetry: _reset),
          ],
        );
    }
  }
}
