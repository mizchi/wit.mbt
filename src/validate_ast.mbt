///|
fn define_source_name(
  names : Map[String, Bool],
  name : String,
) -> Unit raise ParseError {
  let key = name.to_lower()
  if names.contains(key) {
    raise ParseError::Message("duplicate name: " + name, 0)
  }
  names.set(key, true)
}

///|
fn source_function_name(func : Function) -> String {
  match func.kind {
    Constructor(name) => "[constructor]" + name
    Method(name)
    | AsyncMethod(name)
    | MethodGetter(name)
    | MethodSetter(name) =>
      "[method]" + accessor_prefix(func.kind) + name + "." + func.name
    Static(name)
    | AsyncStatic(name)
    | StaticGetter(name)
    | StaticSetter(name) =>
      "[static]" + accessor_prefix(func.kind) + name + "." + func.name
    _ => accessor_prefix(func.kind) + func.name
  }
}

///|
fn validate_source_function(func : Function) -> Unit raise ParseError {
  let names : Map[String, Bool] = Map([])
  match func.kind {
    Method(_) | AsyncMethod(_) | MethodGetter(_) | MethodSetter(_) =>
      define_source_name(names, "self")
    _ => ()
  }
  for param in func.params {
    define_source_name(names, param.name)
    validate_source_type(param.ty)
  }
  if func.result is Some(ty) {
    validate_source_type(ty)
  }
}

///|
fn validate_source_type(ty : TypeExpr) -> Unit raise ParseError {
  match ty {
    Tuple(items) => {
      if items.is_empty() {
        raise ParseError::Message("empty tuple", 0)
      }
      for ty in items {
        validate_source_type(ty)
      }
    }
    List(inner) | FixedLengthList(inner, _) | Option(inner) =>
      validate_source_type(inner)
    Future(inner) | Stream(inner) =>
      if inner is Some(ty) {
        validate_source_type(ty)
      }
    Map(key, value) => {
      validate_source_type(key)
      validate_source_type(value)
    }
    Result(ok, err) => {
      if ok is Some(ty) {
        validate_source_type(ty)
      }
      if err is Some(ty) {
        validate_source_type(ty)
      }
    }
    _ => ()
  }
}

///|
fn validate_source_definition(
  def : TypeDef,
  scope : Map[String, Bool],
) -> Unit raise ParseError {
  define_source_name(scope, def.name)
  let names : Map[String, Bool] = Map([])
  match def.kind {
    Record(fields) => {
      if fields.is_empty() {
        raise ParseError::Message("empty record", 0)
      }
      for field in fields {
        define_source_name(names, field.name)
        validate_source_type(field.ty)
      }
    }
    Variant(cases) => {
      if cases.is_empty() {
        raise ParseError::Message("empty variant", 0)
      }
      for case in cases {
        define_source_name(names, case.name)
        if case.ty is Some(ty) {
          validate_source_type(ty)
        }
      }
    }
    Enum(items) | Flags(items) => {
      if items.is_empty() {
        raise ParseError::Message("empty enum/flags", 0)
      }
      for name in items {
        define_source_name(names, name)
      }
    }
    Alias(ty) => validate_source_type(ty)
    Resource(resource) =>
      for func in resource.funcs {
        define_source_name(scope, source_function_name(func))
        validate_source_function(func)
      }
  }
}

///|
fn validate_source_use(
  decl : UseDecl,
  names : Map[String, Bool],
) -> Unit raise ParseError {
  for name in decl.names {
    define_source_name(names, renamed_world_item_name(name, decl.renames))
  }
}

///|
fn validate_source_interface(
  items : Array[InterfaceItem],
) -> Unit raise ParseError {
  let names : Map[String, Bool] = Map([])
  for item in items {
    match item {
      TypeDef(def) => validate_source_definition(def, names)
      Function(func) => {
        define_source_name(names, source_function_name(func))
        validate_source_function(func)
      }
      Use(decl) => validate_source_use(decl, names)
    }
  }
}

///|
fn validate_source_world_item(
  item : WorldItem,
  names : Map[String, Bool],
) -> Unit raise ParseError {
  match item {
    External(_, item) | Attributed(_, item) =>
      validate_source_world_item(item, names)
    Function(func) => {
      define_source_name(names, source_function_name(func))
      validate_source_function(func)
    }
    InlineInterface(iface) => {
      define_source_name(names, iface.name)
      validate_source_interface(iface.items)
    }
    NamedInterface(name, _) => define_source_name(names, name)
    Interface(path) =>
      define_source_name(names, "[interface]" + use_path_string(path))
    Use(decl) => validate_source_use(decl, names)
    Include(_) => ()
  }
}

///|
fn validate_source_asts(asts : Array[WitFile]) -> Unit raise ParseError {
  let top_names : Map[String, Bool] = Map([])
  for ast in asts {
    let pkg = match ast.pkg {
      Some(pkg) => pkg_key(to_rpkg(pkg))
      None => ""
    }
    for iface in ast.interfaces {
      define_source_name(top_names, pkg + "/" + iface.name)
      validate_source_interface(iface.items)
    }
    for world in ast.worlds {
      define_source_name(top_names, pkg + "/" + world.name)
      let imports : Map[String, Bool] = Map([])
      let exports : Map[String, Bool] = Map([])
      for def in world.types {
        validate_source_definition(def, imports)
      }
      for item in world.imports {
        validate_source_world_item(item, imports)
      }
      for item in world.exports {
        validate_source_world_item(item, exports)
      }
    }
  }
}
