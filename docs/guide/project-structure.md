# Project structure

```
sweetmelon/
├── android/, ios/, web/     Host projects for the example app
├── assets/
│   ├── www/                 Default web app (test suite) and the JavaScript SDK
│   │   └── js/              native-sdk.js, native-sdk.d.ts, native-resilience.js
│   ├── framework-sdks/      Angular / React / Vue / RxJS helpers
│   └── devtools/            Bridge inspector page
├── lib/
│   ├── main.dart, app.dart  Example app entry
│   ├── di/                  service_locator.dart (generated sections managed by sync)
│   ├── screens/             WebView host screen
│   ├── packages/            core, plugin_engine, security, performance, devtools
│   ├── plugins/             104 plugins, each with its own README
│   └── cli/                 Implementation of the sweetmelon CLI
├── bin/sweetmelon.dart      The CLI entry point
├── tool/                    plugin_catalog.json and the generated test target list
├── docs/                    This documentation site
├── test/, integration_test/ Unit, widget and on-device tests
└── sweetmelon.yaml          Plugin selection and project settings
```

## Packages in `lib/packages`

| Package | Responsibility |
| --- | --- |
| `core` | Wire protocol, message bridge, WebView host, asset server, SSL pinning |
| `plugin_engine` | Plugin base class, registry, manager, lazy loader, versioning |
| `security` | Permission manager, rate limiter, execution guard |
| `performance` | Cache manager |
| `devtools` | Bridge inspector |

## Your own web app

Put it in `assets/www/` with `index.html` as the entry point. Include `js/native-sdk.js` to get the global `NativeSDK`. Directory entries in the Flutter asset list only bundle the files directly inside them, so every sub-folder of `assets/www` is listed in `pubspec.yaml`.
