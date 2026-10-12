import 'dart:async';
import 'dart:convert';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef NfcEventEmitter = Future<void> Function(String event, dynamic data);

class NfcPlugin extends Plugin {
  final NfcEventEmitter? eventEmitter;
  bool _sessionActive = false;

  NfcPlugin({this.eventEmitter});

  @override
  String get name => 'nfc';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'NFC read/write plugin';

  @override
  List<String> get supportedMethods => [
        'isAvailable',
        'startSession',
        'stopSession',
        'writeText',
        'writeUri',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'isAvailable':
        return _isAvailable();
      case 'startSession':
        return _startSession(args);
      case 'stopSession':
        return _stopSession();
      case 'writeText':
        return _writeText(args);
      case 'writeUri':
        return _writeUri(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'sessionActive': _sessionActive,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _isAvailable() async {
    final available = await NfcManager.instance.isAvailable();
    return {'available': available};
  }

  Future<Map<String, dynamic>> _startSession(Map<String, dynamic> args) async {
    if (_sessionActive) {
      return {'started': true, 'alreadyActive': true};
    }

    final completer = Completer<Map<String, dynamic>>();
    final readOnce = args['readOnce'] as bool? ?? true;

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        final data = _parseTag(tag);

        BridgeLogger.info('NFC', 'Tag discovered: ${data['id']}');

        if (eventEmitter != null) {
          await eventEmitter!('nfc.tagDiscovered', data);
        }

        if (readOnce) {
          NfcManager.instance.stopSession();
          _sessionActive = false;
        }

        if (!completer.isCompleted) {
          completer.complete(data);
        }
      },
      onError: (error) async {
        BridgeLogger.error('NFC', 'Session error: $error');
        _sessionActive = false;

        if (eventEmitter != null) {
          await eventEmitter!('nfc.error', {
            'message': error.message,
            'details': error.details.toString(),
          });
        }

        if (!completer.isCompleted) {
          completer.complete({
            'error': true,
            'message': error.message,
          });
        }
      },
    );

    _sessionActive = true;

    if (readOnce) {
      return completer.future;
    }

    return {'started': true, 'alreadyActive': false, 'mode': 'continuous'};
  }

  Future<Map<String, dynamic>> _stopSession() async {
    NfcManager.instance.stopSession();
    _sessionActive = false;
    return {'stopped': true};
  }

  Future<Map<String, dynamic>> _writeText(Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final completer = Completer<Map<String, dynamic>>();

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            completer.complete({
              'written': false,
              'reason': ndef == null ? 'not_ndef' : 'not_writable',
            });
            NfcManager.instance.stopSession();
            return;
          }

          final record = NdefRecord.createText(text);
          final message = NdefMessage([record]);
          await ndef.write(message);

          completer.complete({
            'written': true,
            'text': text,
            'bytes': message.byteLength,
          });
        } catch (e) {
          completer.complete({
            'written': false,
            'reason': e.toString(),
          });
        }

        NfcManager.instance.stopSession();
        _sessionActive = false;
      },
      onError: (error) async {
        _sessionActive = false;
        if (!completer.isCompleted) {
          completer.complete({'written': false, 'reason': error.message});
        }
      },
    );

    _sessionActive = true;
    return completer.future;
  }

  Future<Map<String, dynamic>> _writeUri(Map<String, dynamic> args) async {
    final uri = args['uri'] as String;
    final completer = Completer<Map<String, dynamic>>();

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        try {
          final ndef = Ndef.from(tag);
          if (ndef == null || !ndef.isWritable) {
            completer.complete({'written': false, 'reason': 'not_writable'});
            NfcManager.instance.stopSession();
            return;
          }

          final record = NdefRecord.createUri(Uri.parse(uri));
          final message = NdefMessage([record]);
          await ndef.write(message);

          completer.complete({'written': true, 'uri': uri});
        } catch (e) {
          completer.complete({'written': false, 'reason': e.toString()});
        }

        NfcManager.instance.stopSession();
        _sessionActive = false;
      },
      onError: (error) async {
        _sessionActive = false;
        if (!completer.isCompleted) {
          completer.complete({'written': false, 'reason': error.message});
        }
      },
    );

    _sessionActive = true;
    return completer.future;
  }

  Map<String, dynamic> _parseTag(NfcTag tag) {
    final data = <String, dynamic>{
      'id': null,
      'type': 'unknown',
      'records': <dynamic>[],
      'timestamp': DateTime.now().toIso8601String(),
    };

    final ndef = Ndef.from(tag);
    if (ndef != null) {
      data['type'] = 'ndef';
      data['isWritable'] = ndef.isWritable;
      data['maxSize'] = ndef.maxSize;

      final message = ndef.cachedMessage;
      if (message != null) {
        data['records'] = message.records.map((record) {
          return {
            'typeNameFormat': record.typeNameFormat.index,
            'type': utf8.decode(record.type),
            'payload': base64Encode(record.payload),
            'payloadString': _tryDecodePayload(record),
          };
        }).toList();
      }
    }

    final nfcA = tag.data['nfca'] as Map<String, dynamic>?;
    if (nfcA != null) {
      final identifier = nfcA['identifier'] as List<dynamic>?;
      if (identifier != null) {
        data['id'] = identifier
            .map((b) => (b as int).toRadixString(16).padLeft(2, '0'))
            .join(':');
      }
    }

    final nfcB = tag.data['nfcb'] as Map<String, dynamic>?;
    if (nfcB != null) {
      final identifier = nfcB['identifier'] as List<dynamic>?;
      if (identifier != null) {
        data['id'] = identifier
            .map((b) => (b as int).toRadixString(16).padLeft(2, '0'))
            .join(':');
      }
    }

    return data;
  }

  String? _tryDecodePayload(NdefRecord record) {
    try {
      final payload = record.payload;
      if (payload.isEmpty) return null;

      if (record.typeNameFormat == NdefTypeNameFormat.nfcWellknown) {
        final type = utf8.decode(record.type);

        if (type == 'T') {
          final langLength = payload[0] & 0x3F;
          return utf8.decode(payload.sublist(1 + langLength));
        }

        if (type == 'U') {
          final prefix = _uriPrefixes[payload[0]] ?? '';
          return prefix + utf8.decode(payload.sublist(1));
        }
      }

      return utf8.decode(payload);
    } catch (_) {
      return null;
    }
  }

  static const Map<int, String> _uriPrefixes = {
    0x00: '',
    0x01: 'http://www.',
    0x02: 'https://www.',
    0x03: 'http://',
    0x04: 'https://',
    0x05: 'tel:',
    0x06: 'mailto:',
  };

  @override
  Future<void> onDispose() async {
    if (_sessionActive) {
      NfcManager.instance.stopSession();
      _sessionActive = false;
    }
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'writeText':
        if (args['text'] is! String || (args['text'] as String).isEmpty) {
          return ValidationResult.invalid('text is required');
        }
        return ValidationResult.valid();
      case 'writeUri':
        if (args['uri'] is! String || (args['uri'] as String).isEmpty) {
          return ValidationResult.invalid('uri is required');
        }
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
