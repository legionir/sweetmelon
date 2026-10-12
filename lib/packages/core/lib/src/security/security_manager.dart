import 'dart:convert';

import '../utils/logger.dart';
import 'bridge_auth.dart';
import 'message_signer.dart';
import 'ssl_pinning.dart';
import 'content_security.dart';
import 'anti_tampering.dart';

/// مدیر مرکزی امنیت
class SecurityManager {
  final BridgeAuth auth;
  final MessageSigner signer;
  final SslPinning sslPinning;
  final ContentSecurityPolicy csp;
  final AntiTampering antiTampering;

  bool _initialized = false;

  SecurityManager({
    BridgeAuth? auth,
    MessageSigner? signer,
    SslPinning? sslPinning,
    ContentSecurityPolicy? csp,
    AntiTampering? antiTampering,
  })  : auth = auth ?? BridgeAuth(),
        signer = signer ?? MessageSigner(),
        sslPinning = sslPinning ?? SslPinning(),
        csp = csp ?? ContentSecurityPolicy.development(),
        antiTampering = antiTampering ?? AntiTampering();

  /// Production configuration
  factory SecurityManager.production() {
    return SecurityManager(
      auth: BridgeAuth(sessionTimeout: const Duration(hours: 8)),
      signer: MessageSigner(
        level: SecurityLevel.signed,
        maxMessageAge: const Duration(seconds: 30),
      ),
      sslPinning: SslPinning()..enable(),
      csp: ContentSecurityPolicy.production(),
      antiTampering: AntiTampering()..enable(),
    );
  }

  /// Development configuration
  factory SecurityManager.development() {
    return SecurityManager(
      auth: BridgeAuth(sessionTimeout: const Duration(hours: 24)),
      signer: MessageSigner(level: SecurityLevel.tokenOnly),
      sslPinning: SslPinning(),
      csp: ContentSecurityPolicy.development(),
      antiTampering: AntiTampering(),
    );
  }

  /// شروع session و تولید JS injection code
  String initializeSession() {
    final token = auth.createSession();
    _initialized = true;

    BridgeLogger.info('SecurityManager', 'Session initialized');

    return token;
  }

  /// اعتبارسنجی یک پیام ورودی
  SecurityCheckResult validateIncomingMessage(
    Map<String, dynamic> message,
  ) {
    // 1. بررسی payload size
    final payloadSize = utf8.encode(jsonEncode(message)).length;
    if (!csp.isPayloadSizeAllowed(payloadSize)) {
      return SecurityCheckResult.rejected('payload_too_large');
    }

    // 2. بررسی token
    final token = message['_token'] as String?;
    if (!auth.validateToken(token)) {
      return SecurityCheckResult.rejected('invalid_token');
    }

    // 3. بررسی signature
    if (signer.level.index >= SecurityLevel.signed.index) {
      final signature = message['_signature'] as String?;
      final secretKey = auth.secretKey;

      if (secretKey != null) {
        final validationResult = signer.validate(
          message,
          token,
          signature,
          secretKey,
          auth.currentToken!,
        );

        if (!validationResult.valid) {
          return SecurityCheckResult.rejected(
            validationResult.reason ?? 'signature_invalid',
          );
        }
      }
    }

    // 4. بررسی plugin access
    final plugin = message['plugin'] as String?;
    if (plugin != null && !csp.isPluginAllowed(plugin)) {
      return SecurityCheckResult.rejected('plugin_blocked');
    }

    return SecurityCheckResult.allowed();
  }

  /// تولید JS code برای injection امنیت
  String generateSecurityScript() {
    final token = auth.currentToken ?? '';
    final secret = auth.secretKey ?? '';
    final level = signer.level.name;

    return '''
      (function() {
        window.__bridgeSecurity = {
          token: "$token",
          secret: "$secret",
          level: "$level",
          
          sign: function(message) {
            if (this.level === 'none' || this.level === 'tokenOnly') {
              return null;
            }
            
            var cleaned = {};
            Object.keys(message).sort().forEach(function(key) {
              if (key !== '_signature' && key !== '_token') {
                cleaned[key] = message[key];
              }
            });
            
            var payload = JSON.stringify(cleaned);
            // Simple HMAC - در production باید از crypto API استفاده بشه
            return this._hmac(payload, this.secret);
          },
          
          _hmac: function(message, key) {
            // Simplified - for production use SubtleCrypto
            var hash = 0;
            var combined = key + message;
            for (var i = 0; i < combined.length; i++) {
              var char = combined.charCodeAt(i);
              hash = ((hash << 5) - hash) + char;
              hash = hash & hash;
            }
            return Math.abs(hash).toString(36);
          },
          
          prepareMessage: function(message) {
            message._token = this.token;
            
            if (this.level === 'strict') {
              message._ts = Date.now();
              message._nonce = Math.random().toString(36).substr(2, 16);
            }
            
            if (this.level === 'signed' || this.level === 'strict') {
              message._signature = this.sign(message);
            }
            
            return message;
          }
        };
        
        // Override Native.call to add security
        if (window.Native && window.Native.call) {
          var originalCall = window.Native.call;
          
          window.Native.call = function(options) {
            var message = {
              plugin: options.plugin,
              method: options.method,
              args: options.args || {},
              version: options.version || '1.0.0',
              requestId: options.requestId,
              timestamp: new Date().toISOString(),
              metadata: options.metadata || { headers: {} }
            };
            
            var secured = window.__bridgeSecurity.prepareMessage(message);
            options._token = secured._token;
            options._signature = secured._signature;
            options._ts = secured._ts;
            options._nonce = secured._nonce;
            
            return originalCall.call(window.Native, options);
          };
        }
        
        console.log('[Security] Bridge security initialized (level: ' + window.__bridgeSecurity.level + ')');
      })();
    ''';
  }

  /// گزارش امنیتی
  Map<String, dynamic> getSecurityReport() {
    return {
      'initialized': _initialized,
      'auth': auth.stats,
      'signer': {
        'level': signer.level.name,
      },
      'sslPinning': sslPinning.stats,
      'csp': csp.stats,
      'antiTampering': antiTampering.stats,
    };
  }

  void dispose() {
    auth.revokeSession();
    signer.clearNonces();
  }
}

class SecurityCheckResult {
  final bool allowed;
  final String? rejectionReason;

  const SecurityCheckResult._({
    required this.allowed,
    this.rejectionReason,
  });

  factory SecurityCheckResult.allowed() =>
      const SecurityCheckResult._(allowed: true);

  factory SecurityCheckResult.rejected(String reason) =>
      SecurityCheckResult._(allowed: false, rejectionReason: reason);
}
