import os, glfw, nvg

proc load_glex() {.importc.}

proc main =
  glfw.init()
  var w = newGlWin()
  sleep(3000)
  w.destroy()
  glfw.terminate()

main()