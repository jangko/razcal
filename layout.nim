import kiwi, tables, idents, ast

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

template getParent*(view: View): View =
  view.parent

proc getPrev*(view: View): View =
  result = nil
  if not view.parent.isNil:
    let i = view.idx - 1
    if i >= 0 and i < view.parent.children.len:
      result = view.parent.children[i]

proc getNext*(view: View): View =
  result = nil
  if not view.parent.isNil:
    let i = view.idx + 1
    if i < view.parent.children.len:
      result = view.parent.children[i]

proc getPrevIdx*(view: View, idx: int): View =
  result = nil
  if not view.parent.isNil:
    let i = view.idx - idx
    if i >= 0 and i < view.parent.children.len:
      result = view.parent.children[i]

proc getNextIdx*(view: View, idx: int): View =
  result = nil
  if not view.parent.isNil:
    let i = view.idx + idx
    if i < view.parent.children.len:
      result = view.parent.children[i]

proc findChild*(view: View, id: Ident): View =
  result = view.views.getOrDefault(id)

proc newAnimation*(duration: float64): Animation =
  new(result)
  result.duration = duration

