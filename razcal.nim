import os, glfw, nvg, nimLUA, opengl

proc load_glex() {.importc, cdecl.}

proc bindNVG(L: PState) =

  L.bindObject(NVGContext -> "nvg"):
    nvgCreate -> "create"
    ~nvgDelete
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

proc main =
  var L = newNimLua()
  L.bindNVG()

  glfw.init()
  var w = newGlWin()
  w.makeContextCurrent()
  load_glex()
  opengl.loadExtensions()

  var nvg = nvgCreate(NVG_ANTIALIAS or NVG_STENCIL_STROKES or NVG_DEBUG)
  if nvg.pointer == nil:
    echo "Could not init nanovg."
    return

  while not w.shouldClose():
    let s = w.framebufSize()
    glViewport(0, 0, GLsizei(s.w), GLsizei(s.h))
    w.update()

  nvg.nvgDelete()
  w.destroy()
  glfw.terminate()

main()
