import sets, idents, strutils, kiwi, tables, sets, types

type
  Interpolator* = proc (origin, destination, current: VarSet, t: float64)

  Scope* = ref object
    depthLevel*: int
    symbols*: HashSet[Symbol]
    parent*: Scope

  VarSet* = ref object
    top*, left*, right*, bottom*: kiwi.Variable
    width*, height*: kiwi.Variable
    centerX*, centerY*: kiwi.Variable

  View* = ref object
    origin*: VarSet
    current*: VarSet
    views*: Table[Ident, View]  # map string to children view
    children*: seq[View]        # children view
    parent*: View               # nil if no parent/root
    name*: Ident                # view's name
    idx*: int                   # index into children position/-1 if invalid
    symNode*: Node
    body*: Node
    dependencies*: HashSet[View]
    visible*: bool

  Anim* = ref object
    view*: View
    interpolator*: Interpolator
    startAni*: float64
    duration*: float64
    current*: VarSet
    destination*: VarSet

  Animation* = ref object of IDobj
    duration*: float64
    anims*: seq[Anim]
    solver*: kiwi.Solver

  ClassContext* = ref object
    paramTable*: Table[Ident, Node] # map param name to SymbolNode
    n*: Node # Node.nkClass

  SymKind* = enum
    skUnknown, skView, skClass, skAlias, skStyle, skParam
    skAnimation

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
    of skAlias:
      alias*: Node
    of skAnimation:
      anim*: Animation
    else: nil
    flags*: set[SymFlags]
    name*: Ident
    pos*: int        # param position
    lineInfo*: RazLineInfo

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
    nkEventList, nkPropList, nkFlexList, nkAnimList
    nkAliasList

    # constraint's related node
    nkChoice       # a list of exprs, excluding '|' operator
    nkChoiceList   # a list of choices, separated by comma ','
    nkConstraint   # kiwi.Constraint
    nkFlexExpr    # kiwi.Expression
    nkFlexTerm    # kiwi.Term
    nkFlexVar     # kiwi.Variable

    # class instantiation used by view
    nkViewClass, nkViewParam

    # a view, a class, a style section
    nkView, nkClass, nkStyle

    # an event and a property node inside view
    nkEvent, nkProp

    # a list of choices, including {'=','>=','<='} [in]equality
    nkFlex # a single constraint

    # view classes startAni endAni interpolator
    nkAnim

    # name expr
    nkAlias

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
    of nkFlexExpr:
      expression*: kiwi.Expression
    of nkFlexTerm:
      term*: kiwi.Term
    of nkFlexVar:
      variable*: kiwi.Variable
    else:
      sons*: seq[Node]
    lineInfo*: RazLineInfo

const
  NodeWithVal* = {nkInt, nkUInt, nkFloat, nkString, nkCharLit,
    nkIdent, nkSymbol, nkConstraint, nkFlexExpr, nkFlexTerm, nkFlexVar}

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

proc newNodeI*(kind: NodeKind, lineInfo: RazLineInfo): Node =
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
  of nkFlexVar: result = n.variable.name & "(" & $n.variable.value & ")"
  of nkFlexExpr: result = $n.expression
  of nkFlexTerm: result = $n.term
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
  of nkFlexExpr:
    result = newNode(nkFlexExpr)
    result.expression = n.expression
  of nkFlexTerm:
    result = newNode(nkFlexTerm)
    result.term = n. term
  of nkFlexVar:
    result = newNode(nkFlexVar)
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

proc newAliasSymbol*(n: Node, alias: Node): Symbol =
  result = newSymbol(skAlias, n)
  result.alias = alias

proc newAnimationSymbol*(n: Node, anim: Animation): Symbol =
  result = newSymbol(skAnimation, n)
  result.anim = anim

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
