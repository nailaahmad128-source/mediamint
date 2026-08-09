import 'subscription_service.dart';

/// Every feature in the app that has a free/premium distinction is listed
/// here, exactly once. Adding a new premium feature means adding one entry
/// to this enum and one line in [FeatureGate.isUnlocked] — not scattering
/// `if (isPremium)` checks through feature screens.
enum PremiumFeature {
  bitrate320,
  wavExport,
  batchConversion,
  advancedTrimming,
  fadeInOut,
  volumeNormalization,
  extraFormats,
  noAds,
  premiumThemes,
}

/// Answers "can the current user use X" by combining [SubscriptionService]
/// with the (currently trivial, all-true) per-feature rules below. Screens
/// call [FeatureGate.isUnlocked] and show an upgrade prompt when it's
/// false — they never touch [SubscriptionService] directly.
class FeatureGate {
  final SubscriptionService subscriptionService;

  FeatureGate(this.subscriptionService);

  static const Set<PremiumFeature> _freeFeatures = {};

  bool isUnlocked(PremiumFeature feature) {
    if (_freeFeatures.contains(feature)) return true;
    return subscriptionService.isPremium;
  }

  bool get isPremium => subscriptionService.isPremium;
}
