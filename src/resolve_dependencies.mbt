///|
fn Resolver::validate_interface_cycles(
  self : Resolver,
) -> Unit raise ParseError {
  let states = Array::make(self.iface_builders.length(), 0)
  for id in 0..<states.length() {
    self.visit_interface_dependency(id, states)
  }
}

///|
fn Resolver::visit_interface_dependency(
  self : Resolver,
  id : Int32,
  states : Array[Int32],
) -> Unit raise ParseError {
  if states[id] == 2 {
    return
  }
  if states[id] == 1 {
    raise ParseError::Message("cyclic interface dependency", 0)
  }
  states[id] = 1
  for dep in self.iface_builders[id].uses {
    self.visit_interface_dependency(dep, states)
  }
  states[id] = 2
}

///|
fn Resolver::add_dependency_import(
  self : Resolver,
  world : RWorld,
  id : Int32,
  allow_export : Bool,
  seen : Array[Bool],
) -> Unit {
  if seen[id] {
    return
  }
  seen[id] = true
  for dep in self.iface_builders[id].uses {
    self.add_dependency_import(world, dep, allow_export, seen)
  }
  let key = "interface-" + id.to_string()
  if allow_export && world.exports.contains(key) {
    return
  }
  if !world.imports.contains(key) {
    world.imports.set(
      key,
      Interface({ id, external_id: None, attributes: Attributes::empty(), }),
    )
  }
}

///|
fn Resolver::import_type_owners(
  self : Resolver,
  world : RWorld,
  ty : RType,
  seen : Array[Bool],
) -> Unit {
  if ty is Id(id) {
    if seen[id] {
      return
    }
    seen[id] = true
    let def = self.types[id]
    if def.owner is Interface(owner) {
      self.add_dependency_import(
        world,
        owner,
        false,
        Array::make(self.iface_builders.length(), false),
      )
    }
    for ty in type_children(def.kind) {
      self.import_type_owners(world, ty, seen)
    }
  }
}

///|
fn Resolver::complete_world_dependencies(self : Resolver) -> Unit {
  for world in self.worlds {
    // Snapshot explicit items before adding the transitive closure.
    let imports = world.imports.values().to_array()
    let exports = world.exports.values().to_array()
    for item in imports {
      match item {
        Interface(iface_ref) =>
          for dep in self.iface_builders[iface_ref.id].uses {
            self.add_dependency_import(
              world,
              dep,
              false,
              Array::make(self.iface_builders.length(), false),
            )
          }
        Type(id) =>
          self.import_type_owners(
            world,
            Id(id),
            Array::make(self.types.length(), false),
          )
        Function(func) => {
          for (_, ty) in func.params {
            self.import_type_owners(
              world,
              ty,
              Array::make(self.types.length(), false),
            )
          }
          if func.result is Some(ty) {
            self.import_type_owners(
              world,
              ty,
              Array::make(self.types.length(), false),
            )
          }
        }
      }
    }
    for item in exports {
      match item {
        Interface(iface_ref) =>
          for dep in self.iface_builders[iface_ref.id].uses {
            self.add_dependency_import(
              world,
              dep,
              true,
              Array::make(self.iface_builders.length(), false),
            )
          }
        Function(func) => {
          for (_, ty) in func.params {
            self.import_type_owners(
              world,
              ty,
              Array::make(self.types.length(), false),
            )
          }
          if func.result is Some(ty) {
            self.import_type_owners(
              world,
              ty,
              Array::make(self.types.length(), false),
            )
          }
        }
        Type(id) =>
          self.import_type_owners(
            world,
            Id(id),
            Array::make(self.types.length(), false),
          )
      }
    }
  }
}
