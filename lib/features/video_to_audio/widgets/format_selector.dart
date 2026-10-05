import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class FormatSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const FormatSelector({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: AppConstants.audioOutputFormats
          .map((format) => ButtonSegment(value: format, label: Text(format)))
          .toList(),
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}
