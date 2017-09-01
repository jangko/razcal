import sets, idents, strutils, layout, context

type
  Scope* = ref object
    depthLevel*: int
    symbols*: HashSet[Symbol]
    parent*: Scope

  SymKind* = enum
    skUnknown, skView, skClass, skAlias, skStyle, skParam

  Symbol* = ref SymbolObj
  SymbolObj* {.acyclic.} = object of IDobj
    case kind*: SymKind
    of skView:
      view*: View
    of skClass:
      class*: Node   # Node.nkClass
    else: nil
    name*: Ident
    lineInfo*: LineInfo

  NodeKind* = enum
    nkEmpty
    nkInfix, nkPrefix, nkPostfix
    nkInt, nkUInt, nkFloat
    nkString, nkCharLit, nkIdent, nkSymbol
    nkCall, nkDotCall, nkAsgn, nkBracketExpr
    nkStmtList, nkClassParams, nkViewClassList
    nkView, nkClass, nkViewClass, nkViewParam
    nkEventList, nkPropList, nkConstList
    nkStyle, nkEvent, nkProp, nkConst

  Node* = ref NodeObj
  NodeObj* {.acyclic.} = object
    case kind*: NodeKind
    of nkInt:
      intVal*: BiggestInt
    of nkUInt:
      uintVal*: BiggestUInt
    of nkFloat:
      floatVal*: BiggestFloat
    of nkString:
      strVal*: string
    of nkCharLit:
      charLit*: string
    of nkIdent:
      ident*: Ident
    of nkSymbol:
      sym*: Symbol
    else:
      sons*: seq[Node]
    lineInfo*: LineInfo

proc newNode*(kind: NodeKind): Node =
  new(result)
  result.kind = kind
  result.lineInfo.line = -1
  result.lineInfo.col = -1
  result.lineInfo.fileIndex = -1

proc newIntNode*(intVal: BiggestInt): Node =
  result = newNode(nkInt)
  result.intVal = intVal

proc newUIntNode*(uintVal: BiggestUInt): Node =
  result = newNode(nkUInt)
  result.uintVal = uintVal

proc newFloatNode*(floatVal: BiggestFloat): Node =
  result = newNode(nkFloat)
  result.floatVal = floatVal

proc newStringNode*(strVal: string): Node =
  result = newNode(nkString)
  result.strVal = strVal

proc newCharLitNode*(charLit: string): Node =
  result = newNode(nkCharLit)
  result.charLit = charLit

proc newIdentNode*(ident: Ident): Node =
  result = newNode(nkIdent)
  result.ident = ident

proc newTree*(kind: NodeKind; children: varargs[Node]): Node =
  result = newNode(kind)
  result.sons = @children

proc newNodeI*(kind: NodeKind, lineInfo: LineInfo): Node =
  result = newNode(kind)
  result.lineInfo = lineInfo

proc newSymbolNode*(sym: Symbol): Node =
  result = newNode(nkSymbol)
  result.sym = sym
  result.lineInfo = sym.lineInfo

proc addSon*(father, son: Node) =
  assert son != nil
  if isNil(father.sons): father.sons = @[]
  add(father.sons, son)

proc val*(n: Node): string =
  case n.kind
  of nkInt: result = $n.intVal
  of nkUInt: result = $n.uintVal
  of nkFloat: result = $n.floatVal
  of nkString: result = n.strVal
  of nkCharLit:
    result = "0x"
    for c in n.charLit:
      result.add(toHex(ord(c), 2))
  of nkIdent: result = $n.ident
  of nkSymbol: result = $n.sym.name
  else: result = ""

proc treeRepr*(n: Node, indent = 0): string =
  const NodeWithVal = {nkInt, nkUInt, nkFloat, nkString, nkCharLit, nkIdent, nkSymbol}
  let spaces = repeat(' ', indent)
  if n.isNil: return spaces & "nil"
  let val = n.val
  if val.len == 0:
    result = "$1$2\n" % [spaces, $n.kind]
  else:
    result = "$1$2: $3\n" % [spaces, $n.kind, n.val]
  if n.kind notin NodeWithVal and not n.sons.isNil:
    for s in n.sons:
      result.add treeRepr(s, indent + 2)

proc copyTree*(n: Node): Node =
  case n.kind
  of nkInt: result = newIntNode(n.intVal)
  of nkUInt: result = newUIntNode(n.uintVal)
  of nkFloat: result = newFloatNode(n.floatVal)
  of nkString: result = newStringNode(n.strVal)
  of nkCharLit: result = newCharLitNode(n.charLit)
  of nkIdent: result = newIdentNode(n.ident)
  of nkSymbol: result = newSymbolNode(n.sym)
  else:
    result = newNode(n.kind)
    if not n.sons.isNil:
      result.sons = newSeq[Node](n.sons.len)
      for i in 0.. <n.sons.len:
        result.sons[i] = copyTree(n.sons[i])
  result.lineInfo = n.lineInfo

proc `[]`*(n: Node, idx: int): Node {.inline.} =
  result = n.sons[idx]

proc `[]=`*(n: Node, idx: int, val: Node) {.inline.} =
  n.sons[idx] = val

proc newSymbol*(kind: SymKind, n: Node): Symbol =
  assert(n.kind == nkIdent)
  new(result)
  result.kind = kind
  result.name = n.ident
  result.lineInfo = n.lineInfo

proc newViewSymbol*(n: Node, view: View): Symbol =
  result = newSymbol(skView, n)
  result.view = view

proc newClassSymbol*(n: Node, cls: Node): Symbol =
  result = newSymbol(skClass, n)
  result.class = cls

proc symString*(n: Node): string {.inline.} =
  assert(n.kind == nkSymbol)
  result = n.sym.name.s

proc identString*(n: Node): string {.inline.} =
  assert(n.kind == nkIdent)
  result = n.ident.s

proc newScope*(): Scope =
  new(result)
  result.depthLevel = 0
  result.symbols = initSet[Symbol]()
  result.parent = nil

proc newScope*(parent: Scope): Scope =
  new(result)
  result.depthLevel = parent.depthLevel + 1
  result.symbols = initSet[Symbol]()
  result.parent = parent
