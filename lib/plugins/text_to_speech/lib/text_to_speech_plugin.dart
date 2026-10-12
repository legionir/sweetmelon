import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef TtsEventEmitter = Future<void> Function(String event, dynamic data);

class TextToSpeechPlugin extends Plugin {
  final TtsEventEmitter? eventEmitter;
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  TextToSpeechPlugin({this.eventEmitter});

  @override
  String get name => 'textToSpeech';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Text to speech plugin';

  @override
  List<String> get supportedMethods => [
        'speak',
        'stop',
        'pause',
        'setLanguage',
        'setSpeechRate',
        'setPitch',
        'setVolume',
        'getLanguages',
        'getVoices',
        'isSpeaking',
        'getInfo',
      ];

  @override
  Future<void> onInitialize() async {
    _tts.setStartHandler(() {
      _speaking = true;
      eventEmitter?.call('tts.start', {'speaking': true});
    });

    _tts.setCompletionHandler(() {
      _speaking = false;
      eventEmitter?.call('tts.complete', {'speaking': false});
    });

    _tts.setCancelHandler(() {
      _speaking = false;
      eventEmitter?.call('tts.cancel', {'speaking': false});
    });

    _tts.setErrorHandler((msg) {
      _speaking = false;
      BridgeLogger.error('TTS', 'Error: $msg');
      eventEmitter?.call('tts.error', {'message': msg});
    });

    _tts.setProgressHandler((text, start, end, word) {
      eventEmitter?.call('tts.progress', {
        'text': text,
        'start': start,
        'end': end,
        'word': word,
      });
    });
  }

  @override
  Future<void> onDispose() async {
    await _tts.stop();
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'speak':
        return _speak(args);
      case 'stop':
        return _stop();
      case 'pause':
        return _pause();
      case 'setLanguage':
        return _setLanguage(args);
      case 'setSpeechRate':
        return _setSpeechRate(args);
      case 'setPitch':
        return _setPitch(args);
      case 'setVolume':
        return _setVolume(args);
      case 'getLanguages':
        return _getLanguages();
      case 'getVoices':
        return _getVoices();
      case 'isSpeaking':
        return {'speaking': _speaking};
      case 'getInfo':
        return {
          'name': name,
          'version': version,
          'speaking': _speaking,
        };
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _speak(Map<String, dynamic> args) async {
    final text = args['text'] as String;
    final language = args['language'] as String?;
    final rate = (args['rate'] as num?)?.toDouble();
    final pitch = (args['pitch'] as num?)?.toDouble();
    final volume = (args['volume'] as num?)?.toDouble();

    if (language != null) await _tts.setLanguage(language);
    if (rate != null) await _tts.setSpeechRate(rate);
    if (pitch != null) await _tts.setPitch(pitch);
    if (volume != null) await _tts.setVolume(volume);

    await _tts.speak(text);
    _speaking = true;

    return {'speaking': true, 'textLength': text.length};
  }

  Future<Map<String, dynamic>> _stop() async {
    await _tts.stop();
    _speaking = false;
    return {'stopped': true};
  }

  Future<Map<String, dynamic>> _pause() async {
    await _tts.pause();
    _speaking = false;
    return {'paused': true};
  }

  Future<Map<String, dynamic>> _setLanguage(Map<String, dynamic> args) async {
    final language = args['language'] as String;
    await _tts.setLanguage(language);
    return {'language': language};
  }

  Future<Map<String, dynamic>> _setSpeechRate(Map<String, dynamic> args) async {
    final rate = (args['rate'] as num).toDouble().clamp(0.0, 2.0);
    await _tts.setSpeechRate(rate);
    return {'rate': rate};
  }

  Future<Map<String, dynamic>> _setPitch(Map<String, dynamic> args) async {
    final pitch = (args['pitch'] as num).toDouble().clamp(0.5, 2.0);
    await _tts.setPitch(pitch);
    return {'pitch': pitch};
  }

  Future<Map<String, dynamic>> _setVolume(Map<String, dynamic> args) async {
    final volume = (args['volume'] as num).toDouble().clamp(0.0, 1.0);
    await _tts.setVolume(volume);
    return {'volume': volume};
  }

  Future<Map<String, dynamic>> _getLanguages() async {
    final languages = await _tts.getLanguages;
    return {'languages': List<String>.from(languages ?? [])};
  }

  Future<Map<String, dynamic>> _getVoices() async {
    final voices = await _tts.getVoices;
    return {
      'voices': (voices as List?)?.map((v) {
            final map = v as Map;
            return {'name': map['name'], 'locale': map['locale']};
          }).toList() ??
          [],
    };
  }

  @override
  Future<ValidationResult> validateArgs(
      String method, Map<String, dynamic> args) async {
    if (method == 'speak') {
      if (args['text'] is! String || (args['text'] as String).isEmpty) {
        return ValidationResult.invalid('text is required');
      }
    }
    return ValidationResult.valid();
  }
}
