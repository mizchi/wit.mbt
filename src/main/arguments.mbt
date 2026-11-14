///|
#warnings("-78")
fn parse_arguments(
  args : Array[String],
) -> Result[(String, String?, @wit.ResolveOptions), String] {
  let positional : Array[String] = []
  let features : Array[String] = []
  let mut all_features = false
  let mut target_version : String? = None
  let mut index = 0
  let mut positional_only = false
  while index < args.length() {
    let arg = args[index]
    if !positional_only && arg == "--" {
      positional_only = true
    } else if !positional_only && arg == "--all-features" {
      all_features = true
    } else if !positional_only &&
      (arg == "--features" || arg == "--target-version") {
      index += 1
      if index >= args.length() {
        return Err("missing value for " + arg)
      }
      if arg == "--features" {
        for feature in args[index].split(",") {
          features.push(feature.to_owned())
        }
      } else {
        target_version = Some(args[index])
      }
    } else if !positional_only && arg.has_prefix("--") {
      return Err("unknown option: " + arg)
    } else {
      positional.push(arg)
    }
    index += 1
  }
  if positional.length() < 1 || positional.length() > 2 {
    return Err(
      "Usage: wit-resolve [--all-features] [--features names] [--target-version version] <wit-path> [world]",
    )
  }
  let options = match target_version {
    Some(version) =>
      @wit.ResolveOptions::new(features~, all_features~, target_version=version)
    None => @wit.ResolveOptions::new(features~, all_features~)
  }
  Ok(
    (
      positional[0],
      if positional.length() == 2 {
        Some(positional[1])
      } else {
        None
      },
      options,
    ),
  )
}
