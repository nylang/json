/**
 * @brief Product face for package `json` — Handler/Reader/Document/Writer.
 * @note Layouts and accessors live in `public/`; Reader/Document/Writer in `private/`.
 * @note Hard cut: no free `Parse`/`ParseFile`/`Emit` (json.md §0.2).
 * @see docs/design/stdlib/json.md §0
 */

import "stdlib:stdlib.ny";

/**
 * @brief SAX handler for `JsonReader` (RapidJSON-style Object/Array event names).
 * @note Return `true` to continue, `false` to abort the Reader (Parse → Err).
 * @see docs/design/stdlib/json.md §0.3
 */
pub interface JsonHandler {
  Null() -> bool;
  Bool(b: bool) -> bool;
  Int64(v: int64) -> bool;
  UInt64(v: uint64) -> bool;
  Number(raw: string) -> bool;
  String(s: string) -> bool;
  StartObject() -> bool;
  Key(k: string) -> bool;
  EndObject(member_count: int32) -> bool;
  StartArray() -> bool;
  EndArray(element_count: int32) -> bool;
}

/**
 * @brief UTF-8 bytes → Handler events; parse temps on caller `scratch` Allocator.
 * @see docs/design/stdlib/json.md §0.4
 */
pub struct JsonReader { _pad: int8; }

/**
 * @brief Construct a Reader (stateless; scratch is per-Parse).
 */
pub static method(JsonReader) New() -> JsonReader;

/**
 * @brief Parse `text` and publish Handler events in document order.
 * @param text UTF-8 source; empty / whitespace-only input is a Parse error (JSON grammar).
 * @param handler SAX receiver (iface by value — Drawable peer; fat pointer mutates impl state).
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Key/String temps; not durable nodes.
 * @returns Ok on full publish; Err on scan/parse failure or handler abort.
 * @note SoT spells `ref mut JsonHandler`; host-nyra iface dispatch requires by-value iface today.
 */
pub method(JsonReader) Parse(
  text: string,
  handler: JsonHandler,
  scratch: Allocator
) -> Result<Unit, JsonError>;

/**
 * @brief Read `path` then `Parse`.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub method(JsonReader) ParseFile(
  path: string,
  handler: JsonHandler,
  scratch: Allocator
) -> Result<Unit, JsonError>;

/**
 * @brief Durable DOM document built by a Handler adapter fed by `JsonReader`.
 * @note Nodes/strings retained on `durable`; parse temps on `scratch` (json.md §0.6).
 * @see docs/design/stdlib/json.md §0.4–0.5
 */
pub struct JsonDocument { root: Json; }

/**
 * @brief Parse `text` into a durable DOM via Reader → Document Handler adapter.
 * @param text UTF-8 source; empty input is a Parse error (JSON grammar).
 * @param durable Allocator for Key/String (and Document storage); typical hosted: `CreateAllocator`.
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Reader temps; Reset after Ok must not pin Document.
 */
pub static method(JsonDocument) Parse(
  text: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<JsonDocument, JsonError>;

/**
 * @brief Read `path` then `JsonDocument.Parse`.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub static method(JsonDocument) ParseFile(
  path: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<JsonDocument, JsonError>;

/**
 * @brief Document root node (retain-copy of the durable tree root).
 */
pub method(JsonDocument) Root() -> Json;

/**
 * @brief SAX/DOM Writer — implements `JsonHandler`; events or `Accept` → toolchain JSON text.
 * @see docs/design/stdlib/json.md §0.4 · §1.5
 */
/**
 * @note Handler methods are on the product face; private shell rebuilds via DomBuilder
 *       for `Accept` (host-nyra pub-struct `implements` itable edge — DomBuilder peer).
 */
pub struct JsonWriter { st: *mut int8; }

/**
 * @brief Construct an empty Writer (Handler state on the heap).
 */
pub static method(JsonWriter) New() -> JsonWriter;

/**
 * @brief UTF-8 JSON text accumulated from Handler events / `Accept`.
 */
pub method(JsonWriter) GetString() -> string;

/**
 * @brief Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 */
pub static method(JsonWriter) Emit(node: Json) -> string;

pub method(JsonWriter) Null() -> bool;
pub method(JsonWriter) Bool(b: bool) -> bool;
pub method(JsonWriter) Int64(v: int64) -> bool;
pub method(JsonWriter) UInt64(v: uint64) -> bool;
pub method(JsonWriter) Number(raw: string) -> bool;
pub method(JsonWriter) String(s: string) -> bool;
pub method(JsonWriter) StartObject() -> bool;
pub method(JsonWriter) Key(k: string) -> bool;
pub method(JsonWriter) EndObject(member_count: int32) -> bool;
pub method(JsonWriter) StartArray() -> bool;
pub method(JsonWriter) EndArray(element_count: int32) -> bool;

/**
 * @brief Walk this DOM node publishing Handler events (Object/Array names).
 * @returns `false` if any Handler method aborts.
 */
pub method(Json) Accept(handler: JsonHandler) -> bool;

/**
 * @brief JSON `null`. Arm 0 of `Json`.
 */
pub struct JsonNull { _pad: int8; }

/**
 * @brief JSON bool (`true` / `false`). Arm 1.
 */
pub struct JsonBool { value: bool; }

/**
 * @brief Decimal signed integer that fits `int64`. Arm 2.
 */
pub struct JsonInt { value: int64; unsigned_value: uint64; is_unsigned: bool; }

/**
 * @brief Exact JSON number lexeme used for fractions, exponents, and integers outside uint64.
 * @note Preserves the original spelling so parse/emit does not lose precision.
 */
pub struct JsonNumber { value: string; }

/**
 * @brief JSON string (UTF-8; escapes decoded). Arm 3.
 */
pub struct JsonStr { value: string; }

/**
 * @brief Array node; `items` insertion order. Arm 4.
 */
pub struct JsonArray { items: Array<Json>; }

/**
 * @brief One object entry; keys are strings only.
 */
pub struct JsonObjectEntry { key: string; value: Json; }

/**
 * @brief Object node; `entries` insertion / parse order. Arm 5.
 */
pub struct JsonObject { entries: Array<JsonObjectEntry>; }

/**
 * @brief In-memory JSON value tree.
 * @note json.md §1.3 escape hatch: `struct Json { node: variant<…> }` because recursive
 *       `typedef Json = variant<…>` through `Array<Json>` is rejected. Do not rename to JsonNode.
 */
pub struct Json { node: variant<JsonNull, JsonBool, JsonInt, JsonNumber, JsonStr, JsonArray, JsonObject>; }

/**
 * @brief Parse or I/O failure from this library (not a compiler `NYxxxx`).
 * @note `line` / `column` are 1-based for scan/parse errors; I/O may use 0.
 */
pub struct JsonError { line: int32; column: int32; message: string; }

/**
 * @brief First entry whose key equals `key`, or `nil` if absent.
 * @param key Object key (string keys only).
 * @returns Matching value, or `nil`.
 */
pub method(JsonObject) Get(key: string) -> Json?;

/**
 * @brief Entry count.
 * @returns Number of `entries`.
 */
pub method(JsonObject) Len() -> int32;

/**
 * @brief Key of the entry at 0-based `index`, or `nil` if out of range.
 * @note Cross-package field access on `JsonObjectEntry` is not available; use this helper.
 */
pub method(JsonObject) KeyAt(index: int32) -> string?;

/**
 * @brief Value of the entry at 0-based `index`, or `nil` if out of range.
 */
pub method(JsonObject) ValueAt(index: int32) -> Json?;

/**
 * @brief Element at 0-based `index`, or `nil` if out of range.
 * @param index Array index.
 * @returns Matching item, or `nil`.
 */
pub method(JsonArray) Get(index: int32) -> Json?;

/**
 * @brief Item count.
 * @returns Number of `items`.
 */
pub method(JsonArray) Len() -> int32;

/**
 * @brief UTF-8 payload of a string scalar (cross-package accessor).
 */
pub method(JsonStr) Text() -> string;

/**
 * @brief Integer scalar payload.
 */
pub method(JsonInt) I64() -> int64;
pub method(JsonNumber) Text() -> string;

/**
 * @brief Bool scalar payload.
 */
pub method(JsonBool) Value() -> bool;

pub func JsonAsInt(doc: Json) -> int64?;
pub func JsonAsUInt64(doc: Json) -> uint64?;
pub func JsonAsNumber(doc: Json) -> string?;
pub func JsonAsBool(doc: Json) -> bool?;
pub func JsonAsStr(doc: Json) -> string?;
pub func JsonAsObject(doc: Json) -> JsonObject?;
pub func JsonAsArray(doc: Json) -> JsonArray?;
pub func JsonIsNull(doc: Json) -> bool;

/**
 * @brief Construct scalar / collection nodes without cross-package `.node` field access.
 * @note Callers outside package `json` should use these (or `JsonWriter`) rather than
 *       `Json{ node: … }` literals — host codegen NY6002 on `.node` in large importers.
 */
pub func JsonFromBool(v: bool) -> Json;
pub func JsonFromInt(v: int64) -> Json;
pub func JsonFromUInt64(v: uint64) -> Json;
pub func JsonFromNumber(raw: string) -> Json?;
pub func JsonFromStr(s: string) -> Json;
pub func JsonFromArray(items: Array<Json>) -> Json;
pub func JsonFromObject(entries: Array<JsonObjectEntry>) -> Json;

/**
 * @brief 1-based line (0 for I/O errors).
 */
pub method(JsonError) Line() -> int32;

/**
 * @brief 1-based column (0 for I/O errors).
 */
pub method(JsonError) Column() -> int32;

/**
 * @brief English error detail (no `NYxxxx`).
 */
pub method(JsonError) Message() -> string;
