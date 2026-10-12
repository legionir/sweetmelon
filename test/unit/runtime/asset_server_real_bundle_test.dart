import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

/// راه‌اندازی [AssetServer] روی bundle واقعی ساخته‌شده توسط تولچین فعلی.
///
/// این تست‌ها کانال `flutter/assets` را به هیچ وجه جایگزین نمی‌کنند؛ بنابراین
/// مانیفست و فایل‌ها دقیقاً از همان چیزی خوانده می‌شوند که `flutter test`
/// می‌سازد (در نسخه‌های جدید: AssetManifest.bin). اگر پیاده‌سازی دوباره به
/// خواندن مستقیم `AssetManifest.json` برگردد، این فایل با خطای
/// «Unable to load asset» شکست می‌خورد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_test کلاینت HTTP را با stub پاسخ 400 جایگزین می‌کند؛ کلاینت
  // واقعی را برای گفت‌وگو با سرور محلی برمی‌گردانیم.
  HttpOverrides.global = null;

  AssetServer? server;
  Directory? tempRoot;

  setUp(() {
    tempRoot =
        Directory.systemTemp.createTempSync('asset_server_real_bundle_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => tempRoot!.path,
    );
  });

  tearDown(() async {
    await server?.stop();
    server = null;
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

  Future<String> fetchBody(AssetServer target, String path) async {
    final client = HttpClient();
    final request = await client.getUrl(
      Uri.parse('http://localhost:${target.port}$path'),
    );
    final response = await request.close();
    expect(response.statusCode, HttpStatus.ok);
    final body = await response.transform(utf8.decoder).join();
    client.close(force: true);
    return body;
  }

  Future<List<String>> extractedTree(Directory dir) async {
    if (!dir.existsSync()) {
      return <String>['<missing dir: ${dir.path}>'];
    }
    final paths = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        paths.add(entity.path.substring(dir.path.length + 1));
      }
    }
    paths.sort();
    return paths;
  }

  test('starts from the real toolchain bundle and serves bundled assets',
      () async {
    // عیب‌یابی چندمرحله‌ای: اول وضعیت خود bundle واقعی ثبت می‌شود تا اگر
    // چیزی در محیط تست خراب بود، دلیل شکست دقیقاً همان مرحله را نشان بدهد.
    final manifestKeys =
        (await AssetManifest.loadFromAssetBundle(rootBundle)).listAssets();

    String nestedProbe;
    try {
      final data = await rootBundle.load('assets/www/css/styles.css');
      nestedProbe = 'ok(${data.lengthInBytes}b)';
    } catch (e) {
      nestedProbe = 'FAILED: $e';
    }

    final started = AssetServer(config: const AssetServerConfig());
    server = started;

    // هیچ JSON ساختگی در کار نیست؛ شروع باید از مانیفست واقعی موفق شود.
    final indexUrl = await started.start();
    expect(indexUrl, started.indexUrl);
    expect(started.isRunning, true);
    expect(started.port, greaterThan(0));

    final tempDir = await getTemporaryDirectory();
    final wwwDir = Directory('${tempDir.path}/www_server');
    final tree = await extractedTree(wwwDir);
    final diag = 'manifest=${manifestKeys.join(',')} | '
        'nestedLoad=$nestedProbe | '
        'extracted=${tree.join(',')}';

    // مرحله ۱: مانیفست واقعی باید کلیدهای تودرتو را داشته باشد.
    expect(
      manifestKeys.join(','),
      contains('assets/www/css/styles.css'),
      reason: diag,
    );

    // مرحله ۲: بارگذاری مستقیم یک کلید تودرتو از کانال واقعی.
    expect(nestedProbe, startsWith('ok('), reason: diag);

    // مرحله ۳: استخراج باید فایل تودرتو را روی دیسک نوشته باشد.
    expect(tree, contains('css/styles.css'), reason: diag);

    // index برنامه با محتوای واقعی فایل مخزن سرو می‌شود.
    final expectedIndex = await File('assets/www/index.html').readAsString();
    expect(
      await fetchBody(started, '/index.html'),
      expectedIndex,
      reason: diag,
    );
    expect(await fetchBody(started, '/'), expectedIndex, reason: diag);

    // assetهای تودرتو نیز استخراج و سرو می‌شوند.
    final expectedCss = await File('assets/www/css/styles.css').readAsString();
    final cssBody = await fetchBody(started, '/css/styles.css');
    expect(cssBody, expectedCss, reason: '$diag | servedLen=${cssBody.length}');

    final expectedJs = await File('assets/www/js/app.js').readAsString();
    expect(
      await fetchBody(started, '/js/app.js'),
      expectedJs,
      reason: diag,
    );

    // filtering پسوند حفظ شده است: .d.ts در فهرست مجاز نیست.
    expect(File('${wwwDir.path}/js/native-sdk.d.ts').existsSync(), false);
  });
}
