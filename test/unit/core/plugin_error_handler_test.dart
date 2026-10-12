import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('PluginErrorHandler', () {
    test('converts UnsupportedError', () {
      final error = PluginErrorHandler.fromException(
        UnsupportedError('not supported'),
      );
      expect(error.code, PluginErrorCode.methodNotFound);
    });

    test('converts StateError', () {
      final error = PluginErrorHandler.fromException(
        StateError('bad state'),
      );
      expect(error.code, PluginErrorCode.executionError);
    });

    test('converts FormatException', () {
      final error = PluginErrorHandler.fromException(
        const FormatException('bad format'),
      );
      expect(error.code, PluginErrorCode.invalidArgs);
    });

    test('converts PluginException', () {
      final error = PluginErrorHandler.fromException(
        const PluginException(
          code: PluginErrorCode.permissionDenied,
          message: 'no camera',
        ),
      );
      expect(error.code, PluginErrorCode.permissionDenied);
      expect(error.message, 'no camera');
    });

    test('detects network errors', () {
      final error = PluginErrorHandler.fromException(
        Exception('SocketException: Connection refused'),
      );
      expect(error.code, PluginErrorCode.networkError);
    });

    test('detects permission errors', () {
      final error = PluginErrorHandler.fromException(
        Exception('Permission denied for camera'),
      );
      expect(error.code, PluginErrorCode.permissionDenied);
    });

    test('falls back to executionError', () {
      final error = PluginErrorHandler.fromException(
        Exception('something random'),
      );
      expect(error.code, PluginErrorCode.executionError);
    });

    test('errorResponse creates PluginResponse', () {
      final response = PluginErrorHandler.errorResponse(
        'req_1',
        Exception('test error'),
      );
      expect(response.success, false);
      expect(response.requestId, 'req_1');
      expect(response.error, isNotNull);
    });
  });

  group('PluginException', () {
    test('notFound factory', () {
      const e = PluginException.notFound('plugin X');
      expect(e.code, PluginErrorCode.pluginNotFound);
      expect(e.message, contains('plugin X'));
    });

    test('invalidArgs factory', () {
      const e = PluginException.invalidArgs('key is required');
      expect(e.code, PluginErrorCode.invalidArgs);
    });

    test('permissionDenied factory', () {
      const e = PluginException.permissionDenied('camera');
      expect(e.code, PluginErrorCode.permissionDenied);
    });

    test('noContext factory', () {
      const e = PluginException.noContext();
      expect(e.code, PluginErrorCode.executionError);
    });

    test('toString includes code and message', () {
      const e = PluginException(
        code: PluginErrorCode.timeout,
        message: 'took too long',
      );
      expect(e.toString(), contains('TIMEOUT'));
      expect(e.toString(), contains('took too long'));
    });
  });
}
