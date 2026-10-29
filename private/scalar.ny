// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Exact JSON number syntax, UTF-8 byte access and allocator-bound string copies. */
module JsonScalar;
import "stdlib:stdlib.ny";

/**
 * @brief Provide an empty JSON string value without allocating payload storage.
 * @returns An empty borrowed string value.
 */
pub func JsonEmptyStr() -> string {
  return string.ViewFrom(0 as *const int8, 0);
}

/**
 * @brief Copy JSON text out of the source buffer into language-owned storage.
 * @returns An owned copy, or an empty value for empty input.
 */
pub func JsonCopyStr(s: string) -> string {
  if s.length <= 0 {
    return JsonEmptyStr();
  }

  var out: string = string.Alloc(s.length);
  memcpy((out.data as *mut uint8), s.data, s.length as uintptr);

  return out;
}

/**
 * @brief Copy `s` into `scratch`; return a view over the scratch bytes (not heap-owned).
 * @note Handler may observe scratch-backed strings; Document (p2) must copy into durable.
 */
pub func JsonScratchCopy(scratch: Allocator, s: string) -> string {
  if s.length <= 0 {
    return JsonEmptyStr();
  }

  let n: uintptr = s.length as uintptr;
  let p: *mut uint8 = scratch.Alloc(n);
  if p == (ptr<uint8>.null()) {
    return JsonEmptyStr();
  }

  memcpy(p, s.data as *const uint8, n);

  return string.ViewFrom(p as *const int8, s.length);
}

/**
 * @brief Read a JSON source byte without crossing its bounds.
 * @returns The byte widened to int32, or -1 outside the source range.
 */
pub func JsonByteAt(s: string, i: int32) -> int32 {
  if i < 0 {
    return -1;
  }

  if i >= s.length {
    return -1;
  }

  return (s[i] as int32) & 255;
}

/**
 * @brief Encode Unicode scalar `cp` as UTF-8 (BMP + astral up to U+10FFFF).
 */
pub func JsonUtf8Cp(cp: int32) -> string {
  let encoded: string? = Text.EncodeUtf8(cp);
  if encoded == nil {
    return JsonEmptyStr();
  }

  return encoded as string;
}

/** @brief Validate the RFC 8259 number grammar without converting or rounding the value. */
pub func JsonNumberIsValid(s: string) -> bool {
  let n: int32 = s.length;
  if n <= 0 {
    return false;
  }

  var i: int32 = 0;
  if JsonByteAt(s, i) == 45 {
    i = i + 1;
  }

  if i >= n {
    return false;
  }

  let first: int32 = JsonByteAt(s, i);
  if first == 48 {
    i = i + 1;
    if i < n {
      let next: int32 = JsonByteAt(s, i);
      if (next >= 48) && (next <= 57) {
        return false;
      }
    }
  } else {
    if (first < 49) || (first > 57) {
      return false;
    }

    i = i + 1;
    while i < n {
      let b: int32 = JsonByteAt(s, i);
      if (b < 48) || (b > 57) {
        break;
      }

      i = i + 1;
    }
  }

  if i < n && JsonByteAt(s, i) == 46 {
    i = i + 1;
    let fraction_start: int32 = i;
    while i < n {
      let b: int32 = JsonByteAt(s, i);
      if (b < 48) || (b > 57) {
        break;
      }

      i = i + 1;
    }

    if i == fraction_start {
      return false;
    }
  }

  if i < n && ((JsonByteAt(s, i) == 101) || (JsonByteAt(s, i) == 69)) {
    i = i + 1;
    if i < n && ((JsonByteAt(s, i) == 43) || (JsonByteAt(s, i) == 45)) {
      i = i + 1;
    }

    let exponent_start: int32 = i;
    while i < n {
      let b: int32 = JsonByteAt(s, i);
      if (b < 48) || (b > 57) {
        break;
      }

      i = i + 1;
    }

    if i == exponent_start {
      return false;
    }
  }

  return i == n;
}
/**
 * @brief Format a signed JSON integer without locale or floating-point conversion.
 * @returns Exact base-10 text, including the minimum signed value.
 */
pub func JsonI64Text(v: int64) -> string {
  if v == (0 as int64) {
    return "0";
  }

  let min64: int64 = (0 as int64) - (9223372036854775807 as int64) - (1 as int64);
  if v == min64 {
    return "-9223372036854775808";
  }

  var neg: bool = v <(0 as int64);
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
    memcpy(dest,(&ch) as *const uint8, 1 as uintptr);
    pos = pos - 1;
    tmp = tmp / ten;
  }

  if neg {
    var minus: uint8 = 45 as uint8;
    memcpy(p,(&minus) as *const uint8, 1 as uintptr);
  }

  return out;
}

/**
 * @brief Format an unsigned JSON integer without rounding.
 * @returns Exact base-10 text for the full uint64 range.
 */
pub func JsonU64Text(v: uint64) -> string {
  if v == 0u64 {
    return "0";
  }

  var count: int32 = 0;
  var scan: uint64 = v;
  while scan > 0u64 {
    scan = scan / 10u64;
    count = count + 1;
  }

  var out: string = string.Alloc(count);
  let bytes: *mut uint8 = out.data as *mut uint8;
  var pos: int32 = count - 1;
  scan = v;
  while scan > 0u64 {
    let digit: uint64 = scan - (scan / 10u64) * 10u64;
    var ch: uint8 = ((digit as int32) + 48) as uint8;
    let dest: *mut uint8 = ((bytes as intptr) + (pos as intptr)) as *mut uint8;
    memcpy(dest,(&ch) as *const uint8, 1 as uintptr);
    scan = scan / 10u64;
    pos = pos - 1;
  }

  return out;
}
