import lexer, lexbase, idents, streams, os, ast, semcheck, context, keywords

type
  Parser* = object
    currInd: int
    firstTok: bool
    hasProgress: bool
    lex*: Lexer
    tok*: Token
    emptyNode: Node

proc getTok(p: var Parser) =
  p.tok.reset()
  p.lex.getToken(p.tok)
  while p.tok.kind in {tkComment, tkNestedComment}:
    p.lex.getToken(p.tok)
  p.hasProgress = true

proc error(p: Parser, kind: MsgKind, args: varargs[string, `$`]) =
  var err = new(SourceError)
  err.msg = p.lex.context.msgKindToString(kind, args)
  err.line = p.tok.line
  err.column = p.tok.col
  err.lineContent = p.lex.getCurrentLine(false)
  err.fileIndex = p.lex.fileIndex
  raise err

template withInd(p, body: untyped) =
  let oldInd = p.currInd
  p.currInd = p.tok.indent
  body
  p.currInd = oldInd

template realInd(p): bool = p.tok.indent > p.currInd
template sameInd(p): bool = p.tok.indent == p.currInd
template sameOrNoInd(p): bool = p.tok.indent == p.currInd or p.tok.indent < 0

proc optPar(p: var Parser) =
  if p.tok.indent >= 0:
    if p.tok.indent < p.currInd: p.error(errInvalidIndentation)

proc optInd(p: var Parser) =
  if p.tok.indent >= 0:
    if not realInd(p): p.error(errInvalidIndentation)

proc eat(p: var Parser, kind: TokenKind) =
  if p.tok.kind == kind:
    p.getTok()
  else:
    p.error(errTokenExpected, kind)

proc getLineInfo(p: Parser): LineInfo =
  result.line = int16(p.tok.line)
  result.col = int16(p.tok.col)
  result.fileIndex = p.lex.fileIndex

proc newNodeP(p: Parser, kind: NodeKind, sons: varargs[Node]): Node =
  result = newTree(kind, sons)
  result.lineInfo = if sons.len == 0: p.getLineInfo() else: sons[0].lineInfo

proc newIdentNodeP(p: Parser): Node =
  result = newIdentNode(nkIdent, p.tok.val.ident)
  result.lineInfo = p.getLineInfo

proc newUIntNodeP(p: Parser): Node =
  result = newUIntNode(nkUInt, p.tok.val.iNumber)
  result.lineInfo = p.getLineInfo

proc newFloatNodeP(p: Parser): Node =
  result = newFloatNode(nkFloat, p.tok.val.fNumber)
  result.lineInfo = p.getLineInfo

proc newStringNodeP(p: Parser): Node =
  result = newStringNode(nkString, p.tok.literal)
  result.lineInfo = p.getLineInfo

proc newCharLitNodeP(p: Parser): Node =
  result = newCharLitNode(nkCharLit, p.tok.literal)
  result.lineInfo = p.getLineInfo

proc openParser*(inputStream: Stream, context: Context, fileIndex: int32): Parser =
  result.tok = initToken()
  result.lex = openLexer(inputStream, context, fileIndex)
  result.getTok() # read the first token
  result.firstTok = true
  result.emptyNode = newNode(nkEmpty)

proc close*(p: var Parser) =
  p.lex.close()

proc parseExpr(p: var Parser, minPrec: int, prev = Node(nil)): Node

proc parseIdentChain(p: var Parser, prev: Node): Node =
  result = prev
  while p.tok.kind == tkDot:
    p.getTok()
    if p.tok.kind != tkIdent:
      p.error(errIdentExpected)
    result = newNodeP(p, nkDotCall, result, newIdentNodeP(p))
    p.getTok()

proc primary(p: var Parser): Node =
  case p.tok.kind:
  of tkParLe:
    p.getTok()
    result = p.parseExpr(-1)
    if p.tok.kind != tkParRi:
      p.error(errClosingParExpected)
    p.getTok()
  of tkEof:
    p.error(errSourceEndedUnexpectedly)
  of tkOpr:
    let a = newIdentNodeP(p)
    p.getTok()
    let b = p.primary()
    if b.kind == nkEmpty: p.error(errInvalidExpresion)
    result = newNodeP(p, nkPrefix, a, b)
  of tkNumber:
    result = newUIntNodeP(p)
    p.getTok()
  of tkFloat:
    result = newFloatNodeP(p)
    p.getTok()
  of tkIdent:
    let a = newIdentNodeP(p)
    p.getTok()
    if p.tok.kind == tkDot:
      result = parseIdentChain(p, a)
    else:
      result = a
  of tkString:
    result = newStringNodeP(p)
    p.getTok()
  of tkCharLit:
    result = newCharLitNodeP(p)
    p.getTok()
  else:
    result = p.emptyNode

proc getPrecedence(tok: Token): int =
  let L = tok.literal.len

  # arrow like?
  if L > 1 and tok.literal[L-1] == '>' and
      tok.literal[L-2] in {'-', '~', '='}: return 6

  template considerAsgn(value: untyped) =
    result = if tok.literal[L-1] == '=': 1 else: value

  case tok.literal[0]
  of '$', '^':considerAsgn(10)
  of '*', '%', '/', '\\': considerAsgn(9)
  of '~': result = 8
  of '+', '-', '|': considerAsgn(8)
  of '&': considerAsgn(7)
  of '=', '<', '>', '!': result = 5
  of '.': considerAsgn(6)
  of '?': result = 2
  else: considerAsgn(2)

proc isLeftAssoc(tok: Token): bool =
  result = tok.literal[0] != '^'

proc isBinary(tok: Token): bool =
  result = tok.kind in {tkOpr, tkDotDot}

proc parseExpr(p: var Parser, minPrec: int, prev = Node(nil)): Node =
  # this is operator precedence parsing algorithm
  result = if prev.isNil: p.primary() else: prev
  var opPrec = getPrecedence(p.tok)
  while opPrec >= minPrec and p.tok.indent < 0 and isBinary(p.tok):
    let assoc = ord(isLeftAssoc(p.tok))
    opPrec = getPrecedence(p.tok)
    let opNode = newIdentNodeP(p)
    p.getTok()
    let rhs = p.parseExpr(opPrec + assoc)
    if rhs.kind == nkEmpty:
      result = newNodeP(p, nkPostfix, opNode, result)
    else:
      result = newNodeP(p, nkInfix, opNode, result, rhs)

proc parseViewClassArgs(p: var Parser): Node =
  p.getTok()
  p.optInd()
  result = newNodeP(p, nkViewClassArgs)
  while true:
    addSon(result, parseExpr(p, -1))
    if p.tok.kind == tkParRi: break
    if p.tok.kind notin {tkComma, tkSemiColon}: break
    p.getTok()
  p.optPar()
  eat(p, tkParRi)

proc parseViewClass(p: var Parser): Node =
  if p.tok.kind != tkColonColon:
    return p.emptyNode

  p.getTok()
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)
  let name = newIdentNodeP(p)

  var args = p.emptyNode
  p.getTok()
  if p.tok.kind == tkParLe and p.tok.indent < 0:
    args = parseViewClassArgs(p)

  result = newNodeP(p, nkViewClass, name, args)

proc parseViewClassList(p: var Parser): Node =
  result = newNodeP(p, nkViewClassList)
  while true:
    let viewClass = parseViewClass(p)
    if viewClass.kind == nkEmpty: break
    addSon(result, viewClass)

proc parseViewBody(p: var Parser): Node =
  if p.tok.indent <= p.currInd:
    return p.emptyNode

  result = newNodeP(p, nkStmtList)
  withInd(p):
    while sameInd(p):
      if p.tok.indent < p.currInd: break
      addSon(result, parseExpr(p, -1))

proc parseView(p: var Parser): Node =
  var name = newIdentNodeP(p)

  p.getTok()
  if p.tok.kind == tkDot:
    name = parseIdentChain(p, name)

  let viewClasses = parseViewClassList(p)
  let viewBody = parseViewBody(p)

  result = newNodeP(p, nkView, name, viewClasses, viewBody)

proc parseClassParam(p: var Parser): Node =
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)

  let lhs = newIdentNodeP(p)
  p.getTok()
  if p.tok.kind in {tkSemiColon, tkParRi}:
    return lhs

  if p.tok.indent >= 0: p.error(errInvalidIndentation)
  if not(p.tok.kind == tkOpr and p.tok.val.ident.id == ord(wEquals)):
    p.error(errOnlyAsgnAllowed)

  p.getTok()
  let rhs = parseExpr(p, -1)
  if rhs.kind == nkEmpty: result = lhs
  else: result = newNodeP(p, nkAsgn, lhs, rhs)

proc parseClassParams(p: var Parser): Node =
  p.getTok()
  p.optInd()

  if p.tok.kind == tkIdent:
    result = newNodeP(p, nkClassParams)
    while true:
      addSon(result, parseClassParam(p))
      if p.tok.kind == tkParRi: break
      if p.tok.kind notin {tkComma, tkSemiColon}: break
      p.getTok()
  else:
    result = p.emptyNode

  p.optPar()
  eat(p, tkParRi)

proc parseClass(p: var Parser): Node =
  p.getTok()
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)

  let name = newIdentNodeP(p)
  var params = p.emptyNode
  p.getTok()
  if p.tok.kind == tkParLe and p.tok.indent < 0:
    params = parseClassParams(p)

  let body = parseViewBody(p)
  result = newNodeP(p, nkClass, name, params, body)

proc parseStyle(p: var Parser): Node =
  p.getTok()

proc parseTopLevel(p: var Parser): Node =
  case p.tok.kind
  of tkIdent: result = parseView(p)
  of tkColonColon: result = parseClass(p)
  of tkStyle: result = parseStyle(p)
  else:
    p.error(errInvalidToken, p.tok.kind)

proc parseAll(p: var Parser): Node =
  result = newNodeP(p, nkStmtList)
  while p.tok.kind != tkEof:
    p.hasProgress = false
    let a = parseTopLevel(p)
    if a.kind != nkEmpty and p.hasProgress:
      addSon(result, a)
    else:
      p.error(errExprExpected)
      # consume a token here to prevent an endless loop:
      p.getTok()
    if p.tok.indent != 0:
      p.error(errInvalidIndentation)

proc main() =
  let fileName = paramStr(1)
  var input = newFileStream(fileName)
  var ctx = newContext()
  var knownFile = false
  let fileIndex = ctx.fileInfoIdx(fileName, knownFile)

  try:
  #block:
    var p = openParser(input, ctx, fileIndex)
    var root = p.parseAll()
    p.close()

    var lay = newLayout(0, ctx)
    lay.semCheck(root)
  except SourceError as srcErr:
    ctx.printError(srcErr)
  except InternalError as ex:
    ctx.printError(ex)
  except Exception as ex:
    echo "unknown error: ", ex.msg

main()

