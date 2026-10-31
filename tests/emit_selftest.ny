// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of JsonTests;

/**
 * @brief JsonWriter.Emit + Document round-trip tests (walk `Json.node` in JsonTypes).
 * @see docs/design/stdlib/json.md §1.5
 */

method(Json) AssertRoundTrip() {
  // Emit takes Json by value (move). Compare two Document parses of the emitted text.
  let text: string = JsonWriter.Emit(self);
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  AssertTrueMsg(r.IsOk(), text);
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  let r2: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  AssertTrueMsg(r2.IsOk(), text);
  let doc2_opt: JsonDocument? = r2.get_if<JsonDocument>();
  AssertTrue(doc2_opt != nil);
  AssertTrue(((doc_opt as JsonDocument).Root()).Equals((doc2_opt as JsonDocument).Root()));
}

static method(JsonDocument) AssertRoundTripText(src: string) {
  (JsonDocument.TestRoot(src)).AssertRoundTrip();
}

static method(JsonWriter) EmitQuoted(s: string) -> string {
  let n: Json = Json{node: JsonStr{value: copy(s)}};

  return JsonWriter.Emit(n);
}

@test
func test_json_emit_empty_collections_and_null() {
  let n: Json = Json{node: JsonNull{_pad: 0}};
  let nt: string = JsonWriter.Emit(n);
  AssertEqString(nt, "null");
  n.AssertRoundTrip();
  let empty_obj: Json = Json{node: JsonObject{entries: Array<JsonObjectEntry>{}}};
  let mt: string = JsonWriter.Emit(empty_obj);
  AssertEqString(mt, "{}");
  empty_obj.AssertRoundTrip();
  let empty_arr: Json = Json{node: JsonArray{items: Array<Json>{}}};
  let st: string = JsonWriter.Emit(empty_arr);
  AssertEqString(st, "[]");
  empty_arr.AssertRoundTrip();
}

@test
func test_json_emit_quotes_special_chars() {
  let quote: string = JsonWriter.EmitQuoted("a\"b");
  AssertTrue(quote.Contains("\\\""));
  (Json{node: JsonStr{value: copy("a\"b")}}).AssertRoundTrip();
  (Json{node: JsonStr{value: copy("true")}}).AssertRoundTrip();
  (Json{node: JsonStr{value: copy("1")}}).AssertRoundTrip();
  (Json{node: JsonStr{value: copy("")}}).AssertRoundTrip();
  (Json{node: JsonStr{value: copy("hello world")}}).AssertRoundTrip();
  let nl: string = JsonWriter.EmitQuoted("a\nb");
  AssertTrue(nl.Contains("\\n"));
  (Json{node: JsonStr{value: copy("a\nb\tc\\d")}}).AssertRoundTrip();
}

@test
func test_json_emit_int_bool() {
  JsonDocument.AssertRoundTripText("42");
  JsonDocument.AssertRoundTripText("-1");
  JsonDocument.AssertRoundTripText("-7");
  JsonDocument.AssertRoundTripText("true");
  JsonDocument.AssertRoundTripText("false");
  AssertEqString(JsonWriter.Emit(JsonDocument.TestRoot("42")), "42");
  AssertEqString(JsonWriter.Emit(JsonDocument.TestRoot("-1")), "-1");
  AssertEqString(JsonWriter.Emit(JsonDocument.TestRoot("true")), "true");
  AssertEqString(JsonWriter.Emit(JsonDocument.TestRoot("false")), "false");
}

@test
func test_json_emit_nested_object_array() {
  JsonDocument.AssertRoundTripText("{\"a\":1,\"b\":[true,null,\"x\"],\"c\":{\"d\":2}}");
  JsonDocument.AssertRoundTripText("[{\"k\":\"v\"},[],{}]");
  JsonDocument.AssertRoundTripText("{\"schema\":2,\"moduleId\":\"m\",\"names\":{}}");
}

@test
func test_json_emit_compact_no_pretty() {
  let text: string = JsonWriter.Emit(JsonDocument.TestRoot("{\n  \"a\" : 1\n}"));
  AssertEqString(text, "{\"a\":1}");
  AssertFalse(text.Contains("\n"));
  AssertFalse(text.Contains(" "));
}
