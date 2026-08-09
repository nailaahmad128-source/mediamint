import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Shown while FFmpeg is running. Handles both determinate progress (when
/// the source duration is known, so percentage is meaningful) and
/// indeterminate (when it isn't — e.g. very first statistics callback
/// hasn't arrived yet).
class ProcessingCard extends StatelessWidget {
  final String stageLabel;
  final double? progress; // null = indeterminate
  final VoidCallback onCancel;

  const ProcessingCard({
    super.key,
    required this.stageLabel,
    required this.progress,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percentLabel =
        progress != null ? '${(progress! * 100).clamp(0, 100).toStringAsFixed(0)}%' : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(stageLabel, style: Theme.of(context).textTheme.titleSmall),
                if (percentLabel != null)
                  Text(
                    percentLabel,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                        ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
