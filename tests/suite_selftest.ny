// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Document, reader and writer contract tests across module boundaries. */
module JsonTests;
part "reader_selftest.ny";
part "document_selftest.ny";
part "writer_selftest.ny";
part "emit_selftest.ny";
part "fixture_selftest.ny";
import "stdlib:stdlib.ny";
import "ntest:ntest.ny";
import "interface/json.ni";
import "private/model.ny";
import "private/reader.ny";
import "private/document.ny";
import "private/emit.ny";
