// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module JsonModel;
import "stdlib:stdlib.ny";
import "interface/json.ni";
import "private/scalar.ny";

/**
 * @brief Node accessors and constructors for the `json` document model.
 * @note `Json` is a wrapper struct (json.md §1.3). Walk `.node` with `holds` / `get_if` /
 *   `visit`.
 * @see docs/design/stdlib/json.md §0–§1.5
 */

/**
 * @brief First entry whose key equals `key`, or `nil` if absent.
 * @param key Object key (string keys only).
 * @returns Matching value, or `nil`.
 */
pub method(JsonObject) Get(key: string) -> Json? {
  var i: int32 = 0;
  let n: int32 = self.entries.Len();
  while i < n {
    // Pointer walk: Array.Get of owned JsonObjectEntry would move the slot out.
    unsafe {
      let ep: *mut JsonObjectEntry = &mut self.entries.buf[i];
      if ((*ep).key == key) {
        let out: Json? = copy((*ep).value);

        return out;
      }
    }

    i = i + 1;
  }

  return nil;
}

/**
 * @brief Entry count.
 * @returns Number of `entries`.
 */
pub method(JsonObject) Len() -> int32 {
  return self.entries.Len();
}

/**
 * @brief Key of the entry at 0-based `index`, or `nil` if out of range.
 * @returns The matching payload, or nil for the absent/out-of-range case described above.
 * @note Cross-package field access on `JsonObjectEntry` is not available; use this helper.
 */
pub method(JsonObject) KeyAt(index: int32) -> string? {
  if index < 0 {
    return nil;
  }

  if index >= self.entries.Len() {
    return nil;
  }

  unsafe {
    let ep: *mut JsonObjectEntry = &mut self.entries.buf[index];
    let out: string? = copy((*ep).key);

    return out;
  }
}

/**
 * @brief Value of the entry at 0-based `index`, or `nil` if out of range.
 * @returns The matching payload, or nil for the absent/out-of-range case described above.
 */
pub method(JsonObject) ValueAt(index: int32) -> Json? {
  if index < 0 {
    return nil;
  }

  if index >= self.entries.Len() {
    return nil;
  }

  unsafe {
    let ep: *mut JsonObjectEntry = &mut self.entries.buf[index];
    let out: Json? = copy((*ep).value);

    return out;
  }
}

/**
 * @brief UTF-8 payload of a string scalar (cross-package accessor).
 * @returns UTF-8 payload of a string scalar (cross-package accessor).
 */
pub method(JsonStr) Text() -> string {
  return copy(self.value);
}

/**
 * @brief Integer scalar payload.
 * @returns Integer scalar payload.
 */
pub method(JsonInt) I64() -> int64 {
  return self.value;
}

/**
 * @brief Read the retained exact JSON number spelling.
 * @returns Original number text, without floating-point conversion.
 */
pub method(JsonNumber) Text() -> string {
  return copy(self.value);
}

/**
 * @brief Bool scalar payload.
 * @returns Bool scalar payload.
 */
pub method(JsonBool) Value() -> bool {
  return self.value;
}

/**
 * @brief Read a representable signed integer from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsInt(doc: Json) -> int64? {
  let iv: JsonInt? = doc.node.get_if<JsonInt>();
  if iv == nil {
    return nil;
  }

  let value: JsonInt = iv as JsonInt;
  if value.is_unsigned {
    return nil;
  }

  return value.I64();
}

/**
 * @brief Read a representable unsigned integer from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsUInt64(doc: Json) -> uint64? {
  let value_opt: JsonInt? = doc.node.get_if<JsonInt>();
  if value_opt != nil {
    let value: JsonInt = value_opt as JsonInt;
    if value.is_unsigned {
      return value.unsigned_value;
    }

    let signed: int64 = value.I64();
    if signed >= 0 as int64 {
      return signed as uint64;
    }
  }

  return nil;
}

/**
 * @brief Read an exact numeric lexeme from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsNumber(doc: Json) -> string? {
  let raw: JsonNumber? = doc.node.get_if<JsonNumber>();
  if raw != nil {
    return copy((raw as JsonNumber).value);
  }

  let integer: JsonInt? = doc.node.get_if<JsonInt>();
  if integer == nil {
    return nil;
  }

  let value: JsonInt = integer as JsonInt;
  if value.is_unsigned {
    return JsonU64Text(value.unsigned_value);
  }

  return JsonI64Text(value.value);
}

/**
 * @brief Read a boolean from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsBool(doc: Json) -> bool? {
  let bv: JsonBool? = doc.node.get_if<JsonBool>();
  if bv == nil {
    return nil;
  }

  return (bv as JsonBool).Value();
}

/**
 * @brief Read a string from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsStr(doc: Json) -> string? {
  let sv: JsonStr? = doc.node.get_if<JsonStr>();
  if sv == nil {
    return nil;
  }

  let out: string? = (sv as JsonStr).Text();

  return out;
}

/**
 * @brief Read an object from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsObject(doc: Json) -> JsonObject? {
  return doc.node.get_if<JsonObject>();
}

/**
 * @brief Read an array from the document node.
 * @returns The matching payload, or nil when the node cannot be represented by that accessor.
 */
pub func JsonAsArray(doc: Json) -> JsonArray? {
  return doc.node.get_if<JsonArray>();
}

/**
 * @brief Test whether a document node holds the null variant.
 * @returns True only for JsonNull; false for every other variant.
 */
pub func JsonIsNull(doc: Json) -> bool {
  let value: JsonNull? = doc.node.get_if<JsonNull>();

  return value != nil;
}

/**
 * @brief Construct scalar / collection nodes without cross-package `.node` field access.
 * @returns The Json value described above, retaining the documented ownership and default-state
 *   semantics.
 * @note Callers outside package `json` should use these (or `JsonWriter`) rather than `Json{
 *   node: … }` literals — host codegen NY6002 on `.node` in large importers.
 */
pub func JsonFromBool(v: bool) -> Json {
  return Json{node: JsonBool{value: v}};
}

/**
 * @brief Construct a signed integer document node.
 * @returns A document value retaining its scalar or collection payload through normal language
 *   ownership.
 */
pub func JsonFromInt(v: int64) -> Json {
  return Json{node: JsonInt{value: v, unsigned_value: 0u64, is_unsigned: false}};
}

/**
 * @brief Construct a unsigned integer document node.
 * @returns A document value retaining its scalar or collection payload through normal language
 *   ownership.
 */
pub func JsonFromUInt64(v: uint64) -> Json {
  if v <= 9223372036854775807u64 {
    return JsonFromInt(v as int64);
  }

  return Json{node: JsonInt{value: 0 as int64, unsigned_value: v, is_unsigned: true}};
}

/**
 * @brief Construct an exact number node without rounding the original spelling.
 * @returns A retained numeric lexeme, or nil when raw is not valid JSON number syntax.
 */
pub func JsonFromNumber(raw: string) -> Json? {
  if !JsonNumberIsValid(raw) {
    return nil;
  }

  return Json{node: JsonNumber{value: copy(raw)}};
}

/**
 * @brief Construct a string document node.
 * @returns A document value retaining its scalar or collection payload through normal language
 *   ownership.
 */
pub func JsonFromStr(s: string) -> Json {
  return Json{node: JsonStr{value: copy(s)}};
}

/**
 * @brief Construct a array document node.
 * @returns A document value retaining its scalar or collection payload through normal language
 *   ownership.
 */
pub func JsonFromArray(items: Array<Json>) -> Json {
  return Json{node: JsonArray{items: items}};
}

/**
 * @brief Construct a object document node.
 * @returns A document value retaining its scalar or collection payload through normal language
 *   ownership.
 */
pub func JsonFromObject(entries: Array<JsonObjectEntry>) -> Json {
  return Json{node: JsonObject{entries: entries}};
}

/**
 * @brief 1-based line (0 for I/O errors).
 * @returns 1-based line (0 for I/O errors).
 */
pub method(JsonError) Line() -> int32 {
  return self.line;
}

/**
 * @brief 1-based column (0 for I/O errors).
 * @returns 1-based column (0 for I/O errors).
 */
pub method(JsonError) Column() -> int32 {
  return self.column;
}

/**
 * @brief English error detail (no `NYxxxx`).
 * @returns English error detail (no `NYxxxx`).
 */
pub method(JsonError) Message() -> string {
  return copy(self.message);
}

/**
 * @brief Element at 0-based `index`, or `nil` if out of range.
 * @param index Array index.
 * @returns Matching item, or `nil`.
 */
pub method(JsonArray) Get(index: int32) -> Json? {
  if index < 0 {
    return nil;
  }

  if index >= self.items.Len() {
    return nil;
  }

  // Pointer read + optional pack moves the element (single owner). Prefer this
  // over Array.Get, which also moves but is easier to misuse across drops.
  unsafe {
    let ip: *mut Json = &mut self.items.buf[index];
    let out: Json? = copy(*ip);

    return out;
  }
}

/**
 * @brief Item count.
 * @returns Number of `items`.
 */
pub method(JsonArray) Len() -> int32 {
  return self.items.Len();
}
