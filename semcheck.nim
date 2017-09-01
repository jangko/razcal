import ast, layout, idents, kiwi, tables, context, hashes, strutils
import nimLUA

type
  Layout* = ref object of IDobj
    root*: View                      # every layout/scene root
    viewTbl*: Table[View, Node]      # view to SymbolNode.skView
    classTbl*: Table[string, Node]   # string to SymbolNode.skClass
    solver*: kiwi.Solver             # constraint solver
    context*: Context                # ref to app global context
    lastParent*: View                # last processed parent view

proc hash(view: View): Hash =
  hash(cast[int](view))

proc newLayout*(id: int, context: Context): Layout =
  new(result)
  result.id = id
  result.root = newView("layout" & $id)
  result.viewTbl = initTable[View, Node]()
  result.classTbl = initTable[string, Node]()
  result.solver = newSolver()
  result.context = context

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

proc createView(lay: Layout, n: Node): Node =
  var view = lay.lastParent.newView(n.identString)
  result   = newViewSymbol(n, view).newSymbolNode()
  lay.lastParent = view
  lay.viewTbl[view] = result
  lay.solver.setBasicConstraint(view)

proc semViewName(lay: Layout, n: Node, lastIdent: Node): Node =
  # check and resolve view name hierarchy
  # such as view1.view1child.view1grandson
  case n.kind
  of nkDotCall:
    assert(n.sons.len == 2)
    n[0] = lay.semViewName(n[0], lastIdent)
    assert(n[0].kind == nkSymbol)
    lay.lastParent = n[0].sym.view
    n[1] = lay.semViewName(n[1], lastIdent)
    result = n[1]
  of nkIdent:
    var view = lay.lastParent.views.getOrDefault(n.identString)
    if view.isNil:
      result = lay.createView(n)
    else:
      assert(lay.viewTbl.hasKey(view))
      if lastIdent == n:
        let symNode = lay.viewTbl[view]
        let info = symNode.lineInfo
        let prev = lay.context.toString(info)
        lay.sourceError(errDuplicateView, n, symNode.symString, prev)
      result = lay.viewTbl[view]
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
  assert(n.kind == nkStmtList)

  for m in n.sons:
    case m.kind
    of nkConstList: lay.semConstList(m)
    of nkEventList: lay.semEventList(m)
    of nkPropList:  lay.semPropList(m)
    else:
      internalError(lay, errUnknownNode, m.kind)

  result = n

proc semView(lay: Layout, n: Node) =
  assert(n.sons.len == 3)
  # each time we create new view
  # need to reset the lastParent
  lay.lastParent = lay.root
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
  let symNode = lay.classTbl.getOrDefault(className.identString)
  if symNode.isNil:
    let sym = newClassSymbol(className, n)
    lay.classTbl[className.identString] = newSymbolNode(sym)
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

let layoutSingleton = 0xDEADBEEF

proc semCheck*(lay: Layout, n: Node) =
  assert(n.kind == nkStmtList)
  for son in n.sons:
    lay.semStmt(son)

  #echo n.treeRepr

  var L = lay.context.getLua()
  
  #nimLuaOptions(nloDebug, true)
  L.bindObject(View):
    newView -> "new"
    name(get, set)
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

  #[echo n.treeRepr
  for view in keys(lay.views):
    var v = view
    var name = v.name & "."
    while v.parent != nil:
      name.add(v.parent.name & ".")
      v = v.parent
    echo name]#
