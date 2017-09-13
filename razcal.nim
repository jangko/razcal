import os, glfw

proc main =
  glfw.init()
  var w = newGlWin()
  sleep(3000)
  w.destroy()
  glfw.terminate()

main()