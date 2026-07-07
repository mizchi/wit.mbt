///|
pub struct ResolvedTypeInfo {
  local_name : String
  type_id : Int
  type_name : String?
  type_kind : RTypeKind
  owner : RTypeOwner
  owner_package : RPackageName?
  owner_interface : String?
  owner_world : String?
} derive(Eq, Debug)

///|
pub impl Show for ResolvedTypeInfo with fn to_string(self) {
  repr(self)
}

///|
pub struct ResolvedInterfaceInfo {
  interface_id : Int
  name : String?
  docs : String?
  package_name : RPackageName?
  functions : Map[String, RFunction]
  types : Map[String, ResolvedTypeInfo]
} derive(Eq, Debug)

///|
pub impl Show for ResolvedInterfaceInfo with fn to_string(self) {
  repr(self)
}

///|
fn package_name_from_id(resolve : Resolve, pkg_id : Int?) -> RPackageName? {
  match pkg_id {
    Some(id) => Some(resolve.packages[id].name)
    None => None
  }
}

///|
fn owner_interface_name(resolve : Resolve, owner : RTypeOwner) -> String? {
  match owner {
    RTypeOwner::Interface(interface_id) => resolve.interfaces[interface_id].name
    _ => None
  }
}

///|
fn owner_world_name(resolve : Resolve, owner : RTypeOwner) -> String? {
  match owner {
    RTypeOwner::World(world_id) => Some(resolve.worlds[world_id].name)
    _ => None
  }
}

///|
fn owner_package_name(resolve : Resolve, owner : RTypeOwner) -> RPackageName? {
  match owner {
    RTypeOwner::Interface(interface_id) =>
      package_name_from_id(resolve, resolve.interfaces[interface_id].pkg)
    RTypeOwner::World(world_id) =>
      package_name_from_id(resolve, resolve.worlds[world_id].pkg)
    RTypeOwner::None => None
  }
}

///|
fn build_resolved_type_info(
  resolve : Resolve,
  local_name : String,
  type_id : Int,
) -> ResolvedTypeInfo {
  let type_def = resolve.types[type_id]
  {
    local_name,
    type_id,
    type_name: type_def.name,
    type_kind: type_def.kind,
    owner: type_def.owner,
    owner_package: owner_package_name(resolve, type_def.owner),
    owner_interface: owner_interface_name(resolve, type_def.owner),
    owner_world: owner_world_name(resolve, type_def.owner),
  }
}

///|
/// Build resolved interface infos from `Resolve`.
pub fn interface_infos(resolve : Resolve) -> Array[ResolvedInterfaceInfo] {
  let infos : Array[ResolvedInterfaceInfo] = []
  for interface_id, iface in resolve.interfaces {
    let type_infos : Map[String, ResolvedTypeInfo] = {}
    for local_name, type_id in iface.types {
      let info = build_resolved_type_info(resolve, local_name, type_id)
      type_infos.set(local_name, info)
    }
    infos.push({
      interface_id,
      name: iface.name,
      docs: iface.docs,
      package_name: package_name_from_id(resolve, iface.pkg),
      functions: iface.functions,
      types: type_infos,
    })
  }
  infos
}

///|
/// Resolve WIT source and return resolved interface infos.
pub fn resolve_interface_infos(
  source : String,
) -> Result[Array[ResolvedInterfaceInfo], ParseError] {
  match resolve(source) {
    Ok(resolved) => Ok(interface_infos(resolved))
    Err(err) => Err(err)
  }
}

///|
/// Resolve WIT path and return resolved interface infos.
pub fn resolve_path_interface_infos(
  path : String,
  world? : String,
) -> Result[Array[ResolvedInterfaceInfo], ParseError] {
  let resolved = match world {
    Some(name) => resolve_path(path, world=name)
    None => resolve_path(path)
  }
  match resolved {
    Ok(input) => Ok(interface_infos(input.resolve))
    Err(err) => Err(err)
  }
}
