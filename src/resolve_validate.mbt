///|
fn type_children(kind : RTypeKind) -> Array[RType] {
  match kind {
    Record(fields) => fields.map(f => f.field_type)
    Variant(cases) => cases.filter_map(c => c.case_type)
    List(t) | FixedLengthList(t, _) | Option(t) | Alias(t) => [t]
    Future(t) | Stream(t) =>
      match t {
        Some(t) => [t]
        None => []
      }
    Map(k, v) => [k, v]
    Result(ok~, err~) => [ok, err].filter_map(t => t)
    Tuple(ts) => ts
    _ => []
  }
}

///|
fn validate_type_cycle(
  types : Array[RTypeDef],
  states : Array[Int32],
  id : Int32,
) -> Unit raise ParseError {
  if states[id] == 2 {
    return
  }
  if states[id] == 1 {
    raise ParseError::Message("recursive WIT type", 0)
  }
  states[id] = 1
  for ty in type_children(types[id].kind) {
    if ty is Id(child) {
      validate_type_cycle(types, states, child)
    }
  }
  states[id] = 2
}

///|
fn map_key_allowed(types : Array[RTypeDef], ty : RType) -> Bool {
  match ty {
    Bool | U8 | U16 | U32 | U64 | S8 | S16 | S32 | S64 | Char | String_ => true
    Id(id) =>
      match types[id].kind {
        Alias(t) => map_key_allowed(types, t)
        _ => false
      }
    _ => false
  }
}

///|
fn map_value_allowed(
  types : Array[RTypeDef],
  ty : RType,
  seen : Array[Bool],
) -> Bool {
  match ty {
    ErrorContext => false
    Id(id) => {
      if seen[id] {
        return true
      }
      seen[id] = true
      match types[id].kind {
        Resource | Handle(_) | Future(_) | Stream(_) => false
        kind => type_children(kind).all(t => map_value_allowed(types, t, seen))
      }
    }
    _ => true
  }
}

///|
fn validate_resolved_types(types : Array[RTypeDef]) -> Unit raise ParseError {
  let states = Array::make(types.length(), 0)
  for id in 0..<types.length() {
    validate_type_cycle(types, states, id)
  }
  for def in types {
    if def.kind is Map(key, value) {
      if !map_key_allowed(types, key) {
        raise ParseError::Message("invalid map key type", 0)
      }
      if !map_value_allowed(types, value, Array::make(types.length(), false)) {
        raise ParseError::Message(
          "map values cannot contain handles or async types", 0,
        )
      }
    }
  }
}

///|
fn canonical_type(types : Array[RTypeDef], ty : RType) -> RType {
  match ty {
    Id(id) =>
      match types[id].kind {
        Alias(t) => canonical_type(types, t)
        _ => ty
      }
    _ => ty
  }
}

///|
fn validate_accessor_pairs(
  functions : Map[String, RFunction],
  types : Array[RTypeDef],
) -> Unit raise ParseError {
  for _, setter in functions {
    match setter.kind {
      Setter | MethodSetter(_) | StaticSetter(_) => {
        if setter.result is Some(result) {
          match resolved_result_payloads(types, result) {
            Some((None, _)) => ()
            _ =>
              raise ParseError::Message(
                "setter result must have no ok payload", 0,
              )
          }
        }
        let getter_name = setter.name.replace(old="[set]", new="[get]")
        let getter = match functions.get(getter_name) {
          Some(getter) => getter
          None =>
            raise ParseError::Message(
              "setter requires a matching getter: " + setter.name,
              0,
            )
        }
        let value = setter.params[setter.params.length() - 1].1
        match getter.result {
          Some(result) => {
            let property_type = match resolved_result_payloads(types, result) {
              Some((Some(ok), _)) => ok
              Some((None, _)) =>
                raise ParseError::Message(
                  "getter result requires an ok payload", 0,
                )
              None => result
            }
            if canonical_type(types, property_type) !=
              canonical_type(types, value) {
              raise ParseError::Message(
                "getter/setter type mismatch: " + setter.name,
                0,
              )
            }
          }
          _ =>
            raise ParseError::Message(
              "getter/setter type mismatch: " + setter.name,
              0,
            )
        }
      }
      _ => ()
    }
  }
}

///|
fn resolved_result_payloads(
  types : Array[RTypeDef],
  ty : RType,
) -> (RType?, RType?)? {
  match canonical_type(types, ty) {
    Id(id) =>
      match types[id].kind {
        Result(ok~, err~) => Some((ok, err))
        _ => None
      }
    _ => None
  }
}

///|
fn validate_constructor_result(
  types : Array[RTypeDef],
  resource : Int32,
  ty : RType,
) -> Unit raise ParseError {
  match resolved_result_payloads(types, ty) {
    Some((Some(ok), _)) =>
      match canonical_type(types, ok) {
        Id(id) if id == resource => return
        Id(id) =>
          match types[id].kind {
            Handle(Own(id)) if id == resource => return
            _ => ()
          }
        _ => ()
      }
    _ => ()
  }
  raise ParseError::Message(
    "constructor result must have its own resource as the ok payload", 0,
  )
}
