import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef PurchaseEventEmitter = Future<void> Function(
    String event, dynamic data);

class InAppPurchasePlugin extends Plugin {
  final PurchaseEventEmitter? eventEmitter;

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  bool _available = false;

  InAppPurchasePlugin({this.eventEmitter});

  @override
  String get name => 'inAppPurchase';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'In-app purchase and subscription plugin';

  @override
  List<String> get supportedMethods => [
        'isAvailable',
        'getProducts',
        'buyProduct',
        'buySubscription',
        'restorePurchases',
        'completePurchase',
        'getPurchaseHistory',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _available = await _iap.isAvailable();

    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onError: (error) {
        BridgeLogger.error('InAppPurchase', 'Stream error: $error');
        eventEmitter?.call('purchase.error', {
          'message': error.toString(),
        });
      },
    );

    BridgeLogger.info('InAppPurchase', 'Available: $_available');
  }

  @override
  Future<void> onDispose() async {
    await _purchaseSub?.cancel();
  }

  void _handlePurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      final data = _purchaseToMap(purchase);

      switch (purchase.status) {
        case PurchaseStatus.pending:
          eventEmitter?.call('purchase.pending', data);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          eventEmitter?.call('purchase.completed', data);
          // Auto-complete
          if (purchase.pendingCompletePurchase) {
            _iap.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.error:
          eventEmitter?.call('purchase.error', {
            ...data,
            'errorMessage': purchase.error?.message,
            'errorCode': purchase.error?.code,
          });
          break;
        case PurchaseStatus.canceled:
          eventEmitter?.call('purchase.cancelled', data);
          break;
      }
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isAvailable':
        return {'available': _available};
      case 'getProducts':
        return _getProducts(args);
      case 'buyProduct':
        return _buyProduct(args);
      case 'buySubscription':
        return _buySubscription(args);
      case 'restorePurchases':
        return _restorePurchases();
      case 'completePurchase':
        return _completePurchase(args);
      case 'getPurchaseHistory':
        return {'note': 'Use purchase events for history'};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'available': _available,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getProducts(
    Map<String, dynamic> args,
  ) async {
    final ids = Set<String>.from(args['productIds'] as List);

    try {
      final response = await _iap.queryProductDetails(ids);

      if (response.notFoundIDs.isNotEmpty) {
        BridgeLogger.warn(
          'InAppPurchase',
          'Not found: ${response.notFoundIDs.join(", ")}',
        );
      }

      final products = response.productDetails
          .map((p) => {
                'id': p.id,
                'title': p.title,
                'description': p.description,
                'price': p.price,
                'rawPrice': p.rawPrice,
                'currencyCode': p.currencyCode,
                'currencySymbol': p.currencySymbol,
              })
          .toList();

      return {
        'products': products,
        'count': products.length,
        'notFound': response.notFoundIDs.toList(),
        'error': response.error?.message,
      };
    } catch (e) {
      return {'products': <dynamic>[], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _buyProduct(
    Map<String, dynamic> args,
  ) async {
    final productId = args['productId'] as String;

    try {
      final response = await _iap.queryProductDetails({productId});

      if (response.productDetails.isEmpty) {
        return {'initiated': false, 'reason': 'product_not_found'};
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);

      final initiated = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return {'initiated': initiated, 'productId': productId};
    } catch (e) {
      return {'initiated': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _buySubscription(
    Map<String, dynamic> args,
  ) async {
    final productId = args['productId'] as String;

    try {
      final response = await _iap.queryProductDetails({productId});

      if (response.productDetails.isEmpty) {
        return {'initiated': false, 'reason': 'product_not_found'};
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);

      final initiated = await _iap.buyNonConsumable(
        purchaseParam: purchaseParam,
      );

      return {'initiated': initiated, 'productId': productId};
    } catch (e) {
      return {'initiated': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _restorePurchases() async {
    try {
      await _iap.restorePurchases();
      return {'restoring': true};
    } catch (e) {
      return {'restoring': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _completePurchase(
    Map<String, dynamic> args,
  ) async {
    return {'completed': true, 'note': 'Auto-completed via stream'};
  }

  Map<String, dynamic> _purchaseToMap(PurchaseDetails purchase) {
    return {
      'productId': purchase.productID,
      'purchaseId': purchase.purchaseID,
      'status': purchase.status.name,
      'transactionDate': purchase.transactionDate,
      'pendingComplete': purchase.pendingCompletePurchase,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'getProducts':
        final ids = args['productIds'];
        if (ids is! List || ids.isEmpty) {
          return ValidationResult.invalid('productIds (list) is required');
        }
        return ValidationResult.valid();
      case 'buyProduct':
      case 'buySubscription':
        if (args['productId'] is! String) {
          return ValidationResult.invalid('productId is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
