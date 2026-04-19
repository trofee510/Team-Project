import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/constants.dart';
import 'supabase_service.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(ref.watch(supabaseServiceProvider));
});

/// RevenueCat integration. Entitlement check is server-side — the client
/// kicks off purchases and triggers a refresh, but trusts Supabase
/// `subscribers.is_pro` (set by the RC webhook) as the source of truth.
class SubscriptionService {
  final SupabaseService _supabase;
  bool _configured = false;

  SubscriptionService(this._supabase);

  Future<void> configure() async {
    if (_configured) return;
    final key = Platform.isIOS
        ? AppConstants.revenueCatIosKey
        : AppConstants.revenueCatAndroidKey;
    if (key.isEmpty) return; // No RC configured — skip silently in dev.

    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(key));
    _configured = true;
  }

  /// Associate the current Supabase user with RC so the webhook can match
  /// customer → user_id. Call after sign-in AND after configure().
  Future<void> identifyUser() async {
    if (!_configured) await configure();
    if (!_configured) return;
    final user = _supabase.currentUser;
    if (user == null) return;
    await Purchases.logIn(user.id);
  }

  Future<void> logOut() async {
    if (!_configured) return;
    try {
      await Purchases.logOut();
    } catch (_) {
      // RC throws if not logged in; safe to swallow.
    }
  }

  Future<Offerings?> getOfferings() async {
    if (!_configured) await configure();
    if (!_configured) return null;
    try {
      return await Purchases.getOfferings();
    } catch (_) {
      return null;
    }
  }

  /// Purchases a package. Returns the new server-confirmed Pro status.
  /// We deliberately re-fetch from Supabase rather than trusting RC's
  /// customer info locally — the webhook write is our source of truth.
  Future<bool> purchasePackage(Package pkg) async {
    if (!_configured) await configure();
    await Purchases.purchasePackage(pkg);
    return _confirmProWithRetry();
  }

  Future<bool> restorePurchases() async {
    if (!_configured) await configure();
    await Purchases.restorePurchases();
    return _confirmProWithRetry();
  }

  /// Webhook round-trip takes a couple seconds — poll briefly.
  Future<bool> _confirmProWithRetry() async {
    for (var i = 0; i < 5; i++) {
      final pro = await _supabase.fetchIsPro();
      if (pro) return true;
      await Future.delayed(const Duration(seconds: 1));
    }
    return false;
  }
}
