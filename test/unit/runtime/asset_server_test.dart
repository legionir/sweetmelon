import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

class _Reply {
  _Reply(this.status, this.body, this.mimeType);

  final int status;
  final String body;
  final String? mimeType;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The test binding stubs HttpClient with a client that answers 400 to every
  // request; restore the real one so the tests can reach the local server.
  HttpOverrides.global = null;

  const manifest = <String, dynamic>{
    'assets/www/': <String>['assets/www/'],
    'assets/www/index.html': <String>['assets/www/index.html'],
    'assets/www/app.js': <String>['assets/www/app.js'],
    'assets/www/style.css': <String>['assets/www/style.css'],
    'assets/www/data.map': <String>['assets/www/data.map'],
    'assets/www/blob.unknownext': <String>['assets/www/blob.unknownext'],
    'assets/www/blocked.exe': <String>['assets/www/blocked.exe'],
    'assets/other/notes.txt': <String>['assets/other/notes.txt'],
  };

  const assetBodies = <String, String>{
    'assets/www/index.html': '<html><body>INDEX</body></html>',
    'assets/www/app.js': 'console.log("app");',
    'assets/www/style.css': 'body { margin: 0; }',
    'assets/www/data.map': '{"version":3}',
    'assets/www/blob.unknownext': 'raw-bytes',
    'assets/www/blocked.exe': 'should never be extracted',
    'assets/other/notes.txt': 'outside the www root',
  };

  AssetServer? server;
  Directory? tempRoot;

  setUp(() {
    // path_provider has no platform implementation under `flutter test`, so
    // route its method channel to a fresh per-test directory.
    tempRoot = Directory.systemTemp.createTempSync('asset_server_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempRoot!.path,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(
        message!.buffer.asUint8List(
          message.offsetInBytes,
          message.lengthInBytes,
        ),
      );
      if (key == 'AssetManifest.bin') {
        // همان کلیدهای نسخهٔ JSON قدیمی، اما در قالب باینری
        // StandardMessageCodec که AssetManifest.loadFromAssetBundle می‌خواند؛
        // عمداً هیچ پاسخی برای AssetManifest.json وجود ندارد تا بازگشت به
        // وابستگی قدیمی فوراً شکست بخورد.
        final binManifest = <String, List<Object>>{
          for (final assetKey in manifest.keys) assetKey: const <Object>[],
        };
        return const StandardMessageCodec().encodeMessage(binManifest);
      }
      final body = assetBodies[key];
      if (body == null) return null;
      return ByteData.sublistView(Uint8List.fromList(utf8.encode(body)));
    });
  });

  tearDown(() async {
    await server?.stop();
    server = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      null,
    );
    if (tempRoot != null && tempRoot!.existsSync()) {
      tempRoot!.deleteSync(recursive: true);
    }
    tempRoot = null;
  });

  Future<AssetServer> startServer({AssetServerConfig? config}) async {
    final started = AssetServer(config: config ?? const AssetServerConfig());
    server = started;
    final indexUrl = await started.start();
    expect(indexUrl, started.indexUrl);
    return started;
  }

  Future<_Reply> send(
    AssetServer target,
    String path, {
    String method = 'GET',
  }) async {
    final client = HttpClient();
    final request = await client.openUrl(
      method,
      Uri.parse('http://localhost:${target.port}$path'),
    );
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final mimeType = response.headers.contentType?.mimeType;
    client.close(force: true);
    return _Reply(response.statusCode, body, mimeType);
  }

  /// Sends the path over a raw socket so the HTTP client cannot normalize it.
  Future<int> sendRaw(AssetServer target, String rawPath) async {
    final socket = await Socket.connect(
      InternetAddress.loopbackIPv4,
      target.port,
    );
    socket.write(
      'GET $rawPath HTTP/1.1\r\n'
      'Host: localhost:${target.port}\r\n'
      'Connection: close\r\n'
      '\r\n',
    );
    await socket.flush();
    final response = await utf8.decodeStream(socket);
    socket.destroy();
    return int.parse(response.split('\r\n').first.split(' ')[1]);
  }

  test('start extracts allowed assets and serves the index', () async {
    final running = await startServer();

    expect(running.isRunning, true);
    expect(running.port, greaterThan(0));
    expect(running.baseUrl, 'http://localhost:${running.port}');
    expect(running.indexUrl, 'http://localhost:${running.port}/index.html');

    // A second start while running is a no-op.
    expect(await running.start(), running.indexUrl);

    final index = await send(running, '/');
    expect(index.status, HttpStatus.ok);
    expect(index.body, '<html><body>INDEX</body></html>');
    expect(index.mimeType, 'text/html');

    final tempDir = await getTemporaryDirectory();
    final wwwDir = Directory('${tempDir.path}/www_server');
    expect(File('${wwwDir.path}/index.html').existsSync(), true);
    expect(File('${wwwDir.path}/app.js').existsSync(), true);
    // Disallowed extension and files outside assets/www are not extracted.
    expect(File('${wwwDir.path}/blocked.exe').existsSync(), false);
    expect(File('${wwwDir.path}/notes.txt').existsSync(), false);
  });

  test('serves scripts, styles and known mime types', () async {
    final running = await startServer();

    final js = await send(running, '/app.js');
    expect(js.status, HttpStatus.ok);
    expect(js.body, 'console.log("app");');
    expect(
      js.mimeType,
      anyOf('text/javascript', 'application/javascript'),
    );

    final css = await send(running, '/style.css');
    expect(css.status, HttpStatus.ok);
    expect(css.body, 'body { margin: 0; }');
    expect(css.mimeType, 'text/css');

    final map = await send(running, '/data.map');
    expect(map.status, HttpStatus.ok);
    expect(map.body, '{"version":3}');
  });

  test('falls back to the default mime for unknown extensions', () async {
    // Allow the otherwise-blocked extension so the file is extracted and the
    // mime lookup hits the switch default instead of the SPA fallback.
    final running = await startServer(
      config: const AssetServerConfig(
        allowedExtensions: {'.unknownext'},
      ),
    );

    final blob = await send(running, '/blob.unknownext');
    expect(blob.status, HttpStatus.ok);
    expect(blob.body, 'raw-bytes');
    expect(blob.mimeType, 'application/octet-stream');
  });

  test('missing files fall back to the SPA index', () async {
    final running = await startServer();

    final fallback = await send(running, '/some/client/route');
    expect(fallback.status, HttpStatus.ok);
    expect(fallback.body, '<html><body>INDEX</body></html>');
    expect(fallback.mimeType, 'text/html');
  });

  test('blocks path traversal attempts', () async {
    final running = await startServer();

    // %2f stays percent-encoded through Uri.parse, so the '..' sequences
    // survive inside one path segment until the server decodes them.
    final traversal = await sendRaw(running, '/..%2f..%2fetc/passwd');
    expect(traversal, HttpStatus.forbidden);

    final tilde = await sendRaw(running, '/~root/secrets');
    expect(tilde, HttpStatus.forbidden);
  });

  test('handles OPTIONS and rejects other methods', () async {
    final running = await startServer();

    final options = await send(running, '/', method: 'OPTIONS');
    expect(options.status, HttpStatus.ok);

    final post = await send(running, '/', method: 'POST');
    expect(post.status, HttpStatus.methodNotAllowed);
  });

  test('HEAD returns headers without a body', () async {
    final running = await startServer();

    final head = await send(running, '/index.html', method: 'HEAD');
    expect(head.status, HttpStatus.ok);
    expect(head.body, isEmpty);
  });

  test('rejects files above the configured size limit', () async {
    final running = await startServer(
      config: const AssetServerConfig(maxFileSize: 8),
    );

    final tooLarge = await send(running, '/app.js');
    expect(tooLarge.status, HttpStatus.requestEntityTooLarge);
  });

  test('stop shuts the server down and cleans up extracted files', () async {
    final running = await startServer();

    final tempDir = await getTemporaryDirectory();
    final wwwDir = Directory('${tempDir.path}/www_server');
    expect(wwwDir.existsSync(), true);

    await running.stop();

    expect(running.isRunning, false);
    expect(running.port, 0);
    expect(wwwDir.existsSync(), false);

    // A second stop is a silent no-op.
    await running.stop();
  });
}
