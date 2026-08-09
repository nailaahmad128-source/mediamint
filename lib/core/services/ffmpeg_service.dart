import 'dart:async';
import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_audio/statistics.dart';
import 'package:ffmpeg_kit_flutter_new_audio/session.dart';

/// Thrown by [FfmpegService] on any failure so callers can show a
/// human-readable message instead of a raw FFmpeg log dump.
class MediaProcessingException implements Exception {
  final String message;
  final String? technicalDetail;
  MediaProcessingException(this.message, {this.technicalDetail});

  @override
  String toString() => message;
}

class MediaProbeResult {
  final int? durationMs;
  final String? formatName;
  final String? videoCodec;
  final String? audioCodec;
  final bool hasAudioStream;

  const MediaProbeResult({
    this.durationMs,
    this.formatName,
    this.videoCodec,
    this.audioCodec,
    this.hasAudioStream = false,
  });
}

/// Progress callback: 0.0–1.0 when the total duration is known, or null
/// when it isn't (still shown as an indeterminate spinner by the UI).
typedef ProgressCallback = void Function(double? fraction, String stageLabel);

/// Thin, purpose-built wrapper around FFmpegKit. Screens never call
/// FFmpegKit directly — everything goes through here so the command syntax
/// lives in exactly one place and every command handles cancellation and
/// failure the same way.
class FfmpegService {
  int? _activeSessionId;

  /// Inspects a media file and returns duration/format/codec info.
  /// Used both to populate the "selected file" preview card and to compute
  /// live progress percentage during conversion.
  Future<MediaProbeResult> probe(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();

    if (info == null) {
      final failStack = await session.getFailStackTrace();
      throw MediaProcessingException(
        'Couldn\'t read this file\'s details. It may be corrupted or in an '
        'unsupported format.',
        technicalDetail: failStack,
      );
    }

    final durationSeconds = double.tryParse(info.getDuration() ?? '');
    final streams = info.getStreams();

    String? videoCodec;
    String? audioCodec;
    var hasAudio = false;

    for (final stream in streams) {
      final type = stream.getType();
      if (type == 'video' && videoCodec == null) {
        videoCodec = stream.getCodec();
      } else if (type == 'audio') {
        hasAudio = true;
        audioCodec ??= stream.getCodec();
      }
    }

    return MediaProbeResult(
      durationMs: durationSeconds != null ? (durationSeconds * 1000).round() : null,
      formatName: info.getFormat(),
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      hasAudioStream: hasAudio,
    );
  }

  /// Extracts (and transcodes) the audio track from a video file.
  Future<void> extractAudio({
    required String inputPath,
    required String outputPath,
    required String format, // MP3 | M4A | WAV
    required int bitrateKbps,
    int? totalDurationMs,
    ProgressCallback? onProgress,
  }) async {
    final codecArgs = switch (format) {
      'MP3' => '-vn -c:a libmp3lame -b:a ${bitrateKbps}k',
      'M4A' => '-vn -c:a aac -b:a ${bitrateKbps}k',
      'WAV' => '-vn -c:a pcm_s16le',
      _ => throw MediaProcessingException('Unsupported output format: $format'),
    };

    final command =
        '-y -i "$inputPath" $codecArgs -ar 44100 "$outputPath"';

    await _runAndAwait(
      command: command,
      totalDurationMs: totalDurationMs,
      onProgress: onProgress,
      stageLabel: 'Extracting audio',
    );
  }

  /// Trims an audio file to [startMs]–[endMs], re-encoding to keep the
  /// output format consistent regardless of source codec.
  Future<void> cutAudio({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    ProgressCallback? onProgress,
  }) async {
    final startSec = (startMs / 1000).toStringAsFixed(3);
    final durationSec = ((endMs - startMs) / 1000).toStringAsFixed(3);
    final extension = outputPath.split('.').last.toLowerCase();
    final codecArgs = _codecArgsForExtension(extension, 192);

    final command =
        '-y -i "$inputPath" -ss $startSec -t $durationSec $codecArgs "$outputPath"';

    await _runAndAwait(
      command: command,
      totalDurationMs: endMs - startMs,
      onProgress: onProgress,
      stageLabel: 'Cutting audio',
    );
  }

  /// Trims plus optional fade in/out and volume gain, used by the Ringtone
  /// Maker. Fades are expressed in seconds and applied with the `afade`
  /// filter so they render into the exported file itself.
  Future<void> makeRingtone({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required double fadeInSec,
    required double fadeOutSec,
    required double volumeMultiplier,
    ProgressCallback? onProgress,
  }) async {
    final startSec = (startMs / 1000).toStringAsFixed(3);
    final clipDurationSec = (endMs - startMs) / 1000;
    final durationSec = clipDurationSec.toStringAsFixed(3);
    final extension = outputPath.split('.').last.toLowerCase();
    final codecArgs = _codecArgsForExtension(extension, 192);

    final filters = <String>[];
    if (fadeInSec > 0) {
      filters.add('afade=t=in:st=0:d=${fadeInSec.toStringAsFixed(2)}');
    }
    if (fadeOutSec > 0) {
      final fadeOutStart = (clipDurationSec - fadeOutSec).clamp(0, clipDurationSec);
      filters.add(
        'afade=t=out:st=${fadeOutStart.toStringAsFixed(2)}:d=${fadeOutSec.toStringAsFixed(2)}',
      );
    }
    if (volumeMultiplier != 1.0) {
      filters.add('volume=${volumeMultiplier.toStringAsFixed(2)}');
    }
    final filterArg = filters.isEmpty ? '' : '-af "${filters.join(',')}"';

    final command =
        '-y -i "$inputPath" -ss $startSec -t $durationSec $filterArg $codecArgs "$outputPath"';

    await _runAndAwait(
      command: command,
      totalDurationMs: endMs - startMs,
      onProgress: onProgress,
      stageLabel: 'Creating ringtone',
    );
  }

  /// Re-encodes an audio file at a lower bitrate to shrink its size.
  Future<void> compressAudio({
    required String inputPath,
    required String outputPath,
    required int targetBitrateKbps,
    int? totalDurationMs,
    ProgressCallback? onProgress,
  }) async {
    final extension = outputPath.split('.').last.toLowerCase();
    final codecArgs = _codecArgsForExtension(extension, targetBitrateKbps);
    final command = '-y -i "$inputPath" $codecArgs "$outputPath"';

    await _runAndAwait(
      command: command,
      totalDurationMs: totalDurationMs,
      onProgress: onProgress,
      stageLabel: 'Compressing audio',
    );
  }

  String _codecArgsForExtension(String extension, int bitrateKbps) {
    switch (extension) {
      case 'mp3':
        return '-c:a libmp3lame -b:a ${bitrateKbps}k';
      case 'm4a':
        return '-c:a aac -b:a ${bitrateKbps}k';
      case 'wav':
        return '-c:a pcm_s16le';
      default:
        return '-c:a libmp3lame -b:a ${bitrateKbps}k';
    }
  }

  Future<void> _runAndAwait({
    required String command,
    required int? totalDurationMs,
    required ProgressCallback? onProgress,
    required String stageLabel,
  }) async {
    final completer = Completer<void>();

    await FFmpegKit.executeAsync(
      command,
      (Session session) async {
        _activeSessionId = null;
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          if (!completer.isCompleted) completer.complete();
        } else if (ReturnCode.isCancel(returnCode)) {
          if (!completer.isCompleted) {
            completer.completeError(
              MediaProcessingException('Cancelled'),
            );
          }
        } else {
          final logs = await session.getAllLogsAsString();
          if (!completer.isCompleted) {
            completer.completeError(
              MediaProcessingException(
                _humanizeFailure(logs ?? ''),
                technicalDetail: logs,
              ),
            );
          }
        }
      },
      null, // log callback — not needed, we read logs on failure instead
      (Statistics stats) {
        if (onProgress == null) return;
        if (totalDurationMs != null && totalDurationMs > 0) {
          final processedMs = stats.getTime();
          final fraction = (processedMs / totalDurationMs).clamp(0.0, 1.0);
          onProgress(fraction, stageLabel);
        } else {
          onProgress(null, stageLabel);
        }
      },
    ).then((session) async {
      _activeSessionId = session.getSessionId();
    });

    return completer.future;
  }

  String _humanizeFailure(String logs) {
    final lower = logs.toLowerCase();
    if (lower.contains('permission denied')) {
      return 'MediaMint doesn\'t have permission to read or write that file.';
    }
    if (lower.contains('no space left')) {
      return 'Not enough storage space to finish this operation.';
    }
    if (lower.contains('invalid data found') || lower.contains('moov atom not found')) {
      return 'This file appears to be corrupted or incomplete.';
    }
    if (lower.contains('does not contain any stream')) {
      return 'This file doesn\'t contain a readable audio track.';
    }
    return 'Something went wrong while processing this file.';
  }

  /// Cancels whatever is currently running, if anything.
  Future<void> cancel() async {
    if (_activeSessionId != null) {
      await FFmpegKit.cancel(_activeSessionId);
    } else {
      await FFmpegKit.cancel();
    }
  }
}
