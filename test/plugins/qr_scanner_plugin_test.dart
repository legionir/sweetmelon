import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/qr_scanner/lib/qr_scanner_plugin.dart';

void main() {
  group('QrScannerPlugin', () {
    test('describes itself and its camera requirement', () {
      final plugin = QrScannerPlugin();

      expect(plugin.name, 'qrScanner');
      expect(plugin.version, '1.0.0');
      expect(plugin.description, contains('QR'));
      expect(plugin.requiredPermissions, ['camera']);
      expect(plugin.supportedMethods, ['scan', 'getInfo']);
      expect(plugin.supportsMethod('scan'), true);
      expect(plugin.supportsMethod('encode'), false);
    });

    test('getInfo lists the supported barcode formats', () async {
      final plugin = QrScannerPlugin();

      final info = await plugin.onCall('getInfo', {}) as Map<String, dynamic>;

      expect(info['name'], 'qrScanner');
      expect(info['version'], '1.0.0');
      final formats = info['supportedFormats'] as List<dynamic>;
      expect(formats, containsAll(['qr', 'ean13', 'code128', 'aztec']));
      expect(formats.length, 13);
    });

    test('unknown methods throw UnsupportedError', () async {
      final plugin = QrScannerPlugin();

      await expectLater(
        plugin.onCall('encode', {}),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('accepts an event emitter and a navigator key is optional', () {
      final emitted = <String>[];
      final plugin = QrScannerPlugin(
        eventEmitter: (event, data) async => emitted.add(event),
      );

      expect(plugin.eventEmitter, isNotNull);
      expect(QrScannerPlugin.navigatorKey, isNull);
      expect(emitted, isEmpty);
    });
  });
}
