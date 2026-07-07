///|
fn join_path(dir : String, entry : String) -> String {
  if dir == "" || dir == "." {
    entry
  } else if dir.has_suffix("/") {
    dir + entry
  } else {
    dir + "/" + entry
  }
}

///|
fn parent_dir(path : String) -> String {
  let chars = path.to_array()
  let mut last_slash = -1
  for i, c in chars {
    if c == '/' {
      last_slash = i
    }
  }
  if last_slash < 0 {
    "."
  } else if last_slash == 0 {
    "/"
  } else {
    String::from_array(chars[:last_slash])
  }
}

///|
fn sort_strings(items : Array[String]) -> Unit {
  let len = items.length()
  if len < 2 {
    return
  }
  for i in 1..<len {
    let key = items[i]
    let mut j = i - 1
    while j >= 0 && items[j].compare(key) > 0 {
      items[j + 1] = items[j]
      j = j - 1
    }
    items[j + 1] = key
  }
}

///|
fn read_dir_raise(dir : String) -> Array[String] raise ParseError {
  @fs.read_dir(dir) catch {
    _ => raise ParseError::Message("read_dir failed: " + dir, 0)
  }
}

///|
fn read_file_raise(path : String) -> String raise ParseError {
  @fs.read_file_to_string(path) catch {
    _ => raise ParseError::Message("read failed: " + path, 0)
  }
}

///|
fn parse_file_raise(path : String) -> WitFile raise ParseError {
  let source = read_file_raise(path)
  parse_wit(source) catch {
    ParseError::Message(msg, offset) =>
      raise ParseError::Message(path + ": " + msg, offset)
  }
}

///|
fn merge_wit_files(
  base : WitFile,
  next : WitFile,
  path : String,
) -> WitFile raise ParseError {
  let pkg = match (base.pkg, next.pkg) {
    (Option::None, Option::None) => Option::None
    (Option::Some(p), Option::None) => Option::Some(p)
    (Option::None, Option::Some(p)) => Option::Some(p)
    (Option::Some(a), Option::Some(b)) =>
      if a == b {
        Option::Some(a)
      } else {
        raise ParseError::Message("package mismatch in " + path, 0)
      }
  }
  let interfaces = base.interfaces
  for iface in next.interfaces {
    interfaces.push(iface)
  }
  let worlds = base.worlds
  for world in next.worlds {
    worlds.push(world)
  }
  { pkg, interfaces, worlds }
}

///|
fn parse_dir_raise(dir : String) -> WitFile raise ParseError {
  let entries = read_dir_raise(dir)
  let files : Array[String] = []
  for entry in entries {
    if entry == "deps" {
      continue
    }
    let path = join_path(dir, entry)
    let is_file = @fs.is_file(path) catch { _ => false }
    if is_file && entry.has_suffix(".wit") {
      files.push(path)
    }
  }
  sort_strings(files)
  if files.length() == 0 {
    raise ParseError::Message("no .wit files in " + dir, 0)
  }
  let mut merged : WitFile? = None
  for path in files {
    let parsed = parse_file_raise(path)
    merged = match merged {
      None => Some(parsed)
      Some(current) => Some(merge_wit_files(current, parsed, path))
    }
  }
  match merged {
    Some(result) => result
    None => raise ParseError::Message("no .wit files in " + dir, 0)
  }
}

///|
fn parse_path_raise(path : String) -> WitFile raise ParseError {
  if !@fs.path_exists(path) {
    raise ParseError::Message("path not found: " + path, 0)
  }
  let is_dir = @fs.is_dir(path) catch { _ => false }
  if is_dir {
    parse_dir_raise(path)
  } else {
    parse_file_raise(path)
  }
}

///|
fn load_deps(wit_dir : String) -> Array[WitFile] raise ParseError {
  let deps_dir = join_path(wit_dir, "deps")
  if !@fs.path_exists(deps_dir) {
    return []
  }
  let is_dir = @fs.is_dir(deps_dir) catch { _ => false }
  if !is_dir {
    return []
  }
  let entries = read_dir_raise(deps_dir)
  let deps : Array[WitFile] = []
  let len = entries.length()
  for i in 0..<len {
    let entry = entries[len - 1 - i]
    let dep_path = join_path(deps_dir, entry)
    let dep_is_dir = @fs.is_dir(dep_path) catch { _ => false }
    if dep_is_dir {
      deps.push(parse_dir_raise(dep_path))
    }
  }
  deps
}

///|
fn find_world_id(
  resolve : Resolve,
  main_pkg : PackageName?,
  main_worlds : Array[World],
  world : String?,
) -> Int raise ParseError {
  let target_name = match world {
    Option::Some(name) => name
    Option::None =>
      if main_worlds.length() > 0 {
        main_worlds[0].name
      } else {
        raise ParseError::Message("no world found in WIT", 0)
      }
  }
  match main_pkg {
    Option::Some(pkg) => {
      let target_pkg = to_rpkg(pkg)
      let mut pkg_id : Int? = Option::None
      for i, item in resolve.packages {
        if item.name == target_pkg {
          pkg_id = Option::Some(i)
          break
        }
      }
      guard pkg_id is Option::Some(pid) else {
        raise ParseError::Message(
          "package not found for world: " + target_name,
          0,
        )
      }
      let pkg_def = resolve.packages[pid]
      match pkg_def.worlds.get(target_name) {
        Option::Some(id) => id
        Option::None =>
          raise ParseError::Message("world not found: " + target_name, 0)
      }
    }
    Option::None =>
      if world is Option::Some(_) {
        for i, item in resolve.worlds {
          if item.name == target_name {
            return i
          }
        }
        raise ParseError::Message("world not found: " + target_name, 0)
      } else {
        if resolve.worlds.length() == 0 {
          raise ParseError::Message("no world found in WIT", 0)
        }
        0
      }
  }
}

///|
fn resolve_path_raise(
  path : String,
  world : String?,
) -> ResolveInput raise ParseError {
  let main_ast = parse_path_raise(path)
  let is_dir = @fs.is_dir(path) catch { _ => false }
  let wit_dir = if is_dir { path } else { parent_dir(path) }
  let deps = load_deps(wit_dir)
  let asts = deps
  asts.push(main_ast)
  let resolve = resolve_asts(asts)
  let world_id = find_world_id(resolve, main_ast.pkg, main_ast.worlds, world)
  { resolve, world_id }
}
