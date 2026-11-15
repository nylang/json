// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

import "json.ny";
import "ntest:ntest.ny";
import "stdlib:stdlib.ny";

@test
func test_json_schema_preserves_exact_integer_counts() {
  let heap = Allocator.ProcessHeap(0i64, 8i64);
  let parsed = JsonDocument.Parse("{\"minLength\":18446744073709551615}", heap, heap);
  let rule = (parsed.get_if<JsonDocument>() as JsonDocument).Root();
  let compiled = JsonSchema.Compile(rule);
  if AssertTrue(compiled.IsOk()) != 0 {
    return;
  }

  let schema = compiled.get_if<JsonSchema>() as JsonSchema;
  let value = Json.FromStr("text");
  let validation = schema.Validate(value);
  if AssertTrue(validation.IsErr()) != 0 {
    return;
  }

  let failure = validation.get_if<SchemaError>() as SchemaError;
  AssertTrue(failure.kind == SchemaErrorKind.Violation);
  AssertEqString(failure.schema_path, "/minLength");
}
