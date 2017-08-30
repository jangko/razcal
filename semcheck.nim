import ast, layout, idents, kiwi, tables, context, hashes, strutils

type
  Layout* = ref object of IDobj
    root*: View
    views*: Table[View, Node]
    solver*: kiwi.Solver
    context: Context
    lastParent*: View      # last processed parent view

proc hash(view: View): Hash =
  hash(cast[int](view))

proc newLayout*(id: int, context: Context): Layout =
  new(result)
  result.id = id
  result.root = newView("layout" & $id)
  result.views = initTable[View, Node]()
  result.solver = newSolver()
  result.context = context

proc internalErrorImpl(lay: Layout, kind: MsgKind, fileName: string, line: int, args: varargs[string, `$`]) =
  var err = new(InternalError)
  err.msg = lay.context.msgKindToString(kind, args)
  err.line = line
  err.fileName = fileName
  raise err

template internalError(lay: Layout, kind: MsgKind, args: varargs[string, `$`]) =
  lay.internalErrorImpl(kind,
    instantiationInfo().fileName,
    instantiationInfo().line,
    args)

proc getCurrentLine*(lay: Layout, info: LineInfo): string =
  let fileName = lay.context.toFullPath(info)
  var f = open(fileName)
  if f.isNil(): lay.internalError(errCannotOpenFile, fileName)
  var line: string
  var n = 0
  while f.readLine(line) and n < info.line:
    inc n
    if n == info.line - 1: result = line & "\n"
  f.close()
  if result.isNil: result = ""

proc sourceError(lay: Layout, kind: MsgKind, n: Node, args: varargs[string, `$`]) =
  var err = new(SourceError)
  err.msg = lay.context.msgKindToString(kind, args)
  err.line = n.lineInfo.line
  err.column = n.lineInfo.col
  err.lineContent = lay.getCurrentLine(n.lineInfo)
  err.fileIndex = n.lineInfo.fileIndex
  raise err

proc createView(lay: Layout, n: Node): Node =
  var view = newView(n.ident.s)
  var sym  = newSymbol(skView, n)
  lay.lastParent.views[n.ident.s] = view
  view.parent = lay.lastParent
  lay.lastParent = view
  sym.view = view
  result = newSymbolNode(sym)
  lay.views[view] = result

proc semViewName(lay: Layout, n: Node, lastIdent: Node): Node =
  case n.kind
  of nkDotCall:
    assert(n.sons.len == 2)
    n.sons[0] = lay.semViewName(n.sons[0], lastIdent)
    assert(n.sons[0].kind == nkSymbol)
    lay.lastParent = n.sons[0].sym.view
    n.sons[1] = lay.semViewName(n.sons[1], lastIdent)
    result = n.sons[1]
  of nkIdent:
    var view = lay.lastParent.views.getOrDefault(n.ident.s)
    if view.isNil:
      result = lay.createView(n)
    else:
      assert(lay.views.hasKey(view))
      if lastIdent == n:
        let symNode = lay.views[view]
        let info = symNode.lineInfo
        let prev = lay.context.toString(info)
        lay.sourceError(errDuplicateView, n, symNode.getSymString, prev)
      result = lay.views[view]
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semViewBody(lay: Layout, n: Node): Node =
  result = n

proc semStmt(lay: Layout, n: Node) =
  case n.kind
  of nkView:
    assert(n.sons.len == 2)
    # each time we create new view
    # need to reset the lastParent
    lay.lastParent = lay.root
    var lastIdent = Node(nil)
    if n.sons[0].kind == nkIdent: lastIdent = n.sons[0]
    if lastIdent.isNil and n.sons[0].kind == nkDotCall:
      let son = n.sons[0].sons[1]
      if son.kind == nkIdent: lastIdent = son
    n.sons[0] = lay.semViewName(n.sons[0], lastIdent)
    n.sons[1] = lay.semViewBody(n.sons[1])
  of nkClass:
    discard
  else:
    internalError(lay, errUnknownNode, n.kind)

proc semCheck*(lay: Layout, n: Node) =
  assert(n.kind == nkStmtList)
  for son in n.sons:
    lay.semStmt(son)
  #echo n.treeRepr
  for view in keys(lay.views):
    var v = view
    var name = v.name & "."
    while v.parent != nil:
      name.add(v.parent.name & ".")
      v = v.parent
    echo name
