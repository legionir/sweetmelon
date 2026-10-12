import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef SttEventEmitter = Future<void> Function(String event, dynamic data);

class SpeechToTextPlugin extends Plugin {
  final SttEventEmitter? eventEmitter;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  bool _listening = false;

  SpeechToTextPlugin({this.eventEmitter});

  @override
  String get name => 'speechToText';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Speech to text recognition plugin';

  @override
  List<String> get requiredPermissions => ['microphone'];

  @override
  List<String> get supportedMethods => [
        'initialize',
        'startListening',
        'stopListening',
        'cancelListening',
        'isAvailable',
        'getLocales',
        'getInfo',
      ];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'initialize':
        return _initialize();
      case 'startListening':
        return _startListening(args);
      case 'stopListening':
        return _stopListening();
      case 'cancelListening':
        return _cancelListening();
      case 'isAvailable':
        return {'available': _available};
      case 'getLocales':
        return _getLocales();
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'available': _available,
          'listening': _listening,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _initialize() async {
    _available = await _speech.initialize(
      onStatus: (status) {
        _listening = status == 'listening';
        if (eventEmitter != null) {
          eventEmitter!('speechToText.status', {
            'status': status,
            'listening': _listening,
          });
        }
      },
      onError: (error) {
        BridgeLogger.error('STT', 'Error: ${error.errorMsg}');
        if (eventEmitter != null) {
          eventEmitter!('speechToText.error', {
            'message': error.errorMsg,
            'permanent': error.permanent,
          });
        }
      },
    );

    return {'initialized': _available};
  }

  Future<Map<String, dynamic>> _startListening(
      Map<String, dynamic> args) async {
    if (!_available) {
      await _initialize();
      if (!_available) {
        return {'started': false, 'reason': 'not_available'};
      }
    }

    final localeId = args['locale'] as String?;
    final listenFor = (args['listenForSeconds'] as num?)?.toInt() ?? 30;
    final pauseFor = (args['pauseForSeconds'] as num?)?.toInt() ?? 3;
    final partialResults = args['partialResults'] as bool? ?? true;

    final completer = Completer<Map<String, dynamic>>();

    await _speech.listen(
      onResult: (result) {
        final data = {
          'text': result.recognizedWords,
          'confidence': result.confidence,
          'finalResult': result.finalResult,
          'alternates': result.alternates.map((a) {
            return {
              'text': a.recognizedWords,
              'confidence': a.confidence,
            };
          }).toList(),
        };

        if (eventEmitter != null) {
          eventEmitter!('speechToText.result', data);
        }

        if (result.finalResult && !completer.isCompleted) {
          completer.complete(data);
        }
      },
      listenOptions: stt.SpeechListenOptions(
        localeId: localeId,
        listenFor: Duration(seconds: listenFor),
        pauseFor: Duration(seconds: pauseFor),
        partialResults: partialResults,
        listenMode: stt.ListenMode.confirmation,
      ),
    );

    _listening = true;

    return completer.future.timeout(
      Duration(seconds: listenFor + 5),
      onTimeout: () {
        _speech.stop();
        _listening = false;
        return {'text': '', 'finalResult': true, 'reason': 'timeout'};
      },
    );
  }

  Future<Map<String, dynamic>> _stopListening() async {
    await _speech.stop();
    _listening = false;
    return {'stopped': true};
  }

  Future<Map<String, dynamic>> _cancelListening() async {
    await _speech.cancel();
    _listening = false;
    return {'cancelled': true};
  }

  Future<Map<String, dynamic>> _getLocales() async {
    if (!_available) await _initialize();
    final locales = await _speech.locales();
    return {
      'locales': locales.map((l) {
        return {
          'id': l.localeId,
          'name': l.name,
        };
      }).toList(),
    };
  }

  @override
  Future<void> onDispose() async {
    if (_listening) await _speech.stop();
  }
}
