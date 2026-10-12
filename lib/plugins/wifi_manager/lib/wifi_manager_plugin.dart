import 'dart:async';
import 'dart:io';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef WifiEventEmitter = Future<void> Function(String event, dynamic data);

class WifiManagerPlugin extends Plugin {
  final WifiEventEmitter? eventEmitter;

  WifiManagerPlugin({this.eventEmitter});

  @override
  String get name => 'wifiManager';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'WiFi network information and management';

  @override
  List<String> get supportedMethods => [
        'getConnectionInfo',
        'getIpAddress',
        'isEnabled',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getConnectionInfo':
        return _getConnectionInfo();
      case 'getIpAddress':
        return _getIpAddress();
      case 'isEnabled':
        return _isEnabled();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'platform': Platform.operatingSystem
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getConnectionInfo() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      String? wifiIp;
      String? wifiName;

      for (final interface in interfaces) {
        if (interface.name.toLowerCase().contains('wlan') ||
            interface.name.toLowerCase().contains('wifi') ||
            interface.name.toLowerCase().contains('en0')) {
          for (final addr in interface.addresses) {
            wifiIp = addr.address;
          }
          wifiName = interface.name;
          break;
        }
      }

      if (wifiIp == null) {
        for (final interface in interfaces) {
          for (final addr in interface.addresses) {
            if (!addr.isLoopback) {
              wifiIp = addr.address;
              wifiName = interface.name;
              break;
            }
          }
          if (wifiIp != null) break;
        }
      }

      return {
        'connected': wifiIp != null,
        'ip': wifiIp,
        'interfaceName': wifiName,
        'interfaces': interfaces
            .map((i) => {
                  'name': i.name,
                  'addresses': i.addresses.map((a) => a.address).toList(),
                })
            .toList(),
      };
    } catch (e) {
      BridgeLogger.error('WifiManager', 'Connection info failed: $e');
      return {'connected': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );

      final ips = <String>[];
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback) {
            ips.add(addr.address);
          }
        }
      }

      return {
        'ips': ips,
        'primary': ips.isNotEmpty ? ips.first : null,
      };
    } catch (e) {
      return {'ips': <String>[], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _isEnabled() async {
    final info = await _getConnectionInfo();
    return {'enabled': info['connected'] == true};
  }
}
