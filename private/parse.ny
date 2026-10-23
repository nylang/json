/**
 * @brief JSON recursive-descent SAX parse → JsonHandler events (m_v0.19_p1).
 * @note Key/String payloads are copied into `scratch` (MemStack/MemArena as Allocator).
 * @note Empty input is a Parse error (json.md §0.4). No floats/comments/trailing commas in v1.
 * @see docs/design/stdlib/json.md §0.3–1.4
 */
part of JsonTypes;

struct JsonI64Parse {
  value: int64;
  ok: bool;
}

struct JsonU64Parse {
  value: uint64;
  ok: bool;
}

struct JsonParseCtx {
  text_data: *const int8;
  text_len: int32;
  pos: int32;
  line: int32;
  column: int32;
  scratch: Allocator;
  handler: JsonHandler;
  failed: bool;
  err_line: int32;
  err_column: int32;
  err_message: string;
  aborted: bool;
}

func json_empty_str() -> string {
  return string.ViewFrom(0 as *const int8, 0);
}

func json_copy_str(s: string) -> string {
  if s.length <= 0 {
    return json_empty_str();
  }
  var out: string = string.Alloc(s.length);
  memcpy((out.data as *mut uint8), s.data, s.length as uintptr);
  return out;
}

/**
 * @brief Copy `s` into `scratch`; return a view over the scratch bytes (not heap-owned).
 * @note Handler may observe scratch-backed strings; Document (p2) must copy into durable.
 */
func json_scratch_copy(scratch: Allocator, s: string) -> string {
  if s.length <= 0 {
    return json_empty_str();
  }
  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = scratch.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return json_empty_str();
  }
  memcpy(p, s.data as *const uint8, n);
  return string.ViewFrom(p as *const int8, s.length);
}

func json_byte_at(s: string, i: int32) -> int32 {
  if i < 0 {
    return -1;
  }
  if i >= s.length {
    return -1;
  }
  return (s[i] as int32) & 255;
}

func json_hex_digit(b: int32) -> int32 {
  if (b >= 48) && (b <= 57) {
    return b - 48;
  }
  if (b >= 65) && (b <= 70) {
    return b - 55;
  }
  if (b >= 97) && (b <= 102) {
    return b - 87;
  }
  return -1;
}

/**
 * @brief Encode Unicode scalar `cp` as UTF-8 (BMP + astral up to U+10FFFF).
 */
func json_utf8_cp(cp: int32) -> string {
  if cp < 0 {
    return json_empty_str();
  }
  if cp < 128 {
    var out: string = string.Alloc(1);
    var b0: uint8 = cp as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    return out;
  }
  if cp <= 2047 {
    var out: string = string.Alloc(2);
    var b0: uint8 = (192 + (cp / 64)) as uint8;
    var b1: uint8 = (128 + (cp - (cp / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1, (&b1) as *const uint8, 1 as uintptr);
    return out;
  }
  if cp <= 65535 {
    var out: string = string.Alloc(3);
    var b0: uint8 = (224 + (cp / 4096)) as uint8;
    let r1: int32 = cp - (cp / 4096) * 4096;
    var b1: uint8 = (128 + (r1 / 64)) as uint8;
    var b2: uint8 = (128 + (r1 - (r1 / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1, (&b1) as *const uint8, 1 as uintptr);
    let p2: *mut uint8 = (((out.data as *mut int8) as intptr) + (2 as intptr)) as *mut uint8;
    memcpy(p2, (&b2) as *const uint8, 1 as uintptr);
    return out;
  }
  if cp <= 1114111 {
    var out: string = string.Alloc(4);
    var b0: uint8 = (240 + (cp / 262144)) as uint8;
    let r1: int32 = cp - (cp / 262144) * 262144;
    var b1: uint8 = (128 + (r1 / 4096)) as uint8;
    let r2: int32 = r1 - (r1 / 4096) * 4096;
    var b2: uint8 = (128 + (r2 / 64)) as uint8;
    var b3: uint8 = (128 + (r2 - (r2 / 64) * 64)) as uint8;
    memcpy((out.data as *mut uint8), (&b0) as *const uint8, 1 as uintptr);
    let p1: *mut uint8 = (((out.data as *mut int8) as intptr) + (1 as intptr)) as *mut uint8;
    memcpy(p1, (&b1) as *const uint8, 1 as uintptr);
    let p2: *mut uint8 = (((out.data as *mut int8) as intptr) + (2 as intptr)) as *mut uint8;
    memcpy(p2, (&b2) as *const uint8, 1 as uintptr);
    let p3: *mut uint8 = (((out.data as *mut int8) as intptr) + (3 as intptr)) as *mut uint8;
    memcpy(p3, (&b3) as *const uint8, 1 as uintptr);
    return out;
  }
  return json_empty_str();
}

func json_parse_i64(s: string) -> JsonI64Parse {
  // Note: do not use uint64 literal 2^63 in `/` or comparisons — host-nyra may
  // lower those as signed int64, so `0 > (INT64_MIN/10)` rejects all negatives.
  // Overflow checks stay in the positive int64 range (INT64_MAX / 10).
  var out: JsonI64Parse = JsonI64Parse{ value: 0 as int64, ok: false };
  let n: int32 = s.length;
  if n <= 0 {
    return out;
  }
  var i: int32 = 0;
  var neg: bool = false;
  if json_byte_at(s, 0) == 45 {
    neg = true;
    i = 1;
    if n == 1 {
      return out;
    }
  }
  // Reject leading zeros (JSON): "0" / "-0" ok; "01" / "-01" not.
  if json_byte_at(s, i) == 48 {
    if (i + 1) < n {
      return out;
    }
  }
  var mag: uint64 = 0u64;
  let ten: uint64 = 10u64;
  // 9223372036854775807 / 10 — fits positive int64 (safe under signed lowering).
  let lim_div: uint64 = 922337203685477580u64;
  var any: bool = false;
  while i < n {
    let b: int32 = json_byte_at(s, i);
    if (b < 48) || (b > 57) {
      return out;
    }
    let d: uint64 = (b - 48) as uint64;
    if mag > lim_div {
      return out;
    }
    if mag == lim_div {
      // Last digit: pos allows 0..7; neg also allows 8 when this is INT64_MIN.
      if d > 7u64 {
        if !neg {
          return out;
        }
        if d != 8u64 {
          return out;
        }
        if (i + 1) < n {
          return out;
        }
        out.ok = true;
        out.value = (0 as int64) - (9223372036854775807 as int64) - (1 as int64);
        return out;
      }
    }
    mag = (mag * ten) + d;
    any = true;
    i = i + 1;
  }
  if !any {
    return out;
  }
  out.ok = true;
  if neg {
    out.value = (0 as int64) - (mag as int64);
    return out;
  }
  out.value = mag as int64;
  return out;
}

func json_parse_u64(s: string) -> JsonU64Parse {
  var out: JsonU64Parse = JsonU64Parse{value: 0u64, ok: false};
  let n: int32 = s.length;
  if n <= 0 || json_byte_at(s, 0) == 45 { return out; }
  if json_byte_at(s, 0) == 48 && n > 1 { return out; }
  let limit_div: uint64 = 1844674407370955161u64;
  var magnitude: uint64 = 0u64;
  var i: int32 = 0;
  while i < n {
    let byte: int32 = json_byte_at(s, i);
    if byte < 48 || byte > 57 { return out; }
    let digit: uint64 = (byte - 48) as uint64;
    if magnitude > limit_div || (magnitude == limit_div && digit > 5u64) { return out; }
    magnitude = magnitude * 10u64 + digit;
    i = i + 1;
  }
  out.value = magnitude;
  out.ok = true;
  return out;
}

func json_keys_has(keys: *mut Array<string>, key: string) -> bool {
  unsafe {
    let n: int32 = (*keys).Len();
    var i: int32 = 0;
    while i < n {
      let sp: *mut string = &mut (*keys).buf[i];
      if (*sp) == key {
        return true;
      }
      i = i + 1;
    }
    return false;
  }
}

method(JsonParseCtx) Src() -> string {
  return string.ViewFrom(self.text_data, self.text_len);
}

method(JsonParseCtx) FailAt(line: int32, column: int32, message: string) -> void {
  if self.failed {
    return;
  }
  self.failed = true;
  self.err_line = line;
  self.err_column = column;
  self.err_message = json_copy_str(message);
}

method(JsonParseCtx) FailHere(message: string) -> void {
  self.FailAt(self.line, self.column, message);
}

method(JsonParseCtx) Peek() -> int32 {
  if self.pos >= self.text_len {
    return -1;
  }
  return json_byte_at(self.Src(), self.pos);
}

method(JsonParseCtx) Advance() -> void {
  if self.pos >= self.text_len {
    return;
  }
  let b: int32 = json_byte_at(self.Src(), self.pos);
  self.pos = self.pos + 1;
  if b == 10 {
    self.line = self.line + 1;
    self.column = 1;
  } else {
    self.column = self.column + 1;
  }
}

method(JsonParseCtx) SkipWs() -> void {
  while true {
    let b: int32 = self.Peek();
    if b < 0 {
      return;
    }
    if (b != 32) && (b != 9) && (b != 10) && (b != 13) {
      return;
    }
    self.Advance();
  }
}

method(JsonParseCtx) MatchLit(lit: string) -> bool {
  let s: string = self.Src();
  let n: int32 = lit.length;
  if self.pos + n > self.text_len {
    return false;
  }
  var i: int32 = 0;
  while i < n {
    if json_byte_at(s, self.pos + i) != json_byte_at(lit, i) {
      return false;
    }
    i = i + 1;
  }
  var k: int32 = 0;
  while k < n {
    self.Advance();
    k = k + 1;
  }
  return true;
}

method(JsonParseCtx) PublishString(heap_s: string) -> bool {
  let view: string = json_scratch_copy(self.scratch, heap_s);
  if (heap_s.length > 0) && (view.length <= 0) {
    self.FailHere("scratch allocator exhausted");
    return false;
  }
  if !self.handler.String(view) {
    self.aborted = true;
    self.FailHere("handler aborted");
    return false;
  }
  return true;
}

method(JsonParseCtx) PublishKey(heap_s: string) -> bool {
  let view: string = json_scratch_copy(self.scratch, heap_s);
  if (heap_s.length > 0) && (view.length <= 0) {
    self.FailHere("scratch allocator exhausted");
    return false;
  }
  if !self.handler.Key(view) {
    self.aborted = true;
    self.FailHere("handler aborted");
    return false;
  }
  return true;
}

method(JsonParseCtx) ReadUXXXX() -> int32 {
  var cp: int32 = 0;
  var h: int32 = 0;
  while h < 4 {
    let b: int32 = self.Peek();
    let hv: int32 = json_hex_digit(b);
    if hv < 0 {
      self.FailHere("invalid Unicode escape in string");
      return -1;
    }
    cp = (cp * 16) + hv;
    self.Advance();
    h = h + 1;
  }
  return cp;
}

method(JsonParseCtx) ParseStringRaw() -> string {
  if self.Peek() != 34 {
    self.FailHere("expected string");
    return json_empty_str();
  }
  self.Advance();
  var buf: StringBuffer = StringBuffer.NewWithCapacity(16);
  while true {
    let b: int32 = self.Peek();
    if b < 0 {
      buf.Destroy();
      self.FailHere("unterminated string");
      return json_empty_str();
    }
    if b == 34 {
      self.Advance();
      return buf.Take();
    }
    if b < 32 {
      buf.Destroy();
      self.FailHere("unescaped control character in string");
      return json_empty_str();
    }
    if b == 92 {
      self.Advance();
      let e: int32 = self.Peek();
      if e < 0 {
        buf.Destroy();
        self.FailHere("invalid escape in string");
        return json_empty_str();
      }
      self.Advance();
      if e == 34 {
        buf.Append("\"");
        continue;
      }
      if e == 92 {
        buf.Append("\\");
        continue;
      }
      if e == 47 {
        buf.Append("/");
        continue;
      }
      if e == 98 {
        buf.Append(json_utf8_cp(8));
        continue;
      }
      if e == 102 {
        buf.Append(json_utf8_cp(12));
        continue;
      }
      if e == 110 {
        buf.Append("\n");
        continue;
      }
      if e == 114 {
        buf.Append("\r");
        continue;
      }
      if e == 116 {
        buf.Append("\t");
        continue;
      }
      if e == 117 {
        let cu: int32 = self.ReadUXXXX();
        if self.failed {
          buf.Destroy();
          return json_empty_str();
        }
        // Surrogate pair: high + \u low → astral scalar.
        if (cu >= 55296) && (cu <= 56319) {
          if self.Peek() == 92 {
            self.Advance();
            if self.Peek() == 117 {
              self.Advance();
              let lo: int32 = self.ReadUXXXX();
              if self.failed {
                buf.Destroy();
                return json_empty_str();
              }
              if (lo >= 56320) && (lo <= 57343) {
                let hi: int32 = cu - 55296;
                let low: int32 = lo - 56320;
                let cp: int32 = 65536 + (hi * 1024) + low;
                buf.Append(json_utf8_cp(cp));
                continue;
              }
              buf.Destroy();
              self.FailHere("invalid Unicode surrogate pair in string");
              return json_empty_str();
            }
            buf.Destroy();
            self.FailHere("invalid Unicode surrogate pair in string");
            return json_empty_str();
          }
          buf.Destroy();
          self.FailHere("invalid Unicode surrogate pair in string");
          return json_empty_str();
        }
        if (cu >= 56320) && (cu <= 57343) {
          buf.Destroy();
          self.FailHere("invalid Unicode surrogate pair in string");
          return json_empty_str();
        }
        buf.Append(json_utf8_cp(cu));
        continue;
      }
      buf.Destroy();
      self.FailHere("invalid escape in string");
      return json_empty_str();
    }
    let s: string = self.Src();
    var nch: int32 = s.Utf8LenAt(self.pos);
    if nch < 1 {
      nch = 1;
    }
    buf.Append(s.View(self.pos, nch));
    var k: int32 = 0;
    while k < nch {
      self.Advance();
      k = k + 1;
    }
  }
}

method(JsonParseCtx) ParseNumber() -> bool {
  let start: int32 = self.pos;
  let start_line: int32 = self.line;
  let start_col: int32 = self.column;
  if self.Peek() == 45 {
    self.Advance();
  }
  let first: int32 = self.Peek();
  if (first < 48) || (first > 57) {
    self.FailAt(start_line, start_col, "invalid number");
    return false;
  }
  if first == 48 {
    self.Advance();
  } else {
    while true {
      let d: int32 = self.Peek();
      if (d < 48) || (d > 57) {
        break;
      }
      self.Advance();
    }
  }
  let after: int32 = self.Peek();
  if (after == 46) || (after == 101) || (after == 69) {
    self.FailAt(start_line, start_col, "floating-point numbers are not supported");
    return false;
  }
  if after == 43 {
    self.FailAt(start_line, start_col, "invalid number");
    return false;
  }
  let lex: string = self.Src().Slice(start, self.pos);
  let parsed: JsonI64Parse = json_parse_i64(lex);
  if parsed.ok {
    if !self.handler.Int64(parsed.value) {
      self.aborted = true;
      self.FailAt(start_line, start_col, "handler aborted");
      return false;
    }
    return true;
  }
  let unsigned: JsonU64Parse = json_parse_u64(lex);
  if !unsigned.ok {
    self.FailAt(start_line, start_col, "integer overflow");
    return false;
  }
  if !self.handler.UInt64(unsigned.value) {
    self.aborted = true;
    self.FailAt(start_line, start_col, "handler aborted");
    return false;
  }
  return true;
}

method(JsonParseCtx) ParseObject() -> bool {
  if self.Peek() != 123 {
    self.FailHere("expected object");
    return false;
  }
  self.Advance();
  if !self.handler.StartObject() {
    self.aborted = true;
    self.FailHere("handler aborted");
    return false;
  }
  self.SkipWs();
  if self.Peek() == 125 {
    self.Advance();
    if !self.handler.EndObject(0) {
      self.aborted = true;
      self.FailHere("handler aborted");
      return false;
    }
    return true;
  }
  var keys: Array<string> = Array<string>{};
  var count: int32 = 0;
  while true {
    self.SkipWs();
    if self.Peek() != 34 {
      self.FailHere("expected object key string");
      return false;
    }
    let key_line: int32 = self.line;
    let key_col: int32 = self.column;
    let key_heap: string = self.ParseStringRaw();
    if self.failed {
      return false;
    }
    let kp: *mut Array<string> = cast<Array<string>>.pointer(&mut keys);
    if json_keys_has(kp, key_heap) {
      self.FailAt(key_line, key_col, "duplicate object key");
      return false;
    }
    keys.Push(copy(key_heap));
    if !self.PublishKey(key_heap) {
      return false;
    }
    self.SkipWs();
    if self.Peek() != 58 {
      self.FailHere("expected ':' after object key");
      return false;
    }
    self.Advance();
    self.SkipWs();
    if !self.ParseValue() {
      return false;
    }
    count = count + 1;
    self.SkipWs();
    let sep: int32 = self.Peek();
    if sep == 125 {
      self.Advance();
      if !self.handler.EndObject(count) {
        self.aborted = true;
        self.FailHere("handler aborted");
        return false;
      }
      return true;
    }
    if sep != 44 {
      self.FailHere("expected ',' or '}' in object");
      return false;
    }
    self.Advance();
    self.SkipWs();
    if self.Peek() == 125 {
      self.FailHere("trailing comma in object");
      return false;
    }
  }
}

method(JsonParseCtx) ParseArray() -> bool {
  if self.Peek() != 91 {
    self.FailHere("expected array");
    return false;
  }
  self.Advance();
  if !self.handler.StartArray() {
    self.aborted = true;
    self.FailHere("handler aborted");
    return false;
  }
  self.SkipWs();
  if self.Peek() == 93 {
    self.Advance();
    if !self.handler.EndArray(0) {
      self.aborted = true;
      self.FailHere("handler aborted");
      return false;
    }
    return true;
  }
  var count: int32 = 0;
  while true {
    self.SkipWs();
    if !self.ParseValue() {
      return false;
    }
    count = count + 1;
    self.SkipWs();
    let sep: int32 = self.Peek();
    if sep == 93 {
      self.Advance();
      if !self.handler.EndArray(count) {
        self.aborted = true;
        self.FailHere("handler aborted");
        return false;
      }
      return true;
    }
    if sep != 44 {
      self.FailHere("expected ',' or ']' in array");
      return false;
    }
    self.Advance();
    self.SkipWs();
    if self.Peek() == 93 {
      self.FailHere("trailing comma in array");
      return false;
    }
  }
}

method(JsonParseCtx) ParseValue() -> bool {
  self.SkipWs();
  let b: int32 = self.Peek();
  if b < 0 {
    self.FailHere("unexpected end of input");
    return false;
  }
  if b == 110 {
    if !self.MatchLit("null") {
      self.FailHere("expected null");
      return false;
    }
    if !self.handler.Null() {
      self.aborted = true;
      self.FailHere("handler aborted");
      return false;
    }
    return true;
  }
  if b == 116 {
    if !self.MatchLit("true") {
      self.FailHere("expected true");
      return false;
    }
    if !self.handler.Bool(true) {
      self.aborted = true;
      self.FailHere("handler aborted");
      return false;
    }
    return true;
  }
  if b == 102 {
    if !self.MatchLit("false") {
      self.FailHere("expected false");
      return false;
    }
    if !self.handler.Bool(false) {
      self.aborted = true;
      self.FailHere("handler aborted");
      return false;
    }
    return true;
  }
  if b == 34 {
    let s: string = self.ParseStringRaw();
    if self.failed {
      return false;
    }
    return self.PublishString(s);
  }
  if b == 123 {
    return self.ParseObject();
  }
  if b == 91 {
    return self.ParseArray();
  }
  if (b == 45) || ((b >= 48) && (b <= 57)) {
    return self.ParseNumber();
  }
  self.FailHere("expected value");
  return false;
}

/**
 * @brief Drive `handler` for one JSON value in `text`; Key/String temps on `scratch`.
 */
func json_sax_parse(text: string, handler: JsonHandler, scratch: Allocator) -> Result<Unit, JsonError> {
  // Touch scratch up front so MemStack/MemArena wiring is exercised even for tiny inputs.
  let frame: *mut uint8 = scratch.Alloc(1 as uintptr);
  if frame == (ptr<uint8>.null()) {
    let err: JsonError = JsonError{ line: 1, column: 1, message: json_copy_str("scratch allocator exhausted") };
    let r: Result<Unit, JsonError> = err;
    return r;
  }

  var ctx: JsonParseCtx = JsonParseCtx{
    text_data: text.data,
    text_len: text.length,
    pos: 0,
    line: 1,
    column: 1,
    scratch: scratch,
    handler: handler,
    failed: false,
    err_line: 1,
    err_column: 1,
    err_message: json_empty_str(),
    aborted: false
  };

  ctx.SkipWs();
  if ctx.Peek() < 0 {
    let err: JsonError = JsonError{ line: 1, column: 1, message: json_copy_str("empty input") };
    let r: Result<Unit, JsonError> = err;
    return r;
  }
  if !ctx.ParseValue() {
    let err: JsonError = JsonError{
      line: ctx.err_line,
      column: ctx.err_column,
      message: json_copy_str(ctx.err_message)
    };
    let r: Result<Unit, JsonError> = err;
    return r;
  }
  ctx.SkipWs();
  if ctx.Peek() >= 0 {
    let err: JsonError = JsonError{
      line: ctx.line,
      column: ctx.column,
      message: json_copy_str("trailing junk after value")
    };
    let r: Result<Unit, JsonError> = err;
    return r;
  }
  let ok: Result<Unit, JsonError> = UnitValue();
  return ok;
}
