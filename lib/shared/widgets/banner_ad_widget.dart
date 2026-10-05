import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/constants/ad_ids.dart';
import '../../core/services/admob_ad_service.dart';
import '../../core/services/storage_service.dart';
import '../../features/premium/feature_gate.dart';
import '../../features/premium/subscription_service.dart';

/// A small, self-contained anchored adaptive banner.
///
/// Safe by construction:
///  * Renders nothing (zero extra height beyond the system inset) until an ad
///    has actually loaded, and again if loading fails.
///  * Hidden for premium users ([PremiumFeature.noAds]).
///  * Any error is swallowed — it can never affect conversion or navigation.
///
/// Intended for use as a Scaffold `bottomNavigationBar` on screens where no
/// conversion is running (currently the Home screen only).
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  final AdMobAdService _ads = AdMobAdService.instance;
  final SubscriptionService _subscription = SubscriptionService(StorageService());
  late final FeatureGate _gate = FeatureGate(_subscription);

  BannerAd? _banner;
  bool _loaded = false;
  bool _premiumResolved = false;
  bool _loadRequested = false;

  @override
  void initState() {
    super.initState();
    _ads.isReady.addListener(_maybeLoad);
    _subscription.load().then((_) {
      _premiumResolved = true;
      _maybeLoad();
    }).catchError((_) {
      // If premium state can't be read, treat as free user.
      _premiumResolved = true;
      _maybeLoad();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  void _maybeLoad() {
    if (!mounted || _loadRequested || !_premiumResolved || !_ads.isReady.value) {
      return;
    }
    if (_gate.isUnlocked(PremiumFeature.noAds)) return;
    _loadRequested = true;
    _loadBanner(MediaQuery.sizeOf(context).width.truncate());
  }

  Future<void> _loadBanner(int width) async {
    try {
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (!mounted || size == null) return;

      final banner = BannerAd(
        adUnitId: AdIds.bannerAdUnitId,
        size: size,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (!mounted) {
              ad.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (ad, error) {
            ad.dispose();
            if (!mounted) return;
            setState(() {
              _banner = null;
              _loaded = false;
            });
          },
        ),
      );
      _banner = banner;
      await banner.load();
    } catch (_) {
      // Ads are best-effort only.
    }
  }

  @override
  void dispose() {
    _ads.isReady.removeListener(_maybeLoad);
    _subscription.dispose();
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banner;
    final showAd = _loaded && banner != null;

    // SafeArea is always present so the bottom system inset is preserved
    // whether or not an ad is showing (a Scaffold removes the body's bottom
    // padding whenever a bottomNavigationBar is supplied).
    return SafeArea(
      top: false,
      child: showAd
          ? SizedBox(
              width: double.infinity,
              height: banner.size.height.toDouble(),
              child: Center(
                child: SizedBox(
                  width: banner.size.width.toDouble(),
                  height: banner.size.height.toDouble(),
                  child: AdWidget(ad: banner),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
