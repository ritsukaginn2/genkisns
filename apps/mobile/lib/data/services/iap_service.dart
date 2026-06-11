import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:logger/logger.dart';
import 'llm_client.dart';

final logger = Logger();

class IAPService {
  static const String _proAnnualProductId = 'genki_sns_pro_annual';
  static const String _proMonthlyProductId = 'genki_sns_pro_monthly';

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  final LLMClient _llmClient;

  late StreamSubscription<List<PurchaseDetails>> _purchaseSubscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  final Set<String> _pendingVerification = {};

  IAPService({required LLMClient llmClient}) : _llmClient = llmClient;

  /// Initialize IAP service
  Future<void> init() async {
    try {
      _isAvailable = await _inAppPurchase.isAvailable();
      logger.i('IAP availability: $_isAvailable');

      if (!_isAvailable) {
        logger.w('In-App Purchase not available on this device');
        return;
      }

      // Load available products
      await _loadProducts();

      // Listen to purchase updates
      _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onError: (error) => logger.e('Purchase stream error: $error'),
      );

      // Restore previous purchases
      await _restorePurchases();
    } catch (e) {
      logger.e('IAP initialization error: $e');
    }
  }

  /// Load product details from App Store
  Future<void> _loadProducts() async {
    try {
      final response = await _inAppPurchase.queryProductDetails(
        {_proAnnualProductId, _proMonthlyProductId},
      );

      if (response.notFoundIDs.isNotEmpty) {
        logger.w('Products not found: ${response.notFoundIDs}');
      }

      _products = response.productDetails;
      logger.i('Loaded ${_products.length} products');
    } catch (e) {
      logger.e('Error loading products: $e');
    }
  }

  /// Get Pro annual product details
  ProductDetails? getProAnnualProduct() {
    try {
      return _products.firstWhere(
        (p) => p.id == _proAnnualProductId,
        orElse: () => throw Exception('Product not found'),
      );
    } catch (e) {
      logger.e('Error getting product: $e');
      return null;
    }
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
      logger.i('Purchase initiated for ${product.id}');
    } catch (e) {
      logger.e('Purchase error: $e');
      rethrow;
    }
  }

  /// Handle purchase updates
  Future<void> _handlePurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      logger.i('Purchase update: ${purchase.productID} - ${purchase.status}');

      switch (purchase.status) {
        case PurchaseStatus.pending:
          _pendingVerification.add(purchase.productID);
          logger.i('Purchase pending: ${purchase.productID}');
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _pendingVerification.remove(purchase.productID);

          // Verify receipt with backend
          if (purchase.productID == _proAnnualProductId) {
            await _verifyAndActivateProSubscription(purchase);
          }
          break;

        case PurchaseStatus.canceled:
          _pendingVerification.remove(purchase.productID);
          logger.i('Purchase canceled: ${purchase.productID}');
          break;

        case PurchaseStatus.error:
          _pendingVerification.remove(purchase.productID);
          logger.e('Purchase error: ${purchase.error}');
          break;
      }

    }
  }

  /// Verify receipt with backend and activate Pro subscription
  Future<void> _verifyAndActivateProSubscription(PurchaseDetails purchase) async {
    try {
      // Get the receipt (JWS token for iOS)
      final receiptData = purchase.verificationData.localVerificationData;

      logger.i('Verifying receipt for ${purchase.productID}');

      // Verify with backend
      final entitlements = await _llmClient.verifyPurchase(
        receiptJws: receiptData,
        productId: purchase.productID,
      );

      logger.i('Pro subscription activated! Quota: ${entitlements.quotaRemaining}/${entitlements.quotaTotal}');

      // Success - subscription is active
    } catch (e) {
      logger.e('Receipt verification failed: $e');
      rethrow;
    }
  }

  /// Restore previous purchases
  Future<void> _restorePurchases() async {
    try {
      logger.i('Restoring previous purchases...');
      await _inAppPurchase.restorePurchases();
      logger.i('Purchases restored');
    } catch (e) {
      logger.e('Error restoring purchases: $e');
    }
  }

  /// Check if a purchase is pending verification
  bool isPending(String productId) {
    return _pendingVerification.contains(productId);
  }

  /// Clean up resources
  Future<void> dispose() async {
    await _purchaseSubscription.cancel();
  }
}
