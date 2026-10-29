// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of JsonTests;

/**
 * @brief JsonWriter.Emit + Document round-trip tests (walk `Json.node` in JsonTypes).
 * @see docs/design/stdlib/json.md §1.5
 */

func json_assert_round_trip(node: Json) {
  // Emit takes Json by value (move). Compare two Document parses of the emitted text.
  let text: string = JsonWriter.Emit(node);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  AssertTrueMsg(r.IsOk(), text);
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  let r2: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  AssertTrueMsg(r2.IsOk(), text);
  let doc2_opt: JsonDocument? = r2.get_if<JsonDocument>();
  AssertTrue(doc2_opt != nil);
  AssertTrue(JsonTreesEqual((doc_opt as JsonDocument).Root(),(doc2_opt as JsonDocument).Root()));
}

func json_assert_round_trip_text(src: string) {
  json_assert_round_trip(json_parse_tree(src));
}

func json_emit_quoted(s: string) -> string {
  let n: Json = Json{node: JsonStr{value: copy(s)}};

  return JsonWriter.Emit(n);
}

@test
func test_json_emit_empty_collections_and_null() {
  let n: Json = Json{node: JsonNull{_pad: 0}};
  let nt: string = JsonWriter.Emit(n);
  AssertEqString(nt, "null");
  json_assert_round_trip(n);
  let empty_obj: Json = Json{node: JsonObject{entries: Array<JsonObjectEntry>{}}};
  let mt: string = JsonWriter.Emit(empty_obj);
  AssertEqString(mt, "{}");
  json_assert_round_trip(empty_obj);
  let empty_arr: Json = Json{node: JsonArray{items: Array<Json>{}}};
  let st: string = JsonWriter.Emit(empty_arr);
  AssertEqString(st, "[]");
  json_assert_round_trip(empty_arr);
}

@test
func test_json_emit_quotes_special_chars() {
  let quote: string = json_emit_quoted("a\"b");
  AssertTrue(quote.Contains("\\\""));
  json_assert_round_trip(Json{node: JsonStr{value: copy("a\"b")}});
  json_assert_round_trip(Json{node: JsonStr{value: copy("true")}});
  json_assert_round_trip(Json{node: JsonStr{value: copy("1")}});
  json_assert_round_trip(Json{node: JsonStr{value: copy("")}});
  json_assert_round_trip(Json{node: JsonStr{value: copy("hello world")}});
  let nl: string = json_emit_quoted("a\nb");
  AssertTrue(nl.Contains("\\n"));
  json_assert_round_trip(Json{node: JsonStr{value: copy("a\nb\tc\\d")}});
}

@test
func test_json_emit_int_bool() {
  json_assert_round_trip_text("42");
  json_assert_round_trip_text("-1");
  json_assert_round_trip_text("-7");
  json_assert_round_trip_text("true");
  json_assert_round_trip_text("false");
  AssertEqString(JsonWriter.Emit(json_parse_tree("42")), "42");
  AssertEqString(JsonWriter.Emit(json_parse_tree("-1")), "-1");
  AssertEqString(JsonWriter.Emit(json_parse_tree("true")), "true");
  AssertEqString(JsonWriter.Emit(json_parse_tree("false")), "false");
}

@test
func test_json_emit_nested_object_array() {
  json_assert_round_trip_text("{\"a\":1,\"b\":[true,null,\"x\"],\"c\":{\"d\":2}}");
  json_assert_round_trip_text("[{\"k\":\"v\"},[],{}]");
  json_assert_round_trip_text("{\"schema\":2,\"moduleId\":\"m\",\"names\":{}}");
}

@test
func test_json_emit_compact_no_pretty() {
  let text: string = JsonWriter.Emit(json_parse_tree("{\n  \"a\" : 1\n}"));
  AssertEqString(text, "{\"a\":1}");
  AssertFalse(text.Contains("\n"));
  AssertFalse(text.Contains(" "));
}
