///|
pub enum TokenType {
  Ident(String)
  Keyword(String)
  Symbol(String)
  StringLit(String)
  Number(String)
  Doc(String)
  Eof
} derive(Show, Eq)

///|
pub struct Token {
  token_type : TokenType
  offset : Int
} derive(Show, Eq)

///|
priv struct Lexer {
  input : Array[Char]
  mut pos : Int
}

///|
fn Lexer::new(source : String) -> Lexer {
  { input: source.to_array(), pos: 0 }
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
  let buf = StringBuilder::new()
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
  let buf = StringBuilder::new()
  while true {
    match self.peek_char() {
      Some(c) if c.is_ascii_digit() || c == '.' => {
        buf.write_char(c)
        let _ = self.advance()

      }
      _ => break
    }
  }
  buf.to_string()
}

///|
fn Lexer::read_line_comment(self : Lexer) -> String {
  let buf = StringBuilder::new()
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
  let _ = self.advance()
  let buf = StringBuilder::new()
  while true {
    match self.peek_char() {
      None => raise ParseError::Message("unterminated string", start)
      Some('"') => {
        let _ = self.advance()
        break
      }
      Some('\\') => {
        let _ = self.advance()
        match self.peek_char() {
          Some('n') => {
            let _ = self.advance()
            buf.write_char('\n')
          }
          Some('t') => {
            let _ = self.advance()
            buf.write_char('\t')
          }
          Some('r') => {
            let _ = self.advance()
            buf.write_char('\r')
          }
          Some('"') => {
            let _ = self.advance()
            buf.write_char('"')
          }
          Some('\\') => {
            let _ = self.advance()
            buf.write_char('\\')
          }
          Some(other) => {
            let _ = self.advance()
            buf.write_char(other)
          }
          None => raise ParseError::Message("unterminated escape", start)
        }
      }
      Some(c) => {
        let _ = self.advance()
        buf.write_char(c)
      }
    }
  }
  buf.to_string()
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
        tokens.push({ token_type: Eof, offset })
        break
      }
      Some('/') if lexer.peek_next() == Some('/') => {
        let _ = lexer.advance()
        let _ = lexer.advance()
        if lexer.peek_char() == Some('/') {
          let _ = lexer.advance()

        }
        let text = lexer.read_line_comment().trim().to_string()
        tokens.push({ token_type: Doc(text), offset })
      }
      Some('%') => {
        let _ = lexer.advance()
        match lexer.peek_char() {
          Some(c) if is_ident_start(c) => {
            let ident = lexer.read_ident()
            tokens.push({ token_type: Ident(ident), offset })
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
        tokens.push({ token_type, offset })
      }
      Some(c) if c.is_ascii_digit() => {
        let num = lexer.read_number()
        tokens.push({ token_type: Number(num), offset })
      }
      Some('"') => {
        let value = lexer.read_string()
        tokens.push({ token_type: StringLit(value), offset })
      }
      Some('-') =>
        match lexer.peek_next() {
          Some('>') => {
            let _ = lexer.advance()
            let _ = lexer.advance()
            tokens.push({ token_type: Symbol("->"), offset })
          }
          _ => {
            let _ = lexer.advance()
            tokens.push({ token_type: Symbol("-"), offset })
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
        tokens.push({ token_type: Symbol(sym), offset })
      }
    }
  }
  tokens
}

///|
pub fn tokenize(source : String) -> Result[Array[Token], ParseError] {
  try? tokenize_raise(source)
}
