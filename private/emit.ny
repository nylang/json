// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module JsonEncoding;
import "stdlib:stdlib.ny";
import "interface/json.ni";
import "private/scalar.ny";
import "private/model.ny";

/**
 * @brief Compact JSON emit (json.md §1.5).
 * @note Same TU as `Json` layouts so `holds` / `get_if` on `Json.node` resolve.
 * @note Product entry is `JsonWriter.Emit`; this is the shared body used by `GetString`.
 */

/** @brief Stateful JSON text encoder; owns output, not DOM mutation or parser state. */
pub struct JsonEmitter {
  buf: StringBuffer;
}

static method(JsonEmitter) HexDigit(n: int32) -> string {
  var d: int32 = n;
  if d < 0 {
    d = 0;
  }

  if d > 15 {
    d = 15;
  }

  if d < 10 {
    return string.Utf8Encode(48 + d);
  }

  return string.Utf8Encode(87 + d);
}

static method(JsonEmitter) EscapeByte(b: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(6);
  buf.Append("\\u00");
  buf.Append(JsonEmitter.HexDigit((b / 16) & 15));
  buf.Append(JsonEmitter.HexDigit(b & 15));

  return buf.Take();
}

/**
 * @brief Quote `s` as a JSON string (escapes `\\` `\"` + short forms / `\u00XX`).
 * @note Peer of `face_json_quote` / `yaml_emit_quote` escape subset (json.md §1.5).
 */
static method(JsonEmitter) Quote(s: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(s.length + 2);
  buf.Append("\"");
  var i: int32 = 0;
  let n: int32 = s.length;
  while i < n {
    let b: int32 = s.ByteAt(i);
    if b == 92 {
      buf.Append("\\\\");
      i = i + 1;
      continue;
    }

    if b == 34 {
      buf.Append("\\\"");
      i = i + 1;
      continue;
    }

    if b == 8 {
      buf.Append("\\b");
      i = i + 1;
      continue;
    }

    if b == 12 {
      buf.Append("\\f");
      i = i + 1;
      continue;
    }

    if b == 10 {
      buf.Append("\\n");
      i = i + 1;
      continue;
    }

    if b == 13 {
      buf.Append("\\r");
      i = i + 1;
      continue;
    }

    if b == 9 {
      buf.Append("\\t");
      i = i + 1;
      continue;
    }

    if (b < 32) || (b == 127) {
      buf.Append(JsonEmitter.EscapeByte(b));
      i = i + 1;
      continue;
    }

    let decoded: UtfDecodeResult = Text.DecodeUtf8(s, i);
    if !decoded.valid {
      let replacement: string? = Text.EncodeUtf8(65533);
      buf.Append(replacement as string);
      i = i + 1;
      continue;
    }

    let nch: int32 = decoded.byte_len;
    buf.Append(s.View(i, nch));
    i = i + nch;
  }

  buf.Append("\"");

  return buf.Take();
}

// Handle the signed minimum through unsigned magnitude instead of negating it in the signed domain.

// Compare retained DOM structure and scalar payloads to validate semantic round trips rather than output whitespace.
/** @brief Compare retained JSON tree kinds, scalar values and collection structure.
 * @returns True for recursively equal values; false for different kinds or contents. */
pub method(Json) Equals(b: Json) -> bool {
  if self.node.holds<JsonNull>() {
    return b.node.holds<JsonNull>();
  }

  if self.node.holds<JsonBool>() {
    if !b.node.holds<JsonBool>() {
      return false;
    }

    let ab: JsonBool? = self.node.get_if<JsonBool>();
    let bb: JsonBool? = b.node.get_if<JsonBool>();
    if ab == nil {
      return false;
    }

    if bb == nil {
      return false;
    }

    let abv: JsonBool = ab as JsonBool;
    let bbv: JsonBool = bb as JsonBool;

    return abv.value == bbv.value;
  }

  if self.node.holds<JsonInt>() {
    if !b.node.holds<JsonInt>() {
      return false;
    }

    let ai: JsonInt? = self.node.get_if<JsonInt>();
    let bi: JsonInt? = b.node.get_if<JsonInt>();
    if ai == nil {
      return false;
    }

    if bi == nil {
      return false;
    }

    let aiv: JsonInt = ai as JsonInt;
    let biv: JsonInt = bi as JsonInt;
    if aiv.is_unsigned != biv.is_unsigned {
      return false;
    }

    if aiv.is_unsigned {
      return aiv.unsigned_value == biv.unsigned_value;
    }

    return aiv.value == biv.value;
  }

  if self.node.holds<JsonNumber>() {
    if !b.node.holds<JsonNumber>() {
      return false;
    }

    let an: JsonNumber? = self.node.get_if<JsonNumber>();
    let bn: JsonNumber? = b.node.get_if<JsonNumber>();
    if an == nil || bn == nil {
      return false;
    }

    return (an as JsonNumber).value == (bn as JsonNumber).value;
  }

  if self.node.holds<JsonStr>() {
    if !b.node.holds<JsonStr>() {
      return false;
    }

    let asv: JsonStr? = self.node.get_if<JsonStr>();
    let bsv: JsonStr? = b.node.get_if<JsonStr>();
    if asv == nil {
      return false;
    }

    if bsv == nil {
      return false;
    }

    let asvv: JsonStr = asv as JsonStr;
    let bsvv: JsonStr = bsv as JsonStr;

    return (asvv.value == bsvv.value);
  }

  if self.node.holds<JsonArray>() {
    if !b.node.holds<JsonArray>() {
      return false;
    }

    let aarr: JsonArray? = self.node.get_if<JsonArray>();
    let barr: JsonArray? = b.node.get_if<JsonArray>();
    if aarr == nil {
      return false;
    }

    if barr == nil {
      return false;
    }

    var sa: JsonArray = aarr as JsonArray;
    var sb: JsonArray = barr as JsonArray;
    let n: int32 = sa.Len();
    if n != sb.Len() {
      return false;
    }

    var i: int32 = 0;
    while i < n {
      unsafe {
        let pa: *mut Json = &mut sa.items.buf[i];
        let pb: *mut Json = &mut sb.items.buf[i];
        if !((*pa)).Equals((*pb)) {
          return false;
        }
      }

      i = i + 1;
    }

    return true;
  }

  if self.node.holds<JsonObject>() {
    if !b.node.holds<JsonObject>() {
      return false;
    }

    let am: JsonObject? = self.node.get_if<JsonObject>();
    let bm: JsonObject? = b.node.get_if<JsonObject>();
    if am == nil {
      return false;
    }

    if bm == nil {
      return false;
    }

    var ma: JsonObject = am as JsonObject;
    var mb: JsonObject = bm as JsonObject;
    let n: int32 = ma.Len();
    if n != mb.Len() {
      return false;
    }

    var i: int32 = 0;
    while i < n {
      unsafe {
        let ea: *mut JsonObjectEntry = &mut ma.entries.buf[i];
        let eb: *mut JsonObjectEntry = &mut mb.entries.buf[i];
        if ((*ea).key != (*eb).key) {
          return false;
        }

        if !((*ea).value).Equals((*eb).value) {
          return false;
        }
      }

      i = i + 1;
    }

    return true;
  }

  return false;
}

method(JsonEmitter) EmitArray(arrv: JsonArray) -> void {
  self.buf.Append("[");
  let n: int32 = arrv.Len();
  var i: int32 = 0;
  while i < n {
    if i > 0 {
      self.buf.Append(",");
    }

    unsafe {
      let ip: *mut Json = &mut arrv.items.buf[i];
      self.EmitJson(*ip);
    }

    i = i + 1;
  }

  self.buf.Append("]");
}

method(JsonEmitter) EmitObject(objv: JsonObject) -> void {
  self.buf.Append("{");
  let n: int32 = objv.Len();
  var i: int32 = 0;
  while i < n {
    if i > 0 {
      self.buf.Append(",");
    }

    unsafe {
      let ep: *mut JsonObjectEntry = &mut objv.entries.buf[i];
      self.buf.Append(JsonEmitter.Quote((*ep).key));
      self.buf.Append(":");
      self.EmitJson((*ep).value);
    }

    i = i + 1;
  }

  self.buf.Append("}");
}

method(JsonEmitter) EmitJson(node: Json) -> void {
  if node.node.holds<JsonNull>() {
    self.buf.Append("null");
    return;
  }

  if node.node.holds<JsonBool>() {
    let bv: JsonBool? = node.node.get_if<JsonBool>();
    if bv != nil {
      let b: JsonBool = bv as JsonBool;
      if b.value {
        self.buf.Append("true");
      } else {
        self.buf.Append("false");
      }
    }

    return;
  }

  if node.node.holds<JsonInt>() {
    let iv: JsonInt? = node.node.get_if<JsonInt>();
    if iv != nil {
      let n: JsonInt = iv as JsonInt;
      if n.is_unsigned {
        self.buf.Append((n.unsigned_value).ToString());
      } else {
        self.buf.Append((n.value).ToString());
      }
    }

    return;
  }

  if node.node.holds<JsonNumber>() {
    let number: JsonNumber? = node.node.get_if<JsonNumber>();
    if number != nil {
      self.buf.Append((number as JsonNumber).value);
    }

    return;
  }

  if node.node.holds<JsonStr>() {
    let sv: JsonStr? = node.node.get_if<JsonStr>();
    if sv != nil {
      let s: JsonStr = sv as JsonStr;
      self.buf.Append(JsonEmitter.Quote(copy(s.value)));
    }

    return;
  }

  if node.node.holds<JsonArray>() {
    let arr: JsonArray? = node.node.get_if<JsonArray>();
    if arr != nil {
      self.EmitArray(arr as JsonArray);
    }

    return;
  }

  if node.node.holds<JsonObject>() {
    let obj: JsonObject? = node.node.get_if<JsonObject>();
    if obj != nil {
      self.EmitObject(obj as JsonObject);
    }

    return;
  }

  self.buf.Append("null");
}

/**
 * @brief Serialize `node` to compact toolchain JSON (insertion-order objects).
 * @returns Language-owned compact text in insertion order.
 * @note Product entry is `JsonWriter.Emit` (json.md §0.4 / §1.5); this is the shared body.
 */
pub static method(JsonEmitter) Emit(node: Json) -> string {
  var em: JsonEmitter = JsonEmitter{buf: StringBuffer.NewWithCapacity(64)};
  em.EmitJson(node);

  return em.buf.Take();
}
