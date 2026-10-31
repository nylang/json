// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

/** @brief Exact JSON number validation and lossless integer serialization. */
module JsonScalar;
import "stdlib:stdlib.ny";
import "interface/json.ni";

/** @brief Validate the RFC 8259 number grammar without converting or rounding the value.
 * @returns True only for a complete valid number lexeme. */
pub static method(JsonNumber) IsValid(s: string) -> bool {
  let n: int32 = s.length;
  if n <= 0 {
    return false;
  }

  var i: int32 = 0;
  if s.ByteAt(i) == 45 {
    i = i + 1;
  }

  if i >= n {
    return false;
  }

  let first: int32 = s.ByteAt(i);
  if first == 48 {
    i = i + 1;
    if i < n {
      let next: int32 = s.ByteAt(i);
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
      let b: int32 = s.ByteAt(i);
      if (b < 48) || (b > 57) {
        break;
      }

      i = i + 1;
    }
  }

  if i < n && s.ByteAt(i) == 46 {
    i = i + 1;
    let fraction_start: int32 = i;
    while i < n {
      let b: int32 = s.ByteAt(i);
      if (b < 48) || (b > 57) {
        break;
      }

      i = i + 1;
    }

    if i == fraction_start {
      return false;
    }
  }

  if i < n && ((s.ByteAt(i) == 101) || (s.ByteAt(i) == 69)) {
    i = i + 1;
    if i < n && ((s.ByteAt(i) == 43) || (s.ByteAt(i) == 45)) {
      i = i + 1;
    }

    let exponent_start: int32 = i;
    while i < n {
      let b: int32 = s.ByteAt(i);
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
