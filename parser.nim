import lexer, lexbase, idents, streams, os, ast

type
  Parser* = object
    currInd: int
    firstTok: bool
    hasProgress: bool
    lex*: Lexer
    tok*: Token

proc getTok(p: var Parser) =
  p.tok.reset()
  p.lex.getToken(p.tok)
  while p.tok.kind in {tkComment, tkNestedComment}:
    p.lex.getToken(p.tok)
  p.hasProgress = true

proc parError(p: var Parser, msg: string) =
  echo msg
  quit(1)

proc getLineInfo(p: Parser): LineInfo =
  result.line = int16(p.tok.line)
  result.col = int16(p.tok.col)
  result.fileIndex = -1

proc newNode(p: Parser, kind: NodeKind): Node =
  result = newNodeI(kind, p.getLineInfo)

proc initParser*(inputStream: Stream, identCache: IdentCache): Parser =
  result.tok = initToken()
  result.lex = initLexer(inputStream, identCache)
  result.getTok() # read the first token
  result.firstTok = true

proc close*(p: var Parser) =
  p.lex.close()

proc parseExpr(p: var Parser, minPrec: int): Node

proc primary(p: var Parser): Node =
  case p.tok.kind:
  of tkParLe:
    p.getTok()
    result = p.parseExpr(-1)
    if p.tok.kind != tkParRi:
      p.parError("unmatched '('")
  of tkEof:
    p.parError("source ended unexpectedly")
  of tkOpr:
    let a = newIdentNode(nkIdent, p.tok.val.ident)
    p.getTok()
    let b = p.primary()
    result = newTree(nkPrefix, a, b)
  of tkNumber:
    result = newIntNode(nkUInt, p.tok.val.iNumber)
    p.getTok()
  of tkFloat:
    result = newFloatNode(nkFloat, p.tok.val.fNumber)
    p.getTok()
  of tkIdent:
    result = newIdentNode(nkIdent, p.tok.val.ident)
    p.getTok()
  else:
    p.parError("unrecognized token: " & $p.tok.kind)

proc getPrecedence(tok: Token): int =
  case tok.literal[0]
  of '$', '^': result = 10
  of '*', '%', '/', '\\': result = 9
  of '~': result = 8
  of '+', '-', '|': result = 8
  of '&': result = 7
  of '=', '<', '>', '!': result = 5
  of '.': result = 6
  of '?': result = 2
  else: result = -1

proc isLeftAssoc(tok: Token): bool =
  result = tok.literal[0] != '^'

proc isBinary(tok: Token): bool =
  result = tok.kind in {tkOpr, tkDotDot}

proc parseExpr(p: var Parser, minPrec: int): Node =
  result = p.primary()
  var opPrec = getPrecedence(p.tok)
  while opPrec >= minPrec and p.tok.indent < 0 and isBinary(p.tok):
    let assoc = ord(isLeftAssoc(p.tok))
    opPrec = getPrecedence(p.tok)
    let opNode = newIdentNode(nkIdent, p.tok.val.ident)
    p.getTok()
    let rhs = p.parseExpr(opPrec + assoc)
    result = newTree(nkInfix, opNode, result, rhs)

proc main() =
  var input = newFileStream(paramStr(1))
  var identCache = newIdentCache()
  var p = initParser(input, identCache)
  var root = p.parseExpr(-1)
  echo root.treeRepr

main()

