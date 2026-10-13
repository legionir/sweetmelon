# Versioning

Sweetmelon core uses [Semantic Versioning](https://semver.org). An app pins the
core release it is built for in `sweetmelon.yaml`:

```yaml
core: "2.4"
```

| Release | Changes | What an app does |
| --- | --- | --- |
| Patch (`2.4.1`) | Bug fixes only. No change to behaviour, the JS bridge or `sweetmelon.yaml`. | Takes it safely. |
| Minor (`2.5.0`) | New features, changed generated output. | Moves on purpose, after reading the [changelog](https://github.com/legionir/sweetmelon/blob/main/CHANGELOG.md). |
| Major (`3.0.0`) | May break the bridge or the config format. | Migrates on purpose. |

A fix for an older minor is made on its `release/x.y` branch and tagged there,
so an app on `2.4` keeps getting `2.4.x` fixes without taking `2.5` features.

## What is checked

`sweetmelon validate` and `sweetmelon doctor` compare `core:` with the CLI
version (`sweetmelon --version`):

- `core: "2.4"` accepts `2.4.0`, `2.4.1`, and so on.
- `core: "2.4.1"` needs patch 1 or newer.
- Any other minor or major is an error.
- A file without `core:` gets a warning.

## Pin an exact tag

Use an exact tag (`v2.4.0`), never a branch or a floating tag:

```yaml
dependencies:
  sweetmelon:
    git:
      url: https://github.com/legionir/sweetmelon.git
      ref: v2.4.0
```
