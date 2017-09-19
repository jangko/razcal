import lexbase, strutils, streams, idents, keywords, razcontext, types

type
  Lexer* = object of BaseLexer
    context*: RazContext
    nextState: LexerState
    tokenStartPos: int
    fileIndex*: int32
    c: char

  # this must be keep in sync with TokenKindToStr array
  TokenKind* = enum
    tkInvalid, tkEof, tkComment, tkNestedComment
    tkIdent, tkNumber, tkFloat, tkString, tkCharLit
    tkSemiColon, tkAccent, tkComma
    tkParLe, tkParRi, tkCurlyLe, tkCurlyRi, tkBracketLe, tkBracketRi

    # tkDot..tkProp must be keep in sync with
    # keywords.SpecialWords
    tkDot, tkDotDot, tkColon, tkColonColon
    tkBang, tkChoice, tkPercent, tkAt
    tkEquals, tkGreaterOrEqual, tkLessOrEqual, tkOpr

    tkProgram, tkStyle, tkAlias, tkFlex, tkEvent, tkProp

  TokenVal* = object {.union.}
    iNumber*: uint64
    fNumber*: float64
    ident*: Ident

  Token* {.acyclic.} = object
    kind*: TokenKind
    val*: TokenVal
    indent*: int
    literal*: string
    line*, col*: int

  LexerState = proc(lex: var Lexer, tok: var Token): bool {.locks: 0, gcSafe.}

const
  LineEnd        = {'\l', '\c', EndOfFile}
  OctalDigits    = {'0'..'7'}
  BinaryDigits   = {'0'..'1'}
  OpChars        = {'+', '-', '*', '/', '\\', '<', '>', '!', '?', '^', '.',
                    '|', '=', '%', '&', '$', '@', '~', ':', '\x80'..'\xFF'}

  TokenKindToStr: array[TokenKind, string] = [
    "tkInvalid", "[EOF]", "tkComment", "tkNestedComment",
    "tkIdent", "tkNumber", "tkFloat", "tkString", "tkCharLit",
    ";", "`", ",", "(", ")", "{", "}", "[", "]",
    ".", "..", ":", "::", "!", "|", "%", "@", "=", ">=", "<=", "tkOpr",
    "program", "style", "alias", "flex", "event", "prop"]

proc toString*(kind: TokenKind): string =
  result = "`" & TokenKindToStr[kind] & "`"

const
  Tabulator* = '\x09'
  ESC* = '\x1B'
  CR* = '\x0D'
  FF* = '\x0C'
  LF* = '\x0A'
  BEL* = '\x07'
  BACKSPACE* = '\x08'
  VT* = '\x0B'

{.push gcSafe, locks: 0.}
proc stateOuterScope(lex: var Lexer, tok: var Token): bool
proc stateLineComment(lex: var Lexer, tok: var Token): bool
proc stateNestedComment(lex: var Lexer, tok: var Token): bool
proc stateIdentifier(lex: var Lexer, tok: var Token): bool
proc stateNumber(lex: var Lexer, tok: var Token): bool
proc stateString(lex: var Lexer, tok: var Token): bool
proc stateCharLit(lex: var Lexer, tok: var Token): bool
proc stateOperator(lex: var Lexer, tok: var Token): bool
{.pop.}

proc openLexer*(stream: Stream, context: RazContext, fileIndex: int32): Lexer =
  result.fileIndex = fileIndex
  result.open(stream)
  result.nextState = stateOuterScope
  result.c = result.buf[result.bufpos]
  result.context = context

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

proc getToken*(lex: var Lexer, tok: var Token) =
  while not lex.nextState(lex, tok): discard

proc error(lex: Lexer, kind: MsgKind, args: varargs[string, `$`]) =
  var err = new(SourceError)
  err.msg = lex.context.msgKindToString(kind, args)
  err.line = lex.lineNumber
  err.column = lex.getColNumber(lex.bufpos)
  err.lineContent = lex.getCurrentLine(false)
  err.fileIndex = lex.fileIndex
  raise err

proc lexCR(lex: var Lexer) =
  lex.bufpos = lex.handleCR(lex.bufpos)
  lex.c = lex.buf[lex.bufpos]

proc lexLF(lex: var Lexer) =
  lex.bufpos = lex.handleLF(lex.bufpos)
  lex.c = lex.buf[lex.bufpos]

template singleToken(tokKind: TokenKind) =
  tok.col = lex.getColNumber(lex.bufpos)
  tok.kind = tokKind
  tok.literal.add lex.c
  lex.advance
  return true

#[template doubleToken(kindSingle: TokenKind, secondChar: char, kindDouble: TokenKind) =
  tok.col = lex.getColNumber(lex.bufpos)
  tok.literal.add lex.c
  if lex.nextChar == secondChar:
    lex.advance
    tok.kind = kindDouble
    tok.literal.add lex.c
  else:
    tok.kind = kindSingle
  lex.advance
  return true
]#

template tokenNextState(tokKind: TokenKind, nextStateProc: typed) =
  tok.col = lex.getColNumber(lex.bufpos)
  tok.kind = tokKind
  lex.nextState = nextStateProc
  return false

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
    lex.error(errTabsAreNotAllowed)
  of '\c':
    lex.lexCR
    return false
  of '\l':
    lex.lexLF
    return false
  of IdentStartChars: tokenNextState(tkIdent, stateIdentifier)
  of Digits: tokenNextState(tkNumber, stateNumber)
  of '"': tokenNextState(tkString, stateString)
  of '\'': tokenNextState(tkCharLit, stateCharLit)
  of EndOfFile:
    tok.indent = 0
    singleToken(tkEof)
  of ';': singleToken(tkSemiColon)
  of '`': singleToken(tkAccent)
  of '(': singleToken(tkParLe)
  of ')': singleToken(tkParRi)
  of '{': singleToken(tkCurlyLe)
  of '}': singleToken(tkCurlyRi)
  of '[': singleToken(tkBracketLe)
  of ']': singleToken(tkBracketRi)
  of ',': singleToken(tkComma)
  else:
    if lex.c in OpChars: tokenNextstate(tkOpr, stateOperator)
    else: lex.error(errInvalidToken, lex.c)

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
    of '\c': lex.lexCR
    of '\l': lex.lexLF
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
      lex.error(errUnexpectedEOLinMultiLineComment)
    else:
      lex.advance

proc stateIdentifier(lex: var Lexer, tok: var Token): bool =
  lex.tokenStartPos = lex.bufpos
  while lex.c in IdentChars:
    lex.advance

  tok.literal = lex.tokenLit
  tok.val.ident = lex.context.getIdent(tok.literal)
  if tok.val.ident.id > ord(wProgram) and tok.val.ident.id < ord(wThis):
    let id = tok.val.ident.id - ord(wProgram)
    tok.kind = TokenKind(id + ord(tkProgram))

  lex.nextState = stateOuterScope
  result = true

proc charToInt(c: char): int =
  case c
  of {'0'..'9'}: result = ord(c) - ord('0')
  of {'a'..'f'}: result = ord(c) - ord('a') + 10
  of {'A'..'F'}: result = ord(c) - ord('A') + 10
  else: result = 0

proc parseBoundedInt(lex: var Lexer, val: string, base: int, maxVal: uint64, start = 0): uint64 =
  result = 0
  for i in start.. <val.len:
    result = result * uint64(base)
    let c  = uint64(charToInt(val[i]))
    let ov = maxVal - result
    if c > ov:
      lex.error(errNumberOverflow)
    else: result += c

proc stateNumber(lex: var Lexer, tok: var Token): bool =
  type
    NumberType = enum
      UnknownNumber
      OrdinaryNumber
      HexNumber
      OctalNumber
      BinaryNumber
      FloatNumber

  template matchChars(lex: var Lexer, validRange, wideRange: set[char]) =
    while true:
      while lex.c in wideRange:
        if lex.c notin validRange:
          lex.error(errInvalidNumberRange, lex.c)
        tok.literal.add lex.c
        lex.advance

      if lex.c == '_':
        lex.advance
        if lex.c notin wideRange:
          lex.error(errInvalidToken, "_")

      if lex.c notin wideRange:
        break

  var numberType = UnknownNumber
  if lex.c == '0':
    let nc = lex.nextChar
    tok.literal.add lex.c
    lex.advance
    case nc
    of 'x', 'X':
      tok.literal.add lex.c
      lex.advance
      lex.matchChars(HexDigits, Letters + Digits)
      numberType = HexNumber
    of 'c', 'o', 'C', 'O':
      tok.literal.add lex.c
      lex.advance
      lex.matchChars(OctalDigits, Digits)
      numberType = OctalNumber
    of 'b', 'B':
      tok.literal.add lex.c
      lex.advance
      lex.matchChars(BinaryDigits, Digits)
      numberType = BinaryNumber
    else:
      numberType = OrdinaryNumber
  else:
    numberType = OrdinaryNumber

  if numberType == OrdinaryNumber:
    lex.matchChars(Digits, Digits)
    if lex.c == '.':
      tok.literal.add lex.c
      lex.advance
      tok.kind = tkFloat
      numberType = FloatNumber

    if tok.kind == tkFloat:
      lex.matchChars(Digits, Digits)

      if lex.c in {'e', 'E'}:
        tok.literal.add lex.c
        lex.advance

      if lex.c in {'+', '-'}:
        tok.literal.add lex.c
        lex.advance

        while lex.c in Digits:
          tok.literal.add lex.c
          lex.advance

  when defined(cpu64):
    const maxVal = 0xFFFFFFFF_FFFFFFFF'u64
  else:
    const maxVal = 0xFFFFFFFF'u32

  case numberType
  of OrdinaryNumber: tok.val.iNumber = lex.parseBoundedInt(tok.literal, 10, maxVal)
  of HexNumber: tok.val.iNumber = lex.parseBoundedInt(tok.literal, 16, maxVal, 2)
  of OctalNumber: tok.val.iNumber = lex.parseBoundedInt(tok.literal, 8, maxVal, 2)
  of BinaryNumber: tok.val.iNumber = lex.parseBoundedInt(tok.literal, 2, maxVal, 2)
  of FloatNumber: tok.val.fNumber = parseFloat(tok.literal)
  else: lex.error(errUnknownNumberType)

  lex.nextState = stateOuterScope
  result = true

proc handleHexChar(lex: var Lexer, xi: var int) =
  case lex.c
  of '0'..'9':
    xi = (xi shl 4) or (ord(lex.c) - ord('0'))
    lex.advance
  of 'a'..'f':
    xi = (xi shl 4) or (ord(lex.c) - ord('a') + 10)
    lex.advance
  of 'A'..'F':
    xi = (xi shl 4) or (ord(lex.c) - ord('A') + 10)
    lex.advance
  else: discard

proc handleDecChars(lex: var Lexer, xi: var int) =
  while lex.c in {'0'..'9'}:
    xi = (xi * 10) + (ord(lex.c) - ord('0'))
    lex.advance

template ones(n): untyped = ((1 shl n)-1) # for utf-8 conversion

proc getEscapedChar(lex: var Lexer, tok: var Token) =
  lex.advance
  case lex.c
  of 'r', 'c', 'R', 'C':
    tok.literal.add CR
    lex.advance
  of 'l', 'L', 'n', 'N':
    tok.literal.add LF
    lex.advance
  of 'f', 'F':
    tok.literal.add FF
    lex.advance
  of 't', 'T':
    tok.literal.add Tabulator
    lex.advance
  of 'v', 'V':
    tok.literal.add VT
    lex.advance
  of '\\', '"', '\'':
    tok.literal.add lex.c
    lex.advance
  of 'a', 'A':
    tok.literal.add BEL
    lex.advance
  of 'b', 'B':
    tok.literal.add BACKSPACE
    lex.advance
  of 'e', 'E':
    tok.literal.add ESC
    lex.advance
  of Digits:
    var xi = 0
    lex.handleDecChars(xi)
    if (xi <= 255): add(tok.literal, chr(xi))
    else: lex.error(errInvalidCharacterConstant, lex.c)
  of 'x', 'X', 'u', 'U':
    let tp = lex.c
    lex.advance
    var xi = 0
    lex.handleHexChar(xi)
    lex.handleHexChar(xi)
    if tp in {'u', 'U'}:
      lex.handleHexChar(xi)
      lex.handleHexChar(xi)
      # inlined toUTF-8 to avoid unicode and strutils dependencies.
      if xi <=% 127:
        add(tok.literal, xi.char)
      elif xi <=% 0x07FF:
        add(tok.literal, ((xi shr 6) or 0b110_00000).char)
        add(tok.literal, ((xi and ones(6)) or 0b10_0000_00).char)
      elif xi <=% 0xFFFF:
        add(tok.literal, (xi shr 12 or 0b1110_0000).char)
        add(tok.literal, (xi shr 6 and ones(6) or 0b10_0000_00).char)
        add(tok.literal, (xi and ones(6) or 0b10_0000_00).char)
      else: # value is 0xFFFF
        add(tok.literal, "\xef\xbf\xbf")
    else:
      add(tok.literal, chr(xi))
  else:
    lex.error(errWrongEscapeChar, lex.c)

proc stateString(lex: var Lexer, tok: var Token): bool =
  lex.advance
  while true:
    case lex.c
    of LineEnd:
      lex.error(errClosingQuoteExpected)
    of '\\':
      lex.getEscapedChar(tok)
    of '"':
      lex.advance
      break
    else:
      tok.literal.add lex.c
      lex.advance

  lex.nextState = stateOuterScope
  result = true

proc stateCharLit(lex: var Lexer, tok: var Token): bool =
  lex.advance
  case lex.c
  of '\0'..pred(' '), '\'':
    lex.error(errInvalidCharacterConstant, toHex(ord(lex.c), 2))
  of '\\':
    lex.getEscapedChar(tok)
  else:
    tok.literal.add lex.c
    lex.advance

  if lex.c != '\'':
    lex.error(errMissingFinalQuote)

  lex.advance
  lex.nextState = stateOuterScope
  result = true

proc stateOperator(lex: var Lexer, tok: var Token): bool =
  while lex.c in OpChars:
    tok.literal.add lex.c
    lex.advance

  tok.val.ident = lex.context.getIdent(tok.literal)
  if tok.val.ident.id >= ord(wDot) and tok.val.ident.id < ord(wProgram):
    let id = tok.val.ident.id - ord(wDot)
    tok.kind = TokenKind(id + ord(tkDot))

  lex.nextState = stateOuterScope
  result = true

proc initToken*(): Token =
  result.kind = tkInvalid
  result.indent = -1
  result.literal = ""
  result.line = 0
  result.col = 0

proc reset*(tok: var Token) =
  tok.kind = tkInvalid
  tok.indent = -1
  tok.literal.setLen(0)
  tok.line = 0
  tok.col = 0
