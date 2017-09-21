import kiwi, tables, idents, ast, sets

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

proc newPropSet*(): PropSet =
  new(result)
  result.visible = true
  result.rotate = 0.0
  #result.bgColor
  #result.borderColor
  #result.pivotX
  #result.pivotY

proc newPropSet*(o: PropSet): PropSet =
  new(result)
  result.visible = o.visible
  result.rotate = o.rotate
  result.bgColor = o.bgColor
  result.borderColor = o.borderColor
  result.pivotX = o.pivotX
  result.pivotY = o.pivotY

proc newView*(name: Ident): View =
  new(result)
  result.origin = newVarSet(name)
  result.current = result.origin
  result.parent = nil
  result.views = initTable[Ident, View]()
  result.name = name
  result.children = @[]
  result.idx = -1
  result.dependencies = initSet[View]()
  result.content = ""
  result.oriProp = newPropSet()
  result.curProp = result.oriProp

proc newView*(parent: View, name: Ident): View =
  assert(parent != nil)
  result = newView(name)
  result.idx = parent.children.len
  parent.views[name] = result
  parent.children.add result
  result.parent = parent

proc setConstraint*(self: VarSet, solver: Solver) =
  solver.addConstraint(self.right == self.left + self.width)
  solver.addConstraint(self.bottom == self.top + self.height)
  solver.addConstraint(self.right >= self.left)
  solver.addConstraint(self.bottom >= self.top)
  solver.addConstraint(self.centerX == self.left + (self.right - self.left) / 2)
  solver.addConstraint(self.centerY == self.top + (self.bottom - self.top) / 2)

proc setBasicConstraint*(solver: Solver, view: View) =
  view.origin.setConstraint(solver)

proc setOrigin*(view: View) =
  view.current = view.origin
  view.curProp = view.oriProp
  for child in view.children:
    child.setOrigin()

proc setOrigin*(view: View, origin: VarSet, prop: PropSet) =
  view.origin = origin
  view.current = origin
  view.oriProp = prop
  view.curProp = prop

proc getChildren*(view: View): seq[View] =
  view.children

proc getName*(view: View): string =
  view.name.s

proc getTop*(view: View): float64 =
  view.current.top.value

proc getLeft*(view: View): float64 =
  view.current.left.value

proc getRight*(view: View): float64 =
  view.current.right.value

proc getBottom*(view: View): float64 =
  view.current.bottom.value

proc getWidth*(view: View): float64 =
  view.current.width.value

proc getHeight*(view: View): float64 =
  view.current.height.value

proc getCenterX*(view: View): float64 =
  view.current.centerX.value

proc getCenterY*(view: View): float64 =
  view.current.centerY.value

proc getParent*(view: View): View =
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
  result.solver = newSolver()

# procs this needed for pivot mechanism
proc viewGetTop*(view: View): float64 =
  view.current.top.value

proc viewGetLeft*(view: View): float64 =
  view.current.left.value

proc viewGetRight*(view: View): float64 =
  view.current.right.value

proc viewGetBottom*(view: View): float64 =
  view.current.bottom.value

proc viewGetWidth*(view: View): float64 =
  view.current.width.value

proc viewGetHeight*(view: View): float64 =
  view.current.height.value

proc viewGetCenterX*(view: View): float64 =
  view.current.centerX.value

proc viewGetCenterY*(view: View): float64 =
  view.current.centerY.value
