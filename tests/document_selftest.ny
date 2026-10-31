// Copyright (c) 2026 tangxiangjiang
// SPDX-License-Identifier: MIT

part of JsonTests;

/**
 * @brief JsonDocument build / query / durable-vs-scratch ownership tests (m_v0.19_p2).
 * @note Scratch strategy views use kernel MemStack.AsAllocator / MemArena.AsAllocator.
 * @see docs/design/stdlib/json.md §0.5–0.6
 */

@test
func test_json_document_empty_is_error() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse("", durable, scratch);
  AssertTrue(r.IsErr());
  let eo: JsonError? = r.get_if<JsonError>();
  AssertTrue(eo != nil);
  let e: JsonError = eo as JsonError;
  AssertEqString(e.Message(), "empty input");
}

@test
func test_json_document_query_object_name() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse("{\"name\":\"x\"}", durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  let root: Json = doc.Root();
  let obj_opt: JsonObject? = root.AsObject();
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  AssertEqI32(objv.Len(), 1);
  let key0: string? = objv.KeyAt(0);
  AssertTrue(key0 != nil);
  AssertEqString(key0 as string, "name");
  let val0: Json? = objv.ValueAt(0);
  AssertTrue(val0 != nil);
  let v0: Json = val0 as Json;
  let s_opt: JsonStr? = v0.node.get_if<JsonStr>();
  AssertTrue(s_opt != nil);
  let sv: JsonStr = s_opt as JsonStr;
  AssertEqString(sv.Text(), "x");

  let r2: Result<JsonDocument, JsonError> = JsonDocument.Parse("{\"name\":\"x\"}", durable, scratch);
  AssertTrue(r2.IsOk());
  let doc2_opt: JsonDocument? = r2.get_if<JsonDocument>();
  AssertTrue(doc2_opt != nil);
  var doc2: JsonDocument = doc2_opt as JsonDocument;
  let obj2_opt: JsonObject? = (doc2.Root()).AsObject();
  AssertTrue(obj2_opt != nil);
  var obj2: JsonObject = obj2_opt as JsonObject;
  let name_node: Json? = obj2.Get("name");
  AssertTrue(name_node != nil);
  let nv: Json = name_node as Json;
  let s2_opt: JsonStr? = nv.node.get_if<JsonStr>();
  AssertTrue(s2_opt != nil);
  let s2: JsonStr = s2_opt as JsonStr;
  AssertEqString(s2.Text(), "x");
}

@test
func test_json_document_query_array_scalars() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(
    "[true, false, null, 42, \"hi\"]",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  let root: Json = doc.Root();
  let arr_opt: JsonArray? = root.AsArray();
  AssertTrue(arr_opt != nil);
  var arrv: JsonArray = arr_opt as JsonArray;
  AssertEqI32(arrv.Len(), 5);

  let i0: Json? = arrv.Get(0);
  AssertTrue(i0 != nil);
  let v0: Json = i0 as Json;
  let v0_is_bool: bool = v0.node.holds<JsonBool>();
  AssertTrue(v0_is_bool);
  let b0_opt: JsonBool? = v0.node.get_if<JsonBool>();
  AssertTrue(b0_opt != nil);
  let b0: JsonBool = b0_opt as JsonBool;
  AssertTrue(b0.value);

  let i2: Json? = arrv.Get(2);
  AssertTrue(i2 != nil);
  let v2: Json = i2 as Json;
  let v2_is_null: bool = v2.node.holds<JsonNull>();
  AssertTrue(v2_is_null);

  let i3: Json? = arrv.Get(3);
  AssertTrue(i3 != nil);
  let v3: Json = i3 as Json;
  let iv: int64? = v3.AsInt();
  AssertTrue(iv != nil);
  AssertEqI64(iv as int64, 42 as int64);
  let ji_opt: JsonInt? = v3.node.get_if<JsonInt>();
  AssertTrue(ji_opt != nil);
  AssertEqI64((ji_opt as JsonInt).I64(), 42 as int64);

  let i4: Json? = arrv.Get(4);
  AssertTrue(i4 != nil);
  let v4: Json = i4 as Json;
  let s4_opt: JsonStr? = v4.node.get_if<JsonStr>();
  AssertTrue(s4_opt != nil);
  AssertEqString((s4_opt as JsonStr).Text(), "hi");

  let oor: Json? = arrv.Get(5);
  AssertTrue(oor == nil);
}

@test
func test_json_document_query_nested_object() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(
    "{\"dependencies\":{\"stdlib\":{\"path\":\"../stdlib\"}}}",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  let root: Json = doc.Root();
  let obj_opt: JsonObject? = root.AsObject();
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  let deps_n: Json? = objv.Get("dependencies");
  AssertTrue(deps_n != nil);
  let deps_obj: JsonObject? = (deps_n as Json).AsObject();
  AssertTrue(deps_obj != nil);
  var dm: JsonObject = deps_obj as JsonObject;
  let std_n: Json? = dm.Get("stdlib");
  AssertTrue(std_n != nil);
  let std_obj: JsonObject? = (std_n as Json).AsObject();
  AssertTrue(std_obj != nil);
  var sm: JsonObject = std_obj as JsonObject;
  let path_n: Json? = sm.Get("path");
  AssertTrue(path_n != nil);
  let path_v: Json = path_n as Json;
  let path_s: JsonStr? = path_v.node.get_if<JsonStr>();
  AssertTrue(path_s != nil);
  AssertEqString((path_s as JsonStr).Text(), "../stdlib");
}

@test
func test_json_document_array_of_objects_with_scalars() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(
    "{\"Types\":[{\"ID\":1,\"Name\":\"int32\"}]}",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  let doc: JsonDocument = doc_opt as JsonDocument;
  let root_opt: JsonObject? = (doc.Root()).AsObject();
  AssertTrue(root_opt != nil);
  let root: JsonObject = root_opt as JsonObject;
  let types_node: Json? = root.Get("Types");
  AssertTrue(types_node != nil);
  let types_opt: JsonArray? = (types_node as Json).AsArray();
  AssertTrue(types_opt != nil);
  let item_node: Json? = (types_opt as JsonArray).Get(0);
  AssertTrue(item_node != nil);
  let item_opt: JsonObject? = (item_node as Json).AsObject();
  AssertTrue(item_opt != nil);
  let id: Json? = (item_opt as JsonObject).Get("ID");
  AssertTrue(id != nil);
  AssertEqI64((id as Json).AsInt() as int64, 1 as int64);
}

@test
func test_json_document_parse_error() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse("{\"a\":1,\"a\":2}", durable, scratch);
  AssertTrue(r.IsErr());
  let eo: JsonError? = r.get_if<JsonError>();
  AssertTrue(eo != nil);
  let e: JsonError = eo as JsonError;
  AssertEqString(e.Message(), "duplicate object key");
}

@test
// Resetting parse scratch must not invalidate strings copied into the document allocator.
func test_json_document_memstack_scratch_reset_durable() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var stack: MemStack = MemStack{};
  stack.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = stack.AsAllocator();
  let mark: uintptr = stack.Mark();
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);

  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(
    "{\"a\":1,\"b\":\"two\"}",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  // Scratch Reset must not invalidate durable Document strings / query results.
  stack.Reset(mark);

  let root: Json = doc.Root();
  let obj_opt: JsonObject? = root.AsObject();
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  AssertEqI32(objv.Len(), 2);
  let ka: string? = objv.KeyAt(0);
  AssertTrue(ka != nil);
  AssertEqString(ka as string, "a");
  let kb: string? = objv.KeyAt(1);
  AssertTrue(kb != nil);
  AssertEqString(kb as string, "b");
  let vb: Json? = objv.Get("b");
  AssertTrue(vb != nil);
  let vb_n: Json = vb as Json;
  let sb: JsonStr? = vb_n.node.get_if<JsonStr>();
  AssertTrue(sb != nil);
  AssertEqString((sb as JsonStr).Text(), "two");
  let va: Json? = objv.Get("a");
  AssertTrue(va != nil);
  let ia: int64? = (va as Json).AsInt();
  AssertTrue(ia != nil);
  AssertEqI64(ia as int64, 1 as int64);
  // Scratch reusable after Reset; Document still valid.
  let r2: Result<JsonDocument, JsonError> = JsonDocument.Parse("{\"x\":\"y\"}", durable, scratch);
  AssertTrue(r2.IsOk());
  let doc2_opt: JsonDocument? = r2.get_if<JsonDocument>();
  AssertTrue(doc2_opt != nil);
  var doc2: JsonDocument = doc2_opt as JsonDocument;
  let root2: Json = doc2.Root();
  let o2_opt: JsonObject? = root2.AsObject();
  AssertTrue(o2_opt != nil);
  var o2: JsonObject = o2_opt as JsonObject;
  let xv: Json? = o2.Get("x");
  AssertTrue(xv != nil);
  let xv_n: Json = xv as Json;
  let xs: JsonStr? = xv_n.node.get_if<JsonStr>();
  AssertTrue(xs != nil);
  AssertEqString((xs as JsonStr).Text(), "y");
  // Original document still queryable after second Parse reused scratch.
  let root_again: Json = doc.Root();
  let obj_again_opt: JsonObject? = root_again.AsObject();
  AssertTrue(obj_again_opt != nil);
  var obj_again: JsonObject = obj_again_opt as JsonObject;
  let k_again: string? = obj_again.KeyAt(0);
  AssertTrue(k_again != nil);
  AssertEqString(k_again as string, "a");

  _nyra_free(chunk);
}

@test
// The durable document must outlive reuse of the temporary parsing arena.
func test_json_document_memarena_scratch_reset_durable() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var arena: MemArena = MemArena{};
  arena.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = arena.AsAllocator();
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);

  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(
    "{\"name\":\"pkg\",\"version\":1}",
    durable,
    scratch
  );
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;

  arena.ResetAll();

  let root: Json = doc.Root();
  let obj_opt: JsonObject? = root.AsObject();
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  let name_n: Json? = objv.Get("name");
  AssertTrue(name_n != nil);
  let name_v: Json = name_n as Json;
  let name_s: JsonStr? = name_v.node.get_if<JsonStr>();
  AssertTrue(name_s != nil);
  AssertEqString((name_s as JsonStr).Text(), "pkg");
  let ver_n: Json? = objv.Get("version");
  AssertTrue(ver_n != nil);
  let ver_i: int64? = (ver_n as Json).AsInt();
  AssertTrue(ver_i != nil);
  AssertEqI64(ver_i as int64, 1 as int64);

  arena.Release();
  _nyra_free(chunk);
}

@test
func test_json_document_parsefile_sample() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.ParseFile(
    JsonFixture.Resolve("tests/data/doc_sample.json").path,
    durable,
    scratch
  );
  if !r.IsOk() {
    let r2: Result<JsonDocument, JsonError> = JsonDocument.ParseFile(
      JsonFixture.Resolve("tests/data/doc_sample.json").path,
      durable,
      scratch
    );
    AssertTrue(r2.IsOk());
    let doc_opt: JsonDocument? = r2.get_if<JsonDocument>();
    AssertTrue(doc_opt != nil);
    var doc: JsonDocument = doc_opt as JsonDocument;
    let root: Json = doc.Root();
    let obj_opt: JsonObject? = root.AsObject();
    AssertTrue(obj_opt != nil);
    var objv: JsonObject = obj_opt as JsonObject;
    let name_n: Json? = objv.Get("name");
    AssertTrue(name_n != nil);
    let name_v: Json = name_n as Json;
    let name_s: JsonStr? = name_v.node.get_if<JsonStr>();
    AssertTrue(name_s != nil);
    AssertEqString((name_s as JsonStr).Text(), "json");
    return;
  }

  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  let root: Json = doc.Root();
  let obj_opt: JsonObject? = root.AsObject();
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  let name_n: Json? = objv.Get("name");
  AssertTrue(name_n != nil);
  let name_v: Json = name_n as Json;
  let name_s: JsonStr? = name_v.node.get_if<JsonStr>();
  AssertTrue(name_s != nil);
  AssertEqString((name_s as JsonStr).Text(), "json");
}

@test
func test_json_uint64_full_range_roundtrip() {
  var durable: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  var scratch: Allocator = Allocator.ProcessHeap(0 as int64, 8 as int64);
  let parsed: Result<JsonDocument, JsonError> = JsonDocument.Parse(
    "{\"id\":18446744073709551615}", durable, scratch);
  AssertTrue(parsed.IsOk());
  let doc_opt: JsonDocument? = parsed.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  let root: Json = (doc_opt as JsonDocument).Root();
  let object_opt: JsonObject? = root.AsObject();
  AssertTrue(object_opt != nil);
  let id_opt: Json? = (object_opt as JsonObject).Get("id");
  AssertTrue(id_opt != nil);
  let value_opt: uint64? = (id_opt as Json).AsUInt64();
  AssertTrue(value_opt != nil && (value_opt as uint64) == 18446744073709551615u64);
  let encoded: string = JsonWriter.Emit(root);
  AssertTrue(encoded == "{\"id\":18446744073709551615}");
  let reparsed: Result<JsonDocument, JsonError> = JsonDocument.Parse(encoded, durable, scratch);
  AssertTrue(reparsed.IsOk());
  let reparsed_opt: JsonDocument? = reparsed.get_if<JsonDocument>();
  AssertTrue(reparsed_opt != nil);
  let reparsed_id: Json? = (((reparsed_opt as JsonDocument).Root()).AsObject() as JsonObject).Get("id");
  AssertTrue(reparsed_id != nil);
  AssertTrue(((reparsed_id as Json).AsUInt64() as uint64) == 18446744073709551615u64);
}
