///|
pub struct PackageName {
  ns : String
  name : String
  version : String?
} derive(Show, Eq)

///|
pub struct WitFile {
  pkg : PackageName?
  interfaces : Array[Interface]
  worlds : Array[World]
} derive(Show, Eq)

///|
pub struct Interface {
  name : String
  docs : String?
  items : Array[InterfaceItem]
} derive(Show, Eq)

///|
pub enum InterfaceItem {
  Use(UseDecl)
  TypeDef(TypeDef)
  Function(Function)
} derive(Show, Eq)

///|
pub struct UseDecl {
  from : UsePath
  names : Array[String]
} derive(Show, Eq)

///|
pub struct TypeDef {
  name : String
  kind : TypeDefKind
  docs : String?
} derive(Show, Eq)

///|
pub enum TypeDefKind {
  Record(Array[Field])
  Enum(Array[String])
  Flags(Array[String])
  Variant(Array[VariantCase])
  Alias(TypeExpr)
  Resource(Resource)
} derive(Show, Eq)

///|
pub struct Resource {
  funcs : Array[Function]
} derive(Show, Eq)

///|
pub struct Field {
  name : String
  ty : TypeExpr
} derive(Show, Eq)

///|
pub struct VariantCase {
  name : String
  ty : TypeExpr?
} derive(Show, Eq)

///|
pub struct Function {
  name : String
  kind : FunctionKind
  params : Array[Param]
  result : TypeExpr?
  docs : String?
} derive(Show, Eq)

///|
pub enum FunctionKind {
  Freestanding
  Constructor(String)
  Method(String)
  Static(String)
} derive(Show, Eq)

///|
pub struct Param {
  name : String
  ty : TypeExpr
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
pub struct World {
  name : String
  docs : String?
  types : Array[TypeDef]
  imports : Array[WorldItem]
  exports : Array[WorldItem]
} derive(Show, Eq)

///|
pub enum WorldItem {
  Interface(UsePath)
  Function(Function)
  InlineInterface(InlineInterface)
  Include(IncludeDecl)
} derive(Show, Eq)

///|
pub struct InlineInterface {
  name : String
  docs : String?
  items : Array[InterfaceItem]
} derive(Show, Eq)

///|
pub struct UsePath {
  pkg : PackageName?
  interface : String
} derive(Show, Eq)

///|
pub struct IncludeDecl {
  path : UsePath
  renames : Array[IncludeRename]
} derive(Show, Eq)

///|
pub struct IncludeRename {
  from : String
  to : String
} derive(Show, Eq)

///|
pub suberror ParseError {
  Message(String, Int)
} derive(Show, Eq)
