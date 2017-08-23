import sets, idents, strutils

type
  Scope* = ref object
    depthLevel*: int
    symbols*: HashSet[Symbol]
    parent*: Scope

  LineInfo* = object
    line*, col*: int16
    fileIndex*: int32

  Symbol* = ref SymbolObj
  SymbolObj* {.acyclic.} = object of IDobj
    name*: Ident
    lineInfo*: LineInfo

  NodeKind* = enum
    nkInfix
    nkPrefix
    nkPostfix
    nkInt, nkUInt
    nkFloat
    nkString
    nkIdent
    nkCall

  Node* = ref NodeObj
  NodeObj* {.acyclic.} = object
    case kind*: NodeKind
    of nkInt, nkUInt:
      intVal*: BiggestUInt
    of nkFloat:
      floatVal*: BiggestFloat
    of nkString:
      strVal*: string
    of nkIdent:
      ident*: Ident
    else:
      sons*: seq[Node]
    lineInfo*: LineInfo

proc newNode*(kind: NodeKind): Node =
  new(result)
  result.kind = kind
  result.lineInfo.line = -1
  result.lineInfo.col = -1
  result.lineInfo.fileIndex = -1

proc newIntNode*(kind: NodeKind, intVal: BiggestUInt): Node =
  result = newNode(kind)
  result.intVal = intVal

proc newFloatNode*(kind: NodeKind, floatVal: BiggestFloat): Node =
  result = newNode(kind)
  result.floatVal = floatVal

proc newStrNode*(kind: NodeKind, strVal: string): Node =
  result = newNode(kind)
  result.strVal = strVal

proc newIdentNode*(kind: NodeKind, ident: Ident): Node =
  result = newNode(kind)
  result.ident = ident

proc newTree*(kind: NodeKind; children: varargs[Node]): Node =
  result = newNode(kind)
  result.sons = @children

proc newNodeI*(kind: NodeKind, lineInfo: LineInfo): Node =
  result = newNode(kind)
  result.lineInfo = lineInfo

proc addSon*(father, son: Node) =
  assert son != nil
  if isNil(father.sons): father.sons = @[]
  add(father.sons, son)

proc val*(n: Node): string =
  case n.kind
  of nkInt, nkUInt: result = $n.intVal
  of nkFloat: result = $n.floatVal
  of nkString: result = n.strVal
  of nkIdent: result = $n.ident
  else: result = ""

const NodeWithVal = {nkInt, nkUInt, nkFloat, nkString, nkIdent}

proc treeRepr*(n: Node, indent = 0): string =
  let spaces = repeat(' ', indent)
  if n.isNil: return spaces & "nil"
  result = "$1$2: $3\n" % [spaces, $n.kind, n.val]
  if n.kind notin NodeWithVal and not n.sons.isNil:
    for s in n.sons:
      result.add treeRepr(s, indent + 2)
