import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';
import 'package:url_launcher/url_launcher.dart';

typedef IntentEventEmitter = Future<void> Function(
  String event,
  dynamic data,
);

class IntentLinkPlugin extends Plugin {
  final IntentEventEmitter? eventEmitter;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  String? _latestLink;

  IntentLinkPlugin({
    this.eventEmitter,
  });

  @override
  String get name => 'intent';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Intent launcher and deep link plugin';

  @override
  List<String> get supportedMethods => [
        'openUrl',
        'canOpenUrl',
        'getInitialLink',
        'getLatestLink',
        'startListening',
        'stopListening',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _latestLink = initial.toString();
      }
    } catch (e) {
      BridgeLogger.warn('Intent', 'Failed to read initial link: $e');
    }
  }

  @override
  Future<void> onDispose() async {
    await _linkSub?.cancel();
    _linkSub = null;
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'openUrl':
        return _openUrl(args);
      case 'canOpenUrl':
        return _canOpenUrl(args);
      case 'getInitialLink':
        return _getInitialLink();
      case 'getLatestLink':
        return {'url': _latestLink};
      case 'startListening':
        return _startListening();
      case 'stopListening':
        return _stopListening();
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _openUrl(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final uri = Uri.parse(url);

    final modeName = args['mode'] as String? ?? 'external';
    final mode = _parseLaunchMode(modeName);

    final opened = await launchUrl(uri, mode: mode);

    return {
      'opened': opened,
      'url': uri.toString(),
      'mode': modeName,
    };
  }

  Future<Map<String, dynamic>> _canOpenUrl(Map<String, dynamic> args) async {
    final url = args['url'] as String;
    final uri = Uri.parse(url);

    final canOpen = await canLaunchUrl(uri);
    return {
      'canOpen': canOpen,
      'url': uri.toString(),
    };
  }

  Future<Map<String, dynamic>> _getInitialLink() async {
    final uri = await _appLinks.getInitialLink();
    final value = uri?.toString();
    if (value != null) {
      _latestLink = value;
    }

    return {'url': value};
  }

  Future<Map<String, dynamic>> _startListening() async {
    if (_linkSub != null) {
      return {
        'listening': true,
        'alreadyListening': true,
      };
    }

    _linkSub = _appLinks.uriLinkStream.listen(
      (uri) async {
        _latestLink = uri.toString();

        BridgeLogger.info('Intent', 'Deep link received: $_latestLink');

        if (eventEmitter != null) {
          await eventEmitter!(
            'intent.deepLink',
            {
              'url': _latestLink,
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      },
      onError: (error) async {
        BridgeLogger.error('Intent', 'Deep link stream error: $error');
        if (eventEmitter != null) {
          await eventEmitter!(
            'intent.error',
            {
              'message': error.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      },
    );

    return {
      'listening': true,
      'alreadyListening': false,
    };
  }

  Future<Map<String, dynamic>> _stopListening() async {
    await _linkSub?.cancel();
    _linkSub = null;
    return {'listening': false};
  }

  LaunchMode _parseLaunchMode(String mode) {
    switch (mode) {
      case 'platform':
        return LaunchMode.platformDefault;
      case 'inApp':
        return LaunchMode.inAppWebView;
      case 'externalNonBrowser':
        return LaunchMode.externalNonBrowserApplication;
      case 'external':
      default:
        return LaunchMode.externalApplication;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'openUrl':
      case 'canOpenUrl':
        final url = args['url'];
        if (url is! String || url.isEmpty) {
          return ValidationResult.invalid(
            'url is required and must be a non-empty string',
          );
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
