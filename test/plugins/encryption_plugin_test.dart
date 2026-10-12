import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/encryption/lib/encryption_plugin.dart';

void main() {
  group('EncryptionPlugin', () {
    late EncryptionPlugin plugin;

    setUp(() async {
      plugin = EncryptionPlugin();
      await plugin.initialize();
    });

    test('generateAesKey returns key and iv', () async {
      final result = await plugin.onCall('generateAesKey', {'bits': 256});

      expect(result['key'], isNotEmpty);
      expect(result['iv'], isNotEmpty);
      expect(result['bits'], 256);
    });

    test('aesEncrypt and aesDecrypt roundtrip', () async {
      final keyResult = await plugin.onCall('generateAesKey', {'bits': 256});
      final key = keyResult['key'] as String;
      final iv = keyResult['iv'] as String;

      final encrypted = await plugin.onCall('aesEncrypt', {
        'data': 'Hello World',
        'key': key,
        'iv': iv,
      });

      expect(encrypted['encrypted'], isNotEmpty);

      final decrypted = await plugin.onCall('aesDecrypt', {
        'data': encrypted['encrypted'],
        'key': key,
        'iv': iv,
      });

      expect(decrypted['decrypted'], 'Hello World');
    });

    test('hashSha256 produces consistent hash', () async {
      final r1 = await plugin.onCall('hashSha256', {'data': 'test'});
      final r2 = await plugin.onCall('hashSha256', {'data': 'test'});

      expect(r1['hash'], r2['hash']);
      expect(r1['hash'], isNotEmpty);
    });

    test('different inputs produce different hashes', () async {
      final r1 = await plugin.onCall('hashSha256', {'data': 'hello'});
      final r2 = await plugin.onCall('hashSha256', {'data': 'world'});

      expect(r1['hash'], isNot(r2['hash']));
    });

    test('hmacSha256 works', () async {
      final result = await plugin.onCall('hmacSha256', {
        'data': 'message',
        'key': 'secret',
      });

      expect(result['hmac'], isNotEmpty);
      expect(result['algorithm'], 'HMAC-SHA256');
    });

    test('base64 encode/decode roundtrip', () async {
      final encoded = await plugin.onCall('base64Encode', {'data': 'Hello!'});
      final decoded = await plugin.onCall('base64Decode', {
        'data': encoded['encoded'],
      });

      expect(decoded['decoded'], 'Hello!');
    });

    test('generateRandomBytes returns correct length', () async {
      final result = await plugin.onCall('generateRandomBytes', {'length': 16});

      expect(result['length'], 16);
      expect(result['hex'], hasLength(32)); // 16 bytes = 32 hex chars
    });

    test('validation rejects missing data', () async {
      final result = await plugin.validateArgs('hashSha256', {});
      expect(result.isValid, false);
    });

    test('validation accepts valid args', () async {
      final result = await plugin.validateArgs('hashSha256', {'data': 'test'});
      expect(result.isValid, true);
    });
  });
}
