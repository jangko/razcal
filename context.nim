import strutils, idents, os, tables, utils

type
  FileInfo* = object
    fullPath: string           # This is a canonical full filesystem path
    projPath*: string          # This is relative to the project's root
    shortName*: string         # short name of the module
    fileName*: string          # name.ext

  Context* = ref object
    identCache: IdentCache
    fileInfos: seq[FileInfo]
    filenameToIndex: Table[string, int32]
    binaryPath: string         # app path

  LineInfo* = object
    line*, col*: int16
    fileIndex*: int32

  SourceError* = ref object of Exception
    line*, column*: int
    lineContent*: string
    fileIndex*: int32

  InternalError* = ref object of Exception
    line*: int
    fileName*: string

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

    errClosingParExpected
    errInvalidIndentation
    errExprExpected
    errIdentExpected
    errTokenExpected
    errSourceEndedUnexpectedly
    errInvalidExpresion

    errUnknownNode
    errCannotOpenFile
    errDuplicateView

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

    errClosingParExpected: "closing parenthesis expected",
    errInvalidIndentation: "invalid indentation",
    errExprExpected: "expr expected",
    errIdentExpected: "ident expected",
    errTokenExpected: "token expected: $1",
    errSourceEndedUnexpectedly: "source ended unexpectedly",
    errInvalidExpresion: "invalid expression",

    errUnknownNode: "unknown node $1",
    errCannotOpenFile: "cannot open file: $1",
    errDuplicateView: "duplicate view not allowed: '$1', the other one is here: $2",
  ]

proc newContext*(): Context =
  new(result)
  result.identCache = newIdentCache()
  result.fileInfos = @[]
  result.filenameToIndex = initTable[string, int32]()
  result.binaryPath = getAppDir()

proc getIdent*(ctx: Context, ident: string): Ident {.inline.} =
  result = ctx.identCache.getIdent(ident)

proc printError*(ctx: Context, err: SourceError) =
  assert(err.fileIndex >= 0 and err.fileIndex < ctx.fileInfos.len)
  let info = ctx.fileInfos[err.fileIndex]
  let msg = "$1($2,$3) Error: $4" % [info.fileName, $err.line, $(err.column + 1), err.msg]
  echo err.lineContent & spaces(err.column) & "^"
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
