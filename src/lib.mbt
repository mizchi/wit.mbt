///|
/// Parse a WIT source string into a `WitFile`.
#warnings("-78")
pub fn parse(source : String) -> Result[WitFile, ParseError] {
  Ok(parse_wit(source)) catch {
    e => Err(e)
  }
}

///|
/// Parse a WIT file or directory into a `WitFile`.
#warnings("-78")
pub fn parse_path(path : String) -> Result[WitFile, ParseError] {
  Ok(parse_path_raise(path)) catch {
    e => Err(e)
  }
}

///|
/// Resolve a WIT source string into a `Resolve`.
#warnings("-78")
pub fn resolve(
  source : String,
  options~ : ResolveOptions = ResolveOptions::new(),
) -> Result[Resolve, ParseError] {
  Ok(resolve_wit(source, options)) catch {
    e => Err(e)
  }
}

///|
/// Resolve multiple WIT ASTs into a single `Resolve`.
#warnings("-78")
pub fn resolve_multi(
  asts : Array[WitFile],
  options~ : ResolveOptions = ResolveOptions::new(),
) -> Result[Resolve, ParseError] {
  Ok(resolve_asts(asts, options)) catch {
    e => Err(e)
  }
}

///|
/// Resolve a WIT file or directory (with deps) into a `ResolveInput`.
#warnings("-78")
pub fn resolve_path(
  path : String,
  world? : String,
  options~ : ResolveOptions = ResolveOptions::new(),
) -> Result[ResolveInput, ParseError] {
  Ok(resolve_path_raise(path, world, options)) catch {
    e => Err(e)
  }
}
