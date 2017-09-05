import ast, layout, idents, kiwi, tables, context, hashes, strutils
import nimLUA, keywords

type
  Layout* = ref object of IDobj
    root: View                   # every layout/scene root
    viewTbl: Table[View, Node]   # view to SymbolNode.skView
    classTbl: Table[Ident, Node] # string to SymbolNode.skClass
    solver: kiwi.Solver          # constraint solver
    context: Context             # ref to app global context
    lastView: View               # last processed parent view
    emptyNode: Node

template hash(view: View): Hash =
  hash(cast[int](view))

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

proc internalErrorImpl(lay: Layout, kind: MsgKind, fileName: string, line: int, args: varargs[string, `$`]) =
  # internal error aid debugging
  var err = new(InternalError)
  err.msg = lay.context.msgKindToString(kind, args)
  err.line = line
  err.fileName = fileName
  raise err

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

proc sourceError(lay: Layout, kind: MsgKind, n: Node, args: varargs[string, `$`]) =
  # report any error during semcheck
  var err = new(SourceError)
  err.msg = lay.context.msgKindToString(kind, args)
  err.line = n.lineInfo.line
  err.column = n.lineInfo.col
  err.lineContent = lay.getCurrentLine(n.lineInfo)
  err.fileIndex = n.lineInfo.fileIndex
  raise err

proc semViewName(lay: Layout, n: Node, lastIdent: Node): Node =
  # check and resolve view name hierarchy
  # such as view1.view1child.view1grandson
  case n.kind
  of nkDotCall:
    assert(n.sons.len == 2)
    n[0] = lay.semViewName(n[0], lastIdent)
    assert(n[0].kind == nkSymbol)
    lay.lastView = n[0].sym.view
    n[1] = lay.semViewName(n[1], lastIdent)
    result = n[1]
  of nkIdent:
    var view = lay.lastView.views.getOrDefault(n.ident)
    if view.isNil:
      result = lay.createView(n)
    else:
      assert(lay.viewTbl.hasKey(view))
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
  discard

proc semPropList(lay: Layout, n: Node) =
  discard

proc semViewBody(lay: Layout, n: Node): Node =
  assert(n.kind in {nkStmtList, nkEmpty})

  for m in n.sons:
    case m.kind
    of nkConstList: lay.semConstList(m)
    of nkEventList: lay.semEventList(m)
    of nkPropList:  lay.semPropList(m)
    of nkEmpty: discard
    else:
      internalError(lay, errUnknownNode, m.kind)

  result = n

proc semView(lay: Layout, n: Node) =
  assert(n.sons.len == 3)
  # each time we create new view
  # need to reset the lastView
  lay.lastView = lay.root
  var lastIdent = Node(nil)
  if n[0].kind == nkIdent: lastIdent = n[0]
  if lastIdent.isNil and n[0].kind == nkDotCall:
    let son = n[0].sons[1]
    if son.kind == nkIdent: lastIdent = son
  n[0] = lay.semViewName(n[0], lastIdent)
  n[1] = lay.semViewClass(n[1])
  n[2] = lay.semViewBody(n[2])

proc semClass(lay: Layout, n: Node) =
  assert(n.sons.len == 3)
  let className = n[0]
  let symNode = lay.classTbl.getOrDefault(className.ident)
  if symNode.isNil:
    let sym = newClassSymbol(className, n)
    n[0] = newSymbolNode(sym)
    lay.classTbl[className.ident] = n[0]
  else:
    let info = symNode.lineInfo
    let prev = lay.context.toString(info)
    lay.sourceError(errDuplicateClass, className, symNode.symString, prev)

proc semStmt(lay: Layout, n: Node) =
  case n.kind
  of nkView: lay.semView(n)
  of nkClass: lay.semClass(n)
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semTopLevel*(lay: Layout, n: Node) =
  assert(n.kind == nkStmtList)
  for son in n.sons:
    lay.semStmt(son)

const layoutSingleton = 0xDEADBEEF

proc luaBinding(lay: Layout) =
  var L = lay.context.getLua()

  #nimLuaOptions(nloDebug, true)
  L.bindObject(View):
    newView -> "new"
    getName
    getChildren
  #nimLuaOptions(nloDebug, false)

  L.bindObject(Layout):
    getRoot

  # store Layout reference
  L.pushLightUserData(cast[pointer](layoutSingleton)) # push key
  L.pushLightUserData(cast[pointer](lay)) # push value
  L.setTable(LUA_REGISTRYINDEX)           # registry[lay.addr] = lay

  # register the only entry point of layout hierarchy to lua
  proc layoutProxy(L: PState): cint {.cdecl.} =
    getRegisteredType(Layout, mtName, pxName)
    var ret = cast[ptr pxName](L.newUserData(sizeof(pxName)))

    # retrieve Layout
    L.pushLightUserData(cast[pointer](layoutSingleton)) # push key
    L.getTable(LUA_REGISTRYINDEX)           # retrieve value
    ret.ud = cast[Layout](L.toUserData(-1)) # convert to layout
    L.pop(1) # remove userdata
    GC_ref(ret.ud)
    L.getMetatable(mtName)
    discard L.setMetatable(-2)
    return 1

  L.pushCfunction(layoutProxy)
  L.setGlobal("getLayout")

  lay.context.executeLua("apple.lua")

proc secViewClass(lay: Layout, n: Node) =
  assert(n.kind in {nkViewClassList, nkEmpty})
  for vc in n.sons:
    assert(vc.kind == nkViewClass)
    assert(vc.len == 2)
    let name = vc.sons[0]
    let params = vc.sons[1]
    assert(name.kind == nkIdent)
    let classNode = lay.classTbl.getOrDefault(name.ident)
    if classNode.isNil:
      lay.sourceError(errClassNotFound, name, name.ident.s)
    else:
      vc.sons[0] = classNode
      let class = classNode.sym.class
      let classParams = class[1]
      assert(classParams.kind == nkClassParams)
      if params.len != classParams.len:
        lay.sourceError(errParamCountNotMatch, params, classParams.len, params.len)

proc toKeyWord(n: Node): SpecialWords =
  assert(n.kind == nkIdent)
  if n.ident.id > 0 and n.ident.id <= ord(high(SpecialWords)):
    result = SpecialWords(n.ident.id)
  else:
    result = wInvalid

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
      if i >= 0:
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
        lay.sourceError(errUndefinedProp, n, n.ident)
    else:
      if id in constRel:
        let view = lay.selectViewRel(lay.lastView, id)
        if view.isNil:
          if choiceMode:
            return lay.emptyNode
          else:
            lay.sourceError(errWrongRelation, n, n.ident)
        result = lay.viewTbl[view]
      else:
        lay.sourceError(errUndefinedRel, n, n.ident)
  of nkDotCall:
    let tempView = lay.lastView
    assert(n.sons.len == 2)
    n[0] = lay.resolveTerm(n[0], lastIdent, choiceMode)
    if choiceMode and n[0].kind == nkEmpty: return n[0]
    assert(n[0].kind == nkSymbol)
    lay.lastView = n[0].sym.view
    n[1] = lay.resolveTerm(n[1], lastIdent, choiceMode)
    if choiceMode and n[1].kind == nkEmpty: return n[1]
    lay.lastView = tempView
    result = n[1]
  of nkBracketExpr:
    assert(n.sons.len == 2)
    assert(n[0].kind == nkIdent)
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

proc termOp(lay: Layout, a, b, op: Node, id: SpecialWords): Node =
  case id
  of wPlus:  result = lay.termOpPlus(a, b, op)
  of wMinus: result = lay.termOpMinus(a, b, op)
  of wMul:   result = lay.termOpMul(a, b, op)
  of wDiv:   result = lay.termOpDiv(a, b, op)
  else: internalError(lay, errUnknownOpr, id)

proc secConstExpr(lay: Layout, n: Node, choiceMode = false): Node =
  case n.kind
  of nkIdent:
    let id = toKeyWord(n)
    if id in constProp:
      result = newNodeI(nkConstVar, n.lineInfo)
      result.variable = lay.selectViewProp(lay.lastView, id)
    else:
      lay.sourceError(errUndefinedProp, n, n.ident)
  of nkUint:
    result = n
  of nkDotCall:
    assert(n.sons.len == 2)
    assert(n[1].kind == nkIdent)
    result = lay.resolveTerm(n, n[1].ident, choiceMode)
  of nkInfix:
    assert(n.len == 3)
    let id = toKeyWord(n[0])
    if id notin constTermOp:
      lay.sourceError(errUnknownOpr, n[0], n[0].ident.s)
    let lhs = lay.secConstExpr(n[1], choiceMode)
    let rhs = lay.secConstExpr(n[2], choiceMode)
    if choiceMode:
      if lhs.kind == nkEmpty or lhs.kind == nkEmpty:
        return lay.emptyNode
    result = lay.termOp(lhs, rhs, n[0], id)
  of nkString:
    lay.sourceError(errStringNotAllowed, n)
  of nkChoice:
    for cc in n.sons:
      result = lay.secConstExpr(cc, true)
      if result.kind != nkEmpty: return result
    lay.sourceError(errNoValidBranch, n)
  else:
    internalError(lay, errUnknownNode, n.kind)

proc constOpEQ(lay: Layout, a, b: Node) =
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
  else: internalError(lay, errUnknownOperation, a.kind, '=', b.kind)

proc constOpLE(lay: Layout, a, b: Node) =
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
  else: internalError(lay, errUnknownOperation, a.kind, "<=", b.kind)

proc constOpGE(lay: Layout, a, b: Node) =
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
  else: internalError(lay, errUnknownOperation, a.kind, ">=", b.kind)

proc constOp(lay: Layout, a, b: Node, id: SpecialWords) =
  case id
  of wEquals: lay.constOpEQ(a, b)
  of wGreaterOrEqual: lay.constOpGE(a, b)
  of wLessOrEqual: lay.constOpLE(a, b)
  else: internalError(lay, errUnknownOpr, id)

proc secConstList(lay: Layout, n: Node) =
  assert(n.kind == nkConstList)
  for cc in n.sons:
    assert(cc.kind == nkConst)
    assert(cc.len >= 3)
    for i in countup(0, cc.sons.len-2, 2):
      let lhs = cc.sons[i]
      let op  = cc.sons[i+1]
      let rhs = cc.sons[i+2]
      let opId = toKeyWord(op)
      assert(opId in constOpr)
      cc.sons[i] = lay.secConstExpr(lhs)
      cc.sons[i+2] = lay.secConstExpr(rhs)
      lay.constOp(cc.sons[i], cc.sons[i+2], opId)

proc secEventList(lay: Layout, n: Node) =
  discard

proc secPropList(lay: Layout, n: Node) =
  discard

proc secViewBody(lay: Layout, n: Node) =
  for m in n.sons:
    case m.kind
    of nkConstList: lay.secConstList(m)
    of nkEventList: lay.secEventList(m)
    of nkPropList:  lay.secPropList(m)
    of nkEmpty: discard
    else:
      internalError(lay, errUnknownNode, m.kind)

proc secView(lay: Layout, n: Node) =
  # skip name node
  assert(n[0].kind == nkSymbol)
  assert(n[0].sym.kind == skView)
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
  assert(n.kind == nkStmtList)
  for son in n.sons:
    lay.secStmt(son)

proc semCheck*(lay: Layout, n: Node) =
  lay.semTopLevel(n)
  lay.secTopLevel(n)

  echo n.treeRepr
  lay.solver.updateVariables()

  for v in keys(lay.viewTbl):
    v.print
