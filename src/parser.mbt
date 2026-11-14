///|
priv struct Parser {
  tokens : Array[Token]
  mut pos : Int32
  mut pending_docs : Array[String]
}

///|
fn Parser::new(tokens : Array[Token]) -> Parser {
  { tokens, pos: 0, pending_docs: [], }
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
  let buf = StringBuilder()
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
fn Parser::peek_n(self : Parser, n : Int32) -> Token {
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
    (Ident(_), Symbol(sym), Ident("get" | "set")) if sym == ":" => true
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
      if !valid_wit_identifier(s) {
        raise self.error("invalid WIT identifier: " + s)
      }
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
fn Parser::parse_annotations(self : Parser) -> String? raise ParseError {
  let mut external_id : String? = None
  while self.match_symbol("@") {
    let name = self.expect_ident()
    match name {
      "external-id" => {
        if external_id is Some(_) {
          raise self.error("duplicate external-id")
        }
        self.expect_symbol("(")
        match self.advance().token_type {
          StringLit(value) => external_id = Some(value)
          _ => raise self.error("expected external-id string")
        }
        self.expect_symbol(")")
      }
      "since" | "unstable" | "deprecated" => self.skip_gate_args()
      _ => raise self.error("unknown annotation: " + name)
    }
  }
  external_id
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
  let buf = StringBuilder()
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
  let version = buf.to_string()
  if !valid_semver(version) {
    raise self.error("invalid semantic version: " + version)
  }
  version
}

///|
fn Parser::parse_package(self : Parser) -> PackageName raise ParseError {
  let mut ns = self.expect_ident()
  self.expect_symbol(":")
  let mut name = self.expect_ident()
  while self.match_symbol(":") {
    ns += ":" + name
    name = self.expect_ident()
  }
  while self.match_symbol("/") {
    name += "/" + self.expect_ident()
  }
  let version = if self.match_symbol("@") {
    Some(self.parse_version())
  } else {
    None
  }
  { ns, name, version, }
}

///|
fn Parser::parse_use_path(self : Parser) -> UsePath raise ParseError {
  let mut ns = self.expect_ident()
  if !self.match_symbol(":") {
    return { pkg: None, interface: ns, }
  }
  let mut name = self.expect_ident()
  while self.match_symbol(":") {
    ns += ":" + name
    name = self.expect_ident()
  }
  let mut version : String? = None
  if self.match_symbol("@") {
    version = Some(self.parse_version())
  }
  self.expect_symbol("/")
  let mut iface = self.expect_ident()
  while self.match_symbol("/") {
    name += "/" + iface
    iface = self.expect_ident()
  }
  if self.match_symbol("@") {
    if version is Some(_) {
      raise self.error("duplicate version in use path")
    }
    version = Some(self.parse_version())
  }
  { pkg: Some({ ns, name, version, }), interface: iface, }
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
    Keyword("error-context") => {
      ignore(self.advance())
      ErrorContext
    }
    Keyword("map") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let key = self.parse_type_expr()
      self.expect_symbol(",")
      let value = self.parse_type_expr()
      self.expect_symbol(">")
      Map(key, value)
    }
    Keyword("list") => {
      ignore(self.advance())
      self.expect_symbol("<")
      let inner = self.parse_type_expr()
      if self.match_symbol(",") {
        let size = self.parse_list_size()
        self.expect_symbol(">")
        FixedLengthList(inner, size)
      } else {
        self.expect_symbol(">")
        List(inner)
      }
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
      let inner = if self.match_symbol("<") {
        let ty = self.parse_type_expr()
        self.expect_symbol(">")
        Some(ty)
      } else {
        None
      }
      Future(inner)
    }
    Keyword("stream") => {
      ignore(self.advance())
      let inner = if self.match_symbol("<") {
        let ty = self.parse_type_expr()
        self.expect_symbol(">")
        Some(ty)
      } else {
        None
      }
      Stream(inner)
    }
    Keyword("result") => {
      ignore(self.advance())
      if self.match_symbol("<") {
        let ok_ty : TypeExpr? = if self.match_keyword("_") ||
          self.match_ident("_") {
          None
        } else {
          Some(self.parse_type_expr())
        }
        let mut err_ty : TypeExpr? = None
        if self.match_symbol(",") {
          let e = self.parse_type_expr()
          err_ty = Some(e)
        }
        self.expect_symbol(">")
        if ok_ty is None && err_ty is None {
          raise self.error("result<_> requires an error type")
        }
        Result(ok_ty, err_ty)
      } else {
        Result(None, None)
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
        raise self.error("unexpected type placeholder")
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
    params.push({ name, ty, })
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
  let kind = self.parse_function_kind(kind)
  let params = self.parse_params()
  let mut result : TypeExpr? = None
  if self.match_symbol("->") {
    let ty = self.parse_type_expr()
    result = Some(ty)
  }
  self.validate_accessor_signature(kind, params, result)
  self.expect_symbol(";")
  { name, kind, params, result, docs, external_id: None, }
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
    external_id: None,
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
  let is_static = self.match_keyword("static")
  let kind = self.parse_function_kind(
    if is_static {
      Static(resource_name)
    } else {
      Method(resource_name)
    },
  )
  let params = self.parse_params()
  let mut result : TypeExpr? = None
  if self.match_symbol("->") {
    let ty = self.parse_type_expr()
    result = Some(ty)
  }
  self.validate_accessor_signature(kind, params, result)
  self.expect_symbol(";")
  { name, kind, params, result, docs, external_id: None, }
}

///|
fn Parser::parse_resource(
  self : Parser,
  name : String,
  docs : String?,
) -> TypeDef raise ParseError {
  // Bare resource declaration: `resource foo;`
  if self.match_symbol(";") {
    return { name, kind: Resource({ funcs: [], }), docs, external_id: None, }
  }
  self.expect_symbol("{")
  let funcs : Array[Function] = []
  while true {
    let docs_before = self.take_docs()
    let external_id = self.parse_annotations()
    let func_docs = merge_docs(docs_before, self.take_docs())
    if self.match_symbol("}") {
      break
    }
    if self.match_keyword("constructor") {
      let func = self.parse_constructor(name, func_docs)
      funcs.push({ ..func, external_id, })
      continue
    }
    if self.match_keyword("static") {
      let func = self.parse_function(Static(name), func_docs)
      funcs.push({ ..func, external_id, })
      continue
    }
    let func = self.parse_resource_function(name, func_docs)
    funcs.push({ ..func, external_id, })
  }
  { name, kind: Resource({ funcs, }), docs, external_id: None, }
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
    fields.push({ name: field_name, ty, })
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  { name, kind: Record(fields), docs, external_id: None, }
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
  { name, kind: Enum(cases), docs, external_id: None, }
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
  { name, kind: Flags(cases), docs, external_id: None, }
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
    cases.push({ name: case_name, ty: payload, })
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  { name, kind: Variant(cases), docs, external_id: None, }
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
  { name, kind: Alias(ty), docs, external_id: None, }
}

///|
fn Parser::parse_use_decl(self : Parser) -> UseDecl raise ParseError {
  let from = self.parse_use_path()
  self.expect_symbol(".")
  self.expect_symbol("{")
  let names : Array[String] = []
  let renames : Array[IncludeRename] = []
  while true {
    if self.match_symbol("}") {
      break
    }
    let name = self.expect_ident()
    names.push(name)
    if self.match_keyword("as") {
      renames.push({ from: name, to: self.expect_ident(), })
    }
    if self.match_symbol(",") {
      continue
    }
    self.expect_symbol("}")
    break
  }
  self.expect_symbol(";")
  { from, names, renames, }
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
      renames.push({ from, to, })
      if self.match_symbol(",") {
        continue
      }
      self.expect_symbol("}")
      break
    }
  }
  self.expect_symbol(";")
  { path, renames, }
}

///|
fn Parser::parse_interface(
  self : Parser,
  docs : String?,
) -> Interface raise ParseError {
  let name = self.expect_ident()
  let items = self.parse_interface_items()
  { name, docs, items, }
}

///|
fn Parser::parse_interface_items(
  self : Parser,
) -> Array[InterfaceItem] raise ParseError {
  self.expect_symbol("{")
  let items : Array[InterfaceItem] = []
  while true {
    let docs_before = self.take_docs()
    let external_id = self.parse_annotations()
    let docs_after = self.take_docs()
    let item_docs = merge_docs(docs_before, docs_after)
    if self.match_symbol("}") {
      break
    }
    if self.match_keyword("use") {
      let decl = self.parse_use_decl()
      items.push(annotate_interface_item(Use(decl), external_id))
      continue
    }
    if self.match_keyword("record") {
      let type_name = self.expect_ident()
      let def = self.parse_record(type_name, item_docs)
      items.push(annotate_interface_item(TypeDef(def), external_id))
      continue
    }
    if self.match_keyword("enum") {
      let type_name = self.expect_ident()
      let def = self.parse_enum(type_name, item_docs)
      items.push(annotate_interface_item(TypeDef(def), external_id))
      continue
    }
    if self.match_keyword("flags") {
      let type_name = self.expect_ident()
      let def = self.parse_flags(type_name, item_docs)
      items.push(annotate_interface_item(TypeDef(def), external_id))
      continue
    }
    if self.match_keyword("variant") {
      let type_name = self.expect_ident()
      let def = self.parse_variant(type_name, item_docs)
      items.push(annotate_interface_item(TypeDef(def), external_id))
      continue
    }
    if self.match_keyword("resource") {
      let type_name = self.expect_ident()
      let def = self.parse_resource(type_name, item_docs)
      items.push(annotate_interface_item(TypeDef(def), external_id))
      continue
    }
    if self.match_keyword("type") {
      let type_name = self.expect_ident()
      let def = self.parse_type_alias(type_name, item_docs)
      items.push(annotate_interface_item(TypeDef(def), external_id))
      continue
    }
    let func = self.parse_function(Freestanding, item_docs)
    items.push(annotate_interface_item(Function(func), external_id))
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
    let external_id = self.parse_annotations()
    let docs_after = self.take_docs()
    let item_docs = merge_docs(docs_before, docs_after)
    if self.match_symbol("}") {
      break
    }
    if self.match_keyword("record") {
      let type_name = self.expect_ident()
      let def = self.parse_record(type_name, item_docs)
      types.push({ ..def, external_id, })
      continue
    }
    if self.match_keyword("enum") {
      let type_name = self.expect_ident()
      let def = self.parse_enum(type_name, item_docs)
      types.push({ ..def, external_id, })
      continue
    }
    if self.match_keyword("flags") {
      let type_name = self.expect_ident()
      let def = self.parse_flags(type_name, item_docs)
      types.push({ ..def, external_id, })
      continue
    }
    if self.match_keyword("variant") {
      let type_name = self.expect_ident()
      let def = self.parse_variant(type_name, item_docs)
      types.push({ ..def, external_id, })
      continue
    }
    if self.match_keyword("resource") {
      let type_name = self.expect_ident()
      let def = self.parse_resource(type_name, item_docs)
      types.push({ ..def, external_id, })
      continue
    }
    if self.match_keyword("type") {
      let type_name = self.expect_ident()
      let def = self.parse_type_alias(type_name, item_docs)
      types.push({ ..def, external_id, })
      continue
    }
    if self.match_keyword("use") {
      imports.push(annotate_world_item(Use(self.parse_use_decl()), external_id))
      continue
    }
    if self.match_keyword("include") {
      let include_decl = self.parse_include_item()
      imports.push(annotate_world_item(Include(include_decl), external_id))
      continue
    }
    if self.match_keyword("import") {
      if self.is_world_func_decl() {
        let func = self.parse_function(Freestanding, item_docs)
        imports.push(annotate_world_item(Function(func), external_id))
      } else if self.is_world_inline_interface_decl() {
        let name = self.expect_ident()
        self.expect_symbol(":")
        self.expect_keyword("interface")
        let items = self.parse_interface_items()
        imports.push(
          annotate_world_item(
            InlineInterface({ name, docs: item_docs, items, }),
            external_id,
          ),
        )
      } else if self.is_named_interface_decl() {
        let name = self.expect_ident()
        self.expect_symbol(":")
        let path = self.parse_use_path()
        self.expect_symbol(";")
        imports.push(
          annotate_world_item(NamedInterface(name, path), external_id),
        )
      } else {
        let path = self.parse_use_path()
        self.expect_symbol(";")
        imports.push(annotate_world_item(Interface(path), external_id))
      }
      continue
    }
    if self.match_keyword("export") {
      if self.is_world_func_decl() {
        let func = self.parse_function(Freestanding, item_docs)
        exports.push(annotate_world_item(Function(func), external_id))
      } else if self.is_world_inline_interface_decl() {
        let name = self.expect_ident()
        self.expect_symbol(":")
        self.expect_keyword("interface")
        let items = self.parse_interface_items()
        exports.push(
          annotate_world_item(
            InlineInterface({ name, docs: item_docs, items, }),
            external_id,
          ),
        )
      } else if self.is_named_interface_decl() {
        let name = self.expect_ident()
        self.expect_symbol(":")
        let path = self.parse_use_path()
        self.expect_symbol(";")
        exports.push(
          annotate_world_item(NamedInterface(name, path), external_id),
        )
      } else {
        let path = self.parse_use_path()
        self.expect_symbol(";")
        exports.push(annotate_world_item(Interface(path), external_id))
      }
      continue
    }
    raise self.error("unexpected world item")
  }
  { name, docs, types, imports, exports, }
}

///|
fn parse_wit(source : String) -> WitFile raise ParseError {
  Parser::new(tokenize_raise(source)).parse_file(None, false, 0)
}

///|
fn Parser::parse_file(
  self : Parser,
  initial_pkg : PackageName?,
  nested : Bool,
  depth : Int32,
) -> WitFile raise ParseError {
  if depth >= 100 {
    raise self.error("package nesting too deep")
  }
  let mut pkg = initial_pkg
  let interfaces : Array[Interface] = []
  let worlds : Array[World] = []
  let packages : Array[WitFile] = []
  let aliases : Map[String, UsePath] = Map([])
  while true {
    let docs_before = self.take_docs()
    if self.parse_annotations() is Some(_) {
      raise self.error("external-id is not allowed on top-level items")
    }
    let docs_after = self.take_docs()
    let item_docs = merge_docs(docs_before, docs_after)
    if nested && self.match_symbol("}") {
      break
    }
    if self.is_eof() {
      if nested {
        raise self.error("unterminated package")
      }
      break
    }
    if self.match_keyword("package") {
      let pkg_name = self.parse_package()
      if self.match_symbol(";") {
        if pkg is Some(_) || nested {
          raise self.error("duplicate package declaration")
        }
        pkg = Some(pkg_name)
      } else {
        self.expect_symbol("{")
        packages.push(self.parse_file(Some(pkg_name), true, depth + 1))
      }
      continue
    }
    if self.match_keyword("use") {
      let path = self.parse_use_path()
      let name = if self.match_keyword("as") {
        self.expect_ident()
      } else {
        path.interface
      }
      self.expect_symbol(";")
      if aliases.contains(name) {
        raise self.error("duplicate top-level use: " + name)
      }
      aliases.set(name, path)
      continue
    }
    if self.match_keyword("interface") {
      interfaces.push(self.parse_interface(item_docs))
      continue
    }
    if self.match_keyword("world") {
      worlds.push(self.parse_world(item_docs))
      continue
    }
    raise self.error("unexpected top-level item")
  }
  let interfaces = interfaces.map(iface => {
    if aliases.contains(iface.name) {
      raise self.error("duplicate top-level name: " + iface.name)
    }
    { ..iface, items: expand_interface_uses(iface.items, aliases), }
  })
  let worlds = worlds.map(world => {
    if aliases.contains(world.name) {
      raise self.error("duplicate top-level name: " + world.name)
    }
    {
      ..world,
      imports: world.imports.map(item => expand_world_uses(item, aliases)),
      exports: world.exports.map(item => expand_world_uses(item, aliases)),
    }
  })
  { pkg, interfaces, worlds, packages, }
}

///|
fn expand_use_path(
  path : UsePath,
  aliases : Map[String, UsePath],
) -> UsePath raise ParseError {
  let mut path = path
  let seen : Map[String, Bool] = Map([])
  while path.pkg is None {
    match aliases.get(path.interface) {
      Some(next) => {
        if seen.contains(path.interface) {
          raise ParseError::Message("cyclic top-level use", 0)
        }
        seen.set(path.interface, true)
        path = next
      }
      None => break
    }
  }
  path
}

///|
fn expand_interface_uses(
  items : Array[InterfaceItem],
  aliases : Map[String, UsePath],
) -> Array[InterfaceItem] raise ParseError {
  items.map(item => {
    match item {
      Use(decl) => Use({ ..decl, from: expand_use_path(decl.from, aliases), })
      _ => item
    }
  })
}

///|
fn expand_world_uses(
  item : WorldItem,
  aliases : Map[String, UsePath],
) -> WorldItem raise ParseError {
  match item {
    Interface(path) => Interface(expand_use_path(path, aliases))
    NamedInterface(name, path) =>
      NamedInterface(name, expand_use_path(path, aliases))
    External(id, item) => External(id, expand_world_uses(item, aliases))
    Include(decl) =>
      Include({ ..decl, path: expand_use_path(decl.path, aliases), })
    Use(decl) => Use({ ..decl, from: expand_use_path(decl.from, aliases), })
    InlineInterface(iface) =>
      InlineInterface({
        ..iface,
        items: expand_interface_uses(iface.items, aliases),
      })
    _ => item
  }
}

///|
fn Parser::match_ident(self : Parser, name : String) -> Bool {
  if self.peek().token_type == Ident(name) {
    ignore(self.advance())
    true
  } else {
    false
  }
}

///|
fn Parser::parse_list_size(self : Parser) -> UInt32 raise ParseError {
  let value = match self.peek().token_type {
    Number(value) => value
    _ => raise self.error("expected fixed list size")
  }
  let mut size = 0U
  for ch in value {
    if !ch.is_ascii_digit() {
      raise self.error("expected integer list size")
    }
    let digit = (ch.to_int() - '0'.to_int()).reinterpret_as_uint()
    if size > (4294967295U - digit) / 10U {
      raise self.error("fixed list size exceeds u32")
    }
    size = size * 10U + digit
  }
  ignore(self.advance())
  size
}

///|
fn async_function_kind(kind : FunctionKind) -> FunctionKind {
  match kind {
    Freestanding => AsyncFreestanding
    Method(name) => AsyncMethod(name)
    Static(name) => AsyncStatic(name)
    _ => kind
  }
}

///|
fn Parser::is_named_interface_decl(self : Parser) -> Bool {
  self.peek_n(1).token_type == Symbol(":") &&
  self.peek_n(1).offset + 1 < self.peek_n(2).offset
}

///|
fn annotate_interface_item(
  item : InterfaceItem,
  external_id : String?,
) -> InterfaceItem raise ParseError {
  match item {
    Function(func) => Function({ ..func, external_id, })
    TypeDef(def) => TypeDef({ ..def, external_id, })
    Use(_) => {
      if external_id is Some(_) {
        raise ParseError::Message("external-id is not allowed on use", 0)
      }
      item
    }
  }
}

///|
fn annotate_world_item(
  item : WorldItem,
  external_id : String?,
) -> WorldItem raise ParseError {
  match (item, external_id) {
    (Function(func), _) => Function({ ..func, external_id, })
    (Use(_) | Include(_), Some(_)) =>
      raise ParseError::Message("external-id is not allowed on use/include", 0)
    (_, Some(id)) => External(id, item)
    (_, None) => item
  }
}

///|
fn Parser::parse_function_kind(
  self : Parser,
  kind : FunctionKind,
) -> FunctionKind raise ParseError {
  if self.match_keyword("async") {
    self.expect_keyword("func")
    return async_function_kind(kind)
  }
  if self.match_keyword("func") {
    return kind
  }
  let getter = self.match_ident("get")
  if !getter && !self.match_ident("set") {
    raise self.error("expected func, get, or set")
  }
  match (kind, getter) {
    (Freestanding, true) => Getter
    (Freestanding, false) => Setter
    (Method(name), true) => MethodGetter(name)
    (Method(name), false) => MethodSetter(name)
    (Static(name), true) => StaticGetter(name)
    (Static(name), false) => StaticSetter(name)
    _ => raise self.error("invalid property kind")
  }
}

///|
fn Parser::validate_accessor_signature(
  self : Parser,
  kind : FunctionKind,
  params : Array[Param],
  result : TypeExpr?,
) -> Unit raise ParseError {
  match kind {
    Getter | MethodGetter(_) | StaticGetter(_) =>
      if params.length() != 0 || result is None {
        raise self.error("getters require no parameters and one result")
      }
    Setter | MethodSetter(_) | StaticSetter(_) =>
      if params.length() != 1 {
        raise self.error("setters require one parameter")
      }
    _ => ()
  }
}

///|
fn valid_wit_identifier(name : String) -> Bool {
  for part in name.split("-") {
    let mut first = true
    let mut has_lower = false
    let mut has_upper = false
    for ch in part {
      if first && !ch.is_ascii_alphabetic() {
        return false
      }
      first = false
      if ch >= 'a' && ch <= 'z' {
        has_lower = true
      } else if ch >= 'A' && ch <= 'Z' {
        has_upper = true
      } else if !ch.is_ascii_digit() {
        return false
      }
    }
    if first || (has_lower && has_upper) {
      return false
    }
  }
  name != ""
}

///|
fn valid_semver(version : String) -> Bool {
  let (core, build) = match version.split_once("+") {
    Some((core, build)) => (core, Some(build))
    None => (version[:], None)
  }
  if build is Some(build) && !valid_version_identifiers(build, false) {
    return false
  }
  let (core, prerelease) = match core.split_once("-") {
    Some((core, prerelease)) => (core, Some(prerelease))
    None => (core, None)
  }
  if prerelease is Some(prerelease) &&
    !valid_version_identifiers(prerelease, true) {
    return false
  }
  let numbers = core.split(".").to_array()
  if numbers.length() != 3 {
    return false
  }
  numbers.all(number => valid_version_number(number))
}

///|
fn valid_version_number(number : StringView) -> Bool {
  number != "" &&
  (number == "0" || !number.has_prefix("0")) &&
  number.iter().all(ch => ch.is_ascii_digit())
}

///|
fn valid_version_identifiers(text : StringView, prerelease : Bool) -> Bool {
  text
  .split(".")
  .all(part => {
    if part == "" {
      return false
    }
    if !part
      .iter()
      .all(ch => (ch.is_ascii_alphabetic() || ch.is_ascii_digit()) || ch == '-') {
      return false
    }
    if prerelease && part.iter().all(ch => ch.is_ascii_digit()) {
      return valid_version_number(part)
    }
    true
  })
}
