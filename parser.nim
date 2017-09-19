import lexer, lexbase, idents, ast, semcheck, keywords
import streams, razcontext, types

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
    p.error(errTokenExpected, kind.toString(), toString(p.tok.kind))

proc getLineInfo(p: Parser): RazLineInfo =
  result.line = int16(p.tok.line)
  result.col = int16(p.tok.col)
  result.fileIndex = p.lex.fileIndex

proc newNodeP(p: Parser, kind: NodeKind, sons: varargs[Node]): Node =
  result = newTree(kind, sons)
  result.lineInfo = if sons.len == 0: p.getLineInfo() else: sons[0].lineInfo

proc newIdentNodeP(p: Parser): Node =
  result = newIdentNode(p.tok.val.ident)
  result.lineInfo = p.getLineInfo

proc newUIntNodeP(p: Parser): Node =
  result = newUIntNode(p.tok.val.iNumber)
  result.lineInfo = p.getLineInfo

proc newFloatNodeP(p: Parser): Node =
  result = newFloatNode(p.tok.val.fNumber)
  result.lineInfo = p.getLineInfo

proc newStringNodeP(p: Parser): Node =
  result = newStringNode(p.tok.literal)
  result.lineInfo = p.getLineInfo

proc newCharLitNodeP(p: Parser): Node =
  result = newCharLitNode(p.tok.literal)
  result.lineInfo = p.getLineInfo

proc openParser*(inputStream: Stream, context: RazContext, fileIndex: int32): Parser =
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
  while p.tok.kind == tkDot and p.tok.indent < 0:
    p.getTok()
    if p.tok.kind != tkIdent:
      p.error(errIdentExpected)
    result = newNodeP(p, nkDotCall, result, newIdentNodeP(p))
    p.getTok()

proc parseName(p: var Parser): Node =
  result = newIdentNodeP(p)
  p.getTok()
  if p.tok.kind == tkDot and p.tok.indent < 0:
    result = parseIdentChain(p, result)

proc parseStringNode(p: var Parser): Node =
  # sequence of strings are concatenated into one string
  result = newStringNodeP(p)

  p.getTok()
  while p.tok.kind == tkString:
    result.strVal.add p.tok.literal
    p.getTok()
    p.optPar()

proc parseNameResolution(p: var Parser): Node =
  result = parseName(p)
  if p.tok.kind == tkBracketLe:
    p.getTok()
    let idxExpr = p.parseExpr(-1)
    if p.tok.kind != tkBracketRi:
      p.error(errClosingBracketExpected)
    p.getTok()
    result = newNodeP(p, nkBracketExpr, result, idxExpr)

proc parseNameChain(p: var Parser): Node =
  result = parseNameResolution(p)
  if p.tok.kind == tkDot:
    p.getTok()
    if p.tok.kind != tkIdent:
      p.error(errIdentExpected)
    let rhs = parseNameResolution(p)
    result = newNodeP(p, nkDotCall, result, rhs)

proc primary(p: var Parser): Node =
  case p.tok.kind:
  of tkParLe:
    p.getTok()
    result = p.parseExpr(-1)
    if p.tok.kind != tkParRi:
      p.error(errClosingParExpected)
    p.getTok()
  of tkEof:
    result = p.emptyNode
    #p.error(errSourceEndedUnexpectedly)
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
    result = parseNameChain(p)
  of tkString:
    result = parseStringNode(p)
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
  result = newNodeP(p, nkViewParam)
  p.getTok()
  if p.tok.kind == tkParLe and p.tok.indent < 0:
    p.getTok()
    p.optInd()

    while true:
      let exp = parseExpr(p, -1)
      if exp.kind != nkEmpty: addSon(result, exp)
      if p.tok.kind == tkParRi: break
      if p.tok.kind notin {tkComma, tkSemiColon}: break
      p.getTok()
    p.optPar()
    eat(p, tkParRi)

proc parseViewClass(p: var Parser): Node =
  if p.tok.indent >= 0 and p.tok.indent <= p.currInd: return p.emptyNode
  if p.tok.kind != tkColonColon:
    return p.emptyNode

  p.getTok()
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)
  let name = newIdentNodeP(p)
  let args = parseViewClassArgs(p)
  result = newNodeP(p, nkViewClass, name, args)

proc parseViewClassList(p: var Parser): Node =
  if p.tok.kind == tkColonColon and p.tok.indent < 0:
    result = newNodeP(p, nkViewClassList)
  else:
    return p.emptyNode

  while true:
    let viewClass = parseViewClass(p)
    if viewClass.kind == nkEmpty: break
    addSon(result, viewClass)

proc parseChoice(p: var Parser): Node =
  var exp = p.parseExpr(-1)
  if p.tok.kind == tkChoice:
    result = newNodeP(p, nkChoice, exp)
    while p.tok.kind == tkChoice:
      p.getTok()
      exp = p.parseExpr(-1)
      if exp.kind == nkEmpty:
        p.error(errExprExpected)
      addSon(result, exp)
  else:
    result = exp

proc parseChoiceList(p: var Parser): Node =
  var choice = p.parseChoice()
  if p.tok.kind == tkComma:
    result = newNodeP(p, nkChoiceList, choice)
    while p.tok.kind == tkComma:
      p.getTok()
      choice = p.parseChoice()
      if choice.kind == nkEmpty:
        p.error(errExprExpected)
      addSon(result, choice)
  else:
    result = choice

proc parseFlex(p: var Parser): Node =
  const constOpr = [tkEquals, tkGreaterOrEqual, tkLessOrEqual]
  var choice = p.parseChoiceList()
  if choice.kind == nkEmpty: return choice
  if choice.kind == nkBracketExpr:
    p.error(errPropExpected)
  if p.tok.kind in constOpr:
    result = newNodeP(p, nkFlex, choice)
    while p.tok.kind in constOpr:
      let opr = newIdentNodeP(p)
      addSon(result, opr)
      p.getTok()
      choice = p.parseChoiceList()
      if choice.kind == nkEmpty:
        p.error(errExprExpected)
      if choice.kind == nkBracketExpr:
        p.error(errPropExpected)
      addSon(result, choice)
  else:
    p.error(errConstOprNeeded)

proc parseFlexList(p: var Parser): Node =
  p.getTok() # skip tkFlex
  result = p.emptyNode
  withInd(p):
    while sameInd(p):
      while true:
        p.optPar()
        let n = parseFlex(p)
        # if no more flex, we finish here
        if n.kind == nkEmpty: return result
        if result.kind == nkEmpty: result = newNodeP(p, nkFlexList)
        addSon(result, n)
        if p.tok.kind == tkSemiColon: p.getTok()
        else: break

proc parseEvent(p: var Parser): Node =
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)
  let name = newIdentNodeP(p)

  p.getTok()
  eat(p, tkColon)

  if p.tok.kind != tkString:
    p.error(errTokenExpected, tkString.toString(), toString(p.tok.kind))

  let rawCode = parseStringNode(p)
  result = newNodeP(p, nkEvent, name, rawCode)

proc parseEventList(p: var Parser): Node =
  p.getTok() # skip tkEvent
  result = newNodeP(p, nkEventList)
  withInd(p):
    while sameInd(p):
      addSon(result, parseEvent(p))

proc parsePropValue(p: var Parser): Node =
  result = p.parseExpr(-1)

proc parseProp(p: var Parser): Node =
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)
  let name = newIdentNodeP(p)

  p.getTok()
  eat(p, tkColon)

  let propValue = parsePropValue(p)
  result = newNodeP(p, nkProp, name, propValue)

proc parsePropList(p: var Parser): Node =
  p.getTok() # skip tkProp
  result = newNodeP(p, nkPropList)
  withInd(p):
    while sameInd(p):
      addSon(result, parseProp(p))

proc parseViewBody(p: var Parser): Node =
  if p.tok.indent <= p.currInd:
    return p.emptyNode

  result = newNodeP(p, nkStmtList)
  withInd(p):
    while sameInd(p):
      case p.tok.kind
      of tkProp, tkColon:
        let list = parsePropList(p)
        addSon(result, list)
      of tkEvent, tkBang:
        let list = parseEventList(p)
        addSon(result, list)
      of tkFlex, tkAt:
        let list = parseFlexList(p)
        addSon(result, list)
      of tkEof:
        break
      else: p.error(errInvalidToken, toString(p.tok.kind))

proc parseView(p: var Parser): Node =
  let name    = parseName(p)
  let classes = parseViewClassList(p)
  let body    = parseViewBody(p)
  result = newNodeP(p, nkView, name, classes, body)

proc parseClassParam(p: var Parser): Node =
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)

  let lhs = newIdentNodeP(p)
  p.getTok()
  if p.tok.kind in {tkSemiColon, tkComma, tkParRi}:
    return lhs

  if p.tok.indent >= 0: p.error(errInvalidIndentation)
  if p.tok.kind != tkEquals:
    p.error(errOnlyAsgnAllowed)
  let opr = newIdentNodeP(p)

  p.getTok()
  let rhs = parseExpr(p, -1)
  if rhs.kind == nkEmpty: p.error(errExprExpected)
  else: result = newNodeP(p, nkAsgn, opr, lhs, rhs)

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

proc parseTime(p: var Parser): Node =
  case p.tok.kind
  of tkNumber: result = newUIntNodeP(p)
  of tkFloat: result = newFloatNodeP(p)
  else:
    p.error(errTokenExpected, "number", toString(p.tok.kind))
  p.getTok()

proc parseAnim(p: var Parser): Node =
  let
    name    = parseName(p)
    classes = parseViewClassList(p)

  var
    startAni = p.emptyNode
    endAni = p.emptyNode
  if p.tok.kind == tkAt:
    startAni = p.emptyNode
    p.getTok()
    endAni = parseTime(p)
  elif p.tok.kind in {tkNumber, tkFloat}:
    startAni = parseTime(p)
    if p.tok.kind in {tkNumber, tkFloat}:
      endAni = parseTime(p)

  var interpolator = p.emptyNode
  if p.tok.kind == tkIdent and p.tok.indent < 0:
    interpolator = newIdentNodeP(p)
    p.getTok()

  result = newNodeP(p, nkAnim, name, classes, startAni, endAni, interpolator)

proc parseAnimBody(p: var Parser): Node =
  if p.tok.indent <= p.currInd:
    return p.emptyNode

  result = newNodeP(p, nkStmtList)
  withInd(p):
    while sameInd(p):
      case p.tok.kind
      of tkIdent:
        let anim = parseAnim(p)
        addSon(result, anim)
      of tkEof:
        break
      else: p.error(errInvalidToken, toString(p.tok.kind))

proc parseAnimList(p: var Parser): Node =
  p.getTok()
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)

  let name = newIdentNodeP(p)
  p.getTok()
  let duration = parseTime(p)
  let body = parseAnimBody(p)
  result = newNodeP(p, nkAnimList, name, duration, body)

proc parseAlias(p: var Parser): Node =
  if p.tok.kind != tkIdent:
    p.error(errIdentExpected)
  let name = newIdentNodeP(p)

  p.getTok()
  eat(p, tkEquals)

  let aliasValue = p.parseExpr(-1)
  result = newNodeP(p, nkAlias, name, aliasValue)

proc parseAliasList(p: var Parser): Node =
  p.getTok() # skip tkAlias
  result = newNodeP(p, nkAliasList)
  withInd(p):
    while sameInd(p):
      addSon(result, parseAlias(p))

proc parseTopLevel(p: var Parser): Node =
  case p.tok.kind
  of tkIdent: result = parseView(p)
  of tkColonColon: result = parseClass(p)
  of tkPercent: result = parseAnimList(p)
  of tkAlias: result = parseAliasList(p)
  else:
    p.error(errInvalidToken, toString(p.tok.kind))

proc parseAll*(p: var Parser): Node =
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
