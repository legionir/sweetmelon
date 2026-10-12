import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('SecurityManager', () {
    test('development config is permissive', () {
      final sm = SecurityManager.development();
      final token = sm.initializeSession();

      expect(token, isNotEmpty);

      final result = sm.validateIncomingMessage({
        'plugin': 'storage',
        'method': 'get',
        '_token': token,
      });

      expect(result.allowed, true);
    });

    test('rejects missing token', () {
      final sm = SecurityManager.development();
      sm.initializeSession();

      final result = sm.validateIncomingMessage({
        'plugin': 'storage',
        'method': 'get',
      });

      expect(result.allowed, false);
      expect(result.rejectionReason, 'invalid_token');
    });

    test('rejects wrong token', () {
      final sm = SecurityManager.development();
      sm.initializeSession();

      final result = sm.validateIncomingMessage({
        'plugin': 'storage',
        'method': 'get',
        '_token': 'wrong_token',
      });

      expect(result.allowed, false);
    });

    test('rejects oversized payload', () {
      final sm = SecurityManager.development();
      sm.initializeSession();
      sm.csp.setMaxPayloadSize(100);

      final largeMessage = {
        'plugin': 'test',
        'method': 'run',
        '_token': sm.auth.currentToken,
        'data': 'x' * 200,
      };

      final result = sm.validateIncomingMessage(largeMessage);
      expect(result.allowed, false);
      expect(result.rejectionReason, 'payload_too_large');
    });

    test('rejects blocked plugins', () {
      final sm = SecurityManager.development();
      final token = sm.initializeSession();
      sm.csp.blockPlugins(['dangerous']);

      final result = sm.validateIncomingMessage({
        'plugin': 'dangerous',
        'method': 'run',
        '_token': token,
      });

      expect(result.allowed, false);
      expect(result.rejectionReason, 'plugin_blocked');
    });

    test('generateSecurityScript returns JS', () {
      final sm = SecurityManager.development();
      sm.initializeSession();

      final js = sm.generateSecurityScript();
      expect(js, contains('__bridgeSecurity'));
      expect(js, contains('token'));
    });

    test('getSecurityReport returns all stats', () {
      final sm = SecurityManager.development();
      sm.initializeSession();

      final report = sm.getSecurityReport();

      expect(report, containsPair('initialized', true));
      expect(report['auth'], isA<Map>());
      expect(report['signer'], isA<Map>());
      expect(report['sslPinning'], isA<Map>());
      expect(report['csp'], isA<Map>());
      expect(report['antiTampering'], isA<Map>());
    });

    test('dispose revokes session', () {
      final sm = SecurityManager.development();
      final token = sm.initializeSession();

      sm.dispose();

      expect(sm.auth.validateToken(token), false);
    });

    test('production config is strict', () {
      final sm = SecurityManager.production();
      final report = sm.getSecurityReport();

      expect(report['sslPinning']['enabled'], true);
      expect(report['antiTampering']['enabled'], true);
      expect(report['csp']['allowEval'], false);
    });
  });
}
