// ignore_for_file: avoid_print
import 'dart:io';

import 'package:path/path.dart' as p;

import '../core_version.dart';
import 'core_compat.dart';
import 'package_rename.dart';
import 'project_settings.dart';
import 'safe_writer.dart';

/// Where the sample caller workflow lives in the core repository.
const workflowExamplePath = 'examples/build-with-sweetmelon.yml';

/// The files of a new project that builds with the core as an Action.
///
/// [workflow] is the text of the sample workflow; every `legionir/sweetmelon@v`
/// reference in it is pinned to [coreVersion].
Map<String, String> renderAppTemplate({
  required String appName,
  required String applicationId,
  required String dartPackage,
  required String workflow,
  String coreVersion = sweetmelonCoreVersion,
}) {
  final minor = coreVersion.split('.').take(2).join('.');
  return {
    'sweetmelon.yaml': '''
# Release of the Sweetmelon core this app is built for. Change it on purpose
# (sweetmelon upgrade), after reading the core CHANGELOG.
core: "$minor"

project:
  name: $dartPackage
  display_name: "$appName"
  version: 1.0.0
  application_id: $applicationId
  dart_package: $dartPackage
  # icon: icon.png            # square PNG, 1024 px or more

# auto: the plugins your JavaScript calls are on, the rest are off.
# Check with: dart run bin/sweetmelon.dart detect --www www
plugin_selection:
  mode: auto
  include: []
  exclude: []

plugins: {}
''',
    'www/index.html': '''
<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>$appName</title>
    <link rel="stylesheet" href="css/styles.css" />
  </head>
  <body>
    <main>
      <h1>$appName</h1>
      <p id="count">Opened 0 times</p>
      <button id="hello">Say hello</button>
    </main>
    <script src="js/native-sdk.js"></script>
    <script src="js/main.js"></script>
  </body>
</html>
''',
    'www/css/styles.css': '''
body { font-family: system-ui, sans-serif; margin: 0; padding: 24px; }
main { max-width: 480px; margin: 0 auto; text-align: center; }
button { padding: 12px 20px; font-size: 16px; }
''',
    'www/js/main.js': '''
// NativeSDK comes from js/native-sdk.js, which the build adds from the core.
// The plugins used here (storage, toast) are found by "detect" and switched on.
var S = window.NativeSDK;

S.waitForReady().then(function () {
  return S.storage.get('opens').then(function (res) {
    var n = (Number(res && res.value) || 0) + 1;
    document.getElementById('count').textContent = 'Opened ' + n + ' times';
    return S.storage.set('opens', n);
  });
});

document.getElementById('hello').onclick = function () {
  S.toast.show('Hello from $appName');
};
''',
    '.github/workflows/build.yml':
        '# Pinned to core v$coreVersion. Change it with: '
            'sweetmelon upgrade --to <version>\n'
            '${_withoutLeadingComments(workflow).replaceAllMapped(RegExp(r'legionir/sweetmelon@v[0-9][^\s]*'), (_) => 'legionir/sweetmelon@v$coreVersion')}',
    '.gitignore': '''
.sweetmelon/
build/
.dart_tool/
''',
    'README.md': '''
# $appName

Web app built with [Sweetmelon](https://github.com/legionir/sweetmelon) core
v$coreVersion.

- `www/` your app (HTML, CSS, JavaScript)
- `sweetmelon.yaml` names, core version and plugin selection
- `.github/workflows/build.yml` Actions tab, "Build app": pick the package name,
  app name and APK / AAB / iOS, then run

Plugins follow the code: a plugin is on when `www/` calls it.
''',
  };
}

/// The workflow without the explanation block that starts the example file.
String _withoutLeadingComments(String text) {
  final lines = text.split('\n');
  final first = lines.indexWhere((l) => !l.startsWith('#'));
  return lines.sublist(first < 0 ? 0 : first).join('\n');
}

/// `sweetmelon init <folder> --package-name ... --app-name ...`.
class InitRunner {
  InitRunner({this.coreRoot = '.'});

  /// Folder of the core checkout, where the sample workflow is read from.
  final String coreRoot;

  Future<int> run(
    String folder, {
    required String appName,
    required String applicationId,
    String? dartPackage,
    bool apply = false,
  }) async {
    final idProblem = validateApplicationId(applicationId);
    if (idProblem != null) {
      print(idProblem);
      return 1;
    }
    final dart = dartPackage ?? _dartNameFrom(applicationId);
    final nameProblem = validateDartPackageName(dart);
    if (nameProblem != null) {
      print(nameProblem);
      return 1;
    }
    final example = File(p.join(coreRoot, workflowExamplePath));
    if (!await example.exists()) {
      print('$workflowExamplePath not found in $coreRoot');
      return 1;
    }
    final target = Directory(folder);
    if (await target.exists() && !await target.list().isEmpty) {
      print('$folder is not empty');
      return 1;
    }

    final files = renderAppTemplate(
      appName: appName,
      applicationId: applicationId,
      dartPackage: dart,
      workflow: await example.readAsString(),
    );
    print('New app "$appName" ($applicationId, Dart package $dart) in $folder');
    final writer =
        SafeWriter(root: folder, dryRun: !apply, requireCleanGit: false);
    files.forEach(writer.replace);
    for (final change in await writer.commit()) {
      print('  $change');
    }
    print(apply
        ? 'Written. Next: push it to GitHub, then Actions > Build app.'
        : 'Dry run. Run again with --apply to write.');
    return 0;
  }

  /// `com.acme.my_app` -> `my_app`.
  static String _dartNameFrom(String applicationId) {
    final last = applicationId.split('.').last.toLowerCase();
    return last.replaceAll(RegExp('[^a-z0-9_]'), '_');
  }
}

/// `sweetmelon upgrade --to 2.5.0` in an app that builds with the Action.
///
/// Sets `core:` in sweetmelon.yaml and the `legionir/sweetmelon@v...` pin in
/// every workflow. Another minor needs a decision, so it is refused unless
/// [allowMinor]; another major unless [allowMajor].
class UpgradeRunner {
  UpgradeRunner({this.root = '.'});

  final String root;

  static final _pin = RegExp(r'legionir/sweetmelon@v([0-9]+\.[0-9]+\.[0-9]+)');

  Future<int> run(
    String target, {
    bool apply = false,
    bool allowMinor = false,
    bool allowMajor = false,
  }) async {
    final wanted = _parse(target);
    if (wanted == null) {
      print('--to must be an exact version such as 2.4.1');
      return 64;
    }
    final yamlFile = File(p.join(root, 'sweetmelon.yaml'));
    if (!await yamlFile.exists()) {
      print('sweetmelon.yaml not found in $root');
      return 1;
    }
    final yaml = await yamlFile.readAsString();
    final current = ProjectSettings.readCore(yaml);
    final from = current == null ? null : parseCoreRequirement(current);

    if (from != null) {
      if (wanted.major != from.major && !allowMajor) {
        print('${from.major}.${from.minor} -> $target changes the major '
            'version and can break the app. Read the changelog, then add '
            '--allow-major.');
        return 1;
      }
      if (wanted.major == from.major &&
          wanted.minor != from.minor &&
          !allowMinor) {
        print('${from.major}.${from.minor} -> $target is a new minor release. '
            'Read the changelog, then add --allow-minor.');
        return 1;
      }
    }

    final writer =
        SafeWriter(root: root, dryRun: !apply, requireCleanGit: false);
    final newCore = '${wanted.major}.${wanted.minor}';
    final updatedYaml = _setCore(yaml, newCore);
    if (updatedYaml != yaml) writer.replace('sweetmelon.yaml', updatedYaml);

    final workflows = Directory(p.join(root, '.github', 'workflows'));
    if (await workflows.exists()) {
      await for (final entity in workflows.list()) {
        if (entity is! File || !entity.path.endsWith('.yml')) continue;
        final text = await entity.readAsString();
        final out = text.replaceAll(_pin, 'legionir/sweetmelon@v$target');
        if (out != text) {
          writer.replace(
              p.relative(entity.path, from: root).replaceAll('\\', '/'), out);
        }
      }
    }

    print('Core ${current ?? '(none)'} -> $target');
    final changes = await writer.commit();
    if (changes.isEmpty) {
      print('Nothing to change.');
      return 0;
    }
    for (final change in changes) {
      print('  $change');
    }
    print(apply
        ? 'Written. Changelog: '
            'https://github.com/legionir/sweetmelon/blob/main/CHANGELOG.md'
        : 'Dry run. Run again with --apply to write.');
    return 0;
  }

  static CoreRequirement? _parse(String text) {
    final parts = text.split('.');
    if (parts.length != 3) return null;
    return parseCoreRequirement(text);
  }

  static String _setCore(String yaml, String core) {
    final line = RegExp(r'^core:.*$', multiLine: true);
    if (line.hasMatch(yaml)) return yaml.replaceFirst(line, 'core: "$core"');
    return 'core: "$core"\n\n$yaml';
  }
}
