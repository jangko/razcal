import os, glfw, nvg, nimLUA, opengl, parser, razcontext, semcheck
import streams, ast, layout, idents

proc load_glex() {.importc, cdecl.}
proc nvgTextBounds*(ctx: NVGContext; x, y: cfloat; str: cstring): cfloat =
  result = ctx.nvgTextBounds(x, y, str, nil, nil)

proc nvgText*(ctx: NVGContext; x, y: cfloat; str: cstring): cfloat =
  result = ctx.nvgText(x, y, str, nil)

proc bindNVG(LX: PState, nvg: NVGcontext) =

  #nimLuaOptions(nloDebug, true)
  LX.bindObject(NVGContext -> "nvg"):
    #nvgCreate -> "create"
    #~nvgDelete
    nvgBeginFrame -> "beginFrame"
    nvgCancelFrame -> "cancelFrame"
    nvgEndFrame -> "endFrame"
    nvgGlobalCompositeOperation -> "globalCompositeOperation"
    nvgGlobalCompositeBlendFunc -> "globalCompositeBlendFunc"
    nvgGlobalCompositeBlendFuncSeparate -> "globalCompositeBlendFuncSeparate"
    nvgSave -> "save"
    nvgRestore -> "restore"
    nvgReset -> "reset"
    nvgShapeAntiAlias -> "shapeAntiAlias"
    nvgStrokeColor -> "strokeColor"
    nvgStrokePaint -> "strokePaint"
    nvgFillColor -> "fillColor"
    nvgFillPaint -> "fillPaint"
    nvgMiterLimit -> "miterLimit"
    nvgStrokeWidth -> "strokeWidth"
    nvgLineCap -> "lineCap"
    nvgLineJoin -> "lineJoin"
    nvgGlobalAlpha -> "globalAlpha"
    nvgResetTransform -> "resetTransform"
    nvgTransform -> "transform"
    nvgTranslate -> "translate"
    nvgRotate -> "rotate"
    nvgSkewX -> "skewX"
    nvgSkewY -> "skewY"
    nvgScale -> "scale"
    nvgCurrentTransform -> "currentTransform"
    nvgCreateImage -> "createImage"
    nvgCreateImageMem -> "createImageMem"
    nvgCreateImageRGBA -> "createImageRGBA"
    nvgUpdateImage -> "updateImage"
    nvgImageSize -> "imageSize"
    nvgDeleteImage -> "deleteImage"
    nvgLinearGradient -> "linearGradient"
    nvgBoxGradient -> "boxGradient"
    nvgRadialGradient -> "radialGradient"
    nvgImagePattern -> "imagePattern"
    nvgScissor -> "scissor"
    nvgIntersectScissor -> "intersectScissor"
    nvgResetScissor -> "resetScissor"
    nvgBeginPath -> "beginPath"
    nvgMoveTo -> "moveTo"
    nvgLineTo -> "lineTo"
    nvgBezierTo -> "bezierTo"
    nvgQuadTo -> "quadTo"
    nvgArcTo -> "arcTo"
    nvgClosePath -> "closePath"
    nvgPathWinding -> "pathWinding"
    nvgArc -> "arc"
    nvgRect -> "rect"
    nvgRoundedRect -> "roundedRect"
    nvgRoundedRectVarying -> "rectVarying"
    nvgEllipse -> "ellipse"
    nvgCircle -> "circle"
    nvgFill -> "fill"
    nvgStroke -> "stroke"
    nvgCreateFont -> "createFont"
    nvgCreateFontMem -> "createFontMem"
    nvgFindFont -> "findFont"
    nvgAddFallbackFontId -> "addFallbackFontId"
    nvgAddFallbackFont -> "addFallbackFont"
    nvgFontSize -> "fontSize"
    nvgFontBlur -> "fontBlur"
    nvgTextLetterSpacing -> "textLetterSpacing"
    nvgTextLineHeight -> "textLineHeight"
    nvgTextAlign -> "textAlign"
    nvgFontFaceId -> "fontFaceId"
    nvgFontFace -> "fontFace"
    nvgText -> "text"
    nvgTextBox -> "textBox"
    nvgTextBounds -> "textBounds"
    nvgTextBoxBounds -> "textBoxBounds"
    nvgTextGlyphPositions -> "textGlyphPositions"
    nvgTextMetrics -> "textMetrics"
    nvgTextBreakLines -> "textBreakLines"

  LX.bindConst("nvg"):
    NVG_ANTIALIAS -> "ANTIALIAS"
    NVG_STENCIL_STROKES -> "STENCIL_STROKES"
    NVG_DEBUG -> "DEBUG"
    NVG_ALIGN_LEFT -> "ALIGN_LEFT"
    NVG_ALIGN_CENTER -> "ALIGN_CENTER"
    NVG_ALIGN_RIGHT -> "ALIGN_RIGHT"
    NVG_ALIGN_TOP -> "ALIGN_TOP"
    NVG_ALIGN_MIDDLE -> "ALIGN_MIDDLE"
    NVG_ALIGN_BOTTOM -> "ALIGN_BOTTOM"
    NVG_ALIGN_BASELINE -> "ALIGN_BASELINE"

  #nimLuaOptions(nloDebug, true)
  LX.bindFunction("nvg"):
    nvgRGB -> "RGB"
    nvgRGBf -> "RGBf"
    nvgRGBA -> "RGBA"
    nvgRGBAf -> "RGBAf"
    nvgLerpRGBA -> "lerpRGBA"
    nvgTransRGBA -> "transRGBA"
    nvgTransRGBAf -> "transRGBAf"
    nvgHSL -> "HSL"
    nvgHSLA -> "HSLA"
    nvgDegToRad -> "degToRad"
    nvgRadToDeg -> "radtoDeg"
    nvgTransformIdentity -> "transformIdentity"
    nvgTransformTranslate -> "transformTranslate"
    nvgTransformScale -> "transformScale"
    nvgTransformRotate -> "transformRotate"
    nvgTransformSkewX -> "transformSkewX"
    nvgTransformSkewY -> "transformSkewY"
    nvgTransformMultiply -> "transformMultiply"
    nvgTransformPremultiply -> "transformPremultiply"
    nvgTransformInverse -> "transformInverse"
    nvgTransformPoint -> "transformPoint"

  # store Layout reference
  LX.pushLightUserData(cast[pointer](genLuaID())) # push key
  LX.pushLightUserData(cast[pointer](nvg)) # push value
  LX.setTable(LUA_REGISTRYINDEX)           # registry[lay.addr] = lay

  # register the only entry point of layout hierarchy to lua
  proc nvgProxy(L: PState): cint {.cdecl.} =
    getRegisteredType(NVGcontext, mtName, pxName)
    var ret = cast[ptr pxName](L.newUserData(sizeof(pxName)))
    # retrieve Layout
    L.pushLightUserData(cast[pointer](getPrevID())) # push key
    L.getTable(LUA_REGISTRYINDEX)           # retrieve value
    ret.ud = cast[NVGcontext](L.toUserData(-1)) # convert to layout
    L.pop(1) # remove userdata
    L.nimGetMetaTable(mtName)
    discard L.setMetatable(-2)
    return 1

  LX.pushCfunction(nvgProxy)
  LX.setGlobal("getNVG")

proc loadMainScript(ctx: RazContext): Layout =
  let fileName = if paramCount() == 0: "main.raz" else: paramStr(1)
  var input = newFileStream(fileName)
  var knownFile = false
  let fileIndex = ctx.fileInfoIdx(fileName, knownFile)

  try:
  #block:
    var p = openParser(input, ctx, fileIndex)
    var root = p.parseAll()
    p.close()

    var lay = newLayout(0, ctx)
    lay.semCheck(root)
    result = lay
  except SourceError as srcErr:
    ctx.printError(srcErr)
  except InternalError as ex:
    ctx.printError(ex)
  except OtherError as ex:
    echo ex.msg
  except Exception as ex:
    echo "unknown error: ", ex.msg
    writeStackTrace()

proc callF(ctx: RazContext, funcName: string) =
  var L = ctx.getLua()
  L.getGlobal(funcName)
  if L.pcall(0, 0, 0) != 0:
    let errorMsg = L.toString(-1)
    L.pop(1)
    ctx.otherError(errLua, errorMsg)

proc loadFonts(nvg: NVGContext) =
  let icons = nvg.nvgCreateFont("icons", "examples/fonts/entypo.ttf")
  if icons == -1:
    echo "Could not add font icons."
    return

  let sans = nvg.nvgCreateFont("sans", "examples/fonts/Roboto-Regular.ttf")
  if sans == -1:
    echo "Could not add font italic."
    return

  let bold = nvg.nvgCreateFont("sans-bold", "examples/fonts/Roboto-Bold.ttf")
  if bold == -1:
    echo "Could not add font bold."
    return

  let emoji = nvg.nvgCreateFont("emoji", "examples/fonts/NotoEmoji-Regular.ttf")
  if emoji == -1:
    echo "Could not add font emoji."
    return

  discard nvg.nvgAddFallbackFontId(sans, emoji)
  discard nvg.nvgAddFallbackFontId(bold, emoji)

proc draw*(view: View, nvg: NVGContext) =
  nvg.nvgBeginPath()
  nvg.nvgRect(view.getLeft(), view.getTop(),
    view.getWidth(), view.getHeight())

  #echo "nam: ", view.name
  #echo "lef: ", view.getLeft()
  #echo "top: ", view.getTop()
  #echo "rig: ", view.getRight()
  #echo "bot: ", view.getBottom()
  nvg.nvgStroke(1.0, 0.0, 0.0, 1.0, 2.0)
  for child in view.children:
    child.draw(nvg)

proc main =
  var ctx = openRazContext()
  var L = ctx.getLua()
  let lay = ctx.loadMainScript()
  if lay == nil: return

  glfw.init()
  var w = newGlWin(nMultiSamples = 4)
  w.makeContextCurrent()
  load_glex()
  opengl.loadExtensions()

  var nvg = nvgCreate(NVG_STENCIL_STROKES or NVG_DEBUG)
  if nvg.pointer == nil:
    echo "Could not init nanovg."
    return

  nvg.loadFonts()
  L.bindNVG(nvg)

  #try:
  #  ctx.executeLua("main.lua")
  #except OtherError as ex:
  #  echo ex.msg
  #except Exception as ex:
  #  echo "unknown error: ", ex.msg
  #  writeStackTrace()

  while not w.shouldClose():
    let s = w.framebufSize()
    glViewport(0, 0, GLsizei(s.w), GLsizei(s.h))

    glClearColor(0.3, 0.3, 0.32, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

    nvg.nvgBeginFrame(s.w.cint, s.h.cint, 1.0)

    let
      pos_x = 50.0
      pos_y = 50.0

    nvg.nvgBeginPath()
    nvg.nvgCircle(50, pos_x, pos_y)
    nvg.nvgFillColor(nvgRGBAf(1.0, 0.7, 0.0, 1.0))
    let stroke_width = 10.0
    nvg.nvgStroke(0.0, 0.5, 1.0, 1.0, stroke_width)

    lay.root.draw(nvg)

    nvg.nvgEndFrame()

    #try:
    #  ctx.callF("updateScene")
    #except OtherError as ex:
    #  echo ex.msg
    #except Exception as ex:
    #  echo "unknown error: ", ex.msg
    #  writeStackTrace()

    w.swapBufs()
    waitEvents()

  nvg.nvgDelete()
  w.destroy()
  glfw.terminate()
  ctx.close()

main()
