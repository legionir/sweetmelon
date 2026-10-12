import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('BinaryProtocol', () {
    test('encodes and decodes message', () {
      final original = {
        'plugin': 'storage',
        'method': 'get',
        'args': {'key': 'test'},
      };

      final encoded = BinaryProtocol.encodeMessage(original);
      expect(encoded.length, greaterThan(BinaryProtocol.headerSize));

      final decoded = BinaryProtocol.decodeMessage(encoded);
      expect(decoded, isNotNull);
      expect(decoded!['plugin'], 'storage');
      expect(decoded['method'], 'get');
    });

    test('magic bytes are correct', () {
      final encoded = BinaryProtocol.encodeMessage({'test': 1});
      expect(encoded[0], 0x53); // S
      expect(encoded[1], 0x57); // W
      expect(encoded[2], 0x4D); // M
      expect(encoded[3], 0x4C); // L
    });

    test('rejects invalid magic', () {
      final bad =
          Uint8List.fromList([0x00, 0x00, 0x00, 0x00, ...List.filled(12, 0)]);
      final result = BinaryProtocol.decode(bad);
      expect(result, isNull);
    });

    test('rejects too small data', () {
      final tiny = Uint8List.fromList([0x01, 0x02]);
      final result = BinaryProtocol.decode(tiny);
      expect(result, isNull);
    });

    test('base64 roundtrip', () {
      final message = {'plugin': 'test', 'method': 'run', 'data': 12345};
      final b64 = BinaryProtocol.encodeToBase64(message);
      expect(b64, isNotEmpty);

      final decoded = BinaryProtocol.decodeFromBase64(b64);
      expect(decoded, isNotNull);
      expect(decoded!['plugin'], 'test');
      expect(decoded['data'], 12345);
    });

    test('encodes text type', () {
      final packet = BinaryProtocol.encodeText('hello world');
      final decoded = BinaryProtocol.decode(packet);
      expect(decoded, isNotNull);
      expect(decoded!.type, BinaryProtocol.typeText);
    });

    test('encodes binary type', () {
      final data = Uint8List.fromList([1, 2, 3, 4, 5]);
      final packet = BinaryProtocol.encodeBinary(data);
      final decoded = BinaryProtocol.decode(packet);
      expect(decoded, isNotNull);
      expect(decoded!.type, BinaryProtocol.typeBinary);
    });

    test('payload length is correct', () {
      final message = {'key': 'value'};
      final json = jsonEncode(message);
      final encoded = BinaryProtocol.encodeMessage(message);
      expect(
        encoded.length,
        BinaryProtocol.headerSize + utf8.encode(json).length,
      );
    });

    test('jsBinaryCode is not empty', () {
      expect(BinaryProtocol.jsBinaryCode, isNotEmpty);
    });
  });
}
