import 'package:flutter/widgets.dart';

/// Abstraction over "an ad provider" so the rest of the app never imports
/// a specific ad SDK. No ad SDK is wired in per the build spec — this
/// exists purely so a future provider (AdMob, etc.) can be dropped in by
/// implementing this interface, without touching call sites.
///
/// [NoOpAdService] is the only implementation right now: every method is a
/// harmless no-op / returns an empty widget, and premium users would be
/// routed around this service entirely by [FeatureGate.isUnlocked]
/// (PremiumFeature.noAds) at the call site.
abstract class AdService {
  Future<void> initialize();
  Widget bannerPlaceholder(BuildContext context);
  Future<bool> showInterstitial();
}

class NoOpAdService implements AdService {
  @override
  Future<void> initialize() async {}

  @override
  Widget bannerPlaceholder(BuildContext context) => const SizedBox.shrink();

  @override
  Future<bool> showInterstitial() async => false;
}
