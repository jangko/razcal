import kiwi, tables, idents

type
  View* = ref object
    top*, left*, right*, bottom*: kiwi.Variable
    width*, height*: kiwi.Variable
    centerX*, centerY*: kiwi.Variable
    views*: Table[Ident, View]  # map string to children view
    children*: seq[View]        # children view
    parent*: View               # nil if no parent/root
    name*: Ident                # view's name
    idx*: int                   # index into children position/-1 if invalid

proc newView*(name: Ident): View =
  new(result)
  result.top = newVariable(name.s & ".top")
  result.left = newVariable(name.s & ".left")
  result.right = newVariable(name.s & ".right")
  result.bottom = newVariable(name.s & ".bottom")
  result.width = newVariable(name.s & ".width")
  result.height = newVariable(name.s & ".height")
  result.centerX = newVariable(name.s & ".centerX")
  result.centerY = newVariable(name.s & ".centerY")
  result.parent = nil
  result.views = initTable[Ident, View]()
  result.name = name
  result.children = @[]
  result.idx = -1

proc newView*(parent: View, name: Ident): View =
  assert(parent != nil)
  result = newView(name)
  result.idx = parent.children.len
  parent.views[name] = result
  parent.children.add result
  result.parent = parent

proc setBasicConstraint*(solver: Solver, view: View) =
  solver.addConstraint(view.right == view.left + view.width)
  solver.addConstraint(view.bottom == view.top + view.height)
  solver.addConstraint(view.right >= view.left)
  solver.addConstraint(view.bottom >= view.top)
  solver.addConstraint(view.centerX == (view.right - view.left) / 2)
  solver.addConstraint(view.centerY == (view.bottom - view.top) / 2)

proc getChildren*(view: View): seq[View] =
  view.children

template getName*(view: View): string =
  view.name.s

template getTop*(view: View): float64 =
  view.top.value

template getLeft*(view: View): float64 =
  view.left.value

template getRight*(view: View): float64 =
  view.right.value

template getBottom*(view: View): float64 =
  view.bottom.value

template getWidth*(view: View): float64 =
  view.width.value

template getHeight*(view: View): float64 =
  view.height.value

template getCenterX*(view: View): float64 =
  view.centerX.value

template getCenterY*(view: View): float64 =
  view.centerY.value

proc print*(view: View) =
  echo view.top
  echo view.left
  echo view.bottom
  echo view.right
  echo view.width
  echo view.height
  echo view.centerX
  echo view.centerY

#[proc main() =
  var
    a = initView("a")
    b = initView("b")
    c = initView("c")
    solver = newSolver()

  solver.setConstraint(a)
  solver.setConstraint(b)
  solver.setConstraint(c)
  solver.addConstraint(a.left >= 0)
  solver.addConstraint(b.left == a.right)
  solver.addConstraint(c.left == b.right)
  solver.addConstraint(a.top == b.top)
  solver.addConstraint(b.top == c.top)
  solver.addConstraint(a.top >= 0)

  solver.updateVariables()

  a.print
  b.print
  c.print

main()]#