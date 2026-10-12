import 'package:yaml/yaml.dart';

enum IssueSeverity { error, warning }

class ConfigIssue {
  const ConfigIssue(this.severity, this.message, {this.line});

  final IssueSeverity severity;
  final String message;

  /// 1-based line in sweetmelon.yaml, when it is known.
  final int? line;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() {
    final tag = isError ? 'ERROR' : 'WARN ';
    final where = line == null ? '' : 'line $line: ';
    return '$tag $where$message';
  }
}

/// Checks the structure of sweetmelon.yaml. It never changes the file.
class ConfigValidator {
  const ConfigValidator({this.knownPluginKeys});

  /// Plugin keys the build understands (see tool/plugin_catalog.json).
  /// When null, unknown plugin keys are not reported.
  final Set<String>? knownPluginKeys;

  static const _rootKeys = {'project', 'plugins'};

  static const _projectKeys = {
    'name',
    'display_name',
    'version',
    'min_sdk',
    'application_id',
    'www_path',
    'entry_point',
  };

  static const _pluginKeys = {'enabled'};

  static final _nameRe = RegExp(r'^[a-z][a-z0-9_]*$');
  static final _versionRe = RegExp(r'^\d+\.\d+\.\d+(\+\d+)?$');
  static final _appIdRe = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$');

  /// Returns every problem found. An empty list means the file is valid.
  List<ConfigIssue> validate(String source) {
    final issues = <ConfigIssue>[];

    final YamlNode? parsed = _parse(source, issues);
    if (parsed == null) return issues;
    if (parsed is! YamlMap) {
      issues.add(const ConfigIssue(
        IssueSeverity.error,
        'the file must be a mapping with "project" and "plugins" sections',
      ));
      return issues;
    }
    final root = parsed;

    _checkUnknownKeys(root, _rootKeys, 'the top level', issues);

    final project = root['project'];
    if (project is YamlMap) {
      _checkProject(project, issues);
    } else {
      issues.add(ConfigIssue(
        IssueSeverity.error,
        'missing "project" mapping',
        line: _line(root, 'project'),
      ));
    }

    final plugins = root['plugins'];
    if (plugins is YamlMap) {
      _checkPlugins(plugins, issues);
    } else {
      issues.add(ConfigIssue(
        IssueSeverity.error,
        'missing "plugins" mapping',
        line: _line(root, 'plugins'),
      ));
    }

    return issues;
  }

  YamlNode? _parse(String source, List<ConfigIssue> issues) {
    try {
      return loadYamlNode(source);
    } catch (e) {
      issues.add(ConfigIssue(IssueSeverity.error, 'invalid YAML: $e'));
      return null;
    }
  }

  void _checkProject(YamlMap project, List<ConfigIssue> issues) {
    _checkUnknownKeys(project, _projectKeys, 'project', issues);

    final name = project['name'];
    if (name is! String || !_nameRe.hasMatch(name)) {
      issues.add(ConfigIssue(
        IssueSeverity.error,
        'project.name must use lowercase letters, digits and underscores, '
        'and start with a letter',
        line: _line(project, 'name'),
      ));
    }

    final displayName = project['display_name'];
    if (displayName is! String || displayName.trim().isEmpty) {
      issues.add(ConfigIssue(
        IssueSeverity.error,
        'project.display_name is required (it is shown under the app icon)',
        line: _line(project, 'display_name'),
      ));
    }

    final version = project['version'];
    if (version is! String || !_versionRe.hasMatch(version)) {
      issues.add(ConfigIssue(
        IssueSeverity.error,
        'project.version must look like 1.2.3 or 1.2.3+4 (quote it if needed)',
        line: _line(project, 'version'),
      ));
    }

    final appId = project['application_id'];
    if (appId != null) {
      if (appId is! String || !_appIdRe.hasMatch(appId)) {
        issues.add(ConfigIssue(
          IssueSeverity.error,
          'project.application_id must look like com.company.app '
          '(lowercase, at least two parts)',
          line: _line(project, 'application_id'),
        ));
      } else if (appId.startsWith('com.example.')) {
        issues.add(ConfigIssue(
          IssueSeverity.warning,
          'project.application_id uses com.example; change it before publishing',
          line: _line(project, 'application_id'),
        ));
      }
    }
  }

  void _checkPlugins(YamlMap plugins, List<ConfigIssue> issues) {
    final known = knownPluginKeys;
    for (final key in plugins.keys) {
      final name = key.toString();
      final line = _line(plugins, key);

      if (known != null && !known.contains(name)) {
        final suggestion = _closest(name, known);
        final hint = suggestion == null ? '' : ' - did you mean "$suggestion"?';
        issues.add(ConfigIssue(
          IssueSeverity.error,
          'unknown plugin "$name"$hint',
          line: line,
        ));
        continue;
      }

      final settings = plugins[key];
      if (settings == null) continue;
      if (settings is! YamlMap) {
        issues.add(ConfigIssue(
          IssueSeverity.error,
          'plugin "$name" must be a mapping, for example "enabled: true"',
          line: line,
        ));
        continue;
      }

      _checkUnknownKeys(settings, _pluginKeys, 'plugin "$name"', issues);

      final enabled = settings['enabled'];
      if (enabled != null && enabled is! bool) {
        issues.add(ConfigIssue(
          IssueSeverity.error,
          'plugin "$name": enabled must be true or false',
          line: _line(settings, 'enabled'),
        ));
      }
    }
  }

  void _checkUnknownKeys(
    YamlMap map,
    Set<String> allowed,
    String where,
    List<ConfigIssue> issues,
  ) {
    for (final key in map.keys) {
      if (!allowed.contains(key.toString())) {
        issues.add(ConfigIssue(
          IssueSeverity.warning,
          'unknown key "$key" in $where',
          line: _line(map, key),
        ));
      }
    }
  }

  int? _line(YamlMap map, Object key) {
    final node = map.nodes[key];
    return node == null ? null : node.span.start.line + 1;
  }

  String? _closest(String name, Set<String> candidates) {
    String? best;
    var bestDistance = 4; // suggest only names up to 3 edits away
    for (final candidate in candidates) {
      final distance = _editDistance(name, candidate);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = candidate;
      }
    }
    return best;
  }
}

int _editDistance(String a, String b) {
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0);
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = current[j - 1] + 1;
      if (previous[j] + 1 < best) best = previous[j] + 1;
      if (previous[j - 1] + cost < best) best = previous[j - 1] + cost;
      current[j] = best;
    }
    previous = current;
  }
  return previous[b.length];
}
