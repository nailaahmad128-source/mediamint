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
import '../premium/feature_gate.dart';
import '../premium/subscription_service.dart';

enum _State { empty, selected, processing, success, error }

class RingtoneScreen extends StatefulWidget {
  const RingtoneScreen({super.key});

  @override
  State<RingtoneScreen> createState() => _RingtoneScreenState();
}

class _RingtoneScreenState extends State<RingtoneScreen> {
  final FfmpegService _ffmpeg = FfmpegService();
  final OutputLocationService _outputLocation = OutputLocationService();
  final PermissionService _permissions = PermissionService();
  final StorageService _storage = StorageService();
  late final FeatureGate _featureGate;

  _State _state = _State.empty;
  MediaFileModel? _source;
  RangeValues _range = const RangeValues(0, AppConstants.ringtoneMaxSeconds * 1000.0);
  double _fadeInSec = 0;
  double _fadeOutSec = 0;
  double _volume = 1.0;
  double? _progress;
  String _errorMessage = '';
  RecentFileModel? _result;

  @override
  void initState() {
    super.initState();
    _featureGate = FeatureGate(SubscriptionService(_storage)..load());
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
      final durationMs = probe.durationMs ?? 0;
      final maxMs = AppConstants.ringtoneMaxSeconds * 1000;
      final clipEnd = durationMs > 0 ? (durationMs < maxMs ? durationMs : maxMs) : maxMs;
      setState(() {
        _source = _source!.copyWith(
          durationMs: durationMs,
          formatLabel: probe.formatName ?? FileUtils.extensionOf(path),
        );
        _range = RangeValues(0, clipEnd.toDouble());
      });
    } catch (_) {
      // Fall back to the default 0–30s window if probing fails.
    }
  }

  void _reset() {
    setState(() {
      _source = null;
      _result = null;
      _fadeInSec = 0;
      _fadeOutSec = 0;
      _volume = 1.0;
      _state = _State.empty;
    });
  }

  double get _clipMaxMs {
    final duration = _source?.durationMs;
    final cap = AppConstants.ringtoneMaxSeconds * 1000;
    if (duration == null || duration <= 0) return cap.toDouble();
    return (duration < cap ? duration : cap).toDouble();
  }

  Future<void> _create() async {
    final source = _source;
    if (source == null) return;

    final wantsFade = _fadeInSec > 0 || _fadeOutSec > 0;
    if (wantsFade && !_featureGate.isUnlocked(PremiumFeature.fadeInOut)) {
      showAppSnackBar(context, 'Fade in/out is a MediaMint Pro feature.');
      return;
    }

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
      final baseName = '${FileUtils.nameWithoutExtension(source.fileName)} (ringtone)';
      final outputPath = await FileUtils.uniqueFilePath(outputDir.path, baseName, 'm4a');

      await _ffmpeg.makeRingtone(
        inputPath: source.path,
        outputPath: outputPath,
        startMs: _range.start.round(),
        endMs: _range.end.round(),
        fadeInSec: _fadeInSec,
        fadeOutSec: _fadeOutSec,
        volumeMultiplier: _volume,
        onProgress: (fraction, _) {
          if (!mounted) return;
          setState(() => _progress = fraction);
        },
      );

      final size = await FileUtils.sizeOf(outputPath);
      final recent = RecentFileModel(
        path: outputPath,
        fileName: FileUtils.fileNameOf(outputPath),
        format: 'M4A',
        sizeBytes: size,
        createdAt: DateTime.now(),
        kind: RecentFileKind.ringtone,
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
        _errorMessage = 'Something went wrong while creating this ringtone.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ringtone Maker')),
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
            Icon(Icons.music_note_rounded, size: 72, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 20),
            Text('Select an audio file', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Clips are limited to ${AppConstants.ringtoneMaxSeconds} seconds',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
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
            Text('Clip (max ${AppConstants.ringtoneMaxSeconds}s)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            RangeSlider(
              values: RangeValues(
                _range.start.clamp(0, _clipMaxMs),
                _range.end.clamp(0, _clipMaxMs),
              ),
              min: 0,
              max: _clipMaxMs,
              labels: RangeLabels(
                FormatUtils.duration(_range.start.round()),
                FormatUtils.duration(_range.end.round()),
              ),
              onChanged: (values) {
                final capped = (values.end - values.start) > AppConstants.ringtoneMaxSeconds * 1000
                    ? RangeValues(values.start, values.start + AppConstants.ringtoneMaxSeconds * 1000)
                    : values;
                setState(() => _range = capped);
              },
            ),
            const SizedBox(height: 12),
            _SliderRow(
              label: 'Fade in',
              value: _fadeInSec,
              max: 5,
              display: '${_fadeInSec.toStringAsFixed(1)}s',
              locked: !_featureGate.isUnlocked(PremiumFeature.fadeInOut),
              onChanged: (v) => setState(() => _fadeInSec = v),
              onLockedTap: () => showAppSnackBar(context, 'Fade in/out is a MediaMint Pro feature.'),
            ),
            _SliderRow(
              label: 'Fade out',
              value: _fadeOutSec,
              max: 5,
              display: '${_fadeOutSec.toStringAsFixed(1)}s',
              locked: !_featureGate.isUnlocked(PremiumFeature.fadeInOut),
              onChanged: (v) => setState(() => _fadeOutSec = v),
              onLockedTap: () => showAppSnackBar(context, 'Fade in/out is a MediaMint Pro feature.'),
            ),
            _SliderRow(
              label: 'Volume',
              value: _volume,
              min: 0.2,
              max: 2.0,
              display: '${(_volume * 100).round()}%',
              onChanged: (v) => setState(() => _volume = v),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.music_note_rounded),
              label: const Text('Save as Ringtone'),
            ),
            const SizedBox(height: 8),
            Text(
              'Android doesn\'t let apps set the system ringtone directly on '
              'every device. MediaMint saves the ringtone file — set it as your '
              'ringtone from Settings ▸ Sound, or your file manager, if the '
              '"Set as ringtone" shortcut isn\'t offered on your phone.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
              stageLabel: 'Creating ringtone',
              progress: _progress,
              onCancel: () => _ffmpeg.cancel(),
            ),
          ],
        );

      case _State.success:
        final result = _result!;
        return SuccessResultCard(
          title: 'Ringtone Ready',
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
        return ErrorView(message: _errorMessage, onRetry: _reset);
    }
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final bool locked;
  final ValueChanged<double> onChanged;
  final VoidCallback? onLockedTap;

  const _SliderRow({
    required this.label,
    required this.value,
    this.min = 0,
    required this.max,
    required this.display,
    this.locked = false,
    required this.onChanged,
    this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              if (locked) ...[
                const SizedBox(width: 4),
                Icon(Icons.lock_outline_rounded,
                    size: 14, color: Theme.of(context).colorScheme.outline),
              ],
            ],
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: locked ? null : onChanged,
          ),
        ),
        SizedBox(width: 44, child: Text(display, textAlign: TextAlign.end)),
      ],
    );
  }
}
