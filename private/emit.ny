/**
 * @brief Compact JSON emit (json.md §1.5).
 * @note Same TU as `Json` layouts so `holds` / `get_if` on `Json.node` resolve.
 * @note Product entry is `JsonWriter.Emit`; this is the shared body used by `GetString`.
 */
part of JsonTypes;

struct JsonEmitter {
  buf: StringBuffer;
}

func json_hex_char(n: int32) -> string {
  var d: int32 = n;
  if d < 0 {
    d = 0;
  }
  if d > 15 {
    d = 15;
  }
  if d < 10 {
    return json_utf8_cp(48 + d);
  }
  return json_utf8_cp(87 + d);
}

func json_u00(b: int32) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(6);
  buf.Append("\\u00");
  buf.Append(json_hex_char((b / 16) & 15));
  buf.Append(json_hex_char(b & 15));
  return buf.Take();
}

/**
 * @brief Quote `s` as a JSON string (escapes `\\` `\"` + short forms / `\u00XX`).
 * @note Peer of `face_json_quote` / `yaml_emit_quote` escape subset (json.md §1.5).
 */
func json_emit_quote(s: string) -> string {
  var buf: StringBuffer = StringBuffer.NewWithCapacity(s.length + 2);
  buf.Append("\"");
  var i: int32 = 0;
  let n: int32 = s.length;
  while i < n {
    let b: int32 = json_byte_at(s, i);
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
      buf.Append(json_u00(b));
      i = i + 1;
      continue;
    }
    var nch: int32 = s.Utf8LenAt(i);
    if nch < 1 {
      nch = 1;
    }
    buf.Append(s.View(i, nch));
    i = i + nch;
  }
  buf.Append("\"");
  return buf.Take();
}

func json_i64_text(v: int64) -> string {
  if v == (0 as int64) {
    return "0";
  }
  let min64: int64 = (0 as int64) - (9223372036854775807 as int64) - (1 as int64);
  if v == min64 {
    return "-9223372036854775808";
  }
  var neg: bool = v < (0 as int64);
  var mag: uint64 = v as uint64;
  if neg {
    mag = ((0 as int64) - v) as uint64;
  }
  var tmp: uint64 = mag;
  var nd: int32 = 0;
  let ten: uint64 = 10u64;
  while tmp > 0u64 {
    tmp = tmp / ten;
    nd = nd + 1;
  }
  var cap: int32 = nd;
  if neg {
    cap = nd + 1;
  }
  var out: string = string.Alloc(cap);
  var p: *mut uint8 = (out.data as *mut uint8);
  var pos: int32 = cap - 1;
  tmp = mag;
  while tmp > 0u64 {
    let d: uint64 = tmp - (tmp / ten) * ten;
    var ch: uint8 = ((d as int32) + 48) as uint8;
    let dest: *mut uint8 = ((p as intptr) + (pos as intptr)) as *mut uint8;
    memcpy(dest, (&ch) as *const uint8, 1 as uintptr);
    pos = pos - 1;
    tmp = tmp / ten;
  }
  if neg {
    var minus: uint8 = 45 as uint8;
    memcpy(p, (&minus) as *const uint8, 1 as uintptr);
  }
  return out;
}

func json_u64_text(v: uint64) -> string {
  if v == 0u64 { return "0"; }
  var count: int32 = 0;
  var scan: uint64 = v;
  while scan > 0u64 { scan = scan / 10u64; count = count + 1; }
  var out: string = string.Alloc(count);
  let bytes: *mut uint8 = out.data as *mut uint8;
  var pos: int32 = count - 1;
  scan = v;
  while scan > 0u64 {
    let digit: uint64 = scan - (scan / 10u64) * 10u64;
    var ch: uint8 = ((digit as int32) + 48) as uint8;
    let dest: *mut uint8 = ((bytes as intptr) + (pos as intptr)) as *mut uint8;
    memcpy(dest, (&ch) as *const uint8, 1 as uintptr);
    scan = scan / 10u64;
    pos = pos - 1;
  }
  return out;
}

func json_trees_equal(a: Json, b: Json) -> bool {
  if a.node.holds<JsonNull>() {
    return b.node.holds<JsonNull>();
  }
  if a.node.holds<JsonBool>() {
    if !b.node.holds<JsonBool>() {
      return false;
    }
    let ab: JsonBool? = a.node.get_if<JsonBool>();
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
  if a.node.holds<JsonInt>() {
    if !b.node.holds<JsonInt>() {
      return false;
    }
    let ai: JsonInt? = a.node.get_if<JsonInt>();
    let bi: JsonInt? = b.node.get_if<JsonInt>();
    if ai == nil {
      return false;
    }
    if bi == nil {
      return false;
    }
    let aiv: JsonInt = ai as JsonInt;
    let biv: JsonInt = bi as JsonInt;
    if aiv.is_unsigned != biv.is_unsigned { return false; }
    if aiv.is_unsigned { return aiv.unsigned_value == biv.unsigned_value; }
    return aiv.value == biv.value;
  }
  if a.node.holds<JsonStr>() {
    if !b.node.holds<JsonStr>() {
      return false;
    }
    let asv: JsonStr? = a.node.get_if<JsonStr>();
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
  if a.node.holds<JsonArray>() {
    if !b.node.holds<JsonArray>() {
      return false;
    }
    let aarr: JsonArray? = a.node.get_if<JsonArray>();
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
        if !json_trees_equal((*pa), (*pb)) {
          return false;
        }
      }
      i = i + 1;
    }
    return true;
  }
  if a.node.holds<JsonObject>() {
    if !b.node.holds<JsonObject>() {
      return false;
    }
    let am: JsonObject? = a.node.get_if<JsonObject>();
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
        if !json_trees_equal((*ea).value, (*eb).value) {
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
      self.buf.Append(json_emit_quote((*ep).key));
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
      if n.is_unsigned { self.buf.Append(json_u64_text(n.unsigned_value)); }
      else { self.buf.Append(json_i64_text(n.value)); }
    }
    return;
  }
  if node.node.holds<JsonStr>() {
    let sv: JsonStr? = node.node.get_if<JsonStr>();
    if sv != nil {
      let s: JsonStr = sv as JsonStr;
      self.buf.Append(json_emit_quote(copy(s.value)));
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
 * @note Product entry is `JsonWriter.Emit` (json.md §0.4 / §1.5); this is the shared body.
 */
func json_emit_text(node: Json) -> string {
  var em: JsonEmitter = JsonEmitter{ buf: StringBuffer.NewWithCapacity(64) };
  em.EmitJson(node);
  return em.buf.Take();
}

pub func JsonTreesEqual(a: Json, b: Json) -> bool {
  return json_trees_equal(a, b);
}
