///|
fn resource_identity(types : Array[RTypeDef], initial : Int32) -> Int32? {
  let mut id = initial
  for _ in 0..<types.length() {
    match types[id].kind {
      Resource => return Some(id)
      Alias(Id(next)) => id = next
      _ => return None
    }
  }
  None
}

///|
fn Resolver::resource_value(self : Resolver, ty : RType) -> RType {
  if ty is Id(id) {
    if resource_identity(self.types, id) is Some(resource) {
      return self.ensure_own_handle(resource)
    }
  }
  ty
}

///|
fn Resolver::normalize_resource_kind(
  self : Resolver,
  kind : RTypeKind,
) -> RTypeKind {
  match kind {
    Record(fields) =>
      Record(
        fields.map(field => {
          ..field,
          field_type: self.resource_value(field.field_type),
        }),
      )
    Variant(cases) =>
      Variant(
        cases.map(case => {
          ..case,
          case_type: case.case_type.map(ty => self.resource_value(ty)),
        }),
      )
    List(ty) => List(self.resource_value(ty))
    FixedLengthList(ty, size) => FixedLengthList(self.resource_value(ty), size)
    Option(ty) => Option(self.resource_value(ty))
    Future(ty) => Future(ty.map(ty => self.resource_value(ty)))
    Stream(ty) => Stream(ty.map(ty => self.resource_value(ty)))
    Result(ok~, err~) =>
      Result(
        ok=ok.map(ty => self.resource_value(ty)),
        err=err.map(ty => self.resource_value(ty)),
      )
    Tuple(types) => Tuple(types.map(ty => self.resource_value(ty)))
    Map(key, value) => Map(self.resource_value(key), self.resource_value(value))
    Handle(Own(id)) =>
      Handle(Own(resource_identity(self.types, id).unwrap_or(id)))
    Handle(Borrow(id)) =>
      Handle(Borrow(resource_identity(self.types, id).unwrap_or(id)))
    // A named resource alias remains a type alias. Ownership applies at value sites.
    _ => kind
  }
}

///|
fn Resolver::normalize_resource_function(
  self : Resolver,
  func : RFunction,
) -> RFunction {
  {
    ..func,
    params: func.params.map(param => (param.0, self.resource_value(param.1))),
    result: func.result.map(ty => self.resource_value(ty)),
  }
}

///|
fn Resolver::normalize_resource_values(self : Resolver) -> Unit {
  let count = self.types.length()
  for id in 0..<count {
    self.set_type_kind(id, self.normalize_resource_kind(self.types[id].kind))
  }
  for iface in self.iface_builders {
    for func in iface.functions.values().to_array() {
      iface.functions.set(func.name, self.normalize_resource_function(func))
    }
  }
  for world in self.worlds {
    for items in [world.imports, world.exports] {
      for (name, item) in items.iter().to_array() {
        if item is Function(func) {
          items.set(name, Function(self.normalize_resource_function(func)))
        }
      }
    }
  }
}
