///|
fn main {
  match parse_arguments(user_arguments()) {
    Err(message) => {
      println(message)
      @sys.exit(1)
    }
    Ok((path, world, options)) => {
      let result = match world {
        Some(name) => @wit.resolve_path(path, world=name, options~)
        None => @wit.resolve_path(path, options~)
      }
      match result {
        Ok(input) => println(input.to_json().stringify(indent=2))
        Err(err) => {
          println("Error: " + err.to_string())
          @sys.exit(1)
        }
      }
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
