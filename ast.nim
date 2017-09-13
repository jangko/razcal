import sets, idents, strutils, layout, context, kiwi, tables

type
  Scope* = ref object
    depthLevel*: int
    symbols*: HashSet[Symbol]
    parent*: Scope

  ClassContext* = ref object
    paramTable*: Table[Ident, Node] # map param name to SymbolNode
    n*: Node # Node.nkClass

  SymKind* = enum
    skUnknown, skView, skClass, skAlias, skStyle, skParam

  SymFlags* = enum
    sfUsed

  Symbol* = ref SymbolObj
  SymbolObj* {.acyclic.} = object of IDobj
    case kind*: SymKind
    of skView:
      view*: View
    of skClass:
      class*: ClassContext
    of skParam:
      value*: Node   # the default value of a param or nil
    else: nil
    flags*: set[SymFlags]
    name*: Ident
    pos*: int        # param position
    lineInfo*: LineInfo

  NodeKind* = enum
    nkEmpty
    nkInfix     # a opr b
    nkPrefix    # opr n
    nkPostfix   # opr n

    # basic terminal node
    nkInt, nkUInt, nkFloat, nkString, nkCharLit, nkIdent

    nkSymbol    # act as pointer to other node

    nkCall        # f(args)
    nkDotCall     # arg.f
    nkAsgn        # n '=' expr
    nkBracketExpr # n[expr]

    # x.sons[1..n]
    nkStmtList, nkClassParams, nkViewClassList
    nkEventList, nkPropList, nkFlexList

    # constraint's related node
    nkChoice       # a list of exprs, excluding '|' operator
    nkChoiceList   # a list of choices, separated by comma ','
    nkConstraint   # kiwi.Constraint
    nkConstExpr    # kiwi.Expression
    nkConstTerm    # kiwi.Term
    nkConstVar     # kiwi.Variable

    # class instantiation used by view
    nkViewClass, nkViewParam

    # a view, a class, a style section
    nkView, nkClass, nkStyle

    # an event and a property node inside view
    nkEvent, nkProp

    # a list of choices, including {'=','>=','<='} [in]equality
    nkFlex # a single constraint

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
    of nkConstraint:
      constraint*: kiwi.Constraint
    of nkConstExpr:
      expression*: kiwi.Expression
    of nkConstTerm:
      term*: kiwi.Term
    of nkConstVar:
      variable*: kiwi.Variable
    else:
      sons*: seq[Node]
    lineInfo*: LineInfo

const
  NodeWithVal* = {nkInt, nkUInt, nkFloat, nkString, nkCharLit,
    nkIdent, nkSymbol, nkConstraint, nkConstExpr, nkConstTerm, nkConstVar}

  NodeWithSons* = {low(NodeKind)..high(NodeKind)} - NodewithVal

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
  of nkConstVar: result = n.variable.name & "(" & $n.variable.value & ")"
  of nkConstExpr: result = $n.expression
  of nkConstTerm: result = $n.term
  of nkConstraint: result = $n.constraint
  else: result = ""

proc treeRepr*(n: Node, indent = 0): string =
  let spaces = repeat(' ', indent)
  if n.isNil: return spaces & "nil\n"
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
  of nkConstraint:
    result = newNode(nkConstraint)
    result.constraint = n.constraint
  of nkConstExpr:
    result = newNode(nkConstExpr)
    result.expression = n.expression
  of nkConstTerm:
    result = newNode(nkConstTerm)
    result.term = n. term
  of nkConstVar:
    result = newNode(nkConstVar)
    result.variable = n.variable
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

proc len*(n: Node): int {.inline.} =
  result = n.sons.len

proc newSymbol*(kind: SymKind, n: Node): Symbol =
  assert(n.kind == nkIdent)
  new(result)
  result.kind = kind
  result.name = n.ident
  result.lineInfo = n.lineInfo

proc newViewSymbol*(n: Node, view: View): Symbol =
  result = newSymbol(skView, n)
  result.view = view

proc newClassSymbol*(n: Node, cls: ClassContext): Symbol =
  result = newSymbol(skClass, n)
  result.class = cls

proc newClassContext*(n: Node): ClassContext =
  new(result)
  result.n = n
  result.paramTable = initTable[Ident, Node](8)

proc newParamSymbol*(n: Node, val: Node, pos: int): Symbol =
  result = newSymbol(skParam, n)
  result.value = val
  result.pos = pos

template symString*(n: Node): string =
  assert(n.kind == nkSymbol)
  n.sym.name.s

template identString*(n: Node): string =
  assert(n.kind == nkIdent)
  n.ident.s

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
