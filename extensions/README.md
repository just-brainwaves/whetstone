# Whetstone Extensions Registry

This folder is the **community extension registry** for Whetstone. The editor reads
[`registry.json`](./registry.json) to power the **Browse** tab in the Extensions
manager (search, install) and to **check for updates**.

## How it works

- `registry.json` is the index. Each entry describes one extension and points at a
  folder here that holds its files.
- The app fetches `registry.json` (and each extension's files) over raw GitHub:
  `https://raw.githubusercontent.com/just-brainwaves/whetstone/main/extensions/...`
- **Updates** are version-driven: the app compares the `version` in `registry.json`
  against the version you have installed (semver). Bump the `version` here when you
  publish a new build and every app sees the update on its next registry fetch.

## Publishing an extension

1. Add a folder `extensions/<your-id>/` containing your extension's files — at
   minimum `whetstone.json` (the manifest), plus any `main.js`, `README.md`,
   `icon.*`, theme JSONs, etc.
2. Add an entry to `registry.json`:

   ```jsonc
   {
     "id": "acme.rainbow",          // must equal the manifest "id"
     "name": "Rainbow Brackets",
     "version": "1.2.0",            // must equal the manifest "version"
     "description": "…",
     "author": "Acme",
     "categories": ["editor"],
     "dir": "rainbow",              // the folder under extensions/
     "files": ["whetstone.json", "main.js", "README.md", "icon.svg"]
   }
   ```

3. Open a pull request. Once merged into `main`, the extension is live in every
   Whetstone install's Browse tab.

## Updating an extension

Bump both the `version` in your `whetstone.json` **and** the matching `version` in
`registry.json`, update the files, and open a PR. Installed users get an
"Update to vX" button on the extension's page.

## Manifest reference

See the extension manifest contract in the Whetstone docs
(`docs/architecture/extensions.md` in the source tree): `contributes.commands`,
`keybindings`, `themes`, and `settings` are supported today.
