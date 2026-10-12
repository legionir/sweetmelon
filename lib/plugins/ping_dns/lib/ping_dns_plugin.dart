import 'dart:async';
import 'dart:io';

import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

class PingDnsPlugin extends Plugin {
  @override
  String get name => 'pingDns';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Ping hosts and DNS lookup';

  @override
  List<String> get supportedMethods => [
        'ping',
        'dnsLookup',
        'reverseDns',
        'traceroute',
        'isReachable',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'ping':
        return _ping(args);
      case 'dnsLookup':
        return _dnsLookup(args);
      case 'reverseDns':
        return _reverseDns(args);
      case 'traceroute':
        return _traceroute(args);
      case 'isReachable':
        return _isReachable(args);
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _ping(Map<String, dynamic> args) async {
    final host = args['host'] as String;
    final count = (args['count'] as num?)?.toInt() ?? 4;
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 5000;

    try {
      final result = await Process.run(
        'ping',
        ['-c', '$count', '-W', '${timeoutMs ~/ 1000}', host],
      );

      final output = result.stdout.toString();
      final success = result.exitCode == 0;

      // Parse ping output
      double? avgMs;
      double? minMs;
      double? maxMs;
      int? packetLoss;

      final rttMatch = RegExp(
        r'rtt min/avg/max/mdev = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+)',
      ).firstMatch(output);

      if (rttMatch != null) {
        minMs = double.tryParse(rttMatch.group(1) ?? '');
        avgMs = double.tryParse(rttMatch.group(2) ?? '');
        maxMs = double.tryParse(rttMatch.group(3) ?? '');
      }

      final lossMatch = RegExp(r'(\d+)% packet loss').firstMatch(output);
      if (lossMatch != null) {
        packetLoss = int.tryParse(lossMatch.group(1) ?? '');
      }

      return {
        'host': host,
        'reachable': success,
        'count': count,
        'avgMs': avgMs,
        'minMs': minMs,
        'maxMs': maxMs,
        'packetLoss': packetLoss,
        'output': output,
      };
    } catch (e) {
      // Fallback: TCP connect test
      return _isReachable({'host': host, 'timeoutMs': timeoutMs});
    }
  }

  Future<Map<String, dynamic>> _dnsLookup(Map<String, dynamic> args) async {
    final host = args['host'] as String;

    try {
      final addresses = await InternetAddress.lookup(host);

      final results = addresses.map((addr) {
        return {
          'address': addr.address,
          'host': addr.host,
          'type': addr.type == InternetAddressType.IPv4 ? 'IPv4' : 'IPv6',
          'isLoopback': addr.isLoopback,
        };
      }).toList();

      return {
        'host': host,
        'resolved': true,
        'addresses': results,
        'primary': results.isNotEmpty ? results.first['address'] : null,
        'count': results.length,
      };
    } on SocketException catch (e) {
      return {
        'host': host,
        'resolved': false,
        'error': e.message,
      };
    }
  }

  Future<Map<String, dynamic>> _reverseDns(Map<String, dynamic> args) async {
    final ip = args['ip'] as String;

    try {
      final address = InternetAddress(ip);
      final result = await address.reverse();

      return {
        'ip': ip,
        'hostname': result.host,
        'resolved': true,
      };
    } catch (e) {
      return {
        'ip': ip,
        'hostname': null,
        'resolved': false,
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _traceroute(Map<String, dynamic> args) async {
    final host = args['host'] as String;
    final maxHops = (args['maxHops'] as num?)?.toInt() ?? 15;

    try {
      final result = await Process.run(
        'traceroute',
        ['-m', '$maxHops', '-w', '2', host],
      ).timeout(const Duration(seconds: 30));

      final output = result.stdout.toString();
      final lines =
          output.split('\n').where((l) => l.trim().isNotEmpty).toList();

      final hops = <Map<String, dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        final hopMatch = RegExp(
          r'^\s*(\d+)\s+(\S+)\s+\((\S+)\)\s+([\d.]+)\s*ms',
        ).firstMatch(line);

        if (hopMatch != null) {
          hops.add({
            'hop': int.parse(hopMatch.group(1) ?? '0'),
            'host': hopMatch.group(2),
            'ip': hopMatch.group(3),
            'rttMs': double.tryParse(hopMatch.group(4) ?? ''),
          });
        } else if (line.contains('* * *')) {
          final hopNum = RegExp(r'^\s*(\d+)').firstMatch(line);
          hops.add({
            'hop': int.parse(hopNum?.group(1) ?? '$i'),
            'host': '*',
            'ip': '*',
            'rttMs': null,
            'timeout': true,
          });
        }
      }

      return {
        'host': host,
        'hops': hops,
        'hopCount': hops.length,
        'completed': result.exitCode == 0,
      };
    } catch (e) {
      return {'host': host, 'hops': <dynamic>[], 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _isReachable(Map<String, dynamic> args) async {
    final host = args['host'] as String;
    final port = (args['port'] as num?)?.toInt() ?? 80;
    final timeoutMs = (args['timeoutMs'] as num?)?.toInt() ?? 3000;

    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: Duration(milliseconds: timeoutMs),
      );
      await socket.close();

      return {'host': host, 'port': port, 'reachable': true};
    } catch (e) {
      return {'host': host, 'port': port, 'reachable': false};
    }
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'ping':
      case 'dnsLookup':
      case 'traceroute':
      case 'isReachable':
        if (args['host'] is! String) {
          return ValidationResult.invalid('host is required');
        }
        return ValidationResult.valid();
      case 'reverseDns':
        if (args['ip'] is! String) {
          return ValidationResult.invalid('ip is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
