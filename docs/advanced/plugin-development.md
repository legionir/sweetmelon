# Plugin development

A plugin is a small Dart class in `lib/plugins/<name>/`. Generate the skeleton with the CLI:

```bash
dart run bin/sweetmelon.dart plugin generate MyPlugin
```

This creates the plugin class, a `pubspec.yaml`, a README and a test:

```
lib/plugins/my_plugin/
├── README.md                    # API documentation (required)
├── pubspec.yaml
└── lib/my_plugin_plugin.dart    # Implementation
test/plugins/my_plugin_plugin_test.dart
```

## Implementation

```dart
class MyPluginPlugin extends Plugin {
  @override
  String get name => 'myPlugin';           // JS namespace: NativeSDK.myPlugin

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Does something useful';

  @override
  List<String> get supportedMethods => ['doThing', 'getInfo'];

  @override
  Future<dynamic> onCall(String method, Map<String, dynamic> args) async {
    switch (method) {
      case 'doThing':
        final input = args['input'] as String;
        return {'done': true, 'echo': input};
      case 'getInfo':
        return {'name': name, 'version': version};
      default:
        throw UnsupportedError('Method "$method" not supported');
    }
  }

  // Emit events to JS: eventEmitter?.call('myPlugin.done', {'ok': true});
}
```

## Wiring it in

1. Register the plugin in `lib/di/service_locator.dart`.
2. Add its namespace to `assets/www/js/native-sdk.js` (and `native-sdk.d.ts`).
3. Enable it in `sweetmelon.yaml` and run `sync --apply`.
4. Document every method, argument, return shape and event in the plugin's README: those READMEs are the source of this site's [plugin reference](/plugins/overview).
