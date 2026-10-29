# json

Nyra JSON reader, document model and writer. Import `json:json.ny`.

Version: **0.19.0**. Repository: <https://github.com/nylang/json>.

## Development setup

A standalone checkout uses the installed SDK's implicit stdlib and ntest
packages; it does not require the NyraLang private source layout. JSON is an
independent source package, not a bundled runtime package in SDK 1.0.1 or later.
The original v0.19.0 tag retains its historical manifest; use the current main
commit for the portable manifest and lock the resulting Git revision.

See [MIGRATION.md](MIGRATION.md) for source history and the current workspace
layout. Run the package suite from NyraLang with
`python3 nyra.py test --package json`. Test data is owned by this repository.

## Portable Git dependency

Source imports use the installed SDK's implicit runtime packages (SDK 1.0.2 or
later); package manifests contain no paths into the private compiler checkout.
For automatic Git preparation use native `nyra` 1.0.3 or later. That manager's
public SDK publication is separate from this package; SDK 1.0.2 does not ship it.
With SDK 1.0.2, a manual clone and explicit local consumer path remain usable.

Add this dependency to your application's `package.yaml`:

```yaml
dependencies:
  json:
    git: https://github.com/nylang/json.git
    rev: main
```

Then run `nyra lock ./app` and commit `nyra.lock`; use
`nyra fetch ./app --frozen` to prepare the pinned graph again. `main` above is
an initial selector; the lock fixes the exact commit/content. Normal compiler
and analyzer operations do not fetch dependencies. Historical tags are immutable
and may retain older workspace-specific manifests.


SDK-v2 portable-lock compilation requires the SDK runtime-lock loading fix in
newer compiler builds. The unchanged originally qualified SDK 1.0.3 bootstrap
does not contain that follow-up. Source-only use with public SDK 1.0.2 and the
historical prepared TLS source asset retain their documented limits; this
manifest migration does not release a corrected compiler.

For local multi-package development, list package-file pointers in a common
`workspace.yaml`. Workspace replacements keep Git declarations shareable;
origin lock updates deliberately disable replacements. A package entry and its
SDK can move without rewriting publisher paths.

## License

Licensed under the [MIT License](LICENSE).

## Module architecture

See [module responsibilities, ownership and dependency boundaries](ARCHITECTURE.md).
