# WIT support

Reviewed on 2026-11-15 against:

- [Component Model WIT specification](https://github.com/WebAssembly/component-model/blob/dd1fefc0c618382359feca6f2c758a2b3ef21c36/design/mvp/WIT.md).
- [wasm-tools WIT parser](https://github.com/bytecodealliance/wasm-tools/blob/a104ec67f6b640ff21b41e67d1145a1d4411df06/crates/wit-parser/src/ast.rs) and its resolver/model.

The parser accepts core WIT syntax and the reviewed extensions for fixed-length lists (`list<T, N>`), maps (`map<K, V>`), nested namespace/package paths, custom interface import/export labels, external IDs, and getter/setter functions. These extensions are accepted without a parser feature flag; their presence here does not imply that every Component Model tool or runtime implements them.

Async function kinds are retained rather than converted to synchronous functions. Bare `future`, `stream`, and `result` retain absent payloads, including in JSON. Fallible constructors retain their result wrapper and require their own resource as the success payload. Property accessors can fail; setter results must have no success payload. Fixed-length list sizes are unsigned 32-bit integers. Map keys must resolve to supported scalar types; map values cannot transitively contain resources, handles, futures, streams, or error contexts.

Top-level `use` aliases are expanded into paths in the returned AST. Their scope is one source file or nested package body. They do not leak between files merged by `parse_path`. Nested namespace and package segments are retained in the existing `PackageName.ns` and `PackageName.name` strings.

The resolver validates recursive type graphs, world-include cycles, map restrictions, and getter/setter signatures and pairs. It is not a complete replacement for the upstream validator. In particular, `@since`, `@unstable`, and `@deprecated` annotations are recognized and consumed, but their metadata, feature filtering, and compatibility rules are not implemented. Component binary encoding/validation and runtime ABI validation are outside this library's scope.

Run the regular release checks with:

```sh
just release-check
just target=native check
just target=native test
```

With Python 3 and `wasm-tools` available, run:

```sh
just spec-check
```

This compares the type meanings and function JSON in `testdata/current.wit` and the file-local alias fixture in `testdata/file-scope` against the installed `wasm-tools`, then runs both fixtures through the JS and native CLIs. It normalizes type IDs and aliases; it does not assert byte-for-byte equality of the complete resolution graph. Verified with `wasm-tools 1.245.1`; the more recent external-ID and property-accessor syntax is covered by MoonBit tests based on the pinned upstream sources above.
