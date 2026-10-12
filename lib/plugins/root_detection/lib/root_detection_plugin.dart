import 'dart:io';

import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class RootDetectionPlugin extends Plugin {
  @override
  String get name => 'rootDetection';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Detect rooted/jailbroken devices';

  @override
  List<String> get supportedMethods => [
        'isRooted',
        'getSecurityInfo',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isRooted':
        return _isRooted();
      case 'getSecurityInfo':
        return _getSecurityInfo();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _isRooted() async {
    final checks = <String, bool>{};
    bool isRooted = false;

    if (Platform.isAndroid) {
      // Check 1: su binary
      checks['suBinary'] = _checkSuBinary();
      // Check 2: root management apps
      checks['rootApps'] = _checkRootApps();
      // Check 3: dangerous props
      checks['dangerousProps'] = _checkDangerousProps();
      // Check 4: rw system partition
      checks['rwSystem'] = _checkRWSystem();
      // Check 5: test keys
      checks['testKeys'] = _checkTestKeys();
      // Check 6: busybox
      checks['busybox'] = _checkBusybox();
      // Check 7: Magisk
      checks['magisk'] = _checkMagisk();

      isRooted = checks.values.any((v) => v);
    }

    return {
      'isRooted': isRooted,
      'platform': Platform.operatingSystem,
      'checks': checks,
      'riskLevel': _calculateRiskLevel(checks),
    };
  }

  Future<Map<String, dynamic>> _getSecurityInfo() async {
    final rootInfo = await _isRooted();

    return {
      ...rootInfo,
      'isEmulator': _isEmulator(),
      'isDebugMode': _isDebugMode(),
      'adbEnabled': _checkAdb(),
    };
  }

  bool _checkSuBinary() {
    final paths = [
      '/system/bin/su',
      '/system/xbin/su',
      '/sbin/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/failsafe/su',
      '/data/local/su',
      '/su/bin/su',
    ];

    for (final path in paths) {
      if (File(path).existsSync()) return true;
    }
    return false;
  }

  bool _checkRootApps() {
    final packages = [
      '/system/app/Superuser.apk',
      '/system/app/SuperSU.apk',
      '/system/app/Superuser',
      '/system/app/SuperSU',
    ];

    for (final pkg in packages) {
      if (File(pkg).existsSync() || Directory(pkg).existsSync()) return true;
    }
    return false;
  }

  bool _checkDangerousProps() {
    try {
      final result = Process.runSync('getprop', ['ro.debuggable']);
      if (result.stdout.toString().trim() == '1') return true;
    } catch (_) {}
    return false;
  }

  bool _checkRWSystem() {
    try {
      final result = Process.runSync('mount', []);
      final output = result.stdout.toString();
      if (output.contains('/system') && output.contains('rw,')) return true;
    } catch (_) {}
    return false;
  }

  bool _checkTestKeys() {
    try {
      final result = Process.runSync('getprop', ['ro.build.tags']);
      if (result.stdout.toString().trim() == 'test-keys') return true;
    } catch (_) {}
    return false;
  }

  bool _checkBusybox() {
    final paths = [
      '/system/xbin/busybox',
      '/system/bin/busybox',
      '/sbin/busybox'
    ];
    for (final path in paths) {
      if (File(path).existsSync()) return true;
    }
    return false;
  }

  bool _checkMagisk() {
    final paths = ['/sbin/.magisk', '/data/adb/magisk'];
    for (final path in paths) {
      if (File(path).existsSync() || Directory(path).existsSync()) return true;
    }
    return false;
  }

  bool _isEmulator() {
    try {
      final brand = Process.runSync('getprop', ['ro.product.brand'])
          .stdout
          .toString()
          .trim();
      final device = Process.runSync('getprop', ['ro.product.device'])
          .stdout
          .toString()
          .trim();
      final model = Process.runSync('getprop', ['ro.product.model'])
          .stdout
          .toString()
          .trim();
      final hardware =
          Process.runSync('getprop', ['ro.hardware']).stdout.toString().trim();

      final emulatorIndicators = [
        'generic',
        'emulator',
        'sdk',
        'goldfish',
        'ranchu'
      ];
      final combined = '$brand $device $model $hardware'.toLowerCase();

      return emulatorIndicators.any((e) => combined.contains(e));
    } catch (_) {
      return false;
    }
  }

  bool _isDebugMode() {
    bool debug = false;
    assert(() {
      debug = true;
      return true;
    }());
    return debug;
  }

  bool _checkAdb() {
    try {
      final result = Process.runSync('getprop', ['init.svc.adbd']);
      return result.stdout.toString().trim() == 'running';
    } catch (_) {
      return false;
    }
  }

  String _calculateRiskLevel(Map<String, bool> checks) {
    final positiveCount = checks.values.where((v) => v).length;
    if (positiveCount == 0) return 'safe';
    if (positiveCount <= 2) return 'low';
    if (positiveCount <= 4) return 'medium';
    return 'high';
  }
}
