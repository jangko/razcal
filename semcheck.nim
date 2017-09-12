import ast, layout, idents, kiwi, tables, context, hashes, strutils
import nimLUA, keywords

type
  Layout* = ref object of IDobj
    root: View                   # every layout/scene root
    viewTbl: Table[View, Node]   # view to SymbolNode.skView
    classTbl: Table[Ident, Node] # string to SymbolNode.skClass
    solver: kiwi.Solver          # constraint solver
    context: Context             # ref to app global context
    lastView: View               # last processed parent view/current View
    emptyNode: Node

template hash(view: View): Hash =
  hash(cast[int](view))

proc newInternalError(fileName: string, line: int, msg: string): InternalError =
  new(result)
  result.msg = msg
  result.line = line
  result.fileName = fileName

template ensure(cond: bool) =
  if not cond: raise newInternalError(instantiationInfo().fileName,
    instantiationInfo().line, astToStr(cond))

proc toKeyWord(n: Node): SpecialWords =
  ensure(n.kind == nkIdent)
  if n.ident.id > 0 and n.ident.id <= ord(high(SpecialWords)):
    result = SpecialWords(n.ident.id)
  else:
    result = wInvalid

proc createView(lay: Layout, n: Node): Node =
  var view = lay.lastView.newView(n.ident)
  result   = newViewSymbol(n, view).newSymbolNode()
  lay.lastView = view
  lay.viewTbl[view] = result
  lay.solver.setBasicConstraint(view)

proc newLayout*(id: int, context: Context): Layout =
  new(result)
  result.id = id
  result.viewTbl = initTable[View, Node]()
  result.classTbl = initTable[Ident, Node]()
  result.solver = newSolver()
  result.context = context
  result.emptyNode = newNode(nkEmpty)

  let root = context.getIdent("root")
  let n = newIdentNode(root)
  result.root = newView(root)
  result.viewTbl[result.root] = newViewSymbol(n, result.root).newSymbolNode()
  result.solver.setBasicConstraint(result.root)

proc getRoot(lay: Layout): View =
  result = lay.root

proc getIdent(lay: Layout, s: string): Ident =
  result = lay.context.getIdent(s)

proc internalErrorImpl(lay: Layout, kind: MsgKind, fileName: string, line: int, args: varargs[string, `$`]) =
  # internal error aid debugging
  raise newInternalError(fileName, line, lay.context.msgKindToString(kind, args))

template internalError(lay: Layout, kind: MsgKind, args: varargs[string, `$`]) =
  # pointing to Nim source code location
  # where the error occured
  lay.internalErrorImpl(kind,
    instantiationInfo().fileName,
    instantiationInfo().line,
    args)

proc otherError(lay: Layout, kind: MsgKind, args: varargs[string, `$`]) =
  lay.context.otherError(kind, args)

proc getCurrentLine*(lay: Layout, info: context.LineInfo): string =
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
      ensure(lay.viewTbl.hasKey(view))
      let symNode = lay.viewTbl[view]
      if lastIdent == n:
        let info = symNode.lineInfo
        let prev = lay.context.toString(info)
        lay.sourceError(errDuplicateView, n, symNode.symString, prev)
      result = symNode
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semViewClass(lay: Layout, n: Node): Node =
  result = n

proc semConstList(lay: Layout, n: Node) =
  discard

proc semEventList(lay: Layout, n: Node) =
  for ev in n.sons:
    ensure(ev.kind == nkEvent)
    ensure(ev[0].kind == nkIdent)
    let id = toKeyword(ev[0])
    if id notin validEvents:
      lay.sourceError(errUndefinedEvent, ev[0], ev[0].ident)

proc semPropList(lay: Layout, n: Node) =
  for prop in n.sons:
    ensure(prop.kind == nkProp)
    ensure(prop[0].kind == nkIdent)
    let id = toKeyword(prop[0])
    if id notin validProps:
      lay.sourceError(errUndefinedProp, prop[0], prop[0].ident)

proc semViewBody(lay: Layout, n: Node): Node =
  ensure(n.kind in {nkStmtList, nkEmpty})

  for m in n.sons:
    case m.kind
    of nkFlexList: lay.semConstList(m)
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

  # at this point, the view already created
  # and n[0] already replaced with a symbolNode
  lay.lastView = n[0].sym.view
  n[1] = lay.semViewClass(n[1])
  n[2] = lay.semViewBody(n[2])

proc subst(lay: Layout, n: Node, cls: ClassContext): Node =
  case n.kind
  of nkFlexList, nkFlex, nkDotCall:
    for i in 0.. <n.len:
      n[i] = lay.subst(n[i], cls)
    result = n
  of nkIdent:
    let sym = cls.paramTable.getOrDefault(n.ident)
    if not sym.isNil:
      sym.sym.flags.incl(sfUsed)
      return sym
    result = n
  of nkUint:
    result = n
  else:
    internalError(lay, errUnknownNode, n.kind)

proc substituteParams(lay: Layout, n: Node, cls: ClassContext) =
  for i in 0.. <n.len:
    n[i] = lay.subst(n[i], cls)

  for s in values(cls.paramTable):
    if sfUsed notin s.sym.flags:
      lay.sourceWarning(warnParamNotUsed, s, s.sym.name)

proc collectParams(lay: Layout, n: Node, cls: ClassContext) =
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

proc semStmt(lay: Layout, n: Node) =
  case n.kind
  of nkView: lay.semView(n)
  of nkClass: lay.semClass(n)
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semTopLevel*(lay: Layout, n: Node) =
  ensure(n.kind == nkStmtList)
  for son in n.sons:
    lay.semStmt(son)

# entering second pass
proc secViewBody(lay: Layout, n: Node)

proc checkParamCountMatch(lay: Layout, params, classParams: Node) =
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
  case n.kind
  of nkStmtList, nkFlexList, nkFlex, nkDotCall, nkChoice:
    for i in 0.. <n.len:
      n[i] = lay.instClass(n[i], cls, params)
    result = n
  of nkSymbol:
    if n.sym.pos >= 0 and n.sym.pos < params.len:
      result = params[n.sym.pos]
    else:
      result = n.sym.value
  of nkIdent, nkUInt:
    result = n
  else:
    internalError(lay, errUnknownNode, n.kind)

proc instantiateClass(lay: Layout, cls: ClassContext, params: Node): Node =
  # copy only the class body which is essentialy
  # has the same structure with view body
  var n = cls.n[2].copyTree()
  for i in 0.. <n.len:
    n[i] = lay.instClass(n[i], cls, params)

  lay.secViewbody(n)
  result = n

proc secViewClass(lay: Layout, n: Node) =
  ensure(n.kind in {nkViewClassList, nkEmpty})
  for vc in n.sons:
    ensure(vc.kind == nkViewClass)
    ensure(vc.len == 2)
    let name = vc.sons[0]
    let params = vc.sons[1]
    ensure(name.kind == nkIdent)
    let classSymbol = lay.classTbl.getOrDefault(name.ident)
    if classSymbol.isNil:
      lay.sourceError(errClassNotFound, name, name.ident.s)
    # replace name with symbol
    vc.sons[0] = classSymbol
    let class = classSymbol.sym.class
    let classParams = class.n[1]
    lay.checkParamCountMatch(params, classParams)
    # replace param(s) with intantiated class
    vc.sons[1] = lay.instantiateClass(class, params)

proc selectViewProp(lay: Layout, view: View, id: SpecialWords): Variable =
  case id
  of wLeft: result = view.left
  of wRight: result = view.right
  of wTop: result = view.top
  of wBottom: result = view.bottom
  of wWidth: result = view.width
  of wHeight: result = view.height
  of wCenterX: result = view.centerX
  of wCenterY: result = view.centerY
  else:
    internalError(lay, errUnknownProp, id)

proc selectViewRel(lay: Layout, view: View, id: SpecialWords, idx = 1): View =
  # idx = -1 means the last
  case id
  of wThis:
    result = view
  of wParent:
    result = view.parent
    if idx > 1:
      var i = 1
      while i < idx:
        if result.isNil: break
        result = result.parent
        inc i
  of wChild:
    if idx < 0: return view.children[^1]
    if idx < view.children.len:
      result = view.children[idx]
  of wPrev:
    if not view.parent.isNil:
      if idx < 0: return view.parent.children[0]
      let i = view.idx - idx
      if i >= 0 and i < view.parent.children.len:
        result = view.parent.children[i]
  of wNext:
    if not view.parent.isNil:
      if idx < 0: return view.parent.children[^1]
      let i = view.idx + idx
      if i < view.parent.children.len:
        result = view.parent.children[i]
  else:
    internalError(lay, errUnknownRel, id)

proc resolveTerm(lay: Layout, n: Node, lastIdent: Ident, choiceMode = false): Node =
  case n.kind
  of nkIdent:
    let id = toKeyWord(n)
    if n.ident == lastIdent:
      if id in constProp:
        result = newNodeI(nkConstVar, n.lineInfo)
        result.variable = lay.selectViewProp(lay.lastView, id)
      else:
        lay.sourceError(errUndefinedVar, n, n.ident)
    else:
      let view = if id in constRel: lay.selectViewRel(lay.lastView, id)
        else: lay.lastView.views.getOrDefault(n.ident)
      if view.isNil:
        if choiceMode: return lay.emptyNode
        else: lay.sourceError(errRelationNotFound, n, n.ident, lay.lastView.name)
      result = lay.viewTbl[view]
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
    ensure(n[0].kind == nkIdent)
    let id = toKeyWord(n[0])
    if id in constRel:
      var idx = 1
      if n[1].kind == nkEmpty: idx = -1
      elif n[1].kind == nkUInt: idx = int(n[1].uintVal)
      else: internalError(lay, errUnknownNode, n[1].kind)
      let view = lay.selectViewRel(lay.lastView, id, idx)
      if view.isNil:
        if choiceMode:
          return lay.emptyNode
        else:
          lay.sourceError(errWrongRelationIndex, n[1], idx)
      result = lay.viewTbl[view]
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
  elif a.kind in numberNode and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() + b.variable
  elif a.kind in numberNode and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() + b.expression
  elif a.kind in numberNode and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() + b.term
  elif a.kind == nkConstVar and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable + b.toNumber()
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable + b.expression
  elif a.kind == nkConstVar and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable + b.term
  elif a.kind == nkConstVar and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable + b.variable
  elif a.kind == nkConstExpr and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression + b.toNumber()
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression + b.variable
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression + b.expression
  elif a.kind == nkConstExpr and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression + b.term
  elif a.kind == nkConstTerm and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term + b.term
  elif a.kind == nkConstTerm and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term + b.expression
  elif a.kind == nkConstTerm and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term + b.variable
  elif a.kind == nkConstTerm and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term + b.toNumber()
  else: internalError(lay, errUnknownOperation, a.kind, "'+'", b.kind)

proc termOpMinus(lay: Layout, a, b, op: Node): Node =
  if a.kind == nkConstExpr and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression - b.toNumber()
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression - b.variable
  elif a.kind == nkConstExpr and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression - b.term
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression - b.expression
  elif a.kind == nkConstTerm and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term - b.expression
  elif a.kind == nkConstTerm and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term - b.term
  elif a.kind == nkConstTerm and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term - b.variable
  elif a.kind == nkConstTerm and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.term - b.toNumber()
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable - b.expression
  elif a.kind == nkConstVar and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable - b.term
  elif a.kind == nkConstVar and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable - b.variable
  elif a.kind == nkConstVar and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.variable - b.toNumber()
  elif a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() - b.toNumber()
  elif a.kind in numberNode and b.kind == nkConstVar:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() - b.variable
  elif a.kind in numberNode and b.kind == nkConstTerm:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() - b.term
  elif a.kind in numberNode and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() - b.expression
  else: internalError(lay, errUnknownOperation, a.kind, "'-'", b.kind)

proc termOpMul(lay: Layout, a, b, op: Node): Node =
  if a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() * b.toNumber()
  elif a.kind in numberNode and b.kind == nkConstVar:
    result = newNodeI(nkConstTerm, a.lineInfo)
    result.term = a.toNumber() * b.variable
  elif a.kind in numberNode and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.toNumber() * b.expression
  elif a.kind in numberNode and b.kind == nkConstTerm:
    result = newNodeI(nkConstTerm, a.lineInfo)
    result.term = a.toNumber() * b.term
  elif a.kind == nkConstVar and b.kind in numberNode:
    result = newNodeI(nkConstTerm, a.lineInfo)
    result.term = a.variable * b.toNumber()
  elif a.kind == nkConstExpr and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression * b.toNumber()
  elif a.kind == nkConstTerm and b.kind in numberNode:
    result = newNodeI(nkConstTerm, a.lineInfo)
    result.term = a.term * b.toNumber()
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression * b.expression
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    #result = newNodeI(nkConstExpr, a.lineInfo)
    #result.expression = a.expression * b.variable
    lay.sourceError(errIllegalOperation, op, a.kind, "'*'", b.kind)
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    #result = newNodeI(nkConstExpr, a.lineInfo)
    #result.expression = a.variable * b.expression
    lay.sourceError(errIllegalOperation, op, a.kind, "'*'", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, "'*'", b.kind)

proc termOpDiv(lay: Layout, a, b, op: Node): Node =
  if a.kind == nkConstVar and b.kind in numberNode:
    result = newNodeI(nkConstTerm, a.lineInfo)
    result.term = a.variable / b.toNumber()
  elif a.kind == nkConstTerm and b.kind in numberNode:
    result = newNodeI(nkConstTerm, a.lineInfo)
    result.term = a.term / b.toNumber()
  elif a.kind == nkConstExpr and b.kind in numberNode:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression / b.toNumber()
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    result = newNodeI(nkConstExpr, a.lineInfo)
    result.expression = a.expression / b.expression
  elif a.kind in numberNode and b.kind in numberNode:
    result = newNodeI(nkFloat, a.lineInfo)
    result.floatVal = a.toNumber() / b.toNumber()
  elif a.kind in numberNode and b.kind == nkConstVar:
    #result = newNodeI(nkConstExpr, a.lineInfo)
    #result.expression = a.toNumber() / b.variable
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  elif a.kind in numberNode and b.kind == nkConstExpr:
    #result = newNodeI(nkConstExpr, a.lineInfo)
    #result.expression = a.toNumber() / b.expression
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    #result = newNodeI(nkConstExpr, a.lineInfo)
    #result.expression = a.expression / b.variable
    lay.sourceError(errIllegalOperation, op, a.kind, "'/'", b.kind)
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    #result = newNodeI(nkConstExpr, a.lineInfo)
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
  of nkConstVar:
    result = newNodeI(nkConstTerm, operand.lineInfo)
    result.term = -operand.variable
  of nkConstTerm:
    result = newNodeI(nkConstTerm, operand.lineInfo)
    result.term = -operand.term
  of nkConstExpr:
    result = newNodeI(nkConstExpr, operand.lineInfo)
    result.expression = -operand.expression
  else: internalError(lay, errUnknownPrefix, "'-'", operand.kind)

proc unaryTermOp(lay: Layout, operand, op: Node, id: SpecialWords): Node =
  case id
  of wMinus: result = lay.termPrefixMinus(operand, op)
  else: internalError(lay, errUnknownPrefixOpr, id)

proc secConstExpr(lay: Layout, n: Node, choiceMode = false): Node =
  case n.kind
  of nkIdent:
    let id = toKeyWord(n)
    if id in constProp:
      result = newNodeI(nkConstVar, n.lineInfo)
      result.variable = lay.selectViewProp(lay.lastView, id)
    else:
      lay.sourceError(errUndefinedVar, n, n.ident)
  of nkUint:
    result = n
  of nkDotCall:
    ensure(n.len == 2)
    ensure(n[1].kind == nkIdent)
    result = lay.resolveTerm(n, n[1].ident, choiceMode)
  of nkInfix:
    ensure(n.len == 3)
    let id = toKeyWord(n[0])
    if id notin constBinaryTermOp:
      lay.sourceError(errIllegalBinaryOpr, n[0], n[0].ident)
    let lhs = lay.secConstExpr(n[1], choiceMode)
    let rhs = lay.secConstExpr(n[2], choiceMode)
    if choiceMode:
      if lhs.kind == nkEmpty or lhs.kind == nkEmpty:
        return lay.emptyNode
    result = lay.binaryTermOp(lhs, rhs, n[0], id)
  of nkString:
    lay.sourceError(errStringNotAllowed, n)
  of nkChoice:
    for cc in n.sons:
      result = lay.secConstExpr(cc, true)
      if result.kind != nkEmpty: return result
    lay.sourceError(errNoValidBranch, n)
  of nkPrefix:
    ensure(n.len == 2)
    let id = toKeyWord(n[0])
    if id notin constUnaryTermOp:
      lay.sourceError(errIllegalPrefixOpr, n[0], n[0].ident)
    let operand = lay.secConstExpr(n[1], choiceMode)
    if choiceMode and operand.kind == nkEmpty:
      return lay.emptyNode
    result = lay.unaryTermOp(operand, n[0], id)
  of nkConstVar, nkConstExpr, nkConstTerm:
    # already processed, just return it
    result = n
  else:
    internalError(lay, errUnknownNode, n.kind)

proc constOpEQ(lay: Layout, a, b, op: Node) =
  if a.kind in numberNode and b.kind == nkConstVar:
    lay.solver.addConstraint(a.toNumber() == b.variable)
  elif a.kind in numberNode and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.toNumber() == b.expression)
  elif a.kind in numberNode and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.toNumber() == b.term)
  elif a.kind == nkConstVar and b.kind in numberNode:
    lay.solver.addConstraint(a.variable == b.toNumber())
  elif a.kind == nkConstVar and b.kind == nkConstVar:
    lay.solver.addConstraint(a.variable == b.variable)
  elif a.kind == nkConstVar and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.variable == b.term)
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.variable == b.expression)
  elif a.kind == nkConstTerm and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.term == b.expression)
  elif a.kind == nkConstTerm and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.term == b.term)
  elif a.kind == nkConstTerm and b.kind == nkConstVar:
    lay.solver.addConstraint(a.term == b.variable)
  elif a.kind == nkConstTerm and b.kind in numberNode:
    lay.solver.addConstraint(a.term == b.toNumber())
  elif a.kind == nkConstExpr and b.kind in numberNode:
    lay.solver.addConstraint(a.expression == b.toNumber())
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    lay.solver.addConstraint(a.expression == b.variable)
  elif a.kind == nkConstExpr and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.expression == b.term)
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.expression == b.expression)
  elif a.kind in numberNode and b.kind in numberNode:
    lay.sourceError(errIllegalOperation, op, a.kind, "=", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, '=', b.kind)

proc constOpLE(lay: Layout, a, b, op: Node) =
  if a.kind in numberNode and b.kind == nkConstVar:
    lay.solver.addConstraint(a.toNumber() <= b.variable)
  elif a.kind in numberNode and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.toNumber() <= b.expression)
  elif a.kind in numberNode and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.toNumber() <= b.term)
  elif a.kind == nkConstVar and b.kind in numberNode:
    lay.solver.addConstraint(a.variable <= b.toNumber())
  elif a.kind == nkConstVar and b.kind == nkConstVar:
    lay.solver.addConstraint(a.variable <= b.variable)
  elif a.kind == nkConstVar and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.variable <= b.term)
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.variable <= b.expression)
  elif a.kind == nkConstTerm and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.term <= b.expression)
  elif a.kind == nkConstTerm and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.term <= b.term)
  elif a.kind == nkConstTerm and b.kind == nkConstVar:
    lay.solver.addConstraint(a.term <= b.variable)
  elif a.kind == nkConstTerm and b.kind in numberNode:
    lay.solver.addConstraint(a.term <= b.toNumber())
  elif a.kind == nkConstExpr and b.kind in numberNode:
    lay.solver.addConstraint(a.expression <= b.toNumber())
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    lay.solver.addConstraint(a.expression <= b.variable)
  elif a.kind == nkConstExpr and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.expression <= b.term)
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.expression <= b.expression)
  elif a.kind in numberNode and b.kind in numberNode:
    lay.sourceError(errIllegalOperation, op, a.kind, "<=", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, "<=", b.kind)

proc constOpGE(lay: Layout, a, b, op: Node) =
  if a.kind in numberNode and b.kind == nkConstVar:
    lay.solver.addConstraint(a.toNumber() >= b.variable)
  elif a.kind in numberNode and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.toNumber() >= b.expression)
  elif a.kind in numberNode and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.toNumber() >= b.term)
  elif a.kind == nkConstVar and b.kind in numberNode:
    lay.solver.addConstraint(a.variable >= b.toNumber())
  elif a.kind == nkConstVar and b.kind == nkConstVar:
    lay.solver.addConstraint(a.variable >= b.variable)
  elif a.kind == nkConstVar and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.variable >= b.term)
  elif a.kind == nkConstVar and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.variable >= b.expression)
  elif a.kind == nkConstTerm and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.term >= b.expression)
  elif a.kind == nkConstTerm and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.term >= b.term)
  elif a.kind == nkConstTerm and b.kind == nkConstVar:
    lay.solver.addConstraint(a.term >= b.variable)
  elif a.kind == nkConstTerm and b.kind in numberNode:
    lay.solver.addConstraint(a.term >= b.toNumber())
  elif a.kind == nkConstExpr and b.kind in numberNode:
    lay.solver.addConstraint(a.expression >= b.toNumber())
  elif a.kind == nkConstExpr and b.kind == nkConstVar:
    lay.solver.addConstraint(a.expression >= b.variable)
  elif a.kind == nkConstExpr and b.kind == nkConstTerm:
    lay.solver.addConstraint(a.expression >= b.term)
  elif a.kind == nkConstExpr and b.kind == nkConstExpr:
    lay.solver.addConstraint(a.expression >= b.expression)
  elif a.kind in numberNode and b.kind in numberNode:
    lay.sourceError(errIllegalOperation, op, a.kind, "<=", b.kind)
  else: internalError(lay, errUnknownOperation, a.kind, ">=", b.kind)

proc constOp(lay: Layout, a, b, op: Node, id: SpecialWords) =
  case id
  of wEquals: lay.constOpEQ(a, b, op)
  of wGreaterOrEqual: lay.constOpGE(a, b, op)
  of wLessOrEqual: lay.constOpLE(a, b, op)
  else: internalError(lay, errUnknownEqualityOpr, id)

proc secChoiceList(lay: Layout, lhs, rhs, op: Node, opId: SpecialWords) =
  if rhs.kind != nkChoiceList: lay.sourceError(errUnbalancedArm, op)
  if rhs.len != lhs.len: lay.sourceError(errUnbalancedArm, op)
  for i in 0.. <lhs.len:
    lhs[i] = lay.secConstExpr(lhs[i])
    rhs[i] = lay.secConstExpr(rhs[i])
    lay.constOp(lhs[i], rhs[i], op, opId)

proc secConstList(lay: Layout, n: Node) =
  ensure(n.kind == nkFlexList)
  for cc in n.sons:
    ensure(cc.kind == nkFlex)
    ensure(cc.len >= 3)
    for i in countup(0, cc.sons.len-2, 2):
      let lhs = cc.sons[i]
      let op  = cc.sons[i+1]
      let rhs = cc.sons[i+2]
      let opId = toKeyWord(op)
      ensure(opId in constOpr)
      if lhs.kind == nkChoiceList:
        lay.secChoiceList(lhs, rhs, op, opId)
      else:
        cc.sons[i] = lay.secConstExpr(lhs)
        cc.sons[i+2] = lay.secConstExpr(rhs)
        lay.constOp(cc.sons[i], cc.sons[i+2], op, opId)

proc secEventList(lay: Layout, n: Node) =
  discard

proc secPropList(lay: Layout, n: Node) =
  discard

proc secViewBody(lay: Layout, n: Node) =
  ensure(n.kind in {nkStmtList, nkEmpty})
  for m in n.sons:
    case m.kind
    of nkFlexList: lay.secConstList(m)
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
  lay.secViewBody(n[2])

proc secClass(lay: Layout, n: Node) =
  discard

proc secStmt(lay: Layout, n: Node) =
  case n.kind
  of nkView: lay.secView(n)
  of nkClass: lay.secClass(n)
  else:
    internalError(lay, errUnknownNode, n.kind)

proc secTopLevel*(lay: Layout, n: Node) =
  ensure(n.kind == nkStmtList)
  for son in n.sons:
    lay.secStmt(son)

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
  L.pushLightUserData(cast[pointer](NLMaxID)) # push key
  L.pushLightUserData(cast[pointer](lay)) # push value
  L.setTable(LUA_REGISTRYINDEX)           # registry[lay.addr] = lay

  # register the only entry point of layout hierarchy to lua
  proc layoutProxy(L: PState): cint {.cdecl.} =
    getRegisteredType(Layout, mtName, pxName)
    var ret = cast[ptr pxName](L.newUserData(sizeof(pxName)))

    # retrieve Layout
    L.pushLightUserData(cast[pointer](NLMaxID)) # push key
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

  #echo n.treeRepr
  lay.solver.updateVariables()
  lay.context.executeLua("apple.lua")

  var L = lay.context.getLua()
  L.getGlobal("View")     # get View table
  discard L.pushString("onClick") # push the key "onClick"
  L.rawGet(-2)            # get the function
  if L.isNil(-1):
    echo "onClick not found"
  else:
    var proxy = L.getUD(lay.root) # push first argument
    assert(proxy == lay.root)
    if L.pcall(1, 0, 0) != 0:
      let errorMsg = L.toString(-1)
      L.pop(1)
      lay.context.otherError(errLua, errorMsg)
  L.pop(1) # pop View Table
