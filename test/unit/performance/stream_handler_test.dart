import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('StreamHandler', () {
    late List<String> jsCommands;
    late StreamHandler handler;

    setUp(() {
      jsCommands = [];
      handler = StreamHandler(
        jsRunner: (js) async => jsCommands.add(js),
      );
    });

    test('sends start, chunks, end for large data', () async {
      final data = List<int>.generate(200 * 1024, (i) => i % 256);
      await handler.sendLargeData('stream1', data, chunkSize: 64 * 1024);

      expect(jsCommands.any((c) => c.contains('__streamStart')), true);
      expect(jsCommands.any((c) => c.contains('__streamChunk')), true);
      expect(jsCommands.any((c) => c.contains('__streamEnd')), true);
    });

    test('sends 4 chunks for 256KB with 64KB chunk', () async {
      final data = List<int>.generate(256 * 1024, (i) => i % 256);
      await handler.sendLargeData('stream2', data, chunkSize: 64 * 1024);

      final chunkCalls =
          jsCommands.where((c) => c.contains('__streamChunk')).length;
      expect(chunkCalls, 4);
    });

    test('cancel stream', () async {
      await handler.cancelStream('stream3');
      expect(
        jsCommands.any((c) => c.contains('__streamCancel')),
        true,
      );
    });

    test('sends text as UTF8', () async {
      const text = 'Hello World من یک متن فارسی هستم';
      final bytes = utf8.encode(text);
      await handler.sendLargeText(
        'text_stream',
        text,
        chunkSize: bytes.length + 100,
      );

      expect(jsCommands.any((c) => c.contains('__streamStart')), true);
      expect(jsCommands.any((c) => c.contains('__streamEnd')), true);
    });

    test('jsBinaryCode is not empty', () {
      expect(StreamHandler.jsStreamingCode, isNotEmpty);
      expect(StreamHandler.jsStreamingCode, contains('__streamStart'));
      expect(StreamHandler.jsStreamingCode, contains('__streamEnd'));
    });
  });
}
