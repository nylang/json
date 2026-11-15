// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "interface/json.ni";
import "schema:schema.ny";
import "stdlib:stdlib.ny";

/** @brief Compiled document rules with a JSON DOM entry point. */
pub struct JsonSchema;

/** @brief Compile rules from a JSON document node. The resulting schema owns its rules. */
pub static method(JsonSchema) Compile(rule: ref Json) -> Result<JsonSchema, SchemaError>;

/** @brief Validate a JSON document without materializing a second tree. */
pub method(JsonSchema) Validate(value: ref Json) -> Result<Unit, SchemaError>;

/** @brief Reuse rules previously compiled by any schema reader. */
pub static method(JsonSchema) FromCompiled(rules: Schema) -> JsonSchema;

/** @brief Return the reusable compiled rules for another document format. */
pub method(JsonSchema) Compiled() -> Schema;
