/**
 * @brief JsonDocument + Handler adapter DOM build (m_v0.19_p2).
 * @note Reader publishes SAX events; private builder copies Key/String into `durable`.
 * @note Open containers use a malloc'd linked stack (not `Array<private struct>` — that
 *       breaks sizeof across some barrel import edges). Object/array shells use
 *       `Array.NewWithAllocator(durable)` so Push/grow honor Document durable (Y01).
 * @see docs/design/stdlib/json.md §0.4–0.6
 */
part of JsonTypes;

/**
 * @brief One open object or array while the Handler adapter builds the tree (RapidJSON stack peer).
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

func json_null_node() -> Json {
  return Json{ node: JsonNull{ _pad: 0 } };
}

func json_bool_node(v: bool) -> Json {
  return Json{ node: JsonBool{ value: v } };
}

func json_int_node(v: int64) -> Json {
  return JsonFromInt(v);
}

func json_str_node(v: string) -> Json {
  return Json{ node: JsonStr{ value: v } };
}

func json_doc_fail(line: int32, column: int32, message: string) -> Result<JsonDocument, JsonError> {
  var msg: string = message;
  if message.length > 0 {
    var out: string = string.Alloc(message.length);
    memcpy((out.data as *mut uint8), message.data, message.length as uintptr);
    msg = out;
  }
  let err: JsonError = JsonError{ line: line, column: column, message: msg };
  return Err<JsonDocument, JsonError>(err);
}

func json_dom_fail() -> Result<JsonDocument, JsonError> {
  return json_doc_fail(1, 1, "document build failed");
}

func json_doc_ok(doc: JsonDocument) -> Result<JsonDocument, JsonError> {
  return Ok<JsonDocument, JsonError>(doc);
}

func json_doc_io_kind(e: IoError) -> string {
  if e == IoError.NotFound {
    return "file not found";
  }
  if e == IoError.PermissionDenied {
    return "permission denied";
  }
  if e == IoError.IsADirectory {
    return "path is a directory";
  }
  if e == IoError.NotADirectory {
    return "path is not a directory";
  }
  if e == IoError.InvalidArgument {
    return "invalid path";
  }
  return "I/O error";
}

/**
 * @brief Copy `s` into `durable` and adopt as a heap string (survives scratch Reset).
 * @note Requires process-heap durable (`CreateAllocator`); drop frees via `_nyra_*`.
 */
func json_durable_copy(durable: Allocator, s: string) -> string {
  if s.length <= 0 {
    return json_empty_str();
  }
  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = durable.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return json_empty_str();
  }
  memcpy(p, s.data as *const uint8, n);
  return string.AdoptFrom(p as *const int8, s.length);
}

/**
 * @brief Reuse static storage for common schema keys instead of duplicating
 *        the same short key string for every JSON object entry.
 * @note Unknown user keys still get copied into the document's durable arena.
 */
func json_dom_static_key(key: string) -> string? {
  if key == "ABI" { return "ABI"; }
  if key == "Args" { return "Args"; }
  if key == "Assembly" { return "Assembly"; }
  if key == "Bits" { return "Bits"; }
  if key == "Body" { return "Body"; }
  if key == "CChar" { return "CChar"; }
  if key == "Column" { return "Column"; }
  if key == "Condition" { return "Condition"; }
  if key == "DebugName" { return "DebugName"; }
  if key == "Element" { return "Element"; }
  if key == "Else" { return "Else"; }
  if key == "EndByte" { return "EndByte"; }
  if key == "EndColumn" { return "EndColumn"; }
  if key == "EndLine" { return "EndLine"; }
  if key == "External" { return "External"; }
  if key == "Fields" { return "Fields"; }
  if key == "File" { return "File"; }
  if key == "Functions" { return "Functions"; }
  if key == "Globals" { return "Globals"; }
  if key == "ID" { return "ID"; }
  if key == "Index" { return "Index"; }
  if key == "Indices" { return "Indices"; }
  if key == "Initializers" { return "Initializers"; }
  if key == "Inline" { return "Inline"; }
  if key == "Kind" { return "Kind"; }
  if key == "Left" { return "Left"; }
  if key == "Length" { return "Length"; }
  if key == "Line" { return "Line"; }
  if key == "LinkName" { return "LinkName"; }
  if key == "Linkage" { return "Linkage"; }
  if key == "Module" { return "Module"; }
  if key == "Name" { return "Name"; }
  if key == "Op" { return "Op"; }
  if key == "Origin" { return "Origin"; }
  if key == "Params" { return "Params"; }
  if key == "PointerSized" { return "PointerSized"; }
  if key == "ProfileSites" { return "ProfileSites"; }
  if key == "RCProfileSites" { return "RCProfileSites"; }
  if key == "Readonly" { return "Readonly"; }
  if key == "RequiredPointerBytes" { return "RequiredPointerBytes"; }
  if key == "Return" { return "Return"; }
  if key == "RuntimeRequirements" { return "RuntimeRequirements"; }
  if key == "Signed" { return "Signed"; }
  if key == "Source" { return "Source"; }
  if key == "StartByte" { return "StartByte"; }
  if key == "Symbol" { return "Symbol"; }
  if key == "Synthetic" { return "Synthetic"; }
  if key == "ThreadLocal" { return "ThreadLocal"; }
  if key == "Type" { return "Type"; }
  if key == "Types" { return "Types"; }
  if key == "Value" { return "Value"; }
  if key == "Variadic" { return "Variadic"; }
  if key == "Version" { return "Version"; }
  return nil;
}

func json_dom_state_new(durable: Allocator) -> JsonDomState {
  return JsonDomState{
    durable: durable,
    top: ptr<JsonDomFrame>.null(),
    depth: 0,
    root: json_null_node(),
    has_root: false,
    failed: false
  };
}

func json_dom_empty_object(durable: Allocator) -> JsonObject {
  return JsonObject{ entries: Array<JsonObjectEntry>.NewWithAllocator(durable) };
}

func json_dom_empty_array(durable: Allocator) -> JsonArray {
  return JsonArray{ items: Array<Json>.NewWithAllocator(durable) };
}

func json_dom_frame_alloc(
  durable: Allocator,
  is_object: bool,
  prev: *mut JsonDomFrame
) -> *mut JsonDomFrame {
  let nbytes: int64 = sizeof(JsonDomFrame) as int64;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8 as int64);
  if raw == (ptr<int8>.null()) {
    return ptr<JsonDomFrame>.null();
  }
  memset(raw as *mut uint8, 0 as uint8, nbytes as uintptr);
  let fp: *mut JsonDomFrame = cast<JsonDomFrame>.pointer(raw);
  unsafe {
    (*fp).is_object = is_object;
    (*fp).object = json_dom_empty_object(durable);
    (*fp).array = json_dom_empty_array(durable);
    (*fp).pending_key = json_empty_str();
    (*fp).has_pending_key = false;
    (*fp).prev = prev;
  }
  return fp;
}

func json_dom_frame_free(fp: *mut JsonDomFrame) -> void {
  if fp == (ptr<JsonDomFrame>.null()) {
    return;
  }
  unsafe {
    (*fp).pending_key = json_empty_str();
    (*fp).object = JsonObject{ entries: Array<JsonObjectEntry>{} };
    (*fp).array = JsonArray{ items: Array<Json>{} };
    (*fp).prev = ptr<JsonDomFrame>.null();
  }
  _nyra_free(cast<int8>.pointer(fp));
}

func json_dom_clear_stack(st: *mut JsonDomState) -> void {
  unsafe {
    var cur: *mut JsonDomFrame = (*st).top;
    while cur != (ptr<JsonDomFrame>.null()) {
      let prev: *mut JsonDomFrame = (*cur).prev;
      json_dom_frame_free(cur);
      cur = prev;
    }
    (*st).top = ptr<JsonDomFrame>.null();
    (*st).depth = 0;
  }
}

func json_dom_push_object(st: *mut JsonDomState) -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = json_dom_frame_alloc((*st).durable, true, (*st).top);
    if fp == (ptr<JsonDomFrame>.null()) {
      (*st).failed = true;
      return false;
    }
    (*st).top = fp;
    (*st).depth = (*st).depth + 1;
  }
  return true;
}

func json_dom_push_array(st: *mut JsonDomState) -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = json_dom_frame_alloc((*st).durable, false, (*st).top);
    if fp == (ptr<JsonDomFrame>.null()) {
      (*st).failed = true;
      return false;
    }
    (*st).top = fp;
    (*st).depth = (*st).depth + 1;
  }
  return true;
}

func json_dom_add_value(st: *mut JsonDomState, v: Json) -> bool {
  unsafe {
    if (*st).failed {
      return false;
    }
    let fp: *mut JsonDomFrame = (*st).top;
    if fp == (ptr<JsonDomFrame>.null()) {
      (*st).root = v;
      (*st).has_root = true;
      return true;
    }
    if (*fp).is_object {
      if !(*fp).has_pending_key {
        (*st).failed = true;
        return false;
      }
      let key: string = move((*fp).pending_key);
      (*fp).pending_key = json_empty_str();
      (*fp).has_pending_key = false;
      (*fp).object.entries.Push(JsonObjectEntry{ key: move(key), value: move(v) });
      return true;
    }
    (*fp).array.items.Push(move(v));
    return true;
  }
}

func json_dom_end_object(st: *mut JsonDomState) -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = (*st).top;
    if fp == (ptr<JsonDomFrame>.null()) {
      (*st).failed = true;
      return false;
    }
    if !(*fp).is_object {
      (*st).failed = true;
      return false;
    }
    let object: JsonObject = move((*fp).object);
    let node: Json = Json{ node: move(object) };
    (*fp).object = JsonObject{ entries: Array<JsonObjectEntry>{} };
    (*st).top = (*fp).prev;
    (*st).depth = (*st).depth - 1;
    json_dom_frame_free(fp);
    return json_dom_add_value(st, move(node));
  }
}

func json_dom_end_array(st: *mut JsonDomState) -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = (*st).top;
    if fp == (ptr<JsonDomFrame>.null()) {
      (*st).failed = true;
      return false;
    }
    if (*fp).is_object {
      (*st).failed = true;
      return false;
    }
    let items: JsonArray = move((*fp).array);
    let node: Json = Json{ node: move(items) };
    (*fp).array = JsonArray{ items: Array<Json>{} };
    (*st).top = (*fp).prev;
    (*st).depth = (*st).depth - 1;
    json_dom_frame_free(fp);
    return json_dom_add_value(st, move(node));
  }
}

method(JsonDomBuilder) Null() -> bool {
  return json_dom_add_value(self.st, json_null_node());
}

method(JsonDomBuilder) Bool(b: bool) -> bool {
  return json_dom_add_value(self.st, json_bool_node(b));
}

method(JsonDomBuilder) Int64(v: int64) -> bool {
  return json_dom_add_value(self.st, json_int_node(v));
}

method(JsonDomBuilder) UInt64(v: uint64) -> bool {
  return json_dom_add_value(self.st, JsonFromUInt64(v));
}

method(JsonDomBuilder) String(s: string) -> bool {
  unsafe {
    let heap_s: string = json_durable_copy((*self.st).durable, s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*self.st).failed = true;
      return false;
    }
    return json_dom_add_value(self.st, json_str_node(heap_s));
  }
}

method(JsonDomBuilder) StartObject() -> bool {
  return json_dom_push_object(self.st);
}

method(JsonDomBuilder) Key(k: string) -> bool {
  unsafe {
    let fp: *mut JsonDomFrame = (*self.st).top;
    if fp == (ptr<JsonDomFrame>.null()) {
      (*self.st).failed = true;
      return false;
    }
    if !(*fp).is_object {
      (*self.st).failed = true;
      return false;
    }
    let static_key: string? = json_dom_static_key(k);
    var heap_k: string = json_empty_str();
    if static_key != nil { heap_k = static_key as string; }
    else {
      heap_k = json_durable_copy((*self.st).durable, k);
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
  let _mc: int32 = member_count;
  return json_dom_end_object(self.st);
}

method(JsonDomBuilder) StartArray() -> bool {
  return json_dom_push_array(self.st);
}

method(JsonDomBuilder) EndArray(element_count: int32) -> bool {
  let _ec: int32 = element_count;
  return json_dom_end_array(self.st);
}

/**
 * @brief Parse `text` → durable DOM via Reader + Handler adapter.
 */
pub static method(JsonDocument) Parse(
  text: string,
  durable: Allocator,
  scratch: Allocator
) -> Result<JsonDocument, JsonError> {
  let frame: *mut uint8 = durable.Alloc(1 as uintptr);
  if frame == (ptr<uint8>.null()) {
    return json_doc_fail(1, 1, "durable allocator exhausted");
  }

  var state: JsonDomState = json_dom_state_new(durable);
  let stp: *mut JsonDomState = cast<JsonDomState>.pointer(& mut state);
  var builder: JsonDomBuilder = JsonDomBuilder{ st: stp };
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse(text, builder, scratch);
  if r.IsErr() {
    json_dom_clear_stack(stp);
    let eo: JsonError? = r.get_if<JsonError>();
    if eo == nil {
      return json_doc_fail(1, 1, "parse failed");
    }
    let e: JsonError = eo as JsonError;
    return json_doc_fail(e.line, e.column, e.message);
  }
  unsafe {
    if (*stp).failed || !(*stp).has_root {
      json_dom_clear_stack(stp);
      return json_dom_fail();
    }
    if (*stp).depth != 0 {
      json_dom_clear_stack(stp);
      return json_dom_fail();
    }
    let doc: JsonDocument = JsonDocument{ root: (*stp).root };
    (*stp).has_root = false;
    (*stp).root = json_null_node();
    return json_doc_ok(doc);
  }
}

/**
 * @brief Read `path` with stdlib `File`, then `Parse`.
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
      return json_doc_fail(0, 0, "I/O error reading JSON file: ".Concat(path));
    }
    let msg: string = json_doc_io_kind(eo as IoError).Concat(" reading JSON file: ").Concat(path);
    return json_doc_fail(0, 0, msg);
  }
  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return json_doc_fail(0, 0, "I/O error reading JSON file: ".Concat(path));
  }
  let src: string = text_opt as string;
  let heap_text: string = copy(src);
  return JsonDocument.Parse(heap_text, durable, scratch);
}

/**
 * @brief Document root (by-value retain of the durable tree root).
 */
pub method(JsonDocument) Root() -> Json {
  return self.root;
}
