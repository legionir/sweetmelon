import 'dart:io';

import 'package:crypto/crypto.dart';

import '../utils/logger.dart';

/// SSL Certificate Pinning manager
class SslPinning {
  final Map<String, Set<String>> _pins = {};
  bool _enabled = false;

  /// فعال کردن pinning
  void enable() {
    _enabled = true;
    BridgeLogger.info('SslPinning', 'SSL pinning enabled');
  }

  /// غیرفعال کردن pinning
  void disable() {
    _enabled = false;
    BridgeLogger.info('SslPinning', 'SSL pinning disabled');
  }

  /// اضافه کردن pin برای یک domain
  /// pin باید SHA-256 hash از public key باشه
  void addPin(String domain, String sha256Pin) {
    _pins.putIfAbsent(domain, () => {});
    _pins[domain]!.add(sha256Pin.toLowerCase());

    BridgeLogger.debug(
      'SslPinning',
      'Pin added for $domain: ${sha256Pin.substring(0, 16)}...',
    );
  }

  /// اضافه کردن چندین pin
  void addPins(String domain, List<String> pins) {
    for (final pin in pins) {
      addPin(domain, pin);
    }
  }

  /// حذف pin
  void removePin(String domain) {
    _pins.remove(domain);
  }

  /// ساخت HttpClient با SSL pinning
  ///
  /// وقتی pinning فعال است، پین «مرجع نهایی اعتماد» برای میزبان‌های pin‌شده
  /// است. کلاینت با یک [SecurityContext] ایزوله (بدون ریشه‌های اعتماد پیش‌فرض)
  /// ساخته می‌شود تا هر گواهی‌ای —حتی گواهی معتبری که یک مرجع صدور آن را
  /// تأیید می‌کند— ناگزیر از مسیر [badCertificateCallback] و بررسی پین عبور
  /// کند. بدون این کار، گواهی‌های مورداعتماد هرگز به callback نمی‌رسیدند و
  /// پین به‌طور کامل دور زده می‌شد (نقص امنیتی). [context] فقط در حالت
  /// غیرفعال/بدون پین کاربرد دارد؛ در حالت فعال عمداً نادیده گرفته می‌شود تا
  /// اعتمادِ از پیش تعریف‌شده نتواند پین را دور بزند.
  HttpClient createPinnedClient({SecurityContext? context}) {
    if (!_enabled || _pins.isEmpty) {
      return context == null ? HttpClient() : HttpClient(context: context);
    }

    final client = HttpClient(context: SecurityContext());

    client.badCertificateCallback = (cert, host, port) {
      return _validateCertificate(cert, host);
    };

    return client;
  }

  /// اعتبارسنجی certificate
  bool _validateCertificate(X509Certificate cert, String host) {
    if (!_enabled) return true;

    final domainPins = _findPinsForHost(host);
    if (domainPins == null || domainPins.isEmpty) {
      // اگه pin تعریف نشده، اجازه بده
      return true;
    }

    // محاسبه hash از certificate
    final certHash = _hashCertificate(cert);

    final isValid = domainPins.contains(certHash);

    if (!isValid) {
      BridgeLogger.error(
        'SslPinning',
        'Certificate pin validation failed for $host. '
            'Expected: ${domainPins.first.substring(0, 16)}..., '
            'Got: ${certHash.substring(0, 16)}...',
      );
    }

    return isValid;
  }

  Set<String>? _findPinsForHost(String host) {
    // exact match
    if (_pins.containsKey(host)) {
      return _pins[host];
    }

    // wildcard match
    for (final entry in _pins.entries) {
      if (entry.key.startsWith('*.')) {
        final domain = entry.key.substring(2);
        if (host.endsWith(domain)) {
          return entry.value;
        }
      }
    }

    return null;
  }

  String _hashCertificate(X509Certificate cert) {
    final der = cert.der;
    final digest = sha256.convert(der);
    return digest.toString().toLowerCase();
  }

  /// آمار
  Map<String, dynamic> get stats => {
        'enabled': _enabled,
        'pinnedDomains': _pins.keys.toList(),
        'totalPins': _pins.values.fold<int>(
          0,
          (sum, pins) => sum + pins.length,
        ),
      };
}
