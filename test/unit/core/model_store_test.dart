import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  late Directory temp;
  late ModelStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('model_store_test');
    store = ModelStore(Directory(p.join(temp.path, 'models')));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<ModelEntry> addModel(String kind, String name,
      {Map<String, String> files = const {}}) async {
    final entry = await store.create(kind: kind, name: name);
    for (final e in files.entries) {
      File(p.join(entry.dir, e.key)).writeAsStringSync(e.value);
    }
    return (await store.get(entry.id))!;
  }

  group('slug', () {
    test('keeps letters and digits, drops the extension', () {
      expect(ModelStore.slug('Qwen2.5-0.5B Instruct.Q4_K_M.gguf'),
          'qwen2-5-0-5b-instruct-q4-k-m');
    });

    test('falls back to model', () {
      expect(ModelStore.slug('فارسی'), 'model');
      expect(ModelStore.slug('   '), 'model');
    });

    test('is cut to a sensible length', () {
      expect(ModelStore.slug('a' * 200).length, lessThanOrEqualTo(48));
    });
  });

  group('models', () {
    test('create makes a folder with an id built from the name', () async {
      final entry = await store.create(kind: 'llm', name: 'My Model');
      expect(entry.id, startsWith('my-model-'));
      expect(modelIdPattern.hasMatch(entry.id), isTrue);
      expect(entry.name, 'My Model');
      expect(Directory(entry.dir).existsSync(), isTrue);
      expect(p.basename(p.dirname(entry.dir)), 'llm');
    });

    test('the same name twice gives two models', () async {
      final a = await store.create(kind: 'llm', name: 'same');
      final b = await store.create(kind: 'llm', name: 'same');
      expect(a.id, isNot(b.id));
    });

    test('list shows the files of each model and skips the meta file',
        () async {
      await addModel('llm', 'chat', files: {'a.gguf': 'x' * 10});
      await addModel('stt', 'whisper', files: {'tokens.txt': 'ab'});

      final all = await store.list();
      expect(all, hasLength(2));
      expect(
          (await store.list(kind: 'llm')).single.files.single.name, 'a.gguf');
      expect((await store.list(kind: 'llm')).single.sizeBytes, 10);
      expect(all.expand((m) => m.files).any((f) => f.name.startsWith('.')),
          isFalse);
    });

    test('directories are listed by name, not walked', () async {
      final entry = await addModel('tts', 'voice');
      Directory(p.join(entry.dir, 'espeak-ng-data')).createSync();
      File(p.join(entry.dir, 'espeak-ng-data', 'x')).writeAsStringSync('1');

      final read = (await store.get(entry.id))!;
      expect(read.directories, ['espeak-ng-data']);
      expect(read.files, isEmpty);
    });

    test('get finds a model of any kind, and null for an unknown id', () async {
      final entry = await addModel('stt', 'w');
      expect((await store.get(entry.id))!.kind, 'stt');
      expect(await store.get('nope-123'), isNull);
      expect(await store.get('../etc'), isNull);
    });

    test('rename changes the name only', () async {
      final entry = await addModel('llm', 'old');
      final renamed = await store.rename(entry.id, '  New name ');
      expect(renamed.name, 'New name');
      expect(renamed.id, entry.id);
      expect(() => store.rename(entry.id, '  '), throwsArgumentError);
    });

    test('remove deletes the folder', () async {
      final entry = await addModel('llm', 'gone', files: {'a.gguf': 'x'});
      await store.remove(entry.id);
      expect(Directory(entry.dir).existsSync(), isFalse);
      expect(() => store.remove(entry.id), throwsArgumentError);
    });

    test('a damaged meta file falls back to the folder name', () async {
      final entry = await addModel('llm', 'x');
      File(p.join(entry.dir, '.sweetmelon-model.json')).writeAsStringSync('{');
      expect((await store.get(entry.id))!.name, entry.id);
    });

    test('a bad kind is refused', () {
      expect(() => store.create(kind: 'LLM', name: 'x'), throwsArgumentError);
      expect(() => store.create(kind: '../x', name: 'x'), throwsArgumentError);
    });
  });

  group('paths', () {
    test('only files inside the models folder are accepted', () async {
      final entry = await addModel('llm', 'm', files: {'a.gguf': 'x'});
      final inside = p.join(entry.dir, 'a.gguf');
      expect(store.requireInside(inside), inside);

      final outside = File(p.join(temp.path, 'secret.txt'))
        ..writeAsStringSync('s');
      expect(() => store.requireInside(outside.path), throwsArgumentError);
      expect(() => store.requireInside('relative/a.gguf'), throwsArgumentError);
      expect(() => store.requireInside(''), throwsArgumentError);
    });

    test('.. cannot climb out of the folder', () async {
      final entry = await addModel('llm', 'm', files: {'a.gguf': 'x'});
      File(p.join(temp.path, 'secret.txt')).writeAsStringSync('s');
      final sneaky = p.join(entry.dir, '..', '..', '..', 'secret.txt');
      expect(() => store.requireInside(sneaky), throwsArgumentError);
    });

    test('a link to a file outside is not accepted', () async {
      final entry = await addModel('llm', 'm');
      final secret = File(p.join(temp.path, 'secret.txt'))
        ..writeAsStringSync('s');
      final link = Link(p.join(entry.dir, 'link.gguf'))
        ..createSync(secret.path);
      expect(() => store.requireInside(link.path), throwsArgumentError);
    });
  });
}
