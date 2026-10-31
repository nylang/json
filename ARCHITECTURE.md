# json module architecture

The product entry exports `interface/json.ni` and assembles the implementations.
The existing document layout, Handler contract and allocator lifetimes are retained.

- `private/model.ny` owns node accessors and value construction. It does not parse
  documents, hold a Handler stack or perform I/O orchestration.
- `private/scalar.ny` owns checked `JsonI64Parse` / `JsonU64Parse` number
  recognition. Decimal output delegates to primitive `ToString`; byte access,
  UTF-8 and allocator-bound copying use kernel/stdlib capabilities.
- `private/reader.ny` with `parse.ny` owns the SAX recursive-descent parser and
  Reader I/O admission. Parse cursor, scratch data and handler invocation remain
  local to the `ParseCtx` for one parse operation.
- `private/document.ny` with `writer.ny` owns durable tree construction and the
  event Writer adapter. Their shared DOM frame stack remains private to this TU;
  retaining this part relationship is intentional because both mutate that stack.
  `JsonDomState` owns stack/allocator policy and `JsonDomFrame` frame lifetime.
- `private/emit.ny` defines `JsonEmitter`, owning a StringBuffer for one output.
  `Json.Equals` owns structural comparison. Emission consumes
  model values; it cannot mutate the DOM builder's frame stack.

The dependency direction is scalar/model contracts into Reader and encoding,
then DOM orchestration into Reader and encoding operations. No private frame or
parser cursor crosses a module boundary. Tests live in a separate selftest TU
and exercise model, Reader, Document and Writer through those boundaries.

Public projection, factory, equality and event-publication operations belong to
`Json` and its scalar/container value types. `JsonFixture` retains test path and
relative identity rather than passing fixture state through free functions.
The public source migration requires matching 1.0.5 kernel/stdlib and a full
consumer rebuild; old aliases are removed. The parent focused receipt is
`docs/roadmaps/m_v1.0.5/json-owner-refactor.json` (34 tests on macOS arm64).
