import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../shared/widgets/banner_ad_widget.dart';
import 'ad_service.dart';

/// AdMob-backed implementation of the app's existing [AdService] contract.
///
/// Design goals:
///  * Never throws and never blocks the UI — every failure is swallowed, the
///    app simply shows no ad.
///  * Fire-and-forget at startup (see main.dart); nothing awaits it.
///  * Gathers user consent (Google UMP) before initializing the SDK, as
///    required for users in the EEA/UK. Elsewhere this is a no-op.
///  * Banner only. No interstitial / rewarded ads.
class AdMobAdService implements AdService {
  AdMobAdService._();
  static final AdMobAdService instance = AdMobAdService._();

  /// Flips to true once the Mobile Ads SDK is initialized and ads may be
  /// requested. Banner widgets listen to this and load lazily.
  final ValueNotifier<bool> isReady = ValueNotifier<bool>(false);

  bool _started = false;

  @override
  Future<void> initialize() async {
    if (_started) return;
    _started = true;
    try {
      await _gatherConsent();
      if (await ConsentInformation.instance.canRequestAds()) {
        await MobileAds.instance.initialize();
        isReady.value = true;
      }
    } catch (e) {
      debugPrint('AdMob init skipped: $e');
    }
  }

  Future<void> _gatherConsent() {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? _) => finish());
        },
        (FormError _) => finish(),
      );
    } catch (_) {
      finish();
    }
    return done.future;
  }

  @override
  Widget bannerPlaceholder(BuildContext context) => const BannerAdWidget();

  /// Interstitials are intentionally not used in this app.
  @override
  Future<bool> showInterstitial() async => false;
}
