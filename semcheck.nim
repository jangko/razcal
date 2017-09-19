import ast, layout, idents, kiwi, tables, razcontext, hashes, strutils
import nimLUA, keywords, sets, interpolator, types

const
  screenWidth* = 800
  screenHeight* = 600

type
  Layout* = ref object of IDobj
    root*: View                   # every layout/scene root
    classTbl: Table[Ident, Node] # string to SymbolNode.skClass
    aliasTbl: Table[Ident, Node]
    animTbl: Table[Ident, Node]
    solver: kiwi.Solver          # constraint solver
    origin: kiwi.Solver
    context: RazContext          # ref to app global context
    lastView: View               # last processed parent view/current View
    emptyNode: Node

proc hash*(view: View): Hash =
  result = hash(cast[int](view))

proc newInternalError(fileName: string, line: int, msg: string): InternalError =
  new(result)
  result.msg = msg
  result.line = line
  result.fileName = fileName

# like assert, but better
when defined(release):
  template ensure(cond: bool) = discard
else:
  template ensure(cond: bool) =
    if not cond: raise newInternalError(instantiationInfo().fileName,
      instantiationInfo().line, astToStr(cond))

# convert identNode to SpecialWords
proc toKeyWord(n: Node): SpecialWords =
  ensure(n.kind == nkIdent)
  if n.ident.id > 0 and n.ident.id <= ord(high(SpecialWords)):
    result = SpecialWords(n.ident.id)
  else:
    result = wInvalid

# create view & view node as a child of last parent
proc createView(lay: Layout, n: Node): Node =
  var view = lay.lastView.newView(n.ident)
  result   = newViewSymbol(n, view).newSymbolNode()
  lay.lastView = view
  view.symNode = result
  lay.solver.setBasicConstraint(view)

# one application can have multiple layout a.k.a 'page'
proc newLayout*(id: int, context: RazContext): Layout =
  new(result)
  result.id = id
  result.classTbl = initTable[Ident, Node]()
  result.aliasTbl = initTable[Ident, Node]()
  result.animTbl = initTable[Ident, Node]()
  result.solver = newSolver()
  result.origin = result.solver
  result.context = context
  result.emptyNode = newNode(nkEmpty)

  let root = context.getIdent("root")
  let n = newIdentNode(root)
  result.root = newView(root)
  result.root.symNode = newViewSymbol(n, result.root).newSymbolNode()
  result.root.body = result.emptyNode
  result.root.visible = false
  result.solver.setBasicConstraint(result.root)

proc getRoot(lay: Layout): View =
  result = lay.root

proc getIdent(lay: Layout, s: string): Ident =
  result = lay.context.getIdent(s)

proc getAnimation*(lay: Layout, name: string): Animation =
  let id = lay.getIdent(name)
  let symNode = lay.animTbl.getOrDefault(id)
  if symNode != nil: result = symNode.sym.anim

proc internalErrorImpl(lay: Layout, kind: MsgKind,
  fileName: string, line: int, args: varargs[string, `$`]) =
  # internal error provide debugging information
  raise newInternalError(fileName, line, lay.context.msgKindToString(kind, args))

template internalError(lay: Layout, kind: MsgKind, args: varargs[string, `$`]) =
  # pointing to Nim source code location
  # where the error occured
  lay.internalErrorImpl(kind,
    instantiationInfo().fileName,
    instantiationInfo().line,
    args)

proc otherError(lay: Layout, kind: MsgKind, args: varargs[string, `$`]) =
  # not internal error and not source error
  lay.context.otherError(kind, args)

proc getCurrentLine*(lay: Layout, info: RazLineInfo): string =
  # we don't have lexer getCurrentLine anymore
  # so we simulate one here
  let fileName = lay.context.toFullPath(info)
  var f = open(fileName)
  if f.isNil(): lay.otherError(errCannotOpenFile, fileName)
  var line: string
  var n = 1
  while f.readLine(line):
    if n == info.line:
      result = line & "\n"
      break
    inc n
  f.close()
  if result.isNil: result = ""

proc sourceError[T: Node or Symbol](lay: Layout, kind: MsgKind, n: T, args: varargs[string, `$`]) =
  # report any error during semcheck
  var err = new(SourceError)
  err.msg = lay.context.msgKindToString(kind, args)
  err.line = n.lineInfo.line
  err.column = n.lineInfo.col
  err.lineContent = lay.getCurrentLine(n.lineInfo)
  err.fileIndex = n.lineInfo.fileIndex
  raise err

proc sourceWarning[T: Node or Symbol](lay: Layout, kind: MsgKind, n: T, args: varargs[string, `$`]) =
  # report any error during semcheck
  var err = new(SourceError)
  err.msg = lay.context.msgKindToString(kind, args)
  err.line = n.lineInfo.line
  err.column = n.lineInfo.col
  err.lineContent = lay.getCurrentLine(n.lineInfo)
  err.fileIndex = n.lineInfo.fileIndex
  lay.context.printWarning(err)

proc semViewName(lay: Layout, n: Node, lastIdent: Node): Node =
  # check and resolve view name hierarchy
  # such as view1.view1child.view1grandson
  case n.kind
  of nkDotCall:
    ensure(n.len == 2)
    n[0] = lay.semViewName(n[0], lastIdent)
    ensure(n[0].kind == nkSymbol)
    lay.lastView = n[0].sym.view
    n[1] = lay.semViewName(n[1], lastIdent)
    result = n[1]
  of nkIdent:
    var view = lay.lastView.views.getOrDefault(n.ident)
    if view.isNil:
      result = lay.createView(n)
    else:
      let symNode = view.symNode
      if lastIdent == n:
        let info = symNode.lineInfo
        let prev = lay.context.toString(info)
        lay.sourceError(errDuplicateView, n, symNode.symString, prev)
      result = symNode
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semViewClass(lay: Layout, n: Node): Node =
  result = n

proc semFlexList(lay: Layout, n: Node) =
  discard

proc semEventList(lay: Layout, n: Node) =
  for ev in n.sons:
    ensure(ev.kind == nkEvent)
    ensure(ev[0].kind == nkIdent)
    let id = toKeyword(ev[0])
    if id notin validEvents:
      lay.sourceError(errUndefinedEvent, ev[0], ev[0].ident)

proc semPropList(lay: Layout, n: Node) =
  discard

proc semViewBody(lay: Layout, n: Node): Node =
  ensure(n.kind in {nkStmtList, nkEmpty})

  for m in n.sons:
    case m.kind
    of nkFlexList: lay.semFlexList(m)
    of nkEventList: lay.semEventList(m)
    of nkPropList:  lay.semPropList(m)
    of nkEmpty: discard
    else:
      internalError(lay, errUnknownNode, m.kind)

  result = n

proc semView(lay: Layout, n: Node) =
  ensure(n.len == 3)
  # each time we create new view
  # need to reset the lastView
  lay.lastView = lay.root
  var lastIdent = Node(nil)
  if n[0].kind == nkIdent: lastIdent = n[0]
  if lastIdent.isNil and n[0].kind == nkDotCall:
    let son = n[0].sons[1]
    if son.kind == nkIdent: lastIdent = son
  n[0] = lay.semViewName(n[0], lastIdent)
  n[0].sym.view.body = n[2] #we only need body for next phase

  # at this point, the view already created
  # and n[0] already replaced with a symbolNode
  lay.lastView = n[0].sym.view
  n[1] = lay.semViewClass(n[1])
  n[2] = lay.semViewBody(n[2])

proc subst(lay: Layout, n: Node, cls: ClassContext): Node =
  # substitute node with param symNode
  case n.kind
  of NodeWithSons - {nkProp}:
    for i in 0.. <n.len:
      n[i] = lay.subst(n[i], cls)
    result = n
  of nkProp:
    # do not replace lhs
    for i in 1.. <n.len:
      n[i] = lay.subst(n[i], cls)
    result = n
  of nkIdent:
    let sym = cls.paramTable.getOrDefault(n.ident)
    if not sym.isNil:
      sym.sym.flags.incl(sfUsed)
      return sym
    result = n
  of nkUint, nkString, nkInt:
    result = n
  else:
    internalError(lay, errUnknownNode, n.kind)

proc substituteParams(lay: Layout, n: Node, cls: ClassContext) =
  # iterate over class body and substitue it with param
  # if any, then report unused param if any
  for i in 0.. <n.len:
    n[i] = lay.subst(n[i], cls)

  for s in values(cls.paramTable):
    if sfUsed notin s.sym.flags:
      lay.sourceWarning(warnParamNotUsed, s, s.sym.name)

proc collectParams(lay: Layout, n: Node, cls: ClassContext) =
  # build param symbol table and it's default value if any
  # check for duplicate param's nama
  if n.kind == nkEmpty: return
  ensure(n.kind == nkClassParams)
  for i in 0.. <n.len:
    let m = n.sons[i]
    case m.kind
    of nkIdent:
      let p = cls.paramTable.getOrDefault(m.ident)
      if p.isNil:
        cls.paramTable[m.ident] = newParamSymbol(m, nil, i).newSymbolNode()
      else:
        lay.sourceError(errDuplicateParam, m, m.ident)
    of nkAsgn:
      ensure(m.sons.len == 3)
      let paramName = m[1]
      let paramValue = m[2]
      let p = cls.paramTable.getOrDefault(paramName.ident)
      if p.isNil:
        cls.paramTable[paramName.ident] = newParamSymbol(paramName, paramValue, i).newSymbolNode()
      else:
        lay.sourceError(errDuplicateParam, paramName, paramName.ident)
    else:
      internalError(lay, errUnknownNode, m.kind)

proc semClass(lay: Layout, n: Node) =
  # create class and check for duplicate
  ensure(n.len == 3)
  let className = n[0]
  var symNode = lay.classTbl.getOrDefault(className.ident)
  if symNode.isNil:
    let cls = newClassContext(n)
    let sym = newClassSymbol(className, cls)
    symNode = newSymbolNode(sym)
    lay.classTbl[className.ident] = symNode
    n[0] = symNode
  else:
    let info = symNode.lineInfo
    let prev = lay.context.toString(info)
    lay.sourceError(errDuplicateClass, className, symNode.symString, prev)
  let cls = symNode.sym.class
  lay.collectParams(n[1], cls)    # n[1] = classParams
  if cls.paramTable.len > 0:
    lay.substituteParams(n[2], cls) # n[2] = classBody

proc semAliasList(lay: Layout, n: Node) =
  for m in n.sons:
    ensure(m.kind == nkAlias)
    ensure(m.len == 2)
    ensure(m[0].kind == nkIdent)
    let alias = lay.aliasTbl.getOrDefault(m[0].ident)
    if alias.isNil:
      let sym = newAliasSymbol(m[0], m[1]).newSymbolNode()
      lay.aliasTbl[m[0].ident] = sym
    else:
      let info = alias.lineInfo
      let prev = lay.context.toString(info)
      lay.sourceError(errDuplicateAlias, m[0], alias.sym.name, prev)

proc semAnimList(lay: Layout, n: Node) =
  discard

proc semStmt(lay: Layout, n: Node) =
  case n.kind
  of nkView: lay.semView(n)
  of nkClass: lay.semClass(n)
  of nkAnimList: lay.semAnimList(n)
  of nkAliasList: lay.semAliasList(n)
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semTopLevel*(lay: Layout, n: Node) =
  ensure(n.kind == nkStmtList)
  for son in n.sons:
    lay.semStmt(son)

# entering second pass
proc secViewBody(lay: Layout, n: Node)

proc checkParamCountMatch(lay: Layout, params, classParams: Node) =
  # view can have many class and we need to check if the param
  # count match
  if classParams.kind == nkEmpty:
    if params.len > 0:
      lay.sourceError(errParamCountNotMatch, params, 0, params.len)
    return

  ensure(classParams.kind == nkClassParams)
  if params.len == classParams.len: return

  if params.len > classParams.len:
    lay.sourceError(errParamCountNotMatch, params, classParams.len, params.len)

  var count = classParams.len
  # count params without default value
  for i in countdown(classParams.len-1, 0):
    if classParams[i].kind != nkAsgn:
      count = i + 1
      break

  # count available and needed param
  for i in params.len.. <classParams.len:
    if classParams[i].kind != nkAsgn:
      # it has no default value
      lay.sourceError(errParamCountNotMatch, params, count, params.len)

proc instClass(lay: Layout, n: Node, cls: ClassContext, params: Node): Node =
  # replace each param with value supplied from view or
  # class's param default value
  case n.kind
  of NodeWithSons:
    for i in 0.. <n.len:
      n[i] = lay.instClass(n[i], cls, params)
    result = n
  of nkSymbol:
    if n.sym.pos >= 0 and n.sym.pos < params.len:
      result = params[n.sym.pos]
    else:
      result = n.sym.value
  of nkIdent:
    let alias = lay.aliasTbl.getOrDefault(n.ident)
    if alias.isNil: result = n
    else:
      alias.sym.flags.incl(sfUsed)
      result = alias.sym.alias
  of nkUInt, nkString:
    result = n
  else:
    internalError(lay, errUnknownNode, n.kind)

proc instantiateClass(lay: Layout, cls: ClassContext, params: Node): Node =
  # copy only the class body which is essentialy
  # has the same structure with view body
  # then instantiate it
  var n = cls.n[2].copyTree()
  for i in 0.. <n.len:
    n[i] = lay.instClass(n[i], cls, params)

  # don't forget to check instantiated class
  lay.secViewbody(n)
  result = n

proc instantiateArg(lay: Layout, n: Node): Node =
  case n.kind
  of NodeWithSons:
    for i in 0.. <n.len:
      n[i] = lay.instantiateArg(n[i])
    result = n
  of nkIdent:
    let alias = lay.aliasTbl.getOrDefault(n.ident)
    if alias.isNil: result = n
    else:
      alias.sym.flags.incl(sfUsed)
      result = alias.sym.alias
  else: result = n

proc secViewClass(lay: Layout, n: Node) =
  # the view have classes
  ensure(n.kind in {nkViewClassList, nkEmpty})
  for vc in n.sons:
    ensure(vc.kind == nkViewClass)
    ensure(vc.len == 2)
    let name = vc.sons[0]
    let params = lay.instantiateArg(vc.sons[1])
    ensure(name.kind == nkIdent)
    let classSymbol = lay.classTbl.getOrDefault(name.ident)
    if classSymbol.isNil:
      lay.sourceError(errClassNotFound, name, name.ident.s)
    # mark it as used
    classSymbol.sym.flags.incl(sfUsed)
    # replace name with symbol
    vc.sons[0] = classSymbol
    let class = classSymbol.sym.class
    let classParams = class.n[1]
    lay.checkParamCountMatch(params, classParams)
    # replace param(s) with intantiated class
    vc.sons[1] = lay.instantiateClass(class, params)

proc selectViewProp(lay: Layout, view: View, id: SpecialWords): Variable =
  case id
  of wLeft: result = view.current.left
  of wRight: result = view.current.right
  of wTop: result = view.current.top
  of wBottom: result = view.current.bottom
  of wWidth: result = view.current.width
  of wHeight: result = view.current.height
  of wCenterX: result = view.current.centerX
  of wCenterY: result = view.current.centerY
  else:
    internalError(lay, errUnknownProp, id)

proc selectViewRel(lay: Layout, view: View, id: SpecialWords, idx = 1): View =
  # get a view related to `this` view
  # idx < 0 means the last
  case id
  of wThis: result = view
  of wRoot: result = lay.root
  of wParent:
    result = view.parent
    if idx > 1:
      var i = 1
      while i < idx:
        if result.isNil: break
        result = result.parent
        inc i
  of wChild:
    if idx < 0 and view.parent.children.len > 0: return view.children[^1]
    if idx < view.children.len:
      result = view.children[idx]
  of wPrev:
    if not view.parent.isNil:
      if idx < 0 and view.parent.children.len > 0: return view.parent.children[0]
      let i = view.idx - idx
      if i >= 0 and i < view.parent.children.len:
        result = view.parent.children[i]
  of wNext:
    if not view.parent.isNil:
      if idx < 0 and view.parent.children.len > 0: return view.parent.children[^1]
      let i = view.idx + idx
      if i < view.parent.children.len:
        result = view.parent.children[i]
  else:
    internalError(lay, errUnknownRel, id)

proc computeIdx(lay: Layout, n: Node): int =
  # compute integer index used by something like
  # prev[idx].left
  result = 1
  case n.kind
  of nkEmpty: result = -1
  of nkUInt: result = int(n.uintVal)
  of nkFloat:
    lay.sourceError(errFloatNotAllowed, n)
  of nkString:
    lay.sourceError(errFloatNotAllowed, n)
  of nkInfix:
    let op  = toKeyword(n[0])
    let lhs = lay.computeIdx(n[1])
    let rhs = lay.computeIdx(n[2])
    case op
    of wPlus: result = lhs + rhs
    of wMinus: result = lhs - rhs
    of wMul: result = lhs * rhs
    of wDiv: result = lhs div rhs
    else: internalError(lay, errUnknownBinaryOpr, op)
  of nkPrefix:
    let op = toKeyword(n[0])
    let operand = lay.computeIdx(n[1])
    case op
    of wMinus: result = -operand
    of wPlus: result = abs(operand)
    else: lay.sourceError(errIllegalPrefix, n[0], '-', operand)
  else: internalError(lay, errUnknownNode, n.kind)

proc findRelation(lay: Layout, n: Node, id: SpecialWords, idx = 1, useBracket = false): View =
  # first find from relative relation
  if id in flexRel:
    result = lay.selectViewRel(lay.lastView, id, idx)
    return result

  # find among child
  result = lay.lastView.views.getOrDefault(n.ident)
  if result != nil and useBracket:
    if idx < 0 and result.children.len > 0: return result.children[^1]
    if idx >= 0 and idx < result.children.len: return result.children[idx]

  # find among siblings
  if result.isNil:
    var view = lay.lastView.parent
    while view != nil:
      result = view.views.getOrDefault(n.ident)
      if result != nil and useBracket:
        if idx < 0 and result.children.len > 0: return result.children[^1]
        if idx >= 0 and idx < result.children.len: return result.children[idx]
      if result != nil: return result
      view = view.parent

proc resolveTerm(lay: Layout, n: Node, lastIdent: Ident, choiceMode = false): Node =
  # here we try to validate an term
  case n.kind
  of nkIdent:
    let id = toKeyWord(n)
    if n.ident == lastIdent:
      if id in flexProp:
        result = newNodeI(nkFlexVar, n.lineInfo)
        result.variable = lay.selectViewProp(lay.lastView, id)
      else:
        let alias = lay.aliasTbl.getOrDefault(n.ident)
        if alias.isNil:
          lay.sourceError(errUndefinedVar, n, n.ident)
        else:
          alias.sym.flags.incl(sfUsed)
          result = lay.resolveTerm(alias.sym.alias, lastIdent, choiceMode)
    else:
      let view = lay.findRelation(n, id)
      if view.isNil:
        if choiceMode: return lay.emptyNode
        else: lay.sourceError(errRelationNotFound, n, n.ident, lay.lastView.name)
      view.dependencies.incl(lay.lastView)
      lay.lastView.dependencies.incl(view)
      result = view.symNode
  of nkDotCall:
    let tempView = lay.lastView
    ensure(n.len == 2)
    n[0] = lay.resolveTerm(n[0], lastIdent, choiceMode)
    if choiceMode and n[0].kind == nkEmpty: return n[0]
    ensure(n[0].kind == nkSymbol)
    lay.lastView = n[0].sym.view
    n[1] = lay.resolveTerm(n[1], lastIdent, choiceMode)
    if choiceMode and n[1].kind == nkEmpty: return n[1]
    lay.lastView = tempView
    result = n[1]
  of nkBracketExpr:
    ensure(n.len == 2)
    ensure(n[0].kind in {nkIdent, nkDotCall})
    let node = if n[0].kind == nkIdent: n[0] else: n[0][^1]
    let id = toKeyWord(node)
    if id in flexRel:
      let idx  = lay.computeIdx(n[1])
      let tempView = lay.lastView
      if n[0].kind == nkDotCall:
        n[0] = lay.resolveTerm(n[0][0], node.ident, choiceMode)
        lay.lastView = n[0].sym.view
      let view = lay.findRelation(node, id, idx, true)
      lay.lastView = tempView
      if view.isNil:
        if choiceMode: return lay.emptyNode
        else: lay.sourceError(errWrongRelationIndex, n[1], idx)
      view.dependencies.incl(lay.lastView)
      lay.lastView.dependencies.incl(view)
      result = view.symNode
    else:
      lay.sourceError(errUndefinedRel, n[0], n[0].ident)
  of nkString:
    lay.sourceError(errStringNotAllowed, n)
  else:
    internalError(lay, errUnknownNode, n.kind)

const numberNode = {nkInt, nkUInt, nkFloat}

proc toNumber(n: Node): float64 =
  case n.kind
  of nkUint: result = float64(n.uintVal)
  of nkInt: result = float64(n.intVal)
  of nkFloat: result = n.floatVal
  else: result = 0.0

proc termOpPlus(lay: Layout, a, b, op: Node): Node =
  if a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() + b.toNumber()
  elif a.kind in numberNode and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() + b.variable
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() + b.expression
  elif a.kind in numberNode and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() + b.term
  elif a.kind == nkFlexVar and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable + b.toNumber()
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable + b.expression
  elif a.kind == nkFlexVar and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable + b.term
  elif a.kind == nkFlexVar and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable + b.variable
  elif a.kind == nkFlexExpr and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression + b.toNumber()
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression + b.variable
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression + b.expression
  elif a.kind == nkFlexExpr and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression + b.term
  elif a.kind == nkFlexTerm and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term + b.term
  elif a.kind == nkFlexTerm and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term + b.expression
  elif a.kind == nkFlexTerm and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term + b.variable
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term + b.toNumber()
  else: internalError(lay, errUnknownOperation, a.kind, "'+'", b.kind)

proc termOpMinus(lay: Layout, a, b, op: Node): Node =
  if a.kind == nkFlexExpr and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression - b.toNumber()
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression - b.variable
  elif a.kind == nkFlexExpr and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression - b.term
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression - b.expression
  elif a.kind == nkFlexTerm and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term - b.expression
  elif a.kind == nkFlexTerm and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term - b.term
  elif a.kind == nkFlexTerm and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term - b.variable
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.term - b.toNumber()
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable - b.expression
  elif a.kind == nkFlexVar and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable - b.term
  elif a.kind == nkFlexVar and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable - b.variable
  elif a.kind == nkFlexVar and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.variable - b.toNumber()
  elif a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() - b.toNumber()
  elif a.kind in numberNode and b.kind == nkFlexVar:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() - b.variable
  elif a.kind in numberNode and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() - b.term
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() - b.expression
  else: internalError(lay, errUnknownOperation, a.kind, "'-'", b.kind)

proc termOpMul(lay: Layout, a, b, op: Node): Node =
  if a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() * b.toNumber()
  elif a.kind in numberNode and b.kind == nkFlexVar:
    result = newNodeI(nkFlexTerm, a.lineInfo)
    result.term = a.toNumber() * b.variable
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.toNumber() * b.expression
  elif a.kind in numberNode and b.kind == nkFlexTerm:
    result = newNodeI(nkFlexTerm, a.lineInfo)
    result.term = a.toNumber() * b.term
  elif a.kind == nkFlexVar and b.kind in numberNode:
    result = newNodeI(nkFlexTerm, a.lineInfo)
    result.term = a.variable * b.toNumber()
  elif a.kind == nkFlexExpr and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression * b.toNumber()
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    result = newNodeI(nkFlexTerm, a.lineInfo)
    result.term = a.term * b.toNumber()
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression * b.expression
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    #result = newNodeI(nkFlexExpr, a.lineInfo)
    #result.expression = a.expression * b.variable
    lay.sourceError(errIllegalOperation, op, a.kind, "'*'", b.kind)
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    #result = newNodeI(nkFlexExpr, a.lineInfo)
    #result.expression = a.variable * b.expression
    lay.sourceError(errIllegalOperation, op, a.kind, "'*'", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, "'*'", b.kind)

proc termOpDiv(lay: Layout, a, b, op: Node): Node =
  if a.kind == nkFlexVar and b.kind in numberNode:
    result = newNodeI(nkFlexTerm, a.lineInfo)
    result.term = a.variable / b.toNumber()
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    result = newNodeI(nkFlexTerm, a.lineInfo)
    result.term = a.term / b.toNumber()
  elif a.kind == nkFlexExpr and b.kind in numberNode:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression / b.toNumber()
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    result = newNodeI(nkFlexExpr, a.lineInfo)
    result.expression = a.expression / b.expression
  elif a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() / b.toNumber()
  elif a.kind in numberNode and b.kind == nkFlexVar:
    #result = newNodeI(nkFlexExpr, a.lineInfo)
    #result.expression = a.toNumber() / b.variable
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    #result = newNodeI(nkFlexExpr, a.lineInfo)
    #result.expression = a.toNumber() / b.expression
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    #result = newNodeI(nkFlexExpr, a.lineInfo)
    #result.expression = a.expression / b.variable
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    #result = newNodeI(nkFlexExpr, a.lineInfo)
    #result.expression = a.variable / b.expression
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, "'/'", b.kind)

proc binaryTermOp(lay: Layout, a, b, op: Node, id: SpecialWords): Node =
  case id
  of wPlus:  result = lay.termOpPlus(a, b, op)
  of wMinus: result = lay.termOpMinus(a, b, op)
  of wMul:   result = lay.termOpMul(a, b, op)
  of wDiv:   result = lay.termOpDiv(a, b, op)
  else: internalError(lay, errUnknownBinaryOpr, id)

proc termPrefixMinus(lay: Layout, operand, op: Node): Node =
  case operand.kind
  of numberNode:
    result = newNodeI(nkFloat, operand.lineInfo)
    result.floatVal = -operand.toNumber()
  of nkFlexVar:
    result = newNodeI(nkFlexTerm, operand.lineInfo)
    result.term = -operand.variable
  of nkFlexTerm:
    result = newNodeI(nkFlexTerm, operand.lineInfo)
    result.term = -operand.term
  of nkFlexExpr:
    result = newNodeI(nkFlexExpr, operand.lineInfo)
    result.expression = -operand.expression
  else: internalError(lay, errUnknownPrefix, "'-'", operand.kind)

proc unaryTermOp(lay: Layout, operand, op: Node, id: SpecialWords): Node =
  case id
  of wMinus: result = lay.termPrefixMinus(operand, op)
  else: internalError(lay, errUnknownPrefixOpr, id)

proc secFlexExpr(lay: Layout, n: Node, choiceMode = false): Node =
  # here we try to validate an expression
  case n.kind
  of nkIdent:
    let id = toKeyWord(n)
    if id in flexProp:
      result = newNodeI(nkFlexVar, n.lineInfo)
      result.variable = lay.selectViewProp(lay.lastView, id)
    else:
      let alias = lay.aliasTbl.getOrDefault(n.ident)
      if alias.isNil:
        lay.sourceError(errUndefinedVar, n, n.ident)
      else:
        alias.sym.flags.incl(sfUsed)
        result = lay.secFlexExpr(alias.sym.alias, choiceMode)
  of nkUint:
    result = n
  of nkDotCall:
    ensure(n.len == 2)
    ensure(n[1].kind == nkIdent)
    result = lay.resolveTerm(n, n[1].ident, choiceMode)
  of nkInfix:
    ensure(n.len == 3)
    let id = toKeyWord(n[0])
    if id notin flexBinaryTermOp:
      lay.sourceError(errIllegalBinaryOpr, n[0], n[0].ident)
    let lhs = lay.secFlexExpr(n[1], choiceMode)
    let rhs = lay.secFlexExpr(n[2], choiceMode)
    if choiceMode:
      if lhs.kind == nkEmpty or lhs.kind == nkEmpty:
        return lay.emptyNode
    result = lay.binaryTermOp(lhs, rhs, n[0], id)
  of nkString:
    lay.sourceError(errStringNotAllowed, n)
  of nkChoice:
    # choose among choices, we pick first valid one
    # expr1 | expr2 | expr3
    for cc in n.sons:
      result = lay.secFlexExpr(cc, true)
      if result.kind != nkEmpty: return result
    lay.sourceError(errNoValidBranch, n)
  of nkPrefix:
    ensure(n.len == 2)
    let id = toKeyWord(n[0])
    if id notin flexUnaryTermOp:
      lay.sourceError(errIllegalPrefixOpr, n[0], n[0].ident)
    let operand = lay.secFlexExpr(n[1], choiceMode)
    if choiceMode and operand.kind == nkEmpty:
      return lay.emptyNode
    result = lay.unaryTermOp(operand, n[0], id)
  of nkFlexVar, nkFlexExpr, nkFlexTerm:
    # already processed, just return it
    result = n
  else:
    internalError(lay, errUnknownNode, n.kind)

proc flexOpEQ(lay: Layout, a, b, op: Node) =
  if a.kind in numberNode and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.toNumber() == b.variable)
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.toNumber() == b.expression)
  elif a.kind in numberNode and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.toNumber() == b.term)
  elif a.kind == nkFlexVar and b.kind in numberNode:
    lay.solver.addConstraint(a.variable == b.toNumber())
  elif a.kind == nkFlexVar and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.variable == b.variable)
  elif a.kind == nkFlexVar and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.variable == b.term)
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.variable == b.expression)
  elif a.kind == nkFlexTerm and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.term == b.expression)
  elif a.kind == nkFlexTerm and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.term == b.term)
  elif a.kind == nkFlexTerm and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.term == b.variable)
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    lay.solver.addConstraint(a.term == b.toNumber())
  elif a.kind == nkFlexExpr and b.kind in numberNode:
    lay.solver.addConstraint(a.expression == b.toNumber())
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.expression == b.variable)
  elif a.kind == nkFlexExpr and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.expression == b.term)
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.expression == b.expression)
  elif a.kind in numberNode and b.kind in numberNode:
    lay.sourceError(errIllegalOperation, op, a.kind, "=", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, '=', b.kind)

proc flexOpLE(lay: Layout, a, b, op: Node) =
  if a.kind in numberNode and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.toNumber() <= b.variable)
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.toNumber() <= b.expression)
  elif a.kind in numberNode and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.toNumber() <= b.term)
  elif a.kind == nkFlexVar and b.kind in numberNode:
    lay.solver.addConstraint(a.variable <= b.toNumber())
  elif a.kind == nkFlexVar and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.variable <= b.variable)
  elif a.kind == nkFlexVar and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.variable <= b.term)
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.variable <= b.expression)
  elif a.kind == nkFlexTerm and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.term <= b.expression)
  elif a.kind == nkFlexTerm and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.term <= b.term)
  elif a.kind == nkFlexTerm and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.term <= b.variable)
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    lay.solver.addConstraint(a.term <= b.toNumber())
  elif a.kind == nkFlexExpr and b.kind in numberNode:
    lay.solver.addConstraint(a.expression <= b.toNumber())
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.expression <= b.variable)
  elif a.kind == nkFlexExpr and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.expression <= b.term)
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.expression <= b.expression)
  elif a.kind in numberNode and b.kind in numberNode:
    lay.sourceError(errIllegalOperation, op, a.kind, "<=", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, "<=", b.kind)

proc flexOpGE(lay: Layout, a, b, op: Node) =
  if a.kind in numberNode and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.toNumber() >= b.variable)
  elif a.kind in numberNode and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.toNumber() >= b.expression)
  elif a.kind in numberNode and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.toNumber() >= b.term)
  elif a.kind == nkFlexVar and b.kind in numberNode:
    lay.solver.addConstraint(a.variable >= b.toNumber())
  elif a.kind == nkFlexVar and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.variable >= b.variable)
  elif a.kind == nkFlexVar and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.variable >= b.term)
  elif a.kind == nkFlexVar and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.variable >= b.expression)
  elif a.kind == nkFlexTerm and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.term >= b.expression)
  elif a.kind == nkFlexTerm and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.term >= b.term)
  elif a.kind == nkFlexTerm and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.term >= b.variable)
  elif a.kind == nkFlexTerm and b.kind in numberNode:
    lay.solver.addConstraint(a.term >= b.toNumber())
  elif a.kind == nkFlexExpr and b.kind in numberNode:
    lay.solver.addConstraint(a.expression >= b.toNumber())
  elif a.kind == nkFlexExpr and b.kind == nkFlexVar:
    lay.solver.addConstraint(a.expression >= b.variable)
  elif a.kind == nkFlexExpr and b.kind == nkFlexTerm:
    lay.solver.addConstraint(a.expression >= b.term)
  elif a.kind == nkFlexExpr and b.kind == nkFlexExpr:
    lay.solver.addConstraint(a.expression >= b.expression)
  elif a.kind in numberNode and b.kind in numberNode:
    lay.sourceError(errIllegalOperation, op, a.kind, "<=", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, ">=", b.kind)

proc flexOp(lay: Layout, a, b, op: Node, id: SpecialWords) =
  try:
    case id
    of wEquals: lay.flexOpEQ(a, b, op)
    of wGreaterOrEqual: lay.flexOpGE(a, b, op)
    of wLessOrEqual: lay.flexOpLE(a, b, op)
    else: internalError(lay, errUnknownEqualityOpr, id)
  except UnsatisfiableConstraintException:
    lay.sourceError(errUnsatisfiableConstraint, op)
  except:
    raise getCurrentException()

proc secChoiceList(lay: Layout, lhs, rhs, op: Node, opId: SpecialWords) =
  if rhs.kind != nkChoiceList or lhs.kind != nkChoiceList:
    lay.sourceError(errUnbalancedArm, op)
  if rhs.len != lhs.len: lay.sourceError(errUnbalancedArm, op)
  for i in 0.. <lhs.len:
    lhs[i] = lay.secFlexExpr(lhs[i])
    rhs[i] = lay.secFlexExpr(rhs[i])
    lay.flexOp(lhs[i], rhs[i], op, opId)

proc secFlexList(lay: Layout, n: Node) =
  ensure(n.kind == nkFlexList)
  for cc in n.sons:
    ensure(cc.kind == nkFlex)
    ensure(cc.len >= 3)
    for i in countup(0, cc.sons.len-2, 2):
      let lhs = cc.sons[i]
      let op  = cc.sons[i+1]
      let rhs = cc.sons[i+2]
      let opId = toKeyWord(op)
      ensure(opId in flexOpr)
      if lhs.kind == nkChoiceList or rhs.kind == nkChoiceList:
        lay.secChoiceList(lhs, rhs, op, opId)
      else:
        cc.sons[i] = lay.secFlexExpr(lhs)
        cc.sons[i+2] = lay.secFlexExpr(rhs)
        lay.flexOp(cc.sons[i], cc.sons[i+2], op, opId)

proc secEventList(lay: Layout, n: Node) =
  discard

proc secPropList(lay: Layout, n: Node) =
  let view = lay.lastView
  for prop in n.sons:
    ensure(prop.kind == nkProp)
    if prop[0].kind != nkIdent:
      lay.sourceError(errTokenExpected, prop[0], "identifier", prop[0].kind)

    let id = toKeyword(prop[0])
    if id notin validProps:
      lay.sourceError(errUndefinedProp, prop[0], prop[0].ident)

    case id
    of wVisible:
      let val = toKeyWord(prop[1])
      view.visible = val == wTrue
    of wContent:
      if prop[1].kind != nkString:
        lay.sourceError(errTokenExpected, prop[1], "string", prop[1].kind)
      view.content = prop[1].strVal
    else:
      discard

proc secViewBody(lay: Layout, n: Node) =
  ensure(n.kind in {nkStmtList, nkEmpty})
  for m in n.sons:
    case m.kind
    of nkFlexList: lay.secFlexList(m)
    of nkEventList: lay.secEventList(m)
    of nkPropList:  lay.secPropList(m)
    of nkEmpty: discard
    else:
      internalError(lay, errUnknownNode, m.kind)

proc secView(lay: Layout, n: Node) =
  # skip name node
  ensure(n[0].kind == nkSymbol)
  ensure(n[0].sym.kind == skView)
  lay.lastView = n[0].sym.view
  lay.secViewClass(n[1])
  let body = n[2].copyTree
  lay.secViewBody(body)

proc secClass(lay: Layout, n: Node) =
  discard

proc resolveView(lay: Layout, n: Node, parent: View): Node =
  case n.kind
  of nkIdent:
    let view = parent.views.getOrDefault(n.ident)
    if view.isNil:
      lay.sourceError(errUndefinedView, n, n.ident)
    else:
      result = view.symNode
  of nkDotCall:
    ensure(n.len == 2)
    n[0] = lay.resolveView(n[0], parent)
    ensure(n[0].kind == nkSymbol)
    n[1] = lay.resolveView(n[1], n[0].sym.view)
    result = n[1]
  else:
    internalError(lay, errUnknownNode, n.kind)

proc getName(lay: Layout, view: View): string =
  result = $view.name
  var v = view.parent
  while v != lay.root and v != nil:
    result = $v.name & "." & result
    v = v.parent

proc processAnim(lay: Layout, aniNode, n: Node, ani: Animation) =
  lay.solver = ani.solver
  var dependencies = initSet[View]()

  let dest = newVarSet(lay.root.name)
  dest.setConstraint(ani.solver)
  lay.root.current = dest
  ani.solver.addConstraint(dest.top == 0)
  ani.solver.addConstraint(dest.left == 0)
  ani.solver.addConstraint(dest.width == screenWidth)
  ani.solver.addConstraint(dest.height == screenHeight)

  for m in n.sons:
    ensure(m.kind == nkAnim)
    let symNode = lay.resolveView(m[0], lay.root)
    m[0] = symNode
    let view = symNode.sym.view
    let destination = newVarSet(view.name)
    destination.setConstraint(ani.solver)
    dependencies.incl(view.dependencies)
    view.current = destination
    var startAni, endAni: float64

    if m[2].kind == nkEmpty and m[3].kind != nkEmpty:
      startAni = 0.0
      endAni = m[3].toNumber()
      if endAni > 1.0: endAni = 1.0
      if endAni <= 0.0: endAni = 0.01
    elif m[2].kind != nkEmpty and m[3].kind == nkEmpty:
      endAni = 1.0
      startAni = m[2].toNumber()
      if startAni < 0.0: startAni = 0.0
      if startAni >= 1.0: startAni = 0.99
    elif m[2].kind != nkEmpty and m[3].kind != nkEmpty:
      startAni = m[2].toNumber()
      endAni = m[3].toNumber()
      if startAni < 0.0: startAni = 0.0
      if startAni >= 1.0: startAni = 0.99
      if endAni < startAni: endAni = startAni + 0.01
      if endAni > 1.0: endAni = 1.0
    else:
      startAni = 0.0
      endAni = 1.0

    startAni = ani.duration * startAni
    endAni = ani.duration * endAni

    let interpolatorName = if m[4].kind == nkIdent: m[4].ident else: lay.getIdent("linearInterpolation")
    let interpolator = lay.context.getInterpolator(interpolatorName)
    if interpolator.isNil:
      lay.sourceError(errUndefinedInterpolator, m[4], m[4].ident)

    let anim = Anim(view: view, interpolator: interpolator, startAni: startAni, duration: endAni - startAni,
      destination: destination, current: newVarSet(view.name))
    ani.anims.add(anim)

  for m in n.sons:
    let view = m[0].sym.view
    lay.lastView = view
    let body = view.body.copyTree
    lay.secViewBody(body)
    lay.secViewClass(m[1])
    dependencies.excl(m[0].sym.view)

  dependencies.excl(lay.root)
  for v in dependencies:
    lay.sourceError(errNeedToParticipate, aniNode, lay.getName(v), aniNode.ident)
    break

  ani.solver.updateVariables()

proc secAnimList(lay: Layout, n: Node) =
  ensure(n.len == 3)
  let name = n[0].ident
  let duration = n[1].toNumber()

  let anim = lay.animTbl.getOrDefault(name)
  if anim.isNil:
    let ani = newAnimation(duration)
    let sym = newAnimationSymbol(n[0], ani).newSymbolNode()
    lay.animTbl[name] = sym
    lay.processAnim(n[0], n[2], ani)
  else:
    let prev = lay.context.toString(anim.lineInfo)
    lay.sourceError(errDuplicateAnim, n[0], name, prev)

proc secViewAndClass(lay: Layout, n: Node) =
  case n.kind
  of nkView: lay.secView(n)
  of nkClass: lay.secClass(n)
  of nkAnimList: discard
  of nkAliasList: discard # already done
  else:
    internalError(lay, errUnknownNode, n.kind)

proc secAnimation(lay: Layout, n: Node) =
  case n.kind
  of nkView, nkClass, nkAliasList: discard
  of nkAnimList: lay.secAnimList(n)
  else:
    internalError(lay, errUnknownNode, n.kind)

proc checkRecursiveAlias*(lay: Layout, sym: Symbol, n: Node) =
  case n.kind
  of NodeWithSons:
    for m in n.sons:
      lay.checkRecursiveAlias(sym, m)
  of nkIdent:
    if sym.name.id == n.ident.id:
      let prev = lay.context.toString(sym.lineInfo)
      lay.sourceError(errRecursiveAlias, n, sym.name, prev)
    else:
      let alias = lay.aliasTbl.getOrDefault(n.ident)
      if not alias.isNil:
        lay.checkRecursiveAlias(sym, alias.sym.alias)
  else: discard

proc secTopLevel*(lay: Layout, n: Node) =
  for s in values(lay.aliasTbl):
    lay.checkRecursiveAlias(s.sym, s.sym.alias)

  ensure(n.kind == nkStmtList)
  for son in n.sons:
    lay.secViewAndClass(son)

  for son in n.sons:
    lay.secAnimation(son)

  lay.root.setOrigin()

  for s in values(lay.classTbl):
    if sfUsed notin s.sym.flags:
      lay.sourceWarning(warnClassNotUsed, s, s.sym.name)

  for s in values(lay.aliasTbl):
    if sfUsed notin s.sym.flags:
      lay.sourceWarning(warnAliasNotUsed, s, s.sym.name)

proc luaBinding(lay: Layout) =
  var L = lay.context.getLua()

  #nimLuaOptions(nloDebug, true)
  L.bindObject(Ident):
    s(get)
    id(get)

  L.bindObject(View):
    newView -> "new"
    getName -> "_get_name"
    getChildren -> "_get_children"
    getTop -> "_get_top"
    getLeft -> "_get_left"
    getRight -> "_get_right"
    getBottom -> "_get_bottom"
    getWidth -> "_get_width"
    getHeight -> "_get_height"
    getCenterX -> "_get_centerX"
    getCenterY -> "_get_centerY"
    getNext -> "_get_next"
    getPrev -> "_get_prev"
    getNextIdx -> "getNext"
    getPrevIdx -> "getPrev"
    getParent -> "_get_parent"
    findChild
    idx(get)

  L.bindObject(Layout):
    getRoot
    getRoot -> "_get_root"
    getIdent
    id(get)
  #nimLuaOptions(nloDebug, false)

  # store Layout reference
  L.pushLightUserData(cast[pointer](genLuaID())) # push key
  L.pushLightUserData(cast[pointer](lay)) # push value
  L.setTable(LUA_REGISTRYINDEX)           # registry[lay.addr] = lay

  # register the only entry point of layout hierarchy to lua
  proc layoutProxy(L: PState): cint {.cdecl.} =
    getRegisteredType(Layout, mtName, pxName)
    var ret = cast[ptr pxName](L.newUserData(sizeof(pxName)))
    zeroMem(ret, sizeof(pxName))
    # retrieve Layout
    L.pushLightUserData(cast[pointer](getPrevID())) # push key
    L.getTable(LUA_REGISTRYINDEX)           # retrieve value
    ret.ud = cast[Layout](L.toUserData(-1)) # convert to layout
    L.pop(1) # remove userdata
    GC_ref(ret.ud)
    L.nimGetMetaTable(mtName)
    discard L.setMetatable(-2)
    return 1

  L.pushCfunction(layoutProxy)
  L.setGlobal("getLayout")

proc semCheck*(lay: Layout, n: Node) =
  lay.luaBinding()

  lay.origin.addConstraint(lay.root.origin.top == 0)
  lay.origin.addConstraint(lay.root.origin.left == 0)
  lay.origin.addConstraint(lay.root.origin.width == screenWidth)
  lay.origin.addConstraint(lay.root.origin.height == screenHeight)

  # semcheck first pass
  # collecting symbols
  # resolve view hierarchy
  # caching classes and styles
  # register prop
  # register event
  lay.semTopLevel(n)

  # semcheck second pass
  # create constraint and add it to solver
  # instantiate classes
  # applying prop
  # applying style
  # attaching event handler to view
  lay.secTopLevel(n)

  lay.origin.updateVariables()

  #[var L = lay.context.getLua()
  L.getGlobal("View")     # get View table
  discard L.pushString("onClick") # push the key "onClick"
  L.rawGet(-2)            # get the function
  if L.isNil(-1):
    echo "onClick not found"
  else:
    var proxy = L.getUD(lay.root) # push first argument
    ensure(proxy == lay.root)
    if L.pcall(1, 0, 0) != 0:
      let errorMsg = L.toString(-1)
      L.pop(1)
      lay.context.otherError(errLua, errorMsg)
  L.pop(1) # pop View Table
  ]#
