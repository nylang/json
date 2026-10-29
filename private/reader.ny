// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

module JsonReaderEngine;
part "parse.ny";
import "stdlib:stdlib.ny";
import "interface/json.ni";
import "private/scalar.ny";

/**
 * @brief JsonReader + Handler event publish (m_v0.19_p1).
 * @note Parse path: recursive-descent SAX → RapidJSON-order events; Key/String on scratch.
 * @see docs/design/stdlib/json.md §0.3–0.6
 */

func json_reader_ok() -> Result<Unit, JsonError> {
  let r: Result<Unit, JsonError> = UnitValue();

  return r;
}

func json_reader_fail(line: int32, column: int32, message: string) -> Result<Unit, JsonError> {
  var msg: string = message;
  if message.length > 0 {
    var out: string = string.Alloc(message.length);
    memcpy((out.data as *mut uint8), message.data, message.length as uintptr);
    msg = out;
  }

  let err: JsonError = JsonError{line: line, column: column, message: msg};
  let r: Result<Unit, JsonError> = err;

  return r;
}

func json_reader_io_kind(e: IoError) -> string {
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
 * @brief Construct a Reader (stateless; scratch is per-Parse).
 * @returns The JsonReader value described above, retaining the documented ownership and
 *   default-state semantics.
 */
pub static method(JsonReader) New() -> JsonReader {
  return JsonReader{_pad: 0};
}

/**
 * @brief Parse `text` and publish Handler events in document order.
 * @param text UTF-8 source; empty / whitespace-only input is a Parse error (JSON grammar).
 * @param handler SAX receiver (iface by value — Drawable peer; fat pointer mutates impl state).
 * @param scratch `MemStack` / `MemArena` (as `Allocator`) for Key/String temps; not durable
 *   nodes.
 * @returns Ok on full publish; Err on scan/parse failure or handler abort.
 * @note SoT spells `ref mut JsonHandler`; host-nyra iface dispatch requires by-value iface
 *   today.
 */
pub method(JsonReader) Parse(
  text: string,
  handler: JsonHandler,
  scratch: Allocator
) -> Result<Unit, JsonError> {
  return json_sax_parse(text, handler, scratch);
}

/**
 * @brief Read `path` then `Parse`.
 * @returns Ok with Unit on success; Err with JsonError on the failure paths described above.
 * @note I/O failures use `line: 0`, `column: 0`; `message` includes `path`.
 */
pub method(JsonReader) ParseFile(
  path: string,
  handler: JsonHandler,
  scratch: Allocator
) -> Result<Unit, JsonError> {
  let f: File = File.New(path);
  let rd: Result<string, IoError> = f.ReadAsString();
  if rd.IsErr() {
    let eo: IoError? = rd.get_if<IoError>();
    if eo == nil {
      return json_reader_fail(0, 0, "I/O error reading JSON file: ".Concat(path));
    }

    let msg: string = json_reader_io_kind(eo as IoError).Concat(" reading JSON file: ").Concat(path);

    return json_reader_fail(0, 0, msg);
  }

  let text_opt: string? = rd.get_if<string>();
  if text_opt == nil {
    return json_reader_fail(0, 0, "I/O error reading JSON file: ".Concat(path));
  }

  let src: string = text_opt as string;
  let heap_text: string = copy(src);

  return self.Parse(heap_text, handler, scratch);
}
