/**
 * @brief JsonWriter / Accept / Emit tests (m_v0.19_p3).
 * @see docs/design/stdlib/json.md §0.4 · §1.5
 */
part of JsonTypes;

func json_parse_tree(text: string) -> Json {
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  if !r.IsOk() {
    return json_null_node();
  }
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  if doc_opt == nil {
    return json_null_node();
  }
  return (doc_opt as JsonDocument).Root();
}

@test
func test_json_writer_emit_null() {
  let n: Json = Json{ node: JsonNull{ _pad: 0 } };
  let text: string = JsonWriter.Emit(n);
  AssertEqString(text, "null");
}

@test
func test_json_writer_accept_roundtrip_name() {
  let src: Json = json_parse_tree("{\"name\":\"x\"}");
  let text: string = JsonWriter.Emit(src);
  AssertTrue(text.Contains("\"name\""));
  AssertTrue(text.Contains("\"x\""));
  var durable: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  let r: Result<JsonDocument, JsonError> = JsonDocument.Parse(text, durable, scratch);
  AssertTrue(r.IsOk());
  let doc_opt: JsonDocument? = r.get_if<JsonDocument>();
  AssertTrue(doc_opt != nil);
  var doc: JsonDocument = doc_opt as JsonDocument;
  let obj_opt: JsonObject? = JsonAsObject(doc.Root());
  AssertTrue(obj_opt != nil);
  var objv: JsonObject = obj_opt as JsonObject;
  let name_node: Json? = objv.Get("name");
  AssertTrue(name_node != nil);
  let nv: Json = name_node as Json;
  let s_opt: JsonStr? = nv.node.get_if<JsonStr>();
  AssertTrue(s_opt != nil);
  AssertEqString((s_opt as JsonStr).Text(), "x");
}

@test
func test_json_writer_new_handler_get_string() {
  var w: JsonWriter = JsonWriter.New();
  AssertTrue(w.StartObject());
  AssertTrue(w.Key("name"));
  AssertTrue(w.String("x"));
  AssertTrue(w.EndObject(1));
  let text: string = w.GetString();
  AssertEqString(text, "{\"name\":\"x\"}");
}

@test
func test_json_accept_handler_events() {
  var st: JsonEvState = json_ev_state_new();
  let stp: *mut JsonEvState = cast<JsonEvState>.pointer(& mut st);
  var rec: JsonEventRecorder = JsonEventRecorder{ st: stp };
  let node: Json = json_parse_tree("[true, null]");
  AssertTrue(node.Accept(rec));
  AssertTrue(st.kinds.Len() >= 4);
}
