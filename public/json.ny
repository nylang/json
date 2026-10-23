/**
 * @brief Open layouts and accessors for the `json` document model (m_v0.19_p2/p3).
 * @note `Json` is a wrapper struct (json.md §1.3). Walk `.node` with `holds` / `get_if` / `visit`.
 * @see docs/design/stdlib/json.md §0–§1.5
 */

module JsonTypes;
part "../private/parse.ny";
part "../private/reader.ny";
part "../tests/reader_selftest.ny";
part "../private/document.ny";
part "../tests/document_selftest.ny";
part "../private/emit.ny";
part "../private/writer.ny";
part "../tests/writer_selftest.ny";
part "../tests/emit_selftest.ny";
part "../tests/fixture_selftest.ny";

import "stdlib:stdlib.ny";
import "ntest:ntest.ny";
import "interface/json.ni";

/**
 * @brief First matching key, or `nil` if absent.
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
 * @brief Object entry count.
 */
pub method(JsonObject) Len() -> int32 {
  return self.entries.Len();
}

/**
 * @brief Key at `index`, or `nil` if out of range.
 * @note Reads via entry pointer (no Array.Get copy) so key/value drops do not double-free.
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
 * @brief Value at `index`, or `nil` if out of range.
 * @note Reads via entry pointer (no Array.Get copy) so key/value drops do not double-free.
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
 * @brief String scalar payload.
 */
pub method(JsonStr) Text() -> string {
  return copy(self.value);
}

/**
 * @brief Integer scalar payload.
 */
pub method(JsonInt) I64() -> int64 {
  return self.value;
}

/**
 * @brief Bool scalar payload.
 */
pub method(JsonBool) Value() -> bool {
  return self.value;
}

/**
 * @brief If `doc` is an integer scalar, return its value.
 */
pub func JsonAsInt(doc: Json) -> int64? {
  let iv: JsonInt? = doc.node.get_if<JsonInt>();
  if iv == nil {
    return nil;
  }
  let value: JsonInt = iv as JsonInt;
  if value.is_unsigned { return nil; }
  return value.I64();
}

/** @brief If `doc` is an unsigned integer scalar, return its value. */
pub func JsonAsUInt64(doc: Json) -> uint64? {
  let value_opt: JsonInt? = doc.node.get_if<JsonInt>();
  if value_opt != nil {
    let value: JsonInt = value_opt as JsonInt;
    if value.is_unsigned { return value.unsigned_value; }
    let signed: int64 = value.I64();
    if signed >= 0 as int64 { return signed as uint64; }
  }
  return nil;
}

/**
 * @brief If `doc` is a bool scalar, return its value.
 */
pub func JsonAsBool(doc: Json) -> bool? {
  let bv: JsonBool? = doc.node.get_if<JsonBool>();
  if bv == nil {
    return nil;
  }
  return (bv as JsonBool).Value();
}

/**
 * @brief If `doc` is a string scalar, return a copy of its UTF-8 payload.
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
 * @brief If `doc` is an object node, return it.
 */
pub func JsonAsObject(doc: Json) -> JsonObject? {
  return doc.node.get_if<JsonObject>();
}

/**
 * @brief If `doc` is an array node, return it.
 */
pub func JsonAsArray(doc: Json) -> JsonArray? {
  return doc.node.get_if<JsonArray>();
}

/**
 * @brief Whether `doc` is the JSON null scalar.
 */
pub func JsonIsNull(doc: Json) -> bool {
  let value: JsonNull? = doc.node.get_if<JsonNull>();
  return value != nil;
}

/**
 * @brief Bool scalar node (cross-package constructor).
 */
pub func JsonFromBool(v: bool) -> Json {
  return Json{ node: JsonBool{ value: v } };
}

/**
 * @brief Integer scalar node (cross-package constructor).
 */
pub func JsonFromInt(v: int64) -> Json {
  return Json{ node: JsonInt{ value: v, unsigned_value: 0u64, is_unsigned: false } };
}

pub func JsonFromUInt64(v: uint64) -> Json {
  if v <= 9223372036854775807u64 { return JsonFromInt(v as int64); }
  return Json{ node: JsonInt{ value: 0 as int64, unsigned_value: v, is_unsigned: true } };
}

/**
 * @brief String scalar node (cross-package constructor).
 */
pub func JsonFromStr(s: string) -> Json {
  return Json{ node: JsonStr{ value: copy(s) } };
}

/**
 * @brief Array node (cross-package constructor).
 */
pub func JsonFromArray(items: Array<Json>) -> Json {
  return Json{ node: JsonArray{ items: items } };
}

/**
 * @brief Object node (cross-package constructor).
 */
pub func JsonFromObject(entries: Array<JsonObjectEntry>) -> Json {
  return Json{ node: JsonObject{ entries: entries } };
}

/**
 * @brief Error line.
 */
pub method(JsonError) Line() -> int32 {
  return self.line;
}

/**
 * @brief Error column.
 */
pub method(JsonError) Column() -> int32 {
  return self.column;
}

/**
 * @brief Error message text.
 */
pub method(JsonError) Message() -> string {
  return copy(self.message);
}

/**
 * @brief Array element at `index`, or `nil` if out of range.
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
 * @brief Array item count.
 */
pub method(JsonArray) Len() -> int32 {
  return self.items.Len();
}
