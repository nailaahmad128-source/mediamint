enum RecentFileKind { extractedAudio, cutAudio, ringtone, compressedAudio }

extension RecentFileKindLabel on RecentFileKind {
  String get label {
    switch (this) {
      case RecentFileKind.extractedAudio:
        return 'Extracted Audio';
      case RecentFileKind.cutAudio:
        return 'Cut Audio';
      case RecentFileKind.ringtone:
        return 'Ringtone';
      case RecentFileKind.compressedAudio:
        return 'Compressed Audio';
    }
  }
}

/// Lightweight metadata for a file MediaMint created. We deliberately do not
/// store the audio itself here — only a pointer to it on disk plus a few
/// display fields — so this stays cheap to keep in SharedPreferences as a
/// JSON array instead of standing up an on-device database.
class RecentFileModel {
  final String path;
  final String fileName;
  final String format;
  final int sizeBytes;
  final DateTime createdAt;
  final RecentFileKind kind;

  const RecentFileModel({
    required this.path,
    required this.fileName,
    required this.format,
    required this.sizeBytes,
    required this.createdAt,
    required this.kind,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'fileName': fileName,
        'format': format,
        'sizeBytes': sizeBytes,
        'createdAt': createdAt.toIso8601String(),
        'kind': kind.name,
      };

  factory RecentFileModel.fromJson(Map<String, dynamic> json) {
    return RecentFileModel(
      path: json['path'] as String,
      fileName: json['fileName'] as String,
      format: json['format'] as String,
      sizeBytes: json['sizeBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      kind: RecentFileKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => RecentFileKind.extractedAudio,
      ),
    );
  }

  RecentFileModel copyWith({String? fileName}) {
    return RecentFileModel(
      path: path,
      fileName: fileName ?? this.fileName,
      format: format,
      sizeBytes: sizeBytes,
      createdAt: createdAt,
      kind: kind,
    );
  }
}
