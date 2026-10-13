// ignore_for_file: avoid_print
import 'dart:io';

import 'package:path/path.dart' as p;

import 'plugin_catalog.dart';

/// A use of the bridge the scanner cannot resolve to a plugin name.
class DynamicUse {
  const DynamicUse(this.location, this.snippet);

  /// `path:line`
  final String location;
  final String snippet;

  @override
  String toString() => '$location  $snippet';
}

/// What a scan of the web app found.
class DetectResult {
  const DetectResult(this.evidence, this.dynamicUses, this.unknownNames);

  /// Plugin yaml key -> first places that use it (`path:line`, at most 3).
  final Map<String, List<String>> evidence;

  /// Bridge calls whose plugin is not a string literal.
  final List<DynamicUse> dynamicUses;

  /// Names used as `plugin:` that match no plugin (typos, removed plugins).
  final Map<String, String> unknownNames;

  Set<String> get plugins => evidence.keys.toSet();
}

/// Source files that are scanned; the bridge files themselves are not.
const _scanExtensions = {
  '.html', '.htm', '.js', '.mjs', '.cjs', '.jsx', '.ts', '.tsx', '.vue', //
  '.svelte',
};
const _skippedNames = {
  'native-sdk.js',
  'native-sdk.d.ts',
  'native-resilience.js',
};

/// Finds the plugins a web app uses.
///
/// [files]: path -> source text of the app (not the bridge files).
/// [bridgeToKey]: bridge name (`fileSystem`) -> yaml key (`file_system`).
/// [namespaceToBridge]: `NativeSDK.<namespace>` -> bridge name.
///
/// It recognizes `NativeSDK.camera.takePhoto()`, `const { camera } =
/// NativeSDK`, `plugin: 'camera'` in a call object, `.call('camera', ...)` and
/// the annotation `sweetmelon:uses camera, storage` for anything else.
/// This is a text scan, not a JavaScript analysis: a plugin name built at run
/// time is reported in [DetectResult.dynamicUses] instead of being guessed.
DetectResult detectPlugins({
  required Map<String, String> files,
  required Map<String, String> bridgeToKey,
  required Map<String, String> namespaceToBridge,
}) {
  final evidence = <String, List<String>>{};
  final dynamicUses = <DynamicUse>[];
  final unknown = <String, String>{};

  void found(String key, String where) {
    final list = evidence.putIfAbsent(key, () => []);
    if (list.length < 3 && !list.contains(where)) list.add(where);
  }

  void bridge(String name, String where, {bool onlyKnown = false}) {
    final key =
        bridgeToKey[name] ?? (bridgeToKey.values.contains(name) ? name : null);
    if (key != null) {
      found(key, where);
    } else if (!onlyKnown) {
      unknown.putIfAbsent(name, () => where);
    }
  }

  final aliasDecl = RegExp(
      r'(?:\b(?:var|let|const)\s+)?([A-Za-z_$][\w$]*)\s*=\s*(?:window\.|globalThis\.)?NativeSDK\s*(?:;|,|\n|$)');
  final destructure =
      RegExp(r'\{([^{}]*)\}\s*=\s*(?:window\.|globalThis\.)?NativeSDK\b');
  final pluginLiteral =
      RegExp('''\\bplugin['"]?\\s*:\\s*['"]([A-Za-z_]\\w*)['"]''');
  final pluginDynamic = RegExp('''\\bplugin['"]?\\s*:\\s*[A-Za-z_\\[(\$]''');
  // `.call('camera'` and a local helper `call('camera', 'takePhoto', ...)`.
  final callLiteral = RegExp(
      '''(?:\\.call\\(\\s*|\\bcall\\(\\s*(?=['"]\\w+['"]\\s*,\\s*['"]))['"]([A-Za-z_]\\w*)['"]''');
  final callDynamic =
      RegExp('''\\bNative(?:SDK)?\\s*\\.call\\(\\s*[A-Za-z_\\[(\$]''');
  final computed = RegExp(r'\bNativeSDK\s*\[');
  final uses = RegExp(r'sweetmelon:uses\s+([\w,\s]+)');

  files.forEach((path, text) {
    // `var S = window.NativeSDK;` makes `S.camera.x()` a use of the SDK too.
    final names = {
      'NativeSDK',
      for (final m in aliasDecl.allMatches(text)) RegExp.escape(m[1]!),
    }.join('|');
    final sdkNs = RegExp('(?:$names)\\s*\\.\\s*([A-Za-z_]\\w*)\\s*\\.');
    final lines = text.split('\n');
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final where = '$path:${i + 1}';

      for (final m in sdkNs.allMatches(line)) {
        final bridgeName = namespaceToBridge[m[1]!];
        if (bridgeName != null) bridge(bridgeName, where, onlyKnown: true);
      }
      for (final m in pluginLiteral.allMatches(line)) {
        bridge(m[1]!, where);
      }
      for (final m in callLiteral.allMatches(line)) {
        bridge(m[1]!, where, onlyKnown: true);
      }
      for (final m in uses.allMatches(line)) {
        for (final name in m[1]!.split(RegExp(r'[,\s]+'))) {
          if (name.isNotEmpty) bridge(name, where);
        }
      }
      if (pluginDynamic.hasMatch(line) && !pluginLiteral.hasMatch(line)) {
        dynamicUses.add(DynamicUse(where, line.trim()));
      } else if (callDynamic.hasMatch(line) || computed.hasMatch(line)) {
        dynamicUses.add(DynamicUse(where, line.trim()));
      }
    }

    // `const { camera, storage } = NativeSDK` can span lines.
    for (final m in destructure.allMatches(text)) {
      final line = '\n'.allMatches(text.substring(0, m.start)).length + 1;
      for (final part in m[1]!.split(',')) {
        final ns = part.split(':').first.trim();
        final bridgeName = namespaceToBridge[ns];
        if (bridgeName != null) {
          bridge(bridgeName, '$path:$line', onlyKnown: true);
        }
      }
    }
  });

  return DetectResult(evidence, dynamicUses, unknown);
}

/// `NativeSDK.<namespace>` -> bridge name, read from the SDK file itself so it
/// cannot drift from the bridge.
Map<String, String> sdkNamespaces(String sdkSource) {
  final result = <String, String>{};
  final header = RegExp(r'^    (\w+): \{', multiLine: true);
  final call = RegExp(r"call\('(\w+)'");
  final starts = header.allMatches(sdkSource).toList();
  for (var i = 0; i < starts.length; i++) {
    final end = i + 1 < starts.length ? starts[i + 1].start : sdkSource.length;
    final block = sdkSource.substring(starts[i].end, end);
    final first = call.firstMatch(block);
    if (first != null) result[starts[i][1]!] = first[1]!;
  }
  return result;
}

/// Bridge name (`fileSystem`) -> yaml key, from the plugin sources named in
/// the catalog (`String get name => '...'`).
Future<Map<String, String>> bridgeNames(
    String root, PluginCatalog catalog) async {
  final nameRe = RegExp(r"String get name => '([^']+)'");
  final result = <String, String>{};
  for (final entry in catalog.entries) {
    final file = File(p.join(root, 'lib', entry.importPath));
    if (!await file.exists()) continue;
    final m = nameRe.firstMatch(await file.readAsString());
    if (m != null) result[m[1]!] = entry.yamlKey;
  }
  return result;
}

/// Reads the app sources below [wwwDir].
Future<Map<String, String>> readAppSources(String wwwDir) async {
  final files = <String, String>{};
  final dir = Directory(wwwDir);
  if (!await dir.exists()) return files;
  await for (final entity in dir.list(recursive: true)) {
    if (entity is! File) continue;
    final relative =
        p.relative(entity.path, from: wwwDir).replaceAll('\\', '/');
    if (relative.split('/').contains('node_modules')) continue;
    if (_skippedNames.contains(p.basename(relative))) continue;
    if (!_scanExtensions.contains(p.extension(relative).toLowerCase())) {
      continue;
    }
    try {
      files[relative] = await entity.readAsString();
    } on Exception {
      // Not valid UTF-8: not a source file.
    }
  }
  return files;
}

/// Scans [wwwDir] with the catalog and SDK of the project at [root].
Future<DetectResult?> detectInProject(String root, String wwwDir) async {
  final catalog =
      await PluginCatalog.load(p.join(root, 'tool/plugin_catalog.json'));
  final sdk = File(p.join(root, 'assets/www/js/native-sdk.js'));
  if (catalog == null || !await sdk.exists()) return null;
  return detectPlugins(
    files: await readAppSources(wwwDir),
    bridgeToKey: await bridgeNames(root, catalog),
    namespaceToBridge: sdkNamespaces(await sdk.readAsString()),
  );
}

/// `sweetmelon detect [--www dir] [--strict]`.
///
/// Prints the plugins the app uses. A bridge call the scanner cannot resolve is
/// a warning, or an error with [strict].
class DetectRunner {
  DetectRunner({this.root = '.'});

  final String root;

  Future<int> run({String? www, bool strict = false}) async {
    final dir = www ?? p.join(root, 'assets', 'www');
    final result = await detectInProject(root, dir);
    if (result == null) {
      print(
          'tool/plugin_catalog.json or assets/www/js/native-sdk.js not found');
      return 1;
    }
    printReport(result, dir, strict: strict);
    return strict && result.dynamicUses.isNotEmpty ? 1 : 0;
  }

  static void printReport(DetectResult result, String dir,
      {required bool strict}) {
    print('Plugins used by $dir');
    final keys = result.evidence.keys.toList()..sort();
    if (keys.isEmpty) print('  (none)');
    for (final key in keys) {
      print('  $key   ${result.evidence[key]!.join(', ')}');
    }
    for (final entry in result.unknownNames.entries) {
      print('  ⚠️  unknown plugin "${entry.key}" at ${entry.value}');
    }
    if (result.dynamicUses.isNotEmpty) {
      print('');
      print(strict
          ? '❌ Calls the scanner cannot resolve (strict):'
          : '⚠️  Calls the scanner cannot resolve; list their plugins in '
              'plugin_selection.include or add "sweetmelon:uses name" in the '
              'code:');
      for (final use in result.dynamicUses) {
        print('  $use');
      }
    }
  }
}
