/// Export options chosen on the Video to Audio screen. Kept as a plain
/// value object so it can be passed straight into [FfmpegService] without
/// the service needing to know about widget state.
class ConversionSettings {
  final String format; // 'MP3' | 'M4A' | 'WAV'
  final int bitrateKbps; // ignored for WAV

  const ConversionSettings({
    required this.format,
    required this.bitrateKbps,
  });

  /// WAV is uncompressed PCM — there's no bitrate slider to show for it.
  bool get bitrateApplies => format != 'WAV';

  String get fileExtension => format.toLowerCase();

  ConversionSettings copyWith({String? format, int? bitrateKbps}) {
    return ConversionSettings(
      format: format ?? this.format,
      bitrateKbps: bitrateKbps ?? this.bitrateKbps,
    );
  }
}
