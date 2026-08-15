///|
fn main {
  let args = @env.args()
  if args.length() < 2 {
    println("Usage: wit-resolve <wit-path> [world]")
    @sys.exit(1)
  }
  let path = args[1]
  let world = if args.length() > 2 { Some(args[2]) } else { None }
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
