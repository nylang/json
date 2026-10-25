# Source provenance

Extracted with `git subtree split --prefix=source/json` from NyraLang
revision `697ee111dbde913641adcaffe31bc1107bd52254`. The extracted history ends
at `60764df138198262c3a3c51875c789a685e369f1` before the independent-package migration commit.

The source manifest currently targets a NyraLang workspace checkout at
`third_party/json`, with SDK source dependencies under `../../source/`.
The public repository is <https://github.com/nylang/json>. The relative dependency
paths remain a workspace development arrangement; publishing the repository
does not enable automatic remote dependency resolution. Package versions are
preserved during extraction.
