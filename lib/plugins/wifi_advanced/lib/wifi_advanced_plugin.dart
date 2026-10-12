import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef WifiAdvEventEmitter = Future<void> Function(String event, dynamic data);

class WifiAdvancedPlugin extends Plugin {
  final WifiAdvEventEmitter? eventEmitter;
  static const _channel = MethodChannel('sweetmelon/wifi_advanced');

  WifiAdvancedPlugin({this.eventEmitter});

  @override
  String get name => 'wifiAdvanced';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Advanced WiFi: scan, connect, hotspot, direct';

  @override
  List<String> get supportedMethods => [
        'scan',
        'getConnectionInfo',
        'getIpConfig',
        'getSignalStrength',
        'getDhcpInfo',
        'getFrequency',
        'isWifiEnabled',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'scan':
        return _scan();
      case 'getConnectionInfo':
        return _getConnectionInfo();
      case 'getIpConfig':
        return _getIpConfig();
      case 'getSignalStrength':
        return _getSignalStrength();
      case 'getDhcpInfo':
        return _getDhcpInfo();
      case 'getFrequency':
        return _getFrequency();
      case 'isWifiEnabled':
        return _isWifiEnabled();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _scan() async {
    try {
      final result = await _channel.invokeMethod('scanWifi');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      BridgeLogger.warn('WifiAdvanced', 'Native scan not available: $e');
    }

    // Fallback: network interface info
    return _getConnectionInfo();
  }

  Future<Map<String, dynamic>> _getConnectionInfo() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? wifiIp;
      String? interfaceName;
      final allInterfaces = <Map<String, dynamic>>[];

      for (final iface in interfaces) {
        final ifaceInfo = <String, dynamic>{
          'name': iface.name,
          'addresses': iface.addresses.map((a) => a.address).toList(),
        };

        allInterfaces.add(ifaceInfo);

        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final name = iface.name.toLowerCase();
          if (name.contains('wlan') ||
              name.contains('wifi') ||
              name.contains('en0')) {
            wifiIp = addr.address;
            interfaceName = iface.name;
          }
        }
      }

      // Subnet calculation
      String? subnet;
      if (wifiIp != null) {
        final parts = wifiIp.split('.');
        if (parts.length == 4) {
          subnet = '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
        }
      }

      return {
        'connected': wifiIp != null,
        'ip': wifiIp,
        'interfaceName': interfaceName,
        'subnet': subnet,
        'interfaces': allInterfaces,
      };
    } catch (e) {
      return {'connected': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getIpConfig() async {
    try {
      final result = await Process.run('ip', ['addr', 'show']);
      final output = result.stdout.toString();

      // Parse wlan interface
      final wlanMatch = RegExp(
        r'inet (\d+\.\d+\.\d+\.\d+)/(\d+).*?(?:wlan|wifi|en0)',
        dotAll: true,
      ).firstMatch(output);

      String? ip;
      String? cidr;
      String? broadcast;

      if (wlanMatch != null) {
        ip = wlanMatch.group(1);
        cidr = wlanMatch.group(2);
      }

      // Gateway
      final routeResult = await Process.run('ip', ['route', 'show', 'default']);
      final routeOutput = routeResult.stdout.toString();
      final gatewayMatch = RegExp(r'default via (\S+)').firstMatch(routeOutput);

      // DNS
      String? dns;
      try {
        final resolvConf = await File('/etc/resolv.conf').readAsString();
        final dnsMatch = RegExp(r'nameserver (\S+)').firstMatch(resolvConf);
        dns = dnsMatch?.group(1);
      } catch (_) {}

      return {
        'ip': ip,
        'cidr': cidr,
        'gateway': gatewayMatch?.group(1),
        'dns': dns,
        'broadcast': broadcast,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getSignalStrength() async {
    try {
      final result = await Process.run('cat', ['/proc/net/wireless']);
      final output = result.stdout.toString();

      final match = RegExp(r'wlan\d?\s+\d+\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)')
          .firstMatch(output);

      if (match != null) {
        final level = double.tryParse(match.group(2) ?? '') ?? 0;
        return {
          'level': level,
          'quality': _signalQuality(level),
          'unit': 'dBm',
        };
      }

      return {'level': null, 'quality': 'unknown'};
    } catch (e) {
      return {'level': null, 'error': e.toString()};
    }
  }

  String _signalQuality(double dbm) {
    if (dbm >= -50) return 'excellent';
    if (dbm >= -60) return 'good';
    if (dbm >= -70) return 'fair';
    if (dbm >= -80) return 'weak';
    return 'very_weak';
  }

  Future<Map<String, dynamic>> _getDhcpInfo() async {
    try {
      final result = await _channel.invokeMethod('getDhcpInfo');
      if (result != null) {
        return Map<String, dynamic>.from(result);
      }
    } catch (_) {}

    // Fallback
    return _getIpConfig();
  }

  Future<Map<String, dynamic>> _getFrequency() async {
    try {
      final result = await _channel.invokeMethod('getFrequency');
      if (result != null) {
        final freq = result as int;
        return {
          'frequency': freq,
          'band': freq > 5000 ? '5GHz' : '2.4GHz',
          'unit': 'MHz',
        };
      }
    } catch (_) {}

    return {'frequency': null, 'band': 'unknown'};
  }

  Future<Map<String, dynamic>> _isWifiEnabled() async {
    final info = await _getConnectionInfo();
    return {'enabled': info['connected'] == true};
  }
}
