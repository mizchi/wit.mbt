///|
/// Parse a WIT source string into a `WitFile`.
pub fn parse(source : String) -> Result[WitFile, ParseError] {
  try? parse_wit(source)
}

///|
/// Parse a WIT file or directory into a `WitFile`.
pub fn parse_path(path : String) -> Result[WitFile, ParseError] {
  try? parse_path_raise(path)
}

///|
/// Resolve a WIT source string into a `Resolve`.
pub fn resolve(source : String) -> Result[Resolve, ParseError] {
  try? resolve_wit(source)
}

///|
/// Resolve multiple WIT ASTs into a single `Resolve`.
pub fn resolve_multi(asts : Array[WitFile]) -> Result[Resolve, ParseError] {
  try? resolve_asts(asts)
}

///|
/// Resolve a WIT file or directory (with deps) into a `ResolveInput`.
pub fn resolve_path(
  path : String,
  world? : String,
) -> Result[ResolveInput, ParseError] {
  try? resolve_path_raise(path, world)
}
