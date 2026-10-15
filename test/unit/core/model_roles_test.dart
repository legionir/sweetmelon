import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

ModelFile f(String name, [int size = 1]) =>
    ModelFile(name: name, path: '/m/$name', size: size);

void main() {
  group('detectLlmFiles', () {
    test('picks the largest gguf and the projector', () {
      final files = detectLlmFiles([
        f('model-q4.gguf', 4000),
        f('model-q8.gguf', 8000),
        f('mmproj-model-f16.gguf', 600),
        f('readme.txt'),
      ])!;
      expect(files.model.name, 'model-q8.gguf');
      expect(files.mmproj!.name, 'mmproj-model-f16.gguf');
    });

    test('a projector alone is not a model', () {
      expect(detectLlmFiles([f('mmproj.gguf')]), isNull);
      expect(detectLlmFiles([f('a.bin')]), isNull);
    });

    test('is case-insensitive and needs no projector', () {
      final files = detectLlmFiles([f('MODEL.GGUF')])!;
      expect(files.model.name, 'MODEL.GGUF');
      expect(files.mmproj, isNull);
    });
  });

  group('detectAsrFiles', () {
    test('Whisper: encoder, decoder and tokens, quantised files win', () {
      final files = detectAsrFiles([
        f('small-encoder.onnx'),
        f('small-encoder.int8.onnx'),
        f('small-decoder.onnx'),
        f('small-decoder.int8.onnx'),
        f('small-tokens.txt'),
      ])!;
      expect(files.type, AsrType.whisper);
      expect(files.encoder!.name, 'small-encoder.int8.onnx');
      expect(files.decoder!.name, 'small-decoder.int8.onnx');
      expect(files.tokens.name, 'small-tokens.txt');
    });

    test('tokens.txt beats a prefixed tokens file', () {
      final files = detectAsrFiles([
        f('x-tokens.txt'),
        f('tokens.txt'),
        f('tiny-encoder.onnx'),
        f('tiny-decoder.onnx'),
      ])!;
      expect(files.tokens.name, 'tokens.txt');
    });

    test('a joiner makes it a transducer', () {
      final files = detectAsrFiles([
        f('encoder.onnx'),
        f('decoder.onnx'),
        f('joiner.onnx'),
        f('tokens.txt'),
      ])!;
      expect(files.type, AsrType.transducer);
      expect(files.joiner!.name, 'joiner.onnx');
    });

    test('one model file is SenseVoice unless Paraformer is named', () {
      final list = [f('model.int8.onnx'), f('tokens.txt')];
      expect(detectAsrFiles(list)!.type, AsrType.senseVoice);
      expect(detectAsrFiles(list, requested: AsrType.paraformer)!.type,
          AsrType.paraformer);
      expect(detectAsrFiles(list)!.model!.name, 'model.int8.onnx');
    });

    test('missing pieces give null', () {
      expect(detectAsrFiles([f('encoder.onnx'), f('decoder.onnx')]), isNull,
          reason: 'no tokens');
      expect(
          detectAsrFiles([f('encoder.onnx'), f('tokens.txt')],
              requested: AsrType.whisper),
          isNull,
          reason: 'no decoder');
      expect(detectAsrFiles([f('tokens.txt')], requested: AsrType.transducer),
          isNull);
    });

    test('type names round trip', () {
      for (final type in AsrType.values) {
        expect(asrTypeFromName(asrTypeName(type)), type);
      }
      expect(asrTypeFromName('nope'), isNull);
    });
  });

  group('detectTtsFiles', () {
    test('Piper voice: model, tokens and the espeak data folder', () {
      final files = detectTtsFiles(
        [f('fa_IR-gyro-medium.onnx', 60000), f('tokens.txt')],
        ['espeak-ng-data'],
        '/models/tts/v',
      )!;
      expect(files.type, TtsType.vits);
      expect(files.model.name, 'fa_IR-gyro-medium.onnx');
      expect(files.dataDir, '/models/tts/v/espeak-ng-data');
      expect(files.voices, isNull);
    });

    test('voices.bin makes it Kokoro', () {
      final files = detectTtsFiles(
        [f('model.onnx'), f('tokens.txt'), f('voices.bin')],
        ['espeak-ng-data'],
        '/d',
      )!;
      expect(files.type, TtsType.kokoro);
      expect(files.voices!.name, 'voices.bin');
    });

    test('Kokoro needs its voices', () {
      expect(
          detectTtsFiles([f('model.onnx'), f('tokens.txt')], [], '/d',
              requested: TtsType.kokoro),
          isNull);
    });

    test('the lexicon is found, a vocoder is not a model', () {
      final files = detectTtsFiles(
        [
          f('vocoder.onnx', 9),
          f('voice.onnx', 5),
          f('tokens.txt'),
          f('lexicon.txt')
        ],
        [],
        '/d',
      )!;
      expect(files.model.name, 'voice.onnx');
      expect(files.lexicon!.name, 'lexicon.txt');
      expect(files.dataDir, isNull);
    });

    test('no tokens or no model gives null', () {
      expect(detectTtsFiles([f('m.onnx')], [], '/d'), isNull);
      expect(detectTtsFiles([f('tokens.txt')], [], '/d'), isNull);
    });
  });
}
