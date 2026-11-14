///|
test "attributes: unstable APIs are opt in and metadata survives" {
  let source =
    #|package test:gates@1.2.0;
    #|interface api {
    #|  stable:func();
    #|  @unstable(feature=preview)
    #|  preview:func();
    #|  @since(version=1.1.0)
    #|  @deprecated(version=1.2.0)
    #|  old:func();
    #|}
  let ast = @wit.parse(source).unwrap()
  match ast.interfaces[0].items[1] {
    @wit.InterfaceItem::Function(func) =>
      @test.assert_eq(func.attributes.unstable, Some("preview"))
    _ => abort("expected function")
  }
  let stable = @wit.resolve(source).unwrap()
  @test.assert_eq(stable.interfaces[0].functions.contains("preview"), false)
  let enabled = @wit.resolve(
    source,
    options=@wit.ResolveOptions::new(features=["preview"]),
  ).unwrap()
  @test.assert_eq(enabled.interfaces[0].functions.contains("preview"), true)
  @test.assert_eq(
    enabled.interfaces[0].functions.get("old").unwrap().attributes.deprecated,
    Some("1.2.0"),
  )
  let earlier = @wit.resolve(
    source,
    options=@wit.ResolveOptions::new(target_version="1.0.0"),
  ).unwrap()
  @test.assert_eq(earlier.interfaces[0].functions.contains("old"), false)
  let all = @wit.resolve(
    source,
    options=@wit.ResolveOptions::new(all_features=true),
  ).unwrap()
  @test.assert_eq(all.interfaces[0].functions.length(), 3)
}

///|
test "attributes: filtering covers interfaces resources worlds and use" {
  let source =
    #|package test:gates@1.2.0;
    #|@unstable(feature=hidden)
    #|interface hidden { run:func(); }
    #|interface api {
    #|  resource r {
    #|    constructor();
    #|    @unstable(feature=preview)
    #|    preview:func();
    #|  }
    #|}
    #|world app {
    #|  @unstable(feature=hidden)
    #|  import hidden;
    #|  @since(version=1.1.0)
    #|  export new:func();
    #|  export api;
    #|}
  let resolved = @wit.resolve(
    source,
    options=@wit.ResolveOptions::new(target_version="1.0.0"),
  ).unwrap()
  @test.assert_eq(resolved.interfaces.length(), 1)
  @test.assert_eq(
    resolved.interfaces[0].functions.contains("[method]r.preview"),
    false,
  )
  @test.assert_eq(resolved.worlds[0].imports.length(), 0)
  @test.assert_eq(resolved.worlds[0].exports.contains("new"), false)
}

///|
test "attributes: malformed conflicting and unreleased gates fail" {
  for
    source in [
      "package t:p; @since(version=1.0.0) interface api {}", "package t:p@1.0.0; @since(version=2.0.0) interface api {}",
      "package t:p@1.0.0; @since(version=1.0.0) @unstable(feature=x) interface api {}",
      "package t:p@1.0.0; @deprecated(version=1.0.0) interface api {}", "package t:p@1.0.0; @since(nonsense=x) interface api {}",
      "package t:p@1.0.0; @unstable(feature=\"x\") interface api {}",
    ] {
    @test.assert_eq(@wit.resolve(source) is Err(_), true)
  }
}
