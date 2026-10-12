import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('AntiTampering', () {
    late AntiTampering at;

    setUp(() {
      at = AntiTampering();
    });

    test('disabled by default', () {
      expect(at.isEnabled, false);
    });

    test('enable/disable', () {
      at.enable();
      expect(at.isEnabled, true);
      at.disable();
      expect(at.isEnabled, false);
    });

    test('verifyFile passes when disabled', () async {
      final result = await at.verifyFile('/any/path');
      expect(result.valid, true);
      expect(result.reason, 'tampering_check_disabled');
    });

    test('verifyFile passes for unregistered file', () async {
      at.enable();
      final result = await at.verifyFile('/unknown/path');
      expect(result.valid, true);
      expect(result.reason, 'no_hash_registered');
    });

    test('verifyFile fails for missing file', () async {
      at.enable();
      at.registerHash('missing.txt', 'abc123');
      final result = await at.verifyFile('missing.txt');
      expect(result.valid, false);
      expect(result.reason, 'file_not_found');
    });

    test('computeFileHash produces consistent hash', () async {
      final tempDir = await Directory.systemTemp.createTemp('at_test');
      final file = File('${tempDir.path}/test.txt');
      await file.writeAsString('hello world');

      final hash1 = await AntiTampering.computeFileHash(file.path);
      final hash2 = await AntiTampering.computeFileHash(file.path);

      expect(hash1, hash2);
      expect(hash1, isNotEmpty);

      await tempDir.delete(recursive: true);
    });

    test('generateManifest creates hashes for directory', () async {
      final tempDir = await Directory.systemTemp.createTemp('manifest_test');
      await File('${tempDir.path}/a.txt').writeAsString('file a');
      await File('${tempDir.path}/b.txt').writeAsString('file b');

      final manifest = await AntiTampering.generateManifest(tempDir.path);

      expect(manifest.length, 2);
      expect(manifest.containsKey('a.txt'), true);
      expect(manifest.containsKey('b.txt'), true);

      await tempDir.delete(recursive: true);
    });

    test('verifyAll detects tampering', () async {
      final tempDir = await Directory.systemTemp.createTemp('verify_test');
      final file = File('${tempDir.path}/data.txt');
      await file.writeAsString('original content');

      final hash = await AntiTampering.computeFileHash(file.path);

      at.enable();
      at.registerHash('data.txt', hash);

      // اول درسته
      var report = await at.verifyAll(tempDir.path);
      expect(report.verified, true);

      // حالا tamper کنیم
      await file.writeAsString('modified content');

      report = await at.verifyAll(tempDir.path);
      expect(report.verified, false);
      expect(report.invalidFiles, 1);

      await tempDir.delete(recursive: true);
    });

    test('stats tracking', () {
      at.enable();
      at.registerHash('a.txt', 'hash1');
      at.registerHash('b.txt', 'hash2');

      final stats = at.stats;
      expect(stats['enabled'], true);
      expect(stats['registeredFiles'], 2);
    });
  });
}
