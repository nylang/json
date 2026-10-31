// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of JsonReaderEngine;

/**
 * @brief JSON recursive-descent SAX parse → JsonHandler events (m_v0.19_p1).
 * @note Key/String payloads are copied into `scratch` (MemStack/MemArena as Allocator).
 * @note Empty input is a Parse error (json.md §0.4). Comments and trailing commas are rejected.
 * @see docs/design/stdlib/json.md §0.3–1.4
 */

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

static method(JsonParseCtx) HexDigit(b: int32) -> int32 {
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

// Accumulate magnitude with overflow checks so the signed minimum is accepted without overflowing an intermediate.
static method(JsonI64Parse) Parse(s: string) -> JsonI64Parse {
  // Note: do not use uint64 literal 2^63 in `/` or comparisons — host-nyra may
  // lower those as signed int64, so `0 > (INT64_MIN/10)` rejects all negatives.
  // Overflow checks stay in the positive int64 range (INT64_MAX / 10).
  var out: JsonI64Parse = JsonI64Parse{value: 0i64, ok: false};
  let n: int32 = s.length;
  if n <= 0 {
    return out;
  }

  var i: int32 = 0;
  var neg: bool = false;
  if s.ByteAt(0) == 45 {
    neg = true;
    i = 1;
    if n == 1 {
      return out;
    }
  }

  // Reject leading zeros (JSON): "0" / "-0" ok; "01" / "-01" not.
  if s.ByteAt(i) == 48 {
    if (i + 1) < n {
      return out;
    }
  }

  var mag: uint64 = 0;
  let ten: uint64 = 10;
  // 9223372036854775807 / 10 — fits positive int64 (safe under signed lowering).
  let lim_div: uint64 = 922337203685477580u64;
  var any: bool = false;
  while i < n {
    let b: int32 = s.ByteAt(i);
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
        out.value = kInt64Min;

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
    out.value = (0i64) - (mag as int64);

    return out;
  }

  out.value = mag as int64;

  return out;
}

// Check each digit before multiplication; an out-of-range integer must retain its exact numeric spelling elsewhere.
static method(JsonU64Parse) Parse(s: string) -> JsonU64Parse {
  var out: JsonU64Parse = JsonU64Parse{value: 0u64, ok: false};
  let n: int32 = s.length;
  if n <= 0 || s.ByteAt(0) == 45 {
    return out;
  }

  if s.ByteAt(0) == 48 && n > 1 {
    return out;
  }

  let limit_div: uint64 = 1844674407370955161u64;
  var magnitude: uint64 = 0;
  var i: int32 = 0;
  while i < n {
    let byte: int32 = s.ByteAt(i);
    if byte < 48 || byte > 57 {
      return out;
    }

    let digit: uint64 = (byte - 48) as uint64;
    if magnitude > limit_div || (magnitude == limit_div && digit > 5u64) {
      return out;
    }

    magnitude = magnitude * 10u64 + digit;
    i = i + 1;
  }

  out.value = magnitude;
  out.ok = true;

  return out;
}

static method(JsonParseCtx) HasKey(keys: *mut Array<string>, key: string) -> bool {
  unsafe {
    let n: int32 = (*keys).Len();
    var i: int32 = 0;
    while i < n {
      let sp: *mut string = &mut(*keys).buf[i];
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
  self.err_message = copy(message);
}

method(JsonParseCtx) FailHere(message: string) -> void {
  self.FailAt(self.line, self.column, message);
}

method(JsonParseCtx) Peek() -> int32 {
  if self.pos >= self.text_len {
    return -1;
  }

  return (self.Src()).ByteAt(self.pos);
}

method(JsonParseCtx) Advance() -> void {
  if self.pos >= self.text_len {
    return;
  }

  let b: int32 = (self.Src()).ByteAt(self.pos);
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
    if s.ByteAt(self.pos + i) != lit.ByteAt(i) {
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
  let copied_view: string? = (self.scratch).CopyStringView(heap_s);
  let view: string = copied_view != nil ? copied_view as string : "";
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
  let copied_view: string? = (self.scratch).CopyStringView(heap_s);
  let view: string = copied_view != nil ? copied_view as string : "";
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
    let hv: int32 = JsonParseCtx.HexDigit(b);
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

    return "";
  }

  self.Advance();
  var buf: StringBuffer = StringBuffer.NewWithCapacity(16);
  while true {
    let b: int32 = self.Peek();
    if b < 0 {
      buf.Destroy();
      self.FailHere("unterminated string");

      return "";
    }

    if b == 34 {
      self.Advance();

      return buf.Take();
    }

    if b < 32 {
      buf.Destroy();
      self.FailHere("unescaped control character in string");

      return "";
    }

    if b == 92 {
      self.Advance();
      let e: int32 = self.Peek();
      if e < 0 {
        buf.Destroy();
        self.FailHere("invalid escape in string");

        return "";
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
        buf.Append(string.Utf8Encode(8));
        continue;
      }

      if e == 102 {
        buf.Append(string.Utf8Encode(12));
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

          return "";
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

                return "";
              }

              if (lo >= 56320) && (lo <= 57343) {
                let hi: int32 = cu - 55296;
                let low: int32 = lo - 56320;
                let cp: int32 = 65536 + (hi * 1024) + low;
                buf.Append(string.Utf8Encode(cp));
                continue;
              }

              buf.Destroy();
              self.FailHere("invalid Unicode surrogate pair in string");

              return "";
            }

            buf.Destroy();
            self.FailHere("invalid Unicode surrogate pair in string");

            return "";
          }

          buf.Destroy();
          self.FailHere("invalid Unicode surrogate pair in string");

          return "";
        }

        if (cu >= 56320) && (cu <= 57343) {
          buf.Destroy();
          self.FailHere("invalid Unicode surrogate pair in string");

          return "";
        }

        buf.Append(string.Utf8Encode(cu));
        continue;
      }

      buf.Destroy();
      self.FailHere("invalid escape in string");

      return "";
    }

    let s: string = self.Src();
    let decoded: UtfDecodeResult = Text.DecodeUtf8(s, self.pos);
    if !decoded.valid {
      buf.Destroy();
      self.FailHere("invalid UTF-8 in JSON string");

      return "";
    }

    let nch: int32 = decoded.byte_len;
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
    let following: int32 = self.Peek();
    if (following >= 48) && (following <= 57) {
      self.FailAt(start_line, start_col, "leading zero in number");

      return false;
    }
  } else {
    while true {
      let d: int32 = self.Peek();
      if (d < 48) || (d > 57) {
        break;
      }

      self.Advance();
    }
  }

  var is_decimal: bool = false;
  if self.Peek() == 46 {
    is_decimal = true;
    self.Advance();
    let fraction_start: int32 = self.pos;
    while true {
      let d: int32 = self.Peek();
      if (d < 48) || (d > 57) {
        break;
      }

      self.Advance();
    }

    if self.pos == fraction_start {
      self.FailAt(start_line, start_col, "fraction requires a digit");

      return false;
    }
  }

  let exponent: int32 = self.Peek();
  if (exponent == 101) || (exponent == 69) {
    is_decimal = true;
    self.Advance();
    if (self.Peek() == 43) || (self.Peek() == 45) {
      self.Advance();
    }

    let exponent_start: int32 = self.pos;
    while true {
      let d: int32 = self.Peek();
      if (d < 48) || (d > 57) {
        break;
      }

      self.Advance();
    }

    if self.pos == exponent_start {
      self.FailAt(start_line, start_col, "exponent requires a digit");

      return false;
    }
  }

  let lex: string = self.Src().Slice(start, self.pos);
  if is_decimal {
    let copied_raw: string? = (self.scratch).CopyStringView(lex);
    let raw: string = copied_raw != nil ? copied_raw as string : "";
    if raw.length != lex.length {
      self.FailAt(start_line, start_col, "scratch allocator exhausted");

      return false;
    }

    if !self.handler.Number(raw) {
      self.aborted = true;
      self.FailAt(start_line, start_col, "handler aborted");

      return false;
    }

    return true;
  }

  let parsed: JsonI64Parse = JsonI64Parse.Parse(lex);
  if parsed.ok {
    if !self.handler.Int64(parsed.value) {
      self.aborted = true;
      self.FailAt(start_line, start_col, "handler aborted");

      return false;
    }

    return true;
  }

  let unsigned: JsonU64Parse = JsonU64Parse.Parse(lex);
  if !unsigned.ok {
    let copied_raw: string? = (self.scratch).CopyStringView(lex);
    let raw: string = copied_raw != nil ? copied_raw as string : "";
    if raw.length != lex.length {
      self.FailAt(start_line, start_col, "scratch allocator exhausted");

      return false;
    }

    if !self.handler.Number(raw) {
      self.aborted = true;
      self.FailAt(start_line, start_col, "handler aborted");

      return false;
    }

    return true;
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
    if JsonParseCtx.HasKey(kp, key_heap) {
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
static method(JsonParseCtx) Parse(text: string, handler: JsonHandler, scratch: Allocator) -> Result<Unit, JsonError> {
  // Touch scratch up front so MemStack/MemArena wiring is exercised even for tiny inputs.
  let frame: *mut uint8 = scratch.Alloc(1up);
  if frame == (ptr<uint8>.null()) {
    let err: JsonError = JsonError{line: 1, column: 1, message: copy("scratch allocator exhausted")};
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
    err_message: "",
    aborted: false
  };

  ctx.SkipWs();
  if ctx.Peek() < 0 {
    let err: JsonError = JsonError{line: 1, column: 1, message: copy("empty input")};
    let r: Result<Unit, JsonError> = err;

    return r;
  }

  if !ctx.ParseValue() {
    let err: JsonError = JsonError{
      line: ctx.err_line,
      column: ctx.err_column,
      message: copy(ctx.err_message)
    };
    let r: Result<Unit, JsonError> = err;

    return r;
  }

  ctx.SkipWs();
  if ctx.Peek() >= 0 {
    let err: JsonError = JsonError{
      line: ctx.line,
      column: ctx.column,
      message: copy("trailing junk after value")
    };
    let r: Result<Unit, JsonError> = err;

    return r;
  }

  let ok: Result<Unit, JsonError> = UnitValue();

  return ok;
}
