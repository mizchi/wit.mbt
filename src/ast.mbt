///|
#derive(Eq, Debug)
pub struct PackageName {
  ns : String
  name : String
  version : String?
}

///|
pub impl Show for PackageName with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct WitFile {
  pkg : PackageName?
  interfaces : Array[Interface]
  worlds : Array[World]
  packages : Array[WitFile]
}

///|
pub impl Show for WitFile with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Interface {
  name : String
  docs : String?
  items : Array[InterfaceItem]
}

///|
pub impl Show for Interface with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum InterfaceItem {
  Use(UseDecl)
  TypeDef(TypeDef)
  Function(Function)
}

///|
pub impl Show for InterfaceItem with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct UseDecl {
  from : UsePath
  names : Array[String]
  renames : Array[IncludeRename]
}

///|
pub impl Show for UseDecl with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct TypeDef {
  name : String
  kind : TypeDefKind
  docs : String?
  external_id : String?
}

///|
pub impl Show for TypeDef with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum TypeDefKind {
  Record(Array[Field])
  Enum(Array[String])
  Flags(Array[String])
  Variant(Array[VariantCase])
  Alias(TypeExpr)
  Resource(Resource)
}

///|
pub impl Show for TypeDefKind with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Resource {
  funcs : Array[Function]
}

///|
pub impl Show for Resource with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Field {
  name : String
  ty : TypeExpr
}

///|
pub impl Show for Field with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct VariantCase {
  name : String
  ty : TypeExpr?
}

///|
pub impl Show for VariantCase with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Function {
  name : String
  kind : FunctionKind
  params : Array[Param]
  result : TypeExpr?
  docs : String?
  external_id : String?
}

///|
pub impl Show for Function with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum FunctionKind {
  Freestanding
  AsyncFreestanding
  Getter
  Setter
  Constructor(String)
  Method(String)
  AsyncMethod(String)
  MethodGetter(String)
  MethodSetter(String)
  Static(String)
  AsyncStatic(String)
  StaticGetter(String)
  StaticSetter(String)
}

///|
pub impl Show for FunctionKind with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Param {
  name : String
  ty : TypeExpr
}

///|
pub impl Show for Param with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
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
  ErrorContext
  Id(String)
  List(TypeExpr)
  FixedLengthList(TypeExpr, UInt32)
  Map(TypeExpr, TypeExpr)
  Option(TypeExpr)
  Future(TypeExpr?)
  Stream(TypeExpr?)
  Result(TypeExpr?, TypeExpr?)
  Tuple(Array[TypeExpr])
  Own(String)
  Borrow(String)
}

///|
pub impl Show for TypeExpr with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct World {
  name : String
  docs : String?
  types : Array[TypeDef]
  imports : Array[WorldItem]
  exports : Array[WorldItem]
}

///|
pub impl Show for World with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum WorldItem {
  Interface(UsePath)
  NamedInterface(String, UsePath)
  External(String, WorldItem)
  Function(Function)
  InlineInterface(InlineInterface)
  Include(IncludeDecl)
  Use(UseDecl)
}

///|
pub impl Show for WorldItem with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct InlineInterface {
  name : String
  docs : String?
  items : Array[InterfaceItem]
}

///|
pub impl Show for InlineInterface with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct UsePath {
  pkg : PackageName?
  interface : String
}

///|
pub impl Show for UsePath with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct IncludeDecl {
  path : UsePath
  renames : Array[IncludeRename]
}

///|
pub impl Show for IncludeDecl with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct IncludeRename {
  from : String
  to : String
}

///|
pub impl Show for IncludeRename with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub suberror ParseError {
  Message(String, Int32)
}

///|
pub impl Show for ParseError with fn to_string(self) {
  repr(self)
}

///|
pub extend PackageName with Eq::{not_equal, equal}

///|
pub extend PackageName with Debug::{to_repr}

///|
pub extend PackageName with Show::{to_string, output}

///|
pub extend WitFile with Eq::{not_equal, equal}

///|
pub extend WitFile with Debug::{to_repr}

///|
pub extend WitFile with Show::{to_string, output}

///|
pub extend Interface with Eq::{not_equal, equal}

///|
pub extend Interface with Debug::{to_repr}

///|
pub extend Interface with Show::{to_string, output}

///|
pub extend InterfaceItem with Eq::{not_equal, equal}

///|
pub extend InterfaceItem with Debug::{to_repr}

///|
pub extend InterfaceItem with Show::{to_string, output}

///|
pub extend UseDecl with Eq::{not_equal, equal}

///|
pub extend UseDecl with Debug::{to_repr}

///|
pub extend UseDecl with Show::{to_string, output}

///|
pub extend TypeDef with Eq::{not_equal, equal}

///|
pub extend TypeDef with Debug::{to_repr}

///|
pub extend TypeDef with Show::{to_string, output}

///|
pub extend TypeDefKind with Eq::{not_equal, equal}

///|
pub extend TypeDefKind with Debug::{to_repr}

///|
pub extend TypeDefKind with Show::{to_string, output}

///|
pub extend Resource with Eq::{not_equal, equal}

///|
pub extend Resource with Debug::{to_repr}

///|
pub extend Resource with Show::{to_string, output}

///|
pub extend Field with Eq::{not_equal, equal}

///|
pub extend Field with Debug::{to_repr}

///|
pub extend Field with Show::{to_string, output}

///|
pub extend VariantCase with Eq::{not_equal, equal}

///|
pub extend VariantCase with Debug::{to_repr}

///|
pub extend VariantCase with Show::{to_string, output}

///|
pub extend Function with Eq::{not_equal, equal}

///|
pub extend Function with Debug::{to_repr}

///|
pub extend Function with Show::{to_string, output}

///|
pub extend FunctionKind with Eq::{not_equal, equal}

///|
pub extend FunctionKind with Debug::{to_repr}

///|
pub extend FunctionKind with Show::{to_string, output}

///|
pub extend Param with Eq::{not_equal, equal}

///|
pub extend Param with Debug::{to_repr}

///|
pub extend Param with Show::{to_string, output}

///|
pub extend TypeExpr with Eq::{not_equal, equal}

///|
pub extend TypeExpr with Debug::{to_repr}

///|
pub extend TypeExpr with Show::{to_string, output}

///|
pub extend World with Eq::{not_equal, equal}

///|
pub extend World with Debug::{to_repr}

///|
pub extend World with Show::{to_string, output}

///|
pub extend WorldItem with Eq::{not_equal, equal}

///|
pub extend WorldItem with Debug::{to_repr}

///|
pub extend WorldItem with Show::{to_string, output}

///|
pub extend InlineInterface with Eq::{not_equal, equal}

///|
pub extend InlineInterface with Debug::{to_repr}

///|
pub extend InlineInterface with Show::{to_string, output}

///|
pub extend UsePath with Eq::{not_equal, equal}

///|
pub extend UsePath with Debug::{to_repr}

///|
pub extend UsePath with Show::{to_string, output}

///|
pub extend IncludeDecl with Eq::{not_equal, equal}

///|
pub extend IncludeDecl with Debug::{to_repr}

///|
pub extend IncludeDecl with Show::{to_string, output}

///|
pub extend IncludeRename with Eq::{not_equal, equal}

///|
pub extend IncludeRename with Debug::{to_repr}

///|
pub extend IncludeRename with Show::{to_string, output}

///|
pub extend ParseError with Eq::{not_equal, equal}

///|
pub extend ParseError with Debug::{to_repr}

///|
pub extend ParseError with Show::{to_string, output}
