// ignore_for_file: avoid_print

import 'dart:io';

import 'package:sweetmelon/cli/config_processor.dart';
import 'package:sweetmelon/cli/safe_writer.dart';

/// Legacy entry point. Same as `dart run bin/sweetmelon.dart configure`.
/// اجرا: dart run bin/configure.dart [--dry-run]
Future<void> main(List<String> args) async {
  print('🍈 Sweetmelon Configuration Tool');
  print('');

  final processor = ConfigProcessor();
  await processor.load();
  processor.printSummary();

  if (args.contains('--dry-run')) {
    print('');
    print('ℹ️  Dry run mode — no files generated');
    await processor.generateDependencyReport();
    return;
  }

  print('');
  final writer = SafeWriter(
    gitStatus: gitPorcelainStatus,
    requireCleanGit: true,
  );
  await processor.generateServiceLocator(writer);
  try {
    await writer.commit();
  } on StateError catch (e) {
    print('❌ Not written: ${e.message}');
    exitCode = 1;
    return;
  }
  print('');
  print('Pubspec, permissions, app name and web titles: '
      'dart run bin/sweetmelon.dart sync --apply');
}
