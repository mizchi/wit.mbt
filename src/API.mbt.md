# API Documentation

This file contains executable doc tests using `mbt test` blocks.

## parse

Parse a WIT source string.

```mbt check
///|
test {
  let source = "package local:hello;\n\ninterface greet {\n  greet: func(name: string) -> string;\n}\n\nworld hello {\n  export greet;\n}\n"
  debug_inspect(
    @wit.parse(source),
    content=(
      #|Ok(
      #|  {
      #|    pkg: Some({ ns: "local", name: "hello", version: None }),
      #|    interfaces: [
      #|      {
      #|        name: "greet",
      #|        docs: None,
      #|        items: [
      #|          Function(
      #|            {
      #|              name: "greet",
      #|              kind: Freestanding,
      #|              params: [{ name: "name", ty: String_ }],
      #|              result: Some(String_),
      #|              docs: None,
      #|              external_id: None,
      #|              attributes: { since: None, unstable: None, deprecated: None },
      #|            },
      #|          ),
      #|        ],
      #|        attributes: { since: None, unstable: None, deprecated: None },
      #|      },
      #|    ],
      #|    worlds: [
      #|      {
      #|        name: "hello",
      #|        docs: None,
      #|        types: [],
      #|        imports: [],
      #|        exports: [Interface({ pkg: None, interface: "greet" })],
      #|        attributes: { since: None, unstable: None, deprecated: None },
      #|      },
      #|    ],
      #|    packages: [],
      #|    uses: [],
      #|  },
      #|)
    ),
  )
}
```

## resolve

Resolve a WIT source string into a Resolve structure.

```mbt check
///|
test {
  let source = "package local:hello;\n\ninterface greet {\n  greet: func(name: string) -> string;\n}\n\nworld hello {\n  export greet;\n}\n"
  debug_inspect(
    @wit.resolve(source),
    content=(
      #|Ok(
      #|  {
      #|    worlds: [
      #|      {
      #|        name: "hello",
      #|        docs: None,
      #|        imports: {},
      #|        exports: {
      #|          "interface-0": Interface(
      #|            {
      #|              id: 0,
      #|              external_id: None,
      #|              attributes: { since: None, unstable: None, deprecated: None },
      #|            },
      #|          ),
      #|        },
      #|        pkg: Some(0),
      #|        attributes: { since: None, unstable: None, deprecated: None },
      #|      },
      #|    ],
      #|    interfaces: [
      #|      {
      #|        name: Some("greet"),
      #|        docs: None,
      #|        functions: {
      #|          "greet": {
      #|            name: "greet",
      #|            kind: Freestanding,
      #|            params: [("name", String_)],
      #|            result: Some(String_),
      #|            docs: None,
      #|            external_id: None,
      #|            attributes: { since: None, unstable: None, deprecated: None },
      #|          },
      #|        },
      #|        types: {},
      #|        pkg: Some(0),
      #|        attributes: { since: None, unstable: None, deprecated: None },
      #|      },
      #|    ],
      #|    types: [],
      #|    packages: [
      #|      {
      #|        name: { ns: "local", name: "hello", version: None },
      #|        interfaces: { "greet": 0 },
      #|        worlds: { "hello": 0 },
      #|      },
      #|    ],
      #|  },
      #|)
    ),
  )
}
```

## tokenize

Tokenize a WIT source string.

```mbt check
///|
test {
  debug_inspect(
    @wit.tokenize("package local:hello;"),
    content=(
      #|Ok(
      #|  [
      #|    { token_type: Keyword("package"), offset: 0 },
      #|    { token_type: Ident("local"), offset: 8 },
      #|    { token_type: Symbol(":"), offset: 13 },
      #|    { token_type: Ident("hello"), offset: 14 },
      #|    { token_type: Symbol(";"), offset: 19 },
      #|    { token_type: Eof, offset: 20 },
      #|  ],
      #|)
    ),
  )
}
```
