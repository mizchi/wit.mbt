# mizchi/wit

WIT (WebAssembly Interface Types) parser and resolver written in MoonBit.

## Features

- **Lexer & Parser** – Tokenize and parse WIT source into a typed AST
- **Resolver** – Resolve parsed WIT into a flat, index-based representation suitable for code generation
- **Path resolver** – Load WIT files from `deps/` directory layouts produced by `wkg`
- **Current WIT syntax** – Async functions, optional future/stream payloads, error contexts, fixed-length lists, maps, file-local aliases, nested packages, external IDs, and property accessors

See [WIT support and validation limits](SPEC.md) and [API changes](CHANGELOG.md). Verified with MoonBit `0.1.20261104`.

## Conformance fixes in 0.4.1

Version 0.4.1 validates names and resource borrowing, resolves transitive world imports, retains stability metadata, and supports feature/version selection through `ResolveOptions`. See [the changelog](CHANGELOG.md).

## Install

```bash
moon add mizchi/wit
```

## Usage

### Parse a WIT source string

```moonbit
let source =
  #|package local:hello;
  #|
  #|interface greet {
  #|  greet: func(name: string) -> string;
  #|}
  #|
  #|world hello {
  #|  export greet;
  #|}

let wit_file = @wit.parse(source).unwrap()
```

### Resolve to a flat model

```moonbit
let resolve = @wit.resolve(source).unwrap()
```

## API

| Function | Description |
|----------|-------------|
| `parse(String) -> Result[WitFile, ParseError]` | Parse a WIT source string into an AST |
| `parse_path(String) -> Result[WitFile, ParseError]` | Parse a WIT file from a file path |
| `resolve(String) -> Result[Resolve, ParseError]` | Parse and resolve a WIT source string |
| `resolve_path(String, world? : String) -> Result[ResolveInput, ParseError]` | Resolve WIT from a directory path with optional world selection |
| `tokenize(String) -> Result[Array[Token], ParseError]` | Tokenize a WIT source string |

## License

Apache-2.0
