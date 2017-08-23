import lexer, lexbase, idents, streams, os, ast

type
  Parser* = object
    currInd: int
    firstTok: bool
    hasProgress: bool
    lex*: Lexer
    tok*: Token
    fileIndex: int32

  MsgKind = enum
    errInvalidIndentation

proc getTok(p: var Parser) =
  p.tok.reset()
  p.lex.getToken(p.tok)
  while p.tok.kind in {tkComment, tkNestedComment}:
    p.lex.getToken(p.tok)
  p.hasProgress = true

proc parError(p: var Parser, msg: string) =
  echo msg
  quit(1)

proc parError(p: var Parser, msgKind: MsgKind) =
  echo msgKind
  quit(1)

template realInd(p): bool = p.tok.indent > p.currInd
template sameInd(p): bool = p.tok.indent == p.currInd
template sameOrNoInd(p): bool = p.tok.indent == p.currInd or p.tok.indent < 0

proc optPar(p: var Parser) =
  if p.tok.indent >= 0:
    if p.tok.indent < p.currInd: parError(p, errInvalidIndentation)

proc optInd(p: var Parser, n: Node) =
  if p.tok.indent >= 0:
    if not realInd(p): parError(p, errInvalidIndentation)

proc getLineInfo(p: Parser): LineInfo =
  result.line = int16(p.tok.line)
  result.col = int16(p.tok.col)
  result.fileIndex = p.fileIndex

proc newNodeP(p: Parser, kind: NodeKind, sons: varargs[Node]): Node =
  result = newTree(kind, sons)
  result.lineInfo = sons[0].lineInfo

proc newIdentNodeP(p: Parser): Node =
  result = newIdentNode(nkIdent, p.tok.val.ident)
  result.lineInfo = p.getLineInfo

proc newUIntNodeP(p: Parser): Node =
  result = newIntNode(nkUInt, p.tok.val.iNumber)
  result.lineInfo = p.getLineInfo

proc newFloatNodeP(p: Parser): Node =
  result = newFloatNode(nkFloat, p.tok.val.fNumber)
  result.lineInfo = p.getLineInfo

proc openParser*(inputStream: Stream, identCache: IdentCache): Parser =
  result.tok = initToken()
  result.lex = openLexer(inputStream, identCache)
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
    p.getTok()
  of tkEof:
    p.parError("source ended unexpectedly")
  of tkOpr:
    let a = newIdentNodeP(p)
    p.getTok()
    let b = p.primary()
    if b == nil: p.parError("invalid expression")
    result = newNodeP(p, nkPrefix, a, b)
  of tkNumber:
    result = newUIntNodeP(p)
    p.getTok()
  of tkFloat:
    result = newFloatNodeP(p)
    p.getTok()
  of tkIdent:
    result = newIdentNodeP(p)
    p.getTok()
    while p.tok.kind == tkDot:
      p.getTok()
      if p.tok.kind != tkIdent:
        p.parError("identifier expected")
      result = newNodeP(p, nkDotCall, result, newIdentNodeP(p))
      p.getTok()
  else:
    result = nil
    #p.parError("unrecognized token: " & $p.tok.kind)

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
    let opNode = newIdentNodeP(p)
    p.getTok()
    let rhs = p.parseExpr(opPrec + assoc)
    if rhs.isNil:
      result = newNodeP(p, nkPostfix, opNode, result)
    else:
      result = newNodeP(p, nkInfix, opNode, result, rhs)

proc main() =
  var input = newFileStream(paramStr(1))
  var identCache = newIdentCache()
  var p = openParser(input, identCache)
  var root = p.parseExpr(-1)
  echo root.treeRepr
  p.close()

main()

