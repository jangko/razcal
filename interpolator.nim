proc im(a, b, c: float64): float64 =
  result = a + (b - a) * c

proc main() =
  echo im(50, 100, 0.0)
  echo im(50, 100, 1.0)
  echo im(50, 100, 0.5)
  echo im(50, 100, 0.9)

main()