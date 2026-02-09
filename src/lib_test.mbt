///|
fn find_world_by_name(worlds : Array[RWorld], name : String) -> RWorld? {
  for world in worlds {
    if world.name == name {
      return Some(world)
    }
  }
  None
}

///|
test "parse hello" {
  let source = "package local:hello;\n\ninterface greet {\n  greet: func(name: string) -> string;\n}\n\nworld hello {\n  export greet;\n}\n"
  let result = parse(source)
  inspect(
    result,
    content=(
      #|Ok({pkg: Some({ns: "local", name: "hello", version: None}), interfaces: [{name: "greet", docs: None, items: [Function({name: "greet", kind: Freestanding, params: [{name: "name", ty: String_}], result: Some(String_), docs: None})]}], worlds: [{name: "hello", docs: None, types: [], imports: [], exports: [Interface({pkg: None, interface: "greet"})]}]})
    ),
  )
}

///|
test "parse complex types" {
  let source = "package my:complex;\n\ninterface types {\n  record point {\n    x: s32,\n    y: s32,\n  }\n\n  variant shape {\n    circle(s32),\n    rectangle(point),\n    none,\n  }\n\n  greet: func(name: string) -> string;\n  add-points: func(a: point, b: point) -> point;\n  area: func(s: shape) -> option<s32>;\n  parse-int: func(s: string) -> result<s32, string>;\n  get-items: func() -> list<point>;\n}\n\nworld example {\n  export types;\n}\n"
  let result = parse(source)
  inspect(
    result,
    content=(
      #|Ok({pkg: Some({ns: "my", name: "complex", version: None}), interfaces: [{name: "types", docs: None, items: [TypeDef({name: "point", kind: Record([{name: "x", ty: S32}, {name: "y", ty: S32}]), docs: None}), TypeDef({name: "shape", kind: Variant([{name: "circle", ty: Some(S32)}, {name: "rectangle", ty: Some(Id("point"))}, {name: "none", ty: None}]), docs: None}), Function({name: "greet", kind: Freestanding, params: [{name: "name", ty: String_}], result: Some(String_), docs: None}), Function({name: "add-points", kind: Freestanding, params: [{name: "a", ty: Id("point")}, {name: "b", ty: Id("point")}], result: Some(Id("point")), docs: None}), Function({name: "area", kind: Freestanding, params: [{name: "s", ty: Id("shape")}], result: Some(Option(S32)), docs: None}), Function({name: "parse-int", kind: Freestanding, params: [{name: "s", ty: String_}], result: Some(Result(S32, Some(String_))), docs: None}), Function({name: "get-items", kind: Freestanding, params: [], result: Some(List(Id("point"))), docs: None})]}], worlds: [{name: "example", docs: None, types: [], imports: [], exports: [Interface({pkg: None, interface: "types"})]}]})
    ),
  )
}

///|
test "parse resource" {
  let source = "package local:resource-test;\n\ninterface blob-store {\n  resource blob {\n    constructor(data: list<u8>);\n    size: func() -> u32;\n    read: func(offset: u32, len: u32) -> list<u8>;\n    write: func(offset: u32, data: list<u8>);\n  }\n\n  create-blob: func(data: list<u8>) -> own<blob>;\n  get-blob-size: func(b: borrow<blob>) -> u32;\n  consume-blob: func(b: own<blob>) -> list<u8>;\n}\n\nworld resource-world {\n  export blob-store;\n}\n"
  let result = parse(source)
  inspect(
    result,
    content=(
      #|Ok({pkg: Some({ns: "local", name: "resource-test", version: None}), interfaces: [{name: "blob-store", docs: None, items: [TypeDef({name: "blob", kind: Resource({funcs: [{name: "constructor", kind: Constructor("blob"), params: [{name: "data", ty: List(U8)}], result: None, docs: None}, {name: "size", kind: Method("blob"), params: [], result: Some(U32), docs: None}, {name: "read", kind: Method("blob"), params: [{name: "offset", ty: U32}, {name: "len", ty: U32}], result: Some(List(U8)), docs: None}, {name: "write", kind: Method("blob"), params: [{name: "offset", ty: U32}, {name: "data", ty: List(U8)}], result: None, docs: None}]}), docs: None}), Function({name: "create-blob", kind: Freestanding, params: [{name: "data", ty: List(U8)}], result: Some(Own("blob")), docs: None}), Function({name: "get-blob-size", kind: Freestanding, params: [{name: "b", ty: Borrow("blob")}], result: Some(U32), docs: None}), Function({name: "consume-blob", kind: Freestanding, params: [{name: "b", ty: Own("blob")}], result: Some(List(U8)), docs: None})]}], worlds: [{name: "resource-world", docs: None, types: [], imports: [], exports: [Interface({pkg: None, interface: "blob-store"})]}]})
    ),
  )
}

///|
test "parse world imports" {
  let source = "package example:app;\n\ninterface api {\n  calc-add: func(a: s32, b: s32) -> s32;\n}\n\nworld app {\n  import example:math/operations;\n  import example:strings/utils;\n  export api;\n}\n"
  let result = parse(source)
  inspect(
    result,
    content=(
      #|Ok({pkg: Some({ns: "example", name: "app", version: None}), interfaces: [{name: "api", docs: None, items: [Function({name: "calc-add", kind: Freestanding, params: [{name: "a", ty: S32}, {name: "b", ty: S32}], result: Some(S32), docs: None})]}], worlds: [{name: "app", docs: None, types: [], imports: [Interface({pkg: Some({ns: "example", name: "math", version: None}), interface: "operations"}), Interface({pkg: Some({ns: "example", name: "strings", version: None}), interface: "utils"})], exports: [Interface({pkg: None, interface: "api"})]}]})
    ),
  )
}

///|
test "parse async function in interface" {
  let source = "package wasi:http;\n\ninterface client {\n  send: async func(request: string) -> result<string, string>;\n}\n"
  let result = parse(source)
  match result {
    Ok(wit_file) => {
      assert_eq(wit_file.interfaces.length(), 1)
      let iface = wit_file.interfaces[0]
      assert_eq(iface.name, "client")
      let mut found_send = false
      for item in iface.items {
        match item {
          InterfaceItem::Function(func) =>
            if func.name == "send" {
              found_send = true
              assert_eq(func.params.length(), 1)
              assert_eq(func.params[0].name, "request")
            }
          _ => ()
        }
      }
      assert_true(found_send)
    }
    Err(err) => abort("expected parse success, got: " + err.to_string())
  }
}

///|
test "resolve async function in world export" {
  let source = "package wasi:http;\n\nworld service {\n  export handle: async func() -> result<string, string>;\n}\n"
  let result = resolve(source)
  match result {
    Ok(resolved) => {
      assert_eq(resolved.worlds.length(), 1)
      let world = resolved.worlds[0]
      assert_true(world.exports.contains("handle"))
    }
    Err(err) => abort("expected resolve success, got: " + err.to_string())
  }
}

///|
test "parse prerelease package version" {
  let source = "package wasi:http@0.3.0-rc-2026-02-05;\n\ninterface ping {\n  ping: func();\n}\n"
  let result = parse(source)
  match result {
    Ok(wit_file) =>
      match wit_file.pkg {
        Some(pkg) => {
          assert_eq(pkg.ns, "wasi")
          assert_eq(pkg.name, "http")
          assert_eq(pkg.version, Some("0.3.0-rc-2026-02-05"))
        }
        None => abort("expected package declaration")
      }
    Err(err) => abort("expected parse success, got: " + err.to_string())
  }
}

///|
test "parse gates and includes in world" {
  let source = "package wasi:http@0.3.0-rc-2026-02-05;\n\n@since(version = 0.3.0-rc-2026-02-05)\nworld service {\n  @since(version = 0.3.0-rc-2026-02-05)\n  include wasi:clocks/imports@0.3.0-rc-2026-02-05;\n  include wasi:clocks/imports@0.3.0-rc-2026-02-05 with { monotonic-clock as clocks-monotonic-clock };\n  @since(version = 0.3.0-rc-2026-02-05)\n  import wasi:cli/stdout@0.3.0-rc-2026-02-05;\n  export handler: interface {\n    handle: async func();\n  }\n}\n"
  let result = parse(source)
  match result {
    Ok(wit_file) => {
      assert_eq(wit_file.worlds.length(), 1)
      let world = wit_file.worlds[0]
      assert_eq(world.name, "service")
      assert_eq(world.imports.length(), 3)
      let mut has_stdout_import = false
      for item in world.imports {
        match item {
          WorldItem::Interface(path) =>
            if path.interface == "stdout" {
              has_stdout_import = true
              match path.pkg {
                Some(pkg) => {
                  assert_eq(pkg.ns, "wasi")
                  assert_eq(pkg.name, "cli")
                  assert_eq(pkg.version, Some("0.3.0-rc-2026-02-05"))
                }
                None => abort("expected package-qualified use path")
              }
            }
          _ => ()
        }
      }
      assert_true(has_stdout_import)
      assert_eq(world.exports.length(), 1)
      match world.exports[0] {
        WorldItem::InlineInterface(inline) => {
          assert_eq(inline.name, "handler")
          let mut has_handle = false
          for item in inline.items {
            match item {
              InterfaceItem::Function(func) =>
                if func.name == "handle" {
                  has_handle = true
                }
              _ => ()
            }
          }
          assert_true(has_handle)
        }
        _ => abort("expected inline handler export")
      }
    }
    Err(err) => abort("expected parse success, got: " + err.to_string())
  }
}

///|
test "resolve world with gate/include syntax" {
  let source = "package wasi:http@0.3.0-rc-2026-02-05;\n\n@since(version = 0.3.0-rc-2026-02-05)\nworld base {\n  import ping: func() -> u32;\n}\n\n@since(version = 0.3.0-rc-2026-02-05)\nworld service {\n  include base;\n  import pong: func() -> u32;\n}\n"
  let result = resolve(source)
  match result {
    Ok(resolved) => {
      let world = match find_world_by_name(resolved.worlds, "service") {
        Some(found) => found
        None => abort("missing world: service")
      }
      assert_true(world.imports.contains("ping"))
      assert_true(world.imports.contains("pong"))
    }
    Err(err) => abort("expected resolve success, got: " + err.to_string())
  }
}

///|
test "resolve include merges imports and exports" {
  let source = "package local:inc;\n\nworld base {\n  import ping: func() -> u32;\n  export pong: func() -> u32;\n}\n\nworld derived {\n  include base;\n}\n"
  let result = resolve(source)
  match result {
    Ok(resolved) => {
      let derived = match find_world_by_name(resolved.worlds, "derived") {
        Some(world) => world
        None => abort("missing world: derived")
      }
      assert_true(derived.imports.contains("ping"))
      assert_true(derived.exports.contains("pong"))
    }
    Err(err) => abort("expected resolve success, got: " + err.to_string())
  }
}

///|
test "resolve include with rename remaps names" {
  let source = "package local:inc;\n\nworld base {\n  import ping: func() -> u32;\n  export pong: func() -> u32;\n}\n\nworld renamed {\n  include base with { ping as ping-renamed, pong as pong-renamed };\n}\n"
  let result = resolve(source)
  match result {
    Ok(resolved) => {
      let renamed = match find_world_by_name(resolved.worlds, "renamed") {
        Some(world) => world
        None => abort("missing world: renamed")
      }
      assert_true(renamed.imports.contains("ping-renamed"))
      assert_true(renamed.exports.contains("pong-renamed"))
      assert_true(not(renamed.imports.contains("ping")))
      assert_true(not(renamed.exports.contains("pong")))
    }
    Err(err) => abort("expected resolve success, got: " + err.to_string())
  }
}

///|
test "resolve hello" {
  let source = "package local:hello;\n\ninterface greet {\n  greet: func(name: string) -> string;\n}\n\nworld hello {\n  export greet;\n}\n"
  let result = resolve(source)
  inspect(
    result,
    content=(
      #|Ok({worlds: [{name: "hello", docs: None, imports: {}, exports: {"interface-0": Interface({id: 0})}, pkg: Some(0)}], interfaces: [{name: Some("greet"), docs: None, functions: {"greet": {name: "greet", kind: Freestanding, params: [("name", String_)], result: Some(String_), docs: None}}, types: {}, pkg: Some(0)}], types: [], packages: [{name: {ns: "local", name: "hello", version: None}, interfaces: {"greet": 0}, worlds: {"hello": 0}}]})
    ),
  )
}

///|
test "resolve resource" {
  let source = "package local:resource-test;\n\ninterface blob-store {\n  resource blob {\n    constructor(data: list<u8>);\n    size: func() -> u32;\n  }\n\n  create-blob: func(data: list<u8>) -> own<blob>;\n}\n\nworld resource-world {\n  export blob-store;\n}\n"
  let result = resolve(source)
  inspect(
    result,
    content=(
      #|Ok({worlds: [{name: "resource-world", docs: None, imports: {}, exports: {"interface-0": Interface({id: 0})}, pkg: Some(0)}], interfaces: [{name: Some("blob-store"), docs: None, functions: {"[constructor]blob": {name: "[constructor]blob", kind: Constructor(0), params: [("data", Id(1))], result: Some(Id(3)), docs: None}, "[method]blob.size": {name: "[method]blob.size", kind: Method(0), params: [("self", Id(2))], result: Some(U32), docs: None}, "create-blob": {name: "create-blob", kind: Freestanding, params: [("data", Id(1))], result: Some(Id(3)), docs: None}}, types: {"blob": 0}, pkg: Some(0)}], types: [{name: Some("blob"), kind: Resource, owner: Interface(0), docs: None}, {name: None, kind: List(U8), owner: None, docs: None}, {name: None, kind: Handle(Borrow(0)), owner: None, docs: None}, {name: None, kind: Handle(Own(0)), owner: None, docs: None}], packages: [{name: {ns: "local", name: "resource-test", version: None}, interfaces: {"blob-store": 0}, worlds: {"resource-world": 0}}]})
    ),
  )
}

///|
test "resolve world function types" {
  let source = "package local:world-func;\n\nworld app {\n  record point {\n    x: s32,\n    y: s32,\n  }\n\n  resource blob {\n    constructor(data: list<u8>);\n    size: func() -> u32;\n  }\n\n  export use-point: func(p: point) -> point;\n  export take-borrow: func(b: borrow<blob>) -> u32;\n  export make-own: func() -> own<blob>;\n}\n"
  let result = resolve(source)
  inspect(
    result,
    content=(
      #|Ok({worlds: [{name: "app", docs: None, imports: {"point": Type(0), "blob": Type(1), "[constructor]blob": Function({name: "[constructor]blob", kind: Constructor(1), params: [("data", Id(2))], result: Some(Id(4)), docs: None}), "[method]blob.size": Function({name: "[method]blob.size", kind: Method(1), params: [("self", Id(3))], result: Some(U32), docs: None})}, exports: {"use-point": Function({name: "use-point", kind: Freestanding, params: [("p", Id(0))], result: Some(Id(0)), docs: None}), "take-borrow": Function({name: "take-borrow", kind: Freestanding, params: [("b", Id(3))], result: Some(U32), docs: None}), "make-own": Function({name: "make-own", kind: Freestanding, params: [], result: Some(Id(4)), docs: None})}, pkg: Some(0)}], interfaces: [], types: [{name: Some("point"), kind: Record([{name: "x", field_type: S32}, {name: "y", field_type: S32}]), owner: World(0), docs: None}, {name: Some("blob"), kind: Resource, owner: World(0), docs: None}, {name: None, kind: List(U8), owner: None, docs: None}, {name: None, kind: Handle(Borrow(1)), owner: None, docs: None}, {name: None, kind: Handle(Own(1)), owner: None, docs: None}], packages: [{name: {ns: "local", name: "world-func", version: None}, interfaces: {}, worlds: {"app": 0}}]})
    ),
  )
}

///|
test "resolve world inline interface" {
  let source = "package local:inline;\n\nworld app {\n  import foo: interface {\n    foo: func(x: s32) -> s32;\n  }\n\n  export bar: interface {\n    bar: func(s: string);\n  }\n}\n"
  let result = resolve(source)
  inspect(
    result,
    content=(
      #|Ok({worlds: [{name: "app", docs: None, imports: {"foo": Interface({id: 0})}, exports: {"bar": Interface({id: 1})}, pkg: Some(0)}], interfaces: [{name: None, docs: None, functions: {"foo": {name: "foo", kind: Freestanding, params: [("x", S32)], result: Some(S32), docs: None}}, types: {}, pkg: Some(0)}, {name: None, docs: None, functions: {"bar": {name: "bar", kind: Freestanding, params: [("s", String_)], result: None, docs: None}}, types: {}, pkg: Some(0)}], types: [], packages: [{name: {ns: "local", name: "inline", version: None}, interfaces: {}, worlds: {"app": 0}}]})
    ),
  )
}

///|
test "tokenize basic" {
  let result = tokenize("package local:hello;")
  inspect(
    result,
    content=(
      #|Ok([{token_type: Keyword("package"), offset: 0}, {token_type: Ident("local"), offset: 8}, {token_type: Symbol(":"), offset: 13}, {token_type: Ident("hello"), offset: 14}, {token_type: Symbol(";"), offset: 19}, {token_type: Eof, offset: 20}])
    ),
  )
}
