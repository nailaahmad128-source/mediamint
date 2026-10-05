/// Describes a source file the user picked (video or audio), enriched with
/// probed metadata (duration, format) once FFprobe has inspected it.
/// This is transient, in-memory state for a single screen session — it is
/// never persisted; only completed outputs become [RecentFileModel]s.
class MediaFileModel {
  final String path;
  final String fileName;
  final int sizeBytes;

  /// Milliseconds. Null until probing completes.
  final int? durationMs;

  /// e.g. "MP4", "MKV". Null until probing completes.
  final String? formatLabel;

  /// e.g. "h264 / aac" for a quick technical summary. Optional.
  final String? codecSummary;

  const MediaFileModel({
    required this.path,
    required this.fileName,
    required this.sizeBytes,
    this.durationMs,
    this.formatLabel,
    this.codecSummary,
  });

  MediaFileModel copyWith({
    int? durationMs,
    String? formatLabel,
    String? codecSummary,
  }) {
    return MediaFileModel(
      path: path,
      fileName: fileName,
      sizeBytes: sizeBytes,
      durationMs: durationMs ?? this.durationMs,
      formatLabel: formatLabel ?? this.formatLabel,
      codecSummary: codecSummary ?? this.codecSummary,
    );
  }
}
