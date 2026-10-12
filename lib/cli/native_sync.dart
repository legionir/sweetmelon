import 'text_blocks.dart';

/// Android and iOS permission entries, kept in step with the enabled plugins.
///
/// Rules, the same for both platforms:
/// - Only entries named in `managed` are touched. Anything else is left alone.
/// - A managed entry that is already in the file, outside the marker block, is
///   kept as it is (its text is not changed).
/// - A managed entry that is needed but missing is added inside the marker
///   block, with the text from the plugin registry.
/// - A managed entry that is not needed is removed, from inside or outside the
///   block.
/// - Running the same sync twice gives the same text.

const androidPermissionsOpen = '<!-- <sweetmelon:android-permissions> -->';
const androidPermissionsClose = '<!-- </sweetmelon:android-permissions> -->';
const androidFeaturesOpen = '<!-- <sweetmelon:android-features> -->';
const androidFeaturesClose = '<!-- </sweetmelon:android-features> -->';

const iosUsageOpen = '\t<!-- <sweetmelon:ios-usage> -->';
const iosUsageClose = '\t<!-- </sweetmelon:ios-usage> -->';

final _androidPermissionLine = RegExp(
  r'^[ \t]*<uses-permission android:name="([^"]+)"[^>]*/>[ \t]*\n?',
  multiLine: true,
);

final _androidFeatureLine = RegExp(
  r'^[ \t]*<uses-feature android:name="([^"]+)"[^>]*/>[ \t]*\n?',
  multiLine: true,
);

final _iosEntry = RegExp(
  r'^[ \t]*<key>([^<]+)</key>\n[ \t]*<string>[^<]*</string>[ \t]*\n?',
  multiLine: true,
);

/// Returns [manifest] with its `<uses-permission>` entries synced.
///
/// [managed]: permission names the registry knows about.
/// [desired]: permission names needed by enabled plugins, in order.
String syncAndroidPermissions(
  String manifest, {
  required Set<String> managed,
  required List<String> desired,
}) {
  final wanted = desired.toSet();
  final outside = _withoutBlock(
    manifest,
    androidPermissionsOpen,
    androidPermissionsClose,
  );

  final present = <String>{};
  final cleaned = outside.replaceAllMapped(_androidPermissionLine, (m) {
    final name = m.group(1)!;
    if (!managed.contains(name)) return m.group(0)!;
    if (wanted.contains(name)) {
      present.add(name);
      return m.group(0)!;
    }
    return '';
  });

  final toAdd = [
    for (final name in desired)
      if (!present.contains(name)) name
  ];
  if (toAdd.isEmpty) return cleaned;

  if (!cleaned.contains('    <application')) {
    throw StateError('AndroidManifest.xml has no <application> element');
  }
  final block = [
    androidPermissionsOpen,
    for (final name in toAdd) '    <uses-permission android:name="$name"/>',
    androidPermissionsClose,
  ];
  return cleaned.replaceFirst(
    '    <application',
    '${block.join('\n')}\n    <application',
  );
}

/// Returns [manifest] with its `<uses-feature>` entries synced.
///
/// Features follow the same ownership rules as permissions. This removes stale
/// hardware declarations (for example NFC) when their plugin is disabled.
String syncAndroidFeatures(
  String manifest, {
  required Set<String> managed,
  required List<String> desired,
}) {
  final wanted = desired.toSet();
  final outside = _withoutBlock(
    manifest,
    androidFeaturesOpen,
    androidFeaturesClose,
  );

  final present = <String>{};
  final cleaned = outside.replaceAllMapped(_androidFeatureLine, (match) {
    final name = match.group(1)!;
    if (!managed.contains(name)) return match.group(0)!;
    if (wanted.contains(name)) {
      present.add(name);
      return match.group(0)!;
    }
    return '';
  });

  final toAdd = [
    for (final name in desired)
      if (!present.contains(name)) name,
  ];
  if (toAdd.isEmpty) return cleaned;

  if (!cleaned.contains('    <application')) {
    throw StateError('AndroidManifest.xml has no <application> element');
  }
  final block = [
    androidFeaturesOpen,
    for (final name in toAdd)
      '    <uses-feature android:name="$name" android:required="false"/>',
    androidFeaturesClose,
  ];
  return cleaned.replaceFirst(
    '    <application',
    '${block.join('\n')}\n    <application',
  );
}

/// Returns [plist] (ios/Runner/Info.plist) with its usage-description keys
/// synced.
///
/// [managedKeys]: keys the registry knows about.
/// [desired]: key -> text, for the keys needed by enabled plugins. The text is
/// used only when the key is added; an existing text is never changed.
String syncIosUsageDescriptions(
  String plist, {
  required Set<String> managedKeys,
  required Map<String, String> desired,
}) {
  final outside = _withoutBlock(plist, iosUsageOpen, iosUsageClose);

  final present = <String>{};
  final cleaned = outside.replaceAllMapped(_iosEntry, (m) {
    final key = m.group(1)!;
    if (!managedKeys.contains(key)) return m.group(0)!;
    if (desired.containsKey(key)) {
      present.add(key);
      return m.group(0)!;
    }
    return '';
  });

  final toAdd = [
    for (final key in desired.keys)
      if (!present.contains(key)) key,
  ];
  if (toAdd.isEmpty) return cleaned;

  final end = cleaned.lastIndexOf('</dict>');
  if (end < 0) {
    throw StateError('Info.plist has no top-level </dict>');
  }
  final block = [
    iosUsageOpen,
    for (final key in toAdd)
      '\t<key>$key</key>\n\t<string>${_xmlEscape(desired[key]!)}</string>',
    iosUsageClose,
  ];
  return '${cleaned.substring(0, end)}${block.join('\n')}\n'
      '${cleaned.substring(end)}';
}

/// Names of the Android permissions in [manifest] that are inside the marker
/// block, or outside it. Used by the report.
List<String> androidPermissionNames(String manifest) {
  return [
    for (final m in _androidPermissionLine.allMatches(manifest)) m.group(1)!,
  ];
}

/// Names of the Android hardware features declared in [manifest].
List<String> androidFeatureNames(String manifest) {
  return [
    for (final m in _androidFeatureLine.allMatches(manifest)) m.group(1)!,
  ];
}

String _withoutBlock(String text, String open, String close) {
  final match =
      markedBlockPattern(open, close, consumeNewline: true).firstMatch(text);
  if (match == null) return text;
  return text.replaceRange(match.start, match.end, '');
}

String _xmlEscape(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
