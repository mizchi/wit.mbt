# Changelog

## 0.4.0

- Add payloadless `future` and `stream`, `error-context`, fixed-length lists, and maps.
- Preserve async freestanding, resource method, and static function kinds in the AST, resolver, and JSON.
- Support top-level `use`, renamed type imports, world-level `use`, nested packages, and nested namespace/package paths. Top-level aliases are expanded within each source file before directory merging.
- Support named interface imports/exports, `@external-id`, and getter/setter functions, including resource properties.
- Retain and validate fallible constructor results and support fallible property accessors.
- Resolve world includes independently of declaration order and deduplicate included interface names.
- Validate semantic versions, kebab identifiers, recursive types, map key/value restrictions, and getter/setter pairs.
- Support nested block comments and keep ordinary line comments out of documentation.
- Update for the current MoonBit compiler while preserving the public `Result` APIs and explicitly extending existing trait methods.
- Fix Node.js CLI argument handling and add `just spec-check` to compare supported type/function semantics against `wasm-tools` on JS and native targets.

### API changes from 0.3.x

- `TypeExpr::Future` / `Stream` and `RTypeKind::Future` / `Stream` now contain optional payload types. `None` represents the bare type.
- `TypeExpr::Result` now contains two optional payload types. `result` is `Result(None, None)`, and `result<_, E>` has no success payload.
- `WitFile` gains `packages`; `UseDecl` gains `renames`.
- Functions, type definitions, and resolved interface references gain optional `external_id` metadata.
- Type and function-kind enums gain variants for the new syntax. Update exhaustive matches accordingly.
- See [SPEC.md](SPEC.md) for the reviewed upstream revisions and validation limits.
