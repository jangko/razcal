import ast, math, macros, strutils

const PI2 = PI / 2

proc linearInterpolation(p: float): float = p

proc quadraticEaseIn(p: float): float = p * p

proc quadraticEaseOut(p: float): float = -(p * (p - 2))

proc quadraticEaseInOut(p: float): float =
  if p < 0.5: return 2 * p * p
  else: return (-2 * p * p) + (4 * p) - 1

proc cubicEaseIn(p: float): float = p * p * p

proc cubicEaseOut(p: float): float =
  let f = (p - 1)
  result = f * f * f + 1

proc cubicEaseInOut(p: float): float =
  if p < 0.5: return 4 * p * p * p
  else:
    let f = ((2 * p) - 2)
    result = 0.5 * f * f * f + 1

proc quarticEaseIn(p: float): float = p * p * p * p

proc quarticEaseOut(p: float): float =
  let f = (p - 1)
  result = f * f * f * (1 - p) + 1

proc quarticEaseInOut(p: float): float =
  if p < 0.5: return 8 * p * p * p * p
  else:
    let f = (p - 1)
    result = -8 * f * f * f * f + 1

proc quinticEaseIn(p: float): float = p * p * p * p * p

proc quinticEaseOut(p: float): float =
  let f = (p - 1)
  result = f * f * f * f * f + 1

proc quinticEaseInOut(p: float): float =
  if p < 0.5: return 16 * p * p * p * p * p
  else:
    let f = ((2 * p) - 2)
    result = 0.5 * f * f * f * f * f + 1

proc sineEaseIn(p: float): float = sin((p - 1) * PI2) + 1

proc sineEaseOut(p: float): float = sin(p * PI2)

proc sineEaseInOut(p: float): float = 0.5 * (1 - cos(p * PI))

proc circularEaseIn(p: float): float = 1 - sqrt(1 - (p * p))

proc circularEaseOut(p: float): float = sqrt((2 - p) * p)

proc circularEaseInOut(p: float): float =
  if p < 0.5: return 0.5 * (1 - sqrt(1 - 4 * (p * p)))
  else: return 0.5 * (sqrt(-((2 * p) - 3) * ((2 * p) - 1)) + 1)

proc exponentialEaseIn(p: float): float =
  result = if p == 0.0: p else: pow(2, 10 * (p - 1))

proc exponentialEaseOut(p: float): float =
  result = if p == 1.0: p else: 1 - pow(2, -10 * p)

proc exponentialEaseInOut(p: float): float =
  if p == 0.0 or p == 1.0: return p
  if p < 0.5: return 0.5 * pow(2, (20 * p) - 10)
  else: return -0.5 * pow(2, (-20 * p) + 10) + 1

proc elasticEaseIn(p: float): float =
  result = sin(13 * PI2 * p) * pow(2, 10 * (p - 1))

proc elasticEaseOut(p: float): float =
  result = sin(-13 * PI2 * (p + 1)) * pow(2, -10 * p) + 1

proc elasticEaseInOut(p: float): float =
  if p < 0.5: return 0.5 * sin(13 * PI2 * (2 * p)) * pow(2, 10 * ((2 * p) - 1))
  else: return 0.5 * (sin(-13 * PI2 * ((2 * p - 1) + 1)) * pow(2, -10 * (2 * p - 1)) + 2)

proc backEaseIn(p: float): float =
  result = p * p * p - p * sin(p * PI)

proc backEaseOut(p: float): float =
  let f = (1 - p)
  result = 1 - (f * f * f - f * sin(f * PI))

proc backEaseInOut(p: float): float =
  if p < 0.5:
    let f = 2 * p
    return 0.5 * (f * f * f - f * sin(f * PI))
  else:
    let f = (1 - (2*p - 1))
    return 0.5 * (1 - (f * f * f - f * sin(f * PI))) + 0.5

proc bounceEaseOut(p: float): float =
  if p < 4/11.0:
    return (121 * p * p)/16.0
  elif p < 8/11.0:
    return (363/40.0 * p * p) - (99/10.0 * p) + 17/5.0
  elif p < 9/10.0:
    return (4356/361.0 * p * p) - (35442/1805.0 * p) + 16061/1805.0
  else:
    return (54/5.0 * p * p) - (513/25.0 * p) + 268/25.0

proc bounceEaseIn(p: float): float =
  result = 1 - bounceEaseOut(1 - p)

proc bounceEaseInOut(p: float): float =
  if p < 0.5: return 0.5 * bounceEaseIn(p*2)
  else: return 0.5 * bounceEaseOut(p * 2 - 1) + 0.5

proc smoothStep(x: float): float = x * x * (3 - 2 * x)

proc spring(x: float): float =
  let factor = 0.4
  result = pow(2, -10 * x) * sin((x - factor / 4) * (2 * PI) / factor) + 1

template easing(name, eq: untyped) =
  proc name*(origin, destination, t: float): float =
    result = origin + (destination - origin) * eq(t)

  proc `interpolator name`*(origin, destination, current: VarSet, t: float64) =
    current.top.value = name(origin.top.value, destination.top.value, t)
    current.left.value = name(origin.left.value, destination.left.value, t)
    current.right.value = name(origin.right.value, destination.right.value, t)
    current.bottom.value = name(origin.bottom.value, destination.bottom.value, t)
    current.width.value = name(origin.width.value, destination.width.value, t)
    current.height.value = name(origin.height.value, destination.height.value, t)
    current.centerX.value = name(origin.centerX.value, destination.centerX.value, t)
    current.centerY.value = name(origin.centerY.value, destination.centerY.value, t)

macro createInterpolator(n: untyped): untyped =
  var iTbl = "const interpolatorList* = {\n"
  var eTbl = "const easingList* = {\n"
  var glue = ""
  for m in n:
    glue.add "easing(easing$1, $1)\n" % [$m]
    iTbl.add "  \"$1\": interpolatorEasing$1,\n" % [$m]
    eTbl.add "  \"$1\": easing$1,\n" % [$m]
  iTbl.add "  }\n"
  eTbl.add "  }\n"
  result = parseStmt(glue & iTbl & eTbl)

createInterPolator:
  linearInterpolation
  quadraticEaseIn
  quadraticEaseOut
  quadraticEaseInOut
  cubicEaseIn
  cubicEaseOut
  cubicEaseInOut
  quarticEaseIn
  quarticEaseOut
  quarticEaseInOut
  quinticEaseIn
  quinticEaseOut
  quinticEaseInOut
  sineEaseIn
  sineEaseOut
  sineEaseInOut
  circularEaseIn
  circularEaseOut
  circularEaseInOut
  exponentialEaseIn
  exponentialEaseOut
  exponentialEaseInOut
  elasticEaseIn
  elasticEaseOut
  elasticEaseInOut
  backEaseIn
  backEaseOut
  backEaseInOut
  bounceEaseOut
  bounceEaseIn
  bounceEaseInOut
  smoothStep
  spring
