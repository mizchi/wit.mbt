///|
fn numeric_version_compare(a : StringView, b : StringView) -> Int32 {
  if a.length() != b.length() {
    return if a.length() < b.length() { -1 } else { 1 }
  }
  string_lex_compare(a.to_owned(), b.to_owned())
}

///|
fn semver_compare(a : String, b : String) -> Int32 {
  let a = a.split_once("+").map(p => p.0).unwrap_or(a[:])
  let b = b.split_once("+").map(p => p.0).unwrap_or(b[:])
  let (ac, ap) = match a.split_once("-") {
    Some((c, p)) => (c, Some(p))
    None => (a, None)
  }
  let (bc, bp) = match b.split_once("-") {
    Some((c, p)) => (c, Some(p))
    None => (b, None)
  }
  let an = ac.split(".").to_array()
  let bn = bc.split(".").to_array()
  for i in 0..<3 {
    let cmp = numeric_version_compare(an[i], bn[i])
    if cmp != 0 {
      return cmp
    }
  }
  match (ap, bp) {
    (None, None) => 0
    (None, Some(_)) => 1
    (Some(_), None) => -1
    (Some(a), Some(b)) => {
      let an = a.split(".").to_array()
      let bn = b.split(".").to_array()
      let n = if an.length() < bn.length() { an.length() } else { bn.length() }
      for i in 0..<n {
        let ad = an[i].iter().all(ch => ch.is_ascii_digit())
        let bd = bn[i].iter().all(ch => ch.is_ascii_digit())
        let cmp = if ad && bd {
          numeric_version_compare(an[i], bn[i])
        } else if ad != bd {
          if ad {
            -1
          } else {
            1
          }
        } else {
          string_lex_compare(an[i].to_owned(), bn[i].to_owned())
        }
        if cmp != 0 {
          return cmp
        }
      }
      if an.length() == bn.length() {
        0
      } else if an.length() < bn.length() {
        -1
      } else {
        1
      }
    }
  }
}

///|
fn validate_attributes(
  attributes : Attributes,
  pkg : PackageName?,
) -> Unit raise ParseError {
  if attributes.since is Some(_) && attributes.unstable is Some(_) {
    raise ParseError::Message("since and unstable are mutually exclusive", 0)
  }
  if attributes.deprecated is Some(_) &&
    attributes.since is None &&
    attributes.unstable is None {
    raise ParseError::Message("deprecated requires since or unstable", 0)
  }
  for version in [attributes.since, attributes.deprecated] {
    if version is Some(version) {
      if !valid_semver(version) {
        raise ParseError::Message("invalid annotation version", 0)
      }
      let current = match pkg {
        Some(pkg) => pkg.version
        None => None
      }
      guard current is Some(current) else {
        raise ParseError::Message(
          "versioned annotation requires package version", 0,
        )
      }
      if semver_compare(version, current) > 0 {
        raise ParseError::Message(
          "annotation references an unreleased version", 0,
        )
      }
    }
  }
  if attributes.since is Some(since) &&
    attributes.deprecated is Some(deprecated) &&
    semver_compare(deprecated, since) < 0 {
    raise ParseError::Message("deprecation precedes introduction", 0)
  }
}

///|
fn attributes_enabled(
  attributes : Attributes,
  options : ResolveOptions,
) -> Bool {
  if attributes.unstable is Some(feature) &&
    !options.all_features &&
    !options.features.contains(feature) {
    return false
  }
  if attributes.since is Some(since) &&
    options.target_version is Some(target) &&
    semver_compare(since, target) > 0 {
    return false
  }
  true
}

///|
fn prepare_function(
  func : Function,
  pkg : PackageName?,
  options : ResolveOptions,
) -> Function? raise ParseError {
  validate_attributes(func.attributes, pkg)
  if attributes_enabled(func.attributes, options) {
    Some(func)
  } else {
    None
  }
}

///|
fn prepare_definition(
  def : TypeDef,
  pkg : PackageName?,
  options : ResolveOptions,
) -> TypeDef? raise ParseError {
  validate_attributes(def.attributes, pkg)
  let def = match def.kind {
    Resource(resource) =>
      {
        ..def,
        kind: Resource({
          funcs: resource.funcs.filter_map(func => {
            prepare_function(func, pkg, options)
          }),
        }),
      }
    _ => def
  }
  if attributes_enabled(def.attributes, options) {
    Some(def)
  } else {
    None
  }
}

///|
fn prepare_interface_items(
  items : Array[InterfaceItem],
  pkg : PackageName?,
  options : ResolveOptions,
) -> Array[InterfaceItem] raise ParseError {
  items.filter_map(item => {
    match item {
      Function(func) =>
        prepare_function(func, pkg, options).map(func => {
          InterfaceItem::Function(func)
        })
      TypeDef(def) =>
        prepare_definition(def, pkg, options).map(def => {
          InterfaceItem::TypeDef(def)
        })
      Use(decl) => {
        validate_attributes(decl.attributes, pkg)
        if attributes_enabled(decl.attributes, options) {
          Some(item)
        } else {
          None
        }
      }
    }
  })
}

///|
fn prepare_world_item(
  item : WorldItem,
  pkg : PackageName?,
  options : ResolveOptions,
) -> WorldItem? raise ParseError {
  match item {
    External(id, item) =>
      prepare_world_item(item, pkg, options).map(item => {
        WorldItem::External(id, item)
      })
    Attributed(attributes, item) => {
      validate_attributes(attributes, pkg)
      let prepared = prepare_world_item(item, pkg, options)
      if attributes_enabled(attributes, options) {
        prepared.map(item => WorldItem::Attributed(attributes, item))
      } else {
        None
      }
    }
    Function(func) =>
      prepare_function(func, pkg, options).map(func => WorldItem::Function(func))
    InlineInterface(iface) =>
      Some(
        InlineInterface({
          ..iface,
          items: prepare_interface_items(iface.items, pkg, options),
        }),
      )
    Use(decl) => {
      validate_attributes(decl.attributes, pkg)
      if attributes_enabled(decl.attributes, options) {
        Some(item)
      } else {
        None
      }
    }
    Include(decl) => {
      validate_attributes(decl.attributes, pkg)
      if attributes_enabled(decl.attributes, options) {
        Some(item)
      } else {
        None
      }
    }
    _ => Some(item)
  }
}

///|
fn prepare_ast(
  ast : WitFile,
  options : ResolveOptions,
) -> WitFile raise ParseError {
  let interfaces = ast.interfaces.filter_map(iface => {
    validate_attributes(iface.attributes, ast.pkg)
    let items = prepare_interface_items(iface.items, ast.pkg, options)
    if attributes_enabled(iface.attributes, options) {
      Some({ ..iface, items, })
    } else {
      None
    }
  })
  let worlds = ast.worlds.filter_map(world => {
    validate_attributes(world.attributes, ast.pkg)
    let types = world.types.filter_map(def => {
      prepare_definition(def, ast.pkg, options)
    })
    let imports = world.imports.filter_map(item => {
      prepare_world_item(item, ast.pkg, options)
    })
    let exports = world.exports.filter_map(item => {
      prepare_world_item(item, ast.pkg, options)
    })
    if attributes_enabled(world.attributes, options) {
      Some({ ..world, types, imports, exports, })
    } else {
      None
    }
  })
  let uses = ast.uses.filter(decl => {
    validate_attributes(decl.attributes, ast.pkg)
    attributes_enabled(decl.attributes, options)
  })
  {
    ..ast,
    interfaces,
    worlds,
    uses,
    packages: ast.packages.map(ast => prepare_ast(ast, options)),
  }
}

///|
fn validate_toplevel_uses(asts : Array[WitFile]) -> Unit raise ParseError {
  let names : Map[String, Bool] = Map([])
  for ast in asts {
    let pkg = match ast.pkg {
      Some(pkg) => pkg_key(to_rpkg(pkg))
      None => ""
    }
    for iface in ast.interfaces {
      names.set(pkg + "/" + iface.name, true)
    }
    for world in ast.worlds {
      names.set(pkg + "/" + world.name, true)
    }
  }
  for ast in asts {
    for decl in ast.uses {
      let pkg = match
        (
          match decl.from.pkg {
            Some(pkg) => Some(pkg)
            None => ast.pkg
          } : PackageName?) {
        Some(pkg) => pkg_key(to_rpkg(pkg))
        None => ""
      }
      if !names.contains(pkg + "/" + decl.from.interface) {
        raise ParseError::Message(
          "unknown top-level use: " + decl.from.interface,
          0,
        )
      }
    }
  }
}
