# Build an app from a web folder

Write your app as HTML and JavaScript. A GitHub Action builds the APK, AAB or
iOS app with a fixed Sweetmelon core release. You do not copy the core into
your repository.

## Your repository

```
www/              index.html, js, css
sweetmelon.yaml   core version, names, plugin selection
icon.png          optional, square PNG, 1024 px or more
.github/workflows/build.yml
```

```yaml
# sweetmelon.yaml
core: "2.4"

project:
  name: my_app
  display_name: My App          # shown under the icon
  version: 1.0.0
  application_id: com.acme.myapp
  dart_package: my_app
  icon: icon.png

plugin_selection:
  mode: auto                    # use the plugins the code calls
  include: [permission]         # always on
  exclude: [nfc]                # always off

plugins: {}
```

Copy [`examples/build-with-sweetmelon.yml`](https://github.com/legionir/sweetmelon/blob/main/examples/build-with-sweetmelon.yml)
to `.github/workflows/build.yml`. It starts from the **Actions** tab with
fields for the Android package name, Dart package name and app name, and
checkboxes for APK, AAB and iOS. An empty field keeps the value from
`sweetmelon.yaml`.

## Pin the core

```yaml
- uses: legionir/sweetmelon@v2.4.0
```

Use an exact tag. Patch releases only fix bugs; see [Versioning](./versioning).
The `core:` key in `sweetmelon.yaml` must match the tag's minor, or the build
stops with a message.

## What decides the plugins

| `mode` | Plugins that are on |
| --- | --- |
| `manual` (default) | The `plugins:` flags. `include` adds, `exclude` removes. |
| `auto` | The plugins found in `www`, plus `include`, minus `exclude`. |

Find out what `auto` sees before you build:

```bash
dart run bin/sweetmelon.dart detect --www www
```

It recognizes `NativeSDK.camera.takePhoto()`, a variable holding `NativeSDK`,
`const { camera } = NativeSDK`, `plugin: 'camera'` and `call('camera', ...)`.
It reads text and does not run your code. A plugin name built at run time
(`plugin: name`) cannot be resolved: it is a warning, or a failed build with
`strict: 'true'`. Fix it by listing the plugin in `include`, or by adding a
comment such as `// sweetmelon:uses camera`.

## Signing

Without a keystore the action signs with a throw-away key. Such a build installs
for testing, but updates do not install over it and Google Play rejects it.
For releases put your keystore in repository secrets and pass
`keystore_base64`, `keystore_password`, `key_alias` and `key_password`.

The iOS build is not code-signed. It checks that the app compiles; it cannot be
installed on a device.

## Limits

- The app is HTML and JavaScript. Native code of your own is not supported in
  this mode; use a clone or fork of the core for that.
- Permissions follow the enabled plugins and were derived from the plugin
  sources, not tested on each device.
- Some plugins need extra native code in `MainActivity` and do not work yet.

## Start from a template

```bash
dart run bin/sweetmelon.dart init ../my-app \
  --package-name com.acme.myapp --app-name "My App" --apply
```

This writes the files above with the workflow already pinned to the core
release you run it from. A ready copy is in
[`examples/app-template`](https://github.com/legionir/sweetmelon/tree/main/examples/app-template);
publish it as a repository with "Template repository" ticked in its settings.

To move to another core release later:

```bash
dart run bin/sweetmelon.dart upgrade --to 2.4.1 --apply
# a new minor release needs --allow-minor, a new major --allow-major
```
