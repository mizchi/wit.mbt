///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int
  mut pending_docs : Array[String]
}

///|
fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0, pending_docs: [] }
}

///|
fn Parser::consume_docs(self : Parser) -> Unit {
  while true {
    match self.tokens[self.pos].token_type {
      Doc(text) => {
        self.pending_docs.push(text)
        self.pos += 1
      }
      _ => break
    }
  }
}

///|
fn join_docs(lines : Array[String]) -> String {
  let buf = StringBuilder::new()
  for i, line in lines {
    if i > 0 {
      buf.write_char('\n')
    }
    buf.write_string(line)
  }
  buf.to_string()
}

///|
fn merge_docs(before : String?, after : String?) -> String? {
  match before {
    Some(first) =>
      match after {
        Some(second) => Some(first + "\n" + second)
        None => Some(first)
      }
    None => after
  }
}

///|
fn Parser::take_docs(self : Parser) -> String? {
  self.consume_docs()
  if self.pending_docs.length() == 0 {
    None
  } else {
    let docs = join_docs(self.pending_docs)
    self.pending_docs = []
    Some(docs)
  }
}

///|
fn Parser::peek(self : Parser) -> Token {
  self.consume_docs()
  self.tokens[self.pos]
}

///|
fn Parser::is_eof(self : Parser) -> Bool {
  match self.peek().token_type {
    Eof => true
    _ => false
  }
}

///|
fn Parser::advance(self : Parser) -> Token {
  let tok = self.peek()
  if !self.is_eof() {
    self.pos += 1
  }
  tok
}

///|
fn Parser::peek_n(self : Parser, n : Int) -> Token {
  let mut idx = self.pos
  let mut count = 0
  while idx < self.tokens.length() {
    let tok = self.tokens[idx]
    match tok.token_type {
      Doc(_) => {
        idx += 1
        continue
      }
      _ => {
        if count == n {
          return tok
        }
        count += 1
        idx += 1
      }
    }
  }
  self.tokens[self.tokens.length() - 1]
}

///|
fn Parser::is_world_func_decl(self : Parser) -> Bool {
  match
    (
      self.peek_n(0).token_type,
      self.peek_n(1).token_type,
      self.peek_n(2).token_type,
    ) {
    (Ident(_), Symbol(sym), Keyword(kw)) if sym == ":" && kw == "func" => true
    (Ident(_), Symbol(sym), Keyword(kw)) if sym == ":" && kw == "async" =>
      match self.peek_n(3).token_type {
        Keyword(next_kw) if next_kw == "func" => true
        _ => false
      }
    _ => false
  }
}

///|
fn Parser::is_world_inline_interface_decl(self : Parser) -> Bool {
  match
    (
      self.peek_n(0).token_type,
      self.peek_n(1).token_type,
      self.peek_n(2).token_type,
    ) {
    (Ident(_), Symbol(sym), Keyword(kw)) if sym == ":" && kw == "interface" =>
      true
    _ => false
  }
}

///|
fn Parser::error(self : Parser, message : String) -> ParseError {
  let offset = self.peek().offset
  ParseError::Message(message, offset)
}

///|
fn Parser::match_symbol(self : Parser, sym : String) -> Bool {
  match self.peek().token_type {
    Symbol(s) if s == sym => {
      ignore(self.advance())
      true
    }
    _ => false
  }
}

///|
fn Parser::expect_symbol(self : Parser, sym : String) -> Unit raise ParseError {
  if !self.match_symbol(sym) {
    raise self.error("expected symbol")
  }
}

///|
fn Parser::match_keyword(self : Parser, kw : String) -> Bool {
  match self.peek().token_type {
    Keyword(s) if s == kw => {
      ignore(self.advance())
      true
    }
    _ => false
  }
}

///|
fn Parser::expect_keyword(self : Parser, kw : String) -> Unit raise ParseError {
  if !self.match_keyword(kw) {
    raise self.error("expected keyword")
  }
}

///|
fn Parser::expect_ident(self : Parser) -> String raise ParseError {
  match self.peek().token_type {
    Ident(s) => {
      ignore(self.advance())
      s
    }
    _ => raise self.error("expected identifier")
  }
}

///|
fn Parser::skip_gate_args(self : Parser) -> Unit raise ParseError {
  self.expect_symbol("(")
  let mut depth = 1
  while depth > 0 {
    let tok = self.advance()
    match tok.token_type {
      Eof => raise self.error("unterminated gate annotation")
      Symbol(sym) if sym == "(" => depth += 1
      Symbol(sym) if sym == ")" => depth -= 1
      _ => ()
    }
  }
}

///|
fn Parser::skip_gate_annotations(self : Parser) -> Unit raise ParseError {
  while self.match_symbol("@") {
    match self.peek().token_type {
      Ident(_) | Keyword(_) => ignore(self.advance())
      _ => raise self.error("expected gate name")
    }
    self.skip_gate_args()
  }
}

///|
fn is_version_atom(token : TokenType) -> Bool {
  match token {
    Number(_) | Ident(_) => true
    _ => false
  }
}

///|
fn is_version_separator(token : TokenType) -> Bool {
  match token {
    Symbol(sym) if sym == "." || sym == "-" || sym == "+" => true
    _ => false
  }
}

///|
fn Parser::parse_version(self : Parser) -> String raise ParseError {
  let buf = StringBuilder::new()
  if !is_version_atom(self.peek().token_type) {
    raise self.error("expected version")
  }
  let first = self.advance()
  match first.token_type {
    Number(text) | Ident(text) => buf.write_string(text)
    _ => ()
  }
  while is_version_separator(self.peek().token_type) &&
        is_version_atom(self.peek_n(1).token_type) {
    let sep = self.advance()
    let part = self.advance()
    match sep.token_type {
      Symbol(sym) => buf.write_string(sym)
      _ => ()
    }
    match part.token_type {
      Number(text) | Ident(text) => buf.write_string(text)
      _ => ()
    }
  }
  buf.to_string()
}

///|
fn Parser::parse_package(self : Parser) -> PackageName raise ParseError {
  let ns = self.expect_ident()
  self.expect_symbol(":")
  let name = self.expect_ident()
  let mut version : String? = None
  if self.match_symbol("@") {
    let v = self.parse_version()
    version = Some(v)
  }
  self.expect_symbol(";")
  { ns, name, version }
}

///|
fn Parser::parse_use_path(self : Parser) -> UsePath raise ParseError {
  let first = self.expect_ident()
  if self.match_symbol(":") {
    let name = self.expect_ident()
    let mut version : String? = None
    if self.match_symbol("@") {
      let v = self.parse_version()
      version = Some(v)
    }
    if !self.match_symbol("/") {
      raise self.error("expected '/' after package name")
    }
    let iface = self.expect_ident()
    if self.match_symbol("@") {
      if version is Some(_) {
        raise self.error("duplicate version in use path")
      }
      let v = self.parse_version()
      version = Some(v)
    }
    let pkg : PackageName = { ns: first, name, version }
    { pkg: Some(pkg), interface: iface }
  } else {
    { pkg: None, interface: first }
  }
}

///|
fn Parser::parse_type_expr(self : Parser) -> TypeExpr raise ParseError {
  match self.peek().token_type {
    Keyword("bool") => {
      ignore(self.advance())
      Bool
    }
    Keyword("u8") => {
      ignore(self.advance())
      U8
    }
    Keyword("u16") => {
      ignore(self.advance())
      U16
    }
    Keyword("u32") => {
      ignore(self.advance())
      U32
    }
    Keyword("u64") => {
      ignore(self.advance())
      U64
    }
    Keyword("s8") => {
      ignore(self.advance())
      S8
    }
    Keyword("s16") => {
      ignore(self.advance())
      S16
    }
    Keyword("s32") => {
      ignore(self.advance())
      S32
    }
    Keyword("s64") => {
      ignore(self.advance())
      S64
    }
    Keyword("f32") => {
      ignore(self.advance())
      F32
    }
    Keyword("f64") => {
      ignore(self.advance())
      F64
    }
    Keyword("char") => {
      ignore(self.advance())
      Char
    }
    Keyword("string") => {
      ignore(self.advance())
      String_
    }
    Keyword("list") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let inner = self.parse_type_expr()
      self.expect_symbol(">")
      List(inner)
    }
    Keyword("option") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let inner = self.parse_type_expr()
      self.expect_symbol(">")
      Option(inner)
    }
    Keyword("future") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let inner = self.parse_type_expr()
      self.expect_symbol(">")
      Future(inner)
    }
    Keyword("stream") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let inner = self.parse_type_expr()
      self.expect_symbol(">")
      Stream(inner)
    }
    Keyword("result") => {
      ignore(self.advance())
      if self.match_symbol("<") {
        let ok_ty = self.parse_type_expr()
        let mut err_ty : TypeExpr? = None
        if self.match_symbol(",") {
          let e = self.parse_type_expr()
          err_ty = Some(e)
        }
        self.expect_symbol(">")
        Result(ok_ty, err_ty)
      } else {
        Result(Tuple([]), Some(Tuple([])))
      }
    }
    Keyword("tuple") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let items : Array[TypeExpr] = []
      if self.match_symbol(">") {
        Tuple(items)
      } else {
        while true {
          let ty = self.parse_type_expr()
          items.push(ty)
          if self.match_symbol(",") {
            continue
          }
          self.expect_symbol(">")
          break
        }
        Tuple(items)
      }
    }
    Keyword("own") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let name = self.expect_ident()
      self.expect_symbol(">")
      Own(name)
    }
    Keyword("borrow") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let name = self.expect_ident()
      self.expect_symbol(">")
      Borrow(name)
    }
    Ident(name) => {
      ignore(self.advance())
      if name == "_" {
        Tuple([])
      } else {
        Id(name)
      }
    }
    _ => raise self.error("expected type")
  }
}

///|
fn Parser::parse_params(self : Parser) -> Array[Param] raise ParseError {
  self.expect_symbol("(")
  let params : Array[Param] = []
  if self.match_symbol(")") {
    return params
  }
  while true {
    let name = self.expect_ident()
    self.expect_symbol(":")
    let ty = self.parse_type_expr()
    params.push({ name, ty })
    if self.match_symbol(",") {
      if self.match_symbol(")") {
        break
      }
      continue
    }
    self.expect_symbol(")")
    break
  }
  params
}

///|
fn Parser::parse_function(
  self : Parser,
  kind : FunctionKind,
  docs : String?,
) -> Function raise ParseError {
  let name = self.expect_ident()
  self.expect_symbol(":")
  let _ = self.match_keyword("async")
  self.expect_keyword("func")
  let params = self.parse_params()
  let mut result : TypeExpr? = None
  if self.match_symbol("->") {
    let ty = self.parse_type_expr()
    result = Some(ty)
  }
  self.expect_symbol(";")
  { name, kind, params, result, docs }
}

///|
fn Parser::parse_constructor(
  self : Parser,
  resource_name : String,
  docs : String?,
) -> Function raise ParseError {
  let params = self.parse_params()
  let mut result : TypeExpr? = None
  if self.match_symbol("->") {
    let ty = self.parse_type_expr()
    result = Some(ty)
  }
  self.expect_symbol(";")
  {
    name: "constructor",
    kind: Constructor(resource_name),
    params,
    result,
    docs,
  }
}

///|
fn Parser::parse_resource_function(
  self : Parser,
  resource_name : String,
  docs : String?,
) -> Function raise ParseError {
  let name = self.expect_ident()
  self.expect_symbol(":")
  let mut is_static = false
  while true {
    if self.match_keyword("async") {
      continue
    }
    if self.match_keyword("static") {
      is_static = true
      continue
    }
    break
  }
  self.expect_keyword("func")
  let params = self.parse_params()
  let mut result : TypeExpr? = None
  if self.match_symbol("->") {
    let ty = self.parse_type_expr()
    result = Some(ty)
  }
  self.expect_symbol(";")
  {
    name,
    kind: if is_static {
      Static(resource_name)
    } else {
      Method(resource_name)
    },
    params,
    result,
    docs,
  }
}

///|
fn Parser::parse_resource(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  self.expect_symbol("{")
  let funcs : Array[Function] = []
  while true {
    let func_docs = self.take_docs()
    if self.match_symbol("}") {
      break
    }
    if self.match_keyword("constructor") {
      let func = self.parse_constructor(name, func_docs)
      funcs.push(func)
      continue
    }
    if self.match_keyword("static") {
      let func = self.parse_function(Static(name), func_docs)
      funcs.push(func)
      continue
    }
    let func = self.parse_resource_function(name, func_docs)
    funcs.push(func)
  }
  { name, kind: Resource({ funcs, }), docs }
}

///|
fn Parser::parse_record(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  self.expect_symbol("{")
  let fields : Array[Field] = []
  while true {
    if self.match_symbol("}") {
      break
    }
    let field_name = self.expect_ident()
    self.expect_symbol(":")
    let ty = self.parse_type_expr()
    fields.push({ name: field_name, ty })
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  { name, kind: Record(fields), docs }
}

///|
fn Parser::parse_enum(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  self.expect_symbol("{")
  let cases : Array[String] = []
  while true {
    if self.match_symbol("}") {
      break
    }
    let case = self.expect_ident()
    cases.push(case)
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  { name, kind: Enum(cases), docs }
}

///|
fn Parser::parse_flags(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  self.expect_symbol("{")
  let cases : Array[String] = []
  while true {
    if self.match_symbol("}") {
      break
    }
    let flag = self.expect_ident()
    cases.push(flag)
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  { name, kind: Flags(cases), docs }
}

///|
fn Parser::parse_variant(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  self.expect_symbol("{")
  let cases : Array[VariantCase] = []
  while true {
    if self.match_symbol("}") {
      break
    }
    let case_name = self.expect_ident()
    let mut payload : TypeExpr? = None
    if self.match_symbol("(") {
      let ty = self.parse_type_expr()
      payload = Some(ty)
      self.expect_symbol(")")
    }
    cases.push({ name: case_name, ty: payload })
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  { name, kind: Variant(cases), docs }
}

///|
fn Parser::parse_type_alias(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  self.expect_symbol("=")
  let ty = self.parse_type_expr()
  self.expect_symbol(";")
  { name, kind: Alias(ty), docs }
}

///|
fn Parser::parse_use_decl(self : Parser) -> UseDecl raise ParseError {
  let from = self.parse_use_path()
  self.expect_symbol(".")
  self.expect_symbol("{")
  let names : Array[String] = []
  while true {
    if self.match_symbol("}") {
      break
    }
    let name = self.expect_ident()
    names.push(name)
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  self.expect_symbol(";")
  { from, names }
}

///|
fn Parser::parse_include_item(self : Parser) -> IncludeDecl raise ParseError {
  let path = self.parse_use_path()
  let renames : Array[IncludeRename] = []
  if self.match_keyword("with") {
    self.expect_symbol("{")
    while true {
      let from = self.expect_ident()
      self.expect_keyword("as")
      let to = self.expect_ident()
      renames.push({ from, to })
      if self.match_symbol(",") {
        continue
      }
      self.expect_symbol("}")
      break
    }
  }
  self.expect_symbol(";")
  { path, renames }
}

///|
fn Parser::parse_interface(
  self : Parser,
  docs : String?,
) -> Interface raise ParseError {
  let name = self.expect_ident()
  let items = self.parse_interface_items()
  { name, docs, items }
}

///|
fn Parser::parse_interface_items(
  self : Parser,
) -> Array[InterfaceItem] raise ParseError {
  self.expect_symbol("{")
  let items : Array[InterfaceItem] = []
  while true {
    let docs_before = self.take_docs()
    self.skip_gate_annotations()
    let docs_after = self.take_docs()
    let item_docs = merge_docs(docs_before, docs_after)
    if self.match_symbol("}") {
      break
    }
    if self.match_keyword("use") {
      let decl = self.parse_use_decl()
      items.push(Use(decl))
      continue
    }
    if self.match_keyword("record") {
      let type_name = self.expect_ident()
      let def = self.parse_record(type_name, item_docs)
      items.push(TypeDef(def))
      continue
    }
    if self.match_keyword("enum") {
      let type_name = self.expect_ident()
      let def = self.parse_enum(type_name, item_docs)
      items.push(TypeDef(def))
      continue
    }
    if self.match_keyword("flags") {
      let type_name = self.expect_ident()
      let def = self.parse_flags(type_name, item_docs)
      items.push(TypeDef(def))
      continue
    }
    if self.match_keyword("variant") {
      let type_name = self.expect_ident()
      let def = self.parse_variant(type_name, item_docs)
      items.push(TypeDef(def))
      continue
    }
    if self.match_keyword("resource") {
      let type_name = self.expect_ident()
      let def = self.parse_resource(type_name, item_docs)
      items.push(TypeDef(def))
      continue
    }
    if self.match_keyword("type") {
      let type_name = self.expect_ident()
      let def = self.parse_type_alias(type_name, item_docs)
      items.push(TypeDef(def))
      continue
    }
    let func = self.parse_function(Freestanding, item_docs)
    items.push(Function(func))
  }
  items
}

///|
fn Parser::parse_world(self : Parser, docs : String?) -> World raise ParseError {
  let name = self.expect_ident()
  self.expect_symbol("{")
  let types : Array[TypeDef] = []
  let imports : Array[WorldItem] = []
  let exports : Array[WorldItem] = []
  while true {
    let docs_before = self.take_docs()
    self.skip_gate_annotations()
    let docs_after = self.take_docs()
    let item_docs = merge_docs(docs_before, docs_after)
    if self.match_symbol("}") {
      break
    }
    if self.match_keyword("record") {
      let type_name = self.expect_ident()
      let def = self.parse_record(type_name, item_docs)
      types.push(def)
      continue
    }
    if self.match_keyword("enum") {
      let type_name = self.expect_ident()
      let def = self.parse_enum(type_name, item_docs)
      types.push(def)
      continue
    }
    if self.match_keyword("flags") {
      let type_name = self.expect_ident()
      let def = self.parse_flags(type_name, item_docs)
      types.push(def)
      continue
    }
    if self.match_keyword("variant") {
      let type_name = self.expect_ident()
      let def = self.parse_variant(type_name, item_docs)
      types.push(def)
      continue
    }
    if self.match_keyword("resource") {
      let type_name = self.expect_ident()
      let def = self.parse_resource(type_name, item_docs)
      types.push(def)
      continue
    }
    if self.match_keyword("type") {
      let type_name = self.expect_ident()
      let def = self.parse_type_alias(type_name, item_docs)
      types.push(def)
      continue
    }
    if self.match_keyword("include") {
      let include_decl = self.parse_include_item()
      imports.push(Include(include_decl))
      continue
    }
    if self.match_keyword("import") {
      if self.is_world_func_decl() {
        let func = self.parse_function(Freestanding, item_docs)
        imports.push(Function(func))
      } else if self.is_world_inline_interface_decl() {
        let name = self.expect_ident()
        self.expect_symbol(":")
        self.expect_keyword("interface")
        let items = self.parse_interface_items()
        imports.push(InlineInterface({ name, docs: item_docs, items }))
      } else {
        let path = self.parse_use_path()
        self.expect_symbol(";")
        imports.push(Interface(path))
      }
      continue
    }
    if self.match_keyword("export") {
      if self.is_world_func_decl() {
        let func = self.parse_function(Freestanding, item_docs)
        exports.push(Function(func))
      } else if self.is_world_inline_interface_decl() {
        let name = self.expect_ident()
        self.expect_symbol(":")
        self.expect_keyword("interface")
        let items = self.parse_interface_items()
        exports.push(InlineInterface({ name, docs: item_docs, items }))
      } else {
        let path = self.parse_use_path()
        self.expect_symbol(";")
        exports.push(Interface(path))
      }
      continue
    }
    raise self.error("unexpected world item")
  }
  { name, docs, types, imports, exports }
}

///|
fn parse_wit(source : String) -> WitFile raise ParseError {
  let tokens = tokenize_raise(source)
  let parser = Parser::new(tokens)
  let mut pkg : PackageName? = None
  let interfaces : Array[Interface] = []
  let worlds : Array[World] = []
  while true {
    if parser.is_eof() {
      break
    }
    let docs_before = parser.take_docs()
    parser.skip_gate_annotations()
    let docs_after = parser.take_docs()
    let item_docs = merge_docs(docs_before, docs_after)
    if parser.match_keyword("package") {
      let pkg_name = parser.parse_package()
      pkg = Some(pkg_name)
      continue
    }
    if parser.match_keyword("interface") {
      let iface = parser.parse_interface(item_docs)
      interfaces.push(iface)
      continue
    }
    if parser.match_keyword("world") {
      let world = parser.parse_world(item_docs)
      worlds.push(world)
      continue
    }
    raise parser.error("unexpected top-level item")
  }
  { pkg, interfaces, worlds }
}
