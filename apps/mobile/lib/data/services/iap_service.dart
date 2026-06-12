import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';
import 'llm_client.dart';

final Logger _logger = Logger();

class IAPService {
  static const String _proAnnualProductId = 'genki_sns_pro_annual';
  static const String _proMonthlyProductId = 'genki_sns_pro_monthly';
  static const Set<String> _proProductIds = {
    _proAnnualProductId,
    _proMonthlyProductId,
  };

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final LLMClient _llmClient;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  final Set<String> _pendingVerification = {};

  IAPService({required LLMClient llmClient}) : _llmClient = llmClient;

  /// Initialize IAP service
  Future<void> init() async {
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      _logger.i('IAP availability: $_isAvailable');

      if (!_isAvailable) {
        _logger.w('In-App Purchase not available on this device');
        return;
      }

      // Load available products
      await _loadProducts();

      // Listen to purchase updates
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onError: (error) => _logger.e('Purchase stream error: $error'),
      );

      // Restore previous purchases
      await _restorePurchases();
    } catch (e) {
      _logger.e('IAP initialization error: $e');
    }
  }

  /// Load product details from App Store
  Future<void> _loadProducts() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(
        {_proAnnualProductId, _proMonthlyProductId},
      );

      if (response.notFoundIDs.isNotEmpty) {
        _logger.w('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      _logger.i('Loaded ${_products.length} products');
    } catch (e) {
      _logger.e('Error loading products: $e');
    }
  }

  /// Get Pro annual product details
  ProductDetails? getProAnnualProduct() {
    for (final product in _products) {
      if (product.id == _proAnnualProductId) return product;
    }
    return null;
  }

  /// Purchase Pro annual plan
  Future<void> purchaseProAnnual() async {
    if (!_isAvailable) {
      throw Exception('IAP not available');
    }

    final product = getProAnnualProduct();
    if (product == null) {
      throw Exception('Product not available');
    }

    try {
      await _inAppPurchase.buyNonConsumable(purchaseParam: PurchaseParam(productDetails: product));
      _logger.i('Purchase initiated for ${product.id}');
    } catch (e) {
      _logger.e('Purchase error: $e');
      rethrow;
    }
  }

  /// Handle purchase updates
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _logger.i('Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _pendingVerification.add(purchase.productID);
          _logger.i('Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _pendingVerification.remove(purchase.productID);

          // Verify receipt with backend (both annual and monthly Pro plans).
          // Errors are logged but must not escape the stream listener.
          if (_proProductIds.contains(purchase.productID)) {
            try {
              await _verifyAndActivateProSubscription(purchase);
            } catch (e) {
              _logger.e('Verification failed for ${purchase.productID}: $e');
            }
          }
          break;

        case PurchaseStatus.canceled:
          _pendingVerification.remove(purchase.productID);
          _logger.i('Purchase canceled: ${purchase.productID}');
          break;

        case PurchaseStatus.error:
          _pendingVerification.remove(purchase.productID);
          _logger.e('Purchase error: ${purchase.error}');
          break;
      }

      // Apple requires every delivered transaction to be finished, otherwise
      // StoreKit redelivers it on every launch.
      if (purchase.pendingCompletePurchase) {
        try {
          await _inAppPurchase.completePurchase(purchase);
        } catch (e) {
          _logger.e('completePurchase failed for ${purchase.productID}: $e');
        }
      }
    }
  }

  /// Verify receipt with backend and activate Pro subscription
  Future<void> _verifyAndActivateProSubscription(PurchaseDetails purchase) async {
    try {
      // Get the receipt (JWS token for iOS)
      final receiptData = purchase.verificationData.localVerificationData;

      _logger.i('Verifying receipt for ${purchase.productID}');

      // Verify with backend
      final entitlements = await _llmClient.verifyPurchase(
        receiptJws: receiptData,
        productId: purchase.productID,
      );

      _logger.i('Pro subscription activated! Quota: ${entitlements.quotaRemaining}/${entitlements.quotaTotal}');

      // Success - subscription is active
    } catch (e) {
      _logger.e('Receipt verification failed: $e');
      rethrow;
    }
  }

  /// Restore previous purchases
  Future<void> _restorePurchases() async {
    try {
      _logger.i('Restoring previous purchases...');
      await _inAppPurchase.restorePurchases();
      _logger.i('Purchases restored');
    } catch (e) {
      _logger.e('Error restoring purchases: $e');
    }
  }

  /// Check if a purchase is pending verification
  bool isPending(String productId) {
    return _pendingVerification.contains(productId);
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
  }
}
