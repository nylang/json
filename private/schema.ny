// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Exposes JSON schema operations and borrows DOM nodes for a synchronous walk. */
import "interface/schema.ni";
import "interface/json.ni";
import "schema:schema.ny";
import "stdlib:stdlib.ny";

/** @brief Compiled rules with a JSON entry point. */
pub struct JsonSchema {
  readonly rules: Schema;
}

pub static method(JsonSchema) Compile(rule: ref Json) -> Result<JsonSchema, SchemaError> {
  unsafe {
    let reader = JsonSchemaReader{root: &rule};
    let compiled = Schema.Compile(reader);
    if compiled.IsErr() {
      return Err<JsonSchema, SchemaError>(compiled.get_if<SchemaError>() as SchemaError);
    }

    return Ok<JsonSchema, SchemaError>(JsonSchema.FromCompiled(compiled.get_if<Schema>() as Schema));
  }
}

pub method(JsonSchema) Validate(value: ref Json) -> Result<Unit, SchemaError> {
  unsafe {
    let reader = JsonSchemaReader{root: &value};
    return (self.rules).Validate(reader);
  }
}

pub static method(JsonSchema) FromCompiled(rules: Schema) -> JsonSchema {
  return JsonSchema{rules: rules};
}

pub method(JsonSchema) Compiled() -> Schema {
  return self.rules;
}

// The caller retains the root and its collections through Compile or Validate.
struct JsonSchemaReader implements SchemaReader {
  readonly root: *const Json;
}

@override
method(JsonSchemaReader) Root() -> uintptr {
  return self.root as uintptr;
}

@override
method(JsonSchemaReader) Kind(node: uintptr) -> SchemaKind {
  unsafe {
    let value: *const Json = node as *const Json;
    if (*value).node.holds<JsonBool>() {
      return SchemaKind.Boolean;
    }

    if (*value).node.holds<JsonInt>() || (*value).node.holds<JsonNumber>() {
      return SchemaKind.Number;
    }

    if (*value).node.holds<JsonStr>() {
      return SchemaKind.String;
    }

    if (*value).node.holds<JsonArray>() {
      return SchemaKind.Array;
    }

    if (*value).node.holds<JsonObject>() {
      return SchemaKind.Object;
    }
  }

  return SchemaKind.Null;
}

@override
method(JsonSchemaReader) Scalar(node: uintptr) -> SchemaScalar {
  unsafe {
    let value: *const Json = node as *const Json;
    let text: ref JsonStr? = (*value).node.get_ref_if<JsonStr>();
    if text != nil {
      return SchemaScalar{text: text!.value};
    }

    let number: ref JsonInt? = (*value).node.get_ref_if<JsonInt>();
    if number != nil {
      let integer: JsonInt = number!;
      if integer.is_unsigned {
        return SchemaScalar{text: integer.unsigned_value.ToString(), count: integer.unsigned_value};
      }

      let signed: int64 = integer.value;
      if signed < 0i64 {
        return SchemaScalar{text: signed.ToString()};
      }

      return SchemaScalar{text: signed.ToString(), count: signed as uint64};
    }

    let decimal: ref JsonNumber? = (*value).node.get_ref_if<JsonNumber>();
    if decimal != nil {
      return SchemaScalar{text: decimal!.value};
    }

    let boolean: ref JsonBool? = (*value).node.get_ref_if<JsonBool>();
    if boolean != nil {
      return SchemaScalar{boolean: boolean!.value};
    }
  }

  return SchemaScalar{};
}

@override
method(JsonSchemaReader) Len(node: uintptr) -> int32 {
  unsafe {
    let value: *const Json = node as *const Json;
    let items: ref JsonArray? = (*value).node.get_ref_if<JsonArray>();
    if items != nil {
      return items!.Len();
    }

    let entries: ref JsonObject? = (*value).node.get_ref_if<JsonObject>();
    if entries != nil {
      return entries!.Len();
    }
  }

  return 0;
}

@override
method(JsonSchemaReader) KeyAt(node: uintptr, index: int32) -> string {
  unsafe {
    let value: *const Json = node as *const Json;
    let entries: ref JsonObject? = (*value).node.get_ref_if<JsonObject>();
    if entries != nil {
      let item: *const JsonObjectEntry = &entries!.entries.buf[index];
      return (*item).key;
    }
  }

  return "";
}

@override
method(JsonSchemaReader) ChildAt(node: uintptr, index: int32) -> uintptr {
  unsafe {
    let value: *const Json = node as *const Json;
    let items: ref JsonArray? = (*value).node.get_ref_if<JsonArray>();
    if items != nil {
      let item: *const Json = &items!.items.buf[index];
      return item as uintptr;
    }

    let entries: ref JsonObject? = (*value).node.get_ref_if<JsonObject>();
    if entries != nil {
      let item: *const JsonObjectEntry = &entries!.entries.buf[index];
      let child: *const Json = &(*item).value;
      return child as uintptr;
    }
  }

  return 0up;
}
