// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module JsonDom;
part "writer.ny";
import "stdlib:stdlib.ny";
import "interface/json.ni";
import "private/scalar.ny";
import "private/model.ny";
import "private/reader.ny";
import "private/emit.ny";

/**
 * @brief JsonDocument + Handler adapter DOM build (m_v0.19_p2).
 * @note Reader publishes SAX events; private builder copies Key/String into `durable`.
 * @note Open containers use a malloc'd linked stack (not `Array<private struct>` — that breaks
 *   sizeof across some barrel import edges). Object/array shells use
 *   `Array.NewWithAllocator(durable)` so Push/grow honor Document durable (Y01).
 * @see docs/design/stdlib/json.md §0.4–0.6
 */

/**
 * @brief One open object or array while the Handler adapter builds the tree (RapidJSON stack
 *   peer).
 */
struct JsonDomFrame {
  is_object: bool;
  object: JsonObject;
  array: JsonArray;
  pending_key: string;
  has_pending_key: bool;
  prev: *mut JsonDomFrame;
}

/**
 * @brief Mutable DOM build state (pointed at by the by-value Handler shell).
 */
struct JsonDomState {
  durable: Allocator;
  top: *mut JsonDomFrame;
  depth: int32;
  root: Json;
  has_root: bool;
  failed: bool;
}

/**
 * @brief Thin Handler shell — only a pointer; safe to pass as by-value JsonHandler.
 */
struct JsonDomBuilder implements JsonHandler {
  st: *mut JsonDomState;
}

/**
 * @brief Copy `s` into `durable` and adopt as a heap string (survives scratch Reset).
 * @note Requires process-heap durable (`CreateAllocator`); drop frees via `_nyra_*`.
 */
method(JsonDomState) CopyDurable(s: string) -> string {
  if s.length <= 0 {
    return "";
  }

  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = self.durable.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return "";
  }

  memcpy(p, s.data as *const uint8, n);

  return string.AdoptFrom(p as *const int8, s.length);
}

/**
 * @brief Reuse static storage for common schema keys instead of duplicating the same short key
 *   string for every JSON object entry.
 * @note Unknown user keys still get copied into the document's durable arena.
 */
static method(JsonDomState) StaticKey(key: string) -> string? {
  if key == "ABI" {
    return "ABI";
  }

  if key == "Args" {
    return "Args";
  }

  if key == "Assembly" {
    return "Assembly";
  }

  if key == "Bits" {
    return "Bits";
  }

  if key == "Body" {
    return "Body";
  }

  if key == "CChar" {
    return "CChar";
  }

  if key == "Column" {
    return "Column";
  }

  if key == "Condition" {
    return "Condition";
  }

  if key == "DebugName" {
    return "DebugName";
  }

  if key == "Element" {
    return "Element";
  }

  if key == "Else" {
    return "Else";
  }

  if key == "EndByte" {
    return "EndByte";
  }

  if key == "EndColumn" {
    return "EndColumn";
  }

  if key == "EndLine" {
    return "EndLine";
  }

  if key == "External" {
    return "External";
  }

  if key == "Fields" {
    return "Fields";
  }

  if key == "File" {
    return "File";
  }

  if key == "Functions" {
    return "Functions";
  }

  if key == "Globals" {
    return "Globals";
  }

  if key == "ID" {
    return "ID";
  }

  if key == "Index" {
    return "Index";
  }

  if key == "Indices" {
    return "Indices";
  }

  if key == "Initializers" {
    return "Initializers";
  }

  if key == "Inline" {
    return "Inline";
  }

  if key == "Kind" {
    return "Kind";
  }

  if key == "Left" {
    return "Left";
  }

  if key == "Length" {
    return "Length";
  }

  if key == "Line" {
    return "Line";
  }

  if key == "LinkName" {
    return "LinkName";
  }

  if key == "Linkage" {
    return "Linkage";
  }

  if key == "Module" {
    return "Module";
  }

  if key == "Name" {
    return "Name";
  }

  if key == "Op" {
    return "Op";
  }

  if key == "Origin" {
    return "Origin";
  }

  if key == "Params" {
    return "Params";
  }

  if key == "PointerSized" {
    return "PointerSized";
  }

  if key == "ProfileSites" {
    return "ProfileSites";
  }

  if key == "RCProfileSites" {
    return "RCProfileSites";
  }

  if key == "Readonly" {
    return "Readonly";
  }

  if key == "RequiredPointerBytes" {
    return "RequiredPointerBytes";
  }

  if key == "Return" {
    return "Return";
  }

  if key == "RuntimeRequirements" {
    return "RuntimeRequirements";
  }

  if key == "Signed" {
    return "Signed";
  }

  if key == "Source" {
    return "Source";
  }

  if key == "StartByte" {
    return "StartByte";
  }

  if key == "Symbol" {
    return "Symbol";
  }

  if key == "Synthetic" {
    return "Synthetic";
  }

  if key == "ThreadLocal" {
    return "ThreadLocal";
  }

  if key == "Type" {
    return "Type";
  }

  if key == "Types" {
    return "Types";
  }

  if key == "Value" {
    return "Value";
  }

  if key == "Variadic" {
    return "Variadic";
  }

  if key == "Version" {
    return "Version";
  }

  return nil;
}

static method(JsonDomState) New(durable: Allocator) -> JsonDomState {
  return JsonDomState{
    durable: durable,
    top: ptr<JsonDomFrame>.null(),
    depth: 0,
    root: Json{node: JsonNull{_pad: 0}},
    has_root: false,
    failed: false
  };
}

static method(JsonObject) WithAllocator(durable: Allocator) -> JsonObject {
  return JsonObject{entries: Array<JsonObjectEntry>.NewWithAllocator(durable)};
}

static method(JsonArray) WithAllocator(durable: Allocator) -> JsonArray {
  return JsonArray{items: Array<Json>.NewWithAllocator(durable)};
}

static method(JsonDomFrame) Allocate(
  durable: Allocator,
  is_object: bool,
  prev: *mut JsonDomFrame
) -> *mut JsonDomFrame {
  let nbytes: int64 = sizeof(JsonDomFrame) as int64;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8i64);
  if raw == (ptr<int8>.null()) {
    return ptr<JsonDomFrame>.null();
  }

  memset(raw as *mut uint8, 0u8, nbytes as uintptr);
  let fp: *mut JsonDomFrame = cast<JsonDomFrame>.pointer(raw);
  unsafe {
    (*fp).is_object = is_object;
    (*fp).object = JsonObject.WithAllocator(durable);
    (*fp).array = JsonArray.WithAllocator(durable);
    (*fp).pending_key = "";
    (*fp).has_pending_key = false;
    (*fp).prev = prev;
  }

  return fp;
}

static method(JsonDomFrame) Release(fp: *mut JsonDomFrame) -> void {
  if fp == (ptr<JsonDomFrame>.null()) {
    return;
  }

  unsafe {
    (*fp).pending_key = "";
    (*fp).object = JsonObject{entries: Array<JsonObjectEntry>{}};
    (*fp).array = JsonArray{items: Array<Json>{}};
    (*fp).prev = ptr<JsonDomFrame>.null();
  }

  _nyra_free(cast<int8>.pointer(fp));
}

method(JsonDomState) ClearStack() -> void {
  unsafe {
    var cur: *mut JsonDomFrame = self.top;
    while cur != (ptr<JsonDomFrame>.null()) {
      let prev: *mut JsonDomFrame = (*cur).prev;
      JsonDomFrame.Release(cur);
      cur = prev;
    }

    self.top = ptr<JsonDomFrame>.null();
    self.depth = 0;
  }
}

method(JsonDomState) PushObject() -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = JsonDomFrame.Allocate(self.durable, true,self.top);
    if fp == (ptr<JsonDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    self.top = fp;
    self.depth = self.depth + 1;
  }

  return true;
}

method(JsonDomState) PushArray() -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = JsonDomFrame.Allocate(self.durable, false,self.top);
    if fp == (ptr<JsonDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    self.top = fp;
    self.depth = self.depth + 1;
  }

  return true;
}

method(JsonDomState) AddValue(v: Json) -> bool {
  unsafe {
    if self.failed {
      return false;
    }

    let fp: *mut JsonDomFrame = self.top;
    if fp == (ptr<JsonDomFrame>.null()) {
      self.root = v;
      self.has_root = true;

      return true;
    }

    if (*fp).is_object {
      if ! (*fp).has_pending_key {
        self.failed = true;

        return false;
      }

      let key: string = move((*fp).pending_key);
      (*fp).pending_key = "";
      (*fp).has_pending_key = false;
      (*fp).object.entries.Push(JsonObjectEntry{key: move(key), value: move(v)});

      return true;
    }

    (*fp).array.items.Push(move(v));

    return true;
  }
}

method(JsonDomState) EndObject() -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = self.top;
    if fp == (ptr<JsonDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    if ! (*fp).is_object {
      self.failed = true;

      return false;
    }

    let object: JsonObject = move((*fp).object);
    let node: Json = Json{node: move(object)};
    (*fp).object = JsonObject{entries: Array<JsonObjectEntry>{}};
    self.top = (*fp).prev;
    self.depth = self.depth - 1;
    JsonDomFrame.Release(fp);

    return self.AddValue(move(node));
  }
}

method(JsonDomState) EndArray() -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = self.top;
    if fp == (ptr<JsonDomFrame>.null()) {
      self.failed = true;

      return false;
    }

    if (*fp).is_object {
      self.failed = true;

      return false;
    }

    let items: JsonArray = move((*fp).array);
    let node: Json = Json{node: move(items)};
    (*fp).array = JsonArray{items: Array<Json>{}};
    self.top = (*fp).prev;
    self.depth = self.depth - 1;
    JsonDomFrame.Release(fp);

    return self.AddValue(move(node));
  }
}

method(JsonDomBuilder) Null() -> bool {
  unsafe {
    return (*self.st).AddValue(Json{node: JsonNull{_pad: 0}});
  }
}

method(JsonDomBuilder) Bool(b: bool) -> bool {
  unsafe {
    return (*self.st).AddValue(Json.FromBool(b));
  }
}

method(JsonDomBuilder) Int64(v: int64) -> bool {
  unsafe {
    return (*self.st).AddValue(Json.FromInt(v));
  }
}

method(JsonDomBuilder) UInt64(v: uint64) -> bool {
  unsafe {
    return (*self.st).AddValue(Json.FromUInt64(v));
  }
}

method(JsonDomBuilder) Number(raw: string) -> bool {
  unsafe {
    if !JsonNumber.IsValid(raw) {
      (*self.st).failed = true;

      return false;
    }

    let heap_raw: string = (*self.st).CopyDurable(raw);
    if (raw.length > 0) && (heap_raw.length <= 0) {
      (*self.st).failed = true;

      return false;
    }

    return (*self.st).AddValue(Json{node: JsonNumber{value: heap_raw}});
    }
}

method(JsonDomBuilder) String(s: string) -> bool {
  unsafe {
    let heap_s: string = (*self.st).CopyDurable(s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*self.st).failed = true;

      return false;
    }

    return (*self.st).AddValue(Json{node: JsonStr{value: heap_s}});
    }
}

method(JsonDomBuilder) StartObject() -> bool {
  unsafe {
    return (*self.st).PushObject();
  }
}

method(JsonDomBuilder) Key(k: string) -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = (*self.st).top;
    if fp == (ptr<JsonDomFrame>.null()) {
      (*self.st).failed = true;

      return false;
    }

    if ! (*fp).is_object {
      (*self.st).failed = true;

      return false;
    }

    let static_key: string? = JsonDomState.StaticKey(k);
    var heap_k: string = "";
    if static_key != nil {
      heap_k = static_key as string;
    } else {
      heap_k = (*self.st).CopyDurable(k);
      if (k.length > 0) && (heap_k.length <= 0) {
        (*self.st).failed = true;

        return false;
      }
    }

    (*fp).pending_key = move(heap_k);
    (*fp).has_pending_key = true;

    return true;
  }
}

method(JsonDomBuilder) EndObject(member_count: int32) -> bool {
  unsafe {
    let _mc: int32 = member_count;

    return (*self.st).EndObject();
  }
}

method(JsonDomBuilder) StartArray() -> bool {
  unsafe {
    return (*self.st).PushArray();
  }
}

method(JsonDomBuilder) EndArray(element_count: int32) -> bool {
  unsafe {
    let _ec: int32 = element_count;

    return (*self.st).EndArray();
  }
}

/**
 * @brief Parse `text` into a durable DOM via Reader → Document Handler adapter.
 * @param text UTF-8 source; empty input is a Parse error (JSON grammar).
 * @param durable Allocator for Key/String (and Document storage); typical hosted:
 *   `CreateAllocator`.
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Reader temps; Reset after Ok must
 *   not pin Document.
 * @returns Ok with JsonDocument on success; Err with JsonError on the failure paths described
 *   above.
 */
pub static method(JsonDocument) Parse(
  text: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<JsonDocument, JsonError> {
  let frame: *mut uint8 = durable.Alloc(1up);
  if frame == (ptr<uint8>.null()) {
    return Err<JsonDocument, JsonError>(JsonError.New(1, 1, "durable allocator exhausted"));
  }

  var state: JsonDomState = JsonDomState.New(durable);
  let stp: *mut JsonDomState = cast<JsonDomState>.pointer(& mut state);
  var builder: JsonDomBuilder = JsonDomBuilder{st: stp};
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse(text, builder, scratch);
  if r.IsErr() {
    state.ClearStack();
    let eo: JsonError? = r.get_if<JsonError>();
    if eo == nil {
      return Err<JsonDocument, JsonError>(JsonError.New(1, 1, "parse failed"));
    }

    let e: JsonError = eo as JsonError;

    return Err<JsonDocument, JsonError>(JsonError.New(e.line, e.column, e.message));
  }

  unsafe {
    if (*stp).failed || ! (*stp).has_root {
      state.ClearStack();

      return Err<JsonDocument, JsonError>(JsonError.New(1, 1, "document build failed"));
    }

    if (*stp).depth != 0 {
      state.ClearStack();

      return Err<JsonDocument, JsonError>(JsonError.New(1, 1, "document build failed"));
    }

    let doc: JsonDocument = JsonDocument{root:(*stp).root};
    (*stp).has_root = false;
    (*stp).root = Json{node: JsonNull{_pad: 0}};

    return Ok<JsonDocument, JsonError>(doc);
  }
}

/**
 * @brief Read `path` then `JsonDocument.Parse`.
 * @returns Ok with JsonDocument on success; Err with JsonError on the failure paths described
 *   above.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub static method(JsonDocument) ParseFile(
  path: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<JsonDocument, JsonError> {
  let f: File = File.New(path);
  let rd: Result<string, IoError> = f.ReadAsString();
  if rd.IsErr() {
    let eo: IoError? = rd.get_if<IoError>();
    if eo == nil {
      return Err<JsonDocument, JsonError>(JsonError.New(0, 0, "I/O error reading JSON file: ".Concat(path)));
    }

    let msg: string = JsonError.IoDescription(eo as IoError).Concat(" reading JSON file: ").Concat(path);

    return Err<JsonDocument, JsonError>(JsonError.New(0, 0, msg));
  }

  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return Err<JsonDocument, JsonError>(JsonError.New(0, 0, "I/O error reading JSON file: ".Concat(path)));
  }

  let src: string = text_opt as string;
  let heap_text: string = copy(src);

  return JsonDocument.Parse(heap_text, durable, scratch);
}

/**
 * @brief Document root node (retain-copy of the durable tree root).
 * @returns The Json value described above, retaining the documented ownership and default-state
 *   semantics.
 */
pub method(JsonDocument) Root() -> Json {
  return self.root;
}
