import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../utils/logger.dart';

/// نوع سطح امنیت
enum SecurityLevel {
  /// بدون اعتبارسنجی
  none,

  /// فقط token
  tokenOnly,

  /// token + signature
  signed,

  /// token + signature + timestamp + nonce
  strict,
}

class MessageSigner {
  final SecurityLevel level;
  final Duration maxMessageAge;
  final Set<String> _usedNonces = {};
  final int _maxNonceHistory;

  MessageSigner({
    this.level = SecurityLevel.tokenOnly,
    this.maxMessageAge = const Duration(seconds: 30),
    int maxNonceHistory = 10000,
  }) : _maxNonceHistory = maxNonceHistory;

  /// اعتبارسنجی یک پیام ورودی
  ValidationResult validate(
    Map<String, dynamic> message,
    String? token,
    String? signature,
    String secretKey,
    String expectedToken,
  ) {
    if (level == SecurityLevel.none) {
      return const ValidationResult(valid: true);
    }

    // بررسی token
    if (token != expectedToken) {
      return const ValidationResult(
        valid: false,
        reason: 'invalid_token',
      );
    }

    if (level == SecurityLevel.tokenOnly) {
      return const ValidationResult(valid: true);
    }

    // بررسی signature
    if (signature == null || signature.isEmpty) {
      return const ValidationResult(
        valid: false,
        reason: 'missing_signature',
      );
    }

    final expectedSig = _computeSignature(message, secretKey);
    if (signature != expectedSig) {
      BridgeLogger.warn('MessageSigner', 'Signature mismatch');
      return const ValidationResult(
        valid: false,
        reason: 'invalid_signature',
      );
    }

    if (level == SecurityLevel.strict) {
      // بررسی timestamp
      final timestamp = message['_ts'] as int?;
      if (timestamp == null) {
        return const ValidationResult(
          valid: false,
          reason: 'missing_timestamp',
        );
      }

      final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(messageTime);

      if (age > maxMessageAge || age.isNegative) {
        return const ValidationResult(
          valid: false,
          reason: 'message_expired',
        );
      }

      // بررسی nonce (جلوگیری از replay)
      final nonce = message['_nonce'] as String?;
      if (nonce == null) {
        return const ValidationResult(
          valid: false,
          reason: 'missing_nonce',
        );
      }

      if (_usedNonces.contains(nonce)) {
        BridgeLogger.warn('MessageSigner', 'Replay attack detected: $nonce');
        return const ValidationResult(
          valid: false,
          reason: 'replay_detected',
        );
      }

      _usedNonces.add(nonce);

      // cleanup old nonces
      if (_usedNonces.length > _maxNonceHistory) {
        final toRemove = _usedNonces.length - _maxNonceHistory;
        _usedNonces.removeAll(
          _usedNonces.take(toRemove).toList(),
        );
      }
    }

    return const ValidationResult(valid: true);
  }

  /// تولید signature برای response
  String signResponse(Map<String, dynamic> response, String secretKey) {
    return _computeSignature(response, secretKey);
  }

  String _computeSignature(
    Map<String, dynamic> message,
    String secretKey,
  ) {
    // حذف فیلدهای امنیتی قبل از signing
    final cleaned = Map<String, dynamic>.from(message)
      ..remove('_signature')
      ..remove('_token');

    final canonical = _canonicalize(cleaned);
    final key = utf8.encode(secretKey);
    final bytes = utf8.encode(canonical);

    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);

    return digest.toString();
  }

  String _canonicalize(Map<String, dynamic> map) {
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    return jsonEncode(sorted);
  }

  void clearNonces() => _usedNonces.clear();
}

class ValidationResult {
  final bool valid;
  final String? reason;

  const ValidationResult({
    required this.valid,
    this.reason,
  });
}
