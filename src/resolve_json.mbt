///|
using @json {trait ToJson}

///|
fn json_number(value : Int32) -> Json {
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
fn string_lex_compare(a : String, b : String) -> Int32 {
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
  let result : Map[String, Json] = Map([])
  for key in keys {
    match items.get(key) {
      Option::Some(value) => result.set(key, value.to_json())
      Option::None => ()
    }
  }
  Json::object(result)
}

///|
pub impl ToJson for RType with fn to_json(self) {
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
    RType::ErrorContext => json_string("error-context")
    RType::Id(id) => json_number(id)
  }
}

///|
pub impl ToJson for RFunctionKind with fn to_json(self) {
  match self {
    RFunctionKind::Freestanding => json_string("freestanding")
    RFunctionKind::Getter => json_string("getter")
    RFunctionKind::Setter => json_string("setter")
    RFunctionKind::MethodGetter(id) =>
      Json::object({ "method-getter": json_number(id) })
    RFunctionKind::MethodSetter(id) =>
      Json::object({ "method-setter": json_number(id) })
    RFunctionKind::StaticGetter(id) =>
      Json::object({ "static-getter": json_number(id) })
    RFunctionKind::StaticSetter(id) =>
      Json::object({ "static-setter": json_number(id) })
    RFunctionKind::AsyncFreestanding => json_string("async-freestanding")
    RFunctionKind::AsyncMethod(id) =>
      Json::object({ "async-method": json_number(id) })
    RFunctionKind::AsyncStatic(id) =>
      Json::object({ "async-static": json_number(id) })
    RFunctionKind::Constructor(id) =>
      Json::object({ "constructor": json_number(id) })
    RFunctionKind::Method(id) => Json::object({ "method": json_number(id) })
    RFunctionKind::Static(id) => Json::object({ "static": json_number(id) })
  }
}

///|
pub impl ToJson for RFunction with fn to_json(self) {
  let params_json : Array[Json] = []
  for item in self.params {
    let (name, ty) = item
    params_json.push(
      Json::object({ "name": json_string(name), "type": ty.to_json() }),
    )
  }
  let obj : Map[String, Json] = Map([])
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
  if self.external_id is Some(id) {
    obj.set("external-id", json_string(id))
  }
  Json::object(obj)
}

///|
fn world_items_to_json(items : Map[String, RWorldItem]) -> Json {
  let result : Map[String, Json] = Map([])
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
pub impl ToJson for RWorldItem with fn to_json(self) {
  match self {
    RWorldItem::Interface(iface_ref) =>
      Json::object({ "interface": iface_ref.to_json() })
    RWorldItem::Function(func) => Json::object({ "function": func.to_json() })
    RWorldItem::Type(id) => Json::object({ "type": json_number(id) })
  }
}

///|
pub impl ToJson for RInterfaceRef with fn to_json(self) {
  let obj : Map[String, Json] = { "id": json_number(self.id) }
  if self.external_id is Some(id) {
    obj.set("external-id", json_string(id))
  }
  Json::object(obj)
}

///|
pub impl ToJson for RInterface with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
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
pub impl ToJson for RWorld with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
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
pub impl ToJson for RPackageName with fn to_json(self) {
  json_string(package_name_string(self))
}

///|
pub impl ToJson for RPackage with fn to_json(self) {
  Json::object({
    "interfaces": map_sorted_to_json(self.interfaces),
    "name": self.name.to_json(),
    "worlds": map_sorted_to_json(self.worlds),
  })
}

///|
pub impl ToJson for RTypeOwner with fn to_json(self) {
  match self {
    RTypeOwner::Interface(id) => Json::object({ "interface": json_number(id) })
    RTypeOwner::World(id) => Json::object({ "world": json_number(id) })
    RTypeOwner::None => Json::null()
  }
}

///|
pub impl ToJson for RRecordField with fn to_json(self) {
  Json::object({
    "name": json_string(self.name),
    "type": self.field_type.to_json(),
  })
}

///|
pub impl ToJson for RVariantCase with fn to_json(self) {
  Json::object({
    "name": json_string(self.name),
    "type": json_option(self.case_type),
  })
}

///|
pub impl ToJson for RHandleKind with fn to_json(self) {
  match self {
    RHandleKind::Own(id) => Json::object({ "own": json_number(id) })
    RHandleKind::Borrow(id) => Json::object({ "borrow": json_number(id) })
  }
}

///|
pub impl ToJson for RTypeKind with fn to_json(self) {
  match self {
    RTypeKind::Record(fields) =>
      Json::object({
        "record": Json::object({ "fields": ToJson::to_json(fields) }),
      })
    RTypeKind::Variant(cases) =>
      Json::object({
        "variant": Json::object({ "cases": ToJson::to_json(cases) }),
      })
    RTypeKind::List(inner) => Json::object({ "list": inner.to_json() })
    RTypeKind::FixedLengthList(inner, size) =>
      Json::object({
        "fixed-length-list": Json::array([
          inner.to_json(),
          ToJson::to_json(size),
        ]),
      })
    RTypeKind::Map(key, value) =>
      Json::object({ "map": Json::array([key.to_json(), value.to_json()]) })
    RTypeKind::Option(inner) => Json::object({ "option": inner.to_json() })
    RTypeKind::Future(inner) => Json::object({ "future": json_option(inner) })
    RTypeKind::Stream(inner) => Json::object({ "stream": json_option(inner) })
    RTypeKind::Result(ok~, err~) =>
      Json::object({
        "result": Json::object({
          "err": json_option(err),
          "ok": json_option(ok),
        }),
      })
    RTypeKind::Tuple(types) =>
      Json::object({
        "tuple": Json::object({ "types": ToJson::to_json(types) }),
      })
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
pub impl ToJson for RTypeDef with fn to_json(self) {
  let obj : Map[String, Json] = Map([])
  match self.docs {
    Some(text) => obj.set("docs", json_docs(text))
    None => ()
  }
  obj.set("kind", self.kind.to_json())
  obj.set("name", json_option(self.name))
  obj.set("owner", self.owner.to_json())
  if self.external_id is Some(id) {
    obj.set("external-id", json_string(id))
  }
  Json::object(obj)
}

///|
pub impl ToJson for Resolve with fn to_json(self) {
  Json::object({
    "interfaces": ToJson::to_json(self.interfaces),
    "packages": ToJson::to_json(self.packages),
    "types": ToJson::to_json(self.types),
    "worlds": ToJson::to_json(self.worlds),
  })
}

///|
pub impl ToJson for ResolveInput with fn to_json(self) {
  Json::object({
    "resolve": self.resolve.to_json(),
    "world_id": json_number(self.world_id),
  })
}

///|
pub extend RType with ToJson::{to_json}

///|
pub extend RFunctionKind with ToJson::{to_json}

///|
pub extend RFunction with ToJson::{to_json}

///|
pub extend RWorldItem with ToJson::{to_json}

///|
pub extend RInterfaceRef with ToJson::{to_json}

///|
pub extend RInterface with ToJson::{to_json}

///|
pub extend RWorld with ToJson::{to_json}

///|
pub extend RPackageName with ToJson::{to_json}

///|
pub extend RPackage with ToJson::{to_json}

///|
pub extend RTypeOwner with ToJson::{to_json}

///|
pub extend RRecordField with ToJson::{to_json}

///|
pub extend RVariantCase with ToJson::{to_json}

///|
pub extend RHandleKind with ToJson::{to_json}

///|
pub extend RTypeKind with ToJson::{to_json}

///|
pub extend RTypeDef with ToJson::{to_json}

///|
pub extend Resolve with ToJson::{to_json}

///|
pub extend ResolveInput with ToJson::{to_json}
