import ast, layout, idents, kiwi, tables, context

type
  Layout* = ref object of IDobj
    top*, left*, right*, bottom*: kiwi.Variable
    width*, height*: kiwi.Variable
    views*: Table[string, Symbol]
    solver*: kiwi.Solver
    context: Context

proc newLayout*(id: int, context: Context): Layout =
  new(result)
  let name = "layout" & $id
  result.id = id
  result.top = newVariable(name & ".top")
  result.left = newVariable(name & ".left")
  result.right = newVariable(name & ".right")
  result.bottom = newVariable(name & ".bottom")
  result.width = newVariable(name & ".width")
  result.height = newVariable(name & ".height")
  result.views = initTable[string, Symbol]()
  result.solver = newSolver()
  result.context = context

proc semCheck*(lay: Layout, n: Node) =
  echo n.treeRepr
  case n.kind
  of nkView:
    discard
  of nkClass:
    discard
  else:
    echo "something error: ", n.kind