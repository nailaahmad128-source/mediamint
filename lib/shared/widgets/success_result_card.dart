import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';

/// "Audio Ready" style success card shown after Video to Audio, Audio
/// Cutter, Ringtone Maker, and Compressor all finish. Same visual language
/// everywhere so a successful export always feels the same regardless of
/// which tool produced it.
class SuccessResultCard extends StatelessWidget {
  final String title;
  final String fileName;
  final String format;
  final int sizeBytes;
  final int? durationMs;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onConvertAnother;

  const SuccessResultCard({
    super.key,
    this.title = 'Audio Ready',
    required this.fileName,
    required this.format,
    required this.sizeBytes,
    this.durationMs,
    required this.onOpen,
    required this.onShare,
    required this.onSave,
    required this.onConvertAnother,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, size: 44, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(height: 20),
        Text(title, style: textTheme.headlineSmall),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row(context, 'File name', fileName),
                const Divider(height: 20),
                _row(context, 'Format', format),
                const Divider(height: 20),
                _row(context, 'Size', FormatUtils.fileSize(sizeBytes)),
                if (durationMs != null) ...[
                  const Divider(height: 20),
                  _row(context, 'Duration', FormatUtils.duration(durationMs!)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Open'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Save'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: onConvertAnother,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Convert Another'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            )),
        Flexible(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
