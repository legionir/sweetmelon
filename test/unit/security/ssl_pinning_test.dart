import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/packages/core/lib/core.dart';

/// A 64-character SHA-256 style fingerprint built from a repeated seed.
String pin(String seed) => seed * 64;

void main() {
  group('SslPinning registry', () {
    test('starts disabled with no pinned domains', () {
      final pinning = SslPinning();
      expect(pinning.stats, {
        'enabled': false,
        'pinnedDomains': <String>[],
        'totalPins': 0,
      });
    });

    test('enable and disable toggle the enabled flag', () {
      final pinning = SslPinning();
      pinning.enable();
      expect(pinning.stats['enabled'], true);

      pinning.disable();
      expect(pinning.stats['enabled'], false);
    });

    test('addPin stores lower-cased fingerprints once per domain', () {
      final pinning = SslPinning();
      final upper = pin('A');
      pinning.addPin('api.example.com', upper);
      pinning.addPin('api.example.com', upper.toLowerCase());
      expect(pinning.stats['pinnedDomains'], ['api.example.com']);
      expect(pinning.stats['totalPins'], 1);
    });

    test('addPins adds every fingerprint for the domain', () {
      final pinning = SslPinning()
        ..addPins('cdn.example.com', [pin('a'), pin('b'), pin('c')]);
      expect(pinning.stats['totalPins'], 3);
      expect(pinning.stats['pinnedDomains'], ['cdn.example.com']);
    });

    test('totalPins counts fingerprints across all domains', () {
      final pinning = SslPinning()
        ..addPin('one.example.com', pin('1'))
        ..addPins('two.example.com', [pin('2'), pin('3')]);
      expect(pinning.stats['totalPins'], 3);
      expect(pinning.stats['pinnedDomains'],
          containsAll(['one.example.com', 'two.example.com']));
    });

    test('removePin drops every fingerprint for a domain', () {
      final pinning = SslPinning()
        ..addPins('gone.example.com', [pin('x'), pin('y')])
        ..addPin('kept.example.com', pin('z'));
      pinning.removePin('gone.example.com');
      pinning.removePin('never-added.example.com');
      expect(pinning.stats['pinnedDomains'], ['kept.example.com']);
      expect(pinning.stats['totalPins'], 1);
    });
  });

  group('SslPinning.createPinnedClient', () {
    test('returns a plain client when pinning is disabled', () {
      final pinning = SslPinning()..addPin('api.example.com', pin('a'));
      final client = pinning.createPinnedClient();
      expect(client, isA<HttpClient>());
      client.close(force: true);
    });

    test('returns a plain client when no pins are configured', () {
      final pinning = SslPinning()..enable();
      final client = pinning.createPinnedClient();
      expect(client, isA<HttpClient>());
      client.close(force: true);
    });

    test('returns a client when pinning is active', () {
      final pinning = SslPinning()
        ..enable()
        ..addPin('api.example.com', pin('a'));
      final client = pinning.createPinnedClient();
      expect(client, isA<HttpClient>());
      client.close(force: true);
    });
  });
}
