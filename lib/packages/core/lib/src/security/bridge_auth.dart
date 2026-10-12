import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../utils/logger.dart';

/// سیستم احراز هویت Bridge
/// فقط JS هایی که token معتبر دارن می‌تونن با bridge ارتباط بگیرن
class BridgeAuth {
  String? _sessionToken;
  String? _secretKey;
  DateTime? _sessionStart;
  final Duration sessionTimeout;
  final Set<String> _revokedTokens = {};
  int _messageCounter = 0;

  BridgeAuth({
    this.sessionTimeout = const Duration(hours: 24),
  });

  /// ساخت session جدید — وقتی WebView لود می‌شه صدا زده بشه
  String createSession() {
    _secretKey = _generateRandomKey(32);
    _sessionToken = _generateSessionToken(_secretKey!);
    _sessionStart = DateTime.now();
    _messageCounter = 0;

    BridgeLogger.info('BridgeAuth', 'New session created');

    return _sessionToken!;
  }

  /// اعتبارسنجی token
  bool validateToken(String? token) {
    if (token == null || token.isEmpty) {
      BridgeLogger.warn('BridgeAuth', 'Empty token rejected');
      return false;
    }

    if (_sessionToken == null) {
      BridgeLogger.warn('BridgeAuth', 'No active session');
      return false;
    }

    if (_revokedTokens.contains(token)) {
      BridgeLogger.warn('BridgeAuth', 'Revoked token rejected');
      return false;
    }

    if (_isSessionExpired()) {
      BridgeLogger.warn('BridgeAuth', 'Session expired');
      return false;
    }

    if (token != _sessionToken) {
      BridgeLogger.warn('BridgeAuth', 'Invalid token');
      return false;
    }

    _messageCounter++;
    return true;
  }

  /// اعتبارسنجی signed message
  bool validateSignedMessage(
    Map<String, dynamic> message,
    String? signature,
  ) {
    if (_secretKey == null || signature == null) return false;

    final expectedSig = signMessage(message, _secretKey!);
    return signature == expectedSig;
  }

  /// امضای یک پیام
  static String signMessage(Map<String, dynamic> message, String secret) {
    final payload = _canonicalizeMessage(message);
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString();
  }

  /// باطل کردن session
  void revokeSession() {
    if (_sessionToken != null) {
      _revokedTokens.add(_sessionToken!);
    }
    _sessionToken = null;
    _secretKey = null;
    _sessionStart = null;
    BridgeLogger.info('BridgeAuth', 'Session revoked');
  }

  /// تمدید session
  void refreshSession() {
    _sessionStart = DateTime.now();
  }

  bool _isSessionExpired() {
    if (_sessionStart == null) return true;
    return DateTime.now().difference(_sessionStart!) > sessionTimeout;
  }

  String _generateSessionToken(String secret) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = _generateRandomKey(16);
    final payload = '$timestamp:$random:$secret';

    final bytes = utf8.encode(payload);
    final hash = sha256.convert(bytes);

    return hash.toString();
  }

  String _generateRandomKey(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  static String _canonicalizeMessage(Map<String, dynamic> message) {
    final sorted = Map.fromEntries(
      message.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return jsonEncode(sorted);
  }

  /// آمار
  Map<String, dynamic> get stats => {
        'hasSession': _sessionToken != null,
        'sessionAge': _sessionStart != null
            ? DateTime.now().difference(_sessionStart!).inSeconds
            : null,
        'messageCount': _messageCounter,
        'revokedTokens': _revokedTokens.length,
        'expired': _isSessionExpired(),
      };

  /// Secret key برای inject در JS
  String? get secretKey => _secretKey;

  /// Token فعلی
  String? get currentToken => _sessionToken;
}
