///|
test "conformance: retain block documentation and external escapes" {
  let ast = @wit.parse(
    "/** Public API */ interface api { /** Run task */ run:func(); }",
  ).unwrap()
  @test.assert_eq(ast.interfaces[0].docs, Some("Public API"))
  let source =
    #|interface api { @external-id("\u{61}\c3\a9") run:func(); }
  let resolved = @wit.resolve(source).unwrap()
  @test.assert_eq(
    resolved.interfaces[0].functions.get("run").unwrap().external_id,
    Some("aé"),
  )
}

///|
test "conformance: exported interface imports its type dependencies" {
  let source =
    #|package test:transitive;
    #|interface types { record value { n:u32 } }
    #|interface api { use types.{value}; run:func()->value; }
    #|world app { export api; }
  let resolved = @wit.resolve(source).unwrap()
  @test.assert_eq(resolved.worlds[0].imports.contains("interface-0"), true)
}

///|
test "conformance: resource aliases retain resource identity" {
  let source =
    #|interface api {
    #|  run:func(x:borrow<alias>, y:alias)->alias;
    #|  type alias=r;
    #|  resource r;
    #|}
  let resolved = @wit.resolve(source).unwrap()
  let api = resolved.interfaces[0]
  let resource = api.types.get("r").unwrap()
  let alias_id = api.types.get("alias").unwrap()
  match resolved.types[alias_id].kind {
    @wit.RTypeKind::Alias(@wit.RType::Id(id)) => @test.assert_eq(id, resource)
    _ => abort("alias must refer to the resource type")
  }
  let run = api.functions.get("run").unwrap()
  match run.params[0].1 {
    @wit.RType::Id(id) =>
      match resolved.types[id].kind {
        @wit.RTypeKind::Handle(@wit.RHandleKind::Borrow(target)) =>
          @test.assert_eq(target, resource)
        _ => abort("expected borrow")
      }
    _ => abort("expected borrow type id")
  }
  match run.result {
    Some(@wit.RType::Id(id)) =>
      match resolved.types[id].kind {
        @wit.RTypeKind::Handle(@wit.RHandleKind::Own(target)) =>
          @test.assert_eq(target, resource)
        _ => abort("resource values must be owned handles")
      }
    _ => abort("expected own type id")
  }
}
