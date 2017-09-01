type
  SpecialWords* = enum
    wInvalid

    wDot, wDotDot, wColon, wColonColon      # this two section
    wBang, wChoice                          # must match with
    wEquals, wGreaterOrEqual, wLessOrEqual  # TokenKind's order
                                            # to ensure proper
    wProgram, wStyle, wAlias                # token generated
    wEvent, wProp, wConst

    wThis, wSuper, wChild, wPrev, wNext
    wLeft, wRight, wTop, wBottom
    wWidth, wHeight, wCenterX, wCenterY

    wContent, wTitle, wZindex, wOverflow
    wVisible, wMultiline, wLink, wImg, wIcon

    wClick, wContextMenu, wDblClick, wMouseDown
    wMouseEnter, wMouseLeave, wMouseMove, wMouseOver
    wMouseOut, wMouseUp, wWheel

    wKeyDown, wKeyPress, wKeyUp

    wAbort, wBeforeUnload, wWrror, wHashChange
    wLoad, wResize, wScroll, wUnload

    wBlur, wChange, wFocus, wFocusIn, wFocusOut
    wInput, wSelect

    wDrag, wDragEnd, wDragEnter, wDragLeave
    wDragOver, wDragStart, wonDrop

const
  specialWords* = [
    ".", "..", ":", "::",
    "!", "|",
    "=", ">=", "<=",

    "program", "style", "alias",
    "const", "event", "prop", 

    "this", "super", "child", "prev", "next",
    "left", "right", "top", "bottom",
    "width", "height", "centerX", "centerY",

    "content", "title", "zindex", "overflow",
    "visible", "multiline", "link", "img", "icon",

    "click", "contextMenu", "dblClick", "mouseDown",
    "mouseEnter", "mouseLeave", "mouseMove", "mouseOver",
    "mouseOut", "mouseUp", "wheel",

    "keyDown", "keyPress", "keyUp",

    "abort", "beforeUnload", "error", "hashChange",
    "load", "resize", "scroll", "unload",

    "blur", "change", "focus", "focusIn", "focusOut",
    "input", "select",

    "drag", "dragEnd", "dragEnter", "dragLeave",
    "dragOver", "dragStart", "onDrop",
  ]