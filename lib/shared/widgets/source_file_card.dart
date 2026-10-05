import 'package:flutter/material.dart';
import '../../core/utils/format_utils.dart';
import '../models/media_file_model.dart';

class SourceFileCard extends StatelessWidget {
  final MediaFileModel file;
  final IconData icon;
  final VoidCallback? onChangeFile;

  const SourceFileCard({
    super.key,
    required this.file,
    this.icon = Icons.movie_outlined,
    this.onChangeFile,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.fileName,
                    style: textTheme.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    children: [
                      _MetaChip(text: FormatUtils.fileSize(file.sizeBytes)),
                      if (file.durationMs != null)
                        _MetaChip(text: FormatUtils.duration(file.durationMs!)),
                      if (file.formatLabel != null)
                        _MetaChip(text: file.formatLabel!.toUpperCase()),
                    ],
                  ),
                ],
              ),
            ),
            if (onChangeFile != null)
              IconButton(
                tooltip: 'Choose a different file',
                icon: const Icon(Icons.close),
                onPressed: onChangeFile,
              ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  const _MetaChip({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
    );
  }
}
