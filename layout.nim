import kiwi, tables, idents, ast

proc newVarSet*(name: Ident): VarSet =
  new(result)
  result.top = newVariable(name.s & ".top")
  result.left = newVariable(name.s & ".left")
  result.right = newVariable(name.s & ".right")
  result.bottom = newVariable(name.s & ".bottom")
  result.width = newVariable(name.s & ".width")
  result.height = newVariable(name.s & ".height")
  result.centerX = newVariable(name.s & ".centerX")
  result.centerY = newVariable(name.s & ".centerY")

proc newView*(name: Ident): View =
  new(result)
  result.origin = newVarSet(name)
  result.destination = newVarSet(name)
  result.current = result.origin
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

proc setConstraint(self: VarSet, solver: Solver) =
  solver.addConstraint(self.right == self.left + self.width)
  solver.addConstraint(self.bottom == self.top + self.height)
  solver.addConstraint(self.right >= self.left)
  solver.addConstraint(self.bottom >= self.top)
  solver.addConstraint(self.centerX == (self.right - self.left) / 2)
  solver.addConstraint(self.centerY == (self.bottom - self.top) / 2)

proc setBasicConstraint*(solver: Solver, view: View) =
  view.origin.setConstraint(solver)

proc setConstraint*(view: View, solver: Solver) =
  view.current = view.destination
  view.destination.setConstraint(solver)
  for child in view.children:
    child.setConstraint(solver)
    
proc setOrigin*(view: View) =
  view.current = view.origin  
  for child in view.children:
    child.setOrigin()

proc getChildren*(view: View): seq[View] =
  view.children

template getName*(view: View): string =
  view.name.s

template getTop*(view: View): float64 =
  view.current.top.value

template getLeft*(view: View): float64 =
  view.current.left.value

template getRight*(view: View): float64 =
  view.current.right.value

template getBottom*(view: View): float64 =
  view.current.bottom.value

template getWidth*(view: View): float64 =
  view.current.width.value

template getHeight*(view: View): float64 =
  view.current.height.value

template getCenterX*(view: View): float64 =
  view.current.centerX.value

template getCenterY*(view: View): float64 =
  view.current.centerY.value

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
  result.anims = @[]
