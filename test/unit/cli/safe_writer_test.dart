import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sweetmelon/cli/safe_writer.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('safe_writer_test');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  String path(String relative) => p.join(root.path, relative);

  test('dry run reports changes and writes nothing', () async {
    await File(path('a.txt')).writeAsString('old');
    final writer = SafeWriter(root: root.path, dryRun: true)
      ..replace('a.txt', 'new')
      ..replace('b.txt', 'created');

    final changes = await writer.commit();

    expect(changes.map((c) => c.toString()), ['M a.txt', 'A b.txt']);
    expect(await File(path('a.txt')).readAsString(), 'old');
    expect(await File(path('b.txt')).exists(), isFalse);
    expect(await Directory(path('.sweetmelon')).exists(), isFalse);
  });

  test('files with identical content are not reported', () async {
    await File(path('same.txt')).writeAsString('same');
    final writer = SafeWriter(root: root.path, dryRun: true)
      ..replace('same.txt', 'same');

    expect(await writer.commit(), isEmpty);
  });

  test('apply writes files and keeps a backup of the old content', () async {
    await File(path('a.txt')).writeAsString('old');
    final writer = SafeWriter(root: root.path, requireCleanGit: false)
      ..replace('a.txt', 'new')
      ..replace('nested/b.txt', 'created');

    await writer.commit();

    expect(await File(path('a.txt')).readAsString(), 'new');
    expect(await File(path('nested/b.txt')).readAsString(), 'created');

    final backups = Directory(path('.sweetmelon/backup'));
    final stamp = (await backups.list().toList()).single;
    final backedUp = File(p.join(stamp.path, 'a.txt'));
    expect(await backedUp.readAsString(), 'old');
  });

  test('a failed write restores earlier files and removes new ones', () async {
    await File(path('a.txt')).writeAsString('old a');
    await File(path('b.txt')).writeAsString('old b');

    var calls = 0;
    final writer = SafeWriter(
      root: root.path,
      requireCleanGit: false,
      writeFile: (file, bytes) async {
        calls++;
        if (calls == 2) throw const FileSystemException('disk full');
        await file.writeAsBytes(bytes);
      },
    )
      ..replace('a.txt', 'new a')
      ..replace('b.txt', 'new b')
      ..replace('c.txt', 'new c');

    await expectLater(writer.commit(), throwsA(isA<FileSystemException>()));

    expect(await File(path('a.txt')).readAsString(), 'old a');
    expect(await File(path('b.txt')).readAsString(), 'old b');
    expect(await File(path('c.txt')).exists(), isFalse);
  });

  test('refuses to write when git reports uncommitted changes', () async {
    final writer = SafeWriter(
      root: root.path,
      gitStatus: () async => ' M lib/x.dart\n',
    )..replace('a.txt', 'new');

    await expectLater(writer.commit(), throwsA(isA<StateError>()));
    expect(await File(path('a.txt')).exists(), isFalse);
  });

  test('writes when the git tree is clean', () async {
    final writer = SafeWriter(
      root: root.path,
      gitStatus: () async => '',
    )..replace('a.txt', 'new');

    await writer.commit();
    expect(await File(path('a.txt')).readAsString(), 'new');
  });

  test('treats a missing git repository as a reason to skip the check',
      () async {
    final writer = SafeWriter(
      root: root.path,
      gitStatus: () async => null,
    )..replace('a.txt', 'new');

    await writer.commit();
    expect(await File(path('a.txt')).readAsString(), 'new');
  });
}
