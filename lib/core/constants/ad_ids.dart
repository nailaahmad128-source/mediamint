import 'package:flutter/foundation.dart';

/// All AdMob identifiers live here so going live is a one-file change.
///
/// ⚠️ BEFORE RELEASE — replace the two values marked `REPLACE`:
///   1. [_prodBannerAdUnitId]  (below)
///   2. The AdMob *App ID* in android/app/src/main/AndroidManifest.xml
///      (`com.google.android.gms.ads.APPLICATION_ID` meta-data).
///
/// While [useTestAds] is true, Google's official sample ad unit is used, so
/// no real ad traffic is generated during development or testing.
class AdIds {
  AdIds._();

  /// Set to `false` once the real ad unit below has been filled in.
  static const bool useTestAds = false;

  // Google's public TEST banner ad unit (Android).
  static const String _testBannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // REPLACE with your real banner ad unit, e.g. 'ca-app-pub-XXXXXXXXXXXXXXXX/NNNNNNNNNN'.
  static const String _prodBannerAdUnitId = 'ca-app-pub-5092722454826299/8629809727';

  static String get bannerAdUnitId {
    // Never serve production ad units from a debug build (avoids invalid
    // traffic / account risk from your own test taps).
    if (useTestAds || kDebugMode) return _testBannerAdUnitId;
    return _prodBannerAdUnitId;
  }
}
