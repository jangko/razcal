import strutils, idents, os, tables, utils

type
  # information about a file(raz, lua, etc)
  FileInfo* = object
    fullPath: string           # This is a canonical full filesystem path
    projPath*: string          # This is relative to the project's root
    shortName*: string         # short name of the module
    fileName*: string          # name.ext

  # global app context, one per app
  Context* = ref object
    identCache: IdentCache     # only one IdentCache per app
    fileInfos: seq[FileInfo]   # FileInfo list
    filenameToIndex: Table[string, int32] # map canonical filename into FileInfo index
    binaryPath: string         # app path

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

  MsgKind* = enum
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

    errClosingBracketExpected
    errClosingParExpected
    errInvalidIndentation
    errExprExpected
    errIdentExpected
    errTokenExpected
    errSourceEndedUnexpectedly
    errInvalidExpresion
    errOnlyAsgnAllowed

    errUnknownNode
    errCannotOpenFile
    errDuplicateView
    errDuplicateClass

const
  InvalidFileIDX* = int32(-1)

const
  MsgKindToStr*: array[MsgKind, string] = [
    errMissingFinalQuote: "missing final quote",
    errInvalidCharacterConstant: "invalid character constant '0x$1'",
    errClosingQuoteExpected: "closing quote expected",
    errWrongEscapeChar: "wrong escape character in string '$1'",
    errUnknownNumberType: "unknown number type",
    errInvalidToken: "invalid token '$1'",
    errInvalidNumberRange: "invalid number range: $1",
    errNumberOverflow: "number overflow",
    errUnexpectedEOLinMultiLineComment: "unexpected end of file in multi line comment",
    errTabsAreNotAllowed: "tabs are not allowed",

    errClosingBracketExpected: "closing bracket expected",
    errClosingParExpected: "closing parenthesis expected",
    errInvalidIndentation: "invalid indentation",
    errExprExpected: "expr expected",
    errIdentExpected: "ident expected",
    errTokenExpected: "token expected: $1",
    errSourceEndedUnexpectedly: "source ended unexpectedly",
    errInvalidExpresion: "invalid expression",
    errOnlyAsgnAllowed: "only assignment allowed here",

    errUnknownNode: "unknown node $1",
    errCannotOpenFile: "cannot open file: $1",
    errDuplicateView: "duplicate view not allowed: '$1', the other one is here: $2",
    errDuplicateClass: "duplicate class not allowed: '$1', the other one is here: $2",
  ]

proc newContext*(): Context =
  new(result)
  result.identCache = newIdentCache()
  result.fileInfos = @[]
  result.filenameToIndex = initTable[string, int32]()
  result.binaryPath = getAppDir()

proc getIdent*(ctx: Context, ident: string): Ident {.inline.} =
  # a helper proc to get ident
  result = ctx.identCache.getIdent(ident)

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

proc printError*(ctx: Context, err: SourceError) =
  assert(err.fileIndex >= 0 and err.fileIndex < ctx.fileInfos.len)
  let info = ctx.fileInfos[err.fileIndex]
  let msg = "$1($2,$3) Error: $4" % [info.fileName, $err.line, $(err.column + 1), err.msg]
  echo err.marker()
  echo msg

proc printError*(ctx: Context, err: InternalError) =
  let msg = "$1:$2 -> Internal Error: $3" % [err.fileName, $err.line, err.msg]
  echo msg

proc msgKindToString*(ctx: Context, kind: MsgKind, args: varargs[string]): string =
  # later versions may provide translated error messages
  result = MsgKindToStr[kind] % args

proc newFileInfo(fullPath, projPath: string): FileInfo =
  result.fullPath = fullPath
  result.projPath = projPath
  let fileName = projPath.extractFilename
  result.fileName = fileName
  result.shortName = fileName.changeFileExt("")

proc fileInfoIdx*(ctx: Context, filename: string; isKnownFile: var bool): int32 =
  # map file name into FileInfo list's index
  var
    canon: string
    pseudoPath = false

  try:
    canon = canonicalizePath(filename)
    shallow(canon)
  except:
    canon = filename
    # The compiler uses "filenames" such as `command line` or `stdin`
    # This flag indicates that we are working with such a path here
    pseudoPath = true

  if ctx.filenameToIndex.hasKey(canon):
    result = ctx.filenameToIndex[canon]
  else:
    isKnownFile = false
    result = ctx.fileInfos.len.int32
    ctx.fileInfos.add(newFileInfo(canon, if pseudoPath: filename
                                         else: shortenDir(ctx.binaryPath, canon)))
    ctx.filenameToIndex[canon] = result

proc toFileName*(ctx: Context, info: LineInfo): string =
  assert(info.fileIndex >= 0 and info.fileIndex < ctx.fileInfos.len)
  result = ctx.fileInfos[info.fileIndex].fileName

proc toFullPath*(ctx: Context, info: LineInfo): string =
  assert(info.fileIndex >= 0 and info.fileIndex < ctx.fileInfos.len)
  result = ctx.fileInfos[info.fileIndex].fullPath

proc toString*(ctx: Context, info: LineInfo): string =
  result = "$1($2:$3)" % [ctx.toFileName(info), $info.line, $(info.col+1)]
