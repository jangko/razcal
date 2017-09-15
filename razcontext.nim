import strutils, idents, os, tables, utils
import nimLUA

type
  # information about a file(raz, lua, etc)
  FileInfo* = object
    fullPath: string           # This is a canonical full filesystem path
    projPath*: string          # This is relative to the project's root
    shortName*: string         # short name of the module
    fileName*: string          # name.ext

  # global app context, one per app
  RazContext* = ref object
    identCache: IdentCache     # only one IdentCache per app
    fileInfos: seq[FileInfo]   # FileInfo list
    fileNameToIndex: Table[string, int32] # map canonical fileName into FileInfo index
    binaryPath: string         # app path
    lua: lua_State

  # used in Node and Symbol
  LineInfo* = object
    line*, col*: int16
    fileIndex*: int32          # index into FileInfo list

  # Lexer and Parser throw this exception
  SourceError* = ref object of Exception
    line*, column*: int
    lineContent*: string       # full source line content
    fileIndex*: int32          # index into FileInfo list

  # Semcheck and friends throw this exception
  # useful for debugging purpose
  # A stable app should never throw this exception
  InternalError* = ref object of Exception
    line*: int                 # Nim source line
    fileName*: string          # Nim source file name

  OtherError* = ref object of Exception

  MsgKind* = enum
    # lexer's errors
    errMissingFinalQuote
    errInvalidCharacterConstant
    errClosingQuoteExpected
    errWrongEscapeChar
    errUnknownNumberType
    errInvalidToken
    errInvalidNumberRange
    errNumberOverflow
    errUnexpectedEOLinMultiLineComment
    errTabsAreNotAllowed

    # parser's errors
    errClosingBracketExpected
    errClosingParExpected
    errInvalidIndentation
    errExprExpected
    errIdentExpected
    errTokenExpected
    errSourceEndedUnexpectedly
    errInvalidExpresion
    errOnlyAsgnAllowed
    errConstOprNeeded
    errPropExpected

    # semcheck's errors
    errUnknownNode
    errDuplicateView
    errDuplicateClass
    errDuplicateParam
    errClassNotFound
    errParamCountNotMatch
    errUndefinedVar
    errUnknownVar
    errUndefinedRel
    errUnknownRel
    errRelationNotFound
    errWrongRelationIndex
    errIllegalBinaryOpr
    errUnknownBinaryOpr
    errUnknownOperation
    errIllegalOperation
    errStringNotAllowed
    errFloatNotAllowed
    errNoValidBranch
    errIllegalPrefixOpr
    errUnknownPrefixOpr
    errUnknownPrefix
    errIllegalPrefix
    errUnknownEqualityOpr
    errUndefinedProp
    errUnknownProp
    errUndefinedEvent
    errUnknownEvent
    errUnbalancedArm
    errUnsatisfiableConstraint

    # other's errors
    errCannotOpenFile
    errLua

    warnParamNotUsed
    warnClassNotUsed

const
  InvalidFileIDX* = int32(-1)

const
  MsgKindToStr*: array[MsgKind, string] = [
    # lexer's errors
    errMissingFinalQuote: "missing final quote",
    errInvalidCharacterConstant: "invalid character constant `0x$1`",
    errClosingQuoteExpected: "closing quote expected",
    errWrongEscapeChar: "wrong escape character in string `$1`",
    errUnknownNumberType: "unknown number type",
    errInvalidToken: "invalid token `$1`",
    errInvalidNumberRange: "invalid number range: $1",
    errNumberOverflow: "number overflow",
    errUnexpectedEOLinMultiLineComment: "unexpected end of file in multi line comment",
    errTabsAreNotAllowed: "tabs are not allowed",

    # parser`s errors
    errClosingBracketExpected: "closing bracket expected",
    errClosingParExpected: "closing parenthesis expected",
    errInvalidIndentation: "invalid indentation",
    errExprExpected: "expr expected",
    errIdentExpected: "ident expected",
    errTokenExpected: "token expected: $1",
    errSourceEndedUnexpectedly: "source ended unexpectedly",
    errInvalidExpresion: "invalid expression",
    errOnlyAsgnAllowed: "only assignment allowed here",
    errConstOprNeeded: "one of constraint [in]equality needed: `=`, `<=`, `>=`",
    errPropExpected: "prop expected, missing '.' perhaps?",

    # semcheck`s errors
    errUnknownNode: "unknown node $1",
    errDuplicateView: "duplicate view not allowed: `$1`, the other one is here: $2",
    errDuplicateClass: "duplicate class not allowed: `$1`, the other one is here: $2",
    errDuplicateParam: "duplicate param name: `$1`",
    errClassNotFound: "class `$1` not found",
    errParamCountNotMatch: "expected $1 param(s) but got $2 param(s)",
    errUndefinedVar: "`$1` is an undefined constraint variable",
    errUnknownVar: "`$1` is an unknown constraint variable",
    errUndefinedRel: "`$1` is an undefined relation",
    errUnknownRel: "`$1` is an unknown relation",
    errRelationNotFound: "relation not found: `$1` is not available for `$2`",
    errWrongRelationIndex: "relation at index $1 not found",
    errIllegalBinaryOpr: "illegal binary operator: `$1`",
    errUnknownBinaryOpr: "unknown binary operator: `$1`",
    errUnknownOperation: "unknown operation $1 $2 $3",
    errIllegalOperation: "illegal operation $1 $2 $3",
    errStringNotAllowed: "string not allowed here",
    errFloatNotAllowed: "float not allowed here",
    errNoValidBranch: "no valid branch of choices",
    errIllegalPrefixOpr: "illegal prefix operator: `$1`",
    errUnknownPrefixOpr: "unknown prefix operator: `$1`",
    errUnknownPrefix: "unknown prefix operation: `$1` $2",
    errIllegalPrefix: "illegal prefix operation: `$1` $2",
    errUnknownEqualityOpr: "unknown constraint equality operator: `$1`",
    errUndefinedProp: "`$1` is an undefined view property",
    errUnknownProp: "`$1` is an unknown view property",
    errUndefinedEvent: "`$1` is an undefined view event",
    errUnknownEvent: "`$1` is an unknown view event",
    errUnbalancedArm: "left and right arm is not balanced here",
    errUnsatisfiableConstraint: "unsatisfiable constraint",

    # other errors
    errCannotOpenFile: "cannot open file: $1",
    errLua: "lua VM error: $1",

    warnParamNotUsed: "param `$1` not used",
    warnClassNotUsed: "class `$1` not used",
  ]

proc openRazContext*(): RazContext =
  new(result)
  result.identCache = newIdentCache()
  result.fileInfos = @[]
  result.fileNameToIndex = initTable[string, int32]()
  result.binaryPath = getAppDir()
  result.lua = newNimLua()

proc close*(ctx: RazContext) =
  ctx.lua.close()

proc getLua*(ctx: RazContext): lua_State =
  ctx.lua

proc getIdent*(ctx: RazContext, ident: string): Ident {.inline.} =
  # a helper proc to get ident
  result = ctx.identCache.getIdent(ident)

proc msgKindToString*(ctx: RazContext, kind: MsgKind, args: varargs[string]): string =
  # later versions may provide translated error messages
  result = MsgKindToStr[kind] % args

proc otherError*(ctx: RazContext, kind: MsgKind, args: varargs[string, `$`]) =
  var err = new(OtherError)
  err.msg = ctx.msgKindToString(kind, args)
  raise err

proc executeLua*(ctx: RazContext, fileName: string) =
  if ctx.lua.doFile(fileName) != 0.cint:
    let errorMsg = ctx.lua.toString(-1)
    ctx.lua.pop(1)
    ctx.otherError(errLua, errorMsg)

proc marker(err: SourceError): string =
  # the purpose of this function is try to trim a very long line
  # into reasonable length and put error marker '^' below it
  if err.lineContent.len <= 80:
    return err.lineContent & spaces(err.column) & "^"

  var start = err.column - 40
  var stop = err.column + 40
  var trimStart = false
  var trimStop = false
  if start < 0:
    start = 0
    trimStart = true
  if stop > 80:
    stop = 80
    trimStop = true

  result = err.lineContent.substr(start, stop)
  if trimStart:
    var i = 0
    while i < 3 and i < result.len:
      result[i] = '.'
      inc i

  if trimStop:
    var i = result.len - 1
    while i > result.len - 4 and i > 0:
      result[i] = '.'
      dec i

proc printMessage*(ctx: RazContext, err: SourceError, errClass: string) =
  assert(err.fileIndex >= 0 and err.fileIndex < ctx.fileInfos.len)
  let info = ctx.fileInfos[err.fileIndex]
  let msg = "$1($2,$3) $4: $5" % [info.fileName, $err.line, $(err.column + 1), errClass, err.msg]
  echo err.marker()
  echo msg

proc printWarning*(ctx: RazContext, err: SourceError) =
  ctx.printMessage(err, "Warning")

proc printError*(ctx: RazContext, err: SourceError) =
  ctx.printMessage(err, "Error")

proc printError*(ctx: RazContext, err: InternalError) =
  let msg = "$1:$2 -> Internal Error: $3" % [err.fileName, $err.line, err.msg]
  echo msg

proc newFileInfo(fullPath, projPath: string): FileInfo =
  result.fullPath = fullPath
  result.projPath = projPath
  let fileName = projPath.extractfileName
  result.fileName = fileName
  result.shortName = fileName.changeFileExt("")

proc fileInfoIdx*(ctx: RazContext, fileName: string; isKnownFile: var bool): int32 =
  # map file name into FileInfo list's index
  var
    canon: string
    pseudoPath = false

  try:
    canon = canonicalizePath(fileName)
    shallow(canon)
  except:
    canon = fileName
    # The compiler uses "fileNames" such as `command line` or `stdin`
    # This flag indicates that we are working with such a path here
    pseudoPath = true

  if ctx.fileNameToIndex.hasKey(canon):
    result = ctx.fileNameToIndex[canon]
  else:
    isKnownFile = false
    result = ctx.fileInfos.len.int32
    ctx.fileInfos.add(newFileInfo(canon, if pseudoPath: fileName
                                         else: shortenDir(ctx.binaryPath, canon)))
    ctx.fileNameToIndex[canon] = result

proc toFileName*(ctx: RazContext, info: LineInfo): string =
  assert(info.fileIndex >= 0 and info.fileIndex < ctx.fileInfos.len)
  result = ctx.fileInfos[info.fileIndex].fileName

proc toFullPath*(ctx: RazContext, info: LineInfo): string =
  assert(info.fileIndex >= 0 and info.fileIndex < ctx.fileInfos.len)
  result = ctx.fileInfos[info.fileIndex].fullPath

proc toString*(ctx: RazContext, info: LineInfo): string =
  result = "$1($2:$3)" % [ctx.toFileName(info), $info.line, $(info.col+1)]
