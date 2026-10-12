// Marker blocks: the lines between an opening and a closing marker are owned
// by the CLI. Everything outside the markers is left alone.
//
// Dart and Gradle style: `// <sweetmelon:name>` ... `// </sweetmelon:name>`
// XML style:             `<!-- <sweetmelon:name> -->` ... `<!-- </...> -->`

/// Matches a whole marker block, including the marker lines. The block must
/// start at the beginning of a line (leading spaces or tabs are included).
RegExp markedBlockPattern(
  String openTag,
  String closeTag, {
  bool consumeNewline = false,
}) {
  return RegExp(
    '^[ \\t]*${RegExp.escape(openTag)}\\n.*?^[ \\t]*${RegExp.escape(closeTag)}'
    '${consumeNewline ? '\\n?' : ''}',
    multiLine: true,
    dotAll: true,
  );
}

/// Replaces the lines between the two markers with [body].
///
/// [indent] is written in front of both markers and of every body line; an
/// empty body line stays empty. Throws [StateError] if the markers are missing.
String replaceMarkedBlock(
  String text, {
  required String name,
  required String openTag,
  required String closeTag,
  required String indent,
  required List<String> body,
}) {
  final pattern = markedBlockPattern(openTag, closeTag);
  if (!pattern.hasMatch(text)) {
    throw StateError('Marker "$name" not found');
  }
  final lines = [
    '$indent$openTag',
    for (final line in body) line.isEmpty ? '' : '$indent$line',
    '$indent$closeTag',
  ];
  return text.replaceFirst(pattern, lines.join('\n'));
}
