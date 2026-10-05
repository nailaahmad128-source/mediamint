import 'package:flutter/foundation.dart';
import '../../core/services/storage_service.dart';

enum SubscriptionStatus { free, premium }

/// Single source of truth for "is this user premium".
///
/// This is intentionally the *only* place that answers that question.
/// Screens and [FeatureGate] read [isPremium] — they never check purchase
/// state, entitlement flags, or dates themselves. That's what makes it
/// possible to wire in real Google Play Billing later without touching any
/// feature code: only this file's internals change.
///
/// Current implementation: a safe, local development/test toggle
/// (persisted via [StorageService]) with NO fake purchase flow, no fake
/// receipts, and no simulated payment UI — flipping it is explicitly a
/// developer/QA action, exposed in Settings behind a "Developer options"
/// label so it's never mistaken for a real purchase by an end user.
///
/// Future Play Billing integration point: replace [_loadStatus] and
/// [refresh] with calls into the `in_app_purchase` (or billing client)
/// query-purchases flow, keep [isPremium] as a ValueNotifier<bool> exactly
/// as-is, and nothing outside this file needs to change.
class SubscriptionService extends ChangeNotifier {
  final StorageService _storage;
  SubscriptionStatus _status = SubscriptionStatus.free;

  SubscriptionService(this._storage);

  SubscriptionStatus get status => _status;
  bool get isPremium => _status == SubscriptionStatus.premium;

  Future<void> load() async {
    final devOverride = await _storage.getDevPremiumOverride();
    _status = devOverride ? SubscriptionStatus.premium : SubscriptionStatus.free;
    notifyListeners();
  }

  /// Developer/QA-only. Never exposed as a purchase button — see
  /// Settings > Developer options in the UI, clearly labeled as a test
  /// toggle, not a real transaction.
  Future<void> setDevPremiumOverride(bool enabled) async {
    await _storage.setDevPremiumOverride(enabled);
    await load();
  }
}
