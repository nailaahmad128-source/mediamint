import 'package:flutter/material.dart';
import '../../../core/utils/format_utils.dart';
import '../../../shared/models/recent_file_model.dart';

class RecentFileTile extends StatelessWidget {
  final RecentFileModel file;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final bool dense;

  const RecentFileTile({
    super.key,
    required this.file,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
    this.dense = false,
  });

  IconData get _icon {
    switch (file.kind) {
      case RecentFileKind.ringtone:
        return Icons.music_note_rounded;
      case RecentFileKind.cutAudio:
        return Icons.content_cut_rounded;
      case RecentFileKind.compressedAudio:
        return Icons.compress_rounded;
      case RecentFileKind.extractedAudio:
        return Icons.graphic_eq_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: onOpen,
      contentPadding: dense
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(_icon, color: scheme.onPrimaryContainer, size: 20),
      ),
      title: Text(
        file.fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        '${file.format.toUpperCase()} · ${FormatUtils.fileSize(file.sizeBytes)} · ${FormatUtils.date(file.createdAt)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (value) {
          switch (value) {
            case 'open':
              onOpen();
              break;
            case 'share':
              onShare();
              break;
            case 'rename':
              onRename();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'open', child: Text('Open')),
          PopupMenuItem(value: 'share', child: Text('Share')),
          PopupMenuItem(value: 'rename', child: Text('Rename')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}
