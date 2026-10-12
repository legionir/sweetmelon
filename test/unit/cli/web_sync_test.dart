import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/web_sync.dart';

void main() {
  test('syncHtmlTitle sets the title and escapes it', () {
    const html = '<head>\n  <title>hello_world</title>\n</head>';
    expect(
      syncHtmlTitle(html, 'Tom & Jerry <Pro>'),
      '<head>\n  <title>Tom &amp; Jerry &lt;Pro&gt;</title>\n</head>',
    );
  });

  test('syncHtmlTitle is idempotent', () {
    const html = '<title>MelonAI Studio</title>';
    expect(syncHtmlTitle(html, 'MelonAI Studio'), html);
  });

  test('syncWebManifest changes only name and short_name, keeps the layout',
      () {
    const json =
        '{\n    "name": "hello_world",\n    "short_name": "hello_world",\n'
        '    "start_url": ".",\n    "icons": []\n}';
    final out = syncWebManifest(json, name: 'MelonAI Studio');
    expect(out, contains('    "name": "MelonAI Studio",'));
    expect(out, contains('    "short_name": "MelonAI Stud",'));
    expect(out, contains('    "start_url": ".",'));
    final data = jsonDecode(out) as Map<String, dynamic>;
    expect(data['name'], 'MelonAI Studio');
    expect(data['short_name'], 'MelonAI Stud');
  });

  test('syncWebManifest is idempotent', () {
    const json = '{\n  "name": "A",\n  "short_name": "A"\n}';
    final once = syncWebManifest(json, name: 'A');
    expect(syncWebManifest(once, name: 'A'), once);
  });

  test('syncWebManifest rejects invalid JSON', () {
    expect(() => syncWebManifest('{', name: 'A'), throwsFormatException);
  });
}
