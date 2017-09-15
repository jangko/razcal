import os, glfw, nvg, nimLUA, opengl, parser, razcontext, semcheck
import streams

proc load_glex() {.importc, cdecl.}

proc bindNVG(L: PState, nvg: NVGcontext) =

  #nimLuaOptions(nloDebug, true)
  L.bindObject(NVGContext -> "nvg"):
    nvgCreate -> "create"
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

  L.bindConst("nvg"):
    NVG_ANTIALIAS -> "ANTIALIAS"
    NVG_STENCIL_STROKES -> "STENCIL_STROKES"
    NVG_DEBUG -> "DEBUG"

  L.bindFunction("nvg"):
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
  L.pushLightUserData(cast[pointer](genLuaID())) # push key
  L.pushLightUserData(cast[pointer](nvg)) # push value
  L.setTable(LUA_REGISTRYINDEX)           # registry[lay.addr] = lay

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

  L.pushCfunction(nvgProxy)
  L.setGlobal("getNVG")

proc loadMainScript(ctx: RazContext) =
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

proc main =
  var ctx = openRazContext()
  var L = ctx.getLua()
  ctx.loadMainScript()

  glfw.init()
  var w = newGlWin(nMultiSamples = 4)
  w.makeContextCurrent()
  load_glex()
  opengl.loadExtensions()

  var nvg = nvgCreate(NVG_STENCIL_STROKES or NVG_DEBUG)
  if nvg.pointer == nil:
    echo "Could not init nanovg."
    return

  L.bindNVG(nvg)

  while not w.shouldClose():
    let s = w.framebufSize()
    glViewport(0, 0, GLsizei(s.w), GLsizei(s.h))

    glClearColor(0.3, 0.3, 0.32, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

    ctx.callF("updateScene")

    nvg.nvgBeginFrame(s.w.cint, s.h.cint, 1.0)

    let
      pos_x = 50.0
      pos_y = 50.0

    nvg.nvgBeginPath()
    nvg.nvgCircle(50, pos_x, pos_y)
    nvg.nvgFillColor(nvgRGBAf(1.0, 0.7, 0.0, 1.0))
    let stroke_width = 10.0
    nvg.nvgStroke(0.0, 0.5, 1.0, 1.0, stroke_width)

    nvg.nvgEndFrame()

    w.swapBufs()
    waitEvents()

  nvg.nvgDelete()
  w.destroy()
  glfw.terminate()
  ctx.close()

main()
