import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Google Play product IDs — these MUST match the subscription IDs
/// you create in Google Play Console → Monetization → Subscriptions.
class PurchaseIds {
  static const String monthly  = 'clush_plus_1month';
  static const String quarter  = 'clush_plus_3months';
  static const String half     = 'clush_plus_6months';
  static const String annual   = 'clush_plus_12months';

  static const List<String> all = [monthly, quarter, half, annual];
}

/// Singleton service that manages Google Play subscriptions.
class PurchaseService {
  PurchaseService._();
  static final PurchaseService instance = PurchaseService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  bool _available = false;
  bool get isAvailable => _available;

  /// Products fetched from the store, keyed by product ID.
  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => Map.unmodifiable(_products);

  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// Callbacks the UI can register to react to purchase events.
  void Function(String productId)? onPurchaseSuccess;
  void Function(String error)? onPurchaseError;
  void Function()? onPurchasePending;

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> init() async {
    _available = await _iap.isAvailable();
    if (!_available) {
      debugPrint('[PurchaseService] Store is not available');
      return;
    }

    // Listen for purchase updates (restores, completions, errors)
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (e) => debugPrint('[PurchaseService] Stream error: $e'),
    );

    await loadProducts();
  }

  Future<void> loadProducts() async {
    final response = await _iap.queryProductDetails(PurchaseIds.all.toSet());

    if (response.error != null) {
      debugPrint('[PurchaseService] Product query error: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('[PurchaseService] Products not found: ${response.notFoundIDs}');
    }

    _products.clear();
    for (final product in response.productDetails) {
      _products[product.id] = product;
    }
    debugPrint('[PurchaseService] Loaded ${_products.length} products');
  }

  // ─── Buy ──────────────────────────────────────────────────────────────────

  /// Initiates a subscription purchase for the given [productId].
  /// Returns `false` if the product wasn't found or the store is unavailable.
  bool buySubscription(String productId) {
    if (!_available) {
      onPurchaseError?.call('Google Play is not available on this device.');
      return false;
    }

    final product = _products[productId];
    if (product == null) {
      onPurchaseError?.call('Subscription plan not found. Please try again later.');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);

    // Use buyNonConsumable for subscriptions (they auto-renew, not consumed).
    _iap.buyNonConsumable(purchaseParam: purchaseParam);
    return true;
  }

  // ─── Handle updates ───────────────────────────────────────────────────────

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          onPurchasePending?.call();
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify & grant entitlement
          await _grantPremium(purchase);
          // Always complete the purchase to avoid refund
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          onPurchaseSuccess?.call(purchase.productID);
          break;

        case PurchaseStatus.error:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          onPurchaseError?.call(
            purchase.error?.message ?? 'Purchase failed. Please try again.',
          );
          break;

        case PurchaseStatus.canceled:
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          // User cancelled — no error shown
          break;
      }
    }
  }

  // ─── Grant Premium ────────────────────────────────────────────────────────

  Future<void> _grantPremium(PurchaseDetails purchase) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Calculate expiry based on which product was purchased
    final Duration duration;
    switch (purchase.productID) {
      case PurchaseIds.monthly:
        duration = const Duration(days: 30);
        break;
      case PurchaseIds.quarter:
        duration = const Duration(days: 90);
        break;
      case PurchaseIds.half:
        duration = const Duration(days: 180);
        break;
      case PurchaseIds.annual:
        duration = const Duration(days: 365);
        break;
      default:
        duration = const Duration(days: 30);
    }

    try {
      await Supabase.instance.client.from('profiles').update({
        'is_premium': true,
        'premium_expiry': DateTime.now().add(duration).toIso8601String(),
        'purchase_token': purchase.purchaseID,
      }).eq('id', userId);
      debugPrint('[PurchaseService] Premium granted until ${DateTime.now().add(duration)}');
    } catch (e) {
      debugPrint('[PurchaseService] Error updating premium status: $e');
    }
  }

  // ─── Restore ──────────────────────────────────────────────────────────────

  /// Restore previous purchases (e.g. after reinstall).
  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  // ─── Cleanup ──────────────────────────────────────────────────────────────

  void dispose() {
    _subscription?.cancel();
  }
}
