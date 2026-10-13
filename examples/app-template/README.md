# My App

Web app built with [Sweetmelon](https://github.com/legionir/sweetmelon) core
v2.4.1.

- `www/` your app (HTML, CSS, JavaScript)
- `sweetmelon.yaml` names, core version and plugin selection
- `.github/workflows/build.yml` Actions tab, "Build app": pick the package name,
  app name and APK / AAB / iOS, then run

Plugins follow the code: a plugin is on when `www/` calls it.
