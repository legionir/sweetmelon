import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sweetmelon/cli/plugin_detect.dart';

const _bridge = {
  'camera': 'camera',
  'fileSystem': 'file_system',
  'http': 'http_native',
  'storage': 'storage',
};
const _ns = {'camera': 'camera', 'fs': 'fileSystem', 'storage': 'storage'};

DetectResult scan(String source) => detectPlugins(
      files: {'app.js': source},
      bridgeToKey: _bridge,
      namespaceToBridge: _ns,
    );

void main() {
  test('SDK namespaces, also through an alias', () {
    final r = scan('var S = window.NativeSDK;\nS.camera.takePhoto();\n'
        'NativeSDK.fs.readFile("a");');
    expect(r.plugins, {'camera', 'file_system'});
    expect(r.evidence['camera'], ['app.js:2']);
  });

  test('destructuring the SDK', () {
    final r = scan('const { camera, storage: st } = NativeSDK;');
    expect(r.plugins, {'camera', 'storage'});
  });

  test('plugin: literal and call helpers', () {
    final r = scan("Native.call({ plugin: 'http', method: 'get' });\n"
        "call('storage', 'get', {});\n"
        "x.call(this, 1);");
    expect(r.plugins, {'http_native', 'storage'});
    expect(r.dynamicUses, isEmpty);
  });

  test('unknown plugin name is reported, not enabled', () {
    final r = scan("Native.call({ plugin: 'cammera', method: 'x' });");
    expect(r.plugins, isEmpty);
    expect(r.unknownNames.keys, ['cammera']);
  });

  test('dynamic use is reported with its line', () {
    final r =
        scan("const n = 'camera';\nNative.call({ plugin: n, method: 'x' });\n"
            "NativeSDK[n].go();\nNativeSDK.call(n, 'x');");
    expect(r.plugins, isEmpty);
    expect(r.dynamicUses.map((u) => u.location),
        ['app.js:2', 'app.js:3', 'app.js:4']);
  });

  test('annotation names plugins explicitly', () {
    final r = scan('// sweetmelon:uses camera, file_system\n');
    expect(r.plugins, {'camera', 'file_system'});
  });

  test('sdkNamespaces reads the first bridge name of each block', () {
    const sdk = '''
    storage: {
      get: function (k) { return call('storage', 'get', { key: k }); }
    },
    fs: {
      read: function () { return call('fileSystem', 'read', {}); }
    },
''';
    expect(sdkNamespaces(sdk), {'storage': 'storage', 'fs': 'fileSystem'});
  });

  test('the real SDK maps every namespace to a plugin name', () async {
    final map =
        sdkNamespaces(await File('assets/www/js/native-sdk.js').readAsString());
    expect(map['camera'], 'camera');
    expect(map['cameraPreview'], 'cameraPreview');
    expect(map.length, greaterThan(50));
  });
}
