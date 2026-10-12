import 'dart:async';

import 'package:sms_autofill/sms_autofill.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SmsEventEmitter = Future<void> Function(String event, dynamic data);

class SmsOtpPlugin extends Plugin with CodeAutoFill {
  final SmsEventEmitter? eventEmitter;

  String? _appSignature;
  String? _lastCode;
  bool _listening = false;

  SmsOtpPlugin({this.eventEmitter});

  @override
  String get name => 'smsOtp';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'SMS OTP auto-read plugin';

  @override
  List<String> get supportedMethods => [
        'getAppSignature',
        'startListening',
        'stopListening',
        'getLastCode',
        'requestHint',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    try {
      _appSignature = await SmsAutoFill().getAppSignature;
      BridgeLogger.info('SmsOtp', 'App signature: $_appSignature');
    } catch (e) {
      BridgeLogger.warn('SmsOtp', 'Failed to get app signature: $e');
    }
  }

  @override
  Future<void> onDispose() async {
    cancel();
    unregisterListener();
    _listening = false;
  }

  @override
  void codeUpdated() {
    final code = this.code;

    if (code != null && code.isNotEmpty) {
      _lastCode = code;
      BridgeLogger.info('SmsOtp', 'Code received: $code');

      if (eventEmitter != null) {
        eventEmitter!('smsOtp.received', {
          'code': code,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    }
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'getAppSignature':
        return {'signature': _appSignature};

      case 'startListening':
        return _startListening();

      case 'stopListening':
        return _stopListening();

      case 'getLastCode':
        return {'code': _lastCode};

      case 'requestHint':
        return _requestHint();

      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'listening': _listening,
          'signature': _appSignature,
          'lastCode': _lastCode,
        };

      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _startListening() async {
    if (_listening) {
      return {'listening': true, 'alreadyListening': true};
    }

    listenForCode();
    await SmsAutoFill().listenForCode();
    _listening = true;

    return {'listening': true, 'alreadyListening': false};
  }

  Future<Map<String, dynamic>> _stopListening() async {
    cancel();
    unregisterListener();
    _listening = false;

    return {'listening': false};
  }

  Future<Map<String, dynamic>> _requestHint() async {
    try {
      final hint = await SmsAutoFill().hint;
      return {'hint': hint};
    } catch (e) {
      BridgeLogger.warn('SmsOtp', 'Hint request failed: $e');
      return {'hint': null, 'error': e.toString()};
    }
  }
}
