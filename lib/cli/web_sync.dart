import 'dart:convert';

/// Sets the `<title>` of an HTML page. Returns [html] unchanged when the page
/// has no title element.
String syncHtmlTitle(String html, String title) {
  return html.replaceFirst(
    RegExp(r'<title>[^<]*</title>'),
    '<title>${_htmlEscape(title)}</title>',
  );
}

/// Sets `name` and `short_name` of a web app manifest (manifest.json).
///
/// Only the two values are replaced; the rest of the file keeps its layout.
/// `short_name` is the name cut to 12 characters, because home screens show
/// short labels. Throws [FormatException] when [json] is not valid JSON.
String syncWebManifest(String json, {required String name}) {
  final decoded = jsonDecode(json);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('manifest.json must be a JSON object');
  }
  final shortName = name.length <= 12 ? name : name.substring(0, 12);

  var out = _replaceTopLevelString(json, 'name', name);
  out = _replaceTopLevelString(out, 'short_name', shortName);
  return out;
}

/// Replaces the value of the first `"key": "..."` line, or inserts the key
/// right after the opening brace when it is missing.
String _replaceTopLevelString(String json, String key, String value) {
  final encoded = jsonEncode(value);
  final pattern = RegExp(
      '^(\\s*)"${RegExp.escape(key)}"\\s*:\\s*"(?:[^"\\\\]|\\\\.)*"',
      multiLine: true);
  if (pattern.hasMatch(json)) {
    return json.replaceFirstMapped(
      pattern,
      (m) => '${m[1]!}"$key": $encoded',
    );
  }
  return json.replaceFirstMapped(
    RegExp(r'\{'),
    (m) => '{\n  "$key": $encoded,',
  );
}

String _htmlEscape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
