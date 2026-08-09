import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Thin wrapper around Flutter's built-in license page, themed to match
/// the rest of MediaMint instead of the default Material license screen.
class LicensesScreen extends StatelessWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LicensePage(
      applicationName: AppConstants.appName,
      applicationVersion: '1.0.0',
      applicationLegalese: '© ${DateTime.now().year} MediaMint. All rights reserved.\n\n'
          'MediaMint\'s audio engine is built on FFmpeg, distributed under LGPL/GPL. '
          'See individual package licenses below for full terms.',
    );
  }
}
