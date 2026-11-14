# WIT support

The conformance fixes and annotation options described below are available in 0.4.1.

Reviewed on 2026-11-15 against:

- [Component Model WIT specification](https://github.com/WebAssembly/component-model/blob/dd1fefc0c618382359feca6f2c758a2b3ef21c36/design/mvp/WIT.md).
- [wasm-tools WIT parser](https://github.com/bytecodealliance/wasm-tools/blob/a104ec67f6b640ff21b41e67d1145a1d4411df06/crates/wit-parser/src/ast.rs) and its resolver/model.

The parser accepts core WIT syntax and the reviewed extensions for fixed-length lists (`list<T, N>`), maps (`map<K, V>`), nested namespace/package paths, custom interface import/export labels, external IDs, and getter/setter functions. These extensions are accepted without a parser feature flag; their presence here does not imply that every Component Model tool or runtime implements them.

Async function kinds are retained rather than converted to synchronous functions. Bare `future`, `stream`, and `result` retain absent payloads, including in JSON. Fallible constructors retain their result wrapper and require their own resource as the success payload. Property accessors can fail; setter results must have no success payload. Fixed-length list sizes are unsigned 32-bit integers. Map keys must resolve to supported scalar types; map values cannot transitively contain resources, handles, futures, streams, or error contexts.

Top-level `use` aliases are expanded into paths in the returned AST. Their scope is one source file or nested package body. They do not leak between files merged by `parse_path`. Nested namespace and package segments are retained in the existing `PackageName.ns` and `PackageName.name` strings.

The resolver checks recursive type graphs, interface/world dependency cycles, resource handle targets, borrowed return values, compound type cardinality, strong name uniqueness, map restrictions, and getter/setter signatures and pairs. Interface type dependencies are closed transitively in each world's imports, unless an exported interface dependency is explicitly satisfied by another export. Resource aliases preserve nominal resource identity; own/borrow handles refer to the underlying resource rather than another handle.

`@since`, `@unstable`, and `@deprecated` are retained as typed `Attributes` on AST definitions and resolved definitions, and emitted as JSON stability metadata. Annotation fields, conflicting gates, version requirements, unreleased versions, and deprecation ordering are validated. `resolve`, `resolve_multi`, `resolve_path`, and the interface-info helpers accept a named `options` argument:

```moonbit
let options = @wit.ResolveOptions::new(
  features=["preview"],
  target_version="1.1.0",
)
let resolved = @wit.resolve(source, options~).unwrap()
```

Unstable items are excluded by default. `all_features=true` enables every unstable item; `features` selects named features. `target_version` filters definitions introduced after that semantic version; it does not rewrite the source package identity. Filtering applies to interfaces, worlds, resources, functions, type definitions, imports, exports, uses, and includes. The original source annotations remain available through `parse`/`parse_path` even when resolution would filter those items.

The CLI accepts the same selections with `--all-features`, `--features preview,another`, and `--target-version 1.1.0`. A feature-hidden world is excluded before default world selection.

The lexer accepts Core WebAssembly Unicode and UTF-8 byte escapes, validates Unicode scalars and UTF-8, preserves escaped identifier identity and block documentation, and permits an initial UTF-8 BOM.

These checks and the finite corpus below are not a proof of complete WIT conformance. Component binary encoding/validation and runtime ABI validation remain outside this library's scope.

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

The default comparison uses the installed `wasm-tools` on the shared syntax fixtures. It compares interface types/functions, world imports/exports, resource identity, docs, and stability/external-ID metadata on JS and native. It normalizes allocation IDs, aliases, and external-ID JSON field spelling rather than requiring byte-for-byte JSON equality.

The acceptance corpus in `testdata/conformance.json` records 54 positive/negative cases checked against upstream revision `a104ec67f6b640ff21b41e67d1145a1d4411df06`. The same cases run as MoonBit unit tests and through both CLIs; regenerate their unit tests after editing the corpus:

```sh
python3 scripts/generate-conformance-tests.py
just fmt
```

For a live comparison with the pinned upstream implementation, including newer gated syntax and the full semantic result of every accepted corpus input:

```sh
# Requires Python 3, Cargo, and network access on the first build.
just spec-reference
just spec-check --reference _build/spec-reference/probe/target/debug/wit-spec-probe
```

The oracle is built outside the source package under `_build`; it does not replace the installed `wasm-tools`. Shared-syntax comparisons were also verified with `wasm-tools 1.245.1`.
