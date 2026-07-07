///|
pub struct PackageName {
  ns : String
  name : String
  version : String?
} derive(Eq, Debug)

///|
pub impl Show for PackageName with fn to_string(self) {
  repr(self)
}

///|
pub struct WitFile {
  pkg : PackageName?
  interfaces : Array[Interface]
  worlds : Array[World]
} derive(Eq, Debug)

///|
pub impl Show for WitFile with fn to_string(self) {
  repr(self)
}

///|
pub struct Interface {
  name : String
  docs : String?
  items : Array[InterfaceItem]
} derive(Eq, Debug)

///|
pub impl Show for Interface with fn to_string(self) {
  repr(self)
}

///|
pub enum InterfaceItem {
  Use(UseDecl)
  TypeDef(TypeDef)
  Function(Function)
} derive(Eq, Debug)

///|
pub impl Show for InterfaceItem with fn to_string(self) {
  repr(self)
}

///|
pub struct UseDecl {
  from : UsePath
  names : Array[String]
} derive(Eq, Debug)

///|
pub impl Show for UseDecl with fn to_string(self) {
  repr(self)
}

///|
pub struct TypeDef {
  name : String
  kind : TypeDefKind
  docs : String?
} derive(Eq, Debug)

///|
pub impl Show for TypeDef with fn to_string(self) {
  repr(self)
}

///|
pub enum TypeDefKind {
  Record(Array[Field])
  Enum(Array[String])
  Flags(Array[String])
  Variant(Array[VariantCase])
  Alias(TypeExpr)
  Resource(Resource)
} derive(Eq, Debug)

///|
pub impl Show for TypeDefKind with fn to_string(self) {
  repr(self)
}

///|
pub struct Resource {
  funcs : Array[Function]
} derive(Eq, Debug)

///|
pub impl Show for Resource with fn to_string(self) {
  repr(self)
}

///|
pub struct Field {
  name : String
  ty : TypeExpr
} derive(Eq, Debug)

///|
pub impl Show for Field with fn to_string(self) {
  repr(self)
}

///|
pub struct VariantCase {
  name : String
  ty : TypeExpr?
} derive(Eq, Debug)

///|
pub impl Show for VariantCase with fn to_string(self) {
  repr(self)
}

///|
pub struct Function {
  name : String
  kind : FunctionKind
  params : Array[Param]
  result : TypeExpr?
  docs : String?
} derive(Eq, Debug)

///|
pub impl Show for Function with fn to_string(self) {
  repr(self)
}

///|
pub enum FunctionKind {
  Freestanding
  Constructor(String)
  Method(String)
  Static(String)
} derive(Eq, Debug)

///|
pub impl Show for FunctionKind with fn to_string(self) {
  repr(self)
}

///|
pub struct Param {
  name : String
  ty : TypeExpr
} derive(Eq, Debug)

///|
pub impl Show for Param with fn to_string(self) {
  repr(self)
}

///|
pub enum TypeExpr {
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
  Id(String)
  List(TypeExpr)
  Option(TypeExpr)
  Future(TypeExpr)
  Stream(TypeExpr)
  Result(TypeExpr, TypeExpr?)
  Tuple(Array[TypeExpr])
  Own(String)
  Borrow(String)
} derive(Eq, Debug)

///|
pub impl Show for TypeExpr with fn to_string(self) {
  repr(self)
}

///|
pub struct World {
  name : String
  docs : String?
  types : Array[TypeDef]
  imports : Array[WorldItem]
  exports : Array[WorldItem]
} derive(Eq, Debug)

///|
pub impl Show for World with fn to_string(self) {
  repr(self)
}

///|
pub enum WorldItem {
  Interface(UsePath)
  Function(Function)
  InlineInterface(InlineInterface)
  Include(IncludeDecl)
} derive(Eq, Debug)

///|
pub impl Show for WorldItem with fn to_string(self) {
  repr(self)
}

///|
pub struct InlineInterface {
  name : String
  docs : String?
  items : Array[InterfaceItem]
} derive(Eq, Debug)

///|
pub impl Show for InlineInterface with fn to_string(self) {
  repr(self)
}

///|
pub struct UsePath {
  pkg : PackageName?
  interface : String
} derive(Eq, Debug)

///|
pub impl Show for UsePath with fn to_string(self) {
  repr(self)
}

///|
pub struct IncludeDecl {
  path : UsePath
  renames : Array[IncludeRename]
} derive(Eq, Debug)

///|
pub impl Show for IncludeDecl with fn to_string(self) {
  repr(self)
}

///|
pub struct IncludeRename {
  from : String
  to : String
} derive(Eq, Debug)

///|
pub impl Show for IncludeRename with fn to_string(self) {
  repr(self)
}

///|
pub suberror ParseError {
  Message(String, Int)
} derive(Eq, Debug)

///|
pub impl Show for ParseError with fn to_string(self) {
  repr(self)
}
