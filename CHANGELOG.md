# Changelog

## 0.4.1

- Complete transitive world imports for exported interfaces, inline interfaces, and world-level type imports.
- Resolve arbitrarily ordered chains of interface type re-exports and reject interface dependency cycles and unused unresolved top-level aliases.
- Reject duplicate and case-insensitively conflicting definitions, parameters, fields, enum cases, and included world items; reject empty compound type definitions and duplicate constructors.
- Validate resource targets and borrowed return values, preserve resource aliases as aliases, and apply ownership at value sites after forward references have resolved.
- Decode Core WebAssembly string escapes, including Unicode scalars and UTF-8 byte escapes; reject invalid escapes, invalid UTF-8, raw control characters, and invalid scalars.
- Accept an initial UTF-8 BOM and retain block documentation comments.
- Retain stability annotations in the AST, resolved model, and JSON. Validate annotation syntax, conflicting gates, package-version bounds, and deprecation ordering.
- Add `ResolveOptions::new(features?, all_features?, target_version?)` to string, multi-AST, path, and interface-info resolution. Unstable APIs require explicit opt-in; target-version filtering excludes later APIs.
- Add CLI options `--features`, `--all-features`, and `--target-version`, and select the default world after filtering.
- Extend `spec-check` to compare world dependency graphs and metadata, exercise invalid inputs on JS/native, and optionally use a reproducible pinned upstream oracle.

### API changes

- Gate-bearing AST and resolved structures gain `attributes : Attributes`.
- `WorldItem::Attributed` retains annotations on interface imports and exports.
- `WitFile.uses` retains typed `TopLevelUse` entries, including unused bindings.
- Percent-escaped identifiers retain `TokenType::ExplicitIdent` identity.
- Resolution defaults to excluding unstable definitions; use `ResolveOptions::new(all_features=true)` to opt into all of them.

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
