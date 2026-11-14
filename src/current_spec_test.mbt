///|
fn alias_kind(resolve : @wit.Resolve, name : String) -> @wit.RTypeKind {
  for def in resolve.types {
    if def.name == Some(name) {
      let mut kind = def.kind
      for _ in 0..<resolve.types.length() {
        match kind {
          @wit.RTypeKind::Alias(@wit.RType::Id(id)) =>
            kind = resolve.types[id].kind
          _ => return kind
        }
      }
      return kind
    }
  }
  abort("missing type: " + name)
}

///|
test "current spec: payloadless async types and result absence" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface types {
      #|  type completion = future;
      #|  type events = stream;
      #|  type outcome = result;
      #|  type failure = result<_, string>;
      #|  type success = result<u32>;
      #|  type context = error-context;
      #|}
    ),
  ).unwrap()
  for
    (name, expected) in [
      ("completion", "{\"future\":null}"),
      ("events", "{\"stream\":null}"),
      ("outcome", "{\"result\":{\"ok\":null,\"err\":null}}"),
      ("failure", "{\"result\":{\"ok\":null,\"err\":\"string\"}}"),
      ("success", "{\"result\":{\"ok\":\"u32\",\"err\":null}}"),
      ("context", "{\"type\":\"error-context\"}"),
    ] {
    @test.assert_eq(alias_kind(resolved, name).to_json(), @json.parse(expected))
  }
}

///|
test "current spec: world async types" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|world app {
      #|  export run: async func(done: future, events: stream, context: error-context) -> result<_, string>;
      #|}
    ),
  ).unwrap()
  match resolved.worlds[0].exports.get("run").unwrap() {
    @wit.RWorldItem::Function(func) =>
      @test.assert_eq(
        func.kind.to_json(),
        @json.parse("\"async-freestanding\""),
      )
    _ => abort("expected function")
  }
}

///|
test "current spec: preserve async function kinds" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface api {
      #|  run: async func();
      #|  resource task {
      #|    constructor();
      #|    poll: async func() -> bool;
      #|    start: static async func();
      #|  }
      #|}
    ),
  ).unwrap()
  let functions = resolved.interfaces[0].functions
  @test.assert_eq(
    functions.get("run").unwrap().kind.to_json(),
    @json.parse("\"async-freestanding\""),
  )
  @test.assert_eq(
    functions.get("[method]task.poll").unwrap().kind.to_json(),
    @json.parse("{\"async-method\":0}"),
  )
  @test.assert_eq(
    functions.get("[static]task.start").unwrap().kind.to_json(),
    @json.parse("{\"async-static\":0}"),
  )
}

///|
test "current spec: ordinary comments do not become documentation" {
  let ast = @wit.parse(
    (
      #|package test:current;
      #|// implementation note
      #|/// Public API.
      #|interface api {
      #|  /* outer /* nested */ comment */
      #|  /// Run the task.
      #|  run: func();
      #|}
    ),
  ).unwrap()
  @test.assert_eq(ast.interfaces[0].docs, Some("Public API."))
  match ast.interfaces[0].items[0] {
    @wit.InterfaceItem::Function(func) =>
      @test.assert_eq(func.docs, Some("Run the task."))
    _ => abort("expected function")
  }
  @test.assert_eq(@wit.parse("/* unterminated") is Err(_), true)
}

///|
test "current spec: fixed length lists and maps" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface api {
      #|  type ipv4 = list<u8, 4>;
      #|  type ipv6 = list<u8, 16>;
      #|  type headers = map<string, list<string>>;
      #|  run: func(ip: list<u8, 4>) -> list<u8, 16>;
      #|}
    ),
  ).unwrap()
  @test.assert_eq(
    alias_kind(resolved, "ipv4").to_json(),
    @json.parse("{\"fixed-length-list\":[\"u8\",4]}"),
  )
  @test.assert_eq(
    alias_kind(resolved, "ipv6").to_json(),
    @json.parse("{\"fixed-length-list\":[\"u8\",16]}"),
  )
  @test.assert_eq(
    @wit.resolve(
      "world w { export f: func(x: map<string, u32>) -> list<u8, 4>; }",
    )
    is Ok(_),
    true,
  )
}

///|
test "current spec: malformed optional and fixed length types" {
  for
    ty in [
      "future<>", "stream<>", "result<_>", "result<u32, _>", "list<u8, -1>", "list<u8, 1.5>",
      "list<u8, 4294967296>",
    ] {
    @test.assert_eq(
      @wit.parse("interface api { type t = " + ty + "; }") is Err(_),
      true,
    )
  }
}

///|
test "current spec: top level use aliases" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|use types as shared;
      #|interface api {
      #|  use shared.{value};
      #|  run: func(v: value);
      #|}
      #|interface types { type value = u32; }
      #|world app { import shared; export api; }
    ),
  ).unwrap()
  @test.assert_eq(resolved.interfaces[0].types.contains("value"), true)
  @test.assert_eq(
    resolved.worlds[0].imports.get("interface-1")
    is Some(@wit.RWorldItem::Interface(_)),
    true,
  )
}

///|
test "current spec: world use and renamed types" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface types { type value = u32; }
      #|interface api {
      #|  use types.{value as input};
      #|  run: func(v: input);
      #|}
      #|world app {
      #|  use types.{value as output};
      #|  export run: func() -> output;
      #|}
    ),
  ).unwrap()
  @test.assert_eq(resolved.interfaces[1].types.contains("input"), true)
  @test.assert_eq(resolved.worlds[0].imports.contains("output"), true)
}

///|
test "current spec: nested packages and namespaces" {
  let resolved = @wit.resolve(
    (
      #|package test:root;
      #|use test:org:dep/nested/types@1.0.0 as shared;
      #|interface api { use shared.{value}; run: func(v: value); }
      #|package test:org:dep/nested@1.0.0 {
      #|  interface types { type value = u32; }
      #|}
    ),
  ).unwrap()
  @test.assert_eq(resolved.packages.length(), 2)
  @test.assert_eq(resolved.packages[1].name.ns, "test:org")
  @test.assert_eq(resolved.packages[1].name.name, "dep/nested")
  @test.assert_eq(resolved.interfaces[0].types.contains("value"), true)
}

///|
test "current spec: includes are independent of declaration order" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|world app { include base; }
      #|world base { export run: func(); }
    ),
  ).unwrap()
  for world in resolved.worlds {
    @test.assert_eq(world.exports.contains("run"), true)
  }
  @test.assert_eq(
    @wit.resolve("world a { include b; } world b { include a; }") is Err(_),
    true,
  )
}

///|
test "current spec: named interface imports and exports" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface store { get: func() -> string; }
      #|world app { import primary: store; import secondary: store; export api: store; }
    ),
  ).unwrap()
  @test.assert_eq(
    resolved.worlds[0].imports.get("primary"),
    resolved.worlds[0].imports.get("secondary"),
  )
  @test.assert_eq(resolved.worlds[0].exports.contains("api"), true)
}

///|
test "current spec: map constraints follow aliases" {
  for
    source in [
      "interface api { type t = map<f32, u32>; }", "interface api { type key = f64; type t = map<key, u32>; }",
      "interface api { resource r; type t = map<string, r>; }", "interface api { type t = map<string, future>; }",
      "interface api { record value { item: stream, } type t = map<string, value>; }",
    ] {
    @test.assert_eq(@wit.resolve(source) is Err(_), true)
  }
}

///|
test "current spec: external ids survive resolution" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface api {
      #|  @external-id("remote.run/1")
      #|  run: func();
      #|  @external-id("remote.task")
      #|  resource task {
      #|    @external-id("remote.poll")
      #|    poll: func();
      #|  }
      #|}
      #|world app {
      #|  @external-id("https://example.com/api")
      #|  import remote: api;
      #|  @external-id("remote.execute")
      #|  export execute: func();
      #|}
    ),
  ).unwrap()
  let api = resolved.interfaces[0]
  @test.assert_eq(
    api.functions.get("run").unwrap().to_json()
    is { "external-id": "remote.run/1", .. },
    true,
  )
  @test.assert_eq(
    api.functions.get("[method]task.poll").unwrap().to_json()
    is { "external-id": "remote.poll", .. },
    true,
  )
  @test.assert_eq(
    resolved.types[0].to_json() is { "external-id": "remote.task", .. },
    true,
  )
  @test.assert_eq(
    resolved.worlds[0].imports.get("remote").unwrap().to_json()
    is { "interface": { "external-id": "https://example.com/api", .. }, .. },
    true,
  )
}

///|
test "current spec: property accessors in interfaces resources and worlds" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface api {
      #|  count: set(value: u32);
      #|  count: get() -> u32;
      #|  resource task {
      #|    status: get() -> string;
      #|    status: set(value: string);
      #|    total: static get() -> u32;
      #|  }
      #|}
      #|world app {
      #|  export count: get() -> u32;
      #|  export count: set(value: u32);
      #|}
    ),
  ).unwrap()
  let functions = resolved.interfaces[0].functions
  for
    name in [
      "[get]count", "[set]count", "[method][get]task.status", "[method][set]task.status",
      "[static][get]task.total",
    ] {
    @test.assert_eq(functions.contains(name), true)
  }
  @test.assert_eq(resolved.worlds[0].exports.contains("[get]count"), true)
  @test.assert_eq(resolved.worlds[0].exports.contains("[set]count"), true)
}

///|
test "current spec: invalid properties and external ids are rejected" {
  for
    source in [
      "interface api { x: get(v: u32) -> u32; }", "interface api { x: get(); }",
      "interface api { x: set(); }", "interface api { x: get() -> u32; x: set(v: string); }",
      "interface api { x: set(v: u32); }", "interface api { x: async get() -> u32; }",
      "@external-id(\"remote\") interface api {}", "interface api { @unknown(x = 1) run: func(); }",
    ] {
    @test.assert_eq(@wit.resolve(source) is Err(_), true)
  }
}

///|
test "current spec: included interface names are deduplicated" {
  let resolved = @wit.resolve(
    (
      #|package test:current;
      #|interface api { run: func(); }
      #|world a { import api; }
      #|world b { import api; }
      #|world combined { include a; include b; }
    ),
  ).unwrap()
  @test.assert_eq(resolved.worlds[2].imports.length(), 1)
  @test.assert_eq(
    @wit.resolve(
      "interface api {} world a { import named: api; } world b { include a; include a; }",
    )
    is Err(_),
    true,
  )
}

///|
test "current spec: kebab identifiers and full semantic versions" {
  for
    source in [
      "package test:pkg@1; interface api {}", "package test:pkg@01.2.3; interface api {}",
      "package test:pkg@1.2.3-01; interface api {}", "package test:pkg@1.2.3+; interface api {}",
      "interface bad_name {}", "interface bad--name {}", "interface mixedCase {}",
      "interface api { type _ = u32; }",
    ] {
    @test.assert_eq(@wit.parse(source) is Err(_), true)
  }
  @test.assert_eq(
    @wit.parse("package test:pkg@1.2.3-rc.1+build.007; interface XML-api {}")
    is Ok(_),
    true,
  )
}

///|
test "current spec: empty and typed async payloads intern separately" {
  let resolved = @wit.resolve(
    (
      #|interface api {
      #|  type empty = future;
      #|  type number = future<u32>;
      #|  type events = stream;
      #|  type bytes = stream<u8>;
      #|}
    ),
  ).unwrap()
  @test.assert_eq(
    alias_kind(resolved, "empty").to_json(),
    @json.parse("{\"future\":null}"),
  )
  @test.assert_eq(
    alias_kind(resolved, "number").to_json(),
    @json.parse("{\"future\":\"u32\"}"),
  )
  @test.assert_eq(
    alias_kind(resolved, "events").to_json(),
    @json.parse("{\"stream\":null}"),
  )
  @test.assert_eq(
    alias_kind(resolved, "bytes").to_json(),
    @json.parse("{\"stream\":\"u8\"}"),
  )
}

///|
test "current spec: fallible resource constructors retain their result" {
  let resolved = @wit.resolve(
    (
      #|interface api {
      #|  resource task {
      #|    constructor() -> result<task, string>;
      #|  }
      #|}
    ),
  ).unwrap()
  let ctor = resolved.interfaces[0].functions.get("[constructor]task").unwrap()
  match ctor.result {
    Some(@wit.RType::Id(id)) =>
      @test.assert_eq(
        resolved.types[id].kind
        is @wit.RTypeKind::Result(ok=Some(_), err=Some(@wit.RType::String_)),
        true,
      )
    _ => abort("constructor must retain its result wrapper")
  }
  for
    source in [
      "interface api { resource task { constructor() -> u32; } }", "interface api { resource task { constructor() -> result<u32, string>; } }",
      "interface api { resource task { constructor() -> result<_, string>; } }",
    ] {
    @test.assert_eq(@wit.resolve(source) is Err(_), true)
  }
}

///|
test "current spec: fallible getter and setter results" {
  let resolved = @wit.resolve(
    (
      #|interface api {
      #|  type value = u32;
      #|  count: get() -> result<value, string>;
      #|  count: set(v: value) -> result<_, string>;
      #|  resource task {
      #|    total: static get() -> result<u64>;
      #|    total: static set(v: u64) -> result;
      #|  }
      #|}
    ),
  ).unwrap()
  @test.assert_eq(
    resolved.interfaces[0].functions.get("[set]count").unwrap().result
    is Some(_),
    true,
  )
  @test.assert_eq(
    @wit.resolve("interface api { x: get() -> u32; x: set(v:u32) -> u32; }")
    is Err(_),
    true,
  )
}
