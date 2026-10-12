import 'package:in_app_review/in_app_review.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class InAppReviewPlugin extends Plugin {
  final InAppReview _review = InAppReview.instance;

  @override
  String get name => 'inAppReview';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'In-app review and rating prompt';

  @override
  List<String> get supportedMethods => [
        'isAvailable',
        'requestReview',
        'openStoreListing',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isAvailable':
        return _isAvailable();
      case 'requestReview':
        return _requestReview();
      case 'openStoreListing':
        return _openStoreListing(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _isAvailable() async {
    try {
      final available = await _review.isAvailable();
      return {'available': available};
    } catch (e) {
      return {'available': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _requestReview() async {
    try {
      final available = await _review.isAvailable();
      if (!available) {
        return {'requested': false, 'reason': 'not_available'};
      }

      await _review.requestReview();
      BridgeLogger.info('InAppReview', 'Review dialog requested');

      return {'requested': true};
    } catch (e) {
      BridgeLogger.error('InAppReview', 'Request failed: $e');
      return {'requested': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _openStoreListing(
    Map<String, dynamic> args,
  ) async {
    final appStoreId = args['appStoreId'] as String?;

    try {
      await _review.openStoreListing(appStoreId: appStoreId);
      return {'opened': true};
    } catch (e) {
      return {'opened': false, 'error': e.toString()};
    }
  }
}
