///|
fn type_key(ty : RType) -> String {
  match ty {
    RType::Bool => "bool"
    RType::U8 => "u8"
    RType::U16 => "u16"
    RType::U32 => "u32"
    RType::U64 => "u64"
    RType::S8 => "s8"
    RType::S16 => "s16"
    RType::S32 => "s32"
    RType::S64 => "s64"
    RType::F32 => "f32"
    RType::F64 => "f64"
    RType::Char => "char"
    RType::String_ => "string"
    RType::ErrorContext => "error-context"
    RType::Id(id) => "id:" + id.to_string()
  }
}

///|
fn type_key_option(value : RType?) -> String {
  match value {
    Some(v) => type_key(v)
    None => "none"
  }
}

///|
fn type_kind_key(kind : RTypeKind) -> String {
  let buf = StringBuilder()
  match kind {
    RTypeKind::List(inner) => {
      buf.write_string("list(")
      buf.write_string(type_key(inner))
      buf.write_char(')')
    }
    RTypeKind::FixedLengthList(inner, size) =>
      buf.write_string(
        "fixed-list(" + type_key(inner) + "," + size.to_string() + ")",
      )
    RTypeKind::Map(key, value) =>
      buf.write_string("map(" + type_key(key) + "," + type_key(value) + ")")
    RTypeKind::Option(inner) => {
      buf.write_string("option(")
      buf.write_string(type_key(inner))
      buf.write_char(')')
    }
    RTypeKind::Future(inner) => {
      buf.write_string("future(")
      buf.write_string(type_key_option(inner))
      buf.write_char(')')
    }
    RTypeKind::Stream(inner) => {
      buf.write_string("stream(")
      buf.write_string(type_key_option(inner))
      buf.write_char(')')
    }
    RTypeKind::Result(ok~, err~) => {
      buf.write_string("result(")
      buf.write_string(type_key_option(ok))
      buf.write_char(',')
      buf.write_string(type_key_option(err))
      buf.write_char(')')
    }
    RTypeKind::Tuple(types) => {
      buf.write_string("tuple(")
      for i, ty in types {
        if i > 0 {
          buf.write_char(',')
        }
        buf.write_string(type_key(ty))
      }
      buf.write_char(')')
    }
    RTypeKind::Handle(handle) =>
      match handle {
        RHandleKind::Own(id) => {
          buf.write_string("own(")
          buf.write_string(id.to_string())
          buf.write_char(')')
        }
        RHandleKind::Borrow(id) => {
          buf.write_string("borrow(")
          buf.write_string(id.to_string())
          buf.write_char(')')
        }
      }
    _ => ()
  }
  buf.to_string()
}

///|
priv struct InterfaceBuilder {
  name : String?
  docs : String?
  pkg : Int32?
  types : Map[String, Int32]
  functions : Map[String, RFunction]
}

///|
priv struct Resolver {
  types : Array[RTypeDef]
  iface_builders : Array[InterfaceBuilder]
  worlds : Array[RWorld]
  packages : Array[RPackage]
  package_ids : Map[String, Int32]
  iface_ids : Map[String, Int32]
  anon_type_ids : Map[String, Int32]
  constructor_results : Array[(Int32, RType)]
}

///|
priv struct WorldTypeScope {
  types : Map[String, Int32]
  ambiguous : Map[String, Bool]
}

///|
fn pkg_key(pkg : RPackageName) -> String {
  match pkg.version {
    Some(v) => pkg.ns + ":" + pkg.name + "@" + v
    None => pkg.ns + ":" + pkg.name
  }
}

///|
fn iface_key(pkg_id : Int32?, name : String) -> String {
  match pkg_id {
    Some(id) => id.to_string() + ":" + name
    None => "_" + ":" + name
  }
}

///|
fn Resolver::new() -> Resolver {
  {
    constructor_results: [],
    types: [],
    iface_builders: [],
    worlds: [],
    packages: [],
    package_ids: {},
    iface_ids: {},
    anon_type_ids: {},
  }
}

///|
fn Resolver::ensure_package(self : Resolver, pkg : RPackageName) -> Int32 {
  let key = pkg_key(pkg)
  match self.package_ids.get(key) {
    Some(id) => id
    None => {
      let id = self.packages.length()
      let pkg_def : RPackage = { name: pkg, interfaces: {}, worlds: {}, }
      self.packages.push(pkg_def)
      self.package_ids.set(key, id)
      id
    }
  }
}

///|
fn Resolver::ensure_interface(
  self : Resolver,
  pkg_id : Int32?,
  name : String,
) -> Int32 {
  let key = iface_key(pkg_id, name)
  match self.iface_ids.get(key) {
    Some(id) => id
    None => {
      let id = self.iface_builders.length()
      let builder : InterfaceBuilder = {
        name: Some(name),
        docs: None,
        pkg: pkg_id,
        types: {},
        functions: {},
      }
      self.iface_builders.push(builder)
      self.iface_ids.set(key, id)
      match pkg_id {
        Some(pid) => {
          let pkg = self.packages[pid]
          pkg.interfaces.set(name, id)
        }
        None => ()
      }
      id
    }
  }
}

///|
fn Resolver::new_inline_interface(
  self : Resolver,
  pkg_id : Int32?,
  docs : String?,
) -> Int32 {
  let id = self.iface_builders.length()
  let builder : InterfaceBuilder = {
    name: None,
    docs,
    pkg: pkg_id,
    types: {},
    functions: {},
  }
  self.iface_builders.push(builder)
  id
}

///|
fn to_rpkg(pkg : PackageName) -> RPackageName {
  { ns: pkg.ns, name: pkg.name, version: pkg.version, }
}

///|
fn Resolver::push_type(self : Resolver, type_def : RTypeDef) -> Int32 {
  let id = self.types.length()
  self.types.push(type_def)
  id
}

///|
fn Resolver::intern_type(self : Resolver, kind : RTypeKind) -> Int32 {
  let key = type_kind_key(kind)
  match self.anon_type_ids.get(key) {
    Some(id) => id
    None => {
      let id = self.push_type({
        name: None,
        kind,
        owner: RTypeOwner::None,
        docs: None,
        external_id: None,
      })
      self.anon_type_ids.set(key, id)
      id
    }
  }
}

///|
fn Resolver::ensure_borrow_handle(self : Resolver, res_id : Int32) -> RType {
  let id = self.intern_type(RTypeKind::Handle(RHandleKind::Borrow(res_id)))
  RType::Id(id)
}

///|
fn Resolver::ensure_own_handle(self : Resolver, res_id : Int32) -> RType {
  let id = self.intern_type(RTypeKind::Handle(RHandleKind::Own(res_id)))
  RType::Id(id)
}

///|
fn Resolver::set_type_kind(
  self : Resolver,
  type_id : Int32,
  kind : RTypeKind,
) -> Unit {
  let current = self.types[type_id]
  self.types[type_id] = {
    name: current.name,
    kind,
    owner: current.owner,
    docs: current.docs,
    external_id: current.external_id,
  }
}

///|
fn Resolver::resolve_type_expr(
  self : Resolver,
  iface_id : Int32,
  expr : TypeExpr,
) -> RType raise ParseError {
  match expr {
    Bool => RType::Bool
    U8 => RType::U8
    U16 => RType::U16
    U32 => RType::U32
    U64 => RType::U64
    S8 => RType::S8
    S16 => RType::S16
    S32 => RType::S32
    S64 => RType::S64
    F32 => RType::F32
    F64 => RType::F64
    Char => RType::Char
    String_ => RType::String_
    ErrorContext => RType::ErrorContext
    Id(name) => {
      let iface = self.iface_builders[iface_id]
      match iface.types.get(name) {
        Some(id) =>
          if self.types[id].kind == RTypeKind::Resource {
            self.ensure_own_handle(id)
          } else {
            RType::Id(id)
          }
        None => raise ParseError::Message("unknown type: " + name, 0)
      }
    }
    List(inner) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      let id = self.intern_type(List(inner_ty))
      RType::Id(id)
    }
    FixedLengthList(inner, size) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      RType::Id(self.intern_type(FixedLengthList(inner_ty, size)))
    }
    Map(key, value) => {
      let key_ty = self.resolve_type_expr(iface_id, key)
      let value_ty = self.resolve_type_expr(iface_id, value)
      RType::Id(self.intern_type(Map(key_ty, value_ty)))
    }
    Option(inner) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      let id = self.intern_type(Option(inner_ty))
      RType::Id(id)
    }
    Future(inner) => {
      let inner_ty = match inner {
        Some(inner) => Some(self.resolve_type_expr(iface_id, inner))
        None => None
      }
      let id = self.intern_type(Future(inner_ty))
      RType::Id(id)
    }
    Stream(inner) => {
      let inner_ty = match inner {
        Some(inner) => Some(self.resolve_type_expr(iface_id, inner))
        None => None
      }
      let id = self.intern_type(Stream(inner_ty))
      RType::Id(id)
    }
    Result(ok_ty, err_ty) => {
      let ok : RType? = match ok_ty {
        Some(t) => Some(self.resolve_type_expr(iface_id, t))
        None => None
      }
      let err : RType? = match err_ty {
        Some(e) => Some(self.resolve_type_expr(iface_id, e))
        None => None
      }
      let id = self.intern_type(Result(ok~, err~))
      RType::Id(id)
    }
    Tuple(items) => {
      let types : Array[RType] = []
      for item in items {
        types.push(self.resolve_type_expr(iface_id, item))
      }
      let id = self.intern_type(Tuple(types))
      RType::Id(id)
    }
    Own(name) => {
      let iface = self.iface_builders[iface_id]
      let res_id = match iface.types.get(name) {
        Some(id) => id
        None => raise ParseError::Message("unknown resource: " + name, 0)
      }
      self.ensure_own_handle(res_id)
    }
    Borrow(name) => {
      let iface = self.iface_builders[iface_id]
      let res_id = match iface.types.get(name) {
        Some(id) => id
        None => raise ParseError::Message("unknown resource: " + name, 0)
      }
      self.ensure_borrow_handle(res_id)
    }
  }
}

///|
fn Resolver::resolve_function(
  self : Resolver,
  iface_id : Int32,
  func : Function,
  _kind : RFunctionKind,
) -> RFunction raise ParseError {
  let params : Array[(String, RType)] = []
  for param in func.params {
    let ty = self.resolve_type_expr(iface_id, param.ty)
    params.push((param.name, ty))
  }
  let result = match func.result {
    Some(r) => Some(self.resolve_type_expr(iface_id, r))
    None => None
  }
  {
    name: accessor_prefix(func.kind) + func.name,
    kind: resolved_function_kind(func.kind, 0),
    params,
    result,
    docs: func.docs,
    external_id: func.external_id,
  }
}

///|
fn build_world_type_scope(world_types : Map[String, Int32]) -> WorldTypeScope {
  let scope : WorldTypeScope = { types: {}, ambiguous: {}, }
  for name, type_id in world_types {
    scope.types.set(name, type_id)
  }
  scope
}

///|
fn resolve_world_type(
  scope : WorldTypeScope,
  name : String,
) -> Int32 raise ParseError {
  if scope.ambiguous.contains(name) {
    raise ParseError::Message("ambiguous type: " + name, 0)
  }
  match scope.types.get(name) {
    Some(id) => id
    None => raise ParseError::Message("unknown type: " + name, 0)
  }
}

///|
fn renamed_world_item_name(
  name : String,
  renames : Array[IncludeRename],
) -> String {
  for rename in renames {
    if rename.from == name {
      return rename.to
    }
  }
  name
}

///|
fn merge_included_world_items(
  target : Map[String, RWorldItem],
  source : Map[String, RWorldItem],
  renames : Array[IncludeRename],
) -> Unit raise ParseError {
  for name, item in source {
    let merged_name = renamed_world_item_name(name, renames)
    if target.contains(merged_name) {
      // Interface-id keys denote the same interface and are deduplicated by include.
      if name.has_prefix("interface-") &&
        merged_name == name &&
        target.get(merged_name) == Some(item) {
        continue
      }
      raise ParseError::Message("duplicate world item: " + merged_name, 0)
    }
    target.set(merged_name, item)
  }
}

///|
fn Resolver::find_world_id_in_scope(
  self : Resolver,
  pkg_id : Int32?,
  name : String,
) -> Int32? {
  match pkg_id {
    Some(pid) => self.packages[pid].worlds.get(name)
    None => {
      for world_id, world in self.worlds {
        if world.pkg is None && world.name == name {
          return Some(world_id)
        }
      }
      None
    }
  }
}

///|
fn Resolver::resolve_include_world_id(
  self : Resolver,
  current_pkg_id : Int32?,
  include_decl : IncludeDecl,
) -> Int32 raise ParseError {
  match include_decl.path.pkg {
    Some(pkg) => {
      let pid = self.ensure_package(to_rpkg(pkg))
      match self.packages[pid].worlds.get(include_decl.path.interface) {
        Some(world_id) => world_id
        None =>
          raise ParseError::Message(
            "unknown world: " + include_decl.path.interface,
            0,
          )
      }
    }
    None =>
      match
        self.find_world_id_in_scope(current_pkg_id, include_decl.path.interface) {
        Some(world_id) => world_id
        None =>
          raise ParseError::Message(
            "unknown world: " + include_decl.path.interface,
            0,
          )
      }
  }
}

///|
fn Resolver::resolve_world_resource(
  self : Resolver,
  scope : WorldTypeScope,
  name : String,
) -> Int32 raise ParseError {
  let type_id = resolve_world_type(scope, name)
  let type_def = self.types[type_id]
  match type_def.kind {
    RTypeKind::Resource => type_id
    _ => raise ParseError::Message("unknown resource: " + name, 0)
  }
}

///|
fn Resolver::resolve_type_expr_world(
  self : Resolver,
  scope : WorldTypeScope,
  expr : TypeExpr,
) -> RType raise ParseError {
  match expr {
    Bool => RType::Bool
    U8 => RType::U8
    U16 => RType::U16
    U32 => RType::U32
    U64 => RType::U64
    S8 => RType::S8
    S16 => RType::S16
    S32 => RType::S32
    S64 => RType::S64
    F32 => RType::F32
    F64 => RType::F64
    Char => RType::Char
    String_ => RType::String_
    ErrorContext => RType::ErrorContext
    List(inner) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      let id = self.intern_type(List(inner_ty))
      RType::Id(id)
    }
    FixedLengthList(inner, size) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      RType::Id(self.intern_type(FixedLengthList(inner_ty, size)))
    }
    Map(key, value) => {
      let key_ty = self.resolve_type_expr_world(scope, key)
      let value_ty = self.resolve_type_expr_world(scope, value)
      RType::Id(self.intern_type(Map(key_ty, value_ty)))
    }
    Option(inner) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      let id = self.intern_type(Option(inner_ty))
      RType::Id(id)
    }
    Future(inner) => {
      let inner_ty = match inner {
        Some(inner) => Some(self.resolve_type_expr_world(scope, inner))
        None => None
      }
      let id = self.intern_type(Future(inner_ty))
      RType::Id(id)
    }
    Stream(inner) => {
      let inner_ty = match inner {
        Some(inner) => Some(self.resolve_type_expr_world(scope, inner))
        None => None
      }
      let id = self.intern_type(Stream(inner_ty))
      RType::Id(id)
    }
    Result(ok_ty, err_ty) => {
      let ok : RType? = match ok_ty {
        Some(t) => Some(self.resolve_type_expr_world(scope, t))
        None => None
      }
      let err : RType? = match err_ty {
        Some(e) => Some(self.resolve_type_expr_world(scope, e))
        None => None
      }
      let id = self.intern_type(Result(ok~, err~))
      RType::Id(id)
    }
    Tuple(items) => {
      let types : Array[RType] = []
      for item in items {
        types.push(self.resolve_type_expr_world(scope, item))
      }
      let id = self.intern_type(Tuple(types))
      RType::Id(id)
    }
    Id(name) => {
      let type_id = resolve_world_type(scope, name)
      if self.types[type_id].kind == RTypeKind::Resource {
        self.ensure_own_handle(type_id)
      } else {
        RType::Id(type_id)
      }
    }
    Own(name) => {
      let res_id = self.resolve_world_resource(scope, name)
      self.ensure_own_handle(res_id)
    }
    Borrow(name) => {
      let res_id = self.resolve_world_resource(scope, name)
      self.ensure_borrow_handle(res_id)
    }
  }
}

///|
fn Resolver::resolve_world_function(
  self : Resolver,
  func : Function,
  scope : WorldTypeScope,
) -> RFunction raise ParseError {
  let params : Array[(String, RType)] = []
  for param in func.params {
    let ty = self.resolve_type_expr_world(scope, param.ty)
    params.push((param.name, ty))
  }
  let result = match func.result {
    Some(r) => Some(self.resolve_type_expr_world(scope, r))
    None => None
  }
  {
    name: accessor_prefix(func.kind) + func.name,
    kind: resolved_function_kind(func.kind, 0),
    params,
    result,
    docs: func.docs,
    external_id: func.external_id,
  }
}

///|
fn Resolver::register_interfaces(
  self : Resolver,
  pkg_id : Int32?,
  ifaces : Array[Interface],
) -> Unit {
  for iface in ifaces {
    let iface_id = self.ensure_interface(pkg_id, iface.name)
    self.register_interface_items(iface_id, iface.docs, iface.items)
  }
}

///|
fn Resolver::register_interface_items(
  self : Resolver,
  iface_id : Int32,
  docs : String?,
  items : Array[InterfaceItem],
) -> Unit {
  let builder = self.iface_builders[iface_id]
  match docs {
    Some(text) =>
      self.iface_builders[iface_id] = {
        name: builder.name,
        docs: Some(text),
        pkg: builder.pkg,
        types: builder.types,
        functions: builder.functions,
      }
    None => ()
  }
  let builder = self.iface_builders[iface_id]
  for item in items {
    match item {
      TypeDef(def) => {
        let placeholder : RTypeDef = {
          name: Some(def.name),
          kind: if def.kind is Resource(_) {
            Resource
          } else {
            Alias(RType::Bool)
          },
          owner: RTypeOwner::Interface(iface_id),
          docs: def.docs,
          external_id: def.external_id,
        }
        let type_id = self.push_type(placeholder)
        builder.types.set(def.name, type_id)
      }
      _ => ()
    }
  }
}

///|
fn use_path_string(path : UsePath) -> String {
  match path.pkg {
    Some(pkg) => pkg_key(to_rpkg(pkg)) + "/" + path.interface
    None => path.interface
  }
}

///|
fn Resolver::resolve_use_decl_target_iface_id(
  self : Resolver,
  current_pkg : Int32?,
  from : UsePath,
) -> Int32 raise ParseError {
  let target_pkg = match from.pkg {
    Some(pkg) =>
      match self.package_ids.get(pkg_key(to_rpkg(pkg))) {
        Some(pkg_id) => Some(pkg_id)
        None =>
          raise ParseError::Message(
            "unknown interface: " + use_path_string(from),
            0,
          )
      }
    None => current_pkg
  }
  match self.iface_ids.get(iface_key(target_pkg, from.interface)) {
    Some(id) => id
    None =>
      raise ParseError::Message(
        "unknown interface: " + use_path_string(from),
        0,
      )
  }
}

///|
fn Resolver::apply_use_decls_items(
  self : Resolver,
  iface_id : Int32,
  items : Array[InterfaceItem],
) -> Unit raise ParseError {
  let builder = self.iface_builders[iface_id]
  for item in items {
    match item {
      Use(decl) => {
        let target_id = self.resolve_use_decl_target_iface_id(
          builder.pkg,
          decl.from,
        )
        let target = self.iface_builders[target_id]
        for name in decl.names {
          match target.types.get(name) {
            Some(tid) =>
              builder.types.set(
                renamed_world_item_name(name, decl.renames),
                tid,
              )
            None => raise ParseError::Message("unknown type: " + name, 0)
          }
        }
      }
      _ => ()
    }
  }
}

///|
fn Resolver::apply_use_decls(
  self : Resolver,
  pkg_id : Int32?,
  ifaces : Array[Interface],
  strict~ : Bool = true,
) -> Int32 raise ParseError {
  let mut unresolved = 0
  for iface in ifaces {
    let iface_id = match self.iface_ids.get(iface_key(pkg_id, iface.name)) {
      Some(id) => id
      None => continue
    }
    let builder = self.iface_builders[iface_id]
    for item in iface.items {
      match item {
        Use(decl) => {
          let target_id = self.resolve_use_decl_target_iface_id(
            builder.pkg,
            decl.from,
          )
          let target = self.iface_builders[target_id]
          for name in decl.names {
            match target.types.get(name) {
              Some(tid) =>
                builder.types.set(
                  renamed_world_item_name(name, decl.renames),
                  tid,
                )
              None =>
                if strict {
                  raise ParseError::Message("unknown type: " + name, 0)
                } else {
                  unresolved += 1
                }
            }
          }
        }
        _ => ()
      }
    }
  }
  unresolved
}

///|
fn Resolver::fill_interface(
  self : Resolver,
  iface_id : Int32,
  iface : Interface,
) -> Unit raise ParseError {
  let builder = self.iface_builders[iface_id]
  for item in iface.items {
    match item {
      TypeDef(def) => {
        let type_id = match builder.types.get(def.name) {
          Some(id) => id
          None => raise ParseError::Message("missing type id: " + def.name, 0)
        }
        let kind = match def.kind {
          Record(fields) => {
            let resolved : Array[RRecordField] = []
            for field in fields {
              let ty = self.resolve_type_expr(iface_id, field.ty)
              resolved.push({ name: field.name, field_type: ty, })
            }
            RTypeKind::Record(resolved)
          }
          Enum(cases) => RTypeKind::Enum(cases)
          Flags(flags) => RTypeKind::Flags(flags)
          Variant(cases) => {
            let resolved : Array[RVariantCase] = []
            for case in cases {
              let ty = match case.ty {
                Some(t) => Some(self.resolve_type_expr(iface_id, t))
                None => None
              }
              resolved.push({ name: case.name, case_type: ty, })
            }
            RTypeKind::Variant(resolved)
          }
          Alias(target) => {
            let ty = self.resolve_type_expr(iface_id, target)
            RTypeKind::Alias(ty)
          }
          Resource(res) => {
            let mut has_method = false
            for func in res.funcs {
              match func.kind {
                Method(_)
                | AsyncMethod(_)
                | MethodGetter(_)
                | MethodSetter(_) => {
                  has_method = true
                  break
                }
                _ => ()
              }
            }
            for func in res.funcs {
              match func.kind {
                Constructor(_) => {
                  let params : Array[(String, RType)] = []
                  for param in func.params {
                    let ty = self.resolve_type_expr(iface_id, param.ty)
                    params.push((param.name, ty))
                  }
                  if has_method {
                    ignore(self.ensure_borrow_handle(type_id))
                  }
                  let result = match func.result {
                    Some(expr) => {
                      let ty = self.resolve_type_expr(iface_id, expr)
                      self.constructor_results.push((type_id, ty))
                      Some(ty)
                    }
                    None => Some(self.ensure_own_handle(type_id))
                  }
                  let name = "[constructor]" + def.name
                  let resolved : RFunction = {
                    name,
                    kind: RFunctionKind::Constructor(type_id),
                    params,
                    result,
                    docs: func.docs,
                    external_id: func.external_id,
                  }
                  builder.functions.set(resolved.name, resolved)
                }
                Method(_)
                | AsyncMethod(_)
                | MethodGetter(_)
                | MethodSetter(_) => {
                  let params : Array[(String, RType)] = []
                  let self_ty = self.ensure_borrow_handle(type_id)
                  params.push(("self", self_ty))
                  for param in func.params {
                    let ty = self.resolve_type_expr(iface_id, param.ty)
                    params.push((param.name, ty))
                  }
                  let result = match func.result {
                    Some(r) => Some(self.resolve_type_expr(iface_id, r))
                    None => None
                  }
                  let name = "[method]" +
                    accessor_prefix(func.kind) +
                    def.name +
                    "." +
                    func.name
                  let resolved : RFunction = {
                    name,
                    kind: resolved_function_kind(func.kind, type_id),
                    params,
                    result,
                    docs: func.docs,
                    external_id: func.external_id,
                  }
                  builder.functions.set(resolved.name, resolved)
                }
                Static(_)
                | AsyncStatic(_)
                | StaticGetter(_)
                | StaticSetter(_) => {
                  let params : Array[(String, RType)] = []
                  for param in func.params {
                    let ty = self.resolve_type_expr(iface_id, param.ty)
                    params.push((param.name, ty))
                  }
                  let result = match func.result {
                    Some(r) => Some(self.resolve_type_expr(iface_id, r))
                    None => None
                  }
                  let name = "[static]" +
                    accessor_prefix(func.kind) +
                    def.name +
                    "." +
                    func.name
                  let resolved : RFunction = {
                    name,
                    kind: resolved_function_kind(func.kind, type_id),
                    params,
                    result,
                    docs: func.docs,
                    external_id: func.external_id,
                  }
                  builder.functions.set(resolved.name, resolved)
                }
                Freestanding | AsyncFreestanding | Getter | Setter => {
                  let resolved = self.resolve_function(
                    iface_id,
                    func,
                    RFunctionKind::Method(type_id),
                  )
                  builder.functions.set(resolved.name, resolved)
                }
              }
            }
            RTypeKind::Resource
          }
        }
        self.set_type_kind(type_id, kind)
      }
      Function(func) => {
        let resolved = self.resolve_function(
          iface_id,
          func,
          RFunctionKind::Freestanding,
        )
        builder.functions.set(resolved.name, resolved)
      }
      Use(_) => ()
    }
  }
}

///|
fn Resolver::fill_interfaces(
  self : Resolver,
  pkg_id : Int32?,
  ifaces : Array[Interface],
) -> Unit raise ParseError {
  for iface in ifaces {
    let iface_id = match self.iface_ids.get(iface_key(pkg_id, iface.name)) {
      Some(id) => id
      None => continue
    }
    self.fill_interface(iface_id, iface)
  }
}

///|
fn Resolver::fill_worlds(
  self : Resolver,
  pkg_id : Int32?,
  worlds : Array[World],
) -> Unit raise ParseError {
  for world in worlds {
    let imports : Map[String, RWorldItem] = Map([])
    let exports : Map[String, RWorldItem] = Map([])
    let world_id = self.worlds.length()
    let world_types : Map[String, Int32] = Map([])
    for item in world.imports {
      if item is Use(decl) {
        let target_id = self.resolve_use_decl_target_iface_id(pkg_id, decl.from)
        let target = self.iface_builders[target_id]
        for name in decl.names {
          let local_name = renamed_world_item_name(name, decl.renames)
          if world_types.contains(local_name) {
            raise ParseError::Message("duplicate type: " + local_name, 0)
          }
          let tid = match target.types.get(name) {
            Some(id) => id
            None => raise ParseError::Message("unknown type: " + name, 0)
          }
          world_types.set(local_name, tid)
          imports.set(local_name, Type(tid))
        }
      }
    }
    for def in world.types {
      if world_types.contains(def.name) {
        raise ParseError::Message("duplicate type: " + def.name, 0)
      }
      let placeholder : RTypeDef = {
        name: Some(def.name),
        kind: if def.kind is Resource(_) {
          Resource
        } else {
          Alias(RType::Bool)
        },
        owner: RTypeOwner::World(world_id),
        docs: def.docs,
        external_id: def.external_id,
      }
      let type_id = self.push_type(placeholder)
      world_types.set(def.name, type_id)
      imports.set(def.name, Type(type_id))
    }
    let world_scope = build_world_type_scope(world_types)
    for def in world.types {
      let type_id = match world_types.get(def.name) {
        Some(id) => id
        None => raise ParseError::Message("missing type id: " + def.name, 0)
      }
      let kind = match def.kind {
        Record(fields) => {
          let resolved : Array[RRecordField] = []
          for field in fields {
            let ty = self.resolve_type_expr_world(world_scope, field.ty)
            resolved.push({ name: field.name, field_type: ty, })
          }
          RTypeKind::Record(resolved)
        }
        Enum(cases) => RTypeKind::Enum(cases)
        Flags(flags) => RTypeKind::Flags(flags)
        Variant(cases) => {
          let resolved : Array[RVariantCase] = []
          for case in cases {
            let ty = match case.ty {
              Some(t) => Some(self.resolve_type_expr_world(world_scope, t))
              None => None
            }
            resolved.push({ name: case.name, case_type: ty, })
          }
          RTypeKind::Variant(resolved)
        }
        Alias(target) => {
          let ty = self.resolve_type_expr_world(world_scope, target)
          RTypeKind::Alias(ty)
        }
        Resource(res) => {
          let mut has_method = false
          for func in res.funcs {
            match func.kind {
              Method(_) | AsyncMethod(_) | MethodGetter(_) | MethodSetter(_) => {
                has_method = true
                break
              }
              _ => ()
            }
          }
          for func in res.funcs {
            match func.kind {
              Constructor(_) => {
                let params : Array[(String, RType)] = []
                for param in func.params {
                  let ty = self.resolve_type_expr_world(world_scope, param.ty)
                  params.push((param.name, ty))
                }
                if has_method {
                  ignore(self.ensure_borrow_handle(type_id))
                }
                let result = match func.result {
                  Some(expr) => {
                    let ty = self.resolve_type_expr_world(world_scope, expr)
                    self.constructor_results.push((type_id, ty))
                    Some(ty)
                  }
                  None => Some(self.ensure_own_handle(type_id))
                }
                let name = "[constructor]" + def.name
                let resolved : RFunction = {
                  name,
                  kind: RFunctionKind::Constructor(type_id),
                  params,
                  result,
                  docs: func.docs,
                  external_id: func.external_id,
                }
                imports.set(resolved.name, Function(resolved))
              }
              Method(_) | AsyncMethod(_) | MethodGetter(_) | MethodSetter(_) => {
                let params : Array[(String, RType)] = []
                let self_ty = self.ensure_borrow_handle(type_id)
                params.push(("self", self_ty))
                for param in func.params {
                  let ty = self.resolve_type_expr_world(world_scope, param.ty)
                  params.push((param.name, ty))
                }
                let result = match func.result {
                  Some(r) => Some(self.resolve_type_expr_world(world_scope, r))
                  None => None
                }
                let name = "[method]" +
                  accessor_prefix(func.kind) +
                  def.name +
                  "." +
                  func.name
                let resolved : RFunction = {
                  name,
                  kind: resolved_function_kind(func.kind, type_id),
                  params,
                  result,
                  docs: func.docs,
                  external_id: func.external_id,
                }
                imports.set(resolved.name, Function(resolved))
              }
              Static(_) | AsyncStatic(_) | StaticGetter(_) | StaticSetter(_) => {
                let params : Array[(String, RType)] = []
                for param in func.params {
                  let ty = self.resolve_type_expr_world(world_scope, param.ty)
                  params.push((param.name, ty))
                }
                let result = match func.result {
                  Some(r) => Some(self.resolve_type_expr_world(world_scope, r))
                  None => None
                }
                let name = "[static]" +
                  accessor_prefix(func.kind) +
                  def.name +
                  "." +
                  func.name
                let resolved : RFunction = {
                  name,
                  kind: resolved_function_kind(func.kind, type_id),
                  params,
                  result,
                  docs: func.docs,
                  external_id: func.external_id,
                }
                imports.set(resolved.name, Function(resolved))
              }
              Freestanding | AsyncFreestanding | Getter | Setter => {
                let resolved = self.resolve_world_function(func, world_scope)
                imports.set(resolved.name, Function(resolved))
              }
            }
          }
          RTypeKind::Resource
        }
      }
      self.set_type_kind(type_id, kind)
    }
    for item in world.imports {
      let (item, external_id) = match item {
        External(id, item) => (item, Some(id))
        _ => (item, None)
      }
      match item {
        External(_, _) =>
          raise ParseError::Message("nested external-id annotation", 0)
        Use(_) => ()
        WorldItem::Include(include_decl) => {
          let include_world_id = self.resolve_include_world_id(
            pkg_id, include_decl,
          )
          let include_world = self.worlds[include_world_id]
          merge_included_world_items(
            imports,
            include_world.imports,
            include_decl.renames,
          )
          merge_included_world_items(
            exports,
            include_world.exports,
            include_decl.renames,
          )
        }
        WorldItem::NamedInterface(name, path) => {
          let iface_id = self.resolve_use_decl_target_iface_id(pkg_id, path)
          if imports.contains(name) {
            raise ParseError::Message("duplicate world item: " + name, 0)
          }
          imports.set(name, Interface({ id: iface_id, external_id, }))
        }
        WorldItem::Interface(path) => {
          let iface_id = match path.pkg {
            Some(p) => {
              let pid = self.ensure_package(to_rpkg(p))
              self.ensure_interface(Some(pid), path.interface)
            }
            None => {
              let key = iface_key(pkg_id, path.interface)
              match self.iface_ids.get(key) {
                Some(id) => id
                None =>
                  raise ParseError::Message(
                    "unknown interface: " + path.interface,
                    0,
                  )
              }
            }
          }
          let key = "interface-" + iface_id.to_string()
          imports.set(key, Interface({ id: iface_id, external_id, }))
        }
        WorldItem::InlineInterface(inline) => {
          let iface_id = self.new_inline_interface(pkg_id, inline.docs)
          self.register_interface_items(iface_id, inline.docs, inline.items)
          self.apply_use_decls_items(iface_id, inline.items)
          let iface_ast : Interface = {
            name: inline.name,
            docs: inline.docs,
            items: inline.items,
          }
          self.fill_interface(iface_id, iface_ast)
          imports.set(inline.name, Interface({ id: iface_id, external_id, }))
        }
        WorldItem::Function(func) => {
          let resolved = self.resolve_world_function(func, world_scope)
          imports.set(resolved.name, Function(resolved))
        }
      }
    }
    for item in world.exports {
      let (item, external_id) = match item {
        External(id, item) => (item, Some(id))
        _ => (item, None)
      }
      match item {
        External(_, _) =>
          raise ParseError::Message("nested external-id annotation", 0)
        Use(_) => ()
        WorldItem::NamedInterface(name, path) => {
          let iface_id = self.resolve_use_decl_target_iface_id(pkg_id, path)
          if exports.contains(name) {
            raise ParseError::Message("duplicate world item: " + name, 0)
          }
          exports.set(name, Interface({ id: iface_id, external_id, }))
        }
        WorldItem::Interface(path) => {
          let iface_id = match path.pkg {
            Some(p) => {
              let pid = self.ensure_package(to_rpkg(p))
              self.ensure_interface(Some(pid), path.interface)
            }
            None => {
              let key = iface_key(pkg_id, path.interface)
              match self.iface_ids.get(key) {
                Some(id) => id
                None =>
                  raise ParseError::Message(
                    "unknown interface: " + path.interface,
                    0,
                  )
              }
            }
          }
          let key = "interface-" + iface_id.to_string()
          exports.set(key, Interface({ id: iface_id, external_id, }))
        }
        WorldItem::InlineInterface(inline) => {
          let iface_id = self.new_inline_interface(pkg_id, inline.docs)
          self.register_interface_items(iface_id, inline.docs, inline.items)
          self.apply_use_decls_items(iface_id, inline.items)
          let iface_ast : Interface = {
            name: inline.name,
            docs: inline.docs,
            items: inline.items,
          }
          self.fill_interface(iface_id, iface_ast)
          exports.set(inline.name, Interface({ id: iface_id, external_id, }))
        }
        WorldItem::Function(func) => {
          let resolved = self.resolve_world_function(func, world_scope)
          exports.set(resolved.name, Function(resolved))
        }
        WorldItem::Include(_) =>
          raise ParseError::Message("include is not allowed in exports list", 0)
      }
    }
    let world_def : RWorld = {
      name: world.name,
      docs: world.docs,
      imports,
      exports,
      pkg: pkg_id,
    }
    self.worlds.push(world_def)
    match pkg_id {
      Some(pid) => {
        let pkg = self.packages[pid]
        pkg.worlds.set(world.name, world_id)
      }
      None => ()
    }
  }
}

///|
fn build_interfaces(builders : Array[InterfaceBuilder]) -> Array[RInterface] {
  let result : Array[RInterface] = []
  for builder in builders {
    result.push({
      name: builder.name,
      docs: builder.docs,
      functions: builder.functions,
      types: builder.types,
      pkg: builder.pkg,
    })
  }
  result
}

///|
fn resolve_asts(input_asts : Array[WitFile]) -> Resolve raise ParseError {
  let asts : Array[WitFile] = []
  for ast in input_asts {
    flatten_packages(ast, asts)
  }
  let resolver = Resolver::new()
  let pkg_ids : Array[Int32?] = []
  for ast in asts {
    let pkg_id = match ast.pkg {
      Some(p) => Some(resolver.ensure_package(to_rpkg(p)))
      None => None
    }
    pkg_ids.push(pkg_id)
    resolver.register_interfaces(pkg_id, ast.interfaces)
  }
  // Iteratively resolve use declarations until all are resolved.
  // Use declarations may depend on other use declarations across packages,
  // so we retry until convergence (no more unresolved types).
  let max_iterations = asts.length() + 1
  for round in 0..<max_iterations {
    let mut total_unresolved = 0
    let strict = round == max_iterations - 1
    for i, ast in asts {
      total_unresolved += resolver.apply_use_decls(
        pkg_ids[i],
        ast.interfaces,
        strict~,
      )
    }
    if total_unresolved == 0 {
      break
    }
  }
  for i, ast in asts {
    resolver.fill_interfaces(pkg_ids[i], ast.interfaces)
  }
  let pending : Array[(Int32?, World)] = []
  for i, ast in asts {
    for world in ast.worlds {
      pending.push((pkg_ids[i], world))
    }
  }
  let states = Array::make(pending.length(), 0)
  for i in 0..<pending.length() {
    resolver.fill_world_in_order(pending, states, i)
  }
  validate_resolved_types(resolver.types)
  for (resource, result) in resolver.constructor_results {
    validate_constructor_result(resolver.types, resource, result)
  }
  for builder in resolver.iface_builders {
    validate_accessor_pairs(builder.functions, resolver.types)
  }
  for world in resolver.worlds {
    for items in [world.imports, world.exports] {
      let functions : Map[String, RFunction] = Map([])
      for name, item in items {
        if item is Function(func) {
          functions.set(name, func)
        }
      }
      validate_accessor_pairs(functions, resolver.types)
    }
  }
  let interfaces = build_interfaces(resolver.iface_builders)
  {
    worlds: resolver.worlds,
    interfaces,
    types: resolver.types,
    packages: resolver.packages,
  }
}

///|
fn resolve_ast(ast : WitFile) -> Resolve raise ParseError {
  resolve_asts([ast])
}

///|
fn resolve_wit(source : String) -> Resolve raise ParseError {
  let ast = parse_wit(source)
  resolve_ast(ast)
}

///|
fn flatten_packages(ast : WitFile, asts : Array[WitFile]) -> Unit {
  asts.push(ast)
  for pkg in ast.packages {
    flatten_packages(pkg, asts)
  }
}

///|
fn Resolver::fill_world_in_order(
  self : Resolver,
  pending : Array[(Int32?, World)],
  states : Array[Int32],
  index : Int32,
) -> Unit raise ParseError {
  if states[index] == 2 {
    return
  }
  if states[index] == 1 {
    raise ParseError::Message("cyclic world include", 0)
  }
  states[index] = 1
  let (pkg, world) = pending[index]
  for item in world.imports {
    if item is Include(decl) {
      let target_pkg = match decl.path.pkg {
        Some(p) => self.package_ids.get(pkg_key(to_rpkg(p)))
        None => pkg
      }
      for i, (candidate_pkg, candidate) in pending {
        if candidate_pkg == target_pkg && candidate.name == decl.path.interface {
          self.fill_world_in_order(pending, states, i)
          break
        }
      }
    }
  }
  self.fill_worlds(pkg, [world])
  states[index] = 2
}

///|
fn accessor_prefix(kind : FunctionKind) -> String {
  match kind {
    Getter | MethodGetter(_) | StaticGetter(_) => "[get]"
    Setter | MethodSetter(_) | StaticSetter(_) => "[set]"
    _ => ""
  }
}

///|
fn resolved_function_kind(
  kind : FunctionKind,
  resource : Int32,
) -> RFunctionKind {
  match kind {
    Freestanding => RFunctionKind::Freestanding
    AsyncFreestanding => RFunctionKind::AsyncFreestanding
    Getter => RFunctionKind::Getter
    Setter => RFunctionKind::Setter
    Constructor(_) => RFunctionKind::Constructor(resource)
    Method(_) => RFunctionKind::Method(resource)
    AsyncMethod(_) => RFunctionKind::AsyncMethod(resource)
    MethodGetter(_) => RFunctionKind::MethodGetter(resource)
    MethodSetter(_) => RFunctionKind::MethodSetter(resource)
    Static(_) => RFunctionKind::Static(resource)
    AsyncStatic(_) => RFunctionKind::AsyncStatic(resource)
    StaticGetter(_) => RFunctionKind::StaticGetter(resource)
    StaticSetter(_) => RFunctionKind::StaticSetter(resource)
  }
}
