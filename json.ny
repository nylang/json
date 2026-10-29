// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/**
 * @brief Sole public entry for package `json` — Handler/Reader/Document/Writer.
 * @note External importers use `import "json:json.ny";` only. Import `stdlib:stdlib.ny` only (no
 *   source/stdlib/private).
 * @note ADR 0013 — product `export` is interface + public. No free Parse/ParseFile/Emit.
 * @see docs/design/stdlib/json.md
 */
export "interface/json.ni";
import "interface/json.ni";
import "private/model.ny";

import "private/reader.ny";
import "private/document.ny";
import "private/emit.ny";
