import 'package:flutter/material.dart';

/// MediaMint's brand palette.
///
/// The app is a media utility, not a lifestyle brand, so the palette is
/// intentionally restrained: one confident seed color (a deep teal — reads
/// as "audio waveform / studio" rather than the generic purple most
/// generated Flutter apps default to), plus neutral surfaces. No gradients,
/// no accent soup.
class AppColors {
  AppColors._();

  static const Color seed = Color(0xFF0F766E); // teal-700
  static const Color seedDark = Color(0xFF14B8A6); // teal-400, for dark mode

  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);

  static const Color lightSurfaceDim = Color(0xFFF4F5F7);
  static const Color darkSurfaceDim = Color(0xFF121417);
}
