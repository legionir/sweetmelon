// ignore_for_file: avoid_print
import 'dart:io';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:sweetmelon/core_version.dart';
import 'package:sweetmelon/cli/app_scaffold.dart';
import 'package:sweetmelon/cli/config_processor.dart';
import 'package:sweetmelon/cli/config_validator.dart';
import 'package:sweetmelon/cli/plugin_catalog.dart';
import 'package:sweetmelon/cli/plugin_detect.dart';
import 'package:sweetmelon/cli/prepare_runner.dart';
import 'package:sweetmelon/cli/safe_writer.dart';
import 'package:sweetmelon/cli/sync_runner.dart';
import 'package:sweetmelon/cli/tool_runners.dart';
import 'package:sweetmelon/cli/version_bump.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addCommand('create')
    ..addCommand('plugin')
    ..addCommand(
      'configure',
      ArgParser()
        ..addFlag('dry-run',
            negatable: false, help: 'Report generated changes without writing')
        ..addFlag('force',
            negatable: false, help: 'Write with uncommitted git changes'),
    )
    ..addCommand('validate')
    ..addCommand('list')
    ..addCommand('info')
    ..addCommand('build')
    ..addCommand('clean')
    ..addCommand('doctor')
    ..addCommand(
      'sync',
      ArgParser()
        ..addFlag('apply', negatable: false, help: 'Write the changes')
        ..addFlag('check',
            negatable: false,
            help: 'Exit 1 when files are out of date (writes nothing)')
        ..addFlag('force',
            negatable: false, help: 'Write even with uncommitted git changes'),
    )
    ..addCommand(
      'rename',
      ArgParser()
        ..addOption('id',
            help: 'New application id, e.g. com.acme.app. Defaults to '
                'project.application_id')
        ..addOption('dart-package',
            help: 'New Dart package name, e.g. my_app. Renames pubspec name '
                'and all package imports; without --id the application id '
                'is left alone')
        ..addFlag('apply', negatable: false, help: 'Write the changes')
        ..addFlag('force',
            negatable: false, help: 'Write even with uncommitted git changes'),
    )
    ..addCommand(
      'prepare',
      ArgParser()
        ..addOption('www',
            help: 'Folder with the app (index.html, js, css) copied into '
                'assets/www')
        ..addOption('package-name',
            help: 'Android applicationId / iOS bundle id, e.g. com.acme.app')
        ..addOption('dart-package', help: 'Dart package name, e.g. my_app')
        ..addOption('app-name', help: 'Name shown under the app icon')
        ..addOption('icon', help: 'Square PNG, 1024 px or more')
        ..addFlag('strict',
            negatable: false,
            help: 'In plugin_selection auto mode, fail on calls whose '
                'plugin cannot be determined')
        ..addFlag('apply', negatable: false, help: 'Write the changes'),
    )
    ..addCommand(
      'init',
      ArgParser()
        ..addOption('package-name',
            help: 'Android package name, e.g. com.acme.app')
        ..addOption('app-name', help: 'Name shown under the icon')
        ..addOption('dart-package',
            help: 'Dart package name (default: last part of the package name)')
        ..addFlag('apply', negatable: false, help: 'Write the files'),
    )
    ..addCommand(
      'upgrade',
      ArgParser()
        ..addOption('to', help: 'Exact core version, e.g. 2.4.1')
        ..addFlag('allow-minor',
            negatable: false, help: 'Allow a new minor release (2.4 -> 2.5)')
        ..addFlag('allow-major',
            negatable: false, help: 'Allow a new major release (2 -> 3)')
        ..addFlag('apply', negatable: false, help: 'Write the changes'),
    )
    ..addCommand(
      'detect',
      ArgParser()
        ..addOption('www', help: 'Folder to scan (default assets/www)')
        ..addFlag('strict',
            negatable: false,
            help: 'Exit 1 when a call cannot be resolved to a plugin'),
    )
    ..addCommand(
      'icon',
      ArgParser()
        ..addFlag('apply', negatable: false, help: 'Write the changes')
        ..addFlag('force',
            negatable: false, help: 'Write even with uncommitted git changes'),
    )
    ..addCommand(
      'bump',
      ArgParser()
        ..addFlag('apply', negatable: false, help: 'Write the changes')
        ..addFlag('force',
            negatable: false, help: 'Write even with uncommitted git changes'),
    )
    ..addFlag('help', abbr: 'h', negatable: false)
    ..addFlag('version', abbr: 'v', negatable: false);

  final results = parser.parse(args);

  if (results['version'] as bool) {
    print('Sweetmelon CLI v$sweetmelonCoreVersion');
    return;
  }

  if (results['help'] as bool || results.command == null) {
    _printHelp();
    return;
  }

  final cli = SweetmelonCLI();
  final command = results.command!;

  switch (command.name) {
    case 'create':
      await cli.create(results.command!.arguments);
      break;
    case 'plugin':
      await cli.plugin(results.command!.arguments);
      break;
    case 'configure':
      exitCode = await cli.configure(command);
      break;
    case 'validate':
      await cli.validate(results.command!.arguments);
      break;
    case 'list':
      await cli.list(results.command!.arguments);
      break;
    case 'info':
      await cli.info(results.command!.arguments);
      break;
    case 'build':
      await cli.build(results.command!.arguments);
      break;
    case 'clean':
      await cli.clean(results.command!.arguments);
      break;
    case 'doctor':
      await cli.doctor(results.command!.arguments);
      break;
    case 'sync':
      exitCode = await cli.sync(command);
      break;
    case 'rename':
      exitCode = await cli.rename(command);
      break;
    case 'init':
      exitCode = await cli.init(command);
      break;
    case 'upgrade':
      exitCode = await cli.upgrade(command);
      break;
    case 'detect':
      exitCode = await DetectRunner()
          .run(www: command['www'] as String?, strict: command['strict'] as bool);
      break;
    case 'prepare':
      exitCode = await cli.prepare(command);
      break;
    case 'icon':
      exitCode = await cli.icon(command);
      break;
    case 'bump':
      exitCode = await cli.bump(command);
      break;
    default:
      _printHelp();
  }
}

void _printHelp() {
  print('''
🍈 Sweetmelon CLI — Flutter Native Bridge

Usage: dart run bin/sweetmelon.dart <command> [options]

Commands:
  create    Create a new Sweetmelon project or component
  plugin    Plugin management (add, remove, generate, list)
  configure Process sweetmelon.yaml and generate files
  validate  Validate project configuration
  list      List all available plugins
  info      Show info about a specific plugin
  build     Build www assets for deployment
  clean     Clean generated files and cache
  doctor    Check project health and dependencies
  sync      Sync pubspec, permissions, app name and web titles with
            sweetmelon.yaml (--apply to write, --check for CI)
  rename    Change the Android applicationId / iOS bundle id (--id) and the
            Dart package name (--dart-package) (--apply)
  init      Create a new app folder that builds with the core as an Action
            (init <folder> --package-name ... --app-name ... --apply)
  upgrade   Move an app to another core release (--to 2.4.1 --apply)
  detect    List the plugins the web app uses (--www dir, --strict)
  prepare   Get a checkout ready to build: inject www, choose plugins, set
            package name, Dart package, app name and icon, then sync (--apply)
  icon      Generate all app icons from a square PNG of 1024 px or more (--apply)
  bump      Bump the version: build | patch | minor | major (--apply)

Options:
  -h, --help      Show help
  -v, --version   Show version

Examples:
  dart run bin/sweetmelon.dart plugin generate MyPlugin
  dart run bin/sweetmelon.dart plugin enable camera bluetooth
  dart run bin/sweetmelon.dart plugin disable nfc
  dart run bin/sweetmelon.dart configure
  dart run bin/sweetmelon.dart validate
  dart run bin/sweetmelon.dart doctor
  dart run bin/sweetmelon.dart build --framework angular
  dart run bin/sweetmelon.dart sync --apply
  dart run bin/sweetmelon.dart sync --check
  dart run bin/sweetmelon.dart rename --id com.acme.app --apply
  dart run bin/sweetmelon.dart rename --dart-package my_app --apply
  dart run bin/sweetmelon.dart prepare --www my_www --package-name com.acme.app --apply
  dart run bin/sweetmelon.dart icon assets/icon.png --apply
  dart run bin/sweetmelon.dart bump patch --apply
''');
}

class SweetmelonCLI {
  // ── Create ──

  Future<void> create(List<String> args) async {
    if (args.isEmpty) {
      print('Usage: create <type> [name]');
      print('Types: project, plugin, screen, service');
      return;
    }

    final type = args[0];
    final name = args.length > 1 ? args[1] : null;

    switch (type) {
      case 'project':
        await _createProject(name ?? 'my_sweetmelon_app');
        break;
      case 'plugin':
        if (name == null) {
          print('Error: Plugin name required');
          print('Usage: create plugin <PluginName>');
          return;
        }
        await _generatePlugin(name);
        break;
      default:
        print('Unknown type: $type');
    }
  }

  Future<void> _createProject(String name) async {
    print('🍈 Creating Sweetmelon project: $name');

    // ساخت ساختار پوشه
    final dirs = [
      '$name/assets/www/css',
      '$name/assets/www/js',
      '$name/lib/di',
      '$name/lib/screens',
      '$name/test',
    ];

    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }

    // کپی template files
    await _writeFile(
      '$name/sweetmelon.yaml',
      _projectConfigTemplate(name),
    );

    await _writeFile(
      '$name/assets/www/index.html',
      _indexHtmlTemplate(name),
    );

    print('✅ Project created: $name');
    print('');
    print('Next steps:');
    print('  cd $name');
    print('  dart run bin/sweetmelon.dart configure');
    print('  flutter pub get');
    print('  flutter run');
  }

  // ── Plugin ──

  Future<void> plugin(List<String> args) async {
    if (args.isEmpty) {
      print('Usage: plugin <subcommand> [args]');
      print('Subcommands: generate, enable, disable, list, info');
      return;
    }

    final sub = args[0];
    final rest = args.sublist(1);

    switch (sub) {
      case 'generate':
        if (rest.isEmpty) {
          print('Usage: plugin generate <PluginName>');
          return;
        }
        await _generatePlugin(rest[0]);
        break;
      case 'enable':
        if (rest.isEmpty) {
          print('Usage: plugin enable <plugin1> [plugin2] ...');
          return;
        }
        await _setPlugins(rest, true);
        break;
      case 'disable':
        if (rest.isEmpty) {
          print('Usage: plugin disable <plugin1> [plugin2] ...');
          return;
        }
        await _setPlugins(rest, false);
        break;
      case 'list':
        await list(rest);
        break;
      case 'info':
        if (rest.isEmpty) {
          print('Usage: plugin info <plugin_name>');
          return;
        }
        await info(rest);
        break;
      default:
        print('Unknown subcommand: $sub');
    }
  }

  Future<void> _generatePlugin(String name) async {
    print('🔌 Generating plugin: $name');

    final id = _toSnakeCase(name);
    final className = '${name}Plugin';
    final dir = 'lib/plugins/$id';

    await Directory('$dir/lib').create(recursive: true);

    await _writeFile(
      '$dir/lib/${id}_plugin.dart',
      _pluginDartTemplate(name, className, id),
    );

    await _writeFile(
      '$dir/pubspec.yaml',
      _pluginPubspecTemplate(id, name),
    );

    await _writeFile(
      '$dir/README.md',
      _pluginReadmeTemplate(name, id),
    );

    // ساخت تست
    await Directory('test/plugins').create(recursive: true);
    await _writeFile(
      'test/plugins/${id}_plugin_test.dart',
      _pluginTestTemplate(name, className, id),
    );

    print('✅ Plugin generated:');
    print('  📄 $dir/lib/${id}_plugin.dart');
    print('  📄 $dir/pubspec.yaml');
    print('  📄 $dir/README.md');
    print('  🧪 test/plugins/${id}_plugin_test.dart');
    print('');
    print('Next steps:');
    print('  1. Implement onCall() in ${id}_plugin.dart');
    print('  2. Register in lib/di/service_locator.dart');
    print('  3. Add to sweetmelon.yaml');
    print('  4. Add JS wrapper to assets/www/js/native-sdk.js');
    print('  5. Run: dart run bin/sweetmelon.dart configure');
  }

  Future<void> _setPlugins(List<String> pluginIds, bool enabled) async {
    final file = File('sweetmelon.yaml');
    if (!await file.exists()) {
      print('❌ sweetmelon.yaml not found');
      return;
    }

    var content = await file.readAsString();
    int changed = 0;

    for (final id in pluginIds) {
      final pattern = RegExp(
        r'(\s+' + id + r':\s*\n\s+enabled:\s*)(true|false)',
        multiLine: true,
      );

      if (pattern.hasMatch(content)) {
        content = content.replaceAllMapped(pattern, (m) {
          return '${m.group(1)}$enabled';
        });
        print('${enabled ? "✅" : "❌"} ${id.padRight(25)} → ${enabled ? "enabled" : "disabled"}');
        changed++;
      } else {
        print('⚠️  Plugin not found in config: $id');
      }
    }

    if (changed > 0) {
      await file.writeAsString(content);
      print('');
      print('Run "dart run bin/sweetmelon.dart configure" to apply changes.');
    }
  }

  // ── Configure ──

  Future<int> configure(ArgResults args) async {
    final dryRun = args['dry-run'] as bool;
    final force = args['force'] as bool;
    print('🔧 Processing sweetmelon.yaml...');

    if (dryRun) {
      print('ℹ️  Dry run — no files will be written');
    }

    return _runConfigProcessor(dryRun: dryRun, force: force);
  }

  Future<int> _runConfigProcessor({
    bool dryRun = false,
    bool force = false,
  }) async {
    final file = File('sweetmelon.yaml');
    if (!await file.exists()) {
      print('❌ sweetmelon.yaml not found');
      return 1;
    }

    final content = await file.readAsString();
    final yaml = loadYaml(content) as YamlMap;
    final plugins = yaml['plugins'] as YamlMap?;

    if (plugins == null) {
      print('❌ No plugins section in sweetmelon.yaml');
      return 1;
    }

    final enabled = <String>[];
    final disabled = <String>[];

    for (final entry in plugins.entries) {
      final id = entry.key.toString();
      final config = entry.value as YamlMap?;
      final isEnabled = config?['enabled'] as bool? ?? true;

      if (isEnabled) {
        enabled.add(id);
      } else {
        disabled.add(id);
      }
    }

    print('');
    print('✅ Enabled (${enabled.length}): ${enabled.join(", ")}');
    print('❌ Disabled (${disabled.length}): ${disabled.join(", ")}');
    print('');

    final processor = ConfigProcessor();
    await processor.load();
    final writer = SafeWriter(
      dryRun: dryRun,
      gitStatus: gitPorcelainStatus,
      requireCleanGit: !force,
    );
    await processor.generateServiceLocator(writer);
    try {
      final changes = await writer.commit();
      for (final change in changes) {
        print('  $change');
      }
    } on StateError catch (e) {
      print('❌ Not written: ${e.message}');
      return 1;
    }
    print('');
    if (dryRun) {
      print('ℹ️  Dry run complete. Run without --dry-run to write the changes.');
    } else {
      print('ℹ️  Pubspec, permissions, app name and web titles are synced by:');
      print('   dart run bin/sweetmelon.dart sync --apply');
    }
    return 0;
  }

  // ── Validate ──

  Future<void> validate(List<String> args) async {
    print('🔍 Validating Sweetmelon project...');
    print('');

    final issues = <String>[];
    final warnings = <String>[];

    // بررسی فایل‌های ضروری
    final requiredFiles = [
      'sweetmelon.yaml',
      'pubspec.yaml',
      'lib/main.dart',
      'lib/app.dart',
      'assets/www/index.html',
      'lib/di/service_locator.dart',
    ];

    for (final f in requiredFiles) {
      if (!await File(f).exists()) {
        issues.add('Missing required file: $f');
      } else {
        print('✅ $f');
      }
    }

    // بررسی sweetmelon.yaml
    if (await File('sweetmelon.yaml').exists()) {
      try {
        final content = await File('sweetmelon.yaml').readAsString();
        loadYaml(content);
        print('✅ sweetmelon.yaml is valid YAML');
      } catch (e) {
        issues.add('Invalid YAML in sweetmelon.yaml: $e');
      }
    }

    // بررسی ساختار sweetmelon.yaml (نام، نسخه، پلاگین‌های ناشناخته)
    if (await File('sweetmelon.yaml').exists()) {
      final catalog =
          await PluginCatalog.load(ConfigProcessor.pluginCatalogPath);
      if (catalog == null) {
        warnings.add('${ConfigProcessor.pluginCatalogPath} not found: '
            'unknown plugin names are not checked');
      }
      final configIssues = ConfigValidator(knownPluginKeys: catalog?.yamlKeys)
          .validate(await File('sweetmelon.yaml').readAsString());
      for (final issue in configIssues) {
        if (issue.isError) {
          issues.add('sweetmelon.yaml: $issue');
        } else {
          warnings.add('sweetmelon.yaml: $issue');
        }
      }
    }

    // بررسی assets/www
    final wwwDir = Directory('assets/www');
    if (await wwwDir.exists()) {
      final entities = await wwwDir.list(recursive: true).toList();
      print('✅ assets/www: ${entities.length} files');
    } else {
      warnings.add('assets/www directory not found — no web app will be served');
    }

    // بررسی native-sdk.js
    if (!await File('assets/www/js/native-sdk.js').exists()) {
      warnings.add('native-sdk.js not found in assets/www/js/');
    }

    // بررسی AndroidManifest
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    if (await manifest.exists()) {
      final content = await manifest.readAsString();
      if (!content.contains('android.permission.INTERNET')) {
        warnings.add('INTERNET permission not in AndroidManifest.xml');
      }
      print('✅ AndroidManifest.xml');
    } else {
      issues.add('AndroidManifest.xml not found');
    }

    print('');

    if (warnings.isNotEmpty) {
      print('⚠️  Warnings:');
      for (final w in warnings) {
        print('  • $w');
      }
      print('');
    }

    if (issues.isNotEmpty) {
      print('❌ Issues:');
      for (final issue in issues) {
        print('  • $issue');
      }
      print('');
      print('Fix these issues before running the app.');
      exit(1);
    } else {
      print('✅ Validation passed! Project looks good.');
    }
  }

  // ── List ──

  Future<void> list(List<String> args) async {

    print('🔌 Available Plugins (90 total)');
    print('');

    final phases = {
      'Phase 1 — Core': [
        'permission', 'appLifecycle', 'deviceInfo', 'connectivity',
        'storage', 'fileSystem', 'http', 'intent', 'clipboard', 'share',
        'camera', 'geolocation',
      ],
      'Phase 3 — UX': [
        'backButton', 'secureStorage', 'notification', 'statusBar',
        'orientation', 'haptic', 'keyboard',
      ],
      'Phase 4 — Media': [
        'biometrics', 'qrScanner', 'audio', 'smsOtp', 'downloadManager',
        'database', 'contacts', 'phoneDialer',
      ],
      'Phase 5 — Advanced': [
        'bluetooth', 'nfc', 'speechToText', 'textToSpeech', 'videoPlayer',
        'inAppBrowser', 'pdf', 'encryption',
      ],
      'Phase 6 — Realtime': ['websocket', 'backgroundTask'],
      'Phase 7 — Critical': [
        'dialog', 'toast', 'splashScreen', 'pushNotification',
        'wakeLock', 'cookieManager', 'cacheControl', 'appUpdate',
      ],
      'Phase 8 — UX+': [
        'filePicker', 'fileOpener', 'sensors', 'screenBrightness',
        'flashlight', 'navigationBar', 'privacyScreen', 'nativeSettings',
      ],
      'Phase 9 — Device': [
        'calendar', 'badge', 'foregroundService', 'backgroundGeolocation',
        'mediaManager', 'fileCompressor', 'zip', 'shareTarget',
      ],
      'Phase 10 — UX3': [
        'inAppReview', 'nativeMarket', 'screenshot', 'safeArea',
        'datePicker', 'actionSheet', 'textZoom', 'accessibility',
      ],
      'Phase 11 — Specialized': [
        'wifiManager', 'rootDetection', 'appIntegrity', 'alarm',
        'pedometer', 'shakeDetection', 'volumeButtons', 'simInfo',
        'kioskMode', 'intentLauncher', 'emailComposer',
      ],
      'Phase 16 — Firebase': [
        'firebaseAnalytics', 'firebaseCrashlytics',
        'firebaseRemoteConfig', 'firebaseAuth',
      ],
      'Phase 17 — Advanced+': [
        'cameraPreview', 'documentScanner', 'googleMaps',
        'socialLogin', 'inAppPurchase', 'oauth2',
      ],
    };

    for (final entry in phases.entries) {
      print('${entry.key}:');
      for (final plugin in entry.value) {
        print('  • $plugin');
      }
      print('');
    }
  }

  // ── Info ──

  Future<void> info(List<String> args) async {
    if (args.isEmpty) {
      print('Usage: info <plugin_name>');
      return;
    }

    final pluginName = args[0];
    print('🔌 Plugin Info: $pluginName');
    print('');
    print('See lib/plugins/$pluginName/ for implementation details.');
    print('See lib/plugins/$pluginName/README.md for API documentation.');
  }

  // ── Build ──

  Future<void> build(List<String> args) async {
    final framework = _getOption(args, '--framework') ?? 'html';
    final outputPath = _getOption(args, '--output') ?? 'assets/www';

    print('🏗  Building $framework project...');
    print('');

    switch (framework) {
      case 'angular':
        await _buildAngular(outputPath);
        break;
      case 'react':
        await _buildReact(outputPath);
        break;
      case 'vue':
        await _buildVue(outputPath);
        break;
      default:
        print('ℹ️  For HTML projects, just place files in assets/www/');
        print('   No build step required.');
    }
  }

  Future<void> _buildAngular(String outputPath) async {
    print('Building Angular project...');
    print('Running: ng build --configuration production \\');
    print('         --output-path $outputPath \\');
    print('         --base-href ./');
    print('');

    final result = await Process.run(
      'ng',
      [
        'build',
        '--configuration', 'production',
        '--output-path', outputPath,
        '--base-href', './',
      ],
    );

    if (result.exitCode == 0) {
      print('✅ Angular build successful!');
      print('   Output: $outputPath');
    } else {
      print('❌ Angular build failed:');
      print(result.stderr);
    }
  }

  Future<void> _buildReact(String outputPath) async {
    print('Building React project...');
    final result = await Process.run('npx', ['react-scripts', 'build']);
    if (result.exitCode == 0) {
      await Process.run('cp', ['-r', 'build/.', outputPath]);
      print('✅ React build successful!');
    } else {
      print('❌ React build failed');
    }
  }

  Future<void> _buildVue(String outputPath) async {
    print('Building Vue project...');
    final result = await Process.run('npx', ['vue-cli-service', 'build']);
    if (result.exitCode == 0) {
      await Process.run('cp', ['-r', 'dist/.', outputPath]);
      print('✅ Vue build successful!');
    } else {
      print('❌ Vue build failed');
    }
  }

  // ── Clean ──

  Future<void> clean(List<String> args) async {
    print('🧹 Cleaning...');

    final toClean = [
      'build/',
      '.dart_tool/',
      'lib/di/service_locator.g.dart',
      'android/generated_permissions.xml',
      'ios/generated_permissions.xml',
    ];

    for (final path in toClean) {
      final entity = File(path);
      final dir = Directory(path);

      if (await entity.exists()) {
        await entity.delete();
        print('🗑  Deleted: $path');
      } else if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('🗑  Deleted: $path');
      }
    }

    print('✅ Clean complete!');
  }

  // ── Doctor ──

  /// Brings pubspec.yaml, the Android manifest and Info.plist in line with
  /// the plugins enabled in sweetmelon.yaml. Dry run unless --apply.
  Future<int> sync(ArgResults args) async {
    final check = args['check'] as bool;
    return SyncRunner().run(
      SyncOptions(
        apply: args['apply'] as bool,
        force: args['force'] as bool,
      ),
      check: check,
    );
  }

  /// `rename [--id <id>] [--dart-package <name>] [--apply] [--force]`
  ///
  /// With `--dart-package` only the Dart package is renamed, unless `--id` is
  /// given too. Without either option the application id from sweetmelon.yaml
  /// is applied.
  Future<int> rename(ArgResults args) async {
    final dartPackage = args['dart-package'] as String?;
    final newId = args['id'] as String?;
    final apply = args['apply'] as bool;
    final force = args['force'] as bool;

    var ranIdRename = false;
    if (dartPackage == null || newId != null) {
      final code =
          await RenameRunner().run(newId: newId, apply: apply, force: force);
      if (code != 0 || dartPackage == null) return code;
      ranIdRename = true;
    }
    // After the first step wrote its files the working tree is dirty because
    // of this very command, so the second step must not refuse for that.
    return DartPackageRenameRunner().run(
      dartPackage,
      apply: apply,
      force: force || (apply && ranIdRename),
    );
  }

  /// `init <folder> --package-name id --app-name name [--dart-package n]`
  Future<int> init(ArgResults args) async {
    final packageName = args['package-name'] as String?;
    final appName = args['app-name'] as String?;
    if (args.rest.length != 1 || packageName == null || appName == null) {
      print('Usage: sweetmelon init <folder> --package-name com.acme.app '
          '--app-name "My App" [--dart-package my_app] [--apply]');
      return 64;
    }
    return InitRunner().run(
      args.rest.single,
      appName: appName,
      applicationId: packageName,
      dartPackage: args['dart-package'] as String?,
      apply: args['apply'] as bool,
    );
  }

  /// `upgrade --to 2.4.1 [--allow-minor] [--allow-major] [--apply]`
  Future<int> upgrade(ArgResults args) async {
    final to = args['to'] as String?;
    if (to == null) {
      print('Usage: sweetmelon upgrade --to 2.4.1 [--apply]');
      return 64;
    }
    return UpgradeRunner().run(
      to,
      apply: args['apply'] as bool,
      allowMinor: args['allow-minor'] as bool,
      allowMajor: args['allow-major'] as bool,
    );
  }

  /// `prepare [--www dir] [--package-name id] [--dart-package name]
  /// [--app-name name] [--icon file] [--apply]`
  Future<int> prepare(ArgResults args) => PrepareRunner().run(
        PrepareOverrides(
          www: args['www'] as String?,
          applicationId: args['package-name'] as String?,
          dartPackage: args['dart-package'] as String?,
          appName: args['app-name'] as String?,
          icon: args['icon'] as String?,
        ),
        apply: args['apply'] as bool,
        strict: args['strict'] as bool,
      );

  /// `icon <source.png> [--apply] [--force]`
  Future<int> icon(ArgResults args) async {
    if (args.rest.length != 1) {
      print('Usage: sweetmelon icon <square PNG, at least 1024 px> [--apply]');
      return 64;
    }
    return IconRunner().run(
      args.rest.single,
      apply: args['apply'] as bool,
      force: args['force'] as bool,
    );
  }

  /// `bump <build|patch|minor|major> [--apply] [--force]`
  Future<int> bump(ArgResults args) async {
    final kinds = {
      'build': BumpKind.build,
      'patch': BumpKind.patch,
      'minor': BumpKind.minor,
      'major': BumpKind.major,
    };
    final kind = args.rest.length == 1 ? kinds[args.rest.single] : null;
    if (kind == null) {
      print('Usage: sweetmelon bump <build|patch|minor|major> [--apply]');
      return 64;
    }
    return BumpRunner().run(
      kind,
      apply: args['apply'] as bool,
      force: args['force'] as bool,
    );
  }

  /// Environment checks, then the project checks from DoctorRunner.
  Future<void> doctor(List<String> args) async {
    print('🩺 Sweetmelon Doctor');
    print('════════════════════');
    print('');

    final checks = <String, Future<_DoctorCheck> Function()>{
      'Flutter SDK': _checkFlutter,
      'Dart SDK': _checkDart,
      'Android SDK': _checkAndroid,
      'native-sdk.js': _checkNativeSDK,
    };

    var failed = 0;
    for (final entry in checks.entries) {
      final check = await entry.value();
      print('${_icon(check.status)} ${entry.key}: ${check.message}');
      if (check.hint != null) print('   Hint: ${check.hint}');
      if (check.status == _DoctorStatus.error) failed++;
    }

    print('');
    print('Project');
    print('───────');
    final projectCode = await DoctorRunner().run();
    if (failed > 0 || projectCode != 0) {
      exitCode = 1;
    } else {
      print('');
      print('🎉 All checks passed! Your project is healthy.');
    }
  }

  String _icon(_DoctorStatus status) => switch (status) {
        _DoctorStatus.ok => '✅',
        _DoctorStatus.warning => '⚠️ ',
        _DoctorStatus.error => '❌',
      };

  Future<_DoctorCheck> _checkFlutter() async {
    final result = await Process.run('flutter', ['--version']);
    if (result.exitCode == 0) {
      final version = result.stdout.toString().split('\n').first;
      return _DoctorCheck.ok(version);
    }
    return _DoctorCheck.error(
      'Flutter not found',
      hint: 'Install Flutter from https://flutter.dev',
    );
  }

  Future<_DoctorCheck> _checkDart() async {
    final result = await Process.run('dart', ['--version']);
    if (result.exitCode == 0) {
      return _DoctorCheck.ok(result.stdout.toString().trim());
    }
    return _DoctorCheck.error('Dart not found');
  }

  Future<_DoctorCheck> _checkAndroid() async {
    final path = Platform.environment['ANDROID_HOME'] ??
        Platform.environment['ANDROID_SDK_ROOT'];
    if (path != null && await Directory(path).exists()) {
      return _DoctorCheck.ok('Found at $path');
    }
    return _DoctorCheck.warning(
      'ANDROID_HOME not set',
      hint: 'Set ANDROID_HOME environment variable',
    );
  }

  Future<_DoctorCheck> _checkNativeSDK() async {
    if (await File('assets/www/js/native-sdk.js').exists()) {
      return _DoctorCheck.ok('native-sdk.js found');
    }
    return _DoctorCheck.error(
      'native-sdk.js not found',
      hint: 'Copy native-sdk.js to assets/www/js/',
    );
  }

  // ── Helpers ──

  Future<void> _writeFile(String path, String content) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(content);
  }

  String? _getOption(List<String> args, String option) {
    final idx = args.indexOf(option);
    if (idx == -1 || idx + 1 >= args.length) return null;
    return args[idx + 1];
  }

  String _toSnakeCase(String name) {
    return name
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (m) => '_${m.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  // ── Templates ──

  String _pluginDartTemplate(
    String name,
    String className,
    String id,
  ) => '''
import 'dart:async';

import 'package:sweetmelon/packages/core/lib/core.dart';
import 'package:sweetmelon/packages/plugin_engine/lib/plugin_engine.dart';

typedef ${name}EventEmitter = Future<void> Function(String event, dynamic data);

class $className extends BasePlugin {
  final ${name}EventEmitter? eventEmitter;

  $className({this.eventEmitter});

  @override
  String get name => '$id';

  @override
  String get version => '1.0.0';

  @override
  String get description => '$name plugin';

  @override
  List<String> get supportedMethods => [
        'doSomething',
        'getInfo',
      ];

  // Uncomment if permissions needed:
  // @override
  // List<String> get requiredPermissions => ['camera'];

  @override
  Future<void> onInitialize() async {
    logInfo('Plugin initialized');
  }

  @override
  Future<void> onDispose() async {
    logInfo('Plugin disposed');
  }

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'doSomething':
        return _doSomething(args);
      case 'getInfo':
        return {
          'name': name,
          'version': version,
        };
      default:
        throw UnsupportedError('Method "\$method" not supported');
    }
  }

  Future<Map<String, dynamic>> _doSomething(
    Map<String, dynamic> args,
  ) async {
    // TODO: implement
    return {'done': true};
  }

  @override
  Future<ValidationResult> validateArgs(
    String method,
    Map<String, dynamic> args,
  ) async {
    switch (method) {
      case 'doSomething':
        // TODO: add validation
        return ValidationResult.valid();
      default:
        return ValidationResult.valid();
    }
  }
}
''';

  String _pluginPubspecTemplate(String id, String name) => '''
name: ${id}_plugin
description: $name plugin for Sweetmelon
version: 1.0.0

environment:
  sdk: ^3.0.0

dependencies:
  flutter:
    sdk: flutter
  plugin_engine:
    path: ../../packages/plugin_engine
  core:
    path: ../../packages/core
''';

  String _pluginReadmeTemplate(String name, String id) => '''
# $name Plugin

## Plugin Name
`$id`

## Methods

### `doSomething`
Description of what this method does.

**Args:**
| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `param1` | `string` | ✅ | Description |

**Returns:**
```json
{ "done": true }
```

## Usage
```javascript
const result = await NativeSDK.$id.doSomething({ param1: 'value' });
```
''';

  String _pluginTestTemplate(
    String name,
    String className,
    String id,
  ) => '''
import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/plugins/$id/lib/${id}_plugin.dart';
import '../helpers/plugin_test_utils.dart';

void main() {
  group('$className', () {
    late $className plugin;

    setUp(() async {
      plugin = $className();
      await plugin.initialize();
    });

    tearDown(() async => await plugin.dispose());

    test('info', () async {
      await PluginTestUtils.testPluginInfo(
        plugin,
        expectedName: '$id',
        expectedVersion: '1.0.0',
      );
    });

    test('getInfo', () async {
      await PluginTestUtils.testGetInfo(plugin);
    });

    test('unsupported method throws', () async {
      await PluginTestUtils.testUnsupportedMethod(plugin);
    });

    test('doSomething returns done', () async {
      final result = await plugin.onCall('doSomething', {});
      expect(result['done'], true);
    });
  });
}
''';

  String _projectConfigTemplate(String name) => '''
project:
  name: $name
  version: 1.0.0

plugins:
  # Phase 1 - Core
  permission:
    enabled: true
  appLifecycle:
    enabled: true
  deviceInfo:
    enabled: true
  connectivity:
    enabled: true
  storage:
    enabled: true
  fileSystem:
    enabled: true
  http:
    enabled: true
  intent:
    enabled: true
  clipboard:
    enabled: true
  share:
    enabled: true
  camera:
    enabled: false
  geolocation:
    enabled: false
''';

  String _indexHtmlTemplate(String name) => '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$name</title>
</head>
<body>
  <h1>$name</h1>
  <p>Your Sweetmelon app is ready!</p>
  
  <script src="js/native-sdk.js"></script>
  <script>
    NativeSDK.waitForReady().then(function() {
      console.log('Bridge ready!');
      NativeSDK.deviceInfo.getAll().then(function(info) {
        document.body.innerHTML += '<p>Device: ' + info.device.model + '</p>';
      });
    });
  </script>
</body>
</html>
''';
}

enum _DoctorStatus { ok, warning, error }

class _DoctorCheck {
  final _DoctorStatus status;
  final String message;
  final String? hint;

  const _DoctorCheck({
    required this.status,
    required this.message,
    this.hint,
  });

  factory _DoctorCheck.ok(String message) =>
      _DoctorCheck(status: _DoctorStatus.ok, message: message);

  factory _DoctorCheck.warning(String message, {String? hint}) =>
      _DoctorCheck(status: _DoctorStatus.warning, message: message, hint: hint);

  factory _DoctorCheck.error(String message, {String? hint}) =>
      _DoctorCheck(status: _DoctorStatus.error, message: message, hint: hint);
}
