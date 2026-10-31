# json

Development API 0.20.0 requires a matching Nyra SDK 1.0.5 or newer.
Rebuild precompiled consumers against the matching interfaces and runtime.

Nyra JSON reader, document model and writer. Import `json:json.ny`.

Development version: **0.20.0**. Repository: <https://github.com/nylang/json>.

## Development setup

A standalone checkout uses the installed SDK's implicit stdlib and ntest
packages; it does not require the NyraLang private source layout. JSON is an
independent source package, not a bundled runtime package in SDK 1.0.1 or later.
The original v0.19.0 tag retains its historical manifest. Use the immutable
1.0.5-compatible development revision below; no new package tag is claimed.

See [MIGRATION.md](MIGRATION.md) for source history and portable dependency
setup. Run the package suite from NyraLang with
`python3 nyra.py test --package json`. Test data is owned by this repository.

## Portable Git dependency

This working API requires matching Nyra SDK 1.0.5 compiler, runtime and analyzer
capabilities. Its manifest uses implicit SDK packages and contains no paths into
the private compiler checkout. Use the SDK's native `nyra` for Git preparation.
Older source tags retain their documented SDK requirements; they do not qualify
this development API. SDK/package publication remains a separate operation.

Add this dependency to your application's `package.yaml`:

```yaml
dependencies:
  json:
    git: https://github.com/nylang/json.git
    rev: fb58fe499690cea1d9c093d6a81d76adbcaf3ca9
```

Run `nyra lock ./app` and commit `nyra.lock`; use
`nyra fetch ./app --frozen` to prepare the same graph again. The example pins
an existing public development commit whose API matches this source. It does
not select the older stable `main` or claim a newly published package tag.
Normal compiler and analyzer operations do not fetch dependencies.

For local multi-package development, list package-file pointers in a common
`workspace.yaml`. Workspace replacements keep Git declarations shareable;
origin lock updates deliberately disable replacements. A package entry and its
SDK can move without rewriting publisher paths.

## License

Licensed under the [MIT License](LICENSE).

## Module architecture

See [module responsibilities, ownership and dependency boundaries](ARCHITECTURE.md).

## Coding-rule lint

`package.yaml` selects the portable `lint.yaml` profile. It requires the
1.0.5 P7 analyzer candidate (or a later SDK containing those rules); the
published 1.0.4 analyzer does not implement them. `import: default` inherits
the selected workspace profile when present, otherwise analyzer SDK defaults.
No sibling source path is required. Run `nyra-analyzer lint . --json`. Lint checks
coding rules; runtime qualification is a separate gate.

## 1.0.5 source API migration

This working source requires the 1.0.5 kernel capabilities (checked string byte
access and allocator-owned string views); it is not compatible with an unchanged
1.0.4 SDK. No new package tag or release is claimed. Rebuild precompiled users
with matching interfaces and runtime objects. Required native test/ABI entry
points remain free declarations; product and implementation operations now use
real value, cursor, writer and DOM-state owners. No legacy API alias is retained.

Use `node.AsInt()` / `AsUInt64()` / `AsNumber()` / `AsBool()` / `AsStr()` /
`AsObject()` / `AsArray()` and `node.IsNull()`. Construct values with
`Json.FromBool/FromInt/FromUInt64/FromNumber/FromStr/FromArray/FromObject` and
compare with `left.Equals(right)`. These replace the former JsonAs*, JsonFrom*,
JsonIsNull and JsonTreesEqual free functions. JsonReader/Document/Writer keep
their existing parsing, event and emission contracts.
