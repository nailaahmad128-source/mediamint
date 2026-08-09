import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_utils.dart';
import '../../shared/models/recent_file_model.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_view.dart';
import 'widgets/recent_file_tile.dart';

class RecentFilesScreen extends StatefulWidget {
  const RecentFilesScreen({super.key});

  @override
  State<RecentFilesScreen> createState() => _RecentFilesScreenState();
}

class _RecentFilesScreenState extends State<RecentFilesScreen> {
  final StorageService _storage = StorageService();
  List<RecentFileModel> _files = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final files = await _storage.getRecentFiles();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  Future<void> _open(RecentFileModel file) async {
    if (!await File(file.path).exists()) {
      _showMissingFileDialog(file);
      return;
    }
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done && mounted) {
      showAppSnackBar(context, 'No app found to open this file.', isError: true);
    }
  }

  Future<void> _share(RecentFileModel file) async {
    if (!await File(file.path).exists()) {
      _showMissingFileDialog(file);
      return;
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
  }

  Future<void> _rename(RecentFileModel file) async {
    final controller = TextEditingController(
      text: FileUtils.nameWithoutExtension(file.fileName),
    );
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || newName == FileUtils.nameWithoutExtension(file.fileName)) {
      return;
    }

    final extension = FileUtils.extensionOf(file.path);
    final directory = File(file.path).parent.path;
    final newPath = '$directory${Platform.pathSeparator}$newName.$extension';

    try {
      final renamed = await File(file.path).rename(newPath);
      await _storage.updateRecentFilePath(file.path, renamed.path, '$newName.$extension');
      await _load();
      if (mounted) showAppSnackBar(context, 'Renamed to $newName.$extension');
    } catch (_) {
      if (mounted) showAppSnackBar(context, 'Couldn\'t rename this file.', isError: true);
    }
  }

  Future<void> _delete(RecentFileModel file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text('"${file.fileName}" will be permanently deleted from your device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await FileUtils.deleteIfExists(file.path);
    await _storage.removeRecentFile(file.path);
    await _load();
    if (mounted) showAppSnackBar(context, 'File deleted');
  }

  void _showMissingFileDialog(RecentFileModel file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('File not found'),
        content: Text(
          '"${file.fileName}" no longer exists at its saved location. It may have been moved or deleted outside MediaMint.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _storage.removeRecentFile(file.path);
              await _load();
            },
            child: const Text('Remove from list'),
          ),
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recent Files')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _files.isEmpty
                ? const Center(
                    child: EmptyState(
                      icon: Icons.audiotrack_rounded,
                      title: 'No recent files',
                      message: 'Your converted audio files will appear here.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: AppTheme.pagePadding,
                      itemCount: _files.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final file = _files[index];
                        return Card(
                          child: RecentFileTile(
                            file: file,
                            onOpen: () => _open(file),
                            onShare: () => _share(file),
                            onRename: () => _rename(file),
                            onDelete: () => _delete(file),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
