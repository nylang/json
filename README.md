# json

Nyra JSON reader, document model and writer. Import `json:json.ny`.

Version: **0.19.0**. Repository: <https://github.com/nylang/json>.

## Development setup

This source release uses the NyraLang workspace layout: check out this package
at `third_party/json`, alongside `source/stdlib` and `source/ntest` in the
workspace. The relative dependency paths in `package.yaml` target that layout.
A standalone clone does not include these dependencies or a compiler.

Nyra SDK 1.0.0 also includes JSON 0.19.0 for SDK consumers. This repository
publishes the package source and tests under MIT; it does not contain the
Nyra compiler implementation.

See [MIGRATION.md](MIGRATION.md) for source history and the current workspace
layout. Run the package suite from NyraLang with
`python3 nyra.py test --package json`. Test data is owned by this repository.

## License

Licensed under the [MIT License](LICENSE).
