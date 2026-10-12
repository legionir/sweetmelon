import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef UpdateEventEmitter = Future<void> Function(String event, dynamic data);

/// وضعیت‌های مختلف bundle
enum BundleStatus {
  idle,
  checking,
  downloading,
  extracting,
  ready,
  applying,
  applied,
  rollingBack,
  error,
}

/// اطلاعات یک bundle
class BundleInfo {
  final String version;
  final String? url;
  final String? checksum;
  final int? size;
  final DateTime? createdAt;
  final Map<String, dynamic> metadata;

  const BundleInfo({
    required this.version,
    this.url,
    this.checksum,
    this.size,
    this.createdAt,
    this.metadata = const {},
  });

  factory BundleInfo.fromJson(Map<String, dynamic> json) {
    return BundleInfo(
      version: json['version'] as String,
      url: json['url'] as String?,
      checksum: json['checksum'] as String?,
      size: json['size'] as int?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        if (url != null) 'url': url,
        if (checksum != null) 'checksum': checksum,
        if (size != null) 'size': size,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        'metadata': metadata,
      };
}

class LiveUpdaterPlugin extends Plugin {
  final UpdateEventEmitter? eventEmitter;

  String? _serverUrl;
  String? _apiKey;
  String? _channel;
  String _currentVersion = '0.0.0';
  BundleStatus _status = BundleStatus.idle;
  BundleInfo? _availableUpdate;
  BundleInfo? _appliedBundle;
  String? _lastError;

  SharedPreferences? _prefs;

  static const _prefKeyCurrentVersion = 'live_updater_version';
  static const _prefKeyAppliedBundle = 'live_updater_applied';
  static const _prefKeyPreviousBundle = 'live_updater_previous';
  static const _prefKeyFailCount = 'live_updater_fail_count';
  static const _maxFailCount = 3;

  LiveUpdaterPlugin({this.eventEmitter});

  @override
  String get name => 'liveUpdater';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Live update plugin for www assets';

  @override
  List<String> get supportedMethods => [
        'configure',
        'checkForUpdate',
        'downloadUpdate',
        'applyUpdate',
        'checkAndApply',
        'rollback',
        'getCurrentVersion',
        'getAvailableUpdate',
        'getStatus',
        'getUpdateHistory',
        'reset',
        'setChannel',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _prefs = await SharedPreferences.getInstance();
    _currentVersion = _prefs?.getString(_prefKeyCurrentVersion) ?? '0.0.0';

    final appliedJson = _prefs?.getString(_prefKeyAppliedBundle);
    if (appliedJson != null) {
      try {
        _appliedBundle = BundleInfo.fromJson(
          jsonDecode(appliedJson) as Map<String, dynamic>,
        );
      } catch (_) {}
    }

    // Auto-rollback check
    await _checkAutoRollback();

    BridgeLogger.info(
      'LiveUpdater',
      'Initialized (version: $_currentVersion)',
    );
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'configure':
        return _configure(args);
      case 'checkForUpdate':
        return _checkForUpdate();
      case 'downloadUpdate':
        return _downloadUpdate();
      case 'applyUpdate':
        return _applyUpdate();
      case 'checkAndApply':
        return _checkAndApply(args);
      case 'rollback':
        return _rollback();
      case 'getCurrentVersion':
        return _getCurrentVersion();
      case 'getAvailableUpdate':
        return _getAvailableUpdate();
      case 'getStatus':
        return _getStatus();
      case 'getUpdateHistory':
        return _getUpdateHistory();
      case 'reset':
        return _reset();
      case 'setChannel':
        return _setChannel(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'currentVersion': _currentVersion,
          'status': _status.name,
          'configured': _serverUrl != null,
          'channel': _channel,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  // ── Configure ──

  Map<String, dynamic> _configure(Map<String, dynamic> args) {
    _serverUrl = args['serverUrl'] as String;
    _apiKey = args['apiKey'] as String?;
    _channel = args['channel'] as String? ?? 'production';
    _currentVersion = args['currentVersion'] as String? ?? _currentVersion;

    BridgeLogger.info(
      'LiveUpdater',
      'Configured: server=$_serverUrl, channel=$_channel',
    );

    return {
      'configured': true,
      'serverUrl': _serverUrl,
      'channel': _channel,
      'currentVersion': _currentVersion,
    };
  }

  // ── Check for Update ──

  Future<Map<String, dynamic>> _checkForUpdate() async {
    _requireConfig();
    _setStatus(BundleStatus.checking);

    try {
      final response = await http
          .get(
            Uri.parse('$_serverUrl/api/updates/check'),
            headers: _buildHeaders({
              'X-Current-Version': _currentVersion,
              'X-Channel': _channel ?? 'production',
              'X-Platform': Platform.operatingSystem,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _setStatus(BundleStatus.idle);
        return {
          'available': false,
          'reason': 'server_error',
          'statusCode': response.statusCode,
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final updateAvailable = data['updateAvailable'] as bool? ?? false;

      if (!updateAvailable) {
        _setStatus(BundleStatus.idle);
        _availableUpdate = null;
        return {
          'available': false,
          'currentVersion': _currentVersion,
          'latestVersion': data['latestVersion'],
        };
      }

      _availableUpdate =
          BundleInfo.fromJson(data['bundle'] as Map<String, dynamic>);
      _setStatus(BundleStatus.idle);

      _emitEvent('update.available', {
        'version': _availableUpdate!.version,
        'size': _availableUpdate!.size,
        'currentVersion': _currentVersion,
      });

      return {
        'available': true,
        'currentVersion': _currentVersion,
        'newVersion': _availableUpdate!.version,
        'size': _availableUpdate!.size,
        'metadata': _availableUpdate!.metadata,
      };
    } catch (e) {
      _setStatus(BundleStatus.error, error: e.toString());
      return {'available': false, 'error': e.toString()};
    }
  }

  // ── Download Update ──

  Future<Map<String, dynamic>> _downloadUpdate() async {
    if (_availableUpdate == null) {
      return {'downloaded': false, 'reason': 'no_update_available'};
    }

    final bundle = _availableUpdate!;
    if (bundle.url == null) {
      return {'downloaded': false, 'reason': 'no_download_url'};
    }

    _setStatus(BundleStatus.downloading);

    try {
      final tempDir = await getTemporaryDirectory();
      final bundleDir = Directory(
        p.join(tempDir.path, 'live_updates', bundle.version),
      );
      await bundleDir.create(recursive: true);

      final zipPath = p.join(bundleDir.path, 'bundle.zip');

      // Download with progress
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(bundle.url!));
      request.headers.addAll(_buildHeaders());

      final response = await client.send(request);
      final totalBytes = response.contentLength ?? -1;
      var receivedBytes = 0;

      final sink = File(zipPath).openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        final percent =
            totalBytes > 0 ? ((receivedBytes / totalBytes) * 100).round() : -1;

        _emitEvent('update.downloadProgress', {
          'version': bundle.version,
          'receivedBytes': receivedBytes,
          'totalBytes': totalBytes,
          'percent': percent,
        });
      }

      await sink.flush();
      await sink.close();
      client.close();

      // Verify checksum
      if (bundle.checksum != null) {
        final fileBytes = await File(zipPath).readAsBytes();
        final hash = sha256.convert(fileBytes).toString();

        if (hash != bundle.checksum) {
          _setStatus(BundleStatus.error, error: 'Checksum mismatch');
          await bundleDir.delete(recursive: true);

          return {
            'downloaded': false,
            'reason': 'checksum_mismatch',
            'expected': bundle.checksum,
            'actual': hash,
          };
        }

        BridgeLogger.info('LiveUpdater', 'Checksum verified');
      }

      // Extract
      _setStatus(BundleStatus.extracting);

      final extractDir = p.join(bundleDir.path, 'www');
      await _extractBundle(zipPath, extractDir);

      // Verify extracted files
      final indexFile = File(p.join(extractDir, 'index.html'));
      if (!await indexFile.exists()) {
        _setStatus(BundleStatus.error, error: 'Missing index.html');
        await bundleDir.delete(recursive: true);
        return {
          'downloaded': false,
          'reason': 'invalid_bundle',
          'message': 'Bundle must contain index.html',
        };
      }

      _setStatus(BundleStatus.ready);

      _emitEvent('update.downloaded', {
        'version': bundle.version,
        'size': receivedBytes,
        'path': extractDir,
      });

      return {
        'downloaded': true,
        'version': bundle.version,
        'size': receivedBytes,
        'path': extractDir,
      };
    } catch (e) {
      _setStatus(BundleStatus.error, error: e.toString());
      return {'downloaded': false, 'error': e.toString()};
    }
  }

  // ── Apply Update ──

  Future<Map<String, dynamic>> _applyUpdate() async {
    if (_status != BundleStatus.ready || _availableUpdate == null) {
      return {'applied': false, 'reason': 'no_update_ready'};
    }

    _setStatus(BundleStatus.applying);

    try {
      final tempDir = await getTemporaryDirectory();
      final bundleDir = Directory(
        p.join(
          tempDir.path,
          'live_updates',
          _availableUpdate!.version,
          'www',
        ),
      );

      if (!await bundleDir.exists()) {
        _setStatus(BundleStatus.error, error: 'Bundle directory not found');
        return {'applied': false, 'reason': 'bundle_not_found'};
      }

      // Save previous version for rollback
      await _prefs?.setString(
        _prefKeyPreviousBundle,
        _prefs?.getString(_prefKeyAppliedBundle) ?? '',
      );

      // Copy to active www directory
      final appDir = await getApplicationDocumentsDirectory();
      final activeWww = Directory(p.join(appDir.path, 'active_www'));

      // Backup current active
      final backupDir = Directory(p.join(appDir.path, 'backup_www'));
      if (await activeWww.exists()) {
        if (await backupDir.exists()) {
          await backupDir.delete(recursive: true);
        }
        await activeWww.rename(backupDir.path);
      }

      // Copy new bundle to active
      await _copyDirectory(bundleDir, activeWww);

      // Save state
      final previousVersion = _currentVersion;
      _currentVersion = _availableUpdate!.version;
      _appliedBundle = _availableUpdate;

      await _prefs?.setString(_prefKeyCurrentVersion, _currentVersion);
      await _prefs?.setString(
        _prefKeyAppliedBundle,
        jsonEncode(_appliedBundle!.toJson()),
      );
      await _prefs?.setInt(_prefKeyFailCount, 0);

      _setStatus(BundleStatus.applied);
      _availableUpdate = null;

      BridgeLogger.info(
        'LiveUpdater',
        'Update applied: $previousVersion → $_currentVersion',
      );

      _emitEvent('update.applied', {
        'previousVersion': previousVersion,
        'newVersion': _currentVersion,
        'requiresReload': true,
      });

      return {
        'applied': true,
        'previousVersion': previousVersion,
        'newVersion': _currentVersion,
        'requiresReload': true,
        'message': 'Reload WebView to use new version',
      };
    } catch (e) {
      _setStatus(BundleStatus.error, error: e.toString());
      BridgeLogger.error('LiveUpdater', 'Apply failed: $e');

      // Auto rollback on error
      await _rollback();

      return {'applied': false, 'error': e.toString()};
    }
  }

  // ── Check and Apply (one-step) ──

  Future<Map<String, dynamic>> _checkAndApply(
    Map<String, dynamic> args,
  ) async {
    // Check
    final checkResult = await _checkForUpdate();
    if (checkResult['available'] != true) {
      return {
        'updated': false,
        'reason': 'no_update',
        'currentVersion': _currentVersion,
      };
    }

    // Download
    final downloadResult = await _downloadUpdate();
    if (downloadResult['downloaded'] != true) {
      return {
        'updated': false,
        'reason': 'download_failed',
        'error': downloadResult['error'],
      };
    }

    // Apply
    final applyResult = await _applyUpdate();
    if (applyResult['applied'] != true) {
      return {
        'updated': false,
        'reason': 'apply_failed',
        'error': applyResult['error'],
      };
    }

    return {
      'updated': true,
      'previousVersion': applyResult['previousVersion'],
      'newVersion': applyResult['newVersion'],
      'requiresReload': true,
    };
  }

  // ── Rollback ──

  Future<Map<String, dynamic>> _rollback() async {
    _setStatus(BundleStatus.rollingBack);

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final activeWww = Directory(p.join(appDir.path, 'active_www'));
      final backupDir = Directory(p.join(appDir.path, 'backup_www'));

      if (!await backupDir.exists()) {
        _setStatus(BundleStatus.idle);
        return {'rolledBack': false, 'reason': 'no_backup'};
      }

      // Restore backup
      if (await activeWww.exists()) {
        await activeWww.delete(recursive: true);
      }
      await backupDir.rename(activeWww.path);

      // Restore previous version
      final previousJson = _prefs?.getString(_prefKeyPreviousBundle) ?? '';
      if (previousJson.isNotEmpty) {
        try {
          final previousBundle = BundleInfo.fromJson(
            jsonDecode(previousJson) as Map<String, dynamic>,
          );
          _currentVersion = previousBundle.version;
          _appliedBundle = previousBundle;
        } catch (_) {
          _currentVersion = '0.0.0';
          _appliedBundle = null;
        }
      } else {
        _currentVersion = '0.0.0';
        _appliedBundle = null;
      }

      await _prefs?.setString(_prefKeyCurrentVersion, _currentVersion);

      _setStatus(BundleStatus.idle);

      BridgeLogger.info(
        'LiveUpdater',
        'Rolled back to version: $_currentVersion',
      );

      _emitEvent('update.rolledBack', {
        'version': _currentVersion,
        'requiresReload': true,
      });

      return {
        'rolledBack': true,
        'version': _currentVersion,
        'requiresReload': true,
      };
    } catch (e) {
      _setStatus(BundleStatus.error, error: e.toString());
      return {'rolledBack': false, 'error': e.toString()};
    }
  }

  // ── Auto Rollback ──

  Future<void> _checkAutoRollback() async {
    final failCount = _prefs?.getInt(_prefKeyFailCount) ?? 0;

    if (failCount >= _maxFailCount && _appliedBundle != null) {
      BridgeLogger.warn(
        'LiveUpdater',
        'Too many failures ($failCount), auto-rolling back',
      );

      await _rollback();

      _emitEvent('update.autoRolledBack', {
        'reason': 'too_many_failures',
        'failCount': failCount,
      });
    }
  }

  /// وقتی WebView بار خطا بخوره این صدا زده بشه
  Future<void> reportLoadFailure() async {
    final current = _prefs?.getInt(_prefKeyFailCount) ?? 0;
    await _prefs?.setInt(_prefKeyFailCount, current + 1);

    BridgeLogger.warn(
      'LiveUpdater',
      'Load failure reported (count: ${current + 1})',
    );
  }

  /// وقتی WebView موفق لود بشه
  Future<void> reportLoadSuccess() async {
    await _prefs?.setInt(_prefKeyFailCount, 0);
  }

  // ── Getters ──

  Map<String, dynamic> _getCurrentVersion() {
    return {
      'version': _currentVersion,
      'hasUpdate': _appliedBundle != null,
      'isBuiltIn': _appliedBundle == null,
    };
  }

  Map<String, dynamic> _getAvailableUpdate() {
    if (_availableUpdate == null) {
      return {'available': false};
    }
    return {
      'available': true,
      ..._availableUpdate!.toJson(),
    };
  }

  Map<String, dynamic> _getStatus() {
    return {
      'status': _status.name,
      'currentVersion': _currentVersion,
      'hasAppliedBundle': _appliedBundle != null,
      'hasAvailableUpdate': _availableUpdate != null,
      'lastError': _lastError,
      'channel': _channel,
    };
  }

  Map<String, dynamic> _getUpdateHistory() {
    return {
      'currentVersion': _currentVersion,
      'appliedBundle': _appliedBundle?.toJson(),
      'failCount': _prefs?.getInt(_prefKeyFailCount) ?? 0,
    };
  }

  // ── Reset ──

  Future<Map<String, dynamic>> _reset() async {
    final appDir = await getApplicationDocumentsDirectory();
    final activeWww = Directory(p.join(appDir.path, 'active_www'));
    final backupDir = Directory(p.join(appDir.path, 'backup_www'));

    if (await activeWww.exists()) await activeWww.delete(recursive: true);
    if (await backupDir.exists()) await backupDir.delete(recursive: true);

    // Clean temp
    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory(p.join(tempDir.path, 'live_updates'));
    if (await updatesDir.exists()) await updatesDir.delete(recursive: true);

    // Reset prefs
    await _prefs?.remove(_prefKeyCurrentVersion);
    await _prefs?.remove(_prefKeyAppliedBundle);
    await _prefs?.remove(_prefKeyPreviousBundle);
    await _prefs?.remove(_prefKeyFailCount);

    _currentVersion = '0.0.0';
    _appliedBundle = null;
    _availableUpdate = null;
    _setStatus(BundleStatus.idle);

    BridgeLogger.info('LiveUpdater', 'Reset to factory defaults');

    return {'reset': true, 'message': 'Reload app to use built-in assets'};
  }

  Map<String, dynamic> _setChannel(Map<String, dynamic> args) {
    _channel = args['channel'] as String;
    return {'channel': _channel};
  }

  // ── Helpers ──

  void _requireConfig() {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      throw const PluginException(
        code: PluginErrorCode.invalidArgs,
        message: 'Live updater not configured. Call configure() first.',
      );
    }
  }

  Map<String, String> _buildHeaders([Map<String, String>? extra]) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (_apiKey != null) 'Authorization': 'Bearer $_apiKey',
      'X-Plugin-Version': version,
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  void _setStatus(BundleStatus status, {String? error}) {
    _status = status;
    _lastError = error;
  }

  void _emitEvent(String event, dynamic data) {
    eventEmitter?.call(event, data);
  }

  Future<void> _extractBundle(String zipPath, String targetDir) async {
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final targetDirectory = Directory(targetDir);
    await targetDirectory.create(recursive: true);

    for (final file in archive) {
      final filePath = p.join(targetDir, file.name);

      // Path traversal protection
      if (!p.normalize(filePath).startsWith(p.normalize(targetDir))) {
        BridgeLogger.warn('LiveUpdater', 'Skipping unsafe path: ${file.name}');
        continue;
      }

      if (file.isFile) {
        final outFile = File(filePath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);

    await for (final entity in source.list(recursive: false)) {
      final targetPath = p.join(
        target.path,
        p.basename(entity.path),
      );

      if (entity is Directory) {
        await _copyDirectory(entity, Directory(targetPath));
      } else if (entity is File) {
        await entity.copy(targetPath);
      }
    }
  }

  /// مسیر active www — استفاده در WebViewHost
  static Future<String?> getActiveWwwPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final activeWww = Directory(p.join(appDir.path, 'active_www'));
    if (await activeWww.exists()) {
      final index = File(p.join(activeWww.path, 'index.html'));
      if (await index.exists()) {
        return activeWww.path;
      }
    }
    return null;
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'configure':
        if (args['serverUrl'] is! String ||
            (args['serverUrl'] as String).isEmpty) {
          return ValidationResult.invalid('serverUrl is required');
        }
        return ValidationResult.valid();
      case 'setChannel':
        if (args['channel'] is! String) {
          return ValidationResult.invalid('channel is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
