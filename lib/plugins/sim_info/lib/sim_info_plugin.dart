import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class SimInfoPlugin extends Plugin {
  static const _channel = MethodChannel('sweetmelon/sim_info');

  @override
  String get name => 'simInfo';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'SIM card information plugin';

  @override
  List<String> get requiredPermissions => ['phone'];

  @override
  List<String> get supportedMethods => [
        'getSimInfo',
        'getCarrierName',
        'getSimCount',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getSimInfo':
        return _getSimInfo();
      case 'getCarrierName':
        return _getCarrierName();
      case 'getSimCount':
        return _getSimCount();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'platform': Platform.operatingSystem,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getSimInfo() async {
    try {
      final result = await _channel.invokeMethod('getSimInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      BridgeLogger.warn('SimInfo', 'Native channel not available: $e');
    }

    return {
      'available': false,
      'reason': 'native_channel_required',
      'note': 'Add native implementation for full SIM info',
    };
  }

  Future<Map<String, dynamic>> _getCarrierName() async {
    try {
      final result = await _channel.invokeMethod('getCarrierName');
      return {'carrier': result ?? 'unknown'};
    } catch (_) {
      return {'carrier': 'unknown'};
    }
  }

  Future<Map<String, dynamic>> _getSimCount() async {
    try {
      final result = await _channel.invokeMethod('getSimCount');
      return {'count': result ?? 0};
    } catch (_) {
      return {'count': 0};
    }
  }
}
