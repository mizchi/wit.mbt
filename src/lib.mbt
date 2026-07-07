///|
/// Parse a WIT source string into a `WitFile`.
pub fn parse(source : String) -> Result[WitFile, ParseError] {
  Ok(parse_wit(source)) catch {
    e => Err(e)
  }
}

///|
/// Parse a WIT file or directory into a `WitFile`.
pub fn parse_path(path : String) -> Result[WitFile, ParseError] {
  Ok(parse_path_raise(path)) catch {
    e => Err(e)
  }
}

///|
/// Resolve a WIT source string into a `Resolve`.
pub fn resolve(source : String) -> Result[Resolve, ParseError] {
  Ok(resolve_wit(source)) catch {
    e => Err(e)
  }
}

///|
/// Resolve multiple WIT ASTs into a single `Resolve`.
pub fn resolve_multi(asts : Array[WitFile]) -> Result[Resolve, ParseError] {
  Ok(resolve_asts(asts)) catch {
    e => Err(e)
  }
}

///|
/// Resolve a WIT file or directory (with deps) into a `ResolveInput`.
pub fn resolve_path(
  path : String,
  world? : String,
) -> Result[ResolveInput, ParseError] {
  Ok(resolve_path_raise(path, world)) catch {
    e => Err(e)
  }
}
