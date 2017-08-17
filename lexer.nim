import lexbase, strutils, streams, unicode, os

type
  Lexer = object of BaseLexer
    nextState: LexerState
    tokenStartPos: int
    c: char

  TokenKind = enum
    tkEof, tkComment, tkNestedComment, tkIdentifier, tkNumber, tkFloat
    tkString, tkCharLit, tkColon, tkColonColon, tkSemiColon, tkAccent
    tkComma, tkDot, tkDotDot, tkOpr
    tkParLe, tkParRi, tkCurlyLe, tkCurlyRi, tkBracketLe, tkBracketRi

  Token = object
    kind: TokenKind
    indent: int
    literal: string
    line, col: int

  LexerState = proc(lex: var Lexer, tok: var Token): bool {.locks: 0, gcSafe.}

  LexerError* = object of Exception
    line*, column*: int
    lineContent*: string

const
  LineEnd        = {'\l', '\c', EndOfFile}
  OctalDigits    = {'0'..'7'}
  BinaryDigits   = {'0'..'1'}
  OpChars        = {'+', '-', '*', '/', '\\', '<', '>', '!', '?', '^', '.',
                    '|', '=', '%', '&', '$', '@', '~', ':', '\x80'..'\xFF'}

{.push gcSafe, locks: 0.}
proc stateOuterScope(lex: var Lexer, tok: var Token): bool
proc stateLineComment(lex: var Lexer, tok: var Token): bool
proc stateNestedComment(lex: var Lexer, tok: var Token): bool
proc stateIdentifier(lex: var Lexer, tok: var Token): bool
proc stateNumber(lex: var Lexer, tok: var Token): bool
proc stateString(lex: var Lexer, tok: var Token): bool
proc stateCharLit(lex: var Lexer, tok: var Token): bool
{.pop.}

proc initLexer(stream: Stream): Lexer =
  result.open(stream)
  result.nextState = stateOuterScope
  result.c = result.buf[result.bufpos]

proc advance(lex: var Lexer, step = 1) =
  lex.bufpos.inc(step)
  lex.c = lex.buf[lex.bufpos]

proc nextChar(lex: Lexer): char =
  result = lex.buf[lex.bufpos + 1]

proc tokenLen(lex: Lexer): int =
  result = lex.bufpos - lex.tokenStartPos

proc tokenLit(lex: Lexer): string =
  result = newString(lex.tokenLen)
  copyMem(result.cstring, lex.buf[lex.tokenStartPos].unsafeAddr, result.len)

proc next*(lex: var Lexer, tok: var Token) =
  while not lex.nextState(lex, tok): discard

proc lexError(lex: Lexer, message: string): ref LexerError {.raises: [].} =
  result = newException(LexerError, message)
  result.line = lex.lineNumber
  result.column = lex.getColNumber(lex.bufpos)
  result.lineContent = lex.getCurrentLine

proc lexCR(lex: var Lexer) =
  lex.bufpos = lex.handleCR(lex.bufpos)
  lex.c = lex.buf[lex.bufpos]

proc lexLF(lex: var Lexer) =
  lex.bufpos = lex.handleLF(lex.bufpos)
  lex.c = lex.buf[lex.bufpos]

proc stateOuterScope(lex: var Lexer, tok: var Token): bool =  
  let lineStart = lex.getColNumber(lex.bufpos) == 0
  
  while lex.c == ' ':
    lex.advance
    
  tok.line = lex.lineNumber
  if lineStart:
    tok.indent = lex.getColNumber(lex.bufpos)
    
  case lex.c
  of '#':
    tok.col = lex.getColNumber(lex.bufpos)
    if lex.nextChar == '[':
      tok.kind = tkNestedComment
      lex.nextState = stateNestedComment
    else:
      tok.kind = tkComment
      lex.nextState = stateLineComment
    return false
  of '\t':
    raise lexError(lex, "tabs are not allowed")
  of '\c':
    lex.lexCR
    return false
  of '\l':
    lex.lexLF
    return false
  of EndOfFile:
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkEof
    return true
  of IdentStartChars:
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkIdentifier
    lex.nextState = stateIdentifier
    return false
  of Digits:
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkNumber
    lex.nextState = stateNumber
    return false
  of '"':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkString
    lex.nextState = stateString
    return false
  of '\'':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkCharLit
    lex.nextState = stateCharLit
    return false
  of ':':
    tok.col = lex.getColNumber(lex.bufpos)
    if lex.nextChar == ':':
      lex.advance
      tok.kind = tkColonColon
    else:
      tok.kind = tkColon
    lex.advance
    return true
  of ';':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkSemiColon
    lex.advance
    return true
  of '`':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkAccent
    lex.advance
    return true
  of '(':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkParLe
    lex.advance
    return true
  of ')':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkParRi
    lex.advance
    return true
  of '{':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkCurlyLe
    lex.advance
    return true
  of '}':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkCurlyRi
    lex.advance
    return true
  of '[':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkBracketLe
    lex.advance
    return true
  of ']':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkBracketRi
    lex.advance
    return true
  of ',':
    tok.col = lex.getColNumber(lex.bufpos)
    tok.kind = tkComma
    lex.advance
    return true
  of '.':
    tok.col = lex.getColNumber(lex.bufpos)
    if lex.nextChar == ':':
      lex.advance
      tok.kind = tkDotDot
    else:
      tok.kind = tkDot
    lex.advance
    return true
  else:
    if lex.c in OpChars:
      tok.col = lex.getColNumber(lex.bufpos)
      tok.kind = tkOpr
      lex.advance
      return true
    else:
      raise lexError(lex, "unexpected token: '" & $lex.c & "'")
        
  result = true

proc stateLineComment(lex: var Lexer, tok: var Token): bool =
  while lex.c notin LineEnd:
    lex.advance
  lex.nextState = stateOuterScope
  result = true

proc stateNestedComment(lex: var Lexer, tok: var Token): bool =
  lex.advance # skip '['
  var level = 1
  while true:
    case lex.c
    of '\c':
      lex.lexCR
    of '\l':
      lex.lexLF
    of '#':
      if lex.nextChar == '[':
        lex.advance
        inc(level)
      lex.advance
    of ']':
      if lex.nextChar == '#':
        lex.advance
        dec(level)
        if level == 0:
          lex.advance
          lex.nextState = stateOuterScope
          return true
      lex.advance
    of EndOfFile:
      raise lexError(lex, "unexpected end of file in multi line comment")
    else:
      lex.advance

proc stateIdentifier(lex: var Lexer, tok: var Token): bool =
  while lex.c in IdentChars:
    lex.advance
  lex.nextState = stateOuterScope
  result = true

proc stateNumber(lex: var Lexer, tok: var Token): bool =
  template matchChars(lex: var Lexer, chars: set[char]) =
    while true:
      while lex.c in chars:
        lex.advance

      if lex.c == '_':
        lex.advance
        if lex.c notin chars:
          raise lexError(lex, "invalid token '_'")

      if lex.c notin chars:
        break

  var ordinaryNumber = false
  if lex.c == '0':
    let nc = lex.nextChar
    lex.advance
    case nc
    of 'x', 'X':
      lex.advance
      lex.matchChars(HexDigits)
    of 'c', 'o', 'C', 'O':
      lex.advance
      lex.matchChars(OctalDigits)
    of 'b', 'B':
      lex.advance
      lex.matchChars(BinaryDigits)
    else:
      ordinaryNumber = true
  else:
    ordinaryNumber = true

  if ordinaryNumber:
    lex.matchChars(Digits)
    if lex.c == '.':
      lex.advance
      tok.kind = tkFloat

    if tok.kind == tkFloat:
      while lex.c in Digits:
        lex.advance

      if lex.c in {'e', 'E'}:
        lex.advance

      if lex.c in {'+', '-'}:
        lex.advance

        while lex.c in Digits:
          lex.advance

  lex.nextState = stateOuterScope
  result = true

proc getEscapedChar(lex: var Lexer, tok: var Token) =
  lex.advance
  case lex.c
  of 'r', 'c', 'R', 'C': lex.advance
  of 'l', 'L': lex.advance
  of 'f', 'F': lex.advance
  of 't', 'T': lex.advance
  of 'v', 'V': lex.advance
  of 'n', 'N': lex.advance
  of '\\': lex.advance
  of '"': lex.advance
  of '\'': lex.advance
  of 'a': lex.advance
  of 'b': lex.advance
  of 'e': lex.advance
  of Digits:
    while lex.c in Digits:
      lex.advance
  of 'x':
    lex.advance
    while lex.c in HexDigits:
      lex.advance
  else:
    raise lexError(lex, "wrong escape character in string '" & $lex.c & "'")

proc stateString(lex: var Lexer, tok: var Token): bool =
  lex.advance
  while true:
    case lex.c
    of LineEnd:
      raise lexError(lex, "closing quote expected")
    of '\\':
      lex.getEscapedChar(tok)
    of '"':
      lex.advance
      break
    else:
      lex.advance

  lex.nextState = stateOuterScope
  result = true

proc stateCharLit(lex: var Lexer, tok: var Token): bool =
  lex.advance
  case lex.c
  of '\0'..pred(' '), '\'':
    raise lexError(lex, "invalid character constant '0x" & toHex(ord(lex.c), 2) & "'")
  of '\\':
    lex.getEscapedChar(tok)
  else:
    lex.advance

  if lex.c != '\'':
    raise lexError(lex, "missing final quote")

  lex.advance
  lex.nextState = stateOuterScope
  result = true

proc initToken(): Token =
  result.kind = tkEof
  result.indent = -1
  result.literal = ""
  result.line = 0
  result.col = 0

proc nextToken(lex: var Lexer): bool =
  var tok = initToken()
  lex.next(tok)
  echo tok
  result = tok.kind != tkEof

proc main() =
  var input = newFileStream(paramStr(1))
  var lex = initLexer(input)
  while lex.nextToken(): discard

main()

