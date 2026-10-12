import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

import 'ssl_pinning_fixture_certs.dart';

/// Behavioural TLS tests for [SslPinning].
///
/// هر تست یک هندشیک TLS واقعی با یک سرور HTTPS محلی انجام می‌دهد تا رفتار
/// پین‌کردن روی اتصال‌های واقعی سنجیده شود، نه فقط نوع کلاینت برگشتی.
void main() {
  // در صورت وجود هرگونه اتصال قبلی به تست‌بایندینگ، کلاینت واقعی dart:io را
  // برای این فایل برگردان.
  HttpOverrides.global = null;

  const wrongPin =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  Future<HttpServer> startHttpsServer({
    String certPem = kPinningCertPem,
    String keyPem = kPinningKeyPem,
  }) async {
    final context = SecurityContext()
      ..useCertificateChainBytes(utf8.encode(certPem))
      ..usePrivateKeyBytes(utf8.encode(keyPem));
    final server = await HttpServer.bindSecure(
      InternetAddress.loopbackIPv4,
      0,
      context,
    );
    server.listen((request) async {
      request.response
        ..statusCode = HttpStatus.ok
        ..write('trusted but unpinned');
      await request.response.close();
    });
    return server;
  }

  Future<String> fetch(HttpClient client, int port) async {
    final request = await client.getUrl(Uri.parse('https://localhost:$port/'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    client.close(force: true);
    return body;
  }

  /// پین «درست» برای گواهی‌ای که سرور روی پورت [port] سرو می‌کند.
  ///
  /// در dart:io هیچ کارخانهٔ عمومی برای ساخت [X509Certificate] از PEM وجود
  /// ندارد؛ تنها راه رسیدن به شیء گواهی، یک هندشیک واقعی است. پس یک اتصال
  /// کوتاه با [SecureSocket] باز می‌کنیم و گواهی را از مسیر
  /// [onBadCertificate] (که برای گواهی خودامضا همیشه فراخوانی می‌شود)
  /// می‌گیریم و دقیقاً مثل تولید، hash از `der` آن می‌سازیم.
  Future<String> servedPin(int port) async {
    X509Certificate? captured;
    final socket = await SecureSocket.connect(
      'localhost',
      port,
      onBadCertificate: (cert) {
        captured ??= cert;
        return true;
      },
    );
    final cert = captured;
    expect(cert, isNotNull, reason: 'handshake must expose the certificate');
    final pin = sha256.convert(cert!.der).toString();
    await socket.close();
    return pin;
  }

  group('SslPinning over a real TLS handshake', () {
    late HttpServer server;

    tearDown(() async {
      await server.close(force: true);
    });

    test('ordinary TLS accepts the certificate when pinning stays off',
        () async {
      server = await startHttpsServer();

      // کلاینتی که گواهی را از مسیر عادی chain/hostname اعتماد می‌کند، بدون
      // هیچ پینی باید موفق شود؛ این یعنی گواهی از نظر TLS «معتبر» است.
      final trust = SecurityContext()
        ..setTrustedCertificatesBytes(utf8.encode(kPinningCertPem));
      final plain = SslPinning();
      final client = plain.createPinnedClient(context: trust);

      expect(await fetch(client, server.port), 'trusted but unpinned');
    });

    test('pinned connection succeeds with the correct pin', () async {
      server = await startHttpsServer();

      final pinning = SslPinning()
        ..enable()
        ..addPin('localhost', await servedPin(server.port));

      final body = await fetch(pinning.createPinnedClient(), server.port);
      expect(body, 'trusted but unpinned');
    });

    test('valid certificate with a wrong pin is rejected', () async {
      server = await startHttpsServer();

      // همان گواهی معتبر تست قبل؛ حالا پین نادرست باید مانع اتصال شود حتی
      // اگر گواهی از نظر زنجیره/میزبان قابل قبول باشد.
      final pinning = SslPinning()
        ..enable()
        ..addPin('localhost', wrongPin);

      await expectLater(
        fetch(pinning.createPinnedClient(), server.port),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('untrusted certificate with a wrong pin is rejected', () async {
      server = await startHttpsServer(
        certPem: kPinningOtherCertPem,
        keyPem: kPinningOtherKeyPem,
      );

      final pinning = SslPinning()
        ..enable()
        ..addPin('localhost', wrongPin);

      await expectLater(
        fetch(pinning.createPinnedClient(), server.port),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('host without a configured pin still connects', () async {
      server = await startHttpsServer();

      // پین واقعیِ گواهی سروشده، اما برای میزبانی دیگر ثبت شده است.
      final pinning = SslPinning()
        ..enable()
        ..addPin('other.example.com', await servedPin(server.port));

      final body = await fetch(pinning.createPinnedClient(), server.port);
      expect(body, 'trusted but unpinned');
    });

    test('disabled pinning keeps ordinary TLS rules', () async {
      server = await startHttpsServer();

      // کلاینت پیش‌فرض با مخزن اعتماد سیستم، گواهی خودامضای محلی را نمی‌شناسد
      // و باید دقیقاً مثل TLS معمولی اتصال را رد کند.
      final plain = SslPinning();

      await expectLater(
        fetch(plain.createPinnedClient(), server.port),
        throwsA(isA<HandshakeException>()),
      );
    });
  });
}
