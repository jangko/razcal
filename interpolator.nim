import ast

proc im*(origin, destination, c: float64): float64 =
  result = origin + (destination - origin) * c

proc interpolate*(origin, destination, current: VarSet, t: float64) =
  current.top.value = im(origin.top.value, destination.top.value, t)
  current.left.value = im(origin.left.value, destination.left.value, t)
  current.right.value = im(origin.right.value, destination.right.value, t)
  current.bottom.value = im(origin.bottom.value, destination.bottom.value, t)
  current.width.value = im(origin.width.value, destination.width.value, t)
  current.height.value = im(origin.height.value, destination.height.value, t)
  current.centerX.value = im(origin.centerX.value, destination.centerX.value, t)
  current.centerY.value = im(origin.centerY.value, destination.centerY.value, t)
