import 'package:sweetmelon/core_version.dart';

/// `2.6` for core 2.6.3: what `core:` in a sweetmelon.yaml names. Tests use it
/// instead of a literal, so a new minor release does not break them.
final String coreMinor = sweetmelonCoreVersion.split('.').take(2).join('.');
