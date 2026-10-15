import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/plugins/model_manager/lib/model_manager_plugin.dart';

void main() {
  late Directory temp;
  late ModelStore store;
  late List<PickedModelFile>? picks;
  late List<String> events;
  late ModelManagerPlugin plugin;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('model_manager_test');
    store = ModelStore(Directory(p.join(temp.path, 'models')));
    picks = null;
    events = [];
    plugin = ModelManagerPlugin(
      store: store,
      picker: (_) async => picks,
      eventEmitter: (event, data) async {
        events.add('$event:${(data as Map)['stage']}');
      },
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  /// A file as the system picker leaves it: in the cache, with its name.
  PickedModelFile picked(String name, String content) {
    final cache = Directory(p.join(temp.path, 'cache'))
      ..createSync(recursive: true);
    final file = File(p.join(cache.path, name))..writeAsStringSync(content);
    return PickedModelFile(name: name, path: file.path);
  }

  Future<Map<String, dynamic>> import(Map<String, dynamic> args) async =>
      (await plugin.onCall('import', args)) as Map<String, dynamic>;

  test('declares no permission and the expected methods', () {
    expect(plugin.requiredPermissions, isEmpty);
    expect(plugin.supportedMethods,
        containsAll(['import', 'list', 'get', 'remove', 'rename']));
  });

  group('import', () {
    test('a cancelled picker imports nothing', () async {
      final result = await import({'kind': 'llm'});
      expect(result['imported'], isFalse);
      expect(result['reason'], 'cancelled');
      expect(await store.list(), isEmpty);
    });

    test('files are moved into the model folder', () async {
      final file = picked('qwen-0.5b.gguf', 'weights');
      picks = [file];

      final result = await import({'kind': 'llm'});

      expect(result['imported'], isTrue);
      final model = result['model'] as Map;
      expect(model['kind'], 'llm');
      expect(model['name'], 'qwen-0.5b');
      expect((model['files'] as List).single['name'], 'qwen-0.5b.gguf');
      expect(File(file.path).existsSync(), isFalse,
          reason: 'moved, not copied');
      expect(
          File(p.join(model['dir'] as String, 'qwen-0.5b.gguf'))
              .readAsStringSync(),
          'weights');
    });

    test('several files make one model, and the name can be given', () async {
      picks = [
        picked('small-encoder.onnx', 'e'),
        picked('small-decoder.onnx', 'd'),
        picked('small-tokens.txt', 't'),
      ];
      final result = await import({'kind': 'stt', 'name': 'Whisper small'});
      final model = result['model'] as Map;
      expect(model['name'], 'Whisper small');
      expect((model['files'] as List).map((f) => f['name']),
          ['small-decoder.onnx', 'small-encoder.onnx', 'small-tokens.txt']);
      expect(events.first, 'modelManager.progress:start');
      expect(events.last, 'modelManager.progress:done');
    });

    test('a zip is extracted and its single folder is flattened', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('vits-piper/model.onnx', [1, 2, 3]))
        ..addFile(ArchiveFile.bytes('vits-piper/tokens.txt', [4]))
        ..addFile(ArchiveFile.bytes('vits-piper/espeak-ng-data/en', [5]));
      final zip = File(p.join(temp.path, 'voice.zip'))
        ..writeAsBytesSync(ZipEncoder().encode(archive));
      picks = [PickedModelFile(name: 'voice.zip', path: zip.path)];

      final model = (await import({'kind': 'tts'}))['model'] as Map;

      expect(model['name'], 'voice');
      expect((model['files'] as List).map((f) => f['name']),
          ['model.onnx', 'tokens.txt']);
      expect(model['directories'], ['espeak-ng-data']);
      expect(zip.existsSync(), isFalse, reason: 'the archive is removed');
    });

    test('a tar.gz is extracted too', () async {
      final archive = Archive()
        ..addFile(ArchiveFile.bytes('m/model.onnx', [1]))
        ..addFile(ArchiveFile.bytes('m/tokens.txt', [2]));
      final tarGz = File(p.join(temp.path, 'voice.tar.gz'))
        ..writeAsBytesSync(
            const GZipEncoder().encode(TarEncoder().encode(archive)));
      picks = [PickedModelFile(name: 'voice.tar.gz', path: tarGz.path)];

      final model = (await import({'kind': 'tts'}))['model'] as Map;

      expect(model['name'], 'voice');
      expect((model['files'] as List).map((f) => f['name']),
          ['model.onnx', 'tokens.txt']);
    });

    test('extract: false keeps the archive as a file', () async {
      final zip = File(p.join(temp.path, 'a.zip'))..writeAsBytesSync([1, 2]);
      picks = [PickedModelFile(name: 'a.zip', path: zip.path)];
      final model =
          (await import({'kind': 'x', 'extract': false}))['model'] as Map;
      expect((model['files'] as List).single['name'], 'a.zip');
    });

    test('a broken archive leaves no model behind', () async {
      final bad = File(p.join(temp.path, 'bad.zip'))
        ..writeAsStringSync('not a zip');
      picks = [PickedModelFile(name: 'bad.zip', path: bad.path)];

      await expectLater(import({'kind': 'tts'}), throwsA(anything));
      expect(await store.list(), isEmpty);
    });

    test('a file name with a path or a dot prefix is refused', () async {
      final file = picked('x.gguf', 'x');
      picks = [PickedModelFile(name: '.hidden', path: file.path)];
      await expectLater(import({'kind': 'llm'}), throwsArgumentError);
      expect(await store.list(), isEmpty);

      final other = picked('y.gguf', 'y');
      picks = [PickedModelFile(name: '../../escape.gguf', path: other.path)];
      final model = (await import({'kind': 'llm'}))['model'] as Map;
      expect((model['files'] as List).single['name'], 'escape.gguf',
          reason: 'only the last part of the name is used');
    });
  });

  group('list, get, rename, remove', () {
    test('they work on what was imported', () async {
      picks = [picked('a.gguf', 'x')];
      final id =
          ((await import({'kind': 'llm'}))['model'] as Map)['id'] as String;
      picks = [picked('b.onnx', 'y')];
      await import({'kind': 'stt'});

      expect(((await plugin.onCall('list', {}) as Map)['models'] as List),
          hasLength(2));
      expect(
          ((await plugin.onCall('list', {'kind': 'llm'}) as Map)['models']
              as List),
          hasLength(1));
      expect((await plugin.onCall('get', {'id': id}) as Map)['found'], isTrue);
      expect((await plugin.onCall('get', {'id': 'zzz-1'}) as Map)['found'],
          isFalse);

      final renamed =
          await plugin.onCall('rename', {'id': id, 'name': 'Chat'}) as Map;
      expect((renamed['model'] as Map)['name'], 'Chat');

      await plugin.onCall('remove', {'id': id});
      expect(((await plugin.onCall('list', {}) as Map)['models'] as List),
          hasLength(1));

      final info = await plugin.onCall('getInfo', {}) as Map;
      expect(info['count'], 1);
      expect(info['root'], store.root.path);
    });
  });

  group('validateArgs', () {
    Future<bool> ok(String method, Map<String, dynamic> args) async =>
        (await plugin.validateArgs(method, args)).isValid;

    test('import needs a valid kind', () async {
      expect(await ok('import', {}), isFalse);
      expect(await ok('import', {'kind': 'LLM'}), isFalse);
      expect(await ok('import', {'kind': '../x'}), isFalse);
      expect(await ok('import', {'kind': 'llm'}), isTrue);
      expect(
          await ok('import', {'kind': 'llm', 'extensions': 'gguf'}), isFalse);
      expect(
          await ok('import', {
            'kind': 'llm',
            'extensions': ['gguf']
          }),
          isTrue);
    });

    test('get, remove and rename need an id; rename a name', () async {
      for (final method in ['get', 'remove', 'rename']) {
        expect(await ok(method, {}), isFalse);
        expect(await ok(method, {'id': '../x'}), isFalse);
      }
      expect(await ok('get', {'id': 'a-1'}), isTrue);
      expect(await ok('rename', {'id': 'a-1'}), isFalse);
      expect(await ok('rename', {'id': 'a-1', 'name': ' '}), isFalse);
      expect(await ok('rename', {'id': 'a-1', 'name': 'x'}), isTrue);
    });
  });
}
