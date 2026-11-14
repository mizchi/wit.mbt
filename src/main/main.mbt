///|
fn main {
  let args = user_arguments()
  if args.length() < 1 {
    println("Usage: wit-resolve <wit-path> [world]")
    @sys.exit(1)
  }
  let path = args[0]
  let world = if args.length() > 1 { Some(args[1]) } else { None }
  let result = match world {
    Some(name) => @wit.resolve_path(path, world=name)
    None => @wit.resolve_path(path)
  }
  match result {
    Ok(input) => {
      let json = input.to_json()
      println(json.stringify(indent=2))
    }
    Err(err) => {
      println("Error: " + err.to_string())
      @sys.exit(1)
    }
  }
}

///|
#cfg(target="js")
fn user_arguments() -> Array[String] {
  @env.args()[2:].to_owned()
}

///|
#cfg(not(target="js"))
fn user_arguments() -> Array[String] {
  @env.args()[1:].to_owned()
}
