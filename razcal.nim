import os, glfw, nvg, nimLUA, opengl, parser, razcontext, semcheck
import streams, ast, layout, idents, glfw/wrapper, interpolator
import types

proc load_glex() {.importc, cdecl.}
proc textBounds*(ctx: NVGContext; x, y: cfloat; str: cstring): cfloat =
  result = ctx.textBounds(x, y, str, nil, nil)

proc text*(ctx: NVGContext; x, y: cfloat; str: cstring): cfloat =
  result = ctx.text(x, y, str, nil)

proc bindNVG(LX: PState, nvg: NVGcontext) =
  LX.bindObject(NVGContext -> "nvg"):
    beginFrame -> "beginFrame"
    cancelFrame -> "cancelFrame"
    endFrame -> "endFrame"
    globalCompositeOperation -> "globalCompositeOperation"
    globalCompositeBlendFunc -> "globalCompositeBlendFunc"
    globalCompositeBlendFuncSeparate -> "globalCompositeBlendFuncSeparate"
    save -> "save"
    restore -> "restore"
    reset -> "reset"
    shapeAntiAlias -> "shapeAntiAlias"
    strokeColor -> "strokeColor"
    strokePaint -> "strokePaint"
    fillColor -> "fillColor"
    fillPaint -> "fillPaint"
    miterLimit -> "miterLimit"
    strokeWidth -> "strokeWidth"
    lineCap -> "lineCap"
    lineJoin -> "lineJoin"
    globalAlpha -> "globalAlpha"
    resetTransform -> "resetTransform"
    transform -> "transform"
    translate -> "translate"
    rotate -> "rotate"
    skewX -> "skewX"
    skewY -> "skewY"
    scale -> "scale"
    currentTransform -> "currentTransform"
    createImage -> "createImage"
    createImageMem -> "createImageMem"
    createImageRGBA -> "createImageRGBA"
    updateImage -> "updateImage"
    imageSize -> "imageSize"
    deleteImage -> "deleteImage"
    linearGradient -> "linearGradient"
    boxGradient -> "boxGradient"
    radialGradient -> "radialGradient"
    imagePattern -> "imagePattern"
    scissor -> "scissor"
    intersectScissor -> "intersectScissor"
    resetScissor -> "resetScissor"
    beginPath -> "beginPath"
    moveTo -> "moveTo"
    lineTo -> "lineTo"
    bezierTo -> "bezierTo"
    quadTo -> "quadTo"
    arcTo -> "arcTo"
    closePath -> "closePath"
    pathWinding -> "pathWinding"
    arc -> "arc"
    rect -> "rect"
    roundedRect -> "roundedRect"
    roundedRectVarying -> "rectVarying"
    ellipse -> "ellipse"
    circle -> "circle"
    fill -> "fill"
    stroke -> "stroke"
    createFont -> "createFont"
    createFontMem -> "createFontMem"
    findFont -> "findFont"
    addFallbackFontId -> "addFallbackFontId"
    addFallbackFont -> "addFallbackFont"
    fontSize -> "fontSize"
    fontBlur -> "fontBlur"
    textLetterSpacing -> "textLetterSpacing"
    textLineHeight -> "textLineHeight"
    textAlign -> "textAlign"
    fontFaceId -> "fontFaceId"
    fontFace -> "fontFace"
    text -> "text"
    textBox -> "textBox"
    textBounds -> "textBounds"
    textBoxBounds -> "textBoxBounds"
    textGlyphPositions -> "textGlyphPositions"
    textMetrics -> "textMetrics"
    textBreakLines -> "textBreakLines"

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
  let icons = nvg.createFont("icons", "examples/fonts/entypo.ttf")
  if icons == -1:
    echo "Could not add font icons."
    return

  let sans = nvg.createFont("sans", "examples/fonts/Roboto-Regular.ttf")
  if sans == -1:
    echo "Could not add font italic."
    return

  let bold = nvg.createFont("sans-bold", "examples/fonts/Roboto-Bold.ttf")
  if bold == -1:
    echo "Could not add font bold."
    return

  let emoji = nvg.createFont("emoji", "examples/fonts/NotoEmoji-Regular.ttf")
  if emoji == -1:
    echo "Could not add font emoji."
    return

  discard nvg.addFallbackFontId(sans, emoji)
  discard nvg.addFallbackFontId(bold, emoji)

proc drawButton(nvg: NVGContext, x, y, w, h: float64, col: NVGcolor, text: string) =
  let cornerRadius = 4.0
  let bg = nvg.linearGradient(x,y,x,y+h, nvgRGBA(255,255,255,32), nvgRGBA(0,0,0,32))
  let tw = nvg.textBounds(0,0, text)

  nvg.beginPath()
  nvg.roundedRect(x+1,y+1, w-2,h-2, cornerRadius-1)
  nvg.fillColor(col)
  nvg.fill()
  nvg.fillPaint(bg)
  nvg.fill()

  nvg.beginPath()
  nvg.roundedRect(x+0.5,y+0.5, w-1,h-1, cornerRadius-0.5)
  #nvg.nvgStrokeColor(nvgRGBA(0,0,0,48))
  nvg.stroke(0, 0, 0, 48, 1.0)
  nvg.stroke(1.0, 0.0, 0.0, 1.0, 2.0)

  if text.len > 0:
    nvg.fontSize(20.0)
    nvg.fontFace("sans-bold")
    nvg.textAlign(NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvg.fillColor(nvgRGBA(0,0,0,160))
    discard nvg.text(x+w*0.5-tw*0.5,y+h*0.5-1,text)
    nvg.fillColor(nvgRGBA(255,255,255,160))
    discard nvg.text(x+w*0.5-tw*0.5,y+h*0.5,text)

proc drawView*(view: View, nvg: NVGContext) =
  let red = view.curProp.bgColor

  if view.curProp.visible:
    nvg.save()
    nvg.translate(view.getCenterX(), view.getCenterY())
    nvg.rotate(nvgDegToRad(view.curProp.rotate))
    nvg.translate(-view.getCenterX(), -view.getCenterY())
    nvg.drawButton(view.getLeft(), view.getTop(),
      view.getWidth(), view.getHeight(), red, view.content)
    nvg.restore()

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
  var w = newGlWin(dim = (w: screenWidth, h: screenHeight), nMultiSamples = 6)
  w.makeContextCurrent()
  load_glex()
  opengl.loadExtensions()

  var nvg = nvgCreate(NVG_STENCIL_STROKES or NVG_DEBUG)
  if nvg.pointer == nil:
    echo "Could not init nanovg."
    return

  nvg.loadFonts()
  L.bindNVG(nvg)

  var actorstate = ANIM_NONE
  var anim = Animation(nil)

  proc keyboardCB(win: Win, key: Key, scanCode: int, action: KeyAction, modKeys: ModifierKeySet) =
    if key in {keyF1..keyF12}:
      if actorstate == ANIM_NONE:
        let id = "anim" & $(ord(key) - ord(keyF1) + 1)
        let ani = lay.getAnimation(id)
        if anim != ani and ani != nil:
          anim = ani
          actorstate = ANIM_START

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

    nvg.beginFrame(s.w.cint, s.h.cint, 1.0)
    nvg.beginPath()
    nvg.circle(pos_x, pos_y, 50.0)
    nvg.fillColor(nvgRGBAf(1.0, 0.7, 0.0, 1.0))
    let stroke_width = 10.0
    nvg.stroke(0.0, 0.5, 1.0, 1.0, stroke_width)
    nvg.endFrame()

    case actorstate
    of ANIM_START:
      startTime = getTime()
      actorstate = ANIM_RUN
      for a in anim.actors:
        a.interpolator(a.view.origin, a.destination, a.current, 0.0)
        a.view.current = a.current
        a.view.curProp = a.curProp
    of ANIM_RUN:
      nvg.beginFrame(s.w.cint, s.h.cint, 1.0)

      let elapsed = getTime() - startTime
      for a in anim.actors:
        if elapsed >= a.startAni:
          let timeCurve = (elapsed - a.startAni) / a.duration
          a.interpolator(a.view.origin, a.destination, a.current, timeCurve)
          a.curProp.rotate = a.easing(a.view.oriProp.rotate, a.destProp.rotate, timeCurve)
          a.curProp.bgColor.r = a.easing(a.view.oriProp.bgColor.r, a.destProp.bgColor.r, timeCurve)
          a.curProp.bgColor.g = a.easing(a.view.oriProp.bgColor.g, a.destProp.bgColor.g, timeCurve)
          a.curProp.bgColor.b = a.easing(a.view.oriProp.bgColor.b, a.destProp.bgColor.b, timeCurve)
          a.curProp.bgColor.a = a.easing(a.view.oriProp.bgColor.a, a.destProp.bgColor.a, timeCurve)

      lay.root.drawView(nvg)
      nvg.endFrame()
      w.swapBufs()
      if elapsed > anim.duration: actorstate = ANIM_STOP
    of ANIM_STOP:
      for a in anim.actors:
        a.view.setOrigin(a.destination, a.destProp)
      actorstate = ANIM_NONE
    else:
      lay.root.drawView(nvg)
      nvg.endFrame()
      w.swapBufs()
      waitEvents()

  nvg.nvgDelete()
  w.destroy()
  glfw.terminate()
  ctx.close()


main()
