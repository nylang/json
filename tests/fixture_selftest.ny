// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of JsonTests;

/**
 * @brief Package fixtures: ParseFile → Emit → Parse tree equality (m_v0.19_p3).
 * @note Face-shaped fixture mirrors check_faces_selftest DecodeFaceJSON payload (schema 2).
 * @see docs/design/stdlib/json.md §1.5 · §2
 */

func json_path_exists(path: string) -> bool {
  let f: File = File.New(path);

  return f.Exists();
}

func json_resolve_testdata(rel: string) -> string {
  // Resolve package-owned fixtures from either the package or workspace cwd.
  var prefix: string = "";
  var depth: int32 = 0;
  while depth < 8 {
    let candidate: string = prefix.Concat(rel);
    if json_path_exists(candidate) {
      return candidate;
    }

    let workspace: string = prefix.Concat("third_party/json/").Concat(rel);
    if json_path_exists(workspace) {
      return workspace;
    }

    prefix = "../".Concat(prefix);
    depth = depth + 1;
  }

  return copy("");
}

func json_assert_fixture_round_trip(rel: string) {
  let path: string = json_resolve_testdata(rel);
  AssertTrueMsg(path.length > 0, rel);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.ParseFile(path, durable, scratch);
  if !r.IsOk() {
    let eo: JsonError? = r.get_if<JsonError>();
    if eo != nil {
      AssertTrueMsg(false,(eo as JsonError).Message());
    } else {
      AssertTrueMsg(false, path);
    }

    return;
  }

  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  let text: string = JsonWriter.Emit((doc_opt as JsonDocument).Root());
  let r2: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  if !r2.IsOk() {
    let eo2: JsonError? = r2.get_if<JsonError>();
    if eo2 != nil {
      AssertTrueMsg(false,(eo2 as JsonError).Message().Concat(" | ").Concat(text));
    } else {
      AssertTrueMsg(false, text);
    }

    return;
  }

  let doc2_opt: JsonDocument? = r2.get_if<JsonDocument>();
  AssertTrue(doc2_opt != nil);
  let r3: Result<JsonDocument, JsonError> = JsonDocument.ParseFile(path, durable, scratch);
  AssertTrueMsg(r3.IsOk(), path);
  let doc3_opt: JsonDocument? = r3.get_if<JsonDocument>();
  AssertTrue(doc3_opt != nil);
  AssertTrueMsg(
    JsonTreesEqual((doc2_opt as JsonDocument).Root(),(doc3_opt as JsonDocument).Root()),
    text
  );
}

@test
func test_json_fixture_scalars() {
  json_assert_fixture_round_trip("tests/data/fixtures/scalars.json");
}

@test
func test_json_fixture_nested() {
  json_assert_fixture_round_trip("tests/data/fixtures/nested.json");
}

@test
func test_json_fixture_escapes() {
  json_assert_fixture_round_trip("tests/data/fixtures/escapes.json");
}

@test
func test_json_fixture_face_shape() {
  json_assert_fixture_round_trip("tests/data/fixtures/face_shape.json");
  let path: string = json_resolve_testdata("tests/data/fixtures/face_shape.json");
  AssertTrue(path.length > 0);
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.ParseFile(path, durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  let obj_opt: JsonObject? = JsonAsObject(doc.Root());
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  let mid: Json? = objv.Get("moduleId");
  AssertTrue(mid != nil);
  let midv: Json = mid as Json;
  let s_opt: JsonStr? = midv.node.get_if<JsonStr>();
  AssertTrue(s_opt != nil);
  AssertEqString((s_opt as JsonStr).Text(), "named_optional_lib");
  let schema: Json? = objv.Get("schema");
  AssertTrue(schema != nil);
  let schema_i: int64? = JsonAsInt(schema as Json);
  AssertTrue(schema_i != nil);
  AssertEqI64(schema_i as int64, 2 as int64);
}

@test
func test_json_fixture_empty_collections() {
  json_assert_fixture_round_trip("tests/data/fixtures/empty_object.json");
  json_assert_fixture_round_trip("tests/data/fixtures/empty_array.json");
}
