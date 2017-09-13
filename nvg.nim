#
# Copyright (c) 2013 Mikko Mononen memon@inside.org
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#
import math , opengl

when defined(nvgGL2):
  const GLVersion* = "GL2"
elif defined(nvgGL3):
  const GLVersion* = "GL3"
elif defined(nvgGLES2):
  const GLVersion* = "GLES2"
elif defined(nvgGLES3):
  const GLVersion* = "GLES3"
else:
  {.error: "define nvgGL2, nvgGL3, nvgGLES2, or nvgGLES3 (pass -d:... to compile)".}



{.pragma: nvg,
  header:"nanovg.h",
  cdecl,
  importc, 
.}

{.pragma: glf,
  importc:"glnvg__$1",
  cdecl,
  header:"nanovg_gl.h"
.}

{.pragma: glf2,
  importc,
  header:"nanovg_gl.h",
  cdecl
.}

{.pragma: nvgType,
  header:"nanovg.h",
  importc
.}

import os
const ThisPath* = currentSourcePath.splitPath.head

# does not work unfortunately:
# {.emit:"""/*TYPESECTION*/
# #include <GL/gl.h>
# #include <nanovg.h>
# """.}
{.passC: " -include\"GL/gl.h\" -include\"nanovg.h\" ".}
{.passC: "-DNANOVG_"&GLVersion&"_IMPLEMENTATION".}
{.passC: "-I"&ThisPath&"/nanovg/src -I"&ThisPath&"/nanovg/example ".}
{.passL: "-lGL".}
{.compile: ThisPath/"nanovg/src/nanovg.c"}


const 
  NVG_PI* = math.PI#3.141592653589793

type
  NVGcontext* {.nvgType.} = object
  NVGcontextPtr* = ptr NVGcontext

  NVGcolor* {.nvgType, byCopy.} = object 
    r*: cfloat
    g*: cfloat
    b*: cfloat
    a*: cfloat

  NVGpaint* {.nvgType, byCopy.} = object 
    xform*: array[6, cfloat]
    extent*: array[2, cfloat]
    radius*: cfloat
    feather*: cfloat
    innerColor*: NVGcolor
    outerColor*: NVGcolor
    image*: cint

  NVGwinding* = distinct cint
const
  NVG_CCW* = 1.NVGwinding     # Winding for solid shapes
  NVG_CW* = 2.NVGwinding      # Winding for holes


type 
  NVGsolidity* = enum 
    NVG_SOLID = 1,            # CCW
    NVG_HOLE = 2              # CW


type 
  NVGlineCap* = enum 
    NVG_BUTT, NVG_ROUND, NVG_SQUARE, NVG_BEVEL, NVG_MITER


type 
  NVGalign* = enum            # Horizontal align
    NVG_ALIGN_LEFT = 1 shl 0, # Default, align text horizontally to left.
    NVG_ALIGN_CENTER = 1 shl 1, # Align text horizontally to center.
    NVG_ALIGN_RIGHT = 1 shl 2, # Align text horizontally to right.
                               # Vertical align
    NVG_ALIGN_TOP = 1 shl 3,  # Align text vertically to top.
    NVG_ALIGN_MIDDLE = 1 shl 4, # Align text vertically to middle.
    NVG_ALIGN_BOTTOM = 1 shl 5, # Align text vertically to bottom. 
    NVG_ALIGN_BASELINE = 1 shl 6 # Default, align text vertically to baseline. 


type 
  NVGglyphPosition* = object 
    str*: cstring             # Position of the glyph in the input string.
    x*: cfloat                # The x-coordinate of the logical glyph position.
    minx*: cfloat
    maxx*: cfloat             # The bounds of the glyph shape.
  
  NVGtextRow* = object 
    start*: cstring           # Pointer to the input text where the row starts.
    `end`*: cstring           # Pointer to the input text where the row ends (one past the last character).
    next*: cstring            # Pointer to the beginning of the next row.
    width*: cfloat            # Logical width of the row.
    minx*: cfloat
    maxx*: cfloat             # Actual bounds of the row. Logical with and bounds can differ because of kerning and some parts over extending.
  
  NVGimageFlags* = enum 
    NVG_IMAGE_GENERATE_MIPMAPS = 1 shl 0, # Generate mipmaps during creation of the image.
    NVG_IMAGE_REPEATX = 1 shl 1, # Repeat image in X direction.
    NVG_IMAGE_REPEATY = 1 shl 2, # Repeat image in Y direction.
    NVG_IMAGE_FLIPY = 1 shl 3, # Flips (inverses) image in Y direction when rendered.
    NVG_IMAGE_PREMULTIPLIED = 1 shl 4 # Image data has premultiplied alpha.


# Begin drawing a new frame
# Calls to nanovg drawing API should be wrapped in nvgBeginFrame() & nvgEndFrame()
# nvgBeginFrame() defines the size of the window to render to in relation currently
# set viewport (i.e. glViewport on GL backends). Device pixel ration allows to
# control the rendering on Hi-DPI devices.
# For example, GLFW returns two dimension for an opened window: window size and
# frame buffer size. In that case you would set windowWidth/Height to the window size
# devicePixelRatio to: frameBufferWidth / windowWidth.

proc nvgBeginFrame*(ctx: NVGcontextPtr; windowWidth: cint; windowHeight: cint; 
                    devicePixelRatio: cfloat) {.nvg.}
# Cancels drawing the current frame.

proc nvgCancelFrame*(ctx: NVGcontextPtr) {.nvg.}
# Ends drawing flushing remaining render state.

proc nvgEndFrame*(ctx: NVGcontextPtr) {.nvg.}
#
# Color utils
#
# Colors in NanoVG are stored as unsigned ints in ABGR format.
# Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).

proc nvgRGB*(r: cuchar; g: cuchar; b: cuchar): NVGcolor {.nvg.}
# Returns a color value from red, green, blue values. Alpha will be set to 1.0f.

proc nvgRGBf*(r: cfloat; g: cfloat; b: cfloat): NVGcolor {.nvg.}
# Returns a color value from red, green, blue and alpha values.

proc nvgRGBA*(r,g,b,a: uint8): NVGcolor {.nvg.}
# Returns a color value from red, green, blue and alpha values.

proc nvgRGBAf*(r: cfloat; g: cfloat; b: cfloat; a: cfloat): NVGcolor {.nvg.}
# Linearly interpolates from color c0 to c1, and returns resulting color value.

proc nvgLerpRGBA*(c0: NVGcolor; c1: NVGcolor; u: cfloat): NVGcolor {.nvg.}
# Sets transparency of a color value.

proc nvgTransRGBA*(c0: NVGcolor; a: cuchar): NVGcolor {.nvg.}
# Sets transparency of a color value.

proc nvgTransRGBAf*(c0: NVGcolor; a: cfloat): NVGcolor {.nvg.}
# Returns color value specified by hue, saturation and lightness.
# HSL values are all in range [0..1], alpha will be set to 255.

proc nvgHSL*(h: cfloat; s: cfloat; l: cfloat): NVGcolor {.nvg.}
# Returns color value specified by hue, saturation and lightness and alpha.
# HSL values are all in range [0..1], alpha in range [0..255]

proc nvgHSLA*(h: cfloat; s: cfloat; l: cfloat; a: cuchar): NVGcolor {.nvg.}
#
# State Handling
#
# NanoVG contains state which represents how paths will be rendered.
# The state contains transform, fill and stroke styles, text and font styles,
# and scissor clipping.
# Pushes and saves the current render state into a state stack.
# A matching nvgRestore() must be used to restore the state.

proc nvgSave*(ctx: NVGcontextPtr) {.nvg.}
# Pops and restores current render state.

proc nvgRestore*(ctx: NVGcontextPtr) {.nvg.}
# Resets current render state to default values. Does not affect the render state stack.

proc nvgReset*(ctx: NVGcontextPtr) {.nvg.}
#
# Render styles
#
# Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
# Solid color is simply defined as a color value, different kinds of paints can be created
# using nvgLinearGradient(), nvgBoxGradient(), nvgRadialGradient() and nvgImagePattern().
#
# Current render style can be saved and restored using nvgSave() and nvgRestore(). 
# Sets current stroke style to a solid color.

proc nvgStrokeColor*(ctx: NVGcontextPtr; color: NVGcolor) {.nvg.}
# Sets current stroke style to a paint, which can be a one of the gradients or a pattern.

proc nvgStrokePaint*(ctx: NVGcontextPtr; paint: NVGpaint) {.nvg.}
# Sets current fill style to a solid color.

proc nvgFillColor*(ctx: NVGcontextPtr; color: NVGcolor) {.nvg.}
# Sets current fill style to a paint, which can be a one of the gradients or a pattern.

proc nvgFillPaint*(ctx: NVGcontextPtr; paint: NVGpaint) {.nvg.}
# Sets the miter limit of the stroke style.
# Miter limit controls when a sharp corner is beveled.

proc nvgMiterLimit*(ctx: NVGcontextPtr; limit: cfloat) {.nvg.}
# Sets the stroke width of the stroke style.

proc nvgStrokeWidth*(ctx: NVGcontextPtr; size: cfloat) {.nvg.}
# Sets how the end of the line (cap) is drawn,
# Can be one of: NVG_BUTT (default), NVG_ROUND, NVG_SQUARE.

proc nvgLineCap*(ctx: NVGcontextPtr; cap: cint) {.nvg.}
# Sets how sharp path corners are drawn.
# Can be one of NVG_MITER (default), NVG_ROUND, NVG_BEVEL.

proc nvgLineJoin*(ctx: NVGcontextPtr; join: cint) {.nvg.}
# Sets the transparency applied to all rendered shapes.
# Already transparent paths will get proportionally more transparent as well.

proc nvgGlobalAlpha*(ctx: NVGcontextPtr; alpha: cfloat) {.nvg.}
#
# Transforms
#
# The paths, gradients, patterns and scissor region are transformed by an transformation
# matrix at the time when they are passed to the API.
# The current transformation matrix is a affine matrix:
#   [sx kx tx]
#   [ky sy ty]
#   [ 0  0  1]
# Where: sx,sy define scaling, kx,ky skewing, and tx,ty translation.
# The last row is assumed to be 0,0,1 and is not stored.
#
# Apart from nvgResetTransform(), each transformation function first creates
# specific transformation matrix and pre-multiplies the current transformation by it.
#
# Current coordinate system (transformation) can be saved and restored using nvgSave() and nvgRestore(). 
# Resets current transform to a identity matrix.

proc nvgResetTransform*(ctx: NVGcontextPtr) {.nvg.}
# Premultiplies current coordinate system by specified matrix.
# The parameters are interpreted as matrix as follows:
#   [a c e]
#   [b d f]
#   [0 0 1]

proc nvgTransform*(ctx: NVGcontextPtr; a: cfloat; b: cfloat; c: cfloat; 
                   d: cfloat; e: cfloat; f: cfloat) {.nvg.}
# Translates current coordinate system.

proc nvgTranslate*(ctx: NVGcontextPtr; x: cfloat; y: cfloat) {.nvg.}
# Rotates current coordinate system. Angle is specified in radians.

proc nvgRotate*(ctx: NVGcontextPtr; angle: cfloat) {.nvg.}
# Skews the current coordinate system along X axis. Angle is specified in radians.

proc nvgSkewX*(ctx: NVGcontextPtr; angle: cfloat) {.nvg.}
# Skews the current coordinate system along Y axis. Angle is specified in radians.

proc nvgSkewY*(ctx: NVGcontextPtr; angle: cfloat) {.nvg.}
# Scales the current coordinate system.

proc nvgScale*(ctx: NVGcontextPtr; x: cfloat; y: cfloat) {.nvg.}
# Stores the top part (a-f) of the current transformation matrix in to the specified buffer.
#   [a c e]
#   [b d f]
#   [0 0 1]
# There should be space for 6 floats in the return buffer for the values a-f.

proc nvgCurrentTransform*(ctx: NVGcontextPtr; xform: ptr cfloat) {.nvg.}
# The following functions can be used to make calculations on 2x3 transformation matrices.
# A 2x3 matrix is represented as float[6].
# Sets the transform to identity matrix.

proc nvgTransformIdentity*(dst: ptr cfloat) {.nvg.}
# Sets the transform to translation matrix matrix.

proc nvgTransformTranslate*(dst: ptr cfloat; tx: cfloat; ty: cfloat) {.nvg.}
# Sets the transform to scale matrix.

proc nvgTransformScale*(dst: ptr cfloat; sx: cfloat; sy: cfloat) {.nvg.}
# Sets the transform to rotate matrix. Angle is specified in radians.

proc nvgTransformRotate*(dst: ptr cfloat; a: cfloat) {.nvg.}
# Sets the transform to skew-x matrix. Angle is specified in radians.

proc nvgTransformSkewX*(dst: ptr cfloat; a: cfloat) {.nvg.}
# Sets the transform to skew-y matrix. Angle is specified in radians.

proc nvgTransformSkewY*(dst: ptr cfloat; a: cfloat) {.nvg.}
# Sets the transform to the result of multiplication of two transforms, of A = A*B.

proc nvgTransformMultiply*(dst: ptr cfloat; src: ptr cfloat) {.nvg.}
# Sets the transform to the result of multiplication of two transforms, of A = B*A.

proc nvgTransformPremultiply*(dst: ptr cfloat; src: ptr cfloat) {.nvg.}
# Sets the destination to inverse of specified transform.
# Returns 1 if the inverse could be calculated, else 0.

proc nvgTransformInverse*(dst: ptr cfloat; src: ptr cfloat): cint {.nvg.}
# Transform a point by given transform.

proc nvgTransformPoint*(dstx: ptr cfloat; dsty: ptr cfloat; xform: ptr cfloat; 
                        srcx: cfloat; srcy: cfloat) {.nvg.}
# Converts degrees to radians and vice versa.

proc nvgDegToRad*(deg: cfloat): cfloat {.nvg.}
proc nvgRadToDeg*(rad: cfloat): cfloat {.nvg.}
#
# Images
#
# NanoVG allows you to load jpg, png, psd, tga, pic and gif files to be used for rendering.
# In addition you can upload your own image. The image loading is provided by stb_image.
# The parameter imageFlags is combination of flags defined in NVGimageFlags.
# Creates image by loading it from the disk from specified file name.
# Returns handle to the image.

proc nvgCreateImage*(ctx: NVGcontextPtr; filename: cstring; imageFlags: cint): cint {.nvg.}
# Creates image by loading it from the specified chunk of memory.
# Returns handle to the image.

proc nvgCreateImageMem*(ctx: NVGcontextPtr; imageFlags: cint; data: ptr cuchar; 
                        ndata: cint): cint {.nvg.}
# Creates image from specified image data.
# Returns handle to the image.

proc nvgCreateImageRGBA*(ctx: NVGcontextPtr; w: cint; h: cint; 
                         imageFlags: cint; data: ptr cuchar): cint {.nvg.}
# Updates image data specified by image handle.

proc nvgUpdateImage*(ctx: NVGcontextPtr; image: cint; data: ptr cuchar) {.nvg.}
# Returns the dimensions of a created image.

proc nvgImageSize*(ctx: NVGcontextPtr; image: cint; w: ptr cint; h: ptr cint) {.nvg.}
# Deletes created image.

proc nvgDeleteImage*(ctx: NVGcontextPtr; image: cint) {.nvg.}
#
# Paints
#
# NanoVG supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
# These can be used as paints for strokes and fills.
# Creates and returns a linear gradient. Parameters (sx,sy)-(ex,ey) specify the start and end coordinates
# of the linear gradient, icol specifies the start color and ocol the end color.
# The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().

proc nvgLinearGradient*(ctx: NVGcontextPtr; sx: cfloat; sy: cfloat; ex: cfloat; 
                        ey: cfloat; icol: NVGcolor; ocol: NVGcolor): NVGpaint {.nvg.}
# Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
# drop shadows or highlights for boxes. Parameters (x,y) define the top-left corner of the rectangle,
# (w,h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
# the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
# The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().

proc nvgBoxGradient*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; w: cfloat; 
                     h: cfloat; r: cfloat; f: cfloat; icol: NVGcolor; 
                     ocol: NVGcolor): NVGpaint {.nvg.}
# Creates and returns a radial gradient. Parameters (cx,cy) specify the center, inr and outr specify
# the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
# The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().

proc nvgRadialGradient*(ctx: NVGcontextPtr; cx: cfloat; cy: cfloat; 
                        inr: cfloat; outr: cfloat; icol: NVGcolor; 
                        ocol: NVGcolor): NVGpaint {.nvg.}
# Creates and returns an image patter. Parameters (ox,oy) specify the left-top location of the image pattern,
# (ex,ey) the size of one image, angle rotation around the top-left corner, image is handle to the image to render.
# The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().

proc nvgImagePattern*(ctx: NVGcontextPtr; ox: cfloat; oy: cfloat; ex: cfloat; 
                      ey: cfloat; angle: cfloat; image: cint; alpha: cfloat): NVGpaint {.nvg.}
#
# Scissoring
#
# Scissoring allows you to clip the rendering into a rectangle. This is useful for various
# user interface cases like rendering a text edit or a timeline. 
# Sets the current scissor rectangle.
# The scissor rectangle is transformed by the current transform.

proc nvgScissor*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; w: cfloat; h: cfloat) {.nvg.}
# Intersects current scissor rectangle with the specified rectangle.
# The scissor rectangle is transformed by the current transform.
# Note: in case the rotation of previous scissor rect differs from
# the current one, the intersection will be done between the specified
# rectangle and the previous scissor rectangle transformed in the current
# transform space. The resulting shape is always rectangle.

proc nvgIntersectScissor*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; w: cfloat; 
                          h: cfloat) {.nvg.}
# Reset and disables scissoring.

proc nvgResetScissor*(ctx: NVGcontextPtr) {.nvg.}
#
# Paths
#
# Drawing a new shape starts with nvgBeginPath(), it clears all the currently defined paths.
# Then you define one or more paths and sub-paths which describe the shape. The are functions
# to draw common shapes like rectangles and circles, and lower level step-by-step functions,
# which allow to define a path curve by curve.
#
# NanoVG uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
# winding and holes should have counter clockwise order. To specify winding of a path you can
# call nvgPathWinding(). This is useful especially for the common shapes, which are drawn CCW.
#
# Finally you can fill the path using current fill style by calling nvgFill(), and stroke it
# with current stroke style by calling nvgStroke().
#
# The curve segments and sub-paths are transformed by the current transform.
# Clears the current path and sub-paths.

proc nvgBeginPath*(ctx: NVGcontextPtr) {.nvg.}
# Starts new sub-path with specified point as first point.

proc nvgMoveTo*(ctx: NVGcontextPtr; x: cfloat; y: cfloat) {.nvg.}
# Adds line segment from the last point in the path to the specified point.

proc nvgLineTo*(ctx: NVGcontextPtr; x: cfloat; y: cfloat) {.nvg.}
# Adds cubic bezier segment from last point in the path via two control points to the specified point.

proc nvgBezierTo*(ctx: NVGcontextPtr; c1x: cfloat; c1y: cfloat; c2x: cfloat; 
                  c2y: cfloat; x: cfloat; y: cfloat) {.nvg.}
# Adds quadratic bezier segment from last point in the path via a control point to the specified point.

proc nvgQuadTo*(ctx: NVGcontextPtr; cx: cfloat; cy: cfloat; x: cfloat; 
                y: cfloat) {.nvg.}
# Adds an arc segment at the corner defined by the last path point, and two specified points.

proc nvgArcTo*(ctx: NVGcontextPtr; x1: cfloat; y1: cfloat; x2: cfloat; 
               y2: cfloat; radius: cfloat) {.nvg.}
# Closes current sub-path with a line segment.

proc nvgClosePath*(ctx: NVGcontextPtr) {.nvg.}
# Sets the current sub-path winding, see NVGwinding and NVGsolidity. 

proc nvgPathWinding*(ctx: NVGcontextPtr; dir: cint) {.nvg.}
# Creates new circle arc shaped sub-path. The arc center is at cx,cy, the arc radius is r,
# and the arc is drawn from angle a0 to a1, and swept in direction dir (NVG_CCW, or NVG_CW).
# Angles are specified in radians.

proc nvgArc*(ctx: NVGcontextPtr; cx: cfloat; cy: cfloat; r: cfloat; a0: cfloat; 
             a1: cfloat; dir: NVGwinding) {.nvg.}
# Creates new rectangle shaped sub-path.

proc nvgRect*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; w: cfloat; h: cfloat) {.nvg.}
# Creates new rounded rectangle shaped sub-path.

proc nvgRoundedRect*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; w: cfloat; 
                     h: cfloat; r: cfloat) {.nvg.}
# Creates new ellipse shaped sub-path.

proc nvgEllipse*(ctx: NVGcontextPtr; cx: cfloat; cy: cfloat; rx: cfloat; 
                 ry: cfloat) {.nvg.}
# Creates new circle shaped sub-path. 

proc nvgCircle*(ctx: NVGcontextPtr; cx: cfloat; cy: cfloat; r: cfloat) {.nvg.}
# Fills the current path with current fill style.

proc nvgFill*(ctx: NVGcontextPtr) {.nvg.}
# Fills the current path with current stroke style.

proc nvgStroke*(ctx: NVGcontextPtr) {.nvg.}
#
# Text
#
# NanoVG allows you to load .ttf files and use the font to render text.
#
# The appearance of the text can be defined by setting the current text style
# and by specifying the fill color. Common text and font settings such as
# font size, letter spacing and text align are supported. Font blur allows you
# to create simple text effects such as drop shadows.
#
# At render time the font face can be set based on the font handles or name.
#
# Font measure functions return values in local space, the calculations are
# carried in the same resolution as the final rendering. This is done because
# the text glyph positions are snapped to the nearest pixels sharp rendering.
#
# The local space means that values are not rotated or scale as per the current
# transformation. For example if you set font size to 12, which would mean that
# line height is 16, then regardless of the current scaling and rotation, the
# returned line height is always 16. Some measures may vary because of the scaling
# since aforementioned pixel snapping.
#
# While this may sound a little odd, the setup allows you to always render the
# same way regardless of scaling. I.e. following works regardless of scaling:
#
#		const char* txt = "Text me up.";
#		nvgTextBounds(vg, x,y, txt, NULL, bounds);
#		nvgBeginPath(vg);
#		nvgRoundedRect(vg, bounds[0],bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]);
#		nvgFill(vg);
#
# Note: currently only solid color fill is supported for text.
# Creates font by loading it from the disk from specified file name.
# Returns handle to the font.

proc nvgCreateFont*(ctx: NVGcontextPtr; name: cstring; filename: cstring): cint {.nvg.}
# Creates image by loading it from the specified memory chunk.
# Returns handle to the font.

proc nvgCreateFontMem*(ctx: NVGcontextPtr; name: cstring; data: ptr cuchar; 
                       ndata: cint; freeData: cint): cint {.nvg.}
# Finds a loaded font of specified name, and returns handle to it, or -1 if the font is not found.

proc nvgFindFont*(ctx: NVGcontextPtr; name: cstring): cint {.nvg.}
# Sets the font size of current text style.

proc nvgFontSize*(ctx: NVGcontextPtr; size: cfloat) {.nvg.}
# Sets the blur of current text style.

proc nvgFontBlur*(ctx: NVGcontextPtr; blur: cfloat) {.nvg.}
# Sets the letter spacing of current text style.

proc nvgTextLetterSpacing*(ctx: NVGcontextPtr; spacing: cfloat) {.nvg.}
# Sets the proportional line height of current text style. The line height is specified as multiple of font size. 

proc nvgTextLineHeight*(ctx: NVGcontextPtr; lineHeight: cfloat) {.nvg.}
# Sets the text align of current text style, see NVGalign for options.

proc nvgTextAlign*(ctx: NVGcontextPtr; align: cint) {.nvg.}
# Sets the font face based on specified id of current text style.

proc nvgFontFaceId*(ctx: NVGcontextPtr; font: cint) {.nvg.}
# Sets the font face based on specified name of current text style.

proc nvgFontFace*(ctx: NVGcontextPtr; font: cstring) {.nvg.}
# Draws text string at specified location. If end is specified only the sub-string up to the end is drawn.

proc nvgText*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; string: cstring; 
              `end`: cstring): cfloat {.nvg.}
# Draws multi-line text string at specified location wrapped at the specified width. If end is specified only the sub-string up to the end is drawn.
# White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
# Words longer than the max width are slit at nearest character (i.e. no hyphenation).

proc nvgTextBox*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; 
                 breakRowWidth: cfloat; string: cstring; `end`: cstring) {.nvg.}
# Measures the specified text string. Parameter bounds should be a pointer to float[4],
# if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
# Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
# Measured values are returned in local coordinate space.

proc nvgTextBounds*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; string: cstring; 
                    `end`: cstring; bounds: ptr cfloat): cfloat {.nvg.}
# Measures the specified multi-text string. Parameter bounds should be a pointer to float[4],
# if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
# Measured values are returned in local coordinate space.

proc nvgTextBoxBounds*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; 
                       breakRowWidth: cfloat; string: cstring; `end`: cstring; 
                       bounds: ptr cfloat) {.nvg.}
# Calculates the glyph x positions of the specified text. If end is specified only the sub-string will be used.
# Measured values are returned in local coordinate space.

proc nvgTextGlyphPositions*(ctx: NVGcontextPtr; x: cfloat; y: cfloat; 
                            string: cstring; `end`: cstring; 
                            positions: ptr NVGglyphPosition; maxPositions: cint): cint {.nvg.}
# Returns the vertical metrics based on the current text style.
# Measured values are returned in local coordinate space.

proc nvgTextMetrics*(ctx: NVGcontextPtr; ascender: ptr cfloat; 
                     descender: ptr cfloat; lineh: ptr cfloat) {.nvg.}
# Breaks the specified text into lines. If end is specified only the sub-string will be used.
# White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
# Words longer than the max width are slit at nearest character (i.e. no hyphenation).

proc nvgTextBreakLines*(ctx: NVGcontextPtr; string: cstring; `end`: cstring; 
                        breakRowWidth: cfloat; rows: ptr NVGtextRow; 
                        maxRows: cint): cint {.nvg.}
#
# Internal Render API
#

type 
  NVGtexture* = enum 
    NVG_TEXTURE_ALPHA = 0x00000001, NVG_TEXTURE_RGBA = 0x00000002


type 
  NVGscissor* = object 
    xform*: array[6, cfloat]
    extent*: array[2, cfloat]

  NVGvertex* = object 
    x*: cfloat
    y*: cfloat
    u*: cfloat
    v*: cfloat

  NVGpath* = object 
    first*: cint
    count*: cint
    closed*: cuchar
    nbevel*: cint
    fill*: ptr NVGvertex
    nfill*: cint
    stroke*: ptr NVGvertex
    nstroke*: cint
    winding*: cint
    convex*: cint

  NVGparams* = object 
    userPtr*: pointer
    edgeAntiAlias*: cint
    renderCreate*: proc (uptr: pointer): cint
    renderCreateTexture*: proc (uptr: pointer; `type`: cint; w: cint; h: cint; 
                                imageFlags: cint; data: ptr cuchar): cint
    renderDeleteTexture*: proc (uptr: pointer; image: cint): cint
    renderUpdateTexture*: proc (uptr: pointer; image: cint; x: cint; y: cint; 
                                w: cint; h: cint; data: ptr cuchar): cint
    renderGetTextureSize*: proc (uptr: pointer; image: cint; w: ptr cint; 
                                 h: ptr cint): cint
    renderViewport*: proc (uptr: pointer; width: cint; height: cint)
    renderCancel*: proc (uptr: pointer)
    renderFlush*: proc (uptr: pointer)
    renderFill*: proc (uptr: pointer; paint: ptr NVGpaint; 
                       scissor: ptr NVGscissor; fringe: cfloat; 
                       bounds: ptr cfloat; paths: ptr NVGpath; npaths: cint)
    renderStroke*: proc (uptr: pointer; paint: ptr NVGpaint; 
                         scissor: ptr NVGscissor; fringe: cfloat; 
                         strokeWidth: cfloat; paths: ptr NVGpath; npaths: cint)
    renderTriangles*: proc (uptr: pointer; paint: ptr NVGpaint; 
                            scissor: ptr NVGscissor; verts: ptr NVGvertex; 
                            nverts: cint)
    renderDelete*: proc (uptr: pointer)


# Constructor and destructor, called by the render back-end.

proc nvgCreateInternal*(params: ptr NVGparams): NVGcontextPtr {.nvg.}
proc nvgDeleteInternal*(ctx: NVGcontextPtr) {.nvg.}
proc nvgInternalParams*(ctx: NVGcontextPtr): ptr NVGparams {.nvg.}
# Debug function to dump cached path data.

proc nvgDebugDumpPathCache*(ctx: NVGcontextPtr) {.nvg.}
# when defined(_MSC_VER): 
# template NVG_NOTUSED*(v: expr): stmt = 
#   while true: 
#     (void)(if 1: cast[nil](0) else: ((void)(v)))
#     break 









#
# Copyright (c) 2009-2013 Mikko Mononen memon@inside.org
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#
# #ifndef NANOVG_GL_H
# #define NANOVG_GL_H
# #ifdef __cplusplus
# extern "C" {
# #endif
# Create flags



## nanovg_gl.h 

type 
  NVGcreateFlags* {.size:sizeof(cint).} = enum      # Flag indicating if geometry based anti-aliasing is used (may not be needed when using MSAA).
    NVG_ANTIALIAS = 1 shl 0, # Flag indicating if strokes should be drawn using stencil buffer. The rendering will be a little
                             # slower, but path overlaps (i.e. self-intersecting or sharp turns) will be drawn just once.
    NVG_STENCIL_STROKES = 1 shl 1, # Flag indicating that additional debug checks are done.
    NVG_DEBUG = 1 shl 2
converter toCint* (some:NVGcreateFlags): cint = cint(some)

const 
  NANOVG_GL_USE_STATE_FILTER* = (1)

# Creates NanoVG contexts for different OpenGL (ES) versions.
# Flags should be combination of the create flags above.

when defined(nvgGL2): 
  proc nvgCreateGL2*(flags: cint): NVGcontextPtr {.glf2.}
  proc nvgDeleteGL2*(ctx: NVGcontextPtr) {.glf2.}
when defined(nvgGL3): 
  proc nvgCreateGL3*(flags: cint): NVGcontextPtr {.glf2.}
  proc nvgDeleteGL3*(ctx: NVGcontextPtr) {.glf2.}
when defined(NANOVG_GLES2): 
  proc nvgCreateGLES2*(flags: cint): NVGcontextPtr {.glf2.}
  proc nvgDeleteGLES2*(ctx: NVGcontextPtr) {.glf2.}
when defined(NANOVG_GLES3): 
  proc nvgCreateGLES3*(flags: cint): NVGcontextPtr {.glf2.}
  proc nvgDeleteGLES3*(ctx: NVGcontextPtr) {.glf2.}
# These are additional flags on top of NVGimageFlags.

type 
  NVGimageFlagsGL* = enum 
    NVG_IMAGE_NODELETE = 1 shl 16 # Do not delete GL texture handle.


proc nvglCreateImageFromHandle*(ctx: NVGcontextPtr; textureId: GLuint; w: cint; 
                                h: cint; flags: cint): cint {.glf2.}
proc nvglImageHandle*(ctx: NVGcontextPtr; image: cint): GLuint {.glf2.}
# #ifdef __cplusplus
# }
# #endif
# #endif /* NANOVG_GL_H */

when defined(NANOVG_GL_IMPLEMENTATION): 
  import 
    nanovg

  type 
    GLNVGuniformLoc* = enum 
      GLNVG_LOC_VIEWSIZE, GLNVG_LOC_TEX, GLNVG_LOC_FRAG, GLNVG_MAX_LOCS
  type 
    GLNVGshaderType* = enum 
      NSVG_SHADER_FILLGRAD, NSVG_SHADER_FILLIMG, NSVG_SHADER_SIMPLE, 
      NSVG_SHADER_IMG
  when NANOVG_GL_USE_UNIFORMBUFFER: 
    type 
      GLNVGuniformBindings* = enum 
        GLNVG_FRAG_BINDING = 0
  type 
    GLNVGshader* = object 
      prog*: GLuint
      frag*: GLuint
      vert*: GLuint
      loc*: array[GLNVG_MAX_LOCS, GLint]

  type 
    GLNVGtexture* = object 
      id*: cint
      tex*: GLuint
      width*: cint
      height*: cint
      `type`*: cint
      flags*: cint

  type 
    GLNVGcallType* = enum 
      GLNVG_NONE = 0, GLNVG_FILL, GLNVG_CONVEXFILL, GLNVG_STROKE, 
      GLNVG_TRIANGLES
  type 
    GLNVGcall* = object 
      `type`*: cint
      image*: cint
      pathOffset*: cint
      pathCount*: cint
      triangleOffset*: cint
      triangleCount*: cint
      uniformOffset*: cint

  type 
    GLNVGpath* = object 
      fillOffset*: cint
      fillCount*: cint
      strokeOffset*: cint
      strokeCount*: cint

  type 
    INNER_C_STRUCT_1182527569073591724* = object 
      scissorMat*: array[12, cfloat] # matrices are actually 3 vec4s
      paintMat*: array[12, cfloat]
      innerCol*: NVGcolor
      outerCol*: NVGcolor
      scissorExt*: array[2, cfloat]
      scissorScale*: array[2, cfloat]
      extent*: array[2, cfloat]
      radius*: cfloat
      feather*: cfloat
      strokeMult*: cfloat
      strokeThr*: cfloat
      texType*: cfloat
      `type`*: cfloat

  type 
    INNER_C_UNION_1248175051974793794* = object  {.union.}
      ano_16524351669436924357*: INNER_C_STRUCT_1182527569073591724
      uniformArray*: array[NANOVG_GL_UNIFORMARRAY_SIZE, array[4, cfloat]]

  type 
    GLNVGfragUniforms* = object 
      ano_16511226140107564129*: INNER_C_UNION_1248175051974793794 # #if 
                                                                   #NANOVG_GL_USE_UNIFORMBUFFER
                                                                   #  float 
                                                                   # scissorMat[12]; // matrices are actually 3 vec4s
                                                                   #  float paintMat[12];
                                                                   #  struct NVGcolor innerCol;
                                                                   #  struct NVGcolor outerCol;
                                                                   #  float 
                                                                   # scissorExt[2];
                                                                   #  float 
                                                                   # scissorScale[2];
                                                                   #  float extent[2];
                                                                   #  float radius;
                                                                   #  float feather;
                                                                   #  float strokeMult;
                                                                   #  float strokeThr;
                                                                   #  int texType;
                                                                   #  int type;
                                                                   # #else
                                                                   # note: after modifying layout or size of uniform array,
                                                                   # don't forget to also update the fragment shader source!
                                                                   #    #define 
                                                                   #NANOVG_GL_UNIFORMARRAY_SIZE 11
    
  type 
    GLNVGcontext* = object 
      shader*: GLNVGshader
      textures*: ptr GLNVGtexture
      view*: array[2, cfloat]
      ntextures*: cint
      ctextures*: cint
      textureId*: cint
      vertBuf*: GLuint        ##if defined(NANOVG_GL3)\
      vertArr*: GLuint        ##endif\
                              ##if NANOVG_GL_USE_UNIFORMBUFFER\
      fragBuf*: GLuint        ##endif
      fragSize*: cint
      flags*: cint            # Per frame buffers
      calls*: ptr GLNVGcall
      ccalls*: cint
      ncalls*: cint
      paths*: ptr GLNVGpath
      cpaths*: cint
      npaths*: cint
      verts*: ptr NVGvertex
      cverts*: cint
      nverts*: cint
      uniforms*: ptr cuchar
      cuniforms*: cint
      nuniforms*: cint        # cached state
                              # #if NANOVG_GL_USE_STATE_FILTER
                              # GLuint boundTexture;
                              # GLuint stencilMask;
                              # GLenum stencilFunc;
                              # GLint stencilFuncRef;
                              # GLuint stencilFuncMask;
                              # #endif
  

  proc maxi*(a: cint; b: cint): cint {.glf.}

  when defined(NANOVG_GLES2): 
    proc nearestPow2*(num: cuint): cuint {.glf.}

  proc bindTexture*(gl: ptr GLNVGcontext; tex: GLuint) {.glf.}
  # {
  # #if NANOVG_GL_USE_STATE_FILTER
  #   if (gl->boundTexture != tex) {
  #     gl->boundTexture = tex;
  #     glBindTexture(GL_TEXTURE_2D, tex);
  #   }
  # #else
  #   glBindTexture(GL_TEXTURE_2D, tex);
  # #endif
  # }
  proc stencilMask*(gl: ptr GLNVGcontext; mask: GLuint) {.glf.}
  # {
  # #if NANOVG_GL_USE_STATE_FILTER
  #   if (gl->stencilMask != mask) {
  #     gl->stencilMask = mask;
  #     glStencilMask(mask);
  #   }
  # #else
  #   glStencilMask(mask);
  # #endif
  # }
  proc stencilFunc*(gl: ptr GLNVGcontext; `func`: GLenum; `ref`: GLint; 
                           mask: GLuint)
  # {
  # #if NANOVG_GL_USE_STATE_FILTER
  #   if ((gl->stencilFunc != func) ||
  #     (gl->stencilFuncRef != ref) ||
  #     (gl->stencilFuncMask != mask)) {
  #     gl->stencilFunc = func;
  #     gl->stencilFuncRef = ref;
  #     gl->stencilFuncMask = mask;
  #     glStencilFunc(func, ref, mask);
  #   }
  # #else
  #   glStencilFunc(func, ref, mask);
  # #endif
  # }
  proc allocTexture*(gl: ptr GLNVGcontext): ptr GLNVGtexture
  # {
  #   GLNVGtexture* tex = NULL;
  #   int i;
  #   for (i = 0; i < gl->ntextures; i++) {
  #     if (gl->textures[i].id == 0) {
  #       tex = &gl->textures[i];
  #       break;
  #     }
  #   }
  #   if (tex == NULL) {
  #     if (gl->ntextures+1 > gl->ctextures) {
  #       GLNVGtexture* textures;
  #       int ctextures = glnvg__maxi(gl->ntextures+1, 4) +  gl->ctextures/2; // 1.5x Overallocate
  #       textures = (GLNVGtexture*)realloc(gl->textures, sizeof(GLNVGtexture)*ctextures);
  #       if (textures == NULL) return NULL;
  #       gl->textures = textures;
  #       gl->ctextures = ctextures;
  #     }
  #     tex = &gl->textures[gl->ntextures++];
  #   }
  #   memset(tex, 0, sizeof(*tex));
  #   tex->id = ++gl->textureId;
  #   return tex;
  # }
  proc findTexture*(gl: ptr GLNVGcontext; id: cint): ptr GLNVGtexture
  # {
  #   int i;
  #   for (i = 0; i < gl->ntextures; i++)
  #     if (gl->textures[i].id == id)
  #       return &gl->textures[i];
  #   return NULL;
  # }
  proc deleteTexture*(gl: ptr GLNVGcontext; id: cint): cint {.glf.}
  # {
  #   int i;
  #   for (i = 0; i < gl->ntextures; i++) {
  #     if (gl->textures[i].id == id) {
  #       if (gl->textures[i].tex != 0 && (gl->textures[i].flags & NVG_IMAGE_NODELETE) == 0)
  #         glDeleteTextures(1, &gl->textures[i].tex);
  #       memset(&gl->textures[i], 0, sizeof(gl->textures[i]));
  #       return 1;
  #     }
  #   }
  #   return 0;
  # }
  proc dumpShaderError*(shader: GLuint; name: cstring; `type`: cstring) {.glf.}

  proc dumpProgramError*(prog: GLuint; name: cstring) {.glf.}

  proc checkError*(gl: ptr GLNVGcontext; str: cstring) {.glf.}

  proc createShader*(shader: ptr GLNVGshader; name: cstring; 
                            header: cstring; opts: cstring; vshader: cstring; 
                            fshader: cstring): cint {.glf.}

  proc deleteShader*(shader: ptr GLNVGshader) {.glf.}
  
  proc getUniforms*(shader: ptr GLNVGshader) {.glf.}

  proc renderCreate*(uptr: pointer): cint {.glf.}
    # {
    #   GLNVGcontext* gl = (GLNVGcontext*)uptr;
    #   int align = 4;
    #   // TODO: mediump float may not be enough for GLES2 in iOS.
    #   // see the following discussion: https://github.com/memononen/nanovg/issues/46
    #   static const char* shaderHeader =
    # #if defined(NANOVG_GL2)
    #     "#define NANOVG_GL2 1\n"
    # #elif defined(NANOVG_GL3)
    #     "#version 150 core\n"
    #     "#define NANOVG_GL3 1\n"
    # #elif defined(NANOVG_GLES2)
    #     "#version 100\n"
    #     "#define NANOVG_GL2 1\n"
    # #elif defined(NANOVG_GLES3)
    #     "#version 300 es\n"
    #     "#define NANOVG_GL3 1\n"
    # #endif
    # #if NANOVG_GL_USE_UNIFORMBUFFER
    #   "#define USE_UNIFORMBUFFER 1\n"
    # #else
    #   "#define UNIFORMARRAY_SIZE 11\n"
    # #endif
    #   "\n";
    #   static const char* fillVertShader =
    #     "#ifdef NANOVG_GL3\n"
    #     " uniform vec2 viewSize;\n"
    #     " in vec2 vertex;\n"
    #     " in vec2 tcoord;\n"
    #     " out vec2 ftcoord;\n"
    #     " out vec2 fpos;\n"
    #     "#else\n"
    #     " uniform vec2 viewSize;\n"
    #     " attribute vec2 vertex;\n"
    #     " attribute vec2 tcoord;\n"
    #     " varying vec2 ftcoord;\n"
    #     " varying vec2 fpos;\n"
    #     "#endif\n"
    #     "void main(void) {\n"
    #     " ftcoord = tcoord;\n"
    #     " fpos = vertex;\n"
    #     " gl_Position = vec4(2.0*vertex.x/viewSize.x - 1.0, 1.0 - 2.0*vertex.y/viewSize.y, 0, 1);\n"
    #     "}\n";
    #   static const char* fillFragShader = 
    #     "#ifdef GL_ES\n"
    #     "#if defined(GL_FRAGMENT_PRECISION_HIGH) || defined(NANOVG_GL3)\n"
    #     " precision highp float;\n"
    #     "#else\n"
    #     " precision mediump float;\n"
    #     "#endif\n"
    #     "#endif\n"
    #     "#ifdef NANOVG_GL3\n"
    #     "#ifdef USE_UNIFORMBUFFER\n"
    #     " layout(std140) uniform frag {\n"
    #     "   mat3 scissorMat;\n"
    #     "   mat3 paintMat;\n"
    #     "   vec4 innerCol;\n"
    #     "   vec4 outerCol;\n"
    #     "   vec2 scissorExt;\n"
    #     "   vec2 scissorScale;\n"
    #     "   vec2 extent;\n"
    #     "   float radius;\n"
    #     "   float feather;\n"
    #     "   float strokeMult;\n"
    #     "   float strokeThr;\n"
    #     "   int texType;\n"
    #     "   int type;\n"
    #     " };\n"
    #     "#else\n" // NANOVG_GL3 && !USE_UNIFORMBUFFER
    #     " uniform vec4 frag[UNIFORMARRAY_SIZE];\n"
    #     "#endif\n"
    #     " uniform sampler2D tex;\n"
    #     " in vec2 ftcoord;\n"
    #     " in vec2 fpos;\n"
    #     " out vec4 outColor;\n"
    #     "#else\n" // !NANOVG_GL3
    #     " uniform vec4 frag[UNIFORMARRAY_SIZE];\n"
    #     " uniform sampler2D tex;\n"
    #     " varying vec2 ftcoord;\n"
    #     " varying vec2 fpos;\n"
    #     "#endif\n"
    #     "#ifndef USE_UNIFORMBUFFER\n"
    #     " #define scissorMat mat3(frag[0].xyz, frag[1].xyz, frag[2].xyz)\n"
    #     " #define paintMat mat3(frag[3].xyz, frag[4].xyz, frag[5].xyz)\n"
    #     " #define innerCol frag[6]\n"
    #     " #define outerCol frag[7]\n"
    #     " #define scissorExt frag[8].xy\n"
    #     " #define scissorScale frag[8].zw\n"
    #     " #define extent frag[9].xy\n"
    #     " #define radius frag[9].z\n"
    #     " #define feather frag[9].w\n"
    #     " #define strokeMult frag[10].x\n"
    #     " #define strokeThr frag[10].y\n"
    #     " #define texType int(frag[10].z)\n"
    #     " #define type int(frag[10].w)\n"
    #     "#endif\n"
    #     "\n"
    #     "float sdroundrect(vec2 pt, vec2 ext, float rad) {\n"
    #     " vec2 ext2 = ext - vec2(rad,rad);\n"
    #     " vec2 d = abs(pt) - ext2;\n"
    #     " return min(max(d.x,d.y),0.0) + length(max(d,0.0)) - rad;\n"
    #     "}\n"
    #     "\n"
    #     "// Scissoring\n"
    #     "float scissorMask(vec2 p) {\n"
    #     " vec2 sc = (abs((scissorMat * vec3(p,1.0)).xy) - scissorExt);\n"
    #     " sc = vec2(0.5,0.5) - sc * scissorScale;\n"
    #     " return clamp(sc.x,0.0,1.0) * clamp(sc.y,0.0,1.0);\n"
    #     "}\n"
    #     "#ifdef EDGE_AA\n"
    #     "// Stroke - from [0..1] to clipped pyramid, where the slope is 1px.\n"
    #     "float strokeMask() {\n"
    #     " return min(1.0, (1.0-abs(ftcoord.x*2.0-1.0))*strokeMult) * min(1.0, ftcoord.y);\n"
    #     "}\n"
    #     "#endif\n"
    #     "\n"
    #     "void main(void) {\n"
    #     "   vec4 result;\n"
    #     " float scissor = scissorMask(fpos);\n"
    #     "#ifdef EDGE_AA\n"
    #     " float strokeAlpha = strokeMask();\n"
    #     "#else\n"
    #     " float strokeAlpha = 1.0;\n"
    #     "#endif\n"
    #     " if (type == 0) {      // Gradient\n"
    #     "   // Calculate gradient color using box gradient\n"
    #     "   vec2 pt = (paintMat * vec3(fpos,1.0)).xy;\n"
    #     "   float d = clamp((sdroundrect(pt, extent, radius) + feather*0.5) / feather, 0.0, 1.0);\n"
    #     "   vec4 color = mix(innerCol,outerCol,d);\n"
    #     "   // Combine alpha\n"
    #     "   color *= strokeAlpha * scissor;\n"
    #     "   result = color;\n"
    #     " } else if (type == 1) {   // Image\n"
    #     "   // Calculate color fron texture\n"
    #     "   vec2 pt = (paintMat * vec3(fpos,1.0)).xy / extent;\n"
    #     "#ifdef NANOVG_GL3\n"
    #     "   vec4 color = texture(tex, pt);\n"
    #     "#else\n"
    #     "   vec4 color = texture2D(tex, pt);\n"
    #     "#endif\n"
    #     "   if (texType == 1) color = vec4(color.xyz*color.w,color.w);"
    #     "   if (texType == 2) color = vec4(color.x);"
    #     "   // Apply color tint and alpha.\n"
    #     "   color *= innerCol;\n"
    #     "   // Combine alpha\n"
    #     "   color *= strokeAlpha * scissor;\n"
    #     "   result = color;\n"
    #     " } else if (type == 2) {   // Stencil fill\n"
    #     "   result = vec4(1,1,1,1);\n"
    #     " } else if (type == 3) {   // Textured tris\n"
    #     "#ifdef NANOVG_GL3\n"
    #     "   vec4 color = texture(tex, ftcoord);\n"
    #     "#else\n"
    #     "   vec4 color = texture2D(tex, ftcoord);\n"
    #     "#endif\n"
    #     "   if (texType == 1) color = vec4(color.xyz*color.w,color.w);"
    #     "   if (texType == 2) color = vec4(color.x);"
    #     "   color *= scissor;\n"
    #     "   result = color * innerCol;\n"
    #     " }\n"
    #     "#ifdef EDGE_AA\n"
    #     " if (strokeAlpha < strokeThr) discard;\n"
    #     "#endif\n"
    #     "#ifdef NANOVG_GL3\n"
    #     " outColor = result;\n"
    #     "#else\n"
    #     " gl_FragColor = result;\n"
    #     "#endif\n"
    #     "}\n";
    #   glnvg__checkError(gl, "init");
    #   if (gl->flags & NVG_ANTIALIAS) {
    #     if (glnvg__createShader(&gl->shader, "shader", shaderHeader, "#define EDGE_AA 1\n", fillVertShader, fillFragShader) == 0)
    #       return 0;
    #   } else {
    #     if (glnvg__createShader(&gl->shader, "shader", shaderHeader, NULL, fillVertShader, fillFragShader) == 0)
    #       return 0;
    #   }
    #   glnvg__checkError(gl, "uniform locations");
    #   glnvg__getUniforms(&gl->shader);
    #   // Create dynamic vertex array
    # #if defined(NANOVG_GL3)
    #   glGenVertexArrays(1, &gl->vertArr);
    # #endif
    #   glGenBuffers(1, &gl->vertBuf);
    # #if NANOVG_GL_USE_UNIFORMBUFFER
    #   // Create UBOs
    #   glUniformBlockBinding(gl->shader.prog, gl->shader.loc[GLNVG_LOC_FRAG], GLNVG_FRAG_BINDING);
    #   glGenBuffers(1, &gl->fragBuf); 
    #   glGetIntegerv(GL_UNIFORM_BUFFER_OFFSET_ALIGNMENT, &align);
    # #endif
    #   gl->fragSize = sizeof(GLNVGfragUniforms) + align - sizeof(GLNVGfragUniforms) % align;
    #   glnvg__checkError(gl, "create done");
    #   glFinish();
    #   return 1;
    # }
  proc renderCreateTexture*(uptr: pointer; `type`: cint; w: cint; 
                                   h: cint; imageFlags: cint; data: ptr cuchar): cint
    # {
    #   GLNVGcontext* gl = (GLNVGcontext*)uptr;
    #   GLNVGtexture* tex = glnvg__allocTexture(gl);
    #   if (tex == NULL) return 0;
    # #ifdef NANOVG_GLES2
    #   // Check for non-power of 2.
    #   if (glnvg__nearestPow2(w) != (unsigned int)w || glnvg__nearestPow2(h) != (unsigned int)h) {
    #     // No repeat
    #     if ((imageFlags & NVG_IMAGE_REPEATX) != 0 || (imageFlags & NVG_IMAGE_REPEATY) != 0) {
    #       printf("Repeat X/Y is not supported for non power-of-two textures (%d x %d)\n", w, h);
    #       imageFlags &= ~(NVG_IMAGE_REPEATX | NVG_IMAGE_REPEATY);
    #     }
    #     // No mips. 
    #     if (imageFlags & NVG_IMAGE_GENERATE_MIPMAPS) {
    #       printf("Mip-maps is not support for non power-of-two textures (%d x %d)\n", w, h);
    #       imageFlags &= ~NVG_IMAGE_GENERATE_MIPMAPS;
    #     }
    #   }
    # #endif
    #   glGenTextures(1, &tex->tex);
    #   tex->width = w;
    #   tex->height = h;
    #   tex->type = type;
    #   tex->flags = imageFlags;
    #   glnvg__bindTexture(gl, tex->tex);
    #   glPixelStorei(GL_UNPACK_ALIGNMENT,1);
    # #ifndef NANOVG_GLES2
    #   glPixelStorei(GL_UNPACK_ROW_LENGTH, tex->width);
    #   glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
    #   glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
    # #endif
    # #if defined(NANOVG_GL2)
    #   // GL 1.4 and later has support for generating mipmaps using a tex parameter.
    #   if (imageFlags & NVG_IMAGE_GENERATE_MIPMAPS) {
    #     glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
    #   }
    # #endif
    #   if (type == NVG_TEXTURE_RGBA)
    #     glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, w, h, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
    #   else
    # #if defined(NANOVG_GLES2)
    #     glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, w, h, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, data);
    # #elif defined(NANOVG_GLES3)
    #     glTexImage2D(GL_TEXTURE_2D, 0, GL_R8, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, data);
    # #else
    #     glTexImage2D(GL_TEXTURE_2D, 0, GL_RED, w, h, 0, GL_RED, GL_UNSIGNED_BYTE, data);
    # #endif
    #   if (imageFlags & NVG_IMAGE_GENERATE_MIPMAPS) {
    #     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    #   } else {
    #     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    #   }
    #   glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    #   if (imageFlags & NVG_IMAGE_REPEATX)
    #     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    #   else
    #     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    #   if (imageFlags & NVG_IMAGE_REPEATY)
    #     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    #   else
    #     glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    #   glPixelStorei(GL_UNPACK_ALIGNMENT, 4);
    # #ifndef NANOVG_GLES2
    #   glPixelStorei(GL_UNPACK_ROW_LENGTH, 0);
    #   glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0);
    #   glPixelStorei(GL_UNPACK_SKIP_ROWS, 0);
    # #endif
    #   // The new way to build mipmaps on GLES and GL3
    # #if !defined(NANOVG_GL2)
    #   if (imageFlags & NVG_IMAGE_GENERATE_MIPMAPS) {
    #     glGenerateMipmap(GL_TEXTURE_2D);
    #   }
    # #endif
    #   glnvg__checkError(gl, "create tex");
    #   glnvg__bindTexture(gl, 0);
    #   return tex->id;
    # }
  proc renderDeleteTexture*(uptr: pointer; image: cint): cint
    # {
    #   GLNVGcontext* gl = (GLNVGcontext*)uptr;
    #   return glnvg__deleteTexture(gl, image);
    # }
  proc renderUpdateTexture*(uptr: pointer; image: cint; x: cint; y: cint; 
                                   w: cint; h: cint; data: ptr cuchar): cint {.glf.}

  proc renderGetTextureSize*(uptr: pointer; image: cint; w: ptr cint; 
                                    h: ptr cint): cint {.glf.}

  proc xformToMat3x4*(m3: ptr cfloat; t: ptr cfloat) {.glf.}

  proc premulColor*(c: NVGcolor): NVGcolor {.glf.}

  proc convertPaint*(gl: ptr GLNVGcontext; frag: ptr GLNVGfragUniforms; 
                            paint: ptr NVGpaint; scissor: ptr NVGscissor; 
                            width: cfloat; fringe: cfloat; strokeThr: cfloat): cint {.glf.}

  #proc nvg__fragUniformPtr*(gl: ptr GLNVGcontext; i: cint): ptr GLNVGfragUniforms
  proc setUniforms*(gl: ptr GLNVGcontext; uniformOffset: cint; 
                           image: cint) {.glf.}

  proc renderViewport*(uptr: pointer; width: cint; height: cint) {.glf.}

  proc fill*(gl: ptr GLNVGcontext; call: ptr GLNVGcall) {.glf.}

  proc convexFill*(gl: ptr GLNVGcontext; call: ptr GLNVGcall) {.glf.}

  proc stroke*(gl: ptr GLNVGcontext; call: ptr GLNVGcall) {.glf.}

  proc triangles*(gl: ptr GLNVGcontext; call: ptr GLNVGcall) {.glf.}

  proc renderCancel*(uptr: pointer) {.glf.}

  proc renderFlush*(uptr: pointer) {.glf.}

  proc maxVertCount*(paths: ptr NVGpath; npaths: cint): cint {.glf.}

  proc allocCall*(gl: ptr GLNVGcontext): ptr GLNVGcall {.glf.}

  proc allocPaths*(gl: ptr GLNVGcontext; n: cint): cint {.glf.}

  proc allocVerts*(gl: ptr GLNVGcontext; n: cint): cint {.glf.}

  proc allocFragUniforms*(gl: ptr GLNVGcontext; n: cint): cint {.glf.}

  # proc nvg__fragUniformPtr*(gl: ptr GLNVGcontext; i: cint): ptr GLNVGfragUniforms = 
  #   return cast[ptr GLNVGfragUniforms](addr(gl.uniforms[i]))

  proc vset*(vtx: ptr NVGvertex; x: cfloat; y: cfloat; u: cfloat; 
                    v: cfloat) {.glf.}

  proc renderFill*(uptr: pointer; paint: ptr NVGpaint; 
                          scissor: ptr NVGscissor; fringe: cfloat; 
                          bounds: ptr cfloat; paths: ptr NVGpath; npaths: cint) {.glf.}
  
  proc renderStroke*(uptr: pointer; paint: ptr NVGpaint; 
                            scissor: ptr NVGscissor; fringe: cfloat; 
                            strokeWidth: cfloat; paths: ptr NVGpath; 
                            npaths: cint) {.glf.}
  # {
  #   GLNVGcontext* gl = (GLNVGcontext*)uptr;
  #   GLNVGcall* call = glnvg__allocCall(gl);
  #   int i, maxverts, offset;
  #   if (call == NULL) return;
  #   call->type = GLNVG_STROKE;
  #   call->pathOffset = glnvg__allocPaths(gl, npaths);
  #   if (call->pathOffset == -1) goto error;
  #   call->pathCount = npaths;
  #   call->image = paint->image;
  #   // Allocate vertices for all the paths.
  #   maxverts = glnvg__maxVertCount(paths, npaths);
  #   offset = glnvg__allocVerts(gl, maxverts);
  #   if (offset == -1) goto error;
  #   for (i = 0; i < npaths; i++) {
  #     GLNVGpath* copy = &gl->paths[call->pathOffset + i];
  #     const NVGpath* path = &paths[i];
  #     memset(copy, 0, sizeof(GLNVGpath));
  #     if (path->nstroke) {
  #       copy->strokeOffset = offset;
  #       copy->strokeCount = path->nstroke;
  #       memcpy(&gl->verts[offset], path->stroke, sizeof(NVGvertex) * path->nstroke);
  #       offset += path->nstroke;
  #     }
  #   }
  #   if (gl->flags & NVG_STENCIL_STROKES) {
  #     // Fill shader
  #     call->uniformOffset = glnvg__allocFragUniforms(gl, 2);
  #     if (call->uniformOffset == -1) goto error;
  #     glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call->uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
  #     glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call->uniformOffset + gl->fragSize), paint, scissor, strokeWidth, fringe, 1.0f - 0.5f/255.0f);
  #   } else {
  #     // Fill shader
  #     call->uniformOffset = glnvg__allocFragUniforms(gl, 1);
  #     if (call->uniformOffset == -1) goto error;
  #     glnvg__convertPaint(gl, nvg__fragUniformPtr(gl, call->uniformOffset), paint, scissor, strokeWidth, fringe, -1.0f);
  #   }
  #   return;
  # error:
  #   // We get here if call alloc was ok, but something else is not.
  #   // Roll back the last call to prevent drawing it.
  #   if (gl->ncalls > 0) gl->ncalls--;
  # }
  proc renderTriangles*(uptr: pointer; paint: ptr NVGpaint; 
                               scissor: ptr NVGscissor; verts: ptr NVGvertex; 
                               nverts: cint) {.glf.}
  # {
  #   GLNVGcontext* gl = (GLNVGcontext*)uptr;
  #   GLNVGcall* call = glnvg__allocCall(gl);
  #   GLNVGfragUniforms* frag;
  #   if (call == NULL) return;
  #   call->type = GLNVG_TRIANGLES;
  #   call->image = paint->image;
  #   // Allocate vertices for all the paths.
  #   call->triangleOffset = glnvg__allocVerts(gl, nverts);
  #   if (call->triangleOffset == -1) goto error;
  #   call->triangleCount = nverts;
  #   memcpy(&gl->verts[call->triangleOffset], verts, sizeof(NVGvertex) * nverts);
  #   // Fill shader
  #   call->uniformOffset = glnvg__allocFragUniforms(gl, 1);
  #   if (call->uniformOffset == -1) goto error;
  #   frag = nvg__fragUniformPtr(gl, call->uniformOffset);
  #   glnvg__convertPaint(gl, frag, paint, scissor, 1.0f, 1.0f, -1.0f);
  #   frag->type = NSVG_SHADER_IMG;
  #   return;
  # error:
  #   // We get here if call alloc was ok, but something else is not.
  #   // Roll back the last call to prevent drawing it.
  #   if (gl->ncalls > 0) gl->ncalls--;
  # }
  proc renderDelete*(uptr: pointer) {.glf.}
  # {
  #   GLNVGcontext* gl = (GLNVGcontext*)uptr;
  #   int i;
  #   if (gl == NULL) return;
  #   glnvg__deleteShader(&gl->shader);
  # #if NANOVG_GL3
  # #if NANOVG_GL_USE_UNIFORMBUFFER
  #   if (gl->fragBuf != 0)
  #     glDeleteBuffers(1, &gl->fragBuf);
  # #endif
  #   if (gl->vertArr != 0)
  #     glDeleteVertexArrays(1, &gl->vertArr);
  # #endif
  #   if (gl->vertBuf != 0)
  #     glDeleteBuffers(1, &gl->vertBuf);
  #   for (i = 0; i < gl->ntextures; i++) {
  #     if (gl->textures[i].tex != 0 && (gl->textures[i].flags & NVG_IMAGE_NODELETE) == 0)
  #       glDeleteTextures(1, &gl->textures[i].tex);
  #   }
  #   free(gl->textures);
  #   free(gl->paths);
  #   free(gl->verts);
  #   free(gl->uniforms);
  #   free(gl->calls);
  #   free(gl);
  # }
  when defined(nvgGL2): 
    proc nvgCreateGL2*(flags: cint): NVGcontextPtr
  elif defined(nvgGL3): 
    proc nvgCreateGL3*(flags: cint): NVGcontextPtr
  elif defined(NANOVG_GLES2): 
    proc nvgCreateGLES2*(flags: cint): NVGcontextPtr
  elif defined(NANOVG_GLES3): 
    proc nvgCreateGLES3*(flags: cint): NVGcontextPtr
  # {
  #   NVGparams params;
  #   NVGcontext* ctx = NULL;
  #   GLNVGcontext* gl = (GLNVGcontext*)malloc(sizeof(GLNVGcontext));
  #   if (gl == NULL) goto error;
  #   memset(gl, 0, sizeof(GLNVGcontext));
  #   memset(&params, 0, sizeof(params));
  #   params.renderCreate = glnvg__renderCreate;
  #   params.renderCreateTexture = glnvg__renderCreateTexture;
  #   params.renderDeleteTexture = glnvg__renderDeleteTexture;
  #   params.renderUpdateTexture = glnvg__renderUpdateTexture;
  #   params.renderGetTextureSize = glnvg__renderGetTextureSize;
  #   params.renderViewport = glnvg__renderViewport;
  #   params.renderCancel = glnvg__renderCancel;
  #   params.renderFlush = glnvg__renderFlush;
  #   params.renderFill = glnvg__renderFill;
  #   params.renderStroke = glnvg__renderStroke;
  #   params.renderTriangles = glnvg__renderTriangles;
  #   params.renderDelete = glnvg__renderDelete;
  #   params.userPtr = gl;
  #   params.edgeAntiAlias = flags & NVG_ANTIALIAS ? 1 : 0;
  #   gl->flags = flags;
  #   ctx = nvgCreateInternal(&params);
  #   if (ctx == NULL) goto error;
  #   return ctx;
  # error:
  #   // 'gl' is freed by nvgDeleteInternal.
  #   if (ctx != NULL) nvgDeleteInternal(ctx);
  #   return NULL;
  # }

  when defined(nvgGL2): 
    proc nvgDeleteGL2*(ctx: NVGcontextPtr)
  elif defined(nvgGL3): 
    proc nvgDeleteGL3*(ctx: NVGcontextPtr)
  elif defined(NANOVG_GLES2): 
    proc nvgDeleteGLES2*(ctx: NVGcontextPtr)
  elif defined(NANOVG_GLES3): 
    proc nvgDeleteGLES3*(ctx: NVGcontextPtr)
  # {
  #   nvgDeleteInternal(ctx);
  # }
  proc nvglCreateImageFromHandle*(ctx: NVGcontextPtr; textureId: GLuint; 
                                  w: cint; h: cint; imageFlags: cint): cint {.glf2.}

  proc nvglImageHandle*(ctx: NVGcontextPtr; image: cint): GLuint {.glf2.}











