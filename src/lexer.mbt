///|
#derive(Eq, Debug)
pub enum TokenType {
  Ident(String)
  ExplicitIdent(String)
  Keyword(String)
  Symbol(String)
  StringLit(String)
  Number(String)
  Doc(String)
  Eof
}

///|
pub impl Show for TokenType with fn to_string(self) {
  repr(self)
}

///|
#derive(Eq, Debug)
pub struct Token {
  token_type : TokenType
  offset : Int32
}

///|
pub impl Show for Token with fn to_string(self) {
  repr(self)
}

///|
priv struct Lexer {
  input : Array[Char]
  mut pos : Int32
}

///|
fn Lexer::new(source : String) -> Lexer {
  let input = source.to_array()
  let pos = if input.length() > 0 && input[0] == '\u{feff}' { 1 } else { 0 }
  { input, pos, }
}

///|
fn Lexer::peek_char(self : Lexer) -> Char? {
  if self.pos < self.input.length() {
    Some(self.input[self.pos])
  } else {
    None
  }
}

///|
fn Lexer::peek_next(self : Lexer) -> Char? {
  let idx = self.pos + 1
  if idx < self.input.length() {
    Some(self.input[idx])
  } else {
    None
  }
}

///|
fn Lexer::advance(self : Lexer) -> Char? {
  if self.pos < self.input.length() {
    let c = self.input[self.pos]
    self.pos += 1
    Some(c)
  } else {
    None
  }
}

///|
fn is_ident_start(c : Char) -> Bool {
  c.is_ascii_alphabetic() || c == '_'
}

///|
fn is_ident_continue(c : Char) -> Bool {
  is_ident_start(c) || c.is_ascii_digit() || c == '-'
}

///|
fn is_keyword(name : String) -> Bool {
  match name {
    "package"
    | "world"
    | "interface"
    | "include"
    | "as"
    | "with"
    | "from"
    | "record"
    | "enum"
    | "flags"
    | "variant"
    | "resource"
    | "func"
    | "constructor"
    | "import"
    | "export"
    | "use"
    | "type"
    | "list"
    | "option"
    | "result"
    | "tuple"
    | "future"
    | "stream"
    | "map"
    | "error-context"
    | "own"
    | "borrow"
    | "async"
    | "static"
    | "bool"
    | "u8"
    | "u16"
    | "u32"
    | "u64"
    | "s8"
    | "s16"
    | "s32"
    | "s64"
    | "f32"
    | "f64"
    | "char"
    | "string" => true
    _ => false
  }
}

///|
fn Lexer::skip_whitespace(self : Lexer) -> Unit {
  while true {
    match self.peek_char() {
      Some(c) if c.is_ascii_whitespace() => {
        let _ = self.advance()
      }
      _ => break
    }
  }
}

///|
fn Lexer::read_ident(self : Lexer) -> String {
  let buf = StringBuilder()
  while true {
    match self.peek_char() {
      Some(c) if is_ident_continue(c) => {
        buf.write_char(c)
        let _ = self.advance()
      }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn Lexer::read_number(self : Lexer) -> String {
  let buf = StringBuilder()
  while true {
    match self.peek_char() {
      Some(c) if c.is_ascii_digit() => {
        buf.write_char(c)
        let _ = self.advance()
      }
      Some('.') =>
        // Only consume '.' if followed by a digit (e.g., 0.2.9)
        // Don't consume trailing '.' (e.g., in 0.2.9.{...})
        match self.peek_next() {
          Some(next) if next.is_ascii_digit() => {
            buf.write_char('.')
            let _ = self.advance()
          }
          _ => break
        }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn Lexer::read_line_comment(self : Lexer) -> String {
  let buf = StringBuilder()
  while true {
    match self.peek_char() {
      Some('\n') | None => break
      Some(c) => {
        buf.write_char(c)
        let _ = self.advance()
      }
    }
  }
  buf.to_string()
}

///|
fn Lexer::read_string(self : Lexer) -> String raise ParseError {
  let start = self.pos
  ignore(self.advance())
  let buf : Array[Byte] = []
  while true {
    match self.advance() {
      None => raise ParseError::Message("unterminated string", start)
      Some('"') => break
      Some('\\') => {
        let ch = match self.advance() {
          Some(ch) => ch
          None => raise ParseError::Message("unterminated escape", start)
        }
        match ch {
          'n' => buf.push(b'\n')
          't' => buf.push(b'\t')
          'r' => buf.push(b'\r')
          '"' => buf.push(b'"')
          '\'' => buf.push(b'\'')
          '\\' => buf.push(b'\\')
          'u' => {
            if self.advance() != Some('{') {
              raise ParseError::Message(
                "expected '{' in unicode escape",
                self.pos,
              )
            }
            let mut value = self.read_hex_digit()
            let mut trailing_separator = false
            while self.peek_char() != Some('}') {
              if self.peek_char() == Some('_') {
                ignore(self.advance())
                trailing_separator = true
              } else {
                let digit = self.read_hex_digit()
                if value > (0x10ffff - digit) / 16 {
                  raise ParseError::Message("invalid unicode scalar", self.pos)
                }
                value = value * 16 + digit
                trailing_separator = false
              }
            }
            if trailing_separator {
              raise ParseError::Message(
                "trailing underscore in unicode escape",
                self.pos,
              )
            }
            ignore(self.advance())
            let scalar = match value.to_char() {
              Some(ch) => ch
              None =>
                raise ParseError::Message("invalid unicode scalar", self.pos)
            }
            append_utf8_char(buf, scalar)
          }
          _ => {
            let first = match hex_digit(ch) {
              Some(n) => n
              None =>
                raise ParseError::Message("invalid string escape", self.pos - 1)
            }
            let second = self.read_hex_digit()
            buf.push((first * 16 + second).to_byte())
          }
        }
      }
      Some(ch) => {
        if ch.to_int() < 0x20 || ch.to_int() == 0x7f {
          raise ParseError::Message("control character in string", self.pos - 1)
        }
        append_utf8_char(buf, ch)
      }
    }
  }
  @utf8.decode(Bytes::from_array(buf)[:], ignore_bom=false) catch {
    _ => raise ParseError::Message("invalid UTF-8 string", start)
  }
}

///|
fn tokenize_raise(source : String) -> Array[Token] raise ParseError {
  let lexer = Lexer::new(source)
  let tokens : Array[Token] = []
  while true {
    lexer.skip_whitespace()
    let offset = lexer.pos
    match lexer.peek_char() {
      None => {
        tokens.push({ token_type: Eof, offset, })
        break
      }
      Some('/') if lexer.peek_next() == Some('/') => {
        let _ = lexer.advance()
        let _ = lexer.advance()
        let is_doc = lexer.peek_char() == Some('/')
        if is_doc {
          ignore(lexer.advance())
        }
        let text = lexer.read_line_comment().trim().to_owned()
        if is_doc {
          tokens.push({ token_type: Doc(text), offset, })
        }
      }
      Some('/') if lexer.peek_next() == Some('*') =>
        if lexer.read_block_comment() is Some(contents) {
          tokens.push({ token_type: Doc(contents), offset, })
        }
      Some('%') => {
        let _ = lexer.advance()
        match lexer.peek_char() {
          Some(c) if is_ident_start(c) => {
            let ident = lexer.read_ident()
            tokens.push({ token_type: ExplicitIdent(ident), offset, })
          }
          _ => raise ParseError::Message("expected identifier after %", offset)
        }
      }
      Some(c) if is_ident_start(c) => {
        let ident = lexer.read_ident()
        let token_type = if is_keyword(ident) {
          Keyword(ident)
        } else {
          Ident(ident)
        }
        tokens.push({ token_type, offset, })
      }
      Some(c) if c.is_ascii_digit() => {
        let num = lexer.read_number()
        tokens.push({ token_type: Number(num), offset, })
      }
      Some('"') => {
        let value = lexer.read_string()
        tokens.push({ token_type: StringLit(value), offset, })
      }
      Some('-') =>
        match lexer.peek_next() {
          Some('>') => {
            let _ = lexer.advance()
            let _ = lexer.advance()
            tokens.push({ token_type: Symbol("->"), offset, })
          }
          _ => {
            let _ = lexer.advance()
            tokens.push({ token_type: Symbol("-"), offset, })
          }
        }
      Some(c) => {
        let _ = lexer.advance()
        let sym = match c {
          '{' => "{"
          '}' => "}"
          '(' => "("
          ')' => ")"
          '<' => "<"
          '>' => ">"
          ':' => ":"
          ';' => ";"
          ',' => ","
          '.' => "."
          '/' => "/"
          '@' => "@"
          '=' => "="
          '+' => "+"
          _ => ""
        }
        if sym == "" {
          raise ParseError::Message("unexpected character", offset)
        }
        tokens.push({ token_type: Symbol(sym), offset, })
      }
    }
  }
  tokens
}

///|
#warnings("-78")
pub fn tokenize(source : String) -> Result[Array[Token], ParseError] {
  Ok(tokenize_raise(source)) catch {
    e => Err(e)
  }
}

///|
pub extend TokenType with Eq::{not_equal, equal}

///|
pub extend TokenType with Debug::{to_repr}

///|
pub extend TokenType with Show::{to_string, output}

///|
pub extend Token with Eq::{not_equal, equal}

///|
pub extend Token with Debug::{to_repr}

///|
pub extend Token with Show::{to_string, output}

///|
fn Lexer::read_block_comment(self : Lexer) -> String? raise ParseError {
  let offset = self.pos
  ignore(self.advance())
  ignore(self.advance())
  let is_doc = self.peek_char() == Some('*')
  let contents = StringBuilder()
  let mut depth = 1
  while depth > 0 {
    match (self.peek_char(), self.peek_next()) {
      (None, _) =>
        raise ParseError::Message("unterminated block comment", offset)
      (Some('/'), Some('*')) => {
        ignore(self.advance())
        ignore(self.advance())
        depth += 1
        contents.write_string("/*")
      }
      (Some('*'), Some('/')) => {
        ignore(self.advance())
        ignore(self.advance())
        depth -= 1
        if depth > 0 {
          contents.write_string("*/")
        }
      }
      (Some(ch), _) => {
        ignore(self.advance())
        contents.write_char(ch)
      }
    }
  }
  if !is_doc {
    return None
  }
  let text = contents.to_string()
  let text = if text.has_prefix("*") { text[1:].to_owned() } else { text }
  let lines = text
    .split("\n")
    .map(line => {
      let line = line.trim()
      if line.has_prefix("*") {
        line[1:].trim().to_owned()
      } else {
        line.to_owned()
      }
    })
    .to_array()
  Some(join_docs(lines).trim().to_owned())
}

///|
fn hex_digit(ch : Char) -> Int32? {
  if ch >= '0' && ch <= '9' {
    Some(ch.to_int() - '0'.to_int())
  } else if ch >= 'a' && ch <= 'f' {
    Some(ch.to_int() - 'a'.to_int() + 10)
  } else if ch >= 'A' && ch <= 'F' {
    Some(ch.to_int() - 'A'.to_int() + 10)
  } else {
    None
  }
}

///|
fn Lexer::read_hex_digit(self : Lexer) -> Int32 raise ParseError {
  match self.advance() {
    Some(ch) =>
      match hex_digit(ch) {
        Some(n) => n
        None => raise ParseError::Message("invalid hex digit", self.pos - 1)
      }
    None => raise ParseError::Message("unterminated hex escape", self.pos)
  }
}

///|
fn append_utf8_char(buf : Array[Byte], ch : Char) -> Unit {
  for byte in @utf8.encode(ch.to_string()[:]) {
    buf.push(byte)
  }
}
