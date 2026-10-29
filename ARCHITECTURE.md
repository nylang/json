# json module architecture

The product entry exports `interface/json.ni` and assembles the implementations.
The existing document layout, Handler contract and allocator lifetimes are retained.

- `private/model.ny` owns node accessors and value construction. It does not parse
  documents, hold a Handler stack or perform I/O orchestration.
- `private/scalar.ny` owns exact number spelling, integer formatting, UTF-8 byte
  conversion and allocator-bound string copies. It owns no document state.
- `private/reader.ny` with `parse.ny` owns the SAX recursive-descent parser and
  Reader I/O admission. Parse cursor, scratch data and handler invocation remain
  local to one parse operation.
- `private/document.ny` with `writer.ny` owns durable tree construction and the
  event Writer adapter. Their shared DOM frame stack remains private to this TU;
  retaining this part relationship is intentional because both mutate that stack.
- `private/emit.ny` owns tree serialization and structural comparison. It consumes
  model values; it cannot mutate the DOM builder's frame stack.

The dependency direction is scalar/model contracts into Reader and encoding,
then DOM orchestration into Reader and encoding operations. No private frame or
parser cursor crosses a module boundary. Tests live in a separate selftest TU
and exercise model, Reader, Document and Writer through those boundaries.
