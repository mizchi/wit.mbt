///|
/// Resolve type reference
#derive(Eq, Debug)
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
  ErrorContext
  Id(Int32)
}

///|
pub impl Show for RType with fn to_string(self) {
  repr(self)
}

///|
/// Function kind
#derive(Eq, Debug)
pub enum RFunctionKind {
  Freestanding
  AsyncFreestanding
  Getter
  Setter
  Constructor(Int32)
  Method(Int32)
  AsyncMethod(Int32)
  MethodGetter(Int32)
  MethodSetter(Int32)
  Static(Int32)
  AsyncStatic(Int32)
  StaticGetter(Int32)
  StaticSetter(Int32)
}

///|
pub impl Show for RFunctionKind with fn to_string(self) {
  repr(self)
}

///|
/// Function definition
#derive(Eq, Debug)
pub struct RFunction {
  name : String
  kind : RFunctionKind
  params : Array[(String, RType)]
  result : RType?
  docs : String?
  external_id : String?
  attributes : Attributes
}

///|
pub impl Show for RFunction with fn to_string(self) {
  repr(self)
}

///|
/// World item
#derive(Eq, Debug)
pub enum RWorldItem {
  Interface(RInterfaceRef)
  Function(RFunction)
  Type(Int32)
}

///|
pub impl Show for RWorldItem with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RInterfaceRef {
  id : Int32
  external_id : String?
  attributes : Attributes
}

///|
pub impl Show for RInterfaceRef with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RInterface {
  name : String?
  docs : String?
  functions : Map[String, RFunction]
  types : Map[String, Int32]
  pkg : Int32?
  attributes : Attributes
}

///|
pub impl Show for RInterface with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RWorld {
  name : String
  docs : String?
  imports : Map[String, RWorldItem]
  exports : Map[String, RWorldItem]
  pkg : Int32?
  attributes : Attributes
}

///|
pub impl Show for RWorld with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RPackageName {
  ns : String
  name : String
  version : String?
}

///|
pub impl Show for RPackageName with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RPackage {
  name : RPackageName
  interfaces : Map[String, Int32]
  worlds : Map[String, Int32]
}

///|
pub impl Show for RPackage with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum RTypeOwner {
  Interface(Int32)
  World(Int32)
  None
}

///|
pub impl Show for RTypeOwner with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RRecordField {
  name : String
  field_type : RType
}

///|
pub impl Show for RRecordField with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RVariantCase {
  name : String
  case_type : RType?
}

///|
pub impl Show for RVariantCase with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum RHandleKind {
  Own(Int32)
  Borrow(Int32)
}

///|
pub impl Show for RHandleKind with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub enum RTypeKind {
  Record(Array[RRecordField])
  Variant(Array[RVariantCase])
  List(RType)
  FixedLengthList(RType, UInt32)
  Map(RType, RType)
  Option(RType)
  Future(RType?)
  Stream(RType?)
  Result(ok~ : RType?, err~ : RType?)
  Tuple(Array[RType])
  Flags(Array[String])
  Enum(Array[String])
  Alias(RType)
  Resource
  Handle(RHandleKind)
}

///|
pub impl Show for RTypeKind with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct RTypeDef {
  name : String?
  kind : RTypeKind
  owner : RTypeOwner
  docs : String?
  external_id : String?
  attributes : Attributes
}

///|
pub impl Show for RTypeDef with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Resolve {
  worlds : Array[RWorld]
  interfaces : Array[RInterface]
  types : Array[RTypeDef]
  packages : Array[RPackage]
}

///|
pub impl Show for Resolve with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct ResolveInput {
  resolve : Resolve
  world_id : Int32
}

///|
pub impl Show for ResolveInput with fn to_string(self) {
  repr(self)
}

///|
pub extend RType with Eq::{not_equal, equal}

///|
pub extend RType with Debug::{to_repr}

///|
pub extend RType with Show::{to_string, output}

///|
pub extend RFunctionKind with Eq::{not_equal, equal}

///|
pub extend RFunctionKind with Debug::{to_repr}

///|
pub extend RFunctionKind with Show::{to_string, output}

///|
pub extend RFunction with Eq::{not_equal, equal}

///|
pub extend RFunction with Debug::{to_repr}

///|
pub extend RFunction with Show::{to_string, output}

///|
pub extend RWorldItem with Eq::{not_equal, equal}

///|
pub extend RWorldItem with Debug::{to_repr}

///|
pub extend RWorldItem with Show::{to_string, output}

///|
pub extend RInterfaceRef with Eq::{not_equal, equal}

///|
pub extend RInterfaceRef with Debug::{to_repr}

///|
pub extend RInterfaceRef with Show::{to_string, output}

///|
pub extend RInterface with Eq::{not_equal, equal}

///|
pub extend RInterface with Debug::{to_repr}

///|
pub extend RInterface with Show::{to_string, output}

///|
pub extend RWorld with Eq::{not_equal, equal}

///|
pub extend RWorld with Debug::{to_repr}

///|
pub extend RWorld with Show::{to_string, output}

///|
pub extend RPackageName with Eq::{not_equal, equal}

///|
pub extend RPackageName with Debug::{to_repr}

///|
pub extend RPackageName with Show::{to_string, output}

///|
pub extend RPackage with Eq::{not_equal, equal}

///|
pub extend RPackage with Debug::{to_repr}

///|
pub extend RPackage with Show::{to_string, output}

///|
pub extend RTypeOwner with Eq::{not_equal, equal}

///|
pub extend RTypeOwner with Debug::{to_repr}

///|
pub extend RTypeOwner with Show::{to_string, output}

///|
pub extend RRecordField with Eq::{not_equal, equal}

///|
pub extend RRecordField with Debug::{to_repr}

///|
pub extend RRecordField with Show::{to_string, output}

///|
pub extend RVariantCase with Eq::{not_equal, equal}

///|
pub extend RVariantCase with Debug::{to_repr}

///|
pub extend RVariantCase with Show::{to_string, output}

///|
pub extend RHandleKind with Eq::{not_equal, equal}

///|
pub extend RHandleKind with Debug::{to_repr}

///|
pub extend RHandleKind with Show::{to_string, output}

///|
pub extend RTypeKind with Eq::{not_equal, equal}

///|
pub extend RTypeKind with Debug::{to_repr}

///|
pub extend RTypeKind with Show::{to_string, output}

///|
pub extend RTypeDef with Eq::{not_equal, equal}

///|
pub extend RTypeDef with Debug::{to_repr}

///|
pub extend RTypeDef with Show::{to_string, output}

///|
pub extend Resolve with Eq::{not_equal, equal}

///|
pub extend Resolve with Debug::{to_repr}

///|
pub extend Resolve with Show::{to_string, output}

///|
pub extend ResolveInput with Eq::{not_equal, equal}

///|
pub extend ResolveInput with Debug::{to_repr}

///|
pub extend ResolveInput with Show::{to_string, output}
