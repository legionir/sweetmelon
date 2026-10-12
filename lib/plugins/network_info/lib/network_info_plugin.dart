import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class NetworkInfoPlugin extends Plugin {
  @override
  String get name => 'networkInfo';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Network interfaces, IPs, and diagnostics';

  @override
  List<String> get supportedMethods => [
        'getInterfaces',
        'getIpAddresses',
        'getLocalIp',
        'getExternalIp',
        'getGateway',
        'isPortOpen',
        'getHostname',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getInterfaces':
        return _getInterfaces();
      case 'getIpAddresses':
        return _getIpAddresses();
      case 'getLocalIp':
        return _getLocalIp();
      case 'getExternalIp':
        return _getExternalIp();
      case 'getGateway':
        return _getGateway();
      case 'isPortOpen':
        return _isPortOpen(args);
      case 'getHostname':
        return _getHostname();
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _getInterfaces() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );

      final result = interfaces.map((iface) {
        return {
          'name': iface.name,
          'index': iface.index,
          'addresses': iface.addresses.map((addr) {
            return {
              'address': addr.address,
              'type': addr.type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6',
              'isLoopback': addr.isLoopback,
              'isLinkLocal': addr.isLinkLocal,
              'isMulticast': addr.isMulticast,
              'host': addr.host,
            };
          }).toList(),
        };
      }).toList();

      return {'interfaces': result, 'count': result.length};
    } catch (e) {
      return {'interfaces': <dynamic>[], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      final ipv4 = <String>[];
      final ipv6 = <String>[];

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            ipv4.add(addr.address);
          }
        }
      }

      // Also get IPv6
      final v6Interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv6,
        includeLoopback: false,
      );

      for (final iface in v6Interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.isLinkLocal) {
            ipv6.add(addr.address);
          }
        }
      }

      return {
        'ipv4': ipv4,
        'ipv6': ipv6,
        'primary': ipv4.isNotEmpty ? ipv4.first : null,
      };
    } catch (e) {
      return {'ipv4': <String>[], 'ipv6': <String>[], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );

      String? wifiIp;
      String? mobileIp;
      String? anyIp;

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;

          final name = iface.name.toLowerCase();

          if (name.contains('wlan') ||
              name.contains('wifi') ||
              name.contains('en0')) {
            wifiIp = addr.address;
          } else if (name.contains('rmnet') ||
              name.contains('pdp') ||
              name.contains('cellular')) {
            mobileIp = addr.address;
          }

          anyIp ??= addr.address;
        }
      }

      return {
        'ip': wifiIp ?? mobileIp ?? anyIp,
        'wifiIp': wifiIp,
        'mobileIp': mobileIp,
        'type':
            wifiIp != null ? 'wifi' : (mobileIp != null ? 'mobile' : 'other'),
      };
    } catch (e) {
      return {'ip': null, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _getExternalIp() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(
        Uri.parse('https://api.ipify.org?format=json'),
      );
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();

      final data = jsonDecode(body) as Map<String, dynamic>;

      return {
        'externalIp': data['ip'],
        'source': 'ipify.org',
      };
    } catch (e) {
      // Fallback
      try {
        final client = HttpClient();
        final request = await client.getUrl(
          Uri.parse('https://ifconfig.me/ip'),
        );
        final response = await request.close();
        final ip = await response.transform(utf8.decoder).join();
        client.close();

        return {
          'externalIp': ip.trim(),
          'source': 'ifconfig.me',
        };
      } catch (_) {
        return {'externalIp': null, 'error': e.toString()};
      }
    }
  }

  Future<Map<String, dynamic>> _getGateway() async {
    try {
      // Android: از routing table gateway رو بخون
      final result = await Process.run('ip', ['route', 'show', 'default']);
      final output = result.stdout.toString().trim();

      // default via 192.168.1.1 dev wlan0
      final match = RegExp(r'default via (\S+)').firstMatch(output);

      if (match != null) {
        return {
          'gateway': match.group(1),
          'available': true,
        };
      }

      return {'gateway': null, 'available': false};
    } catch (e) {
      return {'gateway': null, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _isPortOpen(Map<String, dynamic> args) async {
    final host = args['host'] as String;
    final port = (args['port'] as num).toInt();
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 3000;

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      await socket.close();

      return {'host': host, 'port': port, 'open': true};
    } catch (e) {
      return {'host': host, 'port': port, 'open': false};
    }
  }

  Future<Map<String, dynamic>> _getHostname() async {
    try {
      return {'hostname': Platform.localHostname};
    } catch (e) {
      return {'hostname': null, 'error': e.toString()};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    if (method == 'isPortOpen') {
      if (args['host'] is! String) {
        return ValidationResult.invalid('host is required');
      }
      if (args['port'] is! num) {
        return ValidationResult.invalid('port is required');
      }
    }
    return ValidationResult.valid();
  }
}
