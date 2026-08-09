import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Presents what Premium unlocks. Deliberately has no purchase button wired
/// to a real transaction — per the build spec, fake purchases are never
/// implemented. This screen is ready to gain a real "Subscribe" button the
/// moment Google Play Billing is integrated into [SubscriptionService];
/// until then it's an honest preview, not a dead end, so the "Developer
/// options" toggle in Settings is the only way to preview Pro during
/// development.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  static const _features = [
    ('320 kbps export', Icons.high_quality_outlined),
    ('WAV export', Icons.graphic_eq_rounded),
    ('Batch conversion', Icons.layers_outlined),
    ('Advanced trimming', Icons.tune_rounded),
    ('Fade in / fade out', Icons.waves_rounded),
    ('Volume normalization', Icons.equalizer_rounded),
    ('More export formats', Icons.library_music_outlined),
    ('No ads', Icons.block_rounded),
    ('Premium themes', Icons.palette_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('MediaMint Pro')),
      body: SafeArea(
        child: ListView(
          padding: AppTheme.pagePadding,
          children: [
            Icon(Icons.workspace_premium_rounded, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Unlock everything MediaMint can do',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'A one-time preview of what Pro will include — pricing and purchase '
              'aren\'t available in this build yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Column(
                children: [
                  for (var i = 0; i < _features.length; i++) ...[
                    ListTile(
                      leading: Icon(_features[i].$2, color: scheme.primary),
                      title: Text(_features[i].$1),
                    ),
                    if (i != _features.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: null,
              child: const Text('Purchases coming soon'),
            ),
          ],
        ),
      ),
    );
  }
}
