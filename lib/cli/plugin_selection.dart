import 'package:yaml/yaml.dart';

/// How the plugins of a build are chosen.
enum SelectionMode {
  /// The plugins the application code uses, found by `sweetmelon detect`,
  /// plus [PluginSelection.include], minus [PluginSelection.exclude].
  auto,

  /// Only what sweetmelon.yaml says: the `plugins:` flags, or
  /// [PluginSelection.include] when the file has no `plugins:` flags.
  manual,
}

/// The `plugin_selection:` section of sweetmelon.yaml.
///
/// ```yaml
/// plugin_selection:
///   mode: auto          # auto | manual
///   include: [camera]   # always on, for calls the scanner cannot see
///   exclude: [nfc]      # always off
/// ```
class PluginSelection {
  const PluginSelection({
    this.mode = SelectionMode.manual,
    this.include = const [],
    this.exclude = const [],
  });

  final SelectionMode mode;
  final List<String> include;
  final List<String> exclude;

  /// A file without the section keeps today's behaviour: the `plugins:` flags
  /// decide.
  static const PluginSelection manualDefault = PluginSelection();

  /// Reads the section. Missing or malformed parts fall back to the defaults;
  /// the validator reports the problems.
  static PluginSelection fromYaml(String text) {
    final YamlNode? doc;
    try {
      doc = loadYamlNode(text);
    } catch (_) {
      return manualDefault;
    }
    if (doc is! YamlMap) return manualDefault;
    final section = doc['plugin_selection'];
    if (section is! YamlMap) return manualDefault;

    List<String> names(Object? value) => value is YamlList
        ? [
            for (final v in value)
              if (v is String) v
          ]
        : const <String>[];

    return PluginSelection(
      mode:
          section['mode'] == 'auto' ? SelectionMode.auto : SelectionMode.manual,
      include: names(section['include']),
      exclude: names(section['exclude']),
    );
  }
}
