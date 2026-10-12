import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef UpdateEventEmitter = Future<void> Function(String event, dynamic data);

class AppUpdatePlugin extends Plugin {
  final UpdateEventEmitter? eventEmitter;

  PackageInfo? _packageInfo;
  Map<String, dynamic>? _lastCheckResult;

  /// URL برای بررسی نسخه جدید — باید از طرف سرور شما ست بشه
  String? _updateCheckUrl;

  /// آدرس Play Store
  String? _playStoreUrl;

  AppUpdatePlugin({this.eventEmitter});

  @override
  String get name => 'appUpdate';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'App version check and update plugin';

  @override
  List<String> get supportedMethods => [
        'configure',
        'getCurrentVersion',
        'checkForUpdate',
        'openStore',
        'getLastCheckResult',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      // PackageInfo is unavailable in unit tests / unsupported platforms.
      BridgeLogger.warn('AppUpdate', 'PackageInfo unavailable: $e');
      _packageInfo = null;
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'configure':
        return _configure(args);
      case 'getCurrentVersion':
        return _getCurrentVersion();
      case 'checkForUpdate':
        return _checkForUpdate(args);
      case 'openStore':
        return _openStore(args);
      case 'getLastCheckResult':
        return _lastCheckResult ?? {'checked': false};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'currentVersion': _packageInfo?.version,
          'buildNumber': _packageInfo?.buildNumber,
          'configured': _updateCheckUrl != null,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Map<String, dynamic> _configure(Map<String, dynamic> args) {
    _updateCheckUrl = args['updateCheckUrl'] as String?;
    _playStoreUrl = args['playStoreUrl'] as String?;

    BridgeLogger.info('AppUpdate', 'Configured: url=$_updateCheckUrl');

    return {
      'configured': true,
      'updateCheckUrl': _updateCheckUrl,
      'playStoreUrl': _playStoreUrl,
    };
  }

  Map<String, dynamic> _getCurrentVersion() {
    return {
      'version': _packageInfo?.version ?? 'unknown',
      'buildNumber': _packageInfo?.buildNumber ?? 'unknown',
      'packageName': _packageInfo?.packageName ?? 'unknown',
      'appName': _packageInfo?.appName ?? 'unknown',
    };
  }

  Future<Map<String, dynamic>> _checkForUpdate(
    Map<String, dynamic> args,
  ) async {
    final checkUrl = args['url'] as String? ?? _updateCheckUrl;

    if (checkUrl == null || checkUrl.isEmpty) {
      // بدون URL سرور — فقط اطلاعات نسخه فعلی
      _lastCheckResult = {
        'checked': true,
        'updateAvailable': false,
        'reason': 'no_update_url_configured',
        'currentVersion': _packageInfo?.version,
      };
      return _lastCheckResult!;
    }

    try {
      final response = await http.get(
        Uri.parse(checkUrl),
        headers: {
          'X-App-Version': _packageInfo?.version ?? '',
          'X-Build-Number': _packageInfo?.buildNumber ?? '',
          'X-Package-Name': _packageInfo?.packageName ?? '',
          'X-Platform': Platform.operatingSystem,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _lastCheckResult = {
          'checked': true,
          'updateAvailable': false,
          'error': 'Server returned ${response.statusCode}',
        };
        return _lastCheckResult!;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final latestVersion = data['latestVersion'] as String?;
      final minVersion = data['minVersion'] as String?;
      final storeUrl = data['storeUrl'] as String?;
      final releaseNotes = data['releaseNotes'] as String?;
      final forceUpdate = data['forceUpdate'] as bool? ?? false;

      if (storeUrl != null) _playStoreUrl = storeUrl;

      final currentVersion = _packageInfo?.version ?? '0.0.0';
      final updateAvailable = latestVersion != null &&
          _isNewerVersion(latestVersion, currentVersion);

      final mustUpdate =
          minVersion != null && _isNewerVersion(minVersion, currentVersion);

      _lastCheckResult = {
        'checked': true,
        'updateAvailable': updateAvailable,
        'mustUpdate': mustUpdate || forceUpdate,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'minVersion': minVersion,
        'releaseNotes': releaseNotes,
        'storeUrl': storeUrl ?? _playStoreUrl,
        'checkedAt': DateTime.now().toIso8601String(),
      };

      if (updateAvailable) {
        eventEmitter?.call('appUpdate.available', _lastCheckResult);
      }

      return _lastCheckResult!;
    } catch (e) {
      BridgeLogger.error('AppUpdate', 'Check failed: $e');

      _lastCheckResult = {
        'checked': true,
        'updateAvailable': false,
        'error': e.toString(),
      };

      return _lastCheckResult!;
    }
  }

  Future<Map<String, dynamic>> _openStore(Map<String, dynamic> args) async {
    final url = args['url'] as String? ?? _playStoreUrl;

    if (url == null || url.isEmpty) {
      // Default Play Store URL
      final packageName = _packageInfo?.packageName ?? '';
      final defaultUrl =
          'https://play.google.com/store/apps/details?id=$packageName';

      final launched = await launchUrl(
        Uri.parse(defaultUrl),
        mode: LaunchMode.externalApplication,
      );

      return {'opened': launched, 'url': defaultUrl};
    }

    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    return {'opened': launched, 'url': url};
  }

  bool _isNewerVersion(String newer, String current) {
    final nParts = newer.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final cParts = current.split('.').map((p) => int.tryParse(p) ?? 0).toList();

    for (var i = 0; i < 3; i++) {
      final n = i < nParts.length ? nParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (n > c) return true;
      if (n < c) return false;
    }

    return false;
  }
}
