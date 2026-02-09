///|
/// Resolve type reference
pub enum RType {
  Bool
  U8
  U16
  U32
  U64
  S8
  S16
  S32
  S64
  F32
  F64
  Char
  String_
  Id(Int)
} derive(Show, Eq)

///|
/// Function kind
pub enum RFunctionKind {
  Freestanding
  Constructor(Int)
  Method(Int)
  Static(Int)
} derive(Show, Eq)

///|
/// Function definition
pub struct RFunction {
  name : String
  kind : RFunctionKind
  params : Array[(String, RType)]
  result : RType?
  docs : String?
} derive(Show, Eq)

///|
/// World item
pub enum RWorldItem {
  Interface(RInterfaceRef)
  Function(RFunction)
  Type(Int)
} derive(Show, Eq)

///|
pub struct RInterfaceRef {
  id : Int
} derive(Show, Eq)

///|
pub struct RInterface {
  name : String?
  docs : String?
  functions : Map[String, RFunction]
  types : Map[String, Int]
  pkg : Int?
} derive(Show, Eq)

///|
pub struct RWorld {
  name : String
  docs : String?
  imports : Map[String, RWorldItem]
  exports : Map[String, RWorldItem]
  pkg : Int?
} derive(Show, Eq)

///|
pub struct RPackageName {
  ns : String
  name : String
  version : String?
} derive(Show, Eq)

///|
pub struct RPackage {
  name : RPackageName
  interfaces : Map[String, Int]
  worlds : Map[String, Int]
} derive(Show, Eq)

///|
pub enum RTypeOwner {
  Interface(Int)
  World(Int)
  None
} derive(Show, Eq)

///|
pub struct RRecordField {
  name : String
  field_type : RType
} derive(Show, Eq)

///|
pub struct RVariantCase {
  name : String
  case_type : RType?
} derive(Show, Eq)

///|
pub enum RHandleKind {
  Own(Int)
  Borrow(Int)
} derive(Show, Eq)

///|
pub enum RTypeKind {
  Record(Array[RRecordField])
  Variant(Array[RVariantCase])
  List(RType)
  Option(RType)
  Future(RType)
  Stream(RType)
  Result(ok~ : RType?, err~ : RType?)
  Tuple(Array[RType])
  Flags(Array[String])
  Enum(Array[String])
  Alias(RType)
  Resource
  Handle(RHandleKind)
} derive(Show, Eq)

///|
pub struct RTypeDef {
  name : String?
  kind : RTypeKind
  owner : RTypeOwner
  docs : String?
} derive(Show, Eq)

///|
pub struct Resolve {
  worlds : Array[RWorld]
  interfaces : Array[RInterface]
  types : Array[RTypeDef]
  packages : Array[RPackage]
} derive(Show, Eq)

///|
pub struct ResolveInput {
  resolve : Resolve
  world_id : Int
} derive(Show, Eq)

///|
fn json_number(value : Int) -> Json {
  Json::number(value.to_double())
}

///|
fn json_string(value : String) -> Json {
  Json::string(value)
}

///|
fn[T : ToJson] json_option(value : T?) -> Json {
  match value {
    Option::Some(v) => v.to_json()
    Option::None => Json::null()
  }
}

///|
fn json_docs(contents : String) -> Json {
  Json::object({ "contents": json_string(contents) })
}

///|
fn package_name_string(pkg : RPackageName) -> String {
  match pkg.version {
    Option::Some(v) => pkg.ns + ":" + pkg.name + "@" + v
    Option::None => pkg.ns + ":" + pkg.name
  }
}

///|
fn sort_strings_for_json(items : Array[String]) -> Unit {
  let len = items.length()
  if len < 2 {
    return
  }
  for i in 1..<len {
    let key = items[i]
    let mut j = i - 1
    while j >= 0 && string_lex_compare(items[j], key) > 0 {
      items[j + 1] = items[j]
      j = j - 1
    }
    items[j + 1] = key
  }
}

///|
fn string_lex_compare(a : String, b : String) -> Int {
  let a_chars = a.to_array()
  let b_chars = b.to_array()
  let a_len = a_chars.length()
  let b_len = b_chars.length()
  let min_len = if a_len < b_len { a_len } else { b_len }
  for i in 0..<min_len {
    let cmp = a_chars[i].compare(b_chars[i])
    if cmp != 0 {
      return cmp
    }
  }
  if a_len < b_len {
    -1
  } else if a_len > b_len {
    1
  } else {
    0
  }
}

///|
fn[T : ToJson] map_sorted_to_json(items : Map[String, T]) -> Json {
  let keys : Array[String] = []
  for key, _ in items {
    keys.push(key)
  }
  sort_strings_for_json(keys)
  let result : Map[String, Json] = {}
  for key in keys {
    match items.get(key) {
      Option::Some(value) => result.set(key, value.to_json())
      Option::None => ()
    }
  }
  Json::object(result)
}

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
  let buf = StringBuilder::new()
  match kind {
    RTypeKind::List(inner) => {
      buf.write_string("list(")
      buf.write_string(type_key(inner))
      buf.write_char(')')
    }
    RTypeKind::Option(inner) => {
      buf.write_string("option(")
      buf.write_string(type_key(inner))
      buf.write_char(')')
    }
    RTypeKind::Future(inner) => {
      buf.write_string("future(")
      buf.write_string(type_key(inner))
      buf.write_char(')')
    }
    RTypeKind::Stream(inner) => {
      buf.write_string("stream(")
      buf.write_string(type_key(inner))
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
pub impl ToJson for RType with to_json(self) {
  match self {
    RType::Bool => json_string("bool")
    RType::U8 => json_string("u8")
    RType::U16 => json_string("u16")
    RType::U32 => json_string("u32")
    RType::U64 => json_string("u64")
    RType::S8 => json_string("s8")
    RType::S16 => json_string("s16")
    RType::S32 => json_string("s32")
    RType::S64 => json_string("s64")
    RType::F32 => json_string("f32")
    RType::F64 => json_string("f64")
    RType::Char => json_string("char")
    RType::String_ => json_string("string")
    RType::Id(id) => json_number(id)
  }
}

///|
pub impl ToJson for RFunctionKind with to_json(self) {
  match self {
    RFunctionKind::Freestanding => json_string("freestanding")
    RFunctionKind::Constructor(id) =>
      Json::object({ "constructor": json_number(id) })
    RFunctionKind::Method(id) => Json::object({ "method": json_number(id) })
    RFunctionKind::Static(id) => Json::object({ "static": json_number(id) })
  }
}

///|
pub impl ToJson for RFunction with to_json(self) {
  let params_json : Array[Json] = []
  for item in self.params {
    let (name, ty) = item
    params_json.push(
      Json::object({ "name": json_string(name), "type": ty.to_json() }),
    )
  }
  let obj : Map[String, Json] = {}
  match self.docs {
    Some(text) => obj.set("docs", json_docs(text))
    None => ()
  }
  obj.set("kind", self.kind.to_json())
  obj.set("name", json_string(self.name))
  obj.set("params", Json::array(params_json))
  match self.result {
    Some(result) => obj.set("result", result.to_json())
    None => ()
  }
  Json::object(obj)
}

///|
fn world_items_to_json(items : Map[String, RWorldItem]) -> Json {
  let result : Map[String, Json] = {}
  for name, item in items {
    match item {
      RWorldItem::Interface(iface_ref) =>
        result.set(name, Json::object({ "interface": iface_ref.to_json() }))
      RWorldItem::Function(func) =>
        result.set(name, Json::object({ "function": func.to_json() }))
      RWorldItem::Type(id) =>
        result.set(name, Json::object({ "type": json_number(id) }))
    }
  }
  map_sorted_to_json(result)
}

///|
pub impl ToJson for RWorldItem with to_json(self) {
  match self {
    RWorldItem::Interface(iface_ref) =>
      Json::object({ "interface": iface_ref.to_json() })
    RWorldItem::Function(func) => Json::object({ "function": func.to_json() })
    RWorldItem::Type(id) => Json::object({ "type": json_number(id) })
  }
}

///|
pub impl ToJson for RInterfaceRef with to_json(self) {
  Json::object({ "id": json_number(self.id) })
}

///|
pub impl ToJson for RInterface with to_json(self) {
  let obj : Map[String, Json] = {}
  match self.docs {
    Some(text) => obj.set("docs", json_docs(text))
    None => ()
  }
  obj.set("functions", map_sorted_to_json(self.functions))
  obj.set("name", json_option(self.name))
  obj.set("package", json_option(self.pkg))
  obj.set("types", map_sorted_to_json(self.types))
  Json::object(obj)
}

///|
pub impl ToJson for RWorld with to_json(self) {
  let obj : Map[String, Json] = {}
  match self.docs {
    Some(text) => obj.set("docs", json_docs(text))
    None => ()
  }
  obj.set("exports", world_items_to_json(self.exports))
  obj.set("imports", world_items_to_json(self.imports))
  obj.set("name", json_string(self.name))
  obj.set("package", json_option(self.pkg))
  Json::object(obj)
}

///|
pub impl ToJson for RPackageName with to_json(self) {
  json_string(package_name_string(self))
}

///|
pub impl ToJson for RPackage with to_json(self) {
  Json::object({
    "interfaces": map_sorted_to_json(self.interfaces),
    "name": self.name.to_json(),
    "worlds": map_sorted_to_json(self.worlds),
  })
}

///|
pub impl ToJson for RTypeOwner with to_json(self) {
  match self {
    RTypeOwner::Interface(id) => Json::object({ "interface": json_number(id) })
    RTypeOwner::World(id) => Json::object({ "world": json_number(id) })
    RTypeOwner::None => Json::null()
  }
}

///|
pub impl ToJson for RRecordField with to_json(self) {
  Json::object({
    "name": json_string(self.name),
    "type": self.field_type.to_json(),
  })
}

///|
pub impl ToJson for RVariantCase with to_json(self) {
  Json::object({
    "name": json_string(self.name),
    "type": json_option(self.case_type),
  })
}

///|
pub impl ToJson for RHandleKind with to_json(self) {
  match self {
    RHandleKind::Own(id) => Json::object({ "own": json_number(id) })
    RHandleKind::Borrow(id) => Json::object({ "borrow": json_number(id) })
  }
}

///|
pub impl ToJson for RTypeKind with to_json(self) {
  match self {
    RTypeKind::Record(fields) =>
      Json::object({ "record": Json::object({ "fields": fields.to_json() }) })
    RTypeKind::Variant(cases) =>
      Json::object({ "variant": Json::object({ "cases": cases.to_json() }) })
    RTypeKind::List(inner) => Json::object({ "list": inner.to_json() })
    RTypeKind::Option(inner) => Json::object({ "option": inner.to_json() })
    RTypeKind::Future(inner) => Json::object({ "future": inner.to_json() })
    RTypeKind::Stream(inner) => Json::object({ "stream": inner.to_json() })
    RTypeKind::Result(ok~, err~) =>
      Json::object({
        "result": Json::object({
          "err": json_option(err),
          "ok": json_option(ok),
        }),
      })
    RTypeKind::Tuple(types) =>
      Json::object({ "tuple": Json::object({ "types": types.to_json() }) })
    RTypeKind::Flags(names) => {
      let flags_json : Array[Json] = []
      for name in names {
        flags_json.push(Json::object({ "name": json_string(name) }))
      }
      Json::object({
        "flags": Json::object({ "flags": Json::array(flags_json) }),
      })
    }
    RTypeKind::Enum(names) => {
      let cases_json : Array[Json] = []
      for name in names {
        cases_json.push(Json::object({ "name": json_string(name) }))
      }
      Json::object({
        "enum": Json::object({ "cases": Json::array(cases_json) }),
      })
    }
    RTypeKind::Alias(ty) => Json::object({ "type": ty.to_json() })
    RTypeKind::Resource => json_string("resource")
    RTypeKind::Handle(handle) => Json::object({ "handle": handle.to_json() })
  }
}

///|
pub impl ToJson for RTypeDef with to_json(self) {
  let obj : Map[String, Json] = {}
  match self.docs {
    Some(text) => obj.set("docs", json_docs(text))
    None => ()
  }
  obj.set("kind", self.kind.to_json())
  obj.set("name", json_option(self.name))
  obj.set("owner", self.owner.to_json())
  Json::object(obj)
}

///|
pub impl ToJson for Resolve with to_json(self) {
  Json::object({
    "interfaces": self.interfaces.to_json(),
    "packages": self.packages.to_json(),
    "types": self.types.to_json(),
    "worlds": self.worlds.to_json(),
  })
}

///|
pub impl ToJson for ResolveInput with to_json(self) {
  Json::object({
    "resolve": self.resolve.to_json(),
    "world_id": json_number(self.world_id),
  })
}

///|
priv struct InterfaceBuilder {
  name : String?
  docs : String?
  pkg : Int?
  types : Map[String, Int]
  functions : Map[String, RFunction]
}

///|
priv struct Resolver {
  types : Array[RTypeDef]
  iface_builders : Array[InterfaceBuilder]
  worlds : Array[RWorld]
  packages : Array[RPackage]
  package_ids : Map[String, Int]
  iface_ids : Map[String, Int]
  anon_type_ids : Map[String, Int]
}

///|
priv struct WorldTypeScope {
  types : Map[String, Int]
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
fn iface_key(pkg_id : Int?, name : String) -> String {
  match pkg_id {
    Some(id) => id.to_string() + ":" + name
    None => "_" + ":" + name
  }
}

///|
fn Resolver::new() -> Resolver {
  {
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
fn Resolver::ensure_package(self : Resolver, pkg : RPackageName) -> Int {
  let key = pkg_key(pkg)
  match self.package_ids.get(key) {
    Some(id) => id
    None => {
      let id = self.packages.length()
      let pkg_def : RPackage = { name: pkg, interfaces: {}, worlds: {} }
      self.packages.push(pkg_def)
      self.package_ids.set(key, id)
      id
    }
  }
}

///|
fn Resolver::ensure_interface(
  self : Resolver,
  pkg_id : Int?,
  name : String,
) -> Int {
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
  pkg_id : Int?,
  docs : String?,
) -> Int {
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
  { ns: pkg.ns, name: pkg.name, version: pkg.version }
}

///|
fn Resolver::push_type(self : Resolver, type_def : RTypeDef) -> Int {
  let id = self.types.length()
  self.types.push(type_def)
  id
}

///|
fn Resolver::intern_type(self : Resolver, kind : RTypeKind) -> Int {
  let key = type_kind_key(kind)
  match self.anon_type_ids.get(key) {
    Some(id) => id
    None => {
      let id = self.push_type({
        name: None,
        kind,
        owner: RTypeOwner::None,
        docs: None,
      })
      self.anon_type_ids.set(key, id)
      id
    }
  }
}

///|
fn Resolver::ensure_borrow_handle(self : Resolver, res_id : Int) -> RType {
  let id = self.intern_type(RTypeKind::Handle(RHandleKind::Borrow(res_id)))
  RType::Id(id)
}

///|
fn Resolver::ensure_own_handle(self : Resolver, res_id : Int) -> RType {
  let id = self.intern_type(RTypeKind::Handle(RHandleKind::Own(res_id)))
  RType::Id(id)
}

///|
fn Resolver::set_type_kind(
  self : Resolver,
  type_id : Int,
  kind : RTypeKind,
) -> Unit {
  let current = self.types[type_id]
  self.types[type_id] = {
    name: current.name,
    kind,
    owner: current.owner,
    docs: current.docs,
  }
}

///|
fn Resolver::resolve_type_expr(
  self : Resolver,
  iface_id : Int,
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
    Id(name) => {
      let iface = self.iface_builders[iface_id]
      match iface.types.get(name) {
        Some(id) => RType::Id(id)
        None => raise ParseError::Message("unknown type: " + name, 0)
      }
    }
    List(inner) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      let id = self.intern_type(List(inner_ty))
      RType::Id(id)
    }
    Option(inner) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      let id = self.intern_type(Option(inner_ty))
      RType::Id(id)
    }
    Future(inner) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      let id = self.intern_type(Future(inner_ty))
      RType::Id(id)
    }
    Stream(inner) => {
      let inner_ty = self.resolve_type_expr(iface_id, inner)
      let id = self.intern_type(Stream(inner_ty))
      RType::Id(id)
    }
    Result(ok_ty, err_ty) => {
      let ok_value = self.resolve_type_expr(iface_id, ok_ty)
      let ok : RType? = Some(ok_value)
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
  iface_id : Int,
  func : Function,
  kind : RFunctionKind,
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
  { name: func.name, kind, params, result, docs: func.docs }
}

///|
fn build_world_type_scope(world_types : Map[String, Int]) -> WorldTypeScope {
  let scope : WorldTypeScope = { types: {}, ambiguous: {} }
  for name, type_id in world_types {
    scope.types.set(name, type_id)
  }
  scope
}

///|
fn resolve_world_type(
  scope : WorldTypeScope,
  name : String,
) -> Int raise ParseError {
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
      raise ParseError::Message("duplicate world item: " + merged_name, 0)
    }
    target.set(merged_name, item)
  }
}

///|
fn Resolver::find_world_id_in_scope(
  self : Resolver,
  pkg_id : Int?,
  name : String,
) -> Int? {
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
  current_pkg_id : Int?,
  include_decl : IncludeDecl,
) -> Int raise ParseError {
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
) -> Int raise ParseError {
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
    List(inner) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      let id = self.intern_type(List(inner_ty))
      RType::Id(id)
    }
    Option(inner) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      let id = self.intern_type(Option(inner_ty))
      RType::Id(id)
    }
    Future(inner) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      let id = self.intern_type(Future(inner_ty))
      RType::Id(id)
    }
    Stream(inner) => {
      let inner_ty = self.resolve_type_expr_world(scope, inner)
      let id = self.intern_type(Stream(inner_ty))
      RType::Id(id)
    }
    Result(ok_ty, err_ty) => {
      let ok_value = self.resolve_type_expr_world(scope, ok_ty)
      let ok : RType? = Some(ok_value)
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
      RType::Id(type_id)
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
    name: func.name,
    kind: RFunctionKind::Freestanding,
    params,
    result,
    docs: func.docs,
  }
}

///|
fn Resolver::register_interfaces(
  self : Resolver,
  pkg_id : Int?,
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
  iface_id : Int,
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
          kind: Alias(RType::Bool),
          owner: RTypeOwner::Interface(iface_id),
          docs: def.docs,
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
  current_pkg : Int?,
  from : UsePath,
) -> Int raise ParseError {
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
  iface_id : Int,
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
            Some(tid) => builder.types.set(name, tid)
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
  pkg_id : Int?,
  ifaces : Array[Interface],
) -> Unit raise ParseError {
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
              Some(tid) => builder.types.set(name, tid)
              None => raise ParseError::Message("unknown type: " + name, 0)
            }
          }
        }
        _ => ()
      }
    }
  }
}

///|
fn Resolver::fill_interface(
  self : Resolver,
  iface_id : Int,
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
              resolved.push({ name: field.name, field_type: ty })
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
              resolved.push({ name: case.name, case_type: ty })
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
                Method(_) => {
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
                  let result = Some(self.ensure_own_handle(type_id))
                  let name = "[constructor]" + def.name
                  let resolved : RFunction = {
                    name,
                    kind: RFunctionKind::Constructor(type_id),
                    params,
                    result,
                    docs: func.docs,
                  }
                  builder.functions.set(resolved.name, resolved)
                }
                Method(_) => {
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
                  let name = "[method]" + def.name + "." + func.name
                  let resolved : RFunction = {
                    name,
                    kind: RFunctionKind::Method(type_id),
                    params,
                    result,
                    docs: func.docs,
                  }
                  builder.functions.set(resolved.name, resolved)
                }
                Static(_) => {
                  let params : Array[(String, RType)] = []
                  for param in func.params {
                    let ty = self.resolve_type_expr(iface_id, param.ty)
                    params.push((param.name, ty))
                  }
                  let result = match func.result {
                    Some(r) => Some(self.resolve_type_expr(iface_id, r))
                    None => None
                  }
                  let name = "[static]" + def.name + "." + func.name
                  let resolved : RFunction = {
                    name,
                    kind: RFunctionKind::Static(type_id),
                    params,
                    result,
                    docs: func.docs,
                  }
                  builder.functions.set(resolved.name, resolved)
                }
                Freestanding => {
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
  pkg_id : Int?,
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
  pkg_id : Int?,
  worlds : Array[World],
) -> Unit raise ParseError {
  for world in worlds {
    let imports : Map[String, RWorldItem] = {}
    let exports : Map[String, RWorldItem] = {}
    let world_id = self.worlds.length()
    let world_types : Map[String, Int] = {}
    for def in world.types {
      if world_types.contains(def.name) {
        raise ParseError::Message("duplicate type: " + def.name, 0)
      }
      let placeholder : RTypeDef = {
        name: Some(def.name),
        kind: Alias(RType::Bool),
        owner: RTypeOwner::World(world_id),
        docs: def.docs,
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
            resolved.push({ name: field.name, field_type: ty })
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
            resolved.push({ name: case.name, case_type: ty })
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
              Method(_) => {
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
                let result = Some(self.ensure_own_handle(type_id))
                let name = "[constructor]" + def.name
                let resolved : RFunction = {
                  name,
                  kind: RFunctionKind::Constructor(type_id),
                  params,
                  result,
                  docs: func.docs,
                }
                imports.set(resolved.name, Function(resolved))
              }
              Method(_) => {
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
                let name = "[method]" + def.name + "." + func.name
                let resolved : RFunction = {
                  name,
                  kind: RFunctionKind::Method(type_id),
                  params,
                  result,
                  docs: func.docs,
                }
                imports.set(resolved.name, Function(resolved))
              }
              Static(_) => {
                let params : Array[(String, RType)] = []
                for param in func.params {
                  let ty = self.resolve_type_expr_world(world_scope, param.ty)
                  params.push((param.name, ty))
                }
                let result = match func.result {
                  Some(r) => Some(self.resolve_type_expr_world(world_scope, r))
                  None => None
                }
                let name = "[static]" + def.name + "." + func.name
                let resolved : RFunction = {
                  name,
                  kind: RFunctionKind::Static(type_id),
                  params,
                  result,
                  docs: func.docs,
                }
                imports.set(resolved.name, Function(resolved))
              }
              Freestanding => {
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
      match item {
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
          imports.set(key, Interface({ id: iface_id }))
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
          imports.set(inline.name, Interface({ id: iface_id }))
        }
        WorldItem::Function(func) => {
          let resolved = self.resolve_world_function(func, world_scope)
          imports.set(resolved.name, Function(resolved))
        }
      }
    }
    for item in world.exports {
      match item {
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
          exports.set(key, Interface({ id: iface_id }))
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
          exports.set(inline.name, Interface({ id: iface_id }))
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
fn resolve_asts(asts : Array[WitFile]) -> Resolve raise ParseError {
  let resolver = Resolver::new()
  let pkg_ids : Array[Int?] = []
  for ast in asts {
    let pkg_id = match ast.pkg {
      Some(p) => Some(resolver.ensure_package(to_rpkg(p)))
      None => None
    }
    pkg_ids.push(pkg_id)
    resolver.register_interfaces(pkg_id, ast.interfaces)
  }
  for i, ast in asts {
    resolver.apply_use_decls(pkg_ids[i], ast.interfaces)
  }
  for i, ast in asts {
    resolver.fill_interfaces(pkg_ids[i], ast.interfaces)
  }
  for i, ast in asts {
    resolver.fill_worlds(pkg_ids[i], ast.worlds)
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
