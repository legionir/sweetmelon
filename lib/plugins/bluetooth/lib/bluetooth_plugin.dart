import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef BleEventEmitter = Future<void> Function(String event, dynamic data);

class BluetoothPlugin extends Plugin {
  final BleEventEmitter? eventEmitter;

  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  final Map<String, BluetoothDevice> _connectedDevices = {};
  bool _scanning = false;

  BluetoothPlugin({this.eventEmitter});

  @override
  String get name => 'bluetooth';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Bluetooth Low Energy (BLE) plugin';

  @override
  List<String> get requiredPermissions => ['bluetooth'];

  @override
  List<String> get supportedMethods => [
        'isAvailable',
        'isOn',
        'startScan',
        'stopScan',
        'connect',
        'disconnect',
        'discoverServices',
        'readCharacteristic',
        'writeCharacteristic',
        'getConnectedDevices',
        'getInfo',
      ];

  @override
  Future<void> onDispose() async {
    await _scanSub?.cancel();
    await _connectionSub?.cancel();
    for (final device in _connectedDevices.values) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
    _connectedDevices.clear();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isAvailable':
        return _isAvailable();
      case 'isOn':
        return _isOn();
      case 'startScan':
        return _startScan(args);
      case 'stopScan':
        return _stopScan();
      case 'connect':
        return _connect(args);
      case 'disconnect':
        return _disconnect(args);
      case 'discoverServices':
        return _discoverServices(args);
      case 'readCharacteristic':
        return _readCharacteristic(args);
      case 'writeCharacteristic':
        return _writeCharacteristic(args);
      case 'getConnectedDevices':
        return _getConnectedDevices();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'scanning': _scanning,
          'connectedDevices': _connectedDevices.keys.toList(),
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _isAvailable() async {
    final supported = await FlutterBluePlus.isSupported;
    return {'available': supported};
  }

  Future<Map<String, dynamic>> _isOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return {
      'on': state == BluetoothAdapterState.on,
      'state': state.name,
    };
  }

  Future<Map<String, dynamic>> _startScan(Map<String, dynamic> args) async {
    if (_scanning) {
      return {'scanning': true, 'alreadyScanning': true};
    }

    final timeoutSec = (args['timeoutSeconds'] as num?)?.toInt() ?? 10;

    _scanning = true;

    _scanSub = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        if (eventEmitter != null) {
          eventEmitter!('bluetooth.deviceFound', {
            'deviceId': result.device.remoteId.str,
            'name': result.device.platformName.isNotEmpty
                ? result.device.platformName
                : 'Unknown',
            'rssi': result.rssi,
            'timestamp': DateTime.now().toIso8601String(),
          });
        }
      }
    });

    await FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSec),
    );

    _scanning = false;

    return {
      'scanning': true,
      'alreadyScanning': false,
      'timeoutSeconds': timeoutSec
    };
  }

  Future<Map<String, dynamic>> _stopScan() async {
    await FlutterBluePlus.stopScan();
    await _scanSub?.cancel();
    _scanSub = null;
    _scanning = false;
    return {'scanning': false};
  }

  Future<Map<String, dynamic>> _connect(Map<String, dynamic> args) async {
    final deviceId = args['deviceId'] as String;
    final timeoutSec = (args['timeoutSeconds'] as num?)?.toInt() ?? 15;

    final device = BluetoothDevice.fromId(deviceId);

    await device.connect(
      timeout: Duration(seconds: timeoutSec),
      autoConnect: args['autoConnect'] as bool? ?? false,
    );

    _connectedDevices[deviceId] = device;

    _connectionSub?.cancel();
    _connectionSub = device.connectionState.listen((state) {
      if (eventEmitter != null) {
        eventEmitter!('bluetooth.connectionState', {
          'deviceId': deviceId,
          'state': state.name,
          'connected': state == BluetoothConnectionState.connected,
        });
      }

      if (state == BluetoothConnectionState.disconnected) {
        _connectedDevices.remove(deviceId);
      }
    });

    BridgeLogger.info('Bluetooth', 'Connected to: $deviceId');

    return {'connected': true, 'deviceId': deviceId};
  }

  Future<Map<String, dynamic>> _disconnect(Map<String, dynamic> args) async {
    final deviceId = args['deviceId'] as String;
    final device = _connectedDevices[deviceId];

    if (device == null) {
      return {'disconnected': false, 'reason': 'not_connected'};
    }

    await device.disconnect();
    _connectedDevices.remove(deviceId);

    return {'disconnected': true, 'deviceId': deviceId};
  }

  Future<Map<String, dynamic>> _discoverServices(
      Map<String, dynamic> args) async {
    final deviceId = args['deviceId'] as String;
    final device = _connectedDevices[deviceId];

    if (device == null) {
      throw StateError('Device "$deviceId" not connected');
    }

    final services = await device.discoverServices();

    return {
      'deviceId': deviceId,
      'services': services.map((s) {
        return {
          'uuid': s.uuid.str,
          'characteristics': s.characteristics.map((c) {
            return {
              'uuid': c.uuid.str,
              'properties': {
                'read': c.properties.read,
                'write': c.properties.write,
                'writeWithoutResponse': c.properties.writeWithoutResponse,
                'notify': c.properties.notify,
                'indicate': c.properties.indicate,
              },
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  Future<Map<String, dynamic>> _readCharacteristic(
      Map<String, dynamic> args) async {
    final deviceId = args['deviceId'] as String;
    final serviceUuid = args['serviceUuid'] as String;
    final characteristicUuid = args['characteristicUuid'] as String;

    final device = _connectedDevices[deviceId];
    if (device == null) throw StateError('Device not connected');

    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid.str.toLowerCase() == serviceUuid.toLowerCase(),
      orElse: () => throw StateError('Service not found'),
    );

    final characteristic = service.characteristics.firstWhere(
      (c) => c.uuid.str.toLowerCase() == characteristicUuid.toLowerCase(),
      orElse: () => throw StateError('Characteristic not found'),
    );

    final value = await characteristic.read();

    return {
      'deviceId': deviceId,
      'serviceUuid': serviceUuid,
      'characteristicUuid': characteristicUuid,
      'value': value,
      'valueBase64': base64Encode(Uint8List.fromList(value)),
      'valueString': String.fromCharCodes(value),
    };
  }

  Future<Map<String, dynamic>> _writeCharacteristic(
      Map<String, dynamic> args) async {
    final deviceId = args['deviceId'] as String;
    final serviceUuid = args['serviceUuid'] as String;
    final characteristicUuid = args['characteristicUuid'] as String;
    final valueBase64 = args['value'] as String;
    final withResponse = args['withResponse'] as bool? ?? true;

    final device = _connectedDevices[deviceId];
    if (device == null) throw StateError('Device not connected');

    final services = await device.discoverServices();
    final service = services.firstWhere(
      (s) => s.uuid.str.toLowerCase() == serviceUuid.toLowerCase(),
    );

    final characteristic = service.characteristics.firstWhere(
      (c) => c.uuid.str.toLowerCase() == characteristicUuid.toLowerCase(),
    );

    final bytes = base64Decode(valueBase64);

    await characteristic.write(
      bytes,
      withoutResponse: !withResponse,
    );

    return {'written': true, 'bytes': bytes.length};
  }

  Map<String, dynamic> _getConnectedDevices() {
    return {
      'devices': _connectedDevices.entries.map((e) {
        return {
          'deviceId': e.key,
          'name': e.value.platformName.isNotEmpty
              ? e.value.platformName
              : 'Unknown',
        };
      }).toList(),
      'count': _connectedDevices.length,
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'connect':
      case 'disconnect':
      case 'discoverServices':
        final id = args['deviceId'];
        if (id is! String || id.isEmpty) {
          return ValidationResult.invalid('deviceId is required');
        }
        return ValidationResult.valid();

      case 'readCharacteristic':
      case 'writeCharacteristic':
        for (final field in ['deviceId', 'serviceUuid', 'characteristicUuid']) {
          final val = args[field];
          if (val is! String || val.isEmpty) {
            return ValidationResult.invalid('$field is required');
          }
        }
        if (method == 'writeCharacteristic') {
          final value = args['value'];
          if (value is! String || value.isEmpty) {
            return ValidationResult.invalid('value (base64) is required');
          }
        }
        return ValidationResult.valid();

      default:
        return ValidationResult.valid();
    }
  }
}
