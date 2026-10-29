// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of JsonDom;

/**
 * @brief JsonWriter + Json.Accept (m_v0.19_p3).
 * @note Accept body is inlined — host-nyra crashes when `method(Json)` passes `self` by value
 *   into another `Json`-typed parameter (retainStringsInValue / ExtractValue).
 * @see docs/design/stdlib/json.md §0.4 · §1.5
 */

/**
 * @brief SAX/DOM Writer — implements `JsonHandler`; events or `Accept` → toolchain JSON text.
 * @see docs/design/stdlib/json.md §0.4 · §1.5
 *
 * @note Handler methods are on the product face; private shell rebuilds via DomBuilder for
 *   `Accept` (host-nyra pub-struct `implements` itable edge — DomBuilder peer).
 */
pub struct JsonWriter {
  st: *mut int8;
}

/**
 * @brief Publish one DOM node as Handler events (child walk; free helper).
 * @note Key/String temps are scratch-backed views (Document copies into durable).
 */
func json_publish_node(node: Json, handler: JsonHandler, scratch: Allocator) -> bool {
  if node.node.holds<JsonNull>() {
    return handler.Null();
  }

  if node.node.holds<JsonBool>() {
    let bv: JsonBool? = node.node.get_if<JsonBool>();
    if bv == nil {
      return handler.Null();
    }

    let b: JsonBool = bv as JsonBool;

    return handler.Bool(b.value);
  }

  if node.node.holds<JsonInt>() {
    let iv: JsonInt? = node.node.get_if<JsonInt>();
    if iv == nil {
      return handler.Null();
    }

    let n: JsonInt = iv as JsonInt;
    if n.is_unsigned {
      return handler.UInt64(n.unsigned_value);
    }

    return handler.Int64(n.value);
  }

  if node.node.holds<JsonNumber>() {
    let number: JsonNumber? = node.node.get_if<JsonNumber>();
    if number == nil {
      return handler.Null();
    }

    let raw: string = JsonScratchCopy(scratch,(number as JsonNumber).value);
    if raw.length != (number as JsonNumber).value.length {
      return false;
    }

    return handler.Number(raw);
  }

  if node.node.holds<JsonStr>() {
    let sv: JsonStr? = node.node.get_if<JsonStr>();
    if sv == nil {
      return handler.Null();
    }

    let s: JsonStr = sv as JsonStr;
    let view: string = JsonScratchCopy(scratch, s.value);
    if (s.value.length > 0) && (view.length <= 0) {
      return false;
    }

    return handler.String(view);
  }

  if node.node.holds<JsonArray>() {
    let arr_opt: JsonArray? = node.node.get_if<JsonArray>();
    if arr_opt == nil {
      return handler.Null();
    }

    var arrv: JsonArray = arr_opt as JsonArray;
    if !handler.StartArray() {
      return false;
    }

    let n: int32 = arrv.Len();
    var i: int32 = 0;
    while i < n {
      unsafe {
        let ip: *mut Json = &mut arrv.items.buf[i];
        if !json_publish_node(*ip, handler, scratch) {
          return false;
        }
      }

      i = i + 1;
    }

    return handler.EndArray(n);
  }

  if node.node.holds<JsonObject>() {
    let obj_opt: JsonObject? = node.node.get_if<JsonObject>();
    if obj_opt == nil {
      return handler.Null();
    }

    var objv: JsonObject = obj_opt as JsonObject;
    if !handler.StartObject() {
      return false;
    }

    let n: int32 = objv.Len();
    var i: int32 = 0;
    while i < n {
      unsafe {
        let ep: *mut JsonObjectEntry = &mut objv.entries.buf[i];
        let kview: string = JsonScratchCopy(scratch,(*ep).key);
        if ((*ep).key.length > 0) && (kview.length <= 0) {
          return false;
        }

        if !handler.Key(kview) {
          return false;
        }

        if !json_publish_node((*ep).value, handler, scratch) {
          return false;
        }
      }

      i = i + 1;
    }

    return handler.EndObject(n);
  }

  return handler.Null();
}

/**
 * @brief Walk this DOM node publishing Handler events (Object/Array names).
 * @returns `false` if any Handler method aborts.
 */
pub method(Json) Accept(handler: JsonHandler) -> bool {
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  if self.node.holds<JsonNull>() {
    return handler.Null();
  }

  if self.node.holds<JsonBool>() {
    let bv: JsonBool? = self.node.get_if<JsonBool>();
    if bv == nil {
      return handler.Null();
    }

    let b: JsonBool = bv as JsonBool;

    return handler.Bool(b.value);
  }

  if self.node.holds<JsonInt>() {
    let iv: JsonInt? = self.node.get_if<JsonInt>();
    if iv == nil {
      return handler.Null();
    }

    let n: JsonInt = iv as JsonInt;
    if n.is_unsigned {
      return handler.UInt64(n.unsigned_value);
    }

    return handler.Int64(n.value);
  }

  if self.node.holds<JsonNumber>() {
    let number: JsonNumber? = self.node.get_if<JsonNumber>();
    if number == nil {
      return handler.Null();
    }

    let value: string = (number as JsonNumber).value;
    let raw: string = JsonScratchCopy(scratch, value);
    if raw.length != value.length {
      return false;
    }

    return handler.Number(raw);
  }

  if self.node.holds<JsonStr>() {
    let sv: JsonStr? = self.node.get_if<JsonStr>();
    if sv == nil {
      return handler.Null();
    }

    let s: JsonStr = sv as JsonStr;
    let view: string = JsonScratchCopy(scratch, s.value);
    if (s.value.length > 0) && (view.length <= 0) {
      return false;
    }

    return handler.String(view);
  }

  if self.node.holds<JsonArray>() {
    let arr_opt: JsonArray? = self.node.get_if<JsonArray>();
    if arr_opt == nil {
      return handler.Null();
    }

    var arrv: JsonArray = arr_opt as JsonArray;
    if !handler.StartArray() {
      return false;
    }

    let n: int32 = arrv.Len();
    var i: int32 = 0;
    while i < n {
      unsafe {
        let ip: *mut Json = &mut arrv.items.buf[i];
        // Child walk via free helper (not method(Json) self-pass).
        if !json_publish_node(*ip, handler, scratch) {
          return false;
        }
      }

      i = i + 1;
    }

    return handler.EndArray(n);
  }

  if self.node.holds<JsonObject>() {
    let obj_opt: JsonObject? = self.node.get_if<JsonObject>();
    if obj_opt == nil {
      return handler.Null();
    }

    var objv: JsonObject = obj_opt as JsonObject;
    if !handler.StartObject() {
      return false;
    }

    let n: int32 = objv.Len();
    var i: int32 = 0;
    while i < n {
      unsafe {
        let ep: *mut JsonObjectEntry = &mut objv.entries.buf[i];
        let kview: string = JsonScratchCopy(scratch,(*ep).key);
        if ((*ep).key.length > 0) && (kview.length <= 0) {
          return false;
        }

        if !handler.Key(kview) {
          return false;
        }

        if !json_publish_node((*ep).value, handler, scratch) {
          return false;
        }
      }

      i = i + 1;
    }

    return handler.EndObject(n);
  }

  return handler.Null();
}

/**
 * @brief Construct an empty Writer (Handler state on the heap).
 * @returns The JsonWriter value described above, retaining the documented ownership and
 *   default-state semantics.
 */
pub static method(JsonWriter) New() -> JsonWriter {
  // Heap shell for JsonDomState (peer yaml Writer.New 1024; keep headroom for Json root).
  let nbytes: int64 = 4096 as int64;
  let raw: *mut int8 = _nyra_malloc(nbytes, 8 as int64);
  if raw == (ptr<int8>.null()) {
    return JsonWriter{st: ptr<int8>.null()};
  }

  // Field assignment releases prior owned values. Establish an empty state
  // before assigning into freshly allocated, potentially recycled bytes.
  memset(raw as *mut uint8, 0 as uint8, nbytes as uintptr);
  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(raw);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  unsafe {
    (*sp).durable = durable;
    (*sp).top = ptr<JsonDomFrame>.null();
    (*sp).depth = 0;
    (*sp).root = json_null_node();
    (*sp).has_root = false;
    (*sp).failed = false;
  }

  return JsonWriter{st: raw};
}

/**
 * @brief UTF-8 JSON text accumulated from Handler events / `Accept`.
 * @returns UTF-8 JSON text accumulated from Handler events / `Accept`.
 */
pub method(JsonWriter) GetString() -> string {
  if self.st == (ptr<int8>.null()) {
    return copy("null");
  }

  unsafe {
    let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);
    if (*sp).failed || ! (*sp).has_root {
      return copy("null");
    }

    if (*sp).depth != 0 {
      return copy("null");
    }

    return JsonEmitText((*sp).root);
  }
}

/**
 * @brief Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 * @returns Serialize `node` via `New` → `node.Accept(writer)` → `GetString`.
 */
pub static method(JsonWriter) Emit(node: Json) -> string {
  var w: JsonWriter = JsonWriter.New();
  if w.st == (ptr<int8>.null()) {
    return copy("null");
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(w.st);
  var builder: JsonDomBuilder = JsonDomBuilder{st: sp};
  let ok: bool = node.Accept(builder);
  if !ok {
    return copy("null");
  }

  return w.GetString();
}

/**
 * @brief Append a null scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) Null() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_add_value(sp, json_null_node());
}

/**
 * @brief Append a boolean scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) Bool(b: bool) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_add_value(sp, json_bool_node(b));
}

/**
 * @brief Append a signed integer scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) Int64(v: int64) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_add_value(sp, json_int_node(v));
}

/**
 * @brief Append an unsigned integer scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) UInt64(v: uint64) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_add_value(sp, JsonFromUInt64(v));
}

/**
 * @brief Append an exact validated JSON number lexeme.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) Number(raw: string) -> bool {
  if self.st == (ptr<int8>.null()) || !JsonNumberIsValid(raw) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);
  unsafe {
    let heap_raw: string = json_durable_copy((*sp).durable, raw);
    if (raw.length > 0) && (heap_raw.length <= 0) {
      (*sp).failed = true;

      return false;
    }

    return json_dom_add_value(sp, Json{node: JsonNumber{value: heap_raw}});
  }
}

/**
 * @brief Append a string scalar event.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) String(s: string) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);
  unsafe {
    let heap_s: string = json_durable_copy((*sp).durable, s);
    if (s.length > 0) && (heap_s.length <= 0) {
      (*sp).failed = true;

      return false;
    }

    return json_dom_add_value(sp, json_str_node(heap_s));
  }
}

/**
 * @brief Begin an object/mapping container.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) StartObject() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_push_object(sp);
}

/**
 * @brief Set the next object/mapping key.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) Key(k: string) -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);
  unsafe {
    let fp: *mut JsonDomFrame = (*sp).top;
    if fp == (ptr<JsonDomFrame>.null()) {
      (*sp).failed = true;

      return false;
    }

    if ! (*fp).is_object {
      (*sp).failed = true;

      return false;
    }

    let heap_k: string = json_durable_copy((*sp).durable, k);
    if (k.length > 0) && (heap_k.length <= 0) {
      (*sp).failed = true;

      return false;
    }

    (*fp).pending_key = heap_k;
    (*fp).has_pending_key = true;

    return true;
  }
}

/**
 * @brief Finish the current object/mapping event with its member count.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) EndObject(member_count: int32) -> bool {
  let _mc: int32 = member_count;
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_end_object(sp);
}

/**
 * @brief Begin an array/sequence container.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) StartArray() -> bool {
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_push_array(sp);
}

/**
 * @brief Finish the current array/sequence event with its element count.
 * @returns True when the DOM writer accepts the event; false for unavailable state or an
 *   event/build failure.
 */
pub method(JsonWriter) EndArray(element_count: int32) -> bool {
  let _ec: int32 = element_count;
  if self.st == (ptr<int8>.null()) {
    return false;
  }

  let sp: *mut JsonDomState = cast<JsonDomState>.pointer(self.st);

  return json_dom_end_array(sp);
}
