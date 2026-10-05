import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class BitrateSelector extends StatelessWidget {
  final int selected;
  final bool Function(int kbps) isLocked;
  final ValueChanged<int> onChanged;

  const BitrateSelector({
    super.key,
    required this.selected,
    required this.isLocked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppConstants.bitrateOptionsKbps.map((kbps) {
        final locked = isLocked(kbps);
        return ChoiceChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$kbps kbps'),
              if (locked) ...[
                const SizedBox(width: 4),
                const Icon(Icons.lock_outline_rounded, size: 14),
              ],
            ],
          ),
          selected: selected == kbps,
          onSelected: (_) => onChanged(kbps),
        );
      }).toList(),
    );
  }
}
