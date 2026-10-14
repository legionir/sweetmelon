import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Contract for the permissions plugins declare.
///
/// `requiredPermissions` is checked by the plugin manager before EVERY call of
/// the plugin, `getInfo` and playback included. The audio plugin declared
/// `microphone` there, so `audio.play` was rejected until the microphone was
/// granted, even though only recording needs it.
///
/// These tests read the sources (no device, no platform channels) and fail when
/// a plugin starts gating all of its methods behind a permission without that
/// being a conscious decision, or names a permission the provider cannot map
/// (which is denied forever).
///
/// If a test here fails after you added a plugin permission:
///  * only some methods need it -> leave `requiredPermissions` empty and ask for
///    the permission inside those methods (see `AudioPlugin._startRecording`);
///  * every method needs it -> add the plugin to [gatedPlugins] below, with
///    the reason.
void main() {
  /// Plugins whose every method really needs the permission.
  const gatedPlugins = <String, List<String>>{
    // Scanning/advertising and connecting all need the Bluetooth permission.
    'bluetooth': ['bluetooth'],
    // Location in every method.
    'geolocation': ['location'],
    'background_geolocation': ['location'],
    // The camera preview is the camera (and the microphone for video).
    'camera_preview': ['camera', 'microphone'],
    'document_scanner': ['camera'],
    'qr_scanner': ['camera'],
    'speech_to_text': ['microphone'],
    'contacts': ['contacts'],
    'push_notification': ['notification'],
    // SIM data needs READ_PHONE_STATE.
    'sim_info': ['phone'],
  };

  final declared = _declaredPermissions();

  test('plugins that gate every method behind a permission are on the list',
      () {
    final withPermissions = {
      for (final e in declared.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };

    final unlisted = withPermissions.keys
        .where((name) => !gatedPlugins.containsKey(name))
        .toList()
      ..sort();
    expect(unlisted, isEmpty,
        reason: 'These plugins declare requiredPermissions, which blocks all '
            'their methods until granted. If only some methods need it, ask '
            'for it inside those methods; otherwise add the plugin to '
            'gatedPlugins in this test with the reason.');

    final stale = gatedPlugins.keys
        .where((name) => !withPermissions.containsKey(name))
        .toList()
      ..sort();
    expect(stale, isEmpty,
        reason: 'These plugins are on gatedPlugins but no longer declare a '
            'permission (or the plugin is gone): remove them from the list.');

    for (final entry in gatedPlugins.entries) {
      expect(withPermissions[entry.key], unorderedEquals(entry.value),
          reason: '${entry.key}: the declared permissions changed');
    }
  });

  test('every declared permission name is one the provider can map', () {
    final mapped = _mappedPermissionNames();
    expect(mapped, isNotEmpty, reason: 'could not read _mapPermission');

    final unknown = <String, List<String>>{};
    declared.forEach((plugin, names) {
      final missing = names.where((n) => !mapped.contains(n)).toList();
      if (missing.isNotEmpty) unknown[plugin] = missing;
    });
    expect(unknown, isEmpty,
        reason: 'An unmapped permission is denied on every call. Add it to '
            'NativePermissionProvider._mapPermission.');
  });

  test('the permission plugin lists exactly the names the provider maps', () {
    final source = File('lib/plugins/permission/lib/permission_plugin.dart')
        .readAsStringSync();
    final block = RegExp(r'_knownPermissions\s*=\s*\[([^\]]*)\]')
        .firstMatch(source)!
        .group(1)!;
    final known =
        RegExp(r"'([^']+)'").allMatches(block).map((m) => m.group(1)!).toSet();
    expect(known, _mappedPermissionNames());
  });

  test('every plugin source was understood', () {
    // A getter written in a form the scan cannot read would hide a gate.
    expect(declared, isNotEmpty);
    for (final dir
        in Directory('lib/plugins').listSync().whereType<Directory>()) {
      final plugin = p.basename(dir.path);
      final lib = Directory(p.join(dir.path, 'lib'));
      if (!lib.existsSync()) continue;
      final hasGetter = lib
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .any((f) => f.readAsStringSync().contains('requiredPermissions'));
      if (hasGetter) {
        expect(declared.containsKey(plugin), isTrue,
            reason: '$plugin: requiredPermissions is declared in a form this '
                'test cannot read; write it as => [ ... ] or => const [].');
      }
    }
  });
}

/// plugin directory name -> permissions from its `requiredPermissions` getter.
Map<String, List<String>> _declaredPermissions() {
  final result = <String, List<String>>{};
  final getter =
      RegExp(r'requiredPermissions\s*=>\s*(?:const\s*)?\[([^\]]*)\]\s*;');
  for (final dir
      in Directory('lib/plugins').listSync().whereType<Directory>()) {
    final lib = Directory(p.join(dir.path, 'lib'));
    if (!lib.existsSync()) continue;
    for (final file in lib.listSync().whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final match = getter.firstMatch(file.readAsStringSync());
      if (match == null) continue;
      result[p.basename(dir.path)] = RegExp(r"'([^']+)'")
          .allMatches(match.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
    }
  }
  return result;
}

Set<String> _mappedPermissionNames() {
  final source = File('lib/packages/security/lib/src/permission_manager.dart')
      .readAsStringSync();
  final start = source.indexOf('_mapPermission(String permission)');
  final end = source.indexOf('_mapStatus(', start);
  if (start < 0 || end < 0) return {};
  return RegExp(r"case '([^']+)':")
      .allMatches(source.substring(start, end))
      .map((m) => m.group(1)!)
      .toSet();
}
