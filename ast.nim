import sets, idents, strutils, layout, context

type
  Scope* = ref object
    depthLevel*: int
    symbols*: HashSet[Symbol]
    parent*: Scope

  SymKind* = enum
    skUnknown, skView, skClass, skConst, skStyle, skParam

  Symbol* = ref SymbolObj
  SymbolObj* {.acyclic.} = object of IDobj
    case kind*: SymKind
    of skView:
      view*: View
    of skClass:
      class*: Class
    else: nil
    name*: Ident
    lineInfo*: LineInfo

  NodeKind* = enum
    nkEmpty
    nkInfix, nkPrefix, nkPostfix
    nkInt, nkUInt, nkFloat
    nkString, nkCharLit, nkIdent, nkSymbol
    nkCall, nkDotCall, nkAsgn
    nkStmtList, nkClassParams, nkViewClassList
    nkView, nkClass, nkViewClass, nkViewClassArgs, nkStyle

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

proc newIntNode*(kind: NodeKind, intVal: BiggestInt): Node =
  result = newNode(kind)
  result.intVal = intVal

proc newUIntNode*(kind: NodeKind, uintVal: BiggestUInt): Node =
  result = newNode(kind)
  result.uintVal = uintVal

proc newFloatNode*(kind: NodeKind, floatVal: BiggestFloat): Node =
  result = newNode(kind)
  result.floatVal = floatVal

proc newStringNode*(kind: NodeKind, strVal: string): Node =
  result = newNode(kind)
  result.strVal = strVal

proc newCharLitNode*(kind: NodeKind, charLit: string): Node =
  result = newNode(kind)
  result.charLit = charLit

proc newIdentNode*(kind: NodeKind, ident: Ident): Node =
  result = newNode(kind)
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

proc newSymbol*(kind: SymKind, n: Node): Symbol =
  assert(n.kind == nkIdent)
  new(result)
  result.kind = kind
  result.name = n.ident
  result.lineInfo = n.lineInfo

proc newViewSymbol*(kind: SymKind, n: Node, view: View): Symbol =
  assert(n.kind == nkIdent)
  new(result)
  result.kind = kind
  result.name = n.ident
  result.lineInfo = n.lineInfo
  result.view = view

proc getSymString*(n: Node): string {.inline.} =
  assert(n.kind == nkSymbol)
  result = n.sym.name.s

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
