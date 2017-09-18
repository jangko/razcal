import os, glfw, nvg, nimLUA, opengl, parser, razcontext, semcheck
import streams, ast, layout, idents, glfw/wrapper, interpolator

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

proc drawButton(nvg: NVGContext, x, y, w, h: float64, col: NVGcolor, text: string) =
  let cornerRadius = 4.0
  let bg = nvg.nvgLinearGradient(x,y,x,y+h, nvgRGBA(255,255,255,32), nvgRGBA(0,0,0,32))
  let tw = nvg.nvgTextBounds(0,0, text)

  nvg.nvgBeginPath()
  nvg.nvgRoundedRect(x+1,y+1, w-2,h-2, cornerRadius-1)
  nvg.nvgFillColor(col)
  nvg.nvgFill()
  nvg.nvgFillPaint(bg)
  nvg.nvgFill()

  nvg.nvgBeginPath()
  nvg.nvgRoundedRect(x+0.5,y+0.5, w-1,h-1, cornerRadius-0.5)
  #nvg.nvgStrokeColor(nvgRGBA(0,0,0,48))
  #nvg.nvgStroke()
  nvg.nvgStroke(1.0, 0.0, 0.0, 1.0, 2.0)

  nvg.nvgFontSize(20.0)
  nvg.nvgFontFace("sans-bold")
  nvg.nvgTextAlign(NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
  nvg.nvgFillColor(nvgRGBA(0,0,0,160))
  discard nvg.nvgText(x+w*0.5-tw*0.5,y+h*0.5-1,text)
  nvg.nvgFillColor(nvgRGBA(255,255,255,160))
  discard nvg.nvgText(x+w*0.5-tw*0.5,y+h*0.5,text)

proc drawView*(view: View, nvg: NVGContext) =
  let red = nvgRGBA(128,16,8,255)

  if view.visible:
    nvg.drawButton(view.getLeft(), view.getTop(),
      view.getWidth(), view.getHeight(), red, view.name.s)

  for child in view.children:
    child.drawView(nvg)

type
  ANIM_STATE = enum
    ANIM_NONE
    ANIM_START
    ANIM_RUN
    ANIM_STOP

proc main =
  var ctx = openRazContext()
  var L = ctx.getLua()
  let lay = ctx.loadMainScript()
  if lay == nil: return

  glfw.init()
  var w = newGlWin(dim = (w: screenWidth, h: screenHeight), nMultiSamples = 4)
  w.makeContextCurrent()
  load_glex()
  opengl.loadExtensions()

  var nvg = nvgCreate(NVG_STENCIL_STROKES or NVG_DEBUG)
  if nvg.pointer == nil:
    echo "Could not init nanovg."
    return

  nvg.loadFonts()
  L.bindNVG(nvg)

  var animState = ANIM_NONE
  var anim1 = lay.getAnimation("anim1")
  var anim2 = lay.getAnimation("anim2")
  var anim = anim2

  proc keyboardCB(win: Win, key: Key, scanCode: int, action: KeyAction, modKeys: ModifierKeySet) =
    if key == keyF1:
      if animState == ANIM_NONE and anim != anim1:
        anim = lay.getAnimation("anim1")
        animState = ANIM_START

    if key == keyF2:
      if animState == ANIM_NONE and anim != anim2:
        anim = lay.getAnimation("anim2")
        animState = ANIM_START

  w.keyCb = keyboardCB
  var
    startTime = 0.0
    pos_x = 0.0
    pos_y = 0.0

  let s = w.framebufSize()
  glViewport(0, 0, GLsizei(s.w), GLsizei(s.h))

  while not w.shouldClose():
    glClearColor(0.3, 0.3, 0.32, 1.0)
    glClear(GL_COLOR_BUFFER_BIT or GL_STENCIL_BUFFER_BIT)

    nvg.nvgBeginFrame(s.w.cint, s.h.cint, 1.0)
    nvg.nvgBeginPath()
    nvg.nvgCircle(pos_x, pos_y, 50.0)
    nvg.nvgFillColor(nvgRGBAf(1.0, 0.7, 0.0, 1.0))
    let stroke_width = 10.0
    nvg.nvgStroke(0.0, 0.5, 1.0, 1.0, stroke_width)
    nvg.nvgEndFrame()

    case animState
    of ANIM_START:
      startTime = getTime()
      animState = ANIM_RUN
    of ANIM_RUN:
      let elapsed = getTime() - startTime
      let timeCurve = elapsed / anim.duration
      for a in anim.anims:
        interpolate(a.view.origin, a.destination, a.current, timeCurve)
        a.view.current = a.current

      nvg.nvgBeginFrame(s.w.cint, s.h.cint, 1.0)
      lay.root.drawView(nvg)
      nvg.nvgEndFrame()
      w.swapBufs()
      if elapsed > anim.duration: animState = ANIM_STOP
    of ANIM_STOP:
      for a in anim.anims:
        a.view.setOrigin(a.destination)
      animState = ANIM_NONE
    else:
      lay.root.drawView(nvg)
      nvg.nvgEndFrame()
      w.swapBufs()
      waitEvents()

  nvg.nvgDelete()
  w.destroy()
  glfw.terminate()
  ctx.close()

main()
