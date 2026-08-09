import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: SafeArea(
        child: ListView(
          padding: AppTheme.pagePadding,
          children: [
            Card(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: scheme.primary),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'MediaMint processes your files locally on your device. '
                        'Your videos and audio are not uploaded to a server.',
                        style: textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _Section(
              title: 'How MediaMint works',
              body: 'Every conversion, cut, and export runs entirely on your phone using a '
                  'local media engine. There is no backend server, no account, and no sign-in — '
                  'the app never sends your media files anywhere.',
            ),
            _Section(
              title: 'What MediaMint stores',
              body: 'MediaMint keeps a small amount of information on your device only: your '
                  'app settings (theme, default format, etc.) and a lightweight list of the '
                  'files you\'ve created (name, size, date) so the Recent Files screen can show '
                  'them. This never leaves your device and is deleted if you uninstall the app.',
            ),
            _Section(
              title: 'File access',
              body: 'MediaMint uses Android\'s built-in file picker to open videos and audio you '
                  'choose — it never browses your storage on its own. Converted files are saved '
                  'either to the app\'s own folder or to your Downloads folder, depending on your '
                  'Settings choice.',
            ),
            _Section(
              title: 'Ads',
              body: 'The free version of MediaMint may show ads in a future update; the paid '
                  'version removes them. No advertising SDK is currently active in the app.',
            ),
            _Section(
              title: 'Changes to this page',
              body: 'If MediaMint\'s data practices ever change, this page will be updated to '
                  'reflect exactly what the app does — nothing here is a promise about features '
                  'that aren\'t actually implemented.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;

  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
