/**
 * @brief JsonReader / JsonHandler event unit tests (m_v0.19_p1).
 * @note Recorder state lives behind a pointer so by-value iface upcast (stack temp)
 *       still mutates the same arrays. SoT `ref mut JsonHandler` awaits codegen Load.
 * @note MemStack/MemArena must be Init'd in-place (ctx points at self).
 */
part of JsonTypes;

pub static kJsonEvNull: int32 = 1;
pub static kJsonEvBool: int32 = 2;
pub static kJsonEvInt64: int32 = 3;
pub static kJsonEvString: int32 = 4;
pub static kJsonEvStartObject: int32 = 5;
pub static kJsonEvKey: int32 = 6;
pub static kJsonEvEndObject: int32 = 7;
pub static kJsonEvStartArray: int32 = 8;
pub static kJsonEvEndArray: int32 = 9;
pub static kJsonEvUInt64: int32 = 10;
pub static kJsonEvNumber: int32 = 11;

/**
 * @brief Mutable event log (pointed at by the Handler shell).
 */
struct JsonEvState {
  kinds: Array<int32>;
  bools: Array<int32>;
  ints: Array<int64>;
  uints: Array<uint64>;
  strings: Array<string>;
  counts: Array<int32>;
  abort_at: int32;
  seen: int32;
}

/**
 * @brief Thin Handler shell — only a pointer; safe to pass as by-value JsonHandler.
 */
struct JsonEventRecorder implements JsonHandler {
  st: *mut JsonEvState;
}

func json_ev_state_new() -> JsonEvState {
  return JsonEvState{
    kinds: Array<int32>{},
    bools: Array<int32>{},
    ints: Array<int64>{},
    uints: Array<uint64>{},
    strings: Array<string>{},
    counts: Array<int32>{},
    abort_at: -1,
    seen: 0
  };
}

func json_ev_push_kind(st: *mut JsonEvState, k: int32) -> bool {
  unsafe {
    (*st).seen = (*st).seen + 1;
    if ((*st).abort_at >= 0) && ((*st).seen > (*st).abort_at) {
      return false;
    }
    (*st).kinds.Push(k);
    return true;
  }
}

method(JsonEventRecorder) Null() -> bool {
  return json_ev_push_kind(self.st, kJsonEvNull);
}

method(JsonEventRecorder) Bool(b: bool) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvBool) {
    return false;
  }
  unsafe {
    if b {
      (*self.st).bools.Push(1);
    } else {
      (*self.st).bools.Push(0);
    }
  }
  return true;
}

method(JsonEventRecorder) Int64(v: int64) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvInt64) {
    return false;
  }
  unsafe {
    (*self.st).ints.Push(v);
  }
  return true;
}

method(JsonEventRecorder) UInt64(v: uint64) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvUInt64) { return false; }
  unsafe { (*self.st).uints.Push(v); }
  return true;
}

method(JsonEventRecorder) Number(raw: string) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvNumber) { return false; }
  unsafe { (*self.st).strings.Push(copy(raw)); }
  return true;
}

method(JsonEventRecorder) String(s: string) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvString) {
    return false;
  }
  unsafe {
    (*self.st).strings.Push(copy(s));
  }
  return true;
}

method(JsonEventRecorder) StartObject() -> bool {
  return json_ev_push_kind(self.st, kJsonEvStartObject);
}

method(JsonEventRecorder) Key(k: string) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvKey) {
    return false;
  }
  unsafe {
    (*self.st).strings.Push(copy(k));
  }
  return true;
}

method(JsonEventRecorder) EndObject(member_count: int32) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvEndObject) {
    return false;
  }
  unsafe {
    (*self.st).counts.Push(member_count);
  }
  return true;
}

method(JsonEventRecorder) StartArray() -> bool {
  return json_ev_push_kind(self.st, kJsonEvStartArray);
}

method(JsonEventRecorder) EndArray(element_count: int32) -> bool {
  if !json_ev_push_kind(self.st, kJsonEvEndArray) {
    return false;
  }
  unsafe {
    (*self.st).counts.Push(element_count);
  }
  return true;
}

/**
 * @brief Slice the Allocator ABI row from an in-place-Init'd MemStack (ctx → stack).
 */
func json_scratch_from_stack(stack: ref mut MemStack) -> Allocator {
  unsafe {
    let sp: *mut MemStack = cast<MemStack>.pointer(stack);
    let ap: *mut Allocator = cast<Allocator>.pointer(sp);
    return *ap;
  }
}

/**
 * @brief Slice the Allocator ABI row from an in-place-Init'd MemArena (ctx → arena).
 */
func json_scratch_from_arena(arena: ref mut MemArena) -> Allocator {
  unsafe {
    let ap: *mut MemArena = cast<MemArena>.pointer(arena);
    let bp: *mut Allocator = cast<Allocator>.pointer(ap);
    return *bp;
  }
}

@test
func test_json_reader_empty_is_error() {
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("", rec, scratch);
  AssertTrue(r.IsErr());
  let eo: JsonError? = r.get_if<JsonError>();
  AssertTrue(eo != nil);
  let e: JsonError = eo as JsonError;
  AssertEqString(e.Message(), "empty input");
  AssertEqI32(state.kinds.Len(), 0);
}

@test
func test_json_reader_object_name_string() {
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("{\"name\":\"x\"}", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 4);
  AssertEqI32(state.kinds.Get(0), kJsonEvStartObject);
  AssertEqI32(state.kinds.Get(1), kJsonEvKey);
  AssertEqI32(state.kinds.Get(2), kJsonEvString);
  AssertEqI32(state.kinds.Get(3), kJsonEvEndObject);
  AssertEqI32(state.strings.Len(), 2);
  AssertEqString(state.strings.Get(0), "name");
  AssertEqString(state.strings.Get(1), "x");
  AssertEqI32(state.counts.Len(), 1);
  AssertEqI32(state.counts.Get(0), 1);
}

@test
func test_json_reader_array_scalars() {
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("[true, false, null, 42, \"hi\"]", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 7);
  AssertEqI32(state.kinds.Get(0), kJsonEvStartArray);
  AssertEqI32(state.kinds.Get(1), kJsonEvBool);
  AssertEqI32(state.kinds.Get(2), kJsonEvBool);
  AssertEqI32(state.kinds.Get(3), kJsonEvNull);
  AssertEqI32(state.kinds.Get(4), kJsonEvInt64);
  AssertEqI32(state.kinds.Get(5), kJsonEvString);
  AssertEqI32(state.kinds.Get(6), kJsonEvEndArray);
  AssertEqI32(state.bools.Len(), 2);
  AssertEqI32(state.bools.Get(0), 1);
  AssertEqI32(state.bools.Get(1), 0);
  AssertEqI32(state.ints.Len(), 1);
  AssertEqI64(state.ints.Get(0), 42 as int64);
  AssertEqI32(state.strings.Len(), 1);
  AssertEqString(state.strings.Get(0), "hi");
  AssertEqI32(state.counts.Get(0), 5);
}

@test
func test_json_reader_nested_object() {
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse(
    "{\"dependencies\":{\"stdlib\":{\"path\":\"../stdlib\"}}}",
    rec,
    scratch
  );
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 10);
  AssertEqI32(state.kinds.Get(0), kJsonEvStartObject);
  AssertEqI32(state.kinds.Get(1), kJsonEvKey);
  AssertEqI32(state.kinds.Get(2), kJsonEvStartObject);
  AssertEqI32(state.kinds.Get(3), kJsonEvKey);
  AssertEqI32(state.kinds.Get(4), kJsonEvStartObject);
  AssertEqI32(state.kinds.Get(5), kJsonEvKey);
  AssertEqI32(state.kinds.Get(6), kJsonEvString);
  AssertEqI32(state.kinds.Get(7), kJsonEvEndObject);
  AssertEqI32(state.kinds.Get(8), kJsonEvEndObject);
  AssertEqI32(state.kinds.Get(9), kJsonEvEndObject);
  AssertEqString(state.strings.Get(0), "dependencies");
  AssertEqString(state.strings.Get(1), "stdlib");
  AssertEqString(state.strings.Get(2), "path");
  AssertEqString(state.strings.Get(3), "../stdlib");
}

@test
func test_json_reader_handler_abort() {
  var state: JsonEvState = json_ev_state_new();
  state.abort_at = 1;
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("{\"name\":\"x\"}", rec, scratch);
  AssertTrue(r.IsErr());
  let eo: JsonError? = r.get_if<JsonError>();
  AssertTrue(eo != nil);
  let e: JsonError = eo as JsonError;
  AssertEqString(e.Message(), "handler aborted");
}

@test
func test_json_reader_int_and_bool_root() {
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();

  var state_i: JsonEvState = json_ev_state_new();
  var rec_i: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state_i) };
  let ri: Result<Unit, JsonError> = reader.Parse("7", rec_i, scratch);
  AssertTrue(ri.IsOk());
  AssertEqI32(state_i.kinds.Get(0), kJsonEvInt64);
  AssertEqI64(state_i.ints.Get(0), 7 as int64);

  var state_b: JsonEvState = json_ev_state_new();
  var rec_b: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state_b) };
  let rb: Result<Unit, JsonError> = reader.Parse("true", rec_b, scratch);
  AssertTrue(rb.IsOk());
  AssertEqI32(state_b.kinds.Get(0), kJsonEvBool);
  AssertEqI32(state_b.bools.Get(0), 1);
}

@test
func test_json_reader_escapes_and_unicode() {
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("\"a\\\"b\\n\\u0041\"", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 1);
  AssertEqI32(state.kinds.Get(0), kJsonEvString);
  AssertEqString(state.strings.Get(0), "a\"b\nA");
}

@test
func test_json_reader_preserves_float_duplicate_trailing() {
  var scratch: Allocator = CreateAllocator(0 as int64, 8 as int64);
  var reader: JsonReader = JsonReader.New();

  var s1: JsonEvState = json_ev_state_new();
  var r1: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut s1) };
  let e1: Result<Unit, JsonError> = reader.Parse("1.0e+2", r1, scratch);
  AssertTrue(e1.IsOk());
  AssertEqI32(s1.kinds.Len(), 1);
  AssertEqI32(s1.kinds.Get(0), kJsonEvNumber);
  AssertEqString(s1.strings.Get(0), "1.0e+2");

  var s2: JsonEvState = json_ev_state_new();
  var r2: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut s2) };
  let e2: Result<Unit, JsonError> = reader.Parse("{\"a\":1,\"a\":2}", r2, scratch);
  AssertTrue(e2.IsErr());
  let eo2: JsonError? = e2.get_if<JsonError>();
  AssertTrue(eo2 != nil);
  AssertEqString((eo2 as JsonError).Message(), "duplicate object key");

  var s3: JsonEvState = json_ev_state_new();
  var r3: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut s3) };
  let e3: Result<Unit, JsonError> = reader.Parse("true false", r3, scratch);
  AssertTrue(e3.IsErr());
  let eo3: JsonError? = e3.get_if<JsonError>();
  AssertTrue(eo3 != nil);
  AssertEqString((eo3 as JsonError).Message(), "trailing junk after value");
}

@test
func test_json_reader_memstack_scratch() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var stack: MemStack = MemStack{};
  stack.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = json_scratch_from_stack(stack);
  let mark: uintptr = stack.Mark();
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("{\"a\":1,\"b\":\"two\"}", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 6);
  stack.Reset(mark);
  AssertEqString(state.strings.Get(0), "a");
  AssertEqString(state.strings.Get(1), "b");
  AssertEqString(state.strings.Get(2), "two");
  var state2: JsonEvState = json_ev_state_new();
  var rec2: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state2) };
  let r2: Result<Unit, JsonError> = reader.Parse("{\"x\":\"y\"}", rec2, scratch);
  AssertTrue(r2.IsOk());
  AssertEqString(state2.strings.Get(0), "x");
  AssertEqString(state2.strings.Get(1), "y");
  _nyra_free(chunk);
}

@test
func test_json_reader_memarena_scratch() {
  let chunk: *mut int8 = _nyra_malloc(8192 as int64, 8 as int64);
  AssertTrue(chunk != (ptr<int8>.null()));
  var arena: MemArena = MemArena{};
  arena.Init(chunk as *mut uint8, 8192 as uintptr);
  let scratch: Allocator = json_scratch_from_arena(arena);
  var state: JsonEvState = json_ev_state_new();
  var rec: JsonEventRecorder = JsonEventRecorder{ st: cast<JsonEvState>.pointer(&mut state) };
  var reader: JsonReader = JsonReader.New();
  let r: Result<Unit, JsonError> = reader.Parse("{\"name\":\"x\"}", rec, scratch);
  AssertTrue(r.IsOk());
  AssertEqI32(state.kinds.Len(), 4);
  AssertEqString(state.strings.Get(0), "name");
  AssertEqString(state.strings.Get(1), "x");
  arena.ResetAll();
  arena.Release();
  _nyra_free(chunk);
}
