import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('PluginRequest', () {
    test('create generates valid request', () {
      final request = PluginRequest.create(
        plugin: 'storage',
        method: 'get',
        args: {'key': 'test'},
      );

      expect(request.plugin, 'storage');
      expect(request.method, 'get');
      expect(request.args['key'], 'test');
      expect(request.requestId, isNotEmpty);
      expect(request.version, '1.0.0');
    });

    test('fromJson parses correctly', () {
      final json = {
        'requestId': 'req_123',
        'plugin': 'camera',
        'method': 'takePhoto',
        'args': {'quality': 80},
        'version': '2.0.0',
        'timestamp': '2024-01-15T10:30:00.000Z',
      };

      final request = PluginRequest.fromJson(json);

      expect(request.requestId, 'req_123');
      expect(request.plugin, 'camera');
      expect(request.method, 'takePhoto');
      expect(request.args['quality'], 80);
      expect(request.version, '2.0.0');
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'plugin': 'test',
        'method': 'run',
      };

      final request = PluginRequest.fromJson(json);

      expect(request.plugin, 'test');
      expect(request.method, 'run');
      expect(request.version, '1.0.0');
      expect(request.args, isEmpty);
      expect(request.requestId, isNotEmpty);
    });

    test('toJson roundtrip', () {
      final original = PluginRequest.create(
        plugin: 'storage',
        method: 'set',
        args: {'key': 'x', 'value': 123},
      );

      final json = original.toJson();
      final parsed = PluginRequest.fromJson(json);

      expect(parsed.plugin, original.plugin);
      expect(parsed.method, original.method);
      expect(parsed.args['key'], original.args['key']);
      expect(parsed.args['value'], original.args['value']);
    });
  });

  group('PluginResponse', () {
    test('success factory', () {
      final response = PluginResponse.success(
        requestId: 'req_1',
        data: {'result': 42},
      );

      expect(response.success, true);
      expect(response.data['result'], 42);
      expect(response.error, isNull);
    });

    test('failure factory', () {
      final response = PluginResponse.failure(
        requestId: 'req_1',
        error: const PluginError(
          code: PluginErrorCode.pluginNotFound,
          message: 'Not found',
        ),
      );

      expect(response.success, false);
      expect(response.error, isNotNull);
      expect(response.error!.code, PluginErrorCode.pluginNotFound);
      expect(response.error!.message, 'Not found');
    });

    test('toJson/fromJson roundtrip', () {
      final original = PluginResponse.success(
        requestId: 'req_1',
        data: {
          'items': [1, 2, 3]
        },
        metadata: const ResponseMetadata(
          processingTimeMs: 42,
          pluginVersion: '1.0.0',
          fromCache: false,
        ),
      );

      final json = original.toJson();
      final parsed = PluginResponse.fromJson(json);

      expect(parsed.success, true);
      expect(parsed.requestId, 'req_1');
      expect(parsed.metadata.processingTimeMs, 42);
    });
  });

  group('PluginError', () {
    test('fromString maps known codes', () {
      expect(
        PluginErrorCode.fromString('PERMISSION_DENIED'),
        PluginErrorCode.permissionDenied,
      );
      expect(
        PluginErrorCode.fromString('TIMEOUT'),
        PluginErrorCode.timeout,
      );
      expect(
        PluginErrorCode.fromString('UNKNOWN_CODE'),
        PluginErrorCode.unknown,
      );
    });
  });

  group('BatchOptions', () {
    test('defaults are correct', () {
      final options = BatchOptions.defaults();

      expect(options.parallel, true);
      expect(options.stopOnError, false);
      expect(options.timeoutMs, isNull);
    });
  });
}
