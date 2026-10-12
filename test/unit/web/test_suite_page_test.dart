import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Static checks for the default web app (assets/www): the page, its scripts
/// and the SDK have to agree with each other, otherwise a button silently does
/// nothing on a device.
void main() {
  final html = File('assets/www/index.html').readAsStringSync();
  final app = File('assets/www/js/app.js').readAsStringSync();
  final ui = File('assets/www/js/ui.js').readAsStringSync();
  final sdk = File('assets/www/js/native-sdk.js').readAsStringSync();

  Set<String> matches(RegExp re, String text, [int group = 1]) =>
      re.allMatches(text).map((m) => m.group(group)!).toSet();

  final htmlIds = matches(RegExp(r'\bid="([^"]+)"'), html);

  test(
      'every local script, stylesheet and image referenced by index.html exists',
      () {
    final refs = matches(RegExp(r'''(?:src|href)=["']([^"':#]+)["']'''), html);
    expect(refs, containsAll(['img/logo.png', 'css/styles.css', 'js/app.js']));
    for (final ref in refs) {
      expect(File('assets/www/$ref').existsSync(), isTrue, reason: ref);
    }
  });

  test('every element id used by the scripts exists in index.html', () {
    final used = {
      ...matches(RegExp(r"""\$\('([A-Za-z0-9_]+)'\)"""), app),
      ...matches(RegExp(r"""\$\('([A-Za-z0-9_]+)'\)"""), ui),
    };
    expect(used, isNotEmpty);
    expect(used.difference(htmlIds), isEmpty);
  });

  test('every button on the page has a click handler', () {
    final buttons = matches(RegExp(r'<button[^>]*\bid="([^"]+)"'), html)
      ..removeAll(const {'btnToggleAll', 'btnJumpResults'}); // wired in ui.js
    final bound = matches(RegExp(r"""\$\('([A-Za-z0-9_]+)'\)\.onclick"""), app);
    expect(buttons.difference(bound), isEmpty);
    expect(bound.difference(buttons), isEmpty);
  });

  test('every panel points at an existing plugin and a known group', () {
    final panels = RegExp(
            r'<section class="panel" data-plugin="([^"]+)" data-group="([^"]+)"')
        .allMatches(html)
        .toList();
    expect(panels.length, greaterThan(25));
    const groups = {
      'System',
      'Network',
      'Storage',
      'Security',
      'Media',
      'Device',
      'UI'
    };
    final seen = <String>{};
    for (final m in panels) {
      final plugin = m.group(1)!;
      expect(Directory('lib/plugins/$plugin').existsSync(), isTrue,
          reason: plugin);
      expect(groups, contains(m.group(2)), reason: plugin);
      expect(seen.add(plugin), isTrue, reason: 'duplicate panel for $plugin');
    }
  });

  test('every NativeSDK call made by app.js exists in native-sdk.js', () {
    final calls = RegExp(r'\bS\.([A-Za-z]+)\.([A-Za-z]+)\(').allMatches(app);
    expect(calls, isNotEmpty);
    for (final m in calls) {
      final ns = m.group(1)!;
      final method = m.group(2)!;
      final start = sdk.indexOf('\n    $ns: {');
      expect(start, isNonNegative, reason: 'namespace $ns');
      final end = sdk.indexOf('\n    }', start);
      expect(sdk.substring(start, end), contains('$method:'),
          reason: 'NativeSDK.$ns.$method');
    }
  });
}
