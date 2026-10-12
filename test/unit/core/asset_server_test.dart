import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('AssetServerConfig', () {
    test('defaults to index.html, a 50MB limit and common web extensions', () {
      const config = AssetServerConfig();

      expect(AssetServerConfig.wwwRoot, 'assets/www');
      expect(config.indexFile, 'index.html');
      expect(config.maxFileSize, 50 * 1024 * 1024);
      expect(config.allowedExtensions, containsAll(['.html', '.js', '.css']));
      expect(config.allowedExtensions, contains('.woff2'));
    });

    test('does not allow executable or server-side extensions by default', () {
      const config = AssetServerConfig();

      expect(config.allowedExtensions, isNot(contains('.exe')));
      expect(config.allowedExtensions, isNot(contains('.php')));
      expect(config.allowedExtensions, isNot(contains('.dart')));
    });

    test('custom values override defaults', () {
      const config = AssetServerConfig(
        indexFile: 'start.html',
        allowedExtensions: {'.html'},
        maxFileSize: 1024,
      );

      expect(config.indexFile, 'start.html');
      expect(config.allowedExtensions, {'.html'});
      expect(config.maxFileSize, 1024);
    });
  });

  group('AssetServer before start', () {
    test('reports it is not running with no bound port', () {
      final server = AssetServer(config: const AssetServerConfig());

      expect(server.isRunning, false);
      expect(server.port, 0);
      expect(server.baseUrl, startsWith('http://localhost:'));
    });

    test('builds the index URL from the configured index file', () {
      final server = AssetServer(
        config: const AssetServerConfig(indexFile: 'app.html'),
      );

      expect(server.indexUrl, endsWith('/app.html'));
      expect(server.indexUrl, startsWith(server.baseUrl));
    });

    test('stop is a no-op when the server never started', () async {
      final server = AssetServer(config: const AssetServerConfig());

      await expectLater(server.stop(), completes);
      expect(server.isRunning, false);
    });
  });
}
