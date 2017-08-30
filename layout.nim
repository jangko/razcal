import kiwi, tables

type
  View* = ref object
    top*, left*, right*, bottom*: kiwi.Variable
    width*, height*: kiwi.Variable
    views*: Table[string, View]

  ViewClass* = ref object

proc newView(name: string): View =
  new(result)
  result.top = newVariable(name & ".top")
  result.left = newVariable(name & ".left")
  result.right = newVariable(name & ".right")
  result.bottom = newVariable(name & ".bottom")
  result.width = newVariable(name & ".width")
  result.height = newVariable(name & ".height")

proc setConstraint*(solver: Solver, view: View) =
  solver.addConstraint(view.right == view.left + view.width)
  solver.addConstraint(view.bottom == view.top + view.height)
  solver.addConstraint(view.right >= view.left)
  solver.addConstraint(view.bottom >= view.top)
  solver.addConstraint(view.width == view.height)
  solver.addConstraint(view.width == 30)

proc print*(view: View) =
  echo view.top
  echo view.left
  echo view.bottom
  echo view.right
  echo view.width
  echo view.height

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