import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

void main() {
  group('ContentSecurityPolicy', () {
    late ContentSecurityPolicy csp;

    setUp(() {
      csp = ContentSecurityPolicy();
    });

    test('allows http/https by default', () {
      expect(csp.isUrlAllowed('https://example.com'), true);
      expect(csp.isUrlAllowed('http://localhost:8080'), true);
    });

    test('blocks blocked origins', () {
      csp.blockOrigin('evil.com');
      expect(csp.isUrlAllowed('https://evil.com/path'), false);
    });

    test('blocks blocked schemes', () {
      csp.blockScheme('ftp');
      expect(csp.isUrlAllowed('ftp://server.com'), false);
    });

    test('allows all plugins by default', () {
      expect(csp.isPluginAllowed('anyPlugin'), true);
    });

    test('whitelist mode blocks unlisted plugins', () {
      csp.setAllowedPlugins(['storage', 'http']);
      expect(csp.isPluginAllowed('storage'), true);
      expect(csp.isPluginAllowed('http'), true);
      expect(csp.isPluginAllowed('bluetooth'), false);
    });

    test('blocked plugins', () {
      csp.blockPlugins(['dangerous']);
      expect(csp.isPluginAllowed('dangerous'), false);
      expect(csp.isPluginAllowed('safe'), true);
    });

    test('payload size check', () {
      csp.setMaxPayloadSize(100);
      expect(csp.isPayloadSizeAllowed(50), true);
      expect(csp.isPayloadSizeAllowed(200), false);
    });

    test('generateMetaTag returns valid string', () {
      final tag = csp.generateMetaTag();
      expect(tag, contains("default-src 'self'"));
      expect(tag, contains('script-src'));
    });

    test('production config is restrictive', () {
      final prod = ContentSecurityPolicy.production();
      expect(prod.stats['allowEval'], false);
      expect(prod.stats['allowInlineScripts'], false);
    });

    test('development config is permissive', () {
      final dev = ContentSecurityPolicy.development();
      expect(dev.stats['allowEval'], true);
      expect(dev.stats['allowInlineScripts'], true);
    });
  });
}
